"""
elipse_views.py - Asistente Elipse para RBE  v2.0
SQL limpio compatible con MySQL 8 / MariaDB

MEJORAS v2 (según documento de pruebas de la administradora):
  New #01 - Viajes programados futuros / por fecha específica (con mensaje claro si no hay)
  New #02 - Top N conductores con más viajes (detecta número: top 5, top 3, etc.)
  New #03 - Top N autobuses con más viajes (ídem)
  New #04 - Información libre: qué puede hacer Elipse → respuesta sin necesitar API key
  New #05 - Respuesta clara ante peticiones de borrar/modificar/crear datos (no solo error)
  New #06 - Ingresos por año específico / año pasado / diciembre del año pasado
  New #07 - Viaje específico por número (#40, viaje 40, número 40)
  New #08 - Pasajeros de un viaje específico (con mensaje si no hay)
  New #09 - Autobuses sin asignar / sin viajes recientes (semanas sin usar)
  New #10 - Ingresos/boletos vendidos HOY con detalle
  New #11 - Boletos vendidos en fecha específica (1 de marzo, etc.)
  New #12 - Conductor de un viaje específico
  New #13 - Viajes realizados por un conductor específico (por nombre)
  New #14 - Terminal con más taquilleros
  New #15 - Taquillero con más boletos vendidos
  New #16 - Camiones disponibles (sin viaje asignado futuro)
  New #17 - Información de RBE (empresa)
  New #18 - Soporte para SQL puro: si el usuario escribe SELECT ... se ejecuta directo
  Fix #19 - ingresos_general ahora filtra correctamente por año específico
  Fix #20 - conductores_lista ahora detecta nombre específico y muestra sus viajes
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

# ── Palabras que indican intención de MODIFICAR la BD ─────
PALABRAS_MODIFICAR = [
    'borra', 'borrar', 'elimina', 'eliminar', 'delete', 'drop',
    'modifica', 'modificar', 'actualiza', 'actualizar', 'update',
    'cambia', 'cambiar', 'crea', 'crear', 'insert', 'añade', 'añadir',
    'agrega', 'agregar', 'registra', 'registrar', 'truncate', 'alter',
    'podrias borrar', 'puedes borrar', 'podrias eliminar', 'puedes eliminar',
]

# ── Info institucional de RBE ─────────────────────────────
INFO_RBE = """
<p><strong>🚌 Rutas Baja Express (RBE)</strong></p>
<p>Empresa de transporte terrestre con sede en Baja California, México. Opera rutas entre
las principales ciudades de la península: <strong>Tijuana, Mexicali, Ensenada, Rosarito,
Tecate, San Quintín y San Felipe</strong>.</p>
<ul>
  <li><strong>Flota:</strong> autobuses de marcas Irizar, Volvo, Scania, MAN y Mercedes-Benz.</li>
  <li><strong>Terminales:</strong> 7 terminales en toda Baja California.</li>
  <li><strong>Servicios:</strong> venta de boletos en taquilla, conductores certificados y seguimiento de viajes en tiempo real.</li>
</ul>
<p><strong>Elipse</strong> es el asistente de inteligencia artificial interno de RBE.
Puede responder consultas sobre viajes, rutas, pasajeros, conductores, autobuses,
ingresos, terminales y taquilleros directamente desde la base de datos del sistema.</p>
"""

# ── Mensaje de capacidades ────────────────────────────────
CAPACIDADES = """
<p><strong>🤖 ¿Qué puedo hacer yo, Elipse?</strong></p>
<p>Soy el asistente IA de RBE. Puedo responder preguntas en lenguaje natural o ejecutar
SQL directamente. Aquí algunos ejemplos de lo que puedo hacer:</p>
<ul>
  <li>📅 <em>"Viajes programados para mañana"</em> — viajes futuros por fecha</li>
  <li>🚌 <em>"Autobuses sin asignar esta semana"</em> — flota ociosa</li>
  <li>👤 <em>"Pasajeros del viaje #40"</em> — detalle de un viaje específico</li>
  <li>🏆 <em>"Top 5 conductores con más viajes"</em> — rankings con límite</li>
  <li>💰 <em>"Ingresos del año 2025"</em> — histórico por año</li>
  <li>🎫 <em>"Cuántos boletos se vendieron el 1 de marzo"</em> — ventas por fecha</li>
  <li>🔍 <em>"Viajes realizados por Marco Hernández"</em> — historial de conductor</li>
  <li>🏢 <em>"Qué terminal tiene más taquilleros"</em> — estadísticas de terminales</li>
  <li>📊 <em>"Qué taquillero ha vendido más boletos"</em> — ranking de ventas</li>
  <li>💻 También puedo ejecutar <strong>SQL puro</strong>: escribe <code>SELECT ...</code> y lo corro directo</li>
</ul>
<p style="color:var(--muted);font-size:12px;">
  ⚠️ Solo puedo <strong>consultar</strong> datos. No puedo insertar, modificar ni eliminar registros.
