from django.shortcuts import render, redirect
from django.contrib.auth.hashers import check_password, make_password
from django.http import JsonResponse
from django.contrib import messages
from django.utils import timezone
from django.db import transaction
from django.core.mail import send_mail, EmailMultiAlternatives
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
    return redirect('login')
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
        is_ajax = request.headers.get('X-Requested-With') == 'XMLHttpRequest' \
                  or 'application/json' in request.headers.get('Accept', '') \
                  or request.path.startswith('/api/')
        if not request.session.get('usuario_id'):
            if is_ajax:
                return JsonResponse({'error': 'no_sesion'}, status=401)
            return redirect('login')
        if not request.session.get('supervisa'):
            if is_ajax:
                return JsonResponse({'error': 'sin_permiso'}, status=403)
            return redirect('panel_principal')
        return view_func(request, *args, **kwargs)
    return wrapper

def login_view(request):
    if request.method == 'POST':
        usuario = request.POST.get('usuario', '').strip()
        contrasena = request.POST.get('contrasena', '').strip()
        try:
            taquillero = Taquillero.objects.get(usuario=usuario)
            if check_password(contrasena, taquillero.contrasena):
                request.session['usuario_id']       = taquillero.registro
                request.session['usuario_nombre']   = taquillero.taqnombre
                request.session['usuario_apellido'] = taquillero.taqprimerapell
                request.session['supervisa']        = bool(taquillero.supervisa)
                if taquillero.supervisa:
                    return redirect('panel_admin')
                else:
                    return redirect('panel_principal')
            else:
                messages.error(request, 'Usuario o contraseña incorrectos')
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
            fechacontrato=date.today(), usuario=usuario, contrasena=make_password(contrasena),
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
        'ticket','pasajero','pago','terminal','tipo_asiento','cuenta_pasajero',
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
    if not all([nombre, ap1, usuario]):
        return JsonResponse({'ok': False, 'error': 'Campos obligatorios incompletos'})
    try:
        taq = Taquillero.objects.get(registro=request.session['usuario_id'])
        taq.taqnombre       = nombre
        taq.taqprimerapell  = ap1
        taq.taqsegundoapell = ap2
        taq.usuario         = usuario
        # Solo actualizar contraseña si el usuario envió una nueva
        if contrasena:
            taq.contrasena = make_password(contrasena)
        taq.save()
        request.session['usuario_nombre']   = nombre
        request.session['usuario_apellido'] = ap1
        return JsonResponse({'ok': True})
    except Exception as e:
        return JsonResponse({'ok': False, 'error': str(e)})

TABLAS_PERMITIDAS = [
    'marca','modelo','autobus','ciudad','conductor','ruta','viaje','asiento',
    'viaje_asiento','taquillero','tipo_pasajero','tipo_pago','edo_viaje',
    'ticket','pasajero','pago','terminal','tipo_asiento','cuenta_pasajero',
]

@admin_requerido
def _get_fk_display_map(tabla):
    """
    Devuelve un dict  { col_name: { id_value: label_string } }
    para todas las FKs de `tabla`, resolviendo automáticamente el campo
    de visualización de la tabla referenciada.
    Abre su propio cursor para no interferir con el cursor del llamador.
    """
    from django.db import connection
    result = {}

    with connection.cursor() as cur:
        cur.execute("""
            SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
            FROM information_schema.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s
              AND REFERENCED_TABLE_NAME IS NOT NULL
        """, [tabla])
        fk_rows = cur.fetchall()

    for col, ref_table, ref_col in fk_rows:
        with connection.cursor() as cur:

            # ── Caso especial: ruta ──────────────────────────────────
            if ref_table == 'ruta':
                cur.execute("""
                    SELECT r.codigo,
                           CONCAT('#', r.codigo, ' — ', corig.nombre, ' → ', cdest.nombre)
                    FROM ruta r
                    JOIN terminal tor  ON r.origen  = tor.numero
                    JOIN terminal tdes ON r.destino = tdes.numero
                    JOIN ciudad corig  ON tor.ciudad = corig.clave
                    JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
                """)
                result[col] = {str(r[0]): r[1] for r in cur.fetchall()}
                continue

            # ── Caso especial: conductor → nombre completo ───────────
            if ref_table == 'conductor':
                cur.execute("""
                    SELECT registro, CONCAT(conNombre, ' ', conPrimerApell) FROM conductor
                """)
                result[col] = {str(r[0]): r[1] for r in cur.fetchall()}
                continue

            # ── Caso especial: taquillero → nombre completo ──────────
            if ref_table == 'taquillero':
                cur.execute("""
                    SELECT registro, CONCAT(taqNombre, ' ', taqPrimerApell) FROM taquillero
                """)
                result[col] = {str(r[0]): r[1] for r in cur.fetchall()}
                continue

            # ── Caso especial: pasajero → nombre completo ────────────
            if ref_table == 'pasajero':
                cur.execute("""
                    SELECT num, CONCAT(paNombre, ' ', paPrimerApell) FROM pasajero
                """)
                result[col] = {str(r[0]): r[1] for r in cur.fetchall()}
                continue

            # ── Genérico: buscar columna de display ──────────────────
            cur.execute(f"SHOW COLUMNS FROM `{ref_table}`")
            rt_cols = [r[0] for r in cur.fetchall()]
            display = next(
                (c for c in rt_cols if c.lower() in ('nombre', 'name', 'descripcion', 'titulo', 'nom')),
                next((c for c in rt_cols if c != ref_col), ref_col)
            )
            cur.execute(f"SELECT `{ref_col}`, `{display}` FROM `{ref_table}` LIMIT 2000")
            result[col] = {str(r[0]): str(r[1]) for r in cur.fetchall()}

    return result


