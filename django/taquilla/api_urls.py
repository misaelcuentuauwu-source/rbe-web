from django.urls import path
from . import views

urlpatterns = [
    path('viajes/', views.api_viajes, name='api_viajes'),
    path('viajes/<int:id>/', views.api_viaje_detalle, name='api_viaje_detalle'),
    path('terminales/', views.api_terminales, name='api_terminales'),
    path('comprar/', views.api_comprar, name='api_comprar'),
    path('login/', views.api_login, name='api_login'),
    path('historial/', views.historial_todas, name='api_historial'),
    path('boleto/<int:folio>/', views.api_buscar_boleto, name='api_buscar_boleto'),
    path('boleto/<int:folio>/detalle/', views.detalle_boleto_folio, name='detalle_boleto_folio'),

    # ── Clientes ──────────────────────────────────────────────────────────────
    path('cliente/google-login/', views.api_cliente_google_login, name='api_cliente_google_login'),
    path('cliente/registro/',     views.api_cliente_registro,     name='api_cliente_registro'),    # ← BUG 1 FIX
    path('cliente/login/',        views.api_cliente_login_email,  name='api_cliente_login_email'), # ← BUG 1 FIX
    path('historial/cliente/<int:cliente_id>/', views.api_historial_cliente, name='api_historial_cliente'),

    # ── Taquillero ────────────────────────────────────────────────────────────
    path('taquillero/<int:taquillero_id>/foto/', views.api_subir_foto_taquillero, name='api_foto_taquillero'),
    path('pasajero/<int:pasajero_num>/foto/',    views.api_subir_foto_pasajero,   name='api_foto_pasajero'),

    # ── Correo / PDF ──────────────────────────────────────────────────────────
    path('boleto/<int:pago_id>/enviar_correo/', views.api_enviar_boleto_correo, name='api_enviar_boleto_correo'),
    path('boleto/<int:pago_id>/adjuntar_pdf/', views.api_enviar_boleto_correo, name='api_adjuntar_pdf_movil'),
]