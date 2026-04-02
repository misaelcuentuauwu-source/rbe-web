from django.shortcuts import render, redirect
from django.http import JsonResponse
from django.contrib import messages
from django.utils import timezone
from django.db import transaction
from django.core.mail import send_mail
from django.views.decorators.http import require_POST
from .models import Taquillero, Terminal, Viaje, Pasajero, Pago, Ticket, TipoPago, TipoPasajero, ViajeAsiento, Asiento, CuentaPasajero
from datetime import date, datetime, timedelta
import json
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .serializers import ViajeSerializer, ViajeListSerializer, TerminalSerializer
from django.http import FileResponse
from django.conf import settings
import os

def ok_view(request):
    path = os.path.join(settings.BASE_DIR, '..', 'pages', 'ok.html')
    return FileResponse(open(path, 'rb'))

def index_view(request):
    path = os.path.join(settings.BASE_DIR, '..', 'index.html')
    return FileResponse(open(path, 'rb'))

CLAVE_MAESTRA = "RutasBaja2024"

def login_requerido(view_func):
    def wrapper(request, *args, **kwargs):
        if not request.session.get('usuario_id'):
            return redirect('login')
        return view_func(request, *args, **kwargs)
    return wrapper

def admin_requerido(view_func):
    def wrapper(request, *args, **kwargs):
        if not request.session.get('usuario_id'):
            return redirect('login')
        if not request.session.get('supervisa'):
            return redirect('panel_principal')
        return view_func(request, *args, **kwargs)
    return wrapper

def login_view(request):
    if request.method == 'POST':
        usuario = request.POST.get('usuario', '').strip()
        contrasena = request.POST.get('contrasena', '').strip()
        try:
            taquillero = Taquillero.objects.get(usuario=usuario, contrasena=contrasena)
            request.session['usuario_id']       = taquillero.registro
            request.session['usuario_nombre']   = taquillero.taqnombre
            request.session['usuario_apellido'] = taquillero.taqprimerapell
            request.session['supervisa']        = bool(taquillero.supervisa)
            if taquillero.supervisa:
                return redirect('panel_admin')
            else:
                return redirect('panel_principal')
        except Taquillero.DoesNotExist:
            messages.error(request, 'Usuario o contraseña incorrectos')
    terminales = Terminal.objects.all()
    return render(request, 'taquilla/login.html', {'terminales': terminales})

def registro_view(request):
    if request.method == 'POST':
        clave = request.POST.get('clave_maestra', '')
        if clave != CLAVE_MAESTRA:
            messages.error(request, 'Clave maestra incorrecta')
            return redirect('login')
        nombre      = request.POST.get('nombre', '').strip()
        ap1         = request.POST.get('primer_apellido', '').strip()
        ap2         = request.POST.get('segundo_apellido', '').strip()
        usuario     = request.POST.get('usuario', '').strip()
        contrasena  = request.POST.get('contrasena', '').strip()
        terminal_id = request.POST.get('terminal')
        supervisa   = request.POST.get('supervisa') == 'on'
        if not all([nombre, ap1, usuario, contrasena]):
            messages.error(request, 'Completa los campos obligatorios')
            return redirect('login')
        Taquillero.objects.create(
            taqnombre=nombre, taqprimerapell=ap1, taqsegundoapell=ap2,
            fechacontrato=date.today(), usuario=usuario, contrasena=contrasena,
            terminal_id=terminal_id, supervisa=supervisa
        )
        messages.success(request, 'Taquillero registrado correctamente')
    return redirect('login')