@admin_requerido
def crud_leer(request, tabla):
    if tabla not in TABLAS_PERMITIDAS:
        return JsonResponse({'error': 'Tabla no permitida'}, status=403)

    modo = request.GET.get('modo', 'db')   # 'db' | 'legible'

    from django.db import connection
    with connection.cursor() as cur:

        # ── Modo DB: SELECT * puro (igual al DBMS) ──────────────
        if modo != 'legible':
            cur.execute(f"SELECT * FROM `{tabla}` LIMIT 500")
            cols = [d[0] for d in cur.description]
            rows = [dict(zip(cols, r)) for r in cur.fetchall()]

        # ── Modo Legible: queries con JOINs explícitos por tabla ──
        else:
            if tabla == 'modelo':
                cur.execute("""
                    SELECT m.numero, m.nombre, m.numasientos, m.ano, m.capacidad,
                           ma.nombre AS marca
                    FROM modelo m
                    JOIN marca ma ON ma.numero = m.marca
                    LIMIT 500
                """)
            elif tabla == 'ruta':
                cur.execute("""
                    SELECT r.codigo,
                           r.duracion,
                           CONCAT(tor.nombre, ' (', corig.nombre, ')') AS origen,
                           CONCAT(tdes.nombre, ' (', cdest.nombre, ')') AS destino,
                           r.precio
                    FROM ruta r
                    JOIN terminal tor  ON r.origen  = tor.numero
                    JOIN terminal tdes ON r.destino = tdes.numero
                    JOIN ciudad corig  ON tor.ciudad = corig.clave
                    JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
                    ORDER BY r.codigo
                    LIMIT 500
                """)
            elif tabla == 'pago':
                cur.execute("""
                    SELECT pg.numero,
                           pg.fechapago,
                           pg.monto,
                           tpg.nombre AS tipo,
                           CONCAT(t.taqNombre, ' ', t.taqPrimerApell) AS vendedor
                    FROM pago pg
                    JOIN tipo_pago tpg ON tpg.numero  = pg.tipo
                    LEFT JOIN taquillero t ON t.registro = pg.vendedor
                    LIMIT 500
                """)
            elif tabla == 'ticket':
                cur.execute("""
                    SELECT tk.codigo,
                           tk.precio,
                           tk.fechaEmision,
                           tk.asiento AS asiento,
                           CONCAT('#', v.numero, ' — ', corig.nombre, ' → ', cdest.nombre) AS viaje,
                           CONCAT(p.paNombre, ' ', p.paPrimerApell) AS pasajero,
                           tp.descripcion AS tipo_pasajero,
                           CONCAT('$', pg.monto, ' — ', tpg.nombre) AS pago
                    FROM ticket tk
                    JOIN viaje v         ON v.numero    = tk.viaje
                    JOIN ruta r          ON r.codigo    = v.ruta
                    JOIN terminal tor    ON r.origen    = tor.numero
                    JOIN terminal tdes   ON r.destino   = tdes.numero
                    JOIN ciudad corig    ON tor.ciudad  = corig.clave
                    JOIN ciudad cdest    ON tdes.ciudad = cdest.clave
                    JOIN pasajero p      ON p.num       = tk.pasajero
                    JOIN tipo_pasajero tp ON tp.num     = tk.tipopasajero
                    JOIN pago pg         ON pg.numero   = tk.pago
                    JOIN tipo_pago tpg   ON tpg.numero  = pg.tipo
                    LIMIT 500
                """)
            elif tabla == 'taquillero':
                cur.execute("""
                    SELECT t.registro, t.taqNombre, t.taqPrimerApell, t.taqSegundoApell,
                           t.fechaContrato, t.usuario,
                           ter.nombre AS terminal,
                           CASE t.supervisa WHEN 1 THEN 'Sí' ELSE 'No' END AS supervisa
                    FROM taquillero t
                    JOIN terminal ter ON ter.numero = t.terminal
                    LIMIT 500
                """)
            elif tabla == 'viaje_asiento':
                cur.execute("""
                    SELECT va.asiento,
                           CONCAT('#', v.numero, ' — ', corig.nombre, ' → ', cdest.nombre) AS viaje,
                           CASE va.ocupado WHEN 1 THEN 'Ocupado' ELSE 'Libre' END AS ocupado
                    FROM viaje_asiento va
                    JOIN viaje v       ON v.numero   = va.viaje
                    JOIN ruta r        ON r.codigo   = v.ruta
                    JOIN terminal tor  ON r.origen   = tor.numero
                    JOIN terminal tdes ON r.destino  = tdes.numero
                    JOIN ciudad corig  ON tor.ciudad = corig.clave
                    JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
                    LIMIT 500
                """)
            elif tabla == 'asiento':
                cur.execute("""
                    SELECT a.numero,
                           ta.descripcion AS tipo,
                           CONCAT(b.numero, ' — ', b.placas) AS autobus
                    FROM asiento a
                    JOIN tipo_asiento ta ON ta.codigo = a.tipo
                    JOIN autobus b       ON b.numero  = a.autobus
                    LIMIT 500
                """)
            elif tabla == 'viaje':
                cur.execute("""
                    SELECT v.numero,
                           v.fecHoraSalida,
                           v.fecHoraEntrada,
                           CONCAT('#', r.codigo, ' — ', corig.nombre, ' → ', cdest.nombre) AS ruta,
                           ev.nombre AS estado,
                           CONCAT(a.numero, ' — ', a.placas) AS autobus,
                           CONCAT(c.conNombre, ' ', c.conPrimerApell) AS conductor
                    FROM viaje v
                    JOIN ruta r        ON r.codigo   = v.ruta
                    JOIN terminal tor  ON r.origen   = tor.numero
                    JOIN terminal tdes ON r.destino  = tdes.numero
                    JOIN ciudad corig  ON tor.ciudad = corig.clave
                    JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
                    JOIN edo_viaje ev  ON ev.numero  = v.estado
                    LEFT JOIN autobus a   ON a.numero  = v.autobus
                    LEFT JOIN conductor c ON c.registro = v.conductor
                    LIMIT 500
                """)
            elif tabla == 'cuenta_pasajero':
                cur.execute("""
                    SELECT cp.pasajero_num,
                           CONCAT(p.paNombre, ' ', p.paPrimerApell) AS pasajero,
                           cp.correo,
                           cp.proveedor,
                           CASE WHEN cp.foto IS NOT NULL AND cp.foto != '' THEN 'Sí' ELSE 'No' END AS tiene_foto,
                           cp.firebase_uid
                    FROM cuenta_pasajero cp
                    JOIN pasajero p ON p.num = cp.pasajero_num
                    ORDER BY cp.pasajero_num
                    LIMIT 500
                """)
            else:
                # Fallback: mismo que DB hasta agregar más tablas
                cur.execute(f"SELECT * FROM `{tabla}` LIMIT 500")

            cols = [d[0] for d in cur.description]
            rows = [dict(zip(cols, r)) for r in cur.fetchall()]

    for row in rows:
        for k, v in row.items():
            if hasattr(v, 'isoformat'):
                row[k] = v.isoformat()

    return JsonResponse({'cols': cols, 'rows': rows, 'modo': modo})
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

                # Caso especial: ruta → mostrar origen → destino
                if rt == 'ruta':
                    cur2.execute("""
                        SELECT r.codigo,
                               CONCAT('#', r.codigo, ' — ', corig.nombre, ' → ', cdest.nombre, ' (', r.duracion, ')')
                        FROM ruta r
                        JOIN terminal tor  ON r.origen  = tor.numero
                        JOIN terminal tdes ON r.destino = tdes.numero
                        JOIN ciudad corig  ON tor.ciudad = corig.clave
                        JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
                        ORDER BY r.codigo
                    """)
                    opciones[col] = [{'value': r[0], 'label': r[1]} for r in cur2.fetchall()]
                    continue

                # Caso especial: conductor → mostrar nombre completo con apellidos
                if rt == 'conductor':
                    cur2.execute("""
                        SELECT registro,
                               CONCAT(conNombre, ' ', conPrimerApell,
                                      IFNULL(CONCAT(' ', conSegundoApell), '')) AS label
                        FROM conductor ORDER BY conNombre
                    """)
                    opciones[col] = [{'value': r[0], 'label': r[1].strip()} for r in cur2.fetchall()]
                    continue

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
    # Hashear contrasena al insertar un taquillero nuevo
    if tabla == 'taquillero' and 'contrasena' in data and data['contrasena']:
        from django.contrib.auth.hashers import make_password as _mkpass
        data['contrasena'] = _mkpass(data['contrasena'])
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

    try:
        from django.db import connection
        with connection.cursor() as cur:

            # ── RF-WEB-24: Solo editar viaje si está Programado ───────
            if tabla == 'viaje':
                cur.execute("""
                    SELECT LOWER(ev.nombre) FROM viaje v
                    JOIN edo_viaje ev ON ev.numero = v.estado
                    WHERE v.numero = %s
                """, [pk_value])
                row = cur.fetchone()
                if not row:
                    return JsonResponse({'ok': False, 'error': 'Viaje no encontrado'})

                estado_actual = row[0]

                if estado_actual not in ('programado',):
                    return JsonResponse({
                        'ok': False,
                        'error': f'No se puede editar un viaje en estado "{estado_actual.capitalize()}". Solo se permiten cambios en viajes disponibles.'
                    })

                # ── RF-WEB-25: Validar transición de estado ───────────
                if 'estado' in data:
                    cur.execute(
                        "SELECT LOWER(nombre) FROM edo_viaje WHERE numero = %s", [data['estado']]
                    )
                    nuevo_estado = cur.fetchone()
                    if nuevo_estado:
                        nuevo_estado = nuevo_estado[0]
                        transiciones_validas = {
                            'programado': ['programado', 'en curso', 'cancelado'],
                            'en curso':   ['en curso', 'completado', 'finalizado'],
                        }
                        permitidos = transiciones_validas.get(estado_actual, [])
                        if nuevo_estado not in permitidos:
                            return JsonResponse({
                                'ok': False,
                                'error': f'Transición no permitida: "{estado_actual.capitalize()}" → "{nuevo_estado.capitalize()}".'
                            })

        # Hashear contrasena si viene con valor nuevo (taquillero)
        if tabla == 'taquillero' and 'contrasena' in data and data['contrasena']:
            from django.contrib.auth.hashers import make_password as _mkpass
            data['contrasena'] = _mkpass(data['contrasena'])

        setters = [f"`{k}` = %s" for k in data]
        vals    = list(data.values()) + [pk_value]
        sql = f"UPDATE `{tabla}` SET {', '.join(setters)} WHERE `{pk_name}` = %s"

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
    data          = json.loads(request.body)
    pk_name       = data['pk_name']
    pk_value      = data['pk_value']
    modo_eliminar = data.get('modo_eliminar', 'restrict')

    def get_refs(cur, t, col):
        """Devuelve [(tabla_hija, columna_fk)] que referencian a t.col"""
        cur.execute("""
            SELECT TABLE_NAME, COLUMN_NAME
            FROM information_schema.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA           = DATABASE()
              AND REFERENCED_TABLE_NAME  = %s
              AND REFERENCED_COLUMN_NAME = %s
        """, [t, col])
        return cur.fetchall()

    def get_pk(cur, t):
        cur.execute("""
            SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = %s
              AND CONSTRAINT_NAME = 'PRIMARY'
            LIMIT 1
        """, [t])
        row = cur.fetchone()
        return row[0] if row else None

    def contar_hijos_total(cur, t, col, val):
        """Cuenta todos los descendientes (recursivo)."""
        total = 0
        refs = get_refs(cur, t, col)
        for ref_t, ref_c in refs:
            cur.execute(f"SELECT COUNT(*) FROM `{ref_t}` WHERE `{ref_c}` = %s", [val])
            n = cur.fetchone()[0]
            if n > 0:
                total += n
                # buscar hijos de los hijos
                ref_pk = get_pk(cur, ref_t)
                if ref_pk:
                    cur.execute(f"SELECT `{ref_pk}` FROM `{ref_t}` WHERE `{ref_c}` = %s", [val])
                    for (child_id,) in cur.fetchall():
                        total += contar_hijos_total(cur, ref_t, ref_pk, child_id)
        return total

    def delete_cascade(cur, t, col, val):
        """Borra recursivamente todos los hijos antes de borrar el padre."""
        refs = get_refs(cur, t, col)
        ref_pk = get_pk(cur, t)
        for ref_t, ref_c in refs:
            # obtener IDs de los hijos para recursion
            if ref_pk:
                cur.execute(f"SELECT `{ref_pk}` FROM `{t}` WHERE `{col}` = %s", [val])
                # no es necesario aqui; iteramos sobre los hijos del hijo
                pass
            # borrar hijos de los hijos primero
            ref_ref_pk = get_pk(cur, ref_t)
            if ref_ref_pk:
                cur.execute(f"SELECT `{ref_ref_pk}` FROM `{ref_t}` WHERE `{ref_c}` = %s", [val])
                nietos_ids = [r[0] for r in cur.fetchall()]
                for nieto_id in nietos_ids:
                    delete_cascade(cur, ref_t, ref_ref_pk, nieto_id)
            cur.execute(f"DELETE FROM `{ref_t}` WHERE `{ref_c}` = %s", [val])
        cur.execute(f"DELETE FROM `{t}` WHERE `{col}` = %s", [val])

    try:
        from django.db import connection
        with connection.cursor() as cur:

            if modo_eliminar == 'restrict':
                # Verificar hijos directos; si los hay, informar y detener
                refs = get_refs(cur, tabla, pk_name)
                conflictos = []
                for ref_t, ref_c in refs:
                    cur.execute(
                        f"SELECT COUNT(*) FROM `{ref_t}` WHERE `{ref_c}` = %s", [pk_value]
                    )
                    n = cur.fetchone()[0]
                    if n > 0:
                        conflictos.append(f'{n} registro(s) en "{ref_t}"')
                if conflictos:
                    return JsonResponse({
                        'ok': False,
                        'error': (
                            'No se puede eliminar porque existen dependencias: '
                            + ', '.join(conflictos) +
                            '. Usa CASCADE para borrarlos también, o SET NULL para desvincularlos.'
                        )
                    })
                cur.execute(f"DELETE FROM `{tabla}` WHERE `{pk_name}` = %s", [pk_value])

            elif modo_eliminar == 'cascade':
                # Desactivar FK checks para evitar conflictos de orden en MySQL
                cur.execute("SET FOREIGN_KEY_CHECKS = 0")
                try:
                    delete_cascade(cur, tabla, pk_name, pk_value)
                finally:
                    cur.execute("SET FOREIGN_KEY_CHECKS = 1")

            elif modo_eliminar == 'setnull':
                # Desactivar FK checks y poner NULL en todos los hijos directos
                cur.execute("SET FOREIGN_KEY_CHECKS = 0")
                try:
                    refs = get_refs(cur, tabla, pk_name)
                    for ref_t, ref_c in refs:
                        cur.execute(
                            f"UPDATE `{ref_t}` SET `{ref_c}` = NULL WHERE `{ref_c}` = %s",
                            [pk_value]
                        )
                    cur.execute(f"DELETE FROM `{tabla}` WHERE `{pk_name}` = %s", [pk_value])
                finally:
                    cur.execute("SET FOREIGN_KEY_CHECKS = 1")

            else:
                return JsonResponse({'ok': False, 'error': 'Modo de eliminación no reconocido'})

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
                   ev.nombre AS estado, v.ruta,
                   CONCAT(c.conNombre,' ',c.conPrimerApell) AS conductor,
                   a.placas AS autobus_placas, a.numero AS autobus_num,
                   r.precio AS precio_ruta
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
            WHERE LOWER(ev.nombre) IN ('en curso','completado','finalizado','cancelado','terminado')
            GROUP BY v.numero
            ORDER BY v.fecHoraSalida DESC
            LIMIT 500
        """, [])
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

            # ── Validar conflicto de CONDUCTOR ────────────────────────
            cur.execute("""
                SELECT numero FROM viaje
                WHERE conductor = %s
                  AND estado NOT IN (
                      SELECT numero FROM edo_viaje
                      WHERE LOWER(nombre) IN ('cancelado', 'completado', 'finalizado', 'terminado')
                  )
                  AND fecHoraSalida < %s
                  AND fecHoraEntrada > %s
            """, [conductor, llegada, salida])

            conflicto_conductor = cur.fetchone()
            if conflicto_conductor:
                cur.execute("""
                    SELECT CONCAT(conNombre, ' ', conPrimerApell) FROM conductor WHERE registro = %s
                """, [conductor])
                nombre = cur.fetchone()
                nombre_str = nombre[0] if nombre else f'ID {conductor}'
                return JsonResponse({
                    'ok': False,
                    'error': f'El conductor {nombre_str} ya tiene asignado el viaje #{conflicto_conductor[0]} en ese horario.'
                })

            # ── Validar conflicto de AUTOBÚS ──────────────────────────
            cur.execute("""
                SELECT numero FROM viaje
                WHERE autobus = %s
                  AND estado NOT IN (
                      SELECT numero FROM edo_viaje
                      WHERE LOWER(nombre) IN ('cancelado', 'completado', 'finalizado', 'terminado')
                  )
                  AND fecHoraSalida < %s
                  AND fecHoraEntrada > %s
            """, [autobus, llegada, salida])

            conflicto_autobus = cur.fetchone()
            if conflicto_autobus:
                cur.execute("SELECT placas FROM autobus WHERE numero = %s", [autobus])
                placas = cur.fetchone()
                placas_str = placas[0] if placas else f'#{autobus}'
                return JsonResponse({
                    'ok': False,
                    'error': f'El autobús {placas_str} ya está asignado al viaje #{conflicto_autobus[0]} en ese horario.'
                })

            # ── Sin conflictos: insertar el viaje ─────────────────────
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
    elif tipo == 'ventas':
        sujeto_tipo = request.GET.get('sujeto_tipo', '')  # 'taquillero' | 'cliente'
        sujeto_id   = request.GET.get('sujeto_id', '')
        ruta_id     = request.GET.get('ruta_id', '')

        pagos = Pago.objects.order_by('-fechapago')

        if sujeto_tipo == 'taquillero' and sujeto_id:
            pagos = pagos.filter(vendedor__registro=sujeto_id)
        elif sujeto_tipo == 'cliente' and sujeto_id:
            pagos = pagos.filter(ticket__pasajero__num=sujeto_id).distinct()

        if ruta_id:
            pagos = pagos.filter(ticket__viaje__ruta__codigo=ruta_id).distinct()

        # Filtro de taquillero adicional (usado cuando sujeto_tipo='cliente' y se quiere ver qué taquillero vendió)
        vendedor_id = request.GET.get('vendedor_id', '')
        if vendedor_id:
            pagos = pagos.filter(vendedor__registro=vendedor_id)

        if aplicar and desde and hasta:
            pagos = pagos.filter(fechapago__date__gte=desde, fechapago__date__lte=hasta)

        rows = []
        for pago in pagos:
            tickets = Ticket.objects.filter(pago=pago).select_related(
                'viaje__ruta__origen__ciudad',
                'viaje__ruta__destino__ciudad',
                'viaje__estado',
            )
            primer_ticket = tickets.first()
            if primer_ticket:
                viaje   = primer_ticket.viaje
                origen  = viaje.ruta.origen.ciudad.nombre
                destino = viaje.ruta.destino.ciudad.nombre
                salida  = str(viaje.fechorasalida)
                estado  = viaje.estado.nombre
            else:
                origen = destino = salida = estado = ''

            rows.append({
                'folio':          pago.numero,
                'fecha':          str(pago.fechapago),
                'origen':         origen,
                'destino':        destino,
                'hora_salida':    salida,
                'estado':         estado,
                'num_pasajeros':  tickets.count(),
                'monto':          str(pago.monto),
                'metodo_pago':    pago.tipo.nombre,
                'vendedor_id':    pago.vendedor.registro if pago.vendedor else None,
                'vendedor_nombre': f'{pago.vendedor.taqnombre} {pago.vendedor.taqprimerapell}' if pago.vendedor else 'App',
            })
        return JsonResponse({'rows': rows, 'tipo': tipo})

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
        cur.execute("SELECT registro, CONCAT(taqNombre,' ',taqPrimerApell), usuario FROM taquillero ORDER BY taqNombre")
        taquilleros = [{'value': r[0], 'label': f"{r[1]} (@{r[2]})"} for r in cur.fetchall()]
        cur.execute("""
            SELECT cp.pasajero_num, CONCAT(p.paNombre,' ',p.paPrimerApell), cp.correo
            FROM cuenta_pasajero cp
            JOIN pasajero p ON cp.pasajero_num = p.num
            ORDER BY p.paNombre
        """)
        clientes = [{'value': r[0], 'label': f"{r[1]} ({r[2]})"} for r in cur.fetchall()]
        cur.execute('''
            SELECT r.codigo,
                   CONCAT(corig.nombre, ' > ', cdest.nombre) AS label
            FROM ruta r
            JOIN terminal tor  ON r.origen  = tor.numero
            JOIN terminal tdes ON r.destino = tdes.numero
            JOIN ciudad corig  ON tor.ciudad = corig.clave
            JOIN ciudad cdest  ON tdes.ciudad = cdest.clave
            ORDER BY corig.nombre, cdest.nombre
        ''')
        rutas = [{'value': r[0], 'label': r[1]} for r in cur.fetchall()]
    return JsonResponse({'conductores': conductores, 'autobuses': autobuses, 'ciudades': ciudades, 'taquilleros': taquilleros, 'clientes': clientes, 'rutas': rutas})

@api_view(['GET'])
def api_viajes(request):
    origen   = request.GET.get('origen')
    destino  = request.GET.get('destino')
    fecha    = request.GET.get('fecha')
    cercanos = request.GET.get('cercanos') == 'true'
    viajes = Viaje.objects.filter(estado=1)
    if origen:
        viajes = viajes.filter(ruta__origen__numero=origen)
    if destino and destino != 'todas':
        viajes = viajes.filter(ruta__destino__numero=destino)
    if fecha:
        fecha_dt  = datetime.strptime(fecha, '%Y-%m-%d')
        fecha_fin = fecha_dt + timedelta(days=1)

        # Si buscan para hoy, filtrar desde ahora + 1 hora
        hoy = datetime.now().date()
        if fecha_dt.date() == hoy:
            desde = datetime.now() + timedelta(hours=1)
        else:
            desde = fecha_dt

        viajes_fecha = viajes.filter(fechorasalida__gte=desde, fechorasalida__lt=fecha_fin)
        if viajes_fecha.exists():
            serializer = ViajeListSerializer(viajes_fecha, many=True)
            return Response(serializer.data)
        elif cercanos:
            # También aplicar el filtro de 1 hora para viajes cercanos
            viaje_cercano = viajes.filter(fechorasalida__gte=desde).order_by('fechorasalida').first()
            if viaje_cercano:
                fecha_real     = viaje_cercano.fechorasalida.date()
                fecha_real_fin = datetime.combine(fecha_real, datetime.max.time())
                fecha_real_ini = datetime.combine(fecha_real, datetime.min.time())
                viajes_cercanos = viajes.filter(fechorasalida__gte=fecha_real_ini, fechorasalida__lte=fecha_real_fin)
                serializer = ViajeListSerializer(viajes_cercanos, many=True)
                return Response({'viajes': serializer.data, 'fecha_real': str(fecha_real), 'exacta': False})
            else:
                return Response({'viajes': [], 'fecha_real': None, 'exacta': False})
        else:
            return Response(ViajeListSerializer([], many=True).data)
    serializer = ViajeListSerializer(viajes, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def api_viaje_detalle(request, id):
    from django.db import connection
    try:
        with connection.cursor() as cur:
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
            cur.execute("""
                SELECT a.numero, ta.codigo AS tipo_codigo,
                       ta.descripcion AS tipo_desc, va.ocupado
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
                    'asiento': {'numero': r[0], 'tipo': {'codigo': r[1], 'descripcion': r[2]}}
                })
            viaje_data['asientos'] = asientos
            viaje_data['asientos_disponibles'] = sum(1 for a in asientos if a['ocupado'] == 0)
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
                GROUP BY a.tipo ORDER BY cantidad DESC
            """, [bus_id])
            tipos = [{'descripcion': r[0], 'codigo': r[1], 'cantidad': r[2]} for r in cur.fetchall()]
        return JsonResponse({'numero': numero, 'placas': placas, 'marca': marca,
                             'modelo': modelo, 'anio': anio, 'num_asientos': num_asientos,
                             'tipos_asiento': tipos})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@admin_requerido
def viaje_pasajeros(request, viaje_id):
    from django.db import connection
    try:
        with connection.cursor() as cur:
            cur.execute("""
                SELECT corig.nombre, cdest.nombre, v.fecHoraSalida, v.autobus
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
        return JsonResponse({'viaje': {'origen': origen, 'destino': destino,
                                       'salida': salida_str, 'autobus': autobus},
                             'pasajeros': pasajeros})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


