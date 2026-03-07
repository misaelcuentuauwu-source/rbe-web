from django.urls import path
from . import views

urlpatterns = [
    path('viajes/', views.api_viajes, name='api_viajes'),
    path('viajes/<int:id>/', views.api_viaje_detalle, name='api_viaje_detalle'),
    path('terminales/', views.api_terminales, name='api_terminales'),
]