def verificar_clave_maestra(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        clave = data.get('clave', '')
        if clave == CLAVE_MAESTRA:
            return JsonResponse({'ok': True})
        return JsonResponse({'ok': False, 'error': 'Clave maestra incorrecta'})
    return JsonResponse({'ok': False, 'error': 'Método no permitido'}, status=405)

def logout_view(request):
    request.session.flush()
    return redirect('login')

@login_requerido
def panel_principal(request):
    return render(request, 'taquilla/panel_principal.html')

@login_requerido
def dashboard(request):
    return render(request, 'taquilla/dash.html')

def salidas(request):
    return render(request, 'taquilla/salidas.html')

@admin_requerido
def panel_admin(request):
    tablas = [
        'marca','modelo','autobus','ciudad','conductor','ruta','viaje','asiento',
        'viaje_asiento','taquillero','tipo_pasajero','tipo_pago','edo_viaje',
        'ticket','pasajero','pago','terminal','tipo_asiento',
    ]
    taquillero = Taquillero.objects.get(registro=request.session['usuario_id'])
    return render(request, 'taquilla/panel_admin.html', {
        'tablas': tablas,
        'taquillero': taquillero,
    })

@require_POST
@admin_requerido
def actualizar_config(request):
    nombre     = request.POST.get('nombre', '').strip()
    ap1        = request.POST.get('primer_apellido', '').strip()
    ap2        = request.POST.get('segundo_apellido', '').strip()
    usuario    = request.POST.get('usuario', '').strip()
    contrasena = request.POST.get('contrasena', '').strip()
    if not all([nombre, ap1, usuario, contrasena]):
        return JsonResponse({'ok': False, 'error': 'Campos obligatorios incompletos'})
    try:
        taq = Taquillero.objects.get(registro=request.session['usuario_id'])
        taq.taqnombre       = nombre
        taq.taqprimerapell  = ap1
        taq.taqsegundoapell = ap2
        taq.usuario         = usuario
        taq.contrasena      = contrasena
        taq.save()
        request.session['usuario_nombre']   = nombre
        request.session['usuario_apellido'] = ap1
        return JsonResponse({'ok': True})
    except Exception as e:
        return JsonResponse({'ok': False, 'error': str(e)})

TABLAS_PERMITIDAS = [
    'marca','modelo','autobus','ciudad','conductor','ruta','viaje','asiento',
    'viaje_asiento','taquillero','tipo_pasajero','tipo_pago','edo_viaje',
    'ticket','pasajero','pago','terminal','tipo_asiento',
]

@admin_requerido
def crud_leer(request, tabla):
    if tabla not in TABLAS_PERMITIDAS:
        return JsonResponse({'error': 'Tabla no permitida'}, status=403)
    from django.db import connection
    with connection.cursor() as cur:
        cur.execute(f"SELECT * FROM `{tabla}` LIMIT 500")
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    for row in rows:
        for k, v in row.items():
            if hasattr(v, 'isoformat'):
                row[k] = v.isoformat()
    return JsonResponse({'cols': cols, 'rows': rows})

@admin_requerido
def crud_esquema(request, tabla):
    if tabla not in TABLAS_PERMITIDAS:
        return JsonResponse({'error': 'Tabla no permitida'}, status=403)
    from django.db import connection
    with connection.cursor() as cur:
        cur.execute(f"SHOW COLUMNS FROM `{tabla}`")
        cols_desc = [d[0] for d in cur.description]
        columnas = [dict(zip(cols_desc, r)) for r in cur.fetchall()]
        cur.execute("""
            SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
            FROM information_schema.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s
              AND REFERENCED_TABLE_NAME IS NOT NULL
        """, [tabla])
        fk_rows = cur.fetchall()
    fk_map = {r[0]: {'ref_table': r[1], 'ref_col': r[2]} for r in fk_rows}
    opciones = {}
    if fk_map:
        from django.db import connection as c2
        with c2.cursor() as cur2:
            for col, fk in fk_map.items():
                rt = fk['ref_table']
                rc = fk['ref_col']
                cur2.execute(f"SHOW COLUMNS FROM `{rt}`")
                rt_cols = [r[0] for r in cur2.fetchall()]
                display = next(
                    (c for c in rt_cols if c.lower() in ('nombre','name','descripcion','titulo','nom')),
                    next((c for c in rt_cols if c != rc), rc)
                )
                cur2.execute(f"SELECT `{rc}`, `{display}` FROM `{rt}` LIMIT 1000")
                opciones[col] = [{'value': r[0], 'label': str(r[1])} for r in cur2.fetchall()]
    return JsonResponse({'columnas': columnas, 'fk_map': fk_map, 'opciones': opciones})

@require_POST
@admin_requerido
def crud_insertar(request, tabla):
    if tabla not in TABLAS_PERMITIDAS:
        return JsonResponse({'error': 'Tabla no permitida'}, status=403)
    data = json.loads(request.body)
    fields = list(data.keys())
    vals   = list(data.values())
    sql = f"INSERT INTO `{tabla}` ({', '.join(f'`{f}`' for f in fields)}) VALUES ({', '.join(['%s']*len(vals))})"
    try:
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(sql, vals)
        return JsonResponse({'ok': True})
    except Exception as e:
        return JsonResponse({'ok': False, 'error': str(e)})

@require_POST
@admin_requerido
def crud_actualizar(request, tabla):
    if tabla not in TABLAS_PERMITIDAS:
        return JsonResponse({'error': 'Tabla no permitida'}, status=403)
    data     = json.loads(request.body)
    pk_name  = data.pop('__pk_name__')
    pk_value = data.pop('__pk_value__')
    setters  = [f"`{k}` = %s" for k in data]
    vals     = list(data.values()) + [pk_value]
    sql = f"UPDATE `{tabla}` SET {', '.join(setters)} WHERE `{pk_name}` = %s"
    try:
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(sql, vals)
        return JsonResponse({'ok': True})
    except Exception as e:
        return JsonResponse({'ok': False, 'error': str(e)})

@require_POST
@admin_requerido
def crud_eliminar(request, tabla):
    if tabla not in TABLAS_PERMITIDAS:
        return JsonResponse({'error': 'Tabla no permitida'}, status=403)
    data     = json.loads(request.body)
    pk_name  = data['pk_name']
    pk_value = data['pk_value']
    try:
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute(f"DELETE FROM `{tabla}` WHERE `{pk_name}` = %s", [pk_value])
        return JsonResponse({'ok': True})
    except Exception as e:
        return JsonResponse({'ok': False, 'error': str(e)})

@admin_requerido
def salidas_json(request):
    from django.db import connection
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with connection.cursor() as cur:
        cur.execute("""
            SELECT v.numero, v.fecHoraSalida, v.fecHoraEntrada,
                   corig.nombre AS origen_ciudad, cdest.nombre AS destino_ciudad,
                   tor.nombre AS origen_terminal, tdes.nombre AS destino_terminal,
                   ev.nombre AS estado,
                   CONCAT(c.conNombre,' ',c.conPrimerApell) AS conductor,
                   a.placas AS autobus_placas, a.numero AS autobus_num
            FROM viaje v
            JOIN ruta r       ON v.ruta = r.codigo
            JOIN terminal tor ON r.origen = tor.numero
            JOIN terminal tdes ON r.destino = tdes.numero
            JOIN ciudad corig ON tor.ciudad = corig.clave
            JOIN ciudad cdest ON tdes.ciudad = cdest.clave
            JOIN edo_viaje ev ON v.estado = ev.numero
            LEFT JOIN conductor c ON v.conductor = c.registro
            LEFT JOIN autobus a   ON v.autobus = a.numero
            WHERE v.fecHoraSalida >= %s
              AND LOWER(ev.nombre) NOT IN ('finalizado','completado','cancelado','terminado')
            ORDER BY v.fecHoraSalida ASC
            LIMIT 200
        """, [now])
        cols = [d[0] for d in cur.description]
        rows = []
        for r in cur.fetchall():
            row = dict(zip(cols, r))
            for k, v in row.items():
                if hasattr(v, 'isoformat'):
                    row[k] = v.isoformat()
            rows.append(row)
    return JsonResponse({'rows': rows})

@admin_requerido
def historial_json(request):
    from django.db import connection
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with connection.cursor() as cur:
        cur.execute("""
            SELECT v.numero, v.fecHoraSalida, v.fecHoraEntrada,
                   corig.nombre AS origen_ciudad, cdest.nombre AS destino_ciudad,
                   tor.nombre AS origen_terminal, tdes.nombre AS destino_terminal,
                   ev.nombre AS estado, v.ruta,
                   CONCAT(c.conNombre,' ',c.conPrimerApell) AS conductor,
                   a.placas AS autobus_placas, a.numero AS autobus_num,
                   mo.numasientos AS asientos_total,
                   COUNT(t.codigo) AS pasajeros_count
            FROM viaje v
            JOIN ruta r       ON v.ruta = r.codigo
            JOIN terminal tor ON r.origen = tor.numero
            JOIN terminal tdes ON r.destino = tdes.numero
            JOIN ciudad corig ON tor.ciudad = corig.clave
            JOIN ciudad cdest ON tdes.ciudad = cdest.clave
            JOIN edo_viaje ev ON v.estado = ev.numero
            LEFT JOIN conductor c ON v.conductor = c.registro
            LEFT JOIN autobus a   ON v.autobus = a.numero
            LEFT JOIN modelo mo   ON a.modelo = mo.numero
            LEFT JOIN ticket t    ON t.viaje = v.numero
            WHERE v.fecHoraSalida < %s
               OR LOWER(ev.nombre) IN ('finalizado','completado','cancelado','terminado')
            GROUP BY v.numero
            ORDER BY v.fecHoraSalida DESC
            LIMIT 500
        """, [now])
        cols = [d[0] for d in cur.description]
        rows = []
        for r in cur.fetchall():
            row = dict(zip(cols, r))
            for k, v in row.items():
                if hasattr(v, 'isoformat'):
                    row[k] = v.isoformat()
            rows.append(row)
    return JsonResponse({'rows': rows})

@admin_requerido
def agregar_viaje_opciones(request):
    from django.db import connection
    result = {}
    with connection.cursor() as cur:
        cur.execute("""
            SELECT r.codigo, CONCAT(corig.nombre,' \u2192 ',cdest.nombre) AS label, r.duracion
            FROM ruta r
            JOIN terminal tor  ON r.origen  = tor.numero
            JOIN terminal tdes ON r.destino = tdes.numero
            JOIN ciudad corig  ON tor.ciudad = corig.clave
            JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
        """)
        result['rutas'] = [{'value': r[0], 'label': r[1], 'duracion': r[2]} for r in cur.fetchall()]
        cur.execute("SELECT numero, placas FROM autobus ORDER BY numero")
        result['autobuses'] = [{'value': r[0], 'label': f"#{r[0]} ({r[1]})"} for r in cur.fetchall()]
        cur.execute("SELECT registro, CONCAT(conNombre,' ',conPrimerApell) AS n FROM conductor ORDER BY conNombre")
        result['conductores'] = [{'value': r[0], 'label': r[1]} for r in cur.fetchall()]
        cur.execute("SELECT numero, nombre FROM edo_viaje ORDER BY numero")
        result['estados'] = [{'value': r[0], 'label': r[1]} for r in cur.fetchall()]
    return JsonResponse(result)

@require_POST
@admin_requerido
def agregar_viaje(request):
    data = json.loads(request.body)
    salida    = data.get('salida')
    llegada   = data.get('llegada')
    ruta      = data.get('ruta')
    autobus   = data.get('autobus')
    conductor = data.get('conductor')
    estado    = data.get('estado')
    if not all([salida, llegada, ruta, autobus, conductor, estado]):
        return JsonResponse({'ok': False, 'error': 'Todos los campos son obligatorios'})
    try:
        from django.db import connection
        with connection.cursor() as cur:
            cur.execute("""
                INSERT INTO viaje (fecHoraSalida, fecHoraEntrada, ruta, estado, autobus, conductor)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, [salida, llegada, ruta, estado, autobus, conductor])
            trip_id = cur.lastrowid
            cur.execute("SELECT numero FROM asiento WHERE autobus = %s", [autobus])
            for (asiento_num,) in cur.fetchall():
                cur.execute(
                    "INSERT INTO viaje_asiento (asiento, viaje, ocupado) VALUES (%s, %s, FALSE)",
                    [asiento_num, trip_id]
                )
        return JsonResponse({'ok': True, 'viaje_id': trip_id})
    except Exception as e:
        return JsonResponse({'ok': False, 'error': str(e)})

@admin_requerido
def kpi_generales(request):
    desde = request.GET.get('desde')
    hasta = request.GET.get('hasta')
    if not desde or not hasta:
        hoy = date.today()
        desde = hasta = hoy.isoformat()
    from django.db import connection
    def qall(sql, params):
        with connection.cursor() as cur:
            cur.execute(sql, params)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]
    return JsonResponse({
        'boletos': qall("""
            SELECT ci.nombre AS ciudad, COUNT(*) AS total
            FROM ticket t JOIN viaje v ON v.numero=t.viaje
            JOIN ruta r ON r.codigo=v.ruta JOIN terminal ter ON ter.numero=r.destino
            JOIN ciudad ci ON ci.clave=ter.ciudad
            WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s
            GROUP BY ci.clave ORDER BY total DESC LIMIT 5
        """, [desde, hasta]),
        'conductores': qall("""
            SELECT CONCAT(c.conNombre,' ',c.conPrimerApell) AS nombre, COUNT(*) AS total
            FROM viaje v JOIN conductor c ON c.registro=v.conductor
            WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s
            GROUP BY v.conductor ORDER BY total DESC LIMIT 5
        """, [desde, hasta]),
        'autobuses': qall("""
            SELECT a.numero AS autobus_num, COUNT(*) AS total
            FROM viaje v JOIN autobus a ON a.numero=v.autobus
            WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s
            GROUP BY a.numero ORDER BY total DESC LIMIT 5
        """, [desde, hasta]),
        'destinos': qall("""
            SELECT ci.nombre AS nombre, COUNT(*) AS total
            FROM viaje v JOIN ruta r ON r.codigo=v.ruta
            JOIN terminal t ON t.numero=r.destino JOIN ciudad ci ON ci.clave=t.ciudad
            WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s
            GROUP BY ci.clave ORDER BY total DESC LIMIT 5
        """, [desde, hasta]),
        'origenes': qall("""
            SELECT ci.nombre AS nombre, COUNT(*) AS total
            FROM viaje v JOIN ruta r ON r.codigo=v.ruta
            JOIN terminal t ON t.numero=r.origen JOIN ciudad ci ON ci.clave=t.ciudad
            WHERE DATE(v.fecHoraSalida) BETWEEN %s AND %s
            GROUP BY ci.clave ORDER BY total DESC LIMIT 5
        """, [desde, hasta]),
        # ── Métricas económicas ───────────────────────────────────
        'eco_resumen': qall("""
            SELECT
                COALESCE(SUM(p.monto), 0)                          AS total_recaudado,
                COUNT(DISTINCT p.numero)                            AS num_transacciones,
                COUNT(t.codigo)                                     AS num_boletos,
                COALESCE(AVG(t.precio), 0)                         AS promedio_boleto,
                COALESCE(SUM(CASE WHEN p.tipo=1 THEN p.monto ELSE 0 END), 0) AS total_efectivo,
                COALESCE(SUM(CASE WHEN p.tipo=2 THEN p.monto ELSE 0 END), 0) AS total_tarjeta,
                COUNT(CASE WHEN p.tipo=1 THEN 1 END)               AS txn_efectivo,
                COUNT(CASE WHEN p.tipo=2 THEN 1 END)               AS txn_tarjeta
            FROM pago p
            LEFT JOIN ticket t ON t.pago = p.numero
            LEFT JOIN viaje v  ON v.numero = t.viaje
            WHERE DATE(p.fechapago) BETWEEN %s AND %s
        """, [desde, hasta]),
        'eco_taquilleros': qall("""
            SELECT
                CONCAT(taq.taqNombre,' ',taq.taqPrimerApell) AS nombre,
                COUNT(DISTINCT p.numero)  AS transacciones,
                COUNT(t.codigo)           AS boletos,
                COALESCE(SUM(p.monto), 0) AS total
            FROM pago p
            JOIN taquillero taq ON taq.registro = p.vendedor
            LEFT JOIN ticket t ON t.pago = p.numero
            WHERE DATE(p.fechapago) BETWEEN %s AND %s
            GROUP BY taq.registro
            ORDER BY total DESC LIMIT 5
        """, [desde, hasta]),
    })

@admin_requerido
def kpi_especificos(request):
    tipo      = request.GET.get('tipo', 'boletos')
    desde     = request.GET.get('desde', '')
    hasta     = request.GET.get('hasta', '')
    conductor = request.GET.get('conductor', '')
    autobus   = request.GET.get('autobus', '')
    ciudad    = request.GET.get('ciudad', '')
    aplicar   = request.GET.get('aplicar', '0') == '1'
    from django.db import connection
    where = []
    params = []
    if aplicar and desde and hasta:
        where.append("v.fecHoraSalida BETWEEN %s AND %s")
        params.extend([desde + ' 00:00:00', hasta + ' 23:59:59'])
    def qall(sql, p):
        with connection.cursor() as cur:
            cur.execute(sql, p)
            cols = [d[0] for d in cur.description]
            rows = []
            for r in cur.fetchall():
                row = dict(zip(cols, r))
                for k, v in row.items():
                    if hasattr(v, 'isoformat'):
                        row[k] = v.isoformat()
                rows.append(row)
            return rows
    w = ('WHERE ' + ' AND '.join(where)) if where else ''
    if tipo == 'boletos':
        rows = qall(f"""
            SELECT v.numero AS trip_id, v.fecHoraSalida AS departure,
                   corig.nombre AS origin_city, cdest.nombre AS dest_city,
                   a.numero AS bus_number, mo.numasientos AS seats_count,
                   COUNT(t.codigo) AS vendidos
            FROM viaje v
            LEFT JOIN ruta r ON v.ruta=r.codigo
            LEFT JOIN terminal tor ON r.origen=tor.numero
            LEFT JOIN terminal tdes ON r.destino=tdes.numero
            LEFT JOIN ciudad corig ON tor.ciudad=corig.clave
            LEFT JOIN ciudad cdest ON tdes.ciudad=cdest.clave
            LEFT JOIN autobus a ON v.autobus=a.numero
            LEFT JOIN modelo mo ON a.modelo=mo.numero
            LEFT JOIN ticket t ON t.viaje=v.numero
            {w} GROUP BY v.numero ORDER BY v.fecHoraSalida ASC
        """, params)
        for r in rows:
            r['disponibles'] = max(0, (r.get('seats_count') or 0) - (r.get('vendidos') or 0))
        return JsonResponse({'rows': rows, 'tipo': tipo})
    elif tipo == 'conductor':
        if conductor:
            where.append("v.conductor = %s"); params.append(conductor)
        w = ('WHERE ' + ' AND '.join(where)) if where else ''
        return JsonResponse({'rows': qall(f"""
            SELECT v.numero AS trip_id, v.fecHoraSalida AS departure,
                   v.fecHoraEntrada AS arrival,
                   corig.nombre AS origin_city, cdest.nombre AS dest_city,
                   a.numero AS bus_number,
                   c.conNombre AS con_nombre, c.conPrimerApell AS con_ap1
            FROM viaje v
            LEFT JOIN ruta r ON v.ruta=r.codigo
            LEFT JOIN terminal tor ON r.origen=tor.numero
            LEFT JOIN terminal tdes ON r.destino=tdes.numero
            LEFT JOIN ciudad corig ON tor.ciudad=corig.clave
            LEFT JOIN ciudad cdest ON tdes.ciudad=cdest.clave
            LEFT JOIN autobus a ON v.autobus=a.numero
            LEFT JOIN conductor c ON v.conductor=c.registro
            {w} ORDER BY v.fecHoraSalida ASC
        """, params), 'tipo': tipo})
    elif tipo == 'autobus':
        if autobus:
            where.append("v.autobus = %s"); params.append(autobus)
        w = ('WHERE ' + ' AND '.join(where)) if where else ''
        return JsonResponse({'rows': qall(f"""
            SELECT DISTINCT a.numero AS bus_number, a.placas,
                   mo.nombre AS modelo_nombre, mo.ano AS modelo_ano,
                   mo.numasientos, m.nombre AS marca_nombre
            FROM viaje v
            JOIN autobus a ON v.autobus=a.numero
            LEFT JOIN modelo mo ON a.modelo=mo.numero
            LEFT JOIN marca m ON mo.marca=m.numero
            {w} ORDER BY a.numero ASC
        """, params), 'tipo': tipo})
    elif tipo == 'ciudad':
        if ciudad:
            where.append("corig.clave = %s"); params.append(ciudad)
        w = ('WHERE ' + ' AND '.join(where)) if where else ''
        return JsonResponse({'rows': qall(f"""
            SELECT corig.nombre AS ciudad, v.fecHoraSalida AS salida,
                   v.numero AS viaje, cdest.nombre AS destino,
                   a.numero AS autobus, a.placas AS matricula,
                   CONCAT(c.conNombre,' ',c.conPrimerApell) AS operador
            FROM viaje v
            LEFT JOIN ruta r ON v.ruta=r.codigo
            LEFT JOIN terminal tor ON r.origen=tor.numero
            LEFT JOIN terminal tdes ON r.destino=tdes.numero
            LEFT JOIN ciudad corig ON tor.ciudad=corig.clave
            LEFT JOIN ciudad cdest ON tdes.ciudad=cdest.clave
            LEFT JOIN autobus a ON v.autobus=a.numero
            LEFT JOIN conductor c ON v.conductor=c.registro
            {w} ORDER BY v.fecHoraSalida ASC
        """, params), 'tipo': tipo})
    return JsonResponse({'rows': [], 'tipo': tipo})

@admin_requerido
def kpi_filtros_opciones(request):
    from django.db import connection
    with connection.cursor() as cur:
        cur.execute("SELECT registro, CONCAT(conNombre,' ',conPrimerApell) FROM conductor ORDER BY conNombre")
        conductores = [{'value': r[0], 'label': r[1]} for r in cur.fetchall()]
        cur.execute("SELECT numero, placas FROM autobus ORDER BY numero")
        autobuses = [{'value': r[0], 'label': f"#{r[0]} ({r[1]})"} for r in cur.fetchall()]
        cur.execute("SELECT clave, nombre FROM ciudad ORDER BY nombre")
        ciudades = [{'value': r[0], 'label': r[1]} for r in cur.fetchall()]
    return JsonResponse({'conductores': conductores, 'autobuses': autobuses, 'ciudades': ciudades})

@api_view(['GET'])
def api_viajes(request):
    origen   = request.GET.get('origen')
    destino  = request.GET.get('destino')   # puede ser 'todas' o None
    fecha    = request.GET.get('fecha')
    cercanos = request.GET.get('cercanos') == 'true'

    viajes = Viaje.objects.filter(estado=1)

    if origen:
        viajes = viajes.filter(ruta__origen__numero=origen)

    # Si destino es 'todas' o vacío, no filtramos por destino
    if destino and destino != 'todas':
        viajes = viajes.filter(ruta__destino__numero=destino)

    if fecha:
        fecha_dt  = datetime.strptime(fecha, '%Y-%m-%d')
        fecha_fin = fecha_dt + timedelta(days=1)
        viajes_fecha = viajes.filter(
            fechorasalida__gte=fecha_dt,
            fechorasalida__lt=fecha_fin
        )

        # ── Lógica de viajes cercanos ──────────────────────────
        if viajes_fecha.exists():
            # Hay viajes en la fecha exacta → respuesta normal
            serializer = ViajeListSerializer(viajes_fecha, many=True)
            return Response(serializer.data)

        elif cercanos:
            # No hay en la fecha exacta → buscar el día más cercano futuro
            viaje_cercano = viajes.filter(
                fechorasalida__gte=fecha_dt
            ).order_by('fechorasalida').first()

            if viaje_cercano:
                # Traer todos los viajes de ese mismo día
                fecha_real    = viaje_cercano.fechorasalida.date()
                fecha_real_fin = datetime.combine(fecha_real, datetime.max.time())
                fecha_real_ini = datetime.combine(fecha_real, datetime.min.time())
                viajes_cercanos = viajes.filter(
                    fechorasalida__gte=fecha_real_ini,
                    fechorasalida__lte=fecha_real_fin
                )
                serializer = ViajeListSerializer(viajes_cercanos, many=True)
                return Response({
                    'viajes':     serializer.data,
                    'fecha_real': str(fecha_real),
                    'exacta':     False,
                })
            else:
                # No hay ningún viaje futuro
                return Response({
                    'viajes':     [],
                    'fecha_real': None,
                    'exacta':     False,
                })
        else:
            # Sin cercanos, devolver lista vacía normal
            serializer = ViajeListSerializer([], many=True)
            return Response(serializer.data)

    # Sin fecha → devolver todos los que coincidan con origen/destino
    serializer = ViajeListSerializer(viajes, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def api_viaje_detalle(request, id):
    from django.db import connection
    try:
        with connection.cursor() as cur:
            # Datos del viaje
            cur.execute("""
                SELECT v.numero, v.fecHoraSalida, v.fecHoraEntrada,
                       r.precio, r.duracion,
                       tor.nombre AS origen_terminal,
                       corig.nombre AS origen_ciudad,
                       tdes.nombre AS destino_terminal,
                       cdest.nombre AS destino_ciudad
                FROM viaje v
                JOIN ruta r        ON v.ruta = r.codigo
                JOIN terminal tor  ON r.origen = tor.numero
                JOIN terminal tdes ON r.destino = tdes.numero
                JOIN ciudad corig  ON tor.ciudad = corig.clave
                JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
                WHERE v.numero = %s
            """, [id])
            row = cur.fetchone()
            if not row:
                return Response({'error': 'Viaje no encontrado'}, status=404)

            viaje_data = {
                'numero': row[0],
                'fechorasalida': str(row[1]),
                'fechoraentrada': str(row[2]),
                'ruta': {
                    'precio': str(row[3]),
                    'duracion': row[4],
                    'origen':  {'ciudad': {'nombre': row[6]}},
                    'destino': {'ciudad': {'nombre': row[8]}},
                }
            }

            # Asientos con estado ocupado REAL desde viaje_asiento
            cur.execute("""
                SELECT a.numero, ta.codigo AS tipo_codigo,
                       ta.descripcion AS tipo_desc,
                       va.ocupado
                FROM viaje_asiento va
                JOIN asiento a       ON va.asiento = a.numero
                JOIN tipo_asiento ta ON a.tipo = ta.codigo
                WHERE va.viaje = %s
                ORDER BY a.numero
            """, [id])

            asientos = []
            for r in cur.fetchall():
                asientos.append({
                    'ocupado': 1 if r[3] else 0,
                    'asiento': {
                        'numero': r[0],
                        'tipo': {
                            'codigo':      r[1],
                            'descripcion': r[2],
                        }
                    }
                })

            viaje_data['asientos'] = asientos
            # También devolver cuántos disponibles (útil para resultados_screen)
            viaje_data['asientos_disponibles'] = sum(
                1 for a in asientos if a['ocupado'] == 0
            )

        return Response(viaje_data)

    except Exception as e:
        return Response({'error': str(e)}, status=500)
@api_view(['GET'])
def api_terminales(request):
    terminales = Terminal.objects.all()
    serializer = TerminalSerializer(terminales, many=True)
    return Response(serializer.data)

@admin_requerido
def autobus_detalle(request, bus_id):
    from django.db import connection
    try:
        with connection.cursor() as cur:
            cur.execute("""
                SELECT a.numero, a.placas, ma.nombre AS marca,
                       mo.nombre AS modelo, mo.ano AS anio, mo.numasientos
                FROM autobus a
                JOIN modelo mo ON a.modelo = mo.numero
                JOIN marca  ma ON mo.marca  = ma.numero
                WHERE a.numero = %s
            """, [bus_id])
            row = cur.fetchone()
            if not row:
                return JsonResponse({'error': f'Autobús #{bus_id} no encontrado'}, status=404)
            numero, placas, marca, modelo, anio, num_asientos = row
            cur.execute("""
                SELECT ta.descripcion, ta.codigo, COUNT(*) AS cantidad
                FROM asiento a
                JOIN tipo_asiento ta ON a.tipo = ta.codigo
                WHERE a.autobus = %s
                GROUP BY a.tipo
                ORDER BY cantidad DESC
            """, [bus_id])
            tipos = [
                {'descripcion': r[0], 'codigo': r[1], 'cantidad': r[2]}
                for r in cur.fetchall()
            ]
        return JsonResponse({
            'numero':       numero,
            'placas':       placas,
            'marca':        marca,
            'modelo':       modelo,
            'anio':         anio,
            'num_asientos': num_asientos,
            'tipos_asiento': tipos,
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@admin_requerido
def viaje_pasajeros(request, viaje_id):
    from django.db import connection
    try:
        with connection.cursor() as cur:
            cur.execute("""
                SELECT corig.nombre, cdest.nombre,
                       v.fecHoraSalida, v.autobus
                FROM viaje v
                JOIN ruta r        ON v.ruta      = r.codigo
                JOIN terminal tor  ON r.origen     = tor.numero
                JOIN terminal tdes ON r.destino    = tdes.numero
                JOIN ciudad corig  ON tor.ciudad   = corig.clave
                JOIN ciudad cdest  ON tdes.ciudad  = cdest.clave
                WHERE v.numero = %s
            """, [viaje_id])
            info = cur.fetchone()
            if not info:
                return JsonResponse({'error': f'Viaje #{viaje_id} no encontrado'}, status=404)
            origen, destino, salida, autobus = info
            cur.execute("""
                SELECT
                    CONCAT(p.paNombre, ' ', p.paPrimerApell,
                           CASE WHEN p.paSegundoApell IS NOT NULL
                                THEN CONCAT(' ', p.paSegundoApell) ELSE '' END) AS nombre_completo,
                    TIMESTAMPDIFF(YEAR, p.fechaNacimiento, CURDATE()) AS edad,
                    t.codigo  AS numero_boleto,
                    t.asiento AS numero_asiento
                FROM ticket t
                JOIN pasajero p ON t.pasajero = p.num
                WHERE t.viaje = %s
                ORDER BY t.asiento ASC, p.paNombre ASC
            """, [viaje_id])
            cols = [d[0] for d in cur.description]
            pasajeros = [dict(zip(cols, r)) for r in cur.fetchall()]
        salida_str = salida.isoformat() if hasattr(salida, 'isoformat') else str(salida)
        return JsonResponse({
            'viaje': {
                'origen':  origen,
                'destino': destino,
                'salida':  salida_str,
                'autobus': autobus,
            },
            'pasajeros': pasajeros,
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


from .elipse_views import elipse_view, elipse_chat

@api_view(['POST'])
def api_login(request):
    usuario = request.data.get('usuario')
    contrasena = request.data.get('contrasena')
    try:
        taquillero = Taquillero.objects.get(usuario=usuario, contrasena=contrasena)
        return Response({
            'tipo': 'taquillero',
            'registro': taquillero.registro,
            'nombre': taquillero.taqnombre,
            'primer_apellido': taquillero.taqprimerapell,
            'segundo_apellido': taquillero.taqsegundoapell or '',
            'usuario': taquillero.usuario,
            'fecha_contrato': str(taquillero.fechacontrato),
            'terminal': {
                'numero': taquillero.terminal.numero,
                'nombre': taquillero.terminal.nombre,
                'ciudad': taquillero.terminal.ciudad.nombre,
            }
        })
    except Taquillero.DoesNotExist:
        return Response({'error': 'Credenciales incorrectas'}, status=401)


@api_view(['POST'])
def api_comprar(request):
    try:
        data = request.data
        viaje_id = data.get('viaje_id')
        tipo_pago_id = data.get('tipo_pago')
        pasajeros = data.get('pasajeros')
        monto_total = data.get('monto_total')
        vendedor_id = data.get('vendedor_id')
        correo_contacto = data.get('correo_contacto', '')

        with transaction.atomic():
            vendedor = None
            if vendedor_id:
                try:
                    vendedor = Taquillero.objects.get(registro=vendedor_id)
                except Taquillero.DoesNotExist:
                    vendedor = None

            pago = Pago.objects.create(
                fechapago=timezone.now(),
                monto=monto_total,
                tipo=TipoPago.objects.get(numero=tipo_pago_id),
                vendedor=vendedor
            )
            viaje = Viaje.objects.get(numero=viaje_id)
            tickets_creados = []

            es_primer_pasajero = True
            for p in pasajeros:
                ano_nacimiento = date.today().year - p['edad']

                if es_primer_pasajero and vendedor is None and vendedor_id:
                    try:
                        pasajero = Pasajero.objects.get(num=vendedor_id)
                    except Pasajero.DoesNotExist:
                        pasajero = Pasajero.objects.create(
                            panombre=p['nombre'],
                            paprimerapell=p['primer_apellido'],
                            pasegundoapell=p.get('segundo_apellido', None),
                            fechanacimiento=date(ano_nacimiento, 1, 1),
                        )
                else:
                    pasajero = Pasajero.objects.create(
                        panombre=p['nombre'],
                        paprimerapell=p['primer_apellido'],
                        pasegundoapell=p.get('segundo_apellido', None),
                        fechanacimiento=date(ano_nacimiento, 1, 1),
                    )

                es_primer_pasajero = False

                tipo_map = {'Adulto': 1, 'Estudiante': 4, 'INAPAM': 3, 'Discapacidad': 5}
                tipo_pasajero_id = tipo_map.get(p['tipo'], 1)
                tipo_pasajero = TipoPasajero.objects.get(num=tipo_pasajero_id)
                precio_base = viaje.ruta.precio
                descuento = tipo_pasajero.descuento
                precio_final = float(precio_base) * (1 - descuento / 100)
                asiento = Asiento.objects.get(numero=p['asiento_id'])
                ticket = Ticket.objects.create(
                    precio=precio_final,
                    fechaemision=timezone.now(),
                    asiento=asiento,
                    viaje=viaje,
                    pasajero=pasajero,
                    tipopasajero=tipo_pasajero,
                    pago=pago
                )
                tickets_creados.append(ticket)
                from django.db import connection
                with connection.cursor() as cur:
                    cur.execute(
                        "UPDATE viaje_asiento SET ocupado = 1 WHERE asiento = %s AND viaje = %s",
                        [asiento.numero, viaje.numero]
                    )

        if correo_contacto:
            try:
                fecha_viaje = viaje.fechorasalida.strftime('%d/%m/%Y')
                hora_salida = viaje.fechorasalida.strftime('%H:%M')
                hora_llegada = viaje.fechoraentrada.strftime('%H:%M')
                lista_pasajeros = ''
                for t in tickets_creados:
                    lista_pasajeros += (
                        f"  • {t.pasajero.panombre} {t.pasajero.paprimerapell}"
                        f" | Asiento {t.asiento.numero}"
                        f" | {t.tipopasajero.descripcion}"
                        f" | ${float(t.precio):.2f} MXN\n"
                    )
                mensaje = f"""
Hola, gracias por viajar con Rutas Baja Express 🚌

Tu compra ha sido confirmada exitosamente.

━━━━━━━━━━━━━━━━━━━━━━━━━━━
  FOLIO DE COMPRA: #{pago.numero}
━━━━━━━━━━━━━━━━━━━━━━━━━━━

🗺  RUTA
  {viaje.ruta.origen.ciudad.nombre} → {viaje.ruta.destino.ciudad.nombre}

📅  FECHA Y HORA
  {fecha_viaje}  |  Salida: {hora_salida}  →  Llegada: {hora_llegada}

👥  PASAJEROS
{lista_pasajeros}
💳  MÉTODO DE PAGO
  {pago.tipo.nombre}

💰  TOTAL PAGADO
  ${float(pago.monto):.2f} MXN

━━━━━━━━━━━━━━━━━━━━━━━━━━━

Preséntate en la terminal 30 minutos antes de la salida con este folio.

¡Buen viaje! 🌟
Rutas Baja Express
"""
                send_mail(
                    subject=f'✅ Confirmación de compra - Folio #{pago.numero} | Rutas Baja Express',
                    message=mensaje,
                    from_email=None,
                    recipient_list=[correo_contacto],
                    fail_silently=True,
                )
            except Exception as e:
                print(f'Error enviando correo: {e}')

        return Response({'success': True, 'pago_id': pago.numero}, status=201)

    except Exception as e:
        return Response({'error': str(e)}, status=400)


@api_view(['GET'])
def api_buscar_boleto(request, folio):
    try:
        pago = Pago.objects.get(numero=folio)
        tickets = Ticket.objects.filter(pago=pago)
        primer_ticket = tickets.first()
        if not primer_ticket:
            return Response({'error': 'No se encontraron tickets'}, status=404)
        viaje = primer_ticket.viaje
        resultado = {
            'folio': pago.numero,
            'fecha_pago': str(pago.fechapago),
            'monto': str(pago.monto),
            'metodo_pago': pago.tipo.nombre,
            'metodo_pago_id': pago.tipo.numero,
            'vendedor': f'{pago.vendedor.taqnombre} {pago.vendedor.taqprimerapell}' if pago.vendedor else 'App',
            'viaje': {
                'origen': viaje.ruta.origen.ciudad.nombre,
                'destino': viaje.ruta.destino.ciudad.nombre,
                'hora_salida': str(viaje.fechorasalida),
                'hora_llegada': str(viaje.fechoraentrada),
                'duracion': viaje.ruta.duracion,
            },
            'tickets': [
                {
                    'codigo': t.codigo,
                    'asiento': t.asiento.numero,
                    'tipo_asiento': t.asiento.tipo.descripcion,
                    'nombre': t.pasajero.panombre,
                    'primer_apellido': t.pasajero.paprimerapell,
                    'pasajero': f'{t.pasajero.panombre} {t.pasajero.paprimerapell}',
                    'tipo_pasajero': t.tipopasajero.descripcion,
                    'descuento': t.tipopasajero.descuento,
                    'precio': str(t.precio),
                }
                for t in tickets
            ]
        }
        return Response(resultado)
    except Pago.DoesNotExist:
        return Response({'error': 'Folio no encontrado'}, status=404)
    except Exception as e:
        return Response({'error': str(e)}, status=400)


@api_view(['POST'])
def api_cliente_google_login(request):
    try:
        data = request.data
        firebase_uid = data.get('firebase_uid')
        correo = data.get('correo')
        nombre = data.get('nombre', '')
        foto = data.get('foto', '')

        cuenta = CuentaPasajero.objects.filter(firebase_uid=firebase_uid).first()
        if not cuenta:
            cuenta = CuentaPasajero.objects.filter(correo=correo).first()

        if cuenta:
            if foto:
                cuenta.foto = foto
                cuenta.save()
            pasajero = cuenta.pasajero_num
        else:
            partes = nombre.strip().split(' ')
            panombre = partes[0] if len(partes) > 0 else 'Usuario'
            paprimerapell = partes[1] if len(partes) > 1 else 'RBE'
            pasajero = Pasajero.objects.create(
                panombre=panombre,
                paprimerapell=paprimerapell,
                fechanacimiento='2000-01-01',
            )
            cuenta = CuentaPasajero.objects.create(
                pasajero_num=pasajero,
                correo=correo,
                firebase_uid=firebase_uid,
                proveedor='google',
                foto=foto,
            )

        return Response({
            'tipo': 'cliente',
            'pasajero_num': cuenta.pasajero_num.num,
            'nombre': cuenta.pasajero_num.panombre,
            'primer_apellido': cuenta.pasajero_num.paprimerapell,
            'correo': cuenta.correo,
            'foto': cuenta.foto or '',
            'proveedor': cuenta.proveedor,
        })

    except Exception as e:
        return Response({'error': str(e)}, status=400)


@api_view(['GET'])
def api_historial_cliente(request, cliente_id):
    try:
        pagos = Pago.objects.filter(
            ticket__pasajero__num=cliente_id
        ).distinct().order_by('-fechapago')
        resultado = []
        for pago in pagos:
            tickets = Ticket.objects.filter(pago=pago)
            primer_ticket = tickets.first()
            if primer_ticket:
                viaje = primer_ticket.viaje
                resultado.append({
                    'folio': pago.numero,
                    'fecha': str(pago.fechapago),
                    'origen': viaje.ruta.origen.ciudad.nombre,
                    'destino': viaje.ruta.destino.ciudad.nombre,
                    'hora_salida': str(viaje.fechorasalida),
                    'monto': str(pago.monto),
                    'num_pasajeros': tickets.count(),
                    'metodo_pago': pago.tipo.nombre,
                    'estado': viaje.estado.nombre,
                    'estado_id': viaje.estado.numero,
                })
        return Response(resultado)
    except Exception as e:
        return Response({'error': str(e)}, status=400)


@api_view(['GET'])
def api_historial_taquillero(request, vendedor_id):
    try:
        pagos = Pago.objects.filter(vendedor__registro=vendedor_id).order_by('-fechapago')
        resultado = []
        for pago in pagos:
            tickets = Ticket.objects.filter(pago=pago)
            primer_ticket = tickets.first()
            if primer_ticket:
                viaje = primer_ticket.viaje
                resultado.append({
                    'folio': pago.numero,
                    'fecha': str(pago.fechapago),
                    'origen': viaje.ruta.origen.ciudad.nombre,
                    'destino': viaje.ruta.destino.ciudad.nombre,
                    'hora_salida': str(viaje.fechorasalida),
                    'monto': str(pago.monto),
                    'num_pasajeros': tickets.count(),
                    'metodo_pago': pago.tipo.nombre,
                    'estado': viaje.estado.nombre,
                    'estado_id': viaje.estado.numero,
                })
        return Response(resultado)
    except Exception as e:
        return Response({'error': str(e)}, status=400)
    
@api_view(['POST'])
def api_cliente_registro(request):
    try:
        data = request.data
        firebase_uid = data.get('firebase_uid', '')
        correo = data.get('correo', '')
        nombre = data.get('nombre', '')
        apellido = data.get('apellido', '')
        contrasena = data.get('contrasena', '')

        if not correo or not nombre or not apellido:
            return Response({'error': 'Faltan campos obligatorios'}, status=400)

        # Verificar si el correo ya existe en CuentaPasajero
        # (cubre tanto registro manual como registro previo con Google/Facebook)
        if CuentaPasajero.objects.filter(correo=correo).exists():
            return Response({'error': 'Este correo ya está registrado'}, status=400)

        # Crear el pasajero
        pasajero = Pasajero.objects.create(
            panombre=nombre,
            paprimerapell=apellido,
            fechanacimiento='2000-01-01',
        )

        # Crear la cuenta
        cuenta = CuentaPasajero.objects.create(
            pasajero_num=pasajero,
            correo=correo,
            firebase_uid=firebase_uid,
            proveedor='email',
            foto='',
        )

        return Response({
            'tipo': 'cliente',
            'pasajero_num': pasajero.num,
            'nombre': pasajero.panombre,
            'primer_apellido': pasajero.paprimerapell,
            'correo': cuenta.correo,
            'foto': '',
            'proveedor': 'email',
        }, status=201)

    except Exception as e:
        return Response({'error': str(e)}, status=400)

@api_view(['POST'])
def api_cliente_login_email(request):
    try:
        firebase_uid = request.data.get('firebase_uid')
        correo = request.data.get('correo')

        cuenta = None
        if firebase_uid:
            cuenta = CuentaPasajero.objects.filter(firebase_uid=firebase_uid).first()
        if not cuenta and correo:
            cuenta = CuentaPasajero.objects.filter(correo=correo).first()

        if not cuenta:
            return Response({'error': 'Usuario no encontrado'}, status=404)

        # Actualizar firebase_uid si se registró antes sin él
        if firebase_uid and not cuenta.firebase_uid:
            cuenta.firebase_uid = firebase_uid
            cuenta.save()

        return Response({
            'tipo': 'cliente',
            'pasajero_num': cuenta.pasajero_num.num,
            'nombre': cuenta.pasajero_num.panombre,
            'primer_apellido': cuenta.pasajero_num.paprimerapell,
            'correo': cuenta.correo,
            'foto': cuenta.foto or '',
            'proveedor': cuenta.proveedor,
        })

    except Exception as e:
        return Response({'error': str(e)}, status=400)
    
@api_view(['GET'])
def api_verificar_pasajero(request):
    correo = request.GET.get('correo', '').strip().lower()
    viaje_id = request.GET.get('viaje_id', '')

    if not correo or not viaje_id:
        return Response({'error': 'Faltan parámetros'}, status=400)

    try:
        # Buscar si hay alguna CuentaPasajero con ese correo
        # que tenga un ticket en ese viaje
        duplicado = Ticket.objects.filter(
            viaje__numero=viaje_id,
            pasajero__cuentapasajero__correo__iexact=correo
        ).exists()

        return Response({'duplicado': duplicado})

    except Exception as e:
        return Response({'error': str(e)}, status=400)


# ── Subir foto taquillero ─────────────────────────────────
@api_view(['POST'])
def api_subir_foto_taquillero(request, taquillero_id):
    try:
        taquillero = Taquillero.objects.get(registro=taquillero_id)
    except Taquillero.DoesNotExist:
        return Response({'error': 'Taquillero no encontrado'}, status=404)

    if 'foto' not in request.FILES:
        return Response({'error': 'No se envió ninguna foto'}, status=400)

    archivo = request.FILES['foto']
    carpeta = os.path.join(settings.MEDIA_ROOT, 'fotos_taquilleros')
    os.makedirs(carpeta, exist_ok=True)

    # Borrar foto anterior si existe
    if taquillero.foto:
        ruta_anterior = os.path.join(settings.MEDIA_ROOT, taquillero.foto)
        if os.path.exists(ruta_anterior):
            os.remove(ruta_anterior)

    nombre = f'taquillero_{taquillero_id}_{archivo.name}'
    ruta_relativa = f'fotos_taquilleros/{nombre}'
    ruta_completa = os.path.join(settings.MEDIA_ROOT, ruta_relativa)

    with open(ruta_completa, 'wb') as f:
        for chunk in archivo.chunks():
            f.write(chunk)

    taquillero.foto = ruta_relativa
    taquillero.save(update_fields=['foto'])

    foto_url = request.build_absolute_uri(f'{settings.MEDIA_URL}{ruta_relativa}')
    return Response({'foto_url': foto_url})


# ── Subir foto pasajero ───────────────────────────────────
@api_view(['POST'])
def api_subir_foto_pasajero(request, pasajero_num):
    try:
        cuenta = CuentaPasajero.objects.get(pasajero_num=pasajero_num)
    except CuentaPasajero.DoesNotExist:
        return Response({'error': 'Cuenta no encontrada'}, status=404)

    if 'foto' not in request.FILES:
        return Response({'error': 'No se envió ninguna foto'}, status=400)

    archivo = request.FILES['foto']
    carpeta = os.path.join(settings.MEDIA_ROOT, 'fotos_pasajeros')
    os.makedirs(carpeta, exist_ok=True)

    if cuenta.foto and not cuenta.foto.startswith('http'):
        ruta_anterior = os.path.join(settings.MEDIA_ROOT, cuenta.foto)
        if os.path.exists(ruta_anterior):
            os.remove(ruta_anterior)

    nombre = f'pasajero_{pasajero_num}_{archivo.name}'
    ruta_relativa = f'fotos_pasajeros/{nombre}'
    ruta_completa = os.path.join(settings.MEDIA_ROOT, ruta_relativa)

    with open(ruta_completa, 'wb') as f:
        for chunk in archivo.chunks():
            f.write(chunk)

    cuenta.foto = ruta_relativa
    cuenta.save(update_fields=['foto'])

    foto_url = request.build_absolute_uri(f'{settings.MEDIA_URL}{ruta_relativa}')
    return Response({'foto_url': foto_url})


# ── Enviar boleto por correo ──────────────────────────────
@api_view(['POST'])
def api_enviar_boleto_correo(request, pago_id):
    try:
        data = json.loads(request.body)
        correo_destino = data.get('correo', '')
        if not correo_destino:
            return Response({'error': 'Correo requerido'}, status=400)

        pago = Pago.objects.get(numero=pago_id)
        tickets = Ticket.objects.filter(pago=pago).select_related(
            'pasajero', 'asiento', 'viaje__ruta__origen', 'viaje__ruta__destino', 'tipopasajero'
        )

        lineas = [f'Folio de compra: #{pago_id}', '']
        for t in tickets:
            v = t.viaje
            lineas.append(f'Pasajero: {t.pasajero.panombre} {t.pasajero.paprimerapell}')
            lineas.append(f'Asiento: {t.asiento.numero}')
            lineas.append(f'Ruta: {v.ruta.origen.nombre} → {v.ruta.destino.nombre}')
            lineas.append(f'Salida: {v.fechorasalida.strftime("%d/%m/%Y %H:%M")}')
            lineas.append(f'Precio: ${t.precio}')
            lineas.append('')

        send_mail(
            subject=f'Tu boleto Rutas Baja Express - Folio #{pago_id}',
            message='\n'.join(lineas),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[correo_destino],
            fail_silently=False,
        )
        return Response({'ok': True, 'mensaje': f'Correo enviado a {correo_destino}'})

    except Pago.DoesNotExist:
        return Response({'error': 'Pago no encontrado'}, status=404)
    except Exception as e:
        return Response({'error': str(e)}, status=500)