from .elipse_views import elipse_view, elipse_chat

@login_requerido
def api_ventas_sujetos(request):
    """Devuelve listas de taquilleros y clientes para el selector del panel de ventas."""
    taqs = Taquillero.objects.all().order_by('taqnombre', 'taqprimerapell')
    clientes = CuentaPasajero.objects.select_related('pasajero_num').all().order_by('correo')
    return JsonResponse({
        'taquilleros': [
            {
                'id': t.registro,
                'nombre': f'{t.taqnombre} {t.taqprimerapell}',
                'usuario': t.usuario,
            } for t in taqs
        ],
        'clientes': [
            {
                'id': c.pasajero_num.num,
                'nombre': f'{c.pasajero_num.panombre} {c.pasajero_num.paprimerapell}',
                'correo': c.correo,
            } for c in clientes
        ],
    })

@api_view(['POST'])
def api_login(request):
    usuario = request.data.get('usuario')
    contrasena = request.data.get('contrasena')
    try:
        taquillero = Taquillero.objects.get(usuario=usuario)
        if not check_password(contrasena, taquillero.contrasena):
            return Response({'error': 'Credenciales incorrectas'}, status=401)
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


def _html_correo(pago, viaje, tickets):
    fecha_viaje  = viaje.fechorasalida.strftime('%d/%m/%Y')
    hora_salida  = viaje.fechorasalida.strftime('%H:%M')
    hora_llegada = viaje.fechoraentrada.strftime('%H:%M')

    filas = ''
    for t in tickets:
        filas += f"""
        <tr>
            <td style="padding:6px 12px;border-bottom:1px solid #eeeeee;font-size:13px;">{t.pasajero.panombre} {t.pasajero.paprimerapell}</td>
            <td style="padding:6px 12px;border-bottom:1px solid #eeeeee;font-size:13px;text-align:center;">{t.asiento.numero}</td>
            <td style="padding:6px 12px;border-bottom:1px solid #eeeeee;font-size:13px;text-align:center;">{t.tipopasajero.descripcion}</td>
            <td style="padding:6px 12px;border-bottom:1px solid #eeeeee;font-size:13px;text-align:right;">${float(t.precio):.2f} MXN</td>
        </tr>
        """

    return f"""<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#f9f9f9;font-family:Arial,sans-serif;color:#222222;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr><td align="center" style="padding:30px 10px;">
      <table width="540" cellpadding="0" cellspacing="0"
             style="background:#ffffff;border:1px solid #dddddd;border-radius:4px;">

        <!-- ENCABEZADO -->
        <tr>
          <td style="padding:24px 32px;border-bottom:2px solid #222222;">
            <p style="margin:0;font-size:11px;letter-spacing:2px;color:#666666;">RUTAS BAJA EXPRESS</p>
            <h2 style="margin:6px 0 0;font-size:20px;color:#222222;">Confirmacion de Compra</h2>
          </td>
        </tr>

        <!-- FOLIO -->
        <tr>
          <td style="padding:20px 32px;border-bottom:1px solid #eeeeee;">
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td>
                  <p style="margin:0;font-size:11px;color:#888888;">NUMERO DE FOLIO</p>
                  <p style="margin:4px 0 0;font-size:22px;font-weight:bold;">#{pago.numero}</p>
                </td>
                <td align="right">
                  <p style="margin:0;font-size:11px;color:#888888;">FECHA DE COMPRA</p>
                  <p style="margin:4px 0 0;font-size:14px;">{pago.fechapago.strftime('%d/%m/%Y %H:%M')}</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- RUTA -->
        <tr>
          <td style="padding:20px 32px;border-bottom:1px solid #eeeeee;">
            <p style="margin:0 0 10px;font-size:11px;color:#888888;letter-spacing:1px;">RUTA</p>
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td>
                  <p style="margin:0;font-size:11px;color:#888888;">ORIGEN</p>
                  <p style="margin:4px 0 0;font-size:16px;font-weight:bold;">{viaje.ruta.origen.ciudad.nombre}</p>
                </td>
                <td align="center" style="font-size:18px;color:#888888;">→</td>
                <td align="right">
                  <p style="margin:0;font-size:11px;color:#888888;">DESTINO</p>
                  <p style="margin:4px 0 0;font-size:16px;font-weight:bold;">{viaje.ruta.destino.ciudad.nombre}</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- FECHA Y HORA -->
        <tr>
          <td style="padding:20px 32px;border-bottom:1px solid #eeeeee;">
            <p style="margin:0 0 10px;font-size:11px;color:#888888;letter-spacing:1px;">FECHA Y HORA</p>
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td width="48%">
                  <p style="margin:0;font-size:11px;color:#888888;">SALIDA</p>
                  <p style="margin:4px 0 0;font-size:14px;font-weight:bold;">{fecha_viaje} &nbsp; {hora_salida}</p>
                </td>
                <td width="4%"></td>
                <td width="48%">
                  <p style="margin:0;font-size:11px;color:#888888;">LLEGADA ESTIMADA</p>
                  <p style="margin:4px 0 0;font-size:14px;font-weight:bold;">{fecha_viaje} &nbsp; {hora_llegada}</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- PASAJEROS -->
        <tr>
          <td style="padding:20px 32px;border-bottom:1px solid #eeeeee;">
            <p style="margin:0 0 10px;font-size:11px;color:#888888;letter-spacing:1px;">PASAJEROS</p>
            <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #eeeeee;">
              <tr style="background:#f5f5f5;">
                <th style="padding:7px 12px;text-align:left;font-size:11px;color:#888888;font-weight:600;">NOMBRE</th>
                <th style="padding:7px 12px;text-align:center;font-size:11px;color:#888888;font-weight:600;">ASIENTO</th>
                <th style="padding:7px 12px;text-align:center;font-size:11px;color:#888888;font-weight:600;">TIPO</th>
                <th style="padding:7px 12px;text-align:right;font-size:11px;color:#888888;font-weight:600;">PRECIO</th>
              </tr>
              {filas}
            </table>
          </td>
        </tr>

        <!-- TOTAL -->
        <tr>
          <td style="padding:20px 32px;border-bottom:1px solid #eeeeee;">
            <table width="100%" cellpadding="0" cellspacing="0">
              <tr>
                <td>
                  <p style="margin:0;font-size:11px;color:#888888;">METODO DE PAGO</p>
                  <p style="margin:4px 0 0;font-size:14px;font-weight:bold;">{pago.tipo.nombre}</p>
                </td>
                <td align="right">
                  <p style="margin:0;font-size:11px;color:#888888;">TOTAL PAGADO</p>
                  <p style="margin:4px 0 0;font-size:20px;font-weight:bold;">${float(pago.monto):.2f} MXN</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- AVISO -->
        <tr>
          <td style="padding:20px 32px;border-bottom:1px solid #eeeeee;">
            <p style="margin:0;font-size:13px;color:#444444;">
              Presentate en la terminal <strong>30 minutos antes</strong> de la salida con este folio.
              Tu boleto en PDF se adjunta a este correo.
            </p>
          </td>
        </tr>

        <!-- PIE -->
        <tr>
          <td style="padding:16px 32px;">
            <p style="margin:0;font-size:11px;color:#aaaaaa;text-align:center;letter-spacing:1px;">
              RUTAS BAJA EXPRESS · BUS TICKET
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>"""


