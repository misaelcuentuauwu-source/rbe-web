from django.urls import path
from . import views

urlpatterns = [
    path('viajes/', views.api_viajes, name='api_viajes'),
    path('viajes/<int:id>/', views.api_viaje_detalle, name='api_viaje_detalle'),
    path('terminales/', views.api_terminales, name='api_terminales'),
    path('comprar/', views.api_comprar, name='api_comprar'),
    path('login/', views.api_login, name='api_login'),
    path('historial/<int:vendedor_id>/', views.api_historial_taquillero, name='api_historial'),
    path('boleto/<int:folio>/', views.api_buscar_boleto, name='api_buscar_boleto'),
    path('cliente/google-login/', views.api_cliente_google_login, name='api_cliente_google_login'),
    path('historial/cliente/<int:cliente_id>/', views.api_historial_cliente, name='api_historial_cliente'),
]