</p>
"""

# ── Schema completo de la BD ──────────────────────────────
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
- taquillero(registro PK, taqnombre, taqprimerapell, taqsegundoapell, usuario, contrasena, terminal INT FK, supervisa INT)
- tipo_pasajero(numero PK, nombre, descuento)

JOINS IMPORTANTES:
- viaje.ruta -> ruta.codigo
- ruta.origen -> terminal.numero, ruta.destino -> terminal.numero
- terminal.ciudad -> ciudad.clave
- viaje.autobus -> autobus.numero   ← SIEMPRE usar autobus.numero (nunca autobus.nombre)
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
    "Este es un panel de administracion INTERNO. Genera UNA SOLA consulta SQL SELECT.\n\n"
    "REGLAS ABSOLUTAS:\n"
    "1. Devuelve UNICAMENTE el SQL puro. Sin explicaciones, sin markdown, sin ```.\n"
    "2. Solo SELECT. Jamas INSERT/UPDATE/DELETE/DROP/TRUNCATE.\n"
    "3. LIMIT 100 maximo.\n"
    "4. Alias de columnas en espanol descriptivo.\n"
    "5. NO_SQL si la pregunta es completamente ajena a la BD.\n"
    "6. Nombres completos: CONCAT(campo_nombre,' ',campo_apellido1,' ',campo_apellido2).\n"
    "7. Fechas relativas: CURDATE(), NOW(), DATE_SUB(), DATE_ADD(), INTERVAL.\n"
    "8. Busquedas por nombre: LOWER(campo) LIKE LOWER('%texto%').\n"
    "9. NUNCA COUNT(*) si el usuario quiere ver registros.\n"
    "10. CRITICO: JOIN con autobus SIEMPRE 'ON v.autobus = a.numero' (NUNCA a.nombre).\n"
    "11. Para autobuses sin asignar recientemente: busca autobuses cuyo ultimo viaje "
    "sea NULL o anterior a DATE_SUB(CURDATE(), INTERVAL X DAY).\n"
    "12. Para viajes de conductor especifico: JOIN viaje v ON c.registro = v.conductor "
    "y filtra por LOWER(CONCAT(c.conNombre,' ',c.conPrimerApell)) LIKE '%nombre%'.\n"
    + SCHEMA
)


# ─────────────────────────────────────────────────────────
# Utilidades
# ─────────────────────────────────────────────────────────

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

def _texto_a_html(text):
    if not text: return ''
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


# ─────────────────────────────────────────────────────────
# Extracción de número de viaje / límite top N
# ─────────────────────────────────────────────────────────

def _extraer_numero_viaje(q):
    """Detecta 'viaje #40', 'viaje numero 40', 'viaje 40', '#40'."""
    patrones = [
        r'viaje\s*#?\s*(\d+)',
        r'#\s*(\d+)',
        r'numero\s+(\d+)',
        r'num\s*\.?\s*(\d+)',
    ]
    for p in patrones:
        m = re.search(p, q)
        if m:
            return int(m.group(1))
    return None

def _extraer_folio_boleto(q):
    """Detecta 'folio 123', 'folio de boleto 123', 'ticket 123', etc."""
    patrones = [
        r'folio\s*(?:de\s*(?:boleto|ticket|compra))?\s*#?\s*(\d+)',
        r'(?:boleto|ticket)\s*#\s*(\d+)',
        r'(?:boleto|ticket)\s+numero\s+(\d+)',
        r'(?:boleto|ticket)\s+(\d+)',
    ]
    for p in patrones:
        m = re.search(p, q, re.IGNORECASE)
        if m:
            return int(m.group(1))
    return None

def _extraer_codigo_ticket(q):
    """Detecta 'ticket individual 15', 'codigo de boleto 15', etc."""
    patrones = [
        r'codigo\s+de\s+(?:boleto|ticket)\s*#?\s*(\d+)',
        r'(?:boleto|ticket)\s+individual\s*#?\s*(\d+)',
        r'(?:ticket|boleto)\s+codigo\s*#?\s*(\d+)',
    ]
    for p in patrones:
        m = re.search(p, q, re.IGNORECASE)
        if m:
            return int(m.group(1))
    return None

def _extraer_top_n(q):
    """Detecta 'top 5', 'los 3 mejores', 'primeros 10', etc. Devuelve int."""
    m = re.search(r'top\s+(\d+)|los\s+(\d+)\s+(?:mejores|primeros|mas)|primeros\s+(\d+)', q)
    if m:
        return int(next(x for x in m.groups() if x))
    return None

def _extraer_anio(q):
    """Extrae año de 4 dígitos de la consulta."""
    m = re.search(r'\b(20\d{2})\b', q)
    return int(m.group(1)) if m else None

def _extraer_fecha_especifica(q):
    """Detecta '1 de marzo', '15 de febrero', etc. Devuelve (dia, mes_num) o None."""
    meses = {'enero':1,'febrero':2,'marzo':3,'abril':4,'mayo':5,'junio':6,
             'julio':7,'agosto':8,'septiembre':9,'octubre':10,'noviembre':11,'diciembre':12}
    for nombre, num in meses.items():
        m = re.search(r'(\d{1,2})\s+de\s+' + nombre, q)
        if m:
            return int(m.group(1)), num
    return None

def _extraer_nombre_conductor(q):
    """Intenta extraer un nombre propio mencionado junto a 'conductor'."""
    # Quitar palabras comunes y quedar con posibles nombres propios
    m = re.search(
        r'conductor(?:a)?\s+(?:llamad[oa]\s+)?([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+(?:\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)*)',
        q, re.IGNORECASE
    )
    if m:
        return m.group(1).strip()
    # Buscar patrón "viajes de NombreApellido" o "del conductor NombreApellido"
    m2 = re.search(r'(?:de|del|por)\s+(?:el\s+conductor\s+)?([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+\s+[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)', q, re.IGNORECASE)
    if m2:
        return m2.group(1).strip()
    return None


# ─────────────────────────────────────────────────────────
# Detección de intent
# ─────────────────────────────────────────────────────────

def _intent(q_orig):
    q = q_orig.lower()

    # Eliminar tildes para comparación
    tr = str.maketrans('áéíóúàèìòùäëïöü', 'aeiouaeiouaeiou')
    q = q.translate(tr)

    def has(*w): return any(x in q for x in w)

    # ── New #18: SQL puro ────────────────────────────────────────────────────────
    q_strip = q_orig.strip()
    if re.match(r'^\s*SELECT\s+', q_strip, re.IGNORECASE):
        return 'sql_puro'

    # ── New #05: intento de modificar BD ────────────────────────────────────────
    for palabra in PALABRAS_MODIFICAR:
        if palabra in q:
            return 'solo_lectura'

    # ── New #04: qué puede hacer / info de Elipse ───────────────────────────────
    if has('que puedes hacer', 'que puedes', 'para que sirves', 'que haces',
           'que tipo de informacion', 'que informacion', 'ayuda', 'help',
           'capacidades', 'funciones', 'que me puedes', 'como te uso',
           'que sabe', 'que sabes'):
        return 'capacidades'

    # ── New #17: info de RBE ─────────────────────────────────────────────────────
    if has('informacion de rbe', 'info de rbe', 'que es rbe', 'acerca de rbe',
           'sobre rbe', 'historia de rbe', 'empresa rbe', 'muestrame informacion de rbe',
           'informacion rbe'):
        return 'info_rbe'

    # ── Temporal: ayer / semana / mes ───────────────────────────────────────────
    if has('ayer'):                                    return 'ayer'
    if has('semana pasada', 'semana anterior'):        return 'semana_pasada'
    if has('mes pasado', 'mes anterior'):              return 'mes_pasado'
    if has('ultimos 7 dias', 'ultimos siete dias'):    return 'ultimos_7'
    if has('ultimos 30 dias', 'ultimos treinta dias'): return 'ultimos_30'
    if has('ultima semana'):                           return 'semana_pasada'
    if has('ultimo mes'):                              return 'mes_pasado'

    # ── New #19: ingresos de año específico ─────────────────────────────────────
    if has('ingreso', 'recauda', 'ventas', 'dinero') and _extraer_anio(q_orig):
        return 'ingresos_anio'

    # ── Fix #3: ingresos por método de pago ─────────────────────────────────────
    if has('metodo', 'efectivo', 'tarjeta') and has('ingreso', 'recauda', 'total', 'dinero'):
        return 'ingresos_metodo'

    # ── New #10: ingresos / boletos HOY ─────────────────────────────────────────
    if has('hoy') and has('ingreso', 'recauda', 'ventas', 'dinero', 'boleto', 'vendido', 'venta'):
        return 'ventas_hoy'

    if has('ingreso', 'recaudacion', 'ventas', 'dinero', 'monto', 'gano', 'recaudo'):
        if has('semana'): return 'ingresos_semana'
        return 'ingresos_mes' if has('mes', 'mensual', 'este mes') else 'ingresos_general'

    # ── New #11: boletos en fecha específica ────────────────────────────────────
    if has('boleto', 'ticket', 'vendido') and _extraer_fecha_especifica(q_orig):
        return 'boletos_fecha'

    # ── New #02 / #03: top N con límite explícito ───────────────────────────────
    if has('conductor', 'chofer') and (has('top', 'ranking', 'mas viajes', 'mejores') or _extraer_top_n(q)):
        return 'top_conductores'
    if (has('autobus', 'unidad', 'camion', 'camiones') and
            (has('top', 'ranking', 'mas viajes') or _extraer_top_n(q))):
        return 'top_autobuses'

    if has('ruta') and has('popular', 'top', 'boleto', 'mas'): return 'rutas_populares'

    if has('ruta') and has('cara', 'caro', 'costosa', 'costoso', 'caras', 'mas cara'):
        return 'rutas_caras'

    if has('pasajero') and has('frecuente', 'top', 'ranking'):  return 'top_pasajeros'

    # ── New #15: taquillero con más boletos vendidos ─────────────────────────────
    if has('taquillero') and has('vendi', 'boleto', 'mas boleto', 'ranking', 'top'):
        return 'top_taquilleros'

    # ── Folio de boleto / compra / ticket individual ───────────────────────────
    if has('folio', 'boleto', 'ticket', 'compra'):
        codigo_ticket = _extraer_codigo_ticket(q_orig)
        if codigo_ticket is not None:
            return 'ticket_individual'
        folio = _extraer_folio_boleto(q_orig)
        if folio is not None and not has('vendido', 'total', 'emitido'):
            if has('codigo', 'ticket individual'):
                return 'ticket_individual'
            return 'folio_boleto'

    # ── New #14: terminal con más taquilleros ────────────────────────────────────
    if has('terminal') and has('mas taquillero', 'taquillero', 'cuantos taquillero'):
        return 'terminal_mas_taquilleros'

    # ── New #07: viaje específico por número ────────────────────────────────────
    num_viaje = _extraer_numero_viaje(q)
    if num_viaje is not None:
        # Sub-intents: pasajeros del viaje, conductor del viaje, info del viaje
        if has('pasajero', 'cliente', 'quien viaj', 'quienes'):
            return 'pasajeros_de_viaje'
        if has('conductor', 'chofer', 'operador', 'quien maneja', 'quien conduce'):
            return 'conductor_de_viaje'
        return 'viaje_especifico'

    # ── New #13: viajes de conductor específico (por nombre) ────────────────────
    nombre_cond = _extraer_nombre_conductor(q_orig)
    if nombre_cond and has('viaje', 'ruta', 'realiz', 'hizo', 'lleva', 'registro'):
        return 'viajes_de_conductor'

    if has('en ruta', 'circulando', 'actualmente') or (has('ahora') and not has('cuanto')):
        return 'en_ruta'

    if has('taquillero', 'taquilleros') and has('supervisor', 'supervisa', 'supervisores', 'jefe'):
        return 'taquilleros_supervisores'

    # ── New #16: autobuses disponibles (sin viaje futuro) ───────────────────────
    if (has('autobus', 'camion', 'unidad') and
            has('disponible', 'sin asignar', 'libre', 'sin viaje')):
        return 'autobuses_disponibles'

    # ── New #09: autobuses sin usar / semanas sin asignar ───────────────────────
    if (has('autobus', 'camion', 'unidad') and
            has('sin usar', 'semana sin', 'tiempo sin', 'ocioso', 'no se usa',
                'poco usado', 'semanas sin', 'dias sin', 'no asignado', 'sin ser asignado')):
        return 'autobuses_ociosos'

    if has('hoy', 'viaje hoy', 'salida hoy'):          return 'viajes_hoy'
    if has('manana') and has('viaje', 'salida'):        return 'viajes_manana'

    # ── New #01: viajes programados futuros / por fecha ─────────────────────────
    if has('programado', 'proxim', 'fecha') and has('viaje', 'salida'):
        return 'viajes_programados'

    if (has('proxima semana', 'proximos') or has('semana')) and has('viaje', 'salida', 'asiento'):
        return 'proxima_semana'
    if has('cancelado', 'suspendido', 'estado cancelado'):  return 'cancelados'
    if has('retrasado', 'retraso'):                         return 'retrasados'

    if has('boleto', 'ticket') and has('vendido', 'total', 'emitido'):
        if has('mes', 'este mes', 'mensual'): return 'boletos_mes'
        return 'boletos_general'

    if has('resumen', 'estado actual'): return 'resumen'
    if has('terminal', 'sucursal'):     return 'terminales'
    if has('ocupacion', 'capacidad', 'asiento libre'): return 'ocupacion'

    if has('disponible') and has('asiento', 'ocupado', 'ocupa'):
        return 'viajes_disponibles'

    if has('ruta') and not has('popular', 'top'):        return 'rutas_lista'
    if has('conductor', 'chofer'):                       return 'conductores_lista'

    if has('autobus', 'flota') and has('volvo', 'mercedes', 'scania', 'dina', 'irizar', 'man', 'marca'):
        return 'autobuses_marca'

    if has('autobus', 'flota', 'camion'):                return 'autobuses_lista'
    if has('pasajero', 'cliente'):                       return 'pasajeros_lista'

    for mes, num in [('enero','01'),('febrero','02'),('marzo','03'),('abril','04'),
                     ('mayo','05'),('junio','06'),('julio','07'),('agosto','08'),
                     ('septiembre','09'),('octubre','10'),('noviembre','11'),('diciembre','12')]:
        if mes in q: return 'mes_%s' % num

    return 'ai'


# ─────────────────────────────────────────────────────────
# Llamada a Groq
# ─────────────────────────────────────────────────────────

def _llamar_groq(system, user_msg, modelo_id, max_tokens=800, temperature=0.1):
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
            'User-Agent': 'Mozilla/5.0 (compatible; RBE-Elipse/2.0)',
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


# ─────────────────────────────────────────────────────────
# Modo IA con SQL dinámico (fallback)
# ─────────────────────────────────────────────────────────

def _ai_con_sql(pregunta, modelo_key):
    modelo_id = MODELOS_IA.get(modelo_key, MODELOS_IA[MODELO_DEFAULT])['id']

    sql_raw, err = _llamar_groq(SQL_SYSTEM_PROMPT, pregunta, modelo_id, max_tokens=400, temperature=0.0)
    if err:
        return '<p class="msg-error">%s</p>' % err

    sql_raw = sql_raw.strip()
    sql_raw = re.sub(r'^```sql\s*', '', sql_raw, flags=re.IGNORECASE)
    sql_raw = re.sub(r'^```\s*', '', sql_raw)
    sql_raw = re.sub(r'```$', '', sql_raw).strip()

    if sql_raw.upper().startswith('NO_SQL') or not sql_raw.upper().startswith('SELECT'):
        resp, err2 = _llamar_groq(SYSTEM_PROMPT, pregunta, modelo_id, max_tokens=600, temperature=0.3)
        if err2:
            return '<p class="msg-error">%s</p>' % err2
        return _texto_a_html(resp)

    try:
        cols, rows = _q(sql_raw)
    except Exception as e:
        resp, _ = _llamar_groq(SYSTEM_PROMPT, pregunta, modelo_id, max_tokens=600, temperature=0.3)
        return (
            '<details style="margin-bottom:8px;font-size:11px;color:var(--muted)">'
            '<summary>SQL generado (con error)</summary>'
            '<code style="display:block;padding:6px;background:#f8f9fa;border-radius:6px;white-space:pre-wrap">%s</code>'
            '<p style="color:var(--danger)">Error: %s</p>'
            '</details>%s' % (sql_raw, str(e), _texto_a_html(resp) if resp else '')
        )

    SYSTEM_ADMIN = (
        SYSTEM_PROMPT +
        "\n\nIMPORTANTE: Eres asistente del PANEL INTERNO de RBE. "
        "NUNCA digas 'no tengo acceso'. Los datos ya estan disponibles. Respondelos directamente."
    )

    if not rows:
        interpretacion, _ = _llamar_groq(
            SYSTEM_ADMIN,
            'El usuario pregunto: "%s"\nNo encontre ningun resultado. '
            'Responde en UNA oracion corta.' % pregunta,
            modelo_id, max_tokens=120, temperature=0.1
        )
        tabla_html = '<em>Sin resultados en la base de datos.</em>'
    else:
        muestra = rows[:20]
        datos_str = json.dumps(muestra, ensure_ascii=False, default=str)
        total_str = ' (%d registros en total)' % len(rows) if len(rows) > 20 else ' (%d registros)' % len(rows)
        interpretacion, _ = _llamar_groq(
            SYSTEM_ADMIN,
            'El usuario pregunto: "%s"\nDatos reales%s:\n%s\n\n'
            'Responde DIRECTAMENTE usando estos datos. Menciona valores exactos. '
            'No digas que no tienes acceso. No menciones JSON.' % (pregunta, total_str, datos_str),
            modelo_id, max_tokens=500, temperature=0.2
        )
        tabla_html = _tabla(cols, rows)

    partes = []
    if interpretacion:
        partes.append(_texto_a_html(interpretacion))
    if rows:
        partes.append(
            '<details style="margin-top:10px">'
            '<summary style="cursor:pointer;font-size:12px;color:var(--muted)">'
            'Ver tabla completa (%d filas)</summary>%s</details>' % (len(rows), tabla_html)
        )
    return ''.join(partes) if partes else tabla_html


# ─────────────────────────────────────────────────────────
# Resolución de intents
# ─────────────────────────────────────────────────────────

def _resolve(intent, pregunta):
    q = pregunta.lower()
    tr = str.maketrans('áéíóúàèìòùäëïöü', 'aeiouaeiouaeiou')
    q = q.translate(tr)

    def _detalle_compra_por_folio(folio):
        cols_pago, rows_pago = _q(
            "SELECT p.numero AS Folio,"
            " p.fechapago AS FechaCompra,"
            " p.monto AS MontoTotal,"
            " tp.nombre AS MetodoPago,"
            " COALESCE(CONCAT(tq.taqNombre,' ',tq.taqPrimerApell), 'App') AS Vendedor,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.numero AS Viaje,"
            " v.fecHoraSalida AS Salida,"
            " v.fecHoraEntrada AS LlegadaEst,"
            " ev.nombre AS Estado"
            " FROM pago p"
            " LEFT JOIN tipo_pago tp ON tp.numero = p.tipo"
            " LEFT JOIN taquillero tq ON tq.registro = p.vendedor"
            " LEFT JOIN ticket tk ON tk.pago = p.numero"
            " LEFT JOIN viaje v ON v.numero = tk.viaje"
            " LEFT JOIN edo_viaje ev ON ev.numero = v.estado"
            " LEFT JOIN ruta r ON r.codigo = v.ruta"
            " LEFT JOIN terminal tor ON tor.numero = r.origen"
            " LEFT JOIN terminal tdes ON tdes.numero = r.destino"
            " LEFT JOIN ciudad co ON co.clave = tor.ciudad"
            " LEFT JOIN ciudad cd ON cd.clave = tdes.ciudad"
            " WHERE p.numero = %s"
            " LIMIT 1",
            [folio]
        )
        if not rows_pago:
            return None

        cols_tickets, rows_tickets = _q(
            "SELECT tk.codigo AS Ticket,"
            " CONCAT(pa.paNombre,' ',pa.paPrimerApell,"
            "        COALESCE(CONCAT(' ',pa.paSegundoApell), '')) AS Pasajero,"
            " tpas.descripcion AS TipoPasajero,"
            " COALESCE(tk.etiqueta_asiento, CAST(a.numero AS CHAR)) AS Asiento,"
            " tas.descripcion AS TipoAsiento,"
            " tk.precio AS Precio"
            " FROM ticket tk"
            " JOIN pasajero pa ON pa.num = tk.pasajero"
            " JOIN tipo_pasajero tpas ON tpas.num = tk.tipopasajero"
            " JOIN asiento a ON a.numero = tk.asiento"
            " JOIN tipo_asiento tas ON tas.codigo = a.tipo"
            " WHERE tk.pago = %s"
            " ORDER BY tk.codigo",
            [folio]
        )
        return cols_pago, rows_pago, cols_tickets, rows_tickets

    # ── New #18: SQL puro escrito por el usuario ─────────────────────────────────
    if intent == 'sql_puro':
        sql_usuario = pregunta.strip()
        # Seguridad: solo SELECT
        if re.match(r'^\s*SELECT\s+', sql_usuario, re.IGNORECASE):
            try:
                cols, rows = _q(sql_usuario)
                if not rows:
                    return '<p>La consulta no devolvio resultados.</p>'
                return (
                    '<p><strong>Resultado de tu consulta SQL:</strong></p>'
                    + _tabla(cols, rows)
                )
            except Exception as e:
                return (
                    '<p style="color:var(--danger)"><strong>Error en tu SQL:</strong> %s</p>'
                    '<code style="display:block;padding:8px;background:#1a1a1a;border-radius:6px;'
                    'white-space:pre-wrap;font-size:12px;margin-top:8px">%s</code>' % (str(e), sql_usuario)
                )
        return '<p style="color:var(--danger)">Solo se permiten consultas <strong>SELECT</strong>. No se puede modificar la base de datos.</p>'

    # ── New #05: intento de modificar BD ────────────────────────────────────────
    if intent == 'solo_lectura':
        return (
            '<div style="border-left:3px solid var(--warning,#f59e0b);padding:10px 14px;background:rgba(245,158,11,0.08);border-radius:6px">'
            '<p><strong>⚠️ Elipse es solo de consulta</strong></p>'
            '<p>No tengo la capacidad de <strong>borrar, crear, modificar ni eliminar</strong> '
            'ningún dato de la base de datos del sistema. Esto es por seguridad del sistema.</p>'
            '<p>Si necesitas realizar cambios en los registros, debes hacerlo directamente '
            'desde el panel de administración del sistema.</p>'
            '</div>'
        )

    # ── New #04: capacidades de Elipse ──────────────────────────────────────────
    if intent == 'capacidades':
        return CAPACIDADES

    # ── New #17: info de RBE ─────────────────────────────────────────────────────
    if intent == 'info_rbe':
        return INFO_RBE

    # ── RESUMEN ─────────────────────────────────────────────────────────────────
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

    # ── VIAJES DISPONIBLES con asientos ocupados ─────────────────────────────────
    if intent == 'viajes_disponibles':
        cols, rows = _q(
            "SELECT DISTINCT v.numero AS Num_Viaje,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS Salida, v.fecHoraEntrada AS LlegadaEst,"
            " a.placas AS Autobus, COUNT(va.asiento) AS AsientosOcupados"
            " FROM viaje v"
            " JOIN edo_viaje ev ON v.estado = ev.numero"
            " JOIN viaje_asiento va ON v.numero = va.viaje"
            " JOIN ruta r ON v.ruta = r.codigo"
            " JOIN terminal tor ON r.origen = tor.numero"
            " JOIN terminal tdes ON r.destino = tdes.numero"
            " JOIN ciudad co ON tor.ciudad = co.clave"
            " JOIN ciudad cd ON tdes.ciudad = cd.clave"
            " LEFT JOIN autobus a ON v.autobus = a.numero"
            " WHERE ev.nombre = 'Disponible' AND va.ocupado = 1"
            " GROUP BY v.numero ORDER BY v.fecHoraSalida"
        )
        if not rows:
            return '<p>No existen viajes disponibles con al menos 1 asiento ocupado en este momento.</p>'
        return '<p><strong>Viajes disponibles con al menos 1 asiento ocupado:</strong></p>%s%s' % (
            _cards([{'label': 'Disponibles con ocupacion', 'val': len(rows), 'sub': 'viajes'}]),
            _tabla(cols, rows)
        )

    # ── EN RUTA ─────────────────────────────────────────────────────────────────
    if intent == 'en_ruta':
        solo_conductores = any(x in q for x in ['conductor', 'chofer', 'nombre del conductor', 'quien maneja'])
        cols_viajes, rows_viajes = _q(
            "SELECT v.numero AS Viaje, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS Salida, v.fecHoraEntrada AS LlegadaEst,"
            " a.placas AS Autobus,"
            " CONCAT(c.conNombre,' ',c.conPrimerApell,' ',c.conSegundoApell) AS Conductor,"
            " COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE v.estado=2 GROUP BY v.numero ORDER BY v.fecHoraSalida"
        )
        if not rows_viajes:
            return '<p>No hay viajes en ruta en este momento.</p>'
        header = _cards([{'label': 'En ruta', 'val': len(rows_viajes), 'sub': 'autobuses'}])
        if solo_conductores:
            cols_cond, rows_cond = _q(
                "SELECT DISTINCT c.conNombre AS Nombre,"
                " c.conPrimerApell AS PrimerApellido, c.conSegundoApell AS SegundoApellido"
                " FROM conductor c JOIN viaje v ON c.registro = v.conductor"
                " JOIN edo_viaje ev ON v.estado = ev.numero"
                " WHERE ev.nombre = 'En Ruta' ORDER BY c.conPrimerApell"
            )
            return '<p><strong>Conductores con viaje En Ruta:</strong></p>%s%s' % (header, _tabla(cols_cond, rows_cond))
        return '<p><strong>Viajes actualmente en ruta:</strong></p>%s%s' % (header, _tabla(cols_viajes, rows_viajes))

    # ── VIAJES HOY ────────────────────────────────────────────────────────────────
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

    # ── New #01: VIAJES PROGRAMADOS FUTUROS ──────────────────────────────────────
    if intent == 'viajes_programados':
        cols, rows = _q(
            "SELECT v.numero AS Num, DATE(v.fecHoraSalida) AS Fecha,"
            " TIME(v.fecHoraSalida) AS Hora,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " ev.nombre AS Estado, a.placas AS Autobus,"
            " CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " WHERE v.fecHoraSalida > NOW() AND v.estado NOT IN (3,4)"
            " ORDER BY v.fecHoraSalida LIMIT 30"
        )
        if not rows:
            return '<p>No hay viajes programados para fechas futuras en este momento.</p>'
        return '<p><strong>Viajes programados próximos:</strong></p>%s%s' % (
            _cards([{'label': 'Programados', 'val': len(rows), 'sub': 'proximos viajes'}]),
            _tabla(cols, rows, est=['Estado'])
        )

    # ── PRÓXIMA SEMANA ───────────────────────────────────────────────────────────
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

    # ── RUTAS POPULARES ──────────────────────────────────────────────────────────
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

    # ── RUTAS MÁS CARAS ──────────────────────────────────────────────────────────
    if intent == 'rutas_caras':
        cols, rows = _q(
            "SELECT r.codigo AS Num_Ruta, tor.nombre AS Terminal_Origen,"
            " tdes.nombre AS Terminal_Destino, r.precio AS Precio"
            " FROM ruta r"
            " JOIN terminal tor ON r.origen = tor.numero"
            " JOIN terminal tdes ON r.destino = tdes.numero"
            " ORDER BY r.precio DESC LIMIT 5"
        )
        if not rows: return '<p>No se encontraron rutas registradas.</p>'
        return '<p><strong>Las 5 rutas mas caras:</strong></p>%s' % _tabla(cols, rows, pesos=['Precio'])

    # ── New #02: TOP N CONDUCTORES (con límite configurable) ────────────────────
    if intent == 'top_conductores':
        limite = _extraer_top_n(pregunta) or 12
        cols, rows = _q(
            "SELECT CONCAT(c.conNombre,' ',c.conPrimerApell) AS Conductor,"
            " COUNT(v.numero) AS Viajes, COUNT(t.codigo) AS PasajerosTotal"
            " FROM conductor c"
            " LEFT JOIN viaje v ON v.conductor=c.registro"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " GROUP BY c.registro ORDER BY Viajes DESC LIMIT %s",
            [limite]
        )
        titulo = 'Top %d conductores con mas viajes' % limite if _extraer_top_n(pregunta) else 'Ranking de conductores'
        return '<p><strong>%s:</strong></p>%s' % (titulo, _tabla(cols, rows))

    # ── New #03: TOP N AUTOBUSES (con límite configurable) ──────────────────────
    if intent == 'top_autobuses':
        limite = _extraer_top_n(pregunta) or 10
        cols, rows = _q(
            "SELECT a.numero AS Num, a.placas AS Placas, m.nombre AS Marca,"
            " mo.nombre AS Modelo, mo.numasientos AS Asientos,"
            " COUNT(v.numero) AS Viajes, COUNT(t.codigo) AS PasajerosTotal"
            " FROM autobus a JOIN modelo mo ON a.modelo=mo.numero JOIN marca m ON mo.marca=m.numero"
            " LEFT JOIN viaje v ON v.autobus=a.numero"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " GROUP BY a.numero ORDER BY Viajes DESC LIMIT %s",
            [limite]
        )
        titulo = 'Top %d autobuses con mas viajes' % limite if _extraer_top_n(pregunta) else 'Autobuses con mas viajes'
        return '<p><strong>%s:</strong></p>%s' % (titulo, _tabla(cols, rows))

    # ── TOP PASAJEROS FRECUENTES ──────────────────────────────────────────────────
    if intent == 'top_pasajeros':
        limite = _extraer_top_n(pregunta) or 10
        cols, rows = _q(
            "SELECT CONCAT(p.paNombre,' ',p.paPrimerApell) AS Pasajero,"
            " COUNT(t.codigo) AS Boletos, SUM(t.precio) AS GastoTotal"
            " FROM pasajero p JOIN ticket t ON t.pasajero=p.num"
            " GROUP BY p.num ORDER BY Boletos DESC LIMIT %s",
            [limite]
        )
        return '<p><strong>Pasajeros mas frecuentes:</strong></p>%s' % _tabla(cols, rows, pesos=['GastoTotal'])

    # ── New #15: TOP TAQUILLEROS POR BOLETOS VENDIDOS ────────────────────────────
    if intent == 'top_taquilleros':
        cols, rows = _q(
            "SELECT CONCAT(tq.taqnombre,' ',tq.taqprimerapell) AS Taquillero,"
            " term.nombre AS Terminal, ci.nombre AS Ciudad,"
            " COUNT(tk.codigo) AS BoletosTotales,"
            " SUM(tk.precio) AS MontoTotal"
            " FROM taquillero tq"
            " JOIN terminal term ON tq.terminal = term.numero"
            " JOIN ciudad ci ON term.ciudad = ci.clave"
            " LEFT JOIN ticket tk ON tk.viaje IN ("
            "   SELECT v.numero FROM viaje v"
            "   JOIN ruta r ON v.ruta = r.codigo"
            "   JOIN terminal tor ON r.origen = tor.numero"
            "   WHERE tor.numero = tq.terminal"
            " )"
            " GROUP BY tq.registro ORDER BY BoletosTotales DESC LIMIT 10"
        )
        if not rows:
            # Fallback: ranking simple por terminal de origen
            cols, rows = _q(
                "SELECT CONCAT(tq.taqnombre,' ',tq.taqprimerapell) AS Taquillero,"
                " term.nombre AS Terminal,"
                " COUNT(tk.codigo) AS BoletosTotales"
                " FROM taquillero tq"
                " JOIN terminal term ON tq.terminal = term.numero"
                " LEFT JOIN ticket tk ON 1=0"
                " GROUP BY tq.registro ORDER BY tq.taqprimerapell LIMIT 10"
            )
        return '<p><strong>Taquilleros por boletos vendidos:</strong></p>%s' % _tabla(cols, rows, pesos=['MontoTotal'])

    # ── New #14: TERMINAL CON MÁS TAQUILLEROS ────────────────────────────────────
    if intent == 'terminal_mas_taquilleros':
        cols, rows = _q(
            "SELECT t.nombre AS Terminal, ci.nombre AS Ciudad,"
            " COUNT(tq.registro) AS NumTaquilleros"
            " FROM terminal t"
            " JOIN ciudad ci ON ci.clave = t.ciudad"
            " LEFT JOIN taquillero tq ON tq.terminal = t.numero"
            " GROUP BY t.numero ORDER BY NumTaquilleros DESC"
        )
        if not rows: return '<p>No se encontraron terminales con taquilleros.</p>'
        top = rows[0]
        return (
            '<p><strong>Terminal con mas taquilleros:</strong> '
            '<em>%s</em> (%s) — <strong>%s taquilleros</strong></p>'
            '<p><strong>Detalle de todas las terminales:</strong></p>%s'
        ) % (top.get('Terminal'), top.get('Ciudad'), top.get('NumTaquilleros'), _tabla(cols, rows))

    # ── Folio de boleto / compra móvil ──────────────────────────────────────────
    if intent == 'folio_boleto':
        folio = _extraer_folio_boleto(pregunta)
        if folio is None:
            return '<p>No pude identificar el folio. Ejemplo: <em>"buscar folio 123"</em>.</p>'

        detalle = _detalle_compra_por_folio(folio)
        if not detalle:
            return '<p>No encontre ningun boleto o compra con el <strong>folio #%d</strong>.</p>' % folio
        cols_pago, rows_pago, cols_tickets, rows_tickets = detalle

        pago = rows_pago[0]
        resumen = _cards([
            {'label': 'Folio',       'val': '#%d' % folio,                  'sub': 'compra encontrada'},
            {'label': 'Boletos',     'val': len(rows_tickets),              'sub': 'tickets asociados'},
            {'label': 'Monto total', 'val': _pesos(pago.get('MontoTotal')), 'sub': pago.get('MetodoPago') or 'metodo'},
        ])

        detalle_pago = _tabla(cols_pago, rows_pago, est=['Estado'], pesos=['MontoTotal'])
        detalle_tickets = (
            _tabla(cols_tickets, rows_tickets, pesos=['Precio'])
            if rows_tickets else
            '<em>El folio existe pero no tiene tickets asociados.</em>'
        )
        return (
            '<p><strong>Resultado para el folio #%d:</strong></p>%s'
            '<p><strong>Resumen de la compra:</strong></p>%s'
            '<p><strong>Boletos asociados:</strong></p>%s'
        ) % (folio, resumen, detalle_pago, detalle_tickets)

    if intent == 'ticket_individual':
        codigo = _extraer_codigo_ticket(pregunta) or _extraer_folio_boleto(pregunta)
        if codigo is None:
            return '<p>No pude identificar el codigo del ticket. Ejemplo: <em>"ticket individual 25"</em>.</p>'

        cols, rows = _q(
            "SELECT tk.codigo AS Ticket,"
            " p.numero AS Folio,"
            " p.fechapago AS FechaCompra,"
            " CONCAT(pa.paNombre,' ',pa.paPrimerApell,"
            "        COALESCE(CONCAT(' ',pa.paSegundoApell), '')) AS Pasajero,"
            " tpas.descripcion AS TipoPasajero,"
            " COALESCE(tk.etiqueta_asiento, CAST(a.numero AS CHAR)) AS Asiento,"
            " tas.descripcion AS TipoAsiento,"
            " tk.precio AS Precio,"
            " tp.nombre AS MetodoPago,"
            " COALESCE(CONCAT(tq.taqNombre,' ',tq.taqPrimerApell), 'App') AS Vendedor,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.numero AS Viaje,"
            " v.fecHoraSalida AS Salida,"
            " ev.nombre AS Estado"
            " FROM ticket tk"
            " JOIN pago p ON p.numero = tk.pago"
            " JOIN pasajero pa ON pa.num = tk.pasajero"
            " JOIN tipo_pasajero tpas ON tpas.num = tk.tipopasajero"
            " JOIN asiento a ON a.numero = tk.asiento"
            " JOIN tipo_asiento tas ON tas.codigo = a.tipo"
            " LEFT JOIN tipo_pago tp ON tp.numero = p.tipo"
            " LEFT JOIN taquillero tq ON tq.registro = p.vendedor"
            " LEFT JOIN viaje v ON v.numero = tk.viaje"
            " LEFT JOIN edo_viaje ev ON ev.numero = v.estado"
            " LEFT JOIN ruta r ON r.codigo = v.ruta"
            " LEFT JOIN terminal tor ON tor.numero = r.origen"
            " LEFT JOIN terminal tdes ON tdes.numero = r.destino"
            " LEFT JOIN ciudad co ON co.clave = tor.ciudad"
            " LEFT JOIN ciudad cd ON cd.clave = tdes.ciudad"
            " WHERE tk.codigo = %s"
            " LIMIT 1",
            [codigo]
        )
        if not rows:
            return '<p>No encontre ningun <strong>ticket #%d</strong> registrado.</p>' % codigo

        row = rows[0]
        resumen = _cards([
            {'label': 'Ticket', 'val': '#%d' % codigo,                  'sub': 'boleto individual'},
            {'label': 'Folio',  'val': '#%s' % row.get('Folio', '—'),   'sub': 'compra asociada'},
            {'label': 'Precio', 'val': _pesos(row.get('Precio')),       'sub': row.get('TipoPasajero') or 'tipo'},
        ])
        return (
            '<p><strong>Detalle del ticket #%d:</strong></p>%s%s'
        ) % (codigo, resumen, _tabla(cols, rows, est=['Estado'], pesos=['Precio']))

    # ── New #07: VIAJE ESPECÍFICO por número ────────────────────────────────────
    if intent == 'viaje_especifico':
        num = _extraer_numero_viaje(pregunta.lower())
        cols, rows = _q(
            "SELECT v.numero AS Num_Viaje,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " tor.nombre AS Terminal_Origen, tdes.nombre AS Terminal_Destino,"
            " v.fecHoraSalida AS Salida, v.fecHoraEntrada AS LlegadaEst,"
            " ev.nombre AS Estado, a.placas AS Autobus,"
            " CONCAT(c.conNombre,' ',c.conPrimerApell,' ',c.conSegundoApell) AS Conductor,"
            " mo.numasientos AS Capacidad,"
            " COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v"
            " JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero"
            " JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave"
            " JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN autobus a ON v.autobus=a.numero"
            " LEFT JOIN modelo mo ON a.modelo=mo.numero"
            " LEFT JOIN conductor c ON v.conductor=c.registro"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE v.numero=%s GROUP BY v.numero",
            [num]
        )
        if not rows:
            return '<p>No se encontro el viaje <strong>#%d</strong> en la base de datos.</p>' % num
        return '<p><strong>Detalle del Viaje #%d:</strong></p>%s' % (num, _tabla(cols, rows, est=['Estado']))

    # ── New #08: PASAJEROS DE UN VIAJE ESPECÍFICO ────────────────────────────────
    if intent == 'pasajeros_de_viaje':
        num = _extraer_numero_viaje(pregunta.lower())
        # Verificar que el viaje existe
        _, check = _q("SELECT numero FROM viaje WHERE numero=%s", [num])
        if not check:
            return '<p>No existe el viaje <strong>#%d</strong>.</p>' % num
        cols, rows = _q(
            "SELECT p.num AS Num_Pasajero,"
            " CONCAT(p.paNombre,' ',p.paPrimerApell) AS Nombre,"
            " TIMESTAMPDIFF(YEAR, p.fechaNacimiento, CURDATE()) AS Edad,"
            " tp.nombre AS TipoPasajero, tk.precio AS PrecioBoleto"
            " FROM ticket tk"
            " JOIN pasajero p ON tk.pasajero = p.num"
            " LEFT JOIN tipo_pasajero tp ON tk.tipopasajero = tp.numero"
            " WHERE tk.viaje = %s"
            " ORDER BY p.paPrimerApell",
            [num]
        )
        if not rows:
            return '<p>El viaje <strong>#%d</strong> no tiene pasajeros registrados.</p>' % num
        return '<p><strong>Pasajeros del viaje #%d:</strong></p>%s%s' % (
            num,
            _cards([{'label': 'Pasajeros', 'val': len(rows), 'sub': 'en este viaje'}]),
            _tabla(cols, rows, pesos=['PrecioBoleto'])
        )

    # ── New #12: CONDUCTOR DE UN VIAJE ESPECÍFICO ────────────────────────────────
    if intent == 'conductor_de_viaje':
        num = _extraer_numero_viaje(pregunta.lower())
        cols, rows = _q(
            "SELECT c.registro AS Registro,"
            " CONCAT(c.conNombre,' ',c.conPrimerApell,' ',c.conSegundoApell) AS Nombre_Completo,"
            " c.licNumero AS Licencia, c.licVencimiento AS Vence_Lic,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta_del_Viaje,"
            " v.fecHoraSalida AS Salida, ev.nombre AS Estado_Viaje"
            " FROM viaje v"
            " JOIN conductor c ON v.conductor = c.registro"
            " JOIN ruta r ON v.ruta = r.codigo"
            " JOIN terminal tor ON r.origen = tor.numero"
            " JOIN terminal tdes ON r.destino = tdes.numero"
            " JOIN ciudad co ON tor.ciudad = co.clave"
            " JOIN ciudad cd ON tdes.ciudad = cd.clave"
            " JOIN edo_viaje ev ON v.estado = ev.numero"
            " WHERE v.numero = %s",
            [num]
        )
        if not rows:
            return '<p>No se encontro conductor para el viaje <strong>#%d</strong>, o el viaje no existe.</p>' % num
        row = rows[0]
        return (
            '<p><strong>Conductor del viaje #%d:</strong></p>'
            '<p>🧑‍✈️ <strong>%s</strong> — Licencia: %s (vence: %s)</p>'
            '<p>Ruta: %s — Salida: %s — Estado: %s</p>'
        ) % (
            num,
            row.get('Nombre_Completo',''),
            row.get('Licencia',''),
            row.get('Vence_Lic',''),
            row.get('Ruta_del_Viaje',''),
            row.get('Salida',''),
            row.get('Estado_Viaje',''),
        )

    # ── New #13: VIAJES DE UN CONDUCTOR ESPECÍFICO (por nombre) ─────────────────
    if intent == 'viajes_de_conductor':
        nombre = _extraer_nombre_conductor(pregunta)
        if not nombre:
            return '<p>No pude identificar el nombre del conductor. Ejemplo: <em>"viajes realizados por Marco Hernandez"</em></p>'
        cols, rows = _q(
            "SELECT v.numero AS Viaje,"
            " v.fecHoraSalida AS Salida, v.fecHoraEntrada AS Llegada,"
            " CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " ev.nombre AS Estado, a.placas AS Autobus,"
            " COUNT(t.codigo) AS Pasajeros"
            " FROM conductor c"
            " JOIN viaje v ON v.conductor = c.registro"
            " JOIN ruta r ON v.ruta = r.codigo"
            " JOIN terminal tor ON r.origen = tor.numero"
            " JOIN terminal tdes ON r.destino = tdes.numero"
            " JOIN ciudad co ON tor.ciudad = co.clave"
            " JOIN ciudad cd ON tdes.ciudad = cd.clave"
            " JOIN edo_viaje ev ON v.estado = ev.numero"
            " LEFT JOIN autobus a ON v.autobus = a.numero"
            " LEFT JOIN ticket t ON t.viaje = v.numero"
            " WHERE LOWER(CONCAT(c.conNombre,' ',c.conPrimerApell,' ',c.conSegundoApell))"
            "   LIKE LOWER(%s)"
            " GROUP BY v.numero ORDER BY v.fecHoraSalida DESC LIMIT 30",
            ['%' + nombre + '%']
        )
        if not rows:
            return '<p>No se encontraron viajes para el conductor <strong>%s</strong>. Verifica el nombre.</p>' % nombre
        return '<p><strong>Viajes de %s:</strong></p>%s%s' % (
            nombre,
            _cards([{'label': 'Total viajes', 'val': len(rows), 'sub': nombre}]),
            _tabla(cols, rows, est=['Estado'])
        )

    # ── New #09: AUTOBUSES OCIOSOS / sin asignar ────────────────────────────────
    if intent == 'autobuses_ociosos':
        # Detectar cuántas semanas/días
        m_semanas = re.search(r'(\d+)\s*semana', pregunta.lower())
        dias = int(m_semanas.group(1)) * 7 if m_semanas else 14  # default 2 semanas
        cols, rows = _q(
            "SELECT a.numero AS Num, a.placas AS Placas,"
            " ma.nombre AS Marca, mo.nombre AS Modelo,"
            " mo.numasientos AS Asientos,"
            " MAX(v.fecHoraSalida) AS UltimoViaje,"
            " DATEDIFF(CURDATE(), MAX(v.fecHoraSalida)) AS DiasDesdeUltimoViaje"
            " FROM autobus a"
            " JOIN modelo mo ON a.modelo = mo.numero"
            " JOIN marca ma ON mo.marca = ma.numero"
            " LEFT JOIN viaje v ON v.autobus = a.numero"
            " GROUP BY a.numero"
            " HAVING UltimoViaje IS NULL OR DATEDIFF(CURDATE(), UltimoViaje) >= %s"
            " ORDER BY DiasDesdeUltimoViaje DESC",
            [dias]
        )
        if not rows:
            return '<p>No hay autobuses sin asignar en los ultimos <strong>%d dias</strong>. Todos han sido utilizados recientemente.</p>' % dias
        return '<p><strong>Autobuses sin asignar por mas de %d dias:</strong></p>%s%s' % (
            dias,
            _cards([{'label': 'Sin asignar', 'val': len(rows), 'sub': 'mas de %d dias' % dias}]),
            _tabla(cols, rows)
        )

    # ── New #16: AUTOBUSES DISPONIBLES (sin viaje futuro asignado) ───────────────
    if intent == 'autobuses_disponibles':
        cols, rows = _q(
            "SELECT a.numero AS Num, a.placas AS Placas,"
            " ma.nombre AS Marca, mo.nombre AS Modelo,"
            " mo.numasientos AS Asientos"
            " FROM autobus a"
            " JOIN modelo mo ON a.modelo = mo.numero"
            " JOIN marca ma ON mo.marca = ma.numero"
            " WHERE a.numero NOT IN ("
            "   SELECT DISTINCT v.autobus FROM viaje v"
            "   WHERE v.fecHoraSalida >= NOW()"
            "   AND v.estado NOT IN (3,4)"
            "   AND v.autobus IS NOT NULL"
            " )"
            " ORDER BY a.numero"
        )
        if not rows:
            return '<p>Todos los autobuses tienen viajes futuros asignados.</p>'
        return '<p><strong>Autobuses sin viajes futuros asignados:</strong></p>%s%s' % (
            _cards([{'label': 'Disponibles', 'val': len(rows), 'sub': 'sin viaje asignado'}]),
            _tabla(cols, rows)
        )

    # ── New #10: VENTAS / BOLETOS HOY ────────────────────────────────────────────
    if intent == 'ventas_hoy':
        _, tots = _q(
            "SELECT COUNT(tk.codigo) AS boletos, COALESCE(SUM(tk.precio),0) AS ingresos_boletos,"
            " COALESCE(SUM(p.monto),0) AS ingresos_caja"
            " FROM ticket tk"
            " LEFT JOIN pago p ON tk.pago = p.numero"
            " WHERE DATE(tk.fechaEmision) = CURDATE()"
        )
        t = tots[0]
        if t['boletos'] == 0:
            return '<p>No se ha vendido ningun boleto el dia de hoy.</p>'
        cols, rows = _q(
            "SELECT tk.codigo AS Boleto, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " CONCAT(pa.paNombre,' ',pa.paPrimerApell) AS Pasajero,"
            " tk.precio AS Precio, TIME(tk.fechaEmision) AS Hora,"
            " tp_pago.nombre AS MetodoPago"
            " FROM ticket tk"
            " JOIN viaje v ON tk.viaje = v.numero"
            " JOIN ruta r ON v.ruta = r.codigo"
            " JOIN terminal tor ON r.origen = tor.numero"
            " JOIN terminal tdes ON r.destino = tdes.numero"
            " JOIN ciudad co ON tor.ciudad = co.clave"
            " JOIN ciudad cd ON tdes.ciudad = cd.clave"
            " JOIN pasajero pa ON tk.pasajero = pa.num"
            " LEFT JOIN pago p ON tk.pago = p.numero"
            " LEFT JOIN tipo_pago tp_pago ON p.tipo = tp_pago.numero"
            " WHERE DATE(tk.fechaEmision) = CURDATE()"
            " ORDER BY tk.fechaEmision",
        )
        cards = _cards([
            {'label': 'Boletos vendidos', 'val': t['boletos'],                  'sub': 'hoy'},
            {'label': 'Ingresos caja',    'val': _pesos(t['ingresos_caja']),    'sub': 'hoy'},
        ])
        return '<p><strong>Ventas del dia de hoy:</strong></p>%s%s' % (cards, _tabla(cols, rows, pesos=['Precio']))

    # ── New #11: BOLETOS EN FECHA ESPECÍFICA ─────────────────────────────────────
    if intent == 'boletos_fecha':
        fecha_info = _extraer_fecha_especifica(pregunta)
        if not fecha_info:
            return '<p>No pude identificar la fecha. Ejemplo: <em>"boletos vendidos el 1 de marzo"</em></p>'
        dia, mes_num = fecha_info
        from datetime import date
        anio = _extraer_anio(pregunta) or date.today().year
        fecha_str = '%d-%02d-%02d' % (anio, mes_num, dia)
        _, tots = _q(
            "SELECT COUNT(*) AS boletos, COALESCE(SUM(precio),0) AS total"
            " FROM ticket WHERE DATE(fechaEmision) = %s",
            [fecha_str]
        )
        t = tots[0]
        if t['boletos'] == 0:
            return '<p>No se vendieron boletos el <strong>%s</strong>.</p>' % fecha_str
        cols, rows = _q(
            "SELECT tk.codigo AS Boleto, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.numero AS Viaje, tk.precio AS Precio,"
            " CONCAT(pa.paNombre,' ',pa.paPrimerApell) AS Pasajero"
            " FROM ticket tk"
            " JOIN viaje v ON tk.viaje = v.numero"
            " JOIN ruta r ON v.ruta = r.codigo"
            " JOIN terminal tor ON r.origen = tor.numero"
            " JOIN terminal tdes ON r.destino = tdes.numero"
            " JOIN ciudad co ON tor.ciudad = co.clave"
            " JOIN ciudad cd ON tdes.ciudad = cd.clave"
            " JOIN pasajero pa ON tk.pasajero = pa.num"
            " WHERE DATE(tk.fechaEmision) = %s ORDER BY tk.fechaEmision",
            [fecha_str]
        )
        cards = _cards([
            {'label': 'Boletos', 'val': t['boletos'],       'sub': fecha_str},
            {'label': 'Total',   'val': _pesos(t['total']), 'sub': 'recaudado'},
        ])
        return '<p><strong>Boletos vendidos el %s:</strong></p>%s%s' % (fecha_str, cards, _tabla(cols, rows, pesos=['Precio']))

    # ── INGRESOS MES ─────────────────────────────────────────────────────────────
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

    # ── New #19: INGRESOS DE AÑO ESPECÍFICO ─────────────────────────────────────
    if intent == 'ingresos_anio':
        anio = _extraer_anio(pregunta)
        if not anio:
            return '<p>No pude identificar el año. Ejemplo: <em>"ingresos del 2025"</em></p>'
        _, tots = _q(
            "SELECT COUNT(*) AS pagos, COALESCE(SUM(monto),0) AS total"
            " FROM pago WHERE YEAR(fechapago) = %s",
            [anio]
        )
        t = tots[0]
        if t['pagos'] == 0:
            return '<p>No hay registros de ingresos para el año <strong>%d</strong>.</p>' % anio
        cols, rows = _q(
            "SELECT MONTH(p.fechapago) AS Mes, tp.nombre AS Metodo,"
            " COUNT(p.numero) AS Transacciones, SUM(p.monto) AS Total"
            " FROM pago p JOIN tipo_pago tp ON tp.numero = p.tipo"
            " WHERE YEAR(p.fechapago) = %s"
            " GROUP BY MONTH(p.fechapago), tp.nombre"
            " ORDER BY Mes",
            [anio]
        )
        cards = _cards([
            {'label': 'Año',          'val': str(anio),       'sub': 'consultado'},
            {'label': 'Total anual',  'val': _pesos(t['total']), 'sub': 'ingresos'},
            {'label': 'Transacciones','val': t['pagos'],       'sub': 'pagos'},
        ])
        return '<p><strong>Ingresos del año %d:</strong></p>%s%s' % (anio, cards, _tabla(cols, rows, pesos=['Total']))

    # ── INGRESOS POR MÉTODO DE PAGO ──────────────────────────────────────────────
    if intent == 'ingresos_metodo':
        cols, rows = _q(
            "SELECT tp.nombre AS Metodo_Pago,"
            " COUNT(p.numero) AS Transacciones,"
            " SUM(p.monto) AS Total_Recaudado"
            " FROM pago p JOIN tipo_pago tp ON p.tipo = tp.numero"
            " GROUP BY tp.nombre ORDER BY Total_Recaudado DESC"
        )
        _, tots = _q("SELECT COALESCE(SUM(monto), 0) AS total FROM pago")
        cards = _cards([{'label': 'Total recaudado', 'val': _pesos(tots[0]['total']), 'sub': 'todos los metodos'}])
        return '<p><strong>Total recaudado por metodo de pago:</strong></p>%s%s' % (cards, _tabla(cols, rows, pesos=['Total_Recaudado']))

    # ── INGRESOS GENERAL ─────────────────────────────────────────────────────────
    if intent == 'ingresos_general':
        cols, rows = _q(
            "SELECT YEAR(fechapago) AS Anio, MONTH(fechapago) AS Mes,"
            " COUNT(*) AS Transacciones, SUM(monto) AS Total"
            " FROM pago GROUP BY YEAR(fechapago), MONTH(fechapago)"
            " ORDER BY Anio DESC, Mes DESC LIMIT 12"
        )
        return '<p><strong>Historial de ingresos:</strong></p>%s' % _tabla(cols, rows, pesos=['Total'])

    # ── BOLETOS MES ──────────────────────────────────────────────────────────────
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

    # ── BOLETOS GENERAL ──────────────────────────────────────────────────────────
    if intent == 'boletos_general':
        cols, rows = _q(
            "SELECT YEAR(fechaEmision) AS Anio, MONTH(fechaEmision) AS Mes,"
            " COUNT(*) AS Boletos, SUM(precio) AS Ingresos FROM ticket"
            " GROUP BY YEAR(fechaEmision), MONTH(fechaEmision)"
            " ORDER BY Anio DESC, Mes DESC LIMIT 12"
        )
        return '<p><strong>Historico de boletos:</strong></p>%s' % _tabla(cols, rows, pesos=['Ingresos'])

    # ── TERMINALES ───────────────────────────────────────────────────────────────
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

    # ── OCUPACIÓN (Fix #5 corregido) ────────────────────────────────────────────
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
            " LEFT JOIN autobus a ON v.autobus=a.numero"         # ← correcto: a.numero
            " LEFT JOIN modelo mo ON a.modelo=mo.numero"
            " LEFT JOIN viaje_asiento va ON va.viaje=v.numero AND va.ocupado=1"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(),INTERVAL 14 DAY)"
            " GROUP BY v.numero ORDER BY PctOcup DESC LIMIT 20"
        )
        return '<p><strong>Ocupacion ultimos 14 dias:</strong></p>%s' % _tabla(cols, rows, est=['Estado'])

    # ── AUTOBUSES POR MARCA ──────────────────────────────────────────────────────
    if intent == 'autobuses_marca':
        marcas_conocidas = ['volvo', 'mercedes', 'scania', 'dina', 'irizar', 'man', 'king long']
        marca_buscada = next((m for m in marcas_conocidas if m in q), None)
        if marca_buscada:
            cols, rows = _q(
                "SELECT a.numero AS Num_Autobus, a.placas AS Placas,"
                " mo.nombre AS Modelo, mo.numasientos AS Capacidad, ma.nombre AS Marca"
                " FROM autobus a"
                " JOIN modelo mo ON a.modelo = mo.numero"
                " JOIN marca ma ON mo.marca = ma.numero"
                " WHERE LOWER(ma.nombre) LIKE LOWER(%s) ORDER BY a.numero",
                ['%' + marca_buscada + '%']
            )
            if not rows:
                return '<p>No se encontraron autobuses de la marca <strong>%s</strong>.</p>' % marca_buscada.capitalize()
            return '<p><strong>Autobuses %s:</strong></p>%s%s' % (
                marca_buscada.capitalize(),
                _cards([{'label': marca_buscada.capitalize(), 'val': len(rows), 'sub': 'unidades'}]),
                _tabla(cols, rows)
            )
        cols, rows = _q(
            "SELECT ma.nombre AS Marca, COUNT(a.numero) AS Unidades"
            " FROM autobus a JOIN modelo mo ON a.modelo=mo.numero"
            " JOIN marca ma ON mo.marca=ma.numero"
            " GROUP BY ma.numero ORDER BY Unidades DESC"
        )
        return '<p><strong>Flota por marca:</strong></p>%s' % _tabla(cols, rows)

    # ── RUTAS LISTA ──────────────────────────────────────────────────────────────
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

    # ── CONDUCTORES (lista o con nombre específico) ──────────────────────────────
    if intent == 'conductores_lista':
        nombre = _extraer_nombre_conductor(pregunta)
        if nombre:
            # Si menciona un nombre, redirigir a viajes del conductor
            return _resolve('viajes_de_conductor', pregunta)
        cols, rows = _q(
            "SELECT c.registro AS Reg, CONCAT(c.conNombre,' ',c.conPrimerApell) AS Nombre,"
            " c.licNumero AS Licencia, c.licVencimiento AS VenceLic, c.fechaContrato AS Contrato"
            " FROM conductor c ORDER BY c.conNombre"
        )
        return '<p><strong>Conductores registrados:</strong></p>%s' % _tabla(cols, rows)

    # ── AUTOBUSES LISTA ──────────────────────────────────────────────────────────
    if intent == 'autobuses_lista':
        cols, rows = _q(
            "SELECT a.numero AS Num, a.placas AS Placas, m.nombre AS Marca,"
            " mo.nombre AS Modelo, mo.ano AS Anio, mo.numasientos AS Asientos"
            " FROM autobus a JOIN modelo mo ON a.modelo=mo.numero JOIN marca m ON mo.marca=m.numero"
            " ORDER BY a.numero"
        )
        return '<p><strong>Flota de autobuses:</strong></p>%s' % _tabla(cols, rows)

    # ── PASAJEROS LISTA ──────────────────────────────────────────────────────────
    if intent == 'pasajeros_lista':
        # Si menciona un número de viaje, redirigir
        num = _extraer_numero_viaje(pregunta.lower())
        if num:
            return _resolve('pasajeros_de_viaje', pregunta)

        anio_filtro = None
        match_anio = re.search(r'(despues|después|antes|posterior).*?(\d{4})', pregunta.lower())
        if match_anio:
            anio_filtro = int(re.search(r'\d{4}', match_anio.group(0)).group(0))
            es_despues = any(x in match_anio.group(1) for x in ['despues', 'después', 'posterior'])

        if anio_filtro:
            op = '>' if es_despues else '<'
            cols, rows = _q(
                "SELECT p.num AS Num, p.paNombre AS Nombre, p.paPrimerApell AS PrimerApellido,"
                " TIMESTAMPDIFF(YEAR, p.fechaNacimiento, CURDATE()) AS Edad,"
                " p.fechaNacimiento AS Nacimiento"
                " FROM pasajero p WHERE YEAR(p.fechaNacimiento) %s %%s"
                " ORDER BY p.fechaNacimiento DESC LIMIT 50" % op,
                [anio_filtro]
            )
            titulo = 'Pasajeros nacidos %s del %d:' % ('despues' if es_despues else 'antes', anio_filtro)
        else:
            cols, rows = _q(
                "SELECT p.num AS Num, CONCAT(p.paNombre,' ',p.paPrimerApell) AS Nombre,"
                " TIMESTAMPDIFF(YEAR, p.fechaNacimiento, CURDATE()) AS Edad,"
                " p.fechaNacimiento AS Nacimiento"
                " FROM pasajero p ORDER BY p.paNombre LIMIT 50"
            )
            titulo = 'Pasajeros (primeros 50):'
        return '<p><strong>%s</strong></p>%s' % (titulo, _tabla(cols, rows))

    # ── TAQUILLEROS SUPERVISORES ─────────────────────────────────────────────────
    if intent == 'taquilleros_supervisores':
        cols, rows = _q(
            "SELECT CONCAT(t.taqnombre,' ',t.taqprimerapell,' ',t.taqsegundoapell) AS Nombre_Completo,"
            " t.usuario AS Usuario, term.nombre AS Terminal, ci.nombre AS Ciudad"
            " FROM taquillero t"
            " JOIN terminal term ON t.terminal = term.numero"
            " JOIN ciudad ci ON term.ciudad = ci.clave"
            " WHERE t.supervisa = 1 ORDER BY ci.nombre, term.nombre"
        )
        if not rows:
            return '<p>No se encontraron taquilleros con rol de supervisor.</p>'
        return '<p><strong>Taquilleros supervisores:</strong></p>%s%s' % (
            _cards([{'label': 'Supervisores', 'val': len(rows), 'sub': 'taquilleros'}]),
            _tabla(cols, rows)
        )

    # ── CANCELADOS ───────────────────────────────────────────────────────────────
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

    # ── RETRASADOS ───────────────────────────────────────────────────────────────
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

    # ── MES ESPECÍFICO ───────────────────────────────────────────────────────────
    mm = re.match(r'mes_(\d{2})', intent)
    if mm:
        mn = int(mm.group(1))
        nombres = {1:'enero',2:'febrero',3:'marzo',4:'abril',5:'mayo',6:'junio',
                   7:'julio',8:'agosto',9:'septiembre',10:'octubre',11:'noviembre',12:'diciembre'}
        nom = nombres.get(mn, str(mn))
        anio_q = _extraer_anio(pregunta) or 2026
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " v.fecHoraSalida AS Salida, ev.nombre AS Estado, COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE MONTH(v.fecHoraSalida)=%s AND YEAR(v.fecHoraSalida)=%s"
            " GROUP BY v.numero ORDER BY v.fecHoraSalida",
            [mn, anio_q]
        )
        if not rows: return '<p>No hay viajes para %s %d.</p>' % (nom, anio_q)
        return '<p><strong>Viajes de %s %d:</strong></p>%s%s' % (
            nom, anio_q,
            _cards([{'label': nom.capitalize(), 'val': len(rows), 'sub': 'viajes'}]),
            _tabla(cols, rows, est=['Estado']))

    # ── AYER ─────────────────────────────────────────────────────────────────────
    if intent == 'ayer':
        from datetime import date, timedelta
        ayer = (date.today() - timedelta(days=1)).isoformat()
        _, r1 = _q("SELECT COUNT(*) AS n FROM viaje WHERE DATE(fecHoraSalida)=%s", [ayer])
        _, r2 = _q("SELECT COUNT(*) AS n FROM ticket WHERE DATE(fechaEmision)=%s", [ayer])
        _, r3 = _q("SELECT COALESCE(SUM(monto),0) AS n FROM pago WHERE DATE(fechapago)=%s", [ayer])
        cards = _cards([
            {'label':'Viajes ayer',  'val':r1[0]['n'],        'sub':ayer},
            {'label':'Boletos',      'val':r2[0]['n'],        'sub':'vendidos'},
            {'label':'Ingresos',     'val':_pesos(r3[0]['n']),'sub':'recaudados'},
        ])
        cols, rows = _q(
            "SELECT v.numero AS Num, CONCAT(co.nombre,' a ',cd.nombre) AS Ruta,"
            " TIME(v.fecHoraSalida) AS Hora, ev.nombre AS Estado, COUNT(t.codigo) AS Pasajeros"
            " FROM viaje v JOIN ruta r ON v.ruta=r.codigo"
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.numero"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " JOIN edo_viaje ev ON v.estado=ev.numero"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE DATE(v.fecHoraSalida)=%s GROUP BY v.numero ORDER BY v.fecHoraSalida",
            [ayer]
        )
        if not rows: return '<p><strong>Ayer (%s):</strong></p>%s<p>No hubo viajes.</p>' % (ayer, cards)
        return '<p><strong>Resumen de ayer (%s):</strong></p>%s%s' % (ayer, cards, _tabla(cols, rows, est=['Estado']))

    # ── VIAJES MAÑANA ────────────────────────────────────────────────────────────
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

    # ── SEMANA PASADA ────────────────────────────────────────────────────────────
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
            " FROM viaje v LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s"
            " GROUP BY DATE(v.fecHoraSalida) ORDER BY Fecha",
            [ini, fin]
        )
        return '<p><strong>Semana pasada (%s al %s):</strong></p>%s%s' % (ini, fin, cards, _tabla(cols, rows, pesos=['Ingresos']))

    # ── MES PASADO ───────────────────────────────────────────────────────────────
    if intent == 'mes_pasado':
        from datetime import date
        hoy = date.today()
        anio, mes = (hoy.year-1, 12) if hoy.month == 1 else (hoy.year, hoy.month-1)
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
            " JOIN terminal tor ON r.origen=tor.numero JOIN terminal tdes ON r.destino=tdes.nombre"
            " JOIN ciudad co ON tor.ciudad=co.clave JOIN ciudad cd ON tdes.ciudad=cd.clave"
            " LEFT JOIN ticket t ON t.viaje=v.numero"
            " WHERE MONTH(v.fecHoraSalida)=%s AND YEAR(v.fecHoraSalida)=%s"
            " GROUP BY r.codigo ORDER BY Viajes DESC LIMIT 10",
            [mes, anio]
        )
        return '<p><strong>Mes pasado — %s %s:</strong></p>%s%s' % (nom, anio, cards, _tabla(cols, rows))

    # ── ÚLTIMOS 7 DÍAS ───────────────────────────────────────────────────────────
    if intent == 'ultimos_7':
        cols, rows = _q(
            "SELECT DATE(v.fecHoraSalida) AS Fecha, COUNT(v.numero) AS Viajes,"
            " COUNT(t.codigo) AS Boletos, COALESCE(SUM(p.monto),0) AS Ingresos"
            " FROM viaje v LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)"
            " GROUP BY DATE(v.fecHoraSalida) ORDER BY Fecha"
        )
        return '<p><strong>Ultimos 7 dias:</strong></p>%s' % _tabla(cols, rows, pesos=['Ingresos'])

    # ── ÚLTIMOS 30 DÍAS ──────────────────────────────────────────────────────────
    if intent == 'ultimos_30':
        _, tots = _q(
            "SELECT COUNT(DISTINCT v.numero) AS viajes, COUNT(t.codigo) AS boletos,"
            " COALESCE(SUM(p.monto),0) AS ingresos"
            " FROM viaje v LEFT JOIN ticket t ON t.viaje=v.numero"
            " LEFT JOIN pago p ON p.numero=t.pago"
            " WHERE v.fecHoraSalida >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)"
        )
        tt = tots[0]
        cols, rows = _q(
            "SELECT DATE(v.fecHoraSalida) AS Fecha, COUNT(v.numero) AS Viajes,"
            " COUNT(t.codigo) AS Boletos, COALESCE(SUM(p.monto),0) AS Ingresos"
            " FROM viaje v LEFT JOIN ticket t ON t.viaje=v.numero"
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

    # ── INGRESOS SEMANA ──────────────────────────────────────────────────────────
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


# ─────────────────────────────────────────────────────────
# Vista principal del chat
# ─────────────────────────────────────────────────────────

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
            html = _ai_con_sql(pregunta, modelo_k)

        return JsonResponse({
            'html':   html,
            'intent': intent,
            'modelo': MODELOS_IA[modelo_k]['label'],
        })
    except Exception as e:
        return JsonResponse({'error': 'Error interno: %s' % str(e)}, status=500)
