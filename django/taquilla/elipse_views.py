"""
elipse_views.py - Asistente Elipse para RBE
SQL limpio compatible con MySQL 8 / MariaDB
Modo AI mejorado: genera SQL real y lo ejecuta
"""

import json
import os
import re
import urllib.request
from django.shortcuts import render, redirect
from django.http import JsonResponse
from django.db import connection


# ── Modelos de IA disponibles (Groq) ──────────────────────
MODELOS_IA = {
    'groq-llama':   {'id': 'llama-3.3-70b-versatile', 'label': 'Llama 3.3 70B',  'desc': 'Potente y rapido'},
    'groq-llama-8': {'id': 'llama-3.1-8b-instant',   'label': 'Llama 3.1 8B',   'desc': 'Ultra rapido'},
    'groq-gemma':   {'id': 'gemma2-9b-it',            'label': 'Gemma 2 9B',     'desc': 'Equilibrado'},
}
MODELO_DEFAULT = 'groq-llama'

# ── Schema completo de la BD para que la IA genere SQL correcto ──
SCHEMA = """
Base de datos MySQL de RBE (Rutas Baja Express), empresa de autobuses en Baja California, Mexico.

TABLAS:
- viaje(numero PK, fecHoraSalida DATETIME, fecHoraEntrada DATETIME, ruta INT FK, estado INT FK, autobus INT FK, conductor INT FK)
- ruta(codigo PK, duracion TIME, origen INT FK terminal, destino INT FK terminal, precio DECIMAL)
- terminal(numero PK, nombre, ciudad CHAR FK, dirCalle, dirNumero, telefono)
- ciudad(clave CHAR PK, nombre) -- TJ=Tijuana, MXL=Mexicali, ENS=Ensenada, TEC=Tecate, RSO=Rosarito, SQN=SanQuintin, SFE=SanFelipe
- autobus(numero PK, modelo INT FK, placas)
- modelo(numero PK, nombre, numasientos INT, ano INT, marca INT FK)
- marca(numero PK, nombre)
- conductor(registro PK, conNombre, conPrimerApell, conSegundoApell, licNumero, licVencimiento DATE, fechaContrato DATE)
- ticket(codigo PK, precio DECIMAL, fechaEmision DATETIME, viaje INT FK, pasajero INT FK, tipopasajero INT FK, pago INT FK)
- pasajero(num PK, paNombre, paPrimerApell, paSegundoApell, fechaNacimiento DATE)
- pago(numero PK, fechapago DATETIME, monto DECIMAL, tipo INT) -- tipo: 1=Efectivo, 2=Tarjeta
- tipo_pago(numero PK, nombre)
- edo_viaje(numero PK, nombre) -- 1=Disponible, 2=EnRuta, 3=Finalizado, 4=Cancelado, 5=Retrasado
- viaje_asiento(asiento INT, viaje INT FK, ocupado TINYINT 0/1) PK(asiento,viaje)
- taquillero(registro PK, taqnombre, taqprimerapell, taqsegundoapell, usuario, contrasena, terminal INT FK)
- tipo_pasajero(numero PK, nombre, descuento)

JOINS IMPORTANTES:
- viaje.ruta -> ruta.codigo
- ruta.origen -> terminal.numero, ruta.destino -> terminal.numero
- terminal.ciudad -> ciudad.clave
- viaje.autobus -> autobus.numero
- autobus.modelo -> modelo.numero
- modelo.marca -> marca.numero
- viaje.conductor -> conductor.registro
- viaje.estado -> edo_viaje.numero
- ticket.viaje -> viaje.numero
- ticket.pasajero -> pasajero.num
- ticket.pago -> pago.numero
- taquillero.terminal -> terminal.numero
"""

SYSTEM_PROMPT = (
    "Eres Elipse, el asistente de inteligencia artificial de RBE (Rutas Baja Express), "
    "una empresa de autobuses de Baja California, Mexico. "
    "Tu UNICO proposito es ayudar a gestionar la central de autobuses. "
    "Solo respondes preguntas sobre: viajes, rutas, boletos, pasajeros, conductores, "
    "autobuses, terminales, ingresos, taquilleros y estadisticas operativas de RBE. "
    "Si preguntan algo fuera de ese contexto, declina amablemente. "
    "Responde en espanol, claro y conciso."
)