@api_view(['POST'])
def api_comprar(request):
    try:
        data            = request.data
        viaje_id        = data.get('viaje_id')
        tipo_pago_id    = data.get('tipo_pago')
        pasajeros       = data.get('pasajeros')
        monto_total     = data.get('monto_total')
        vendedor_id     = data.get('vendedor_id')
        correo_contacto = data.get('correo_contacto', '')
        # BUG 2 FIX: cliente_id viene de la app móvil cuando el comprador es cliente
        # registrado. Se usa para vincular el ticket al Pasajero de su cuenta y que
        # aparezca correctamente en el historial del cliente.
        cliente_id      = data.get('cliente_id')

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
                # Si es el primer pasajero y viene con cliente_id, reusar el Pasajero
                # existente de la cuenta para que el historial quede vinculado.
                if es_primer_pasajero and cliente_id:
                    try:
                        pasajero = Pasajero.objects.get(num=cliente_id)
                    except Pasajero.DoesNotExist:
                        pasajero = Pasajero.objects.create(
                            panombre=p['nombre'], paprimerapell=p['primer_apellido'],
                            pasegundoapell=p.get('segundo_apellido', None),
                            fechanacimiento=date(ano_nacimiento, 1, 1),
                        )
                else:
                    pasajero = Pasajero.objects.create(
                        panombre=p['nombre'], paprimerapell=p['primer_apellido'],
                        pasegundoapell=p.get('segundo_apellido', None),
                        fechanacimiento=date(ano_nacimiento, 1, 1),
                    )
                es_primer_pasajero = False

                tipo_map         = {'Adulto': 1, 'Estudiante': 4, 'INAPAM': 3, 'Discapacidad': 5}
                tipo_pasajero_id = tipo_map.get(p['tipo'], 1)
                tipo_pasajero    = TipoPasajero.objects.get(num=tipo_pasajero_id)
                precio_base      = viaje.ruta.precio
                descuento        = tipo_pasajero.descuento
                precio_final     = float(precio_base) * (1 - descuento / 100)
                asiento          = Asiento.objects.get(numero=p['asiento_id'])
                ticket = Ticket.objects.create(
    precio=precio_final,
    fechaemision=timezone.now(),
    asiento=asiento,
    viaje=viaje,
    pasajero=pasajero,
    tipopasajero=tipo_pasajero,
    pago=pago,
    etiqueta_asiento=p.get('asiento_etiqueta')  # 👈 ESTA ES LA CLAVE
)
                tickets_creados.append(ticket)
                from django.db import connection
                with connection.cursor() as cur:
                    cur.execute(
                        "UPDATE viaje_asiento SET ocupado = 1 WHERE asiento = %s AND viaje = %s",
                        [asiento.numero, viaje.numero]
                    )

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
                'hora_salida': viaje.fechorasalida.strftime('%H:%M'),
