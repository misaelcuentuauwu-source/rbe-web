from django.urls import path, include
from django.views.generic import RedirectView
from django.conf import settings
from django.conf.urls.static import static
from . import views

urlpatterns = [

    path('elipse/',       views.elipse_view, name='elipse'),
    path('elipse/chat/',  views.elipse_chat, name='elipse_chat'),
    path('ok/', views.ok_view, name='ok'),
    path('', views.index_view, name='index'),
    # Auth
    path('login/',         views.login_view,             name='login'),
    path('registro/',      views.registro_view,          name='registro'),
    path('logout/',        views.logout_view,            name='logout'),
    path('api/cliente/verificar-pasajero/', views.api_verificar_pasajero, name='api_verificar_pasajero'),
    # NUEVO: verificación de clave maestra vía AJAX
    path('api/verificar-clave/', views.verificar_clave_maestra, name='verificar_clave'),
    # Vistas generales
    path('panel/',         views.panel_principal,        name='panel_principal'),
    path('dashboard/',     views.dashboard,              name='dashboard'),
    path('salidas/',       views.salidas,                name='salidas'),
    # Panel admin
    path('admin-panel/',   views.panel_admin,            name='panel_admin'),
    # Config
    path('api/config/',    views.actualizar_config,      name='actualizar_config'),
    # CRUD genérico
    path('api/crud/<str:tabla>/leer/',       views.crud_leer,       name='crud_leer'),
    path('api/crud/<str:tabla>/esquema/',    views.crud_esquema,    name='crud_esquema'),
    path('api/crud/<str:tabla>/insertar/',   views.crud_insertar,   name='crud_insertar'),
    path('api/crud/<str:tabla>/actualizar/', views.crud_actualizar, name='crud_actualizar'),
    path('api/crud/<str:tabla>/eliminar/',   views.crud_eliminar,   name='crud_eliminar'),
    # Salidas / viajes (panel admin — deben ir ANTES del include api/)
    path('api/salidas/',             views.salidas_json,           name='salidas_json'),
    path('api/historial/',           views.historial_json,         name='historial_json'),
    path('api/viaje/opciones/',      views.agregar_viaje_opciones, name='viaje_opciones'),
    path('api/viaje/agregar/',       views.agregar_viaje,          name='agregar_viaje'),
    # KPIs
    path('api/kpi/generales/',       views.kpi_generales,          name='kpi_generales'),
    path('api/kpi/especificos/',     views.kpi_especificos,        name='kpi_especificos'),
    path('api/kpi/filtros/',         views.kpi_filtros_opciones,   name='kpi_filtros'),
    # Detalle autobus y pasajeros (usados desde panel_admin.html)
    path('api/autobus/detalle/<int:bus_id>/',   views.autobus_detalle, name='autobus_detalle'),
    path('api/viaje/pasajeros/<int:viaje_id>/', views.viaje_pasajeros, name='viaje_pasajeros'),
    path('api/boleto/<int:pago_id>/adjuntar_pdf/', views.api_enviar_boleto_correo, name='api_adjuntar_pdf'),
    # API móvil (taquilla) — al final para no interceptar rutas del panel
    path('api/', include('taquilla.api_urls')),
]

urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)