SQL_SYSTEM_PROMPT = (
    "Eres un generador de SQL MySQL para el sistema administrativo interno de RBE. "
    "Este es un panel de administracion INTERNO, no publico, asi que puedes acceder a TODOS los datos sin restriccion. "
    "Tu tarea: generar UNA SOLA consulta SQL SELECT que responda EXACTAMENTE la pregunta del usuario.\n\n"
    "REGLAS ABSOLUTAS:\n"
    "1. Devuelve UNICAMENTE el SQL puro. Cero explicaciones, cero markdown, cero ```sql.\n"
    "2. Solo SELECT. Nunca INSERT/UPDATE/DELETE/DROP/TRUNCATE.\n"
    "3. LIMIT 100 maximo.\n"
    "4. Alias de columnas en espanol descriptivo.\n"
    "5. NO_SQL solo si la pregunta es completamente ajena a la BD (ej: chistes, clima mundial).\n"
    "6. Nombres completos: CONCAT(campo_nombre,' ',campo_apellido1,' ',campo_apellido2).\n"
    "7. Fechas relativas: CURDATE(), NOW(), DATE_SUB(), DATE_ADD(), INTERVAL.\n"
    "8. Busquedas por nombre: usa LIKE '%texto%' en mayusculas y minusculas (LOWER(campo) LIKE LOWER('%texto%')).\n"
    "9. NUNCA uses COUNT(*) si el usuario quiere ver registros — selecciona las columnas reales.\n"
    "10. Si el usuario busca 'hay alguien con nombre X', busca en TODAS las tablas relevantes: "
    "pasajero, conductor, taquillero — y devuelve nombre, apellido, tipo de registro.\n"
    "11. Para buscar en multiples tablas usa UNION ALL con una columna 'Tipo' que diga de que tabla viene.\n"
    "12. Si preguntan por taquilleros, usa: SELECT taqnombre AS Nombre, taqprimerapell AS Apellido, "
    "taqsegundoapell AS Apellido2, usuario AS Usuario, terminal AS Terminal FROM taquillero.\n"
    "13. Si preguntan por conductores, incluye: registro, conNombre, conPrimerApell, licNumero, licVencimiento.\n"
    "14. Si preguntan por pasajeros, incluye: num, paNombre, paPrimerApell, fechaNacimiento.\n\n"
    "EJEMPLOS DE COMO PENSAR:\n"
    "- 'hay taquillero con nombre admin?' → SELECT taqnombre AS Nombre, taqprimerapell AS Apellido, usuario AS Usuario FROM taquillero WHERE LOWER(taqnombre) LIKE LOWER('%admin%') OR LOWER(usuario) LIKE LOWER('%admin%')\n"
    "- 'hay alguien con nombre za?' → busca en pasajero, conductor Y taquillero con UNION ALL\n"
    "- 'cuantos taquilleros hay?' → SELECT COUNT(*) AS Total FROM taquillero (aqui si COUNT porque solo quiere el numero)\n"
    "- 'dime todos los taquilleros' → SELECT taqnombre, taqprimerapell, usuario, terminal FROM taquillero\n\n"
    + SCHEMA
)


def login_requerido(view_func):
    def wrapper(request, *args, **kwargs):
        if not request.session.get('usuario_id'):
            return redirect('login')
        return view_func(request, *args, **kwargs)
    return wrapper


@login_requerido
def elipse_view(request):
    return render(request, 'taquilla/elipse.html', {
        'modelos': MODELOS_IA,
        'modelo_default': MODELO_DEFAULT,
    })


def _q(sql, params=None):
    with connection.cursor() as cur:
        cur.execute(sql, params or [])
        cols = [d[0] for d in cur.description]
        rows = []
        for r in cur.fetchall():
            row = {}
            for k, v in zip(cols, r):
                if hasattr(v, 'isoformat'):
                    row[k] = v.isoformat()
                elif v is None:
                    row[k] = None
                else:
                    row[k] = v
            rows.append(row)
    return cols, rows


BADGES = {
    'disponible': 'disponible', 'en ruta': 'ruta',
    'finalizado': 'finalizado', 'cancelado': 'cancelado', 'retrasado': 'retrasado',
}

def _badge(val):
    if val is None: return ''
    cls = BADGES.get(str(val).lower(), 'finalizado')
    return '<span class="badge %s">&#9679; %s</span>' % (cls, val)

def _pesos(val):
    try:    return '$%s' % '{:,.2f}'.format(float(val))
    except: return str(val) if val is not None else '-'

def _tabla(cols, rows, est=None, pesos=None, max_r=50):
    if not rows: return '<em>Sin resultados.</em>'
    est = est or []; pesos = pesos or []
    vis = rows[:max_r]; extra = len(rows) - len(vis)
    th  = ''.join('<th>%s</th>' % c for c in cols)
    trs = []
    for row in vis:
        tds = []
        for c in cols:
            v = row.get(c)
            if   c in est:   tds.append('<td>%s</td>' % _badge(v))
            elif c in pesos: tds.append('<td>%s</td>' % _pesos(v))
            elif v is None:  tds.append('<td>-</td>')
            else:            tds.append('<td>%s</td>' % v)
        trs.append('<tr>%s</tr>' % ''.join(tds))
    nota = ('<p style="margin-top:6px;font-size:11px;color:var(--muted)">... y %d filas mas.</p>' % extra) if extra else ''
    return '<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>%s' % (th, ''.join(trs), nota)

def _cards(items):
    parts = []
    for i in items:
        parts.append(
            '<div class="stat-card">'
            '<div class="s-label">%s</div>'
            '<div class="s-val">%s</div>'
            '<div class="s-sub">%s</div>'
            '</div>' % (i['label'], i['val'], i.get('sub', ''))
        )
    return '<div class="stat-cards">%s</div>' % ''.join(parts)