'hora_llegada':   viaje.fechoraentrada.strftime('%H:%M') if viaje.fechoraentrada else '',
'fecha_viaje': viaje.fechorasalida.strftime('%d %b %Y'),
                'duracion': viaje.ruta.duracion,
            },
            'tickets': [
                {
                    'codigo': t.codigo,
                    'asiento': t.asiento.numero,
'asiento_etiqueta': t.etiqueta_asiento or str(t.asiento.numero),
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
        data         = request.data
        firebase_uid = data.get('firebase_uid')
        correo       = data.get('correo')
        nombre       = data.get('nombre', '')
        foto         = data.get('foto', '')

        cuenta = CuentaPasajero.objects.filter(firebase_uid=firebase_uid).first()
        if not cuenta:
            cuenta = CuentaPasajero.objects.filter(correo=correo).first()

        if cuenta:
            if foto:
                cuenta.foto = foto
                cuenta.save()
            pasajero = cuenta.pasajero_num
        else:
            partes        = nombre.strip().split(' ')
            panombre      = partes[0] if len(partes) > 0 else 'Usuario'
            paprimerapell = partes[1] if len(partes) > 1 else 'RBE'
            pasajero = Pasajero.objects.create(
                panombre=panombre, paprimerapell=paprimerapell, fechanacimiento='2000-01-01',
            )
            cuenta = CuentaPasajero.objects.create(
                pasajero_num=pasajero, correo=correo,
                firebase_uid=firebase_uid, proveedor='google', foto=foto,
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
        pagos = Pago.objects.filter(ticket__pasajero__num=cliente_id).distinct().order_by('-fechapago')
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
def historial_todas(request):
    try:
        pagos = Pago.objects.order_by('-fechapago')
        data = []
        for pago in pagos:
            tickets = Ticket.objects.filter(pago=pago).select_related(
                'viaje__ruta__origen__ciudad',
                'viaje__ruta__destino__ciudad',
                'viaje__estado',
            )
            primer_ticket = tickets.first()

            # Si no hay tickets, igual incluir el pago con datos mínimos
            if primer_ticket:
                viaje = primer_ticket.viaje
                origen   = viaje.ruta.origen.ciudad.nombre
                destino  = viaje.ruta.destino.ciudad.nombre
                salida   = str(viaje.fechorasalida)
                estado   = viaje.estado.nombre
            else:
                origen  = 'Sin datos'
                destino = 'Sin datos'
                salida  = ''
                estado  = ''

            data.append({
                'folio':           pago.numero,
                'fecha':           str(pago.fechapago),
                'origen':          origen,
                'destino':         destino,
                'hora_salida':     salida,
                'estado':          estado,
                'num_pasajeros':   tickets.count(),
                'monto':           str(pago.monto),
                'metodo_pago':     pago.tipo.nombre,
                'vendedor_id':     pago.vendedor.registro if pago.vendedor else None,
                'vendedor_nombre': f'{pago.vendedor.taqnombre} {pago.vendedor.taqprimerapell}' if pago.vendedor else 'App',
            })
        return Response(data)
    except Exception as e:
        return Response({'error': str(e)}, status=400)


@api_view(['GET'])
def detalle_boleto_folio(request, folio):
    try:
        pago = Pago.objects.get(numero=folio)
        tickets = Ticket.objects.filter(pago=pago).select_related(
            'pasajero', 'asiento', 'tipopasajero',
            'viaje__ruta__origen__ciudad',
            'viaje__ruta__destino__ciudad',
        )
        primer_ticket = tickets.first()
        if not primer_ticket:
            return JsonResponse({'error': 'No se encontraron tickets'}, status=404)

        viaje = primer_ticket.viaje
        pasajeros = []
        for t in tickets:
            pasajeros.append({
                'nombre':           t.pasajero.panombre,
                'primer_apellido':  t.pasajero.paprimerapell,
                'asiento_etiqueta': t.etiqueta_asiento or str(t.asiento.numero),
                'asiento_id':       t.asiento.numero,
                'tipo':             t.tipopasajero.descripcion,
                'precio_unitario':  str(t.precio),
            })

        data = {
            'folio':          pago.numero,
            'origen':         viaje.ruta.origen.ciudad.nombre,
            'destino':        viaje.ruta.destino.ciudad.nombre,
            'hora_salida':    viaje.fechorasalida.strftime('%H:%M'),
            'hora_llegada':   viaje.fechoraentrada.strftime('%H:%M') if viaje.fechoraentrada else '',
            'fecha_viaje':    viaje.fechorasalida.strftime('%d %b %Y'),
            'monto':          str(pago.monto),
            'metodo_pago_id': pago.tipo.numero,
            'pasajeros':      pasajeros,
        }
        return JsonResponse(data)

    except Pago.DoesNotExist:
        return JsonResponse({'error': 'Folio no encontrado'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=400)

@api_view(['POST'])
def api_cliente_registro(request):
    try:
        data         = request.data
        firebase_uid = data.get('firebase_uid', '')
        correo       = data.get('correo', '')
        nombre       = data.get('nombre', '')
        apellido     = data.get('apellido', '')

        if not correo or not nombre or not apellido:
            return Response({'error': 'Faltan campos obligatorios'}, status=400)

        if CuentaPasajero.objects.filter(correo=correo).exists():
            return Response({'error': 'Este correo ya está registrado'}, status=400)

        pasajero = Pasajero.objects.create(
            panombre=nombre, paprimerapell=apellido, fechanacimiento='2000-01-01',
        )
        cuenta = CuentaPasajero.objects.create(
            pasajero_num=pasajero, correo=correo,
            firebase_uid=firebase_uid, proveedor='email', foto='',
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
        correo       = request.data.get('correo')

        cuenta = None
        if firebase_uid:
            cuenta = CuentaPasajero.objects.filter(firebase_uid=firebase_uid).first()
        if not cuenta and correo:
            cuenta = CuentaPasajero.objects.filter(correo=correo).first()

        if not cuenta:
            return Response({'error': 'Usuario no encontrado'}, status=404)

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
    correo   = request.GET.get('correo', '').strip().lower()
    viaje_id = request.GET.get('viaje_id', '')
    if not correo or not viaje_id:
        return Response({'error': 'Faltan parámetros'}, status=400)
    try:
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

    archivo   = request.FILES['foto']
    carpeta   = os.path.join(settings.MEDIA_ROOT, 'fotos_taquilleros')
    os.makedirs(carpeta, exist_ok=True)

    if taquillero.foto:
        ruta_anterior = os.path.join(settings.MEDIA_ROOT, taquillero.foto)
        if os.path.exists(ruta_anterior):
            os.remove(ruta_anterior)

    nombre        = f'taquillero_{taquillero_id}_{archivo.name}'
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

    nombre        = f'pasajero_{pasajero_num}_{archivo.name}'
    ruta_relativa = f'fotos_pasajeros/{nombre}'
    ruta_completa = os.path.join(settings.MEDIA_ROOT, ruta_relativa)

    with open(ruta_completa, 'wb') as f:
        for chunk in archivo.chunks():
            f.write(chunk)

    cuenta.foto = ruta_relativa
    cuenta.save(update_fields=['foto'])

    foto_url = request.build_absolute_uri(f'{settings.MEDIA_URL}{ruta_relativa}')
    return Response({'foto_url': foto_url})


# ── Enviar boleto por correo (deshabilitado — se envía en api_comprar) ───
@api_view(['POST'])
def api_enviar_boleto_correo(request, pago_id):
    try:
        data           = json.loads(request.body)
        correo_destino = data.get('correo', '')
        pdf_base64     = data.get('pdf_base64', '')

        if not correo_destino:
            return Response({'error': 'Correo requerido'}, status=400)

        pago = Pago.objects.get(numero=pago_id)
        tickets = Ticket.objects.filter(pago=pago).select_related(
            'pasajero', 'asiento',
            'viaje__ruta__origen__ciudad',
            'viaje__ruta__destino__ciudad',
            'tipopasajero'
        )
        primer_ticket = tickets.first()
        if not primer_ticket:
            return Response({'error': 'No se encontraron tickets'}, status=404)

        viaje       = primer_ticket.viaje
        html        = _html_correo(pago, viaje, tickets)
        texto_plano = (
            f"Confirmación de compra - Folio #{pago_id}\n"
            f"Ruta: {viaje.ruta.origen.ciudad.nombre} → {viaje.ruta.destino.ciudad.nombre}\n"
            f"Salida: {viaje.fechorasalida.strftime('%d/%m/%Y %H:%M')}\n"
            f"Total: ${float(pago.monto):.2f} MXN"
        )

        email = EmailMultiAlternatives(
            subject=f'Confirmación de compra - Folio #{pago_id} | Rutas Baja Express',
            body=texto_plano,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[correo_destino],
        )
        email.attach_alternative(html, "text/html")

        if pdf_base64:
            import base64
            pdf_bytes = base64.b64decode(pdf_base64)
            email.attach(f'Boleto_Folio_{pago_id}.pdf', pdf_bytes, 'application/pdf')

        email.send(fail_silently=False)
        return Response({'ok': True})

    except Pago.DoesNotExist:
        return Response({'error': 'Pago no encontrado'}, status=404)
    except Exception as e:
        return Response({'error': str(e)}, status=500)