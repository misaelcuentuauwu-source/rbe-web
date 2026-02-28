from django.shortcuts import render, redirect
from django.contrib import messages
from .models import Taquillero, Terminal, Viaje
from datetime import date
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .serializers import ViajeSerializer

CLAVE_MAESTRA = "RutasBaja2024"

def login_view(request):
    if request.method == 'POST':
        usuario = request.POST.get('usuario', '').strip()
        contrasena = request.POST.get('contrasena', '').strip()

        try:
            taquillero = Taquillero.objects.get(usuario=usuario, contrasena=contrasena)
            request.session['usuario_id'] = taquillero.registro
            request.session['usuario_nombre'] = taquillero.taqnombre
            request.session['usuario_apellido'] = taquillero.taqprimerapell
            request.session['supervisa'] = bool(taquillero.supervisa)

            if taquillero.supervisa:
                return redirect('dashboard')
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

        nombre = request.POST.get('nombre', '').strip()
        ap1 = request.POST.get('primer_apellido', '').strip()
        ap2 = request.POST.get('segundo_apellido', '').strip()
        usuario = request.POST.get('usuario', '').strip()
        contrasena = request.POST.get('contrasena', '').strip()
        terminal_id = request.POST.get('terminal')
        supervisa = request.POST.get('supervisa') == 'on'

        if not all([nombre, ap1, usuario, contrasena]):
            messages.error(request, 'Completa los campos obligatorios')
            return redirect('login')

        Taquillero.objects.create(
            taqnombre=nombre,
            taqprimerapell=ap1,
            taqsegundoapell=ap2,
            fechacontrato=date.today(),
            usuario=usuario,
            contrasena=contrasena,
            terminal_id=terminal_id,
            supervisa=supervisa
        )
        messages.success(request, 'Taquillero registrado correctamente')
        return redirect('login')

    return redirect('login')

def login_requerido(view_func):
    """Decorador simple para verificar sesión activa."""
    def wrapper(request, *args, **kwargs):
        if not request.session.get('usuario_id'):
            return redirect('login')
        return view_func(request, *args, **kwargs)
    return wrapper


@login_requerido
def panel_principal(request):
    return render(request, 'taquilla/panel_principal.html')


@login_requerido
def panel_admin(request):
    # Solo supervisores pueden entrar
    if not request.session.get('supervisa'):
        return redirect('panel_principal')
    return render(request, 'taquilla/panel_admin.html')


def logout_view(request):
    request.session.flush()
    return redirect('login')

@login_requerido
def dashboard(request):
    return render(request, 'taquilla/dash.html')

@api_view(['GET'])
def api_viajes(request):
    viajes = Viaje.objects.filter(estado=1)  # Solo viajes disponibles
    serializer = ViajeSerializer(viajes, many=True)
    return Response(serializer.data)

@api_view(['GET'])
def api_viaje_detalle(request, id):
    try:
        viaje = Viaje.objects.get(numero=id)
        serializer = ViajeSerializer(viaje)
        return Response(serializer.data)
    except Viaje.DoesNotExist:
        return Response({'error': 'Viaje no encontrado'}, status=404)