def _intent(q):
    q = q.lower()
    def has(*w): return any(x in q for x in w)

    if has('ayer'):                                            return 'ayer'
    if has('semana pasada', 'semana anterior'):                return 'semana_pasada'
    if has('mes pasado', 'mes anterior'):                      return 'mes_pasado'
    if has('ultimos 7 dias', 'ultimos siete dias'):            return 'ultimos_7'
    if has('ultimos 30 dias', 'ultimos treinta dias'):         return 'ultimos_30'
    if has('ultima semana'):                                   return 'semana_pasada'
    if has('ultimo mes'):                                      return 'mes_pasado'
    if has('ingreso', 'recaudacion', 'ventas', 'dinero', 'monto', 'gano', 'recaudo'):
        if has('semana'): return 'ingresos_semana'
        return 'ingresos_mes' if has('mes', 'mensual', 'este mes') else 'ingresos_general'
    if has('conductor', 'chofer') and has('top', 'ranking', 'mas viajes', 'mejores'): return 'top_conductores'
    if has('autobus', 'unidad') and has('top', 'ranking', 'mas viajes'):              return 'top_autobuses'
    if has('ruta') and has('popular', 'top', 'boleto', 'mas'):                        return 'rutas_populares'
    if has('pasajero') and has('frecuente', 'top', 'ranking'):                        return 'top_pasajeros'
    if has('en ruta', 'circulando', 'actualmente') or (has('ahora') and not has('cuanto')):
        return 'en_ruta'
    if has('hoy', 'viaje hoy', 'salida hoy'):                 return 'viajes_hoy'
    if has('manana') and has('viaje', 'salida'):               return 'viajes_manana'
    if (has('proxima semana', 'proximos') or has('semana')) and has('viaje', 'salida', 'asiento'):
        return 'proxima_semana'
    if has('cancelado', 'suspendido'):                        return 'cancelados'
    if has('retrasado', 'retraso'):                           return 'retrasados'
    if has('boleto', 'ticket') and has('vendido', 'total', 'emitido'):
        if has('mes', 'este mes', 'mensual'): return 'boletos_mes'
        return 'boletos_general'
    if has('resumen', 'general', 'estado actual'):            return 'resumen'
    if has('terminal', 'sucursal'):                           return 'terminales'
    if has('ocupacion', 'capacidad', 'asiento libre'):        return 'ocupacion'
    if has('ruta') and not has('popular', 'top'):             return 'rutas_lista'
    if has('conductor', 'chofer'):                            return 'conductores_lista'
    if has('autobus', 'flota'):                               return 'autobuses_lista'
    if has('pasajero', 'cliente'):                            return 'pasajeros_lista'
    for mes, num in [('enero','01'),('febrero','02'),('marzo','03'),('abril','04'),
                     ('mayo','05'),('junio','06'),('julio','07'),('agosto','08'),
                     ('septiembre','09'),('octubre','10'),('noviembre','11'),('diciembre','12')]:
        if mes in q: return 'mes_%s' % num
    return 'ai'


def _resolve(intent, pregunta):

    if intent == 'resumen':
        _, r1 = _q("SELECT COUNT(*) AS n FROM viaje WHERE DATE(fecHoraSalida) = CURDATE()")
        _, r2 = _q("SELECT COUNT(*) AS n FROM viaje WHERE estado = 2")
        _, r3 = _q("SELECT COUNT(*) AS n FROM viaje WHERE estado = 1 AND fecHoraSalida >= NOW()")
        _, r4 = _q("SELECT COUNT(*) AS n FROM ticket WHERE DATE(fechaEmision) = CURDATE()")
        _, r5 = _q("SELECT COALESCE(SUM(monto), 0) AS n FROM pago WHERE DATE(fechapago) = CURDATE()")
        _, r6 = _q("SELECT COUNT(*) AS n FROM viaje WHERE MONTH(fecHoraSalida)=MONTH(CURDATE()) AND YEAR(fecHoraSalida)=YEAR(CURDATE())")
        cards = _cards([
            {'label':'Viajes hoy',      'val':r1[0]['n'], 'sub':'programados'},
            {'label':'En ruta ahora',   'val':r2[0]['n'], 'sub':'circulando'},
            {'label':'Disponibles',     'val':r3[0]['n'], 'sub':'venta abierta'},
            {'label':'Boletos hoy',     'val':r4[0]['n'], 'sub':'emitidos'},
            {'label':'Ingresos hoy',    'val':_pesos(r5[0]['n']), 'sub':'en caja'},
            {'label':'Viajes este mes', 'val':r6[0]['n'], 'sub':'programados'},
        ])
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS Salida, a.placas AS Autobus,"
            " CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " WHERE v.estado=2 ORDER BY v.fecHoraSalida"
        )
        tabla = _tabla(cols, rows) if rows else '<em>Ningun viaje en ruta ahora mismo.</em>'
        return '<p><strong>Resumen general RBE:</strong></p>%s<hr><p><strong>Viajes en ruta:</strong></p>%s' % (cards, tabla)

    if intent == 'en_ruta':
        cols, rows = _q(
            "SELECT v.numero AS Viaje, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS Salida, v.fecHoraEntrada AS LlegadaEst,"
            " a.placas AS Autobus, CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor,"
            " COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE v.estado=2 GROUP BY v.numero ORDER BY v.fecHoraSalida"
        )
        if not rows: return '<p>No hay viajes en ruta en este momento.</p>'
        return '<p><strong>Viajes actualmente en ruta:</strong></p>%s%s' % (
            _cards([{'label':'En ruta','val':len(rows),'sub':'autobuses'}]), _tabla(cols, rows))

    if intent == 'viajes_hoy':
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " TIME(v.fecHoraSalida) AS Hora, ev.nombre AS Estado,"
            " a.placas AS Autobus, CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " WHERE DATE(v.fecHoraSalida)=CURDATE() ORDER BY v.fecHoraSalida"
        )
        if not rows: return '<p>No hay viajes programados para hoy.</p>'
        return '<p><strong>Viajes de hoy:</strong></p>%s%s' % (
            _cards([{'label':'Hoy','val':len(rows),'sub':'viajes'}]),
            _tabla(cols, rows, est=['Estado']))

    if intent == 'proxima_semana':
        cols, rows = _q(
            "SELECT v.numero AS Num, DATE(v.fecHoraSalida) AS Fecha,"
            " TIME(v.fecHoraSalida) AS Hora, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " ev.nombre AS Estado,"
            " (mo.numasientos - COUNT(va.asiento)) AS AsientosLibres, a.placas AS Autobus"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN modelo mo ON a.modelo=mo.numero"
            " LEFT JOIN viaje_asiento va ON va.viaje=v.numero AND va.ocupado=1"
            " WHERE v.fecHoraSalida BETWEEN NOW() AND DATE_ADD(NOW(),INTERVAL 7 DAY)"
            " AND v.estado NOT IN (3,4)"
            " GROUP BY v.numero ORDER BY v.fecHoraSalida LIMIT 40"
        )
        if not rows: return '<p>No hay viajes en los proximos 7 dias.</p>'
        return '<p><strong>Proximos 7 dias:</strong></p>%s%s' % (
            _cards([{'label':'7 dias','val':len(rows),'sub':'viajes'}]),
            _tabla(cols, rows, est=['Estado']))

    if intent == 'rutas_populares':
        cols, rows = _q(
            "SELECT CONCAT(co.nombre,' a ',cd.nombre) AS Ruta, r.precio AS Precio,"
            " COUNT(t.codigo) AS Boletos, COUNT(DISTINCT t.viaje) AS Viajes,"
            " ROUND(COUNT(t.codigo)/NULLIF(COUNT(DISTINCT t.viaje),0),1) AS PaxPorViaje"
            " FROM ticket t JOIN viaje v ON v.numero=t.viaje JOIN ruta r ON r.codigo=v.ruta"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " GROUP BY r.codigo ORDER BY Boletos DESC LIMIT 15"
        )
        return '<p><strong>Rutas mas populares:</strong></p>%s' % _tabla(cols, rows, pesos=['Precio'])

    if intent == 'top_conductores':
        cols, rows = _q(
            "SELECT CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor,"
            " COUNT(v.numero) AS Viajes, COUNT(t.codigo) AS PasajerosTotal"
            " FROM conductor c"
            " LEFT JOIN viaje v ON v.conductor=c.registro"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " GROUP BY c.registro ORDER BY Viajes DESC LIMIT 12"
        )
        return '<p><strong>Ranking de conductores:</strong></p>%s' % _tabla(cols, rows)

    if intent == 'top_autobuses':
        cols, rows = _q(
            "SELECT a.numero AS Num, a.placas AS Placas, m.nombre AS Marca,"
            " mo.nombre AS Modelo, mo.numasientos AS Asientos,"
            " COUNT(v.numero) AS Viajes, COUNT(t.codigo) AS PasajerosTotal"
            " FROM autobus a JOIN modelo mo ON a.modelo=mo.numero JOIN marca m ON mo.marca=m.numero"
            " LEFT JOIN viaje v ON v.autobus=a.numero"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " GROUP BY a.numero ORDER BY Viajes DESC LIMIT 10"
        )
        return '<p><strong>Autobuses con mas viajes:</strong></p>%s' % _tabla(cols, rows)

    if intent == 'ingresos_mes':
        _, tots = _q(
            "SELECT COUNT(*) AS pagos, SUM(monto) AS total,"
            " COUNT(DISTINCT DATE(fechapago)) AS dias FROM pago"
            " WHERE MONTH(fechapago)=MONTH(CURDATE()) AND YEAR(fechapago)=YEAR(CURDATE())"
        )
        t = tots[0]
        cols, rows = _q(
            "SELECT DATE(p.fechapago) AS Fecha, tp.nombre AS Metodo,"
            " COUNT(p.numero) AS Pagos, SUM(p.monto) AS Total"
            " FROM pago p JOIN tipo_pago tp ON tp.numero=p.tipo"
            " WHERE MONTH(p.fechapago)=MONTH(CURDATE()) AND YEAR(p.fechapago)=YEAR(CURDATE())"
            " GROUP BY DATE(p.fechapago), tp.nombre ORDER BY Fecha"
        )
        cards = _cards([
            {'label':'Ingresos mes', 'val':_pesos(t['total']), 'sub':'acumulados'},
            {'label':'Transacciones','val':t['pagos'],         'sub':'pagos'},
            {'label':'Dias activos', 'val':t['dias'],          'sub':'con ventas'},
        ])
        return '<p><strong>Ingresos del mes:</strong></p>%s%s' % (cards, _tabla(cols, rows, pesos=['Total']))

    if intent == 'ingresos_general':
        cols, rows = _q(
            "SELECT YEAR(fechapago) AS Anio, MONTH(fechapago) AS Mes,"
            " COUNT(*) AS Transacciones, SUM(monto) AS Total"
            " FROM pago GROUP BY YEAR(fechapago), MONTH(fechapago)"
            " ORDER BY Anio DESC, Mes DESC LIMIT 12"
        )
        return '<p><strong>Historial de ingresos:</strong></p>%s' % _tabla(cols, rows, pesos=['Total'])

    if intent == 'boletos_mes':
        _, tots = _q(
            "SELECT COUNT(*) AS total, SUM(precio) AS ingresos,"
            " COUNT(DISTINCT viaje) AS viajes FROM ticket"
            " WHERE MONTH(fechaEmision)=MONTH(CURDATE()) AND YEAR(fechaEmision)=YEAR(CURDATE())"
        )
        t = tots[0]
        cols, rows = _q(
            "SELECT CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " COUNT(tk.codigo) AS Boletos, SUM(tk.precio) AS Ingresos"
            " FROM ticket tk JOIN viaje v ON v.numero=tk.viaje JOIN ruta r ON r.codigo=v.ruta"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " WHERE MONTH(tk.fechaEmision)=MONTH(CURDATE()) AND YEAR(tk.fechaEmision)=YEAR(CURDATE())"
            " GROUP BY r.codigo ORDER BY Boletos DESC LIMIT 10"
        )
        cards = _cards([
            {'label':'Boletos vendidos','val':t['total'],            'sub':'este mes'},
            {'label':'Ingresos',        'val':_pesos(t['ingresos']), 'sub':'en boletos'},
            {'label':'Viajes con venta','val':t['viajes'],           'sub':'viajes'},
        ])
        return '<p><strong>Boletos este mes:</strong></p>%s%s' % (cards, _tabla(cols, rows, pesos=['Ingresos']))

    if intent == 'boletos_general':
        cols, rows = _q(
            "SELECT YEAR(fechaEmision) AS Anio, MONTH(fechaEmision) AS Mes,"
            " COUNT(*) AS Boletos, SUM(precio) AS Ingresos FROM ticket"
            " GROUP BY YEAR(fechaEmision), MONTH(fechaEmision)"
            " ORDER BY Anio DESC, Mes DESC LIMIT 12"
        )
        return '<p><strong>Historico de boletos:</strong></p>%s' % _tabla(cols, rows, pesos=['Ingresos'])

    if intent == 'terminales':
        cols, rows = _q(
            "SELECT t.nombre AS Terminal, ci.nombre AS Ciudad,"
            " t.dirCalle AS Calle, t.dirNumero AS Num, t.telefono AS Telefono,"
            " COUNT(DISTINCT taq.registro) AS Taquilleros"
            " FROM terminal t JOIN ciudad ci ON ci.clave=t.ciudad"
            " LEFT JOIN taquillero taq ON taq.terminal=t.numero"
            " GROUP BY t.numero ORDER BY ci.nombre"
        )
        return '<p><strong>Terminales:</strong></p>%s' % _tabla(cols, rows)

    if intent == 'ocupacion':
        cols, rows = _q(
            "SELECT v.numero AS Viaje, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " DATE(v.fecHoraSalida) AS Fecha, ev.nombre AS Estado,"
            " mo.numasientos AS Capacidad, COUNT(va.asiento) AS Ocupados,"
            " ROUND(COUNT(va.asiento)*100.0/NULLIF(mo.numasientos,0),1) AS PctOcup"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN autobus a ON v.autobus=a.nombre"
            " LEFT JOIN modelo mo ON a.modelo=mo.numero"
            " LEFT JOIN viaje_asiento va ON va.viaje=v.numero AND va.ocupado=1"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(),INTERVAL 14 DAY)"
            " GROUP BY v.numero ORDER BY PctOcup DESC LIMIT 20"
        )
        return '<p><strong>Ocupacion ultimos 14 dias:</strong></p>%s' % _tabla(cols, rows, est=['Estado'])

    if intent == 'rutas_lista':
        cols, rows = _q(
            "SELECT r.codigo AS Cod, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " r.duracion AS Duracion, r.precio AS Precio"
            " FROM ruta r"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " ORDER BY r.precio"
        )
        return '<p><strong>Rutas disponibles:</strong></p>%s' % _tabla(cols, rows, pesos=['Precio'])

    if intent == 'conductores_lista':
        cols, rows = _q(
            "SELECT c.registro AS Reg, CONCAT(c.conNombre,' ',c.conPrimerApell) AS Nombre,"
            " c.licNumero AS Licencia, c.licVencimiento AS VenceLic, c.fechaContrato AS Contrato"
            " FROM conductor c ORDER BY c.conNombre"
        )
        return '<p><strong>Conductores registrados:</strong></p>%s' % _tabla(cols, rows)

    if intent == 'autobuses_lista':
        cols, rows = _q(
            "SELECT a.numero AS Num, a.placas AS Placas, m.nombre AS Marca,"
            " mo.nombre AS Modelo, mo.ano AS Anio, mo.numasientos AS Asientos"
            " FROM autobus a JOIN modelo mo ON a.modelo=mo.numero JOIN marca m ON mo.marca=m.numero"
            " ORDER BY a.numero"
        )
        return '<p><strong>Flota de autobuses:</strong></p>%s' % _tabla(cols, rows)

    if intent == 'pasajeros_lista':
        cols, rows = _q(
            "SELECT p.num AS Num, CONCAT(p.paNombre,' ',p.paPrimerApell) AS Nombre,"
            " TIMESTAMPDIFF(YEAR,p.fechaNacimiento,CURDATE()) AS Edad,"
            " p.fechaNacimiento AS Nacimiento"
            " FROM pasajero p ORDER BY p.paNombre LIMIT 50"
        )
        return '<p><strong>Pasajeros (primeros 50):</strong></p>%s' % _tabla(cols, rows)

    if intent == 'top_pasajeros':
        cols, rows = _q(
            "SELECT CONCAT(p.paNombre,' ',p.paPrimerApell) AS Pasajero,"
            " COUNT(t.codigo) AS Boletos, SUM(t.precio) AS GastoTotal"
            " FROM pasajero p JOIN ticket t ON t.pasajero=p.num"
            " GROUP BY p.num ORDER BY Boletos DESC LIMIT 10"
        )
        return '<p><strong>Pasajeros mas frecuentes:</strong></p>%s' % _tabla(cols, rows, pesos=['GastoTotal'])

    if intent == 'cancelados':
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS FechaProg, a.placas AS Autobus"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " WHERE v.estado=4 ORDER BY v.fecHoraSalida DESC LIMIT 20"
        )
        if not rows: return '<p>No hay viajes cancelados.</p>'
        return '<p><strong>Viajes cancelados:</strong></p>%s' % _tabla(cols, rows)

    if intent == 'retrasados':
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS SalidaProg, a.placas AS Autobus"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " WHERE v.estado=5 ORDER BY v.fecHoraSalida DESC LIMIT 20"
        )
        if not rows: return '<p>No hay viajes retrasados.</p>'
        return '<p><strong>Viajes retrasados:</strong></p>%s' % _tabla(cols, rows)

    mm = re.match(r'mes_(\d{2})', intent)
    if mm:
        mn = int(mm.group(1))
        nombres = {1:'enero',2:'febrero',3:'marzo',4:'abril',5:'mayo',6:'junio',
                   7:'julio',8:'agosto',9:'septiembre',10:'octubre',11:'noviembre',12:'diciembre'}
        nom = nombres.get(mn, str(mn))
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS Salida, ev.nombre AS Estado, COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE MONTH(v.fecHoraSalida)=%s AND YEAR(v.fecHoraSalida)=2026"
            " GROUP BY v.numero ORDER BY v.fecHoraSalida",
            [mn]
        )
        if not rows: return '<p>No hay viajes para %s 2026.</p>' % nom
        return '<p><strong>Viajes de %s 2026:</strong></p>%s%s' % (
            nom,
            _cards([{'label': nom.capitalize(), 'val': len(rows), 'sub': 'viajes'}]),
            _tabla(cols, rows, est=['Estado']))

    if intent == 'ayer':
        from datetime import date, timedelta
        ayer = (date.today() - timedelta(days=1)).isoformat()
        _, r1 = _q("SELECT COUNT(*) AS n FROM viaje WHERE DATE(fecHoraSalida)=%s", [ayer])
        _, r2 = _q("SELECT COUNT(*) AS n FROM ticket WHERE DATE(fechaEmision)=%s", [ayer])
        _, r3 = _q("SELECT COALESCE(SUM(monto),0) AS n FROM pago WHERE DATE(fechapago)=%s", [ayer])
        cards = _cards([
            {'label':'Viajes ayer',   'val':r1[0]['n'],        'sub':ayer},
            {'label':'Boletos',       'val':r2[0]['n'],        'sub':'vendidos'},
            {'label':'Ingresos',      'val':_pesos(r3[0]['n']),'sub':'recaudados'},
        ])
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " TIME(v.fecHoraSalida) AS Hora, ev.nombre AS Estado,"
            " COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE DATE(v.fecHoraSalida)=%s"
            " GROUP BY v.numero ORDER BY v.fecHoraSalida",
            [ayer]
        )
        if not rows: return '<p><strong>Ayer (%s):</strong></p>%s<p>No hubo viajes registrados.</p>' % (ayer, cards)
        return '<p><strong>Resumen de ayer (%s):</strong></p>%s%s' % (ayer, cards, _tabla(cols, rows, est=['Estado']))

    if intent == 'viajes_manana':
        from datetime import date, timedelta
        manana = (date.today() + timedelta(days=1)).isoformat()
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " TIME(v.fecHoraSalida) AS Hora, ev.nombre AS Estado,"
            " a.placas AS Autobus, CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " WHERE DATE(v.fecHoraSalida)=%s ORDER BY v.fecHoraSalida",
            [manana]
        )
        if not rows: return '<p>No hay viajes programados para manana (%s).</p>' % manana
        return '<p><strong>Viajes de manana (%s):</strong></p>%s%s' % (
            manana,
            _cards([{'label':'Manana','val':len(rows),'sub':'viajes programados'}]),
            _tabla(cols, rows, est=['Estado']))

    if intent == 'semana_pasada':
        from datetime import date, timedelta
        hoy = date.today()
        ini = (hoy - timedelta(days=hoy.weekday()+7)).isoformat()
        fin = (hoy - timedelta(days=hoy.weekday()+1)).isoformat()
        _, r1 = _q("SELECT COUNT(*) AS n FROM viaje WHERE DATE(fecHoraSalida) BETWEEN %s AND %s", [ini, fin])
        _, r2 = _q("SELECT COUNT(*) AS n FROM ticket WHERE DATE(fechaEmision) BETWEEN %s AND %s", [ini, fin])
        _, r3 = _q("SELECT COALESCE(SUM(monto),0) AS n FROM pago WHERE DATE(fechapago) BETWEEN %s AND %s", [ini, fin])
        cards = _cards([
            {'label':'Viajes',   'val':r1[0]['n'],        'sub':'semana pasada'},
            {'label':'Boletos',  'val':r2[0]['n'],        'sub':'vendidos'},
            {'label':'Ingresos', 'val':_pesos(r3[0]['n']),'sub':'recaudados'},
        ])
        cols, rows = _q(
            "SELECT DATE(v.fecHoraSalida) AS Fecha, COUNT(v.numero) AS Viajes,"
            " COUNT(t.codigo) AS Boletos, SUM(p.monto) AS Ingresos"
            " FROM viaje v"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s"
            " GROUP BY DATE(v.fecHoraSalida) ORDER BY Fecha",
            [ini, fin]
        )
        return '<p><strong>Semana pasada (%s al %s):</strong></p>%s%s' % (ini, fin, cards, _tabla(cols, rows, pesos=['Ingresos']))

    if intent == 'mes_pasado':
        from datetime import date
        hoy = date.today()
        if hoy.month == 1:
            anio, mes = hoy.year - 1, 12
        else:
            anio, mes = hoy.year, hoy.month - 1
        nombres = {1:'enero',2:'febrero',3:'marzo',4:'abril',5:'mayo',6:'junio',
                   7:'julio',8:'agosto',9:'septiembre',10:'octubre',11:'noviembre',12:'diciembre'}
        nom = nombres[mes]
        _, r1 = _q("SELECT COUNT(*) AS n FROM viaje WHERE MONTH(fecHoraSalida)=%s AND YEAR(fecHoraSalida)=%s", [mes, anio])
        _, r2 = _q("SELECT COUNT(*) AS n FROM ticket WHERE MONTH(fechaEmision)=%s AND YEAR(fechaEmision)=%s", [mes, anio])
        _, r3 = _q("SELECT COALESCE(SUM(monto),0) AS n FROM pago WHERE MONTH(fechapago)=%s AND YEAR(fechapago)=%s", [mes, anio])
        cards = _cards([
            {'label':'Viajes',   'val':r1[0]['n'],        'sub':'%s %s' % (nom, anio)},
            {'label':'Boletos',  'val':r2[0]['n'],        'sub':'vendidos'},
            {'label':'Ingresos', 'val':_pesos(r3[0]['n']),'sub':'recaudados'},
        ])
        cols, rows = _q(
            "SELECT CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " COUNT(v.numero) AS Viajes, COUNT(t.codigo) AS Boletos"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE MONTH(v.fecHoraSalida)=%s AND YEAR(v.fecHoraSalida)=%s"
            " GROUP BY r.codigo ORDER BY Viajes DESC LIMIT 10",
            [mes, anio]
        )
        return '<p><strong>Mes pasado — %s %s:</strong></p>%s%s' % (nom, anio, cards, _tabla(cols, rows))

    if intent == 'ultimos_7':
        cols, rows = _q(
            "SELECT DATE(v.fecHoraSalida) AS Fecha, COUNT(v.numero) AS Viajes,"
            " COUNT(t.codigo) AS Boletos, COALESCE(SUM(p.monto),0) AS Ingresos"
            " FROM viaje v"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)"
            " GROUP BY DATE(v.fecHoraSalida) ORDER BY Fecha"
        )
        return '<p><strong>Ultimos 7 dias:</strong></p>%s' % _tabla(cols, rows, pesos=['Ingresos'])

    if intent == 'ultimos_30':
        _, tots = _q(
            "SELECT COUNT(DISTINCT v.numero) AS viajes, COUNT(t.codigo) AS boletos,"
            " COALESCE(SUM(p.monto),0) AS ingresos"
            " FROM viaje v"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)"
        )
        tt = tots[0]
        cols, rows = _q(
            "SELECT DATE(v.fecHoraSalida) AS Fecha, COUNT(v.numero) AS Viajes,"
            " COUNT(t.codigo) AS Boletos, COALESCE(SUM(p.monto),0) AS Ingresos"
            " FROM viaje v"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)"
            " GROUP BY DATE(v.fecHoraSalida) ORDER BY Fecha"
        )
        cards = _cards([
            {'label':'Viajes',   'val':tt['viajes'],          'sub':'ultimos 30 dias'},
            {'label':'Boletos',  'val':tt['boletos'],         'sub':'vendidos'},
            {'label':'Ingresos', 'val':_pesos(tt['ingresos']),'sub':'recaudados'},
        ])
        return '<p><strong>Ultimos 30 dias:</strong></p>%s%s' % (cards, _tabla(cols, rows, pesos=['Ingresos']))

    if intent == 'ingresos_semana':
        from datetime import date, timedelta
        hoy = date.today()
        ini = (hoy - timedelta(days=hoy.weekday())).isoformat()
        cols, rows = _q(
            "SELECT DATE(p.fechapago) AS Fecha, tp.nombre AS Metodo,"
            " COUNT(p.numero) AS Pagos, SUM(p.monto) AS Total"
            " FROM pago p JOIN tipo_pago tp ON tp.numero=p.tipo"
            " WHERE DATE(p.fechapago) >= %s"
            " GROUP BY DATE(p.fechapago), tp.nombre ORDER BY Fecha",
            [ini]
        )
        _, tots = _q("SELECT COALESCE(SUM(monto),0) AS n FROM pago WHERE DATE(fechapago) >= %s", [ini])
        cards = _cards([{'label':'Ingresos semana','val':_pesos(tots[0]['n']),'sub':'desde el lunes'}])
        return '<p><strong>Ingresos esta semana:</strong></p>%s%s' % (cards, _tabla(cols, rows, pesos=['Total']))

    return None  # → AI con SQL dinámico


def _texto_a_html(text):
    lines = text.split('\n')
    parts = []; in_ul = False
    for line in lines:
        line = line.strip()
        if not line:
            if in_ul: parts.append('</ul>'); in_ul = False
            continue
        if line.startswith('- ') or line.startswith('* '):
            if not in_ul: parts.append('<ul>'); in_ul = True
            parts.append('<li>%s</li>' % line[2:])
        else:
            if in_ul: parts.append('</ul>'); in_ul = False
            line = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', line)
            parts.append('<p>%s</p>' % line)
    if in_ul: parts.append('</ul>')
    return ''.join(parts)


def _llamar_groq(system, user_msg, modelo_id, max_tokens=800, temperature=0.1):
    """Llamada genérica a Groq."""
    api_key = os.getenv('GROQ_API_KEY', '')
    if not api_key:
        return None, 'No hay API key de Groq configurada.'

    url = 'https://api.groq.com/openai/v1/chat/completions'
    payload = json.dumps({
        'model': modelo_id,
        'max_tokens': max_tokens,
        'temperature': temperature,
        'messages': [
            {'role': 'system', 'content': system},
            {'role': 'user',   'content': user_msg},
        ]
    }).encode('utf-8')

    req = urllib.request.Request(
        url, data=payload,
        headers={
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + api_key,
            'User-Agent': 'Mozilla/5.0 (compatible; RBE-Elipse/1.0)',
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            data = json.loads(res.read().decode('utf-8'))
            return data['choices'][0]['message']['content'].strip(), None
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='ignore')
        return None, 'Error Groq %s: %s' % (e.code, body[:200])
    except Exception as e:
        return None, 'Error: %s' % str(e)


def _ai_con_sql(pregunta, modelo_key):
    """
    Modo IA avanzado:
    1. Pide a la IA que genere un SQL para la pregunta
    2. Ejecuta el SQL contra la BD real
    3. Pide a la IA que interprete los resultados en lenguaje natural
    """
    modelo_id = MODELOS_IA.get(modelo_key, MODELOS_IA[MODELO_DEFAULT])['id']

    # ── Paso 1: Generar SQL ──────────────────────────────────
    sql_raw, err = _llamar_groq(SQL_SYSTEM_PROMPT, pregunta, modelo_id, max_tokens=400, temperature=0.0)
    if err:
        return '<p class="msg-error">%s</p>' % err

    sql_raw = sql_raw.strip()
    # Limpiar posibles backticks de markdown
    sql_raw = re.sub(r'^```sql\s*', '', sql_raw, flags=re.IGNORECASE)
    sql_raw = re.sub(r'^```\s*', '', sql_raw)
    sql_raw = re.sub(r'```$', '', sql_raw).strip()

    # Si la IA dice que no puede resolverlo con SQL
    if sql_raw.upper().startswith('NO_SQL') or not sql_raw.upper().startswith('SELECT'):
        # Fallback: respuesta conversacional sin BD
        resp, err2 = _llamar_groq(SYSTEM_PROMPT, pregunta, modelo_id, max_tokens=600, temperature=0.3)
        if err2:
            return '<p class="msg-error">%s</p>' % err2
        return _texto_a_html(resp)

    # ── Paso 2: Ejecutar SQL ─────────────────────────────────
    try:
        cols, rows = _q(sql_raw)
    except Exception as e:
        # Si el SQL falla, intentar respuesta conversacional
        resp, _ = _llamar_groq(SYSTEM_PROMPT, pregunta, modelo_id, max_tokens=600, temperature=0.3)
        return (
            '<details style="margin-bottom:8px;font-size:11px;color:var(--muted)">'
            '<summary>SQL generado (con error)</summary>'
            '<code style="display:block;padding:6px;background:#f8f9fa;border-radius:6px;white-space:pre-wrap">%s</code>'
            '<p style="color:var(--danger)">Error: %s</p>'
            '</details>%s' % (sql_raw, str(e), _texto_a_html(resp) if resp else '')
        )

    # ── Paso 3: Interpretar resultados ───────────────────────
    SYSTEM_ADMIN = (
        SYSTEM_PROMPT +
        "\n\nIMPORTANTE: Eres un asistente para el PANEL DE ADMINISTRACION INTERNO de RBE. "
        "Tienes acceso completo a todos los datos de la BD. "
        "NUNCA digas 'no tengo acceso', 'no tengo informacion' ni 'no puedo acceder'. "
        "Los datos ya estan disponibles — respondelos directamente."
    )
    if not rows:
        interpretacion, _ = _llamar_groq(
            SYSTEM_ADMIN,
            'El usuario pregunto: "%s"\n'
            'Consulte la base de datos y no encontre ningun resultado. '
            'Responde en UNA oracion corta diciendo que no existe ese registro.' % pregunta,
            modelo_id, max_tokens=120, temperature=0.1
        )
        tabla_html = '<em>Sin resultados en la base de datos.</em>'
    else:
        muestra = rows[:20]
        datos_str = json.dumps(muestra, ensure_ascii=False, default=str)
        total_str = ' (%d registros en total)' % len(rows) if len(rows) > 20 else ' (%d registros)' % len(rows)
        interpretacion, _ = _llamar_groq(
            SYSTEM_ADMIN,
            'El usuario pregunto: "%s"\n'
            'Datos reales de la BD%s:\n%s\n\n'
            'Responde la pregunta DIRECTAMENTE usando estos datos especificos. '
            'Menciona los valores exactos (nombres, numeros, fechas) que encontraste. '
            'No digas que no tienes acceso. No menciones JSON ni consultas.' % (pregunta, total_str, datos_str),
            modelo_id, max_tokens=500, temperature=0.2
        )
        tabla_html = _tabla(cols, rows)

    # Construir respuesta final con tabla + interpretación
    partes = []
    if interpretacion:
        partes.append(_texto_a_html(interpretacion))
    if rows:
        partes.append('<details style="margin-top:10px"><summary style="cursor:pointer;font-size:12px;color:var(--muted)">Ver tabla completa (%d filas)</summary>%s</details>' % (len(rows), tabla_html))

    return ''.join(partes) if partes else tabla_html


@login_requerido
def elipse_chat(request):
    try:
        body     = json.loads(request.body)
        pregunta = body.get('pregunta', '').strip()
        modelo_k = body.get('modelo', MODELO_DEFAULT)

        if not pregunta:
            return JsonResponse({'error': 'Escribe una pregunta.'})
        if modelo_k not in MODELOS_IA:
            modelo_k = MODELO_DEFAULT

        intent = _intent(pregunta)
        html   = _resolve(intent, pregunta)

        if html is None:
            # Modo AI con generación de SQL dinámico
            html = _ai_con_sql(pregunta, modelo_k)

        return JsonResponse({
            'html':   html,
            'intent': intent,
            'modelo': MODELOS_IA[modelo_k]['label'],
        })
    except Exception as e:
        return JsonResponse({'error': 'Error interno: %s' % str(e)}, status=500)