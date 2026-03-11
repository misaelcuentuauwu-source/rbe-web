from django.urls import path
from . import views

urlpatterns = [
<<<<<<< HEAD
    path('login/',         views.login_view,            name='login'),
    path('registro/',      views.registro_view,          name='registro'),
    path('panel/',         views.panel_principal,        name='panel_principal'),
    path('admin-panel/',   views.panel_admin,            name='panel_admin'),
    path('logout/',        views.logout_view,            name='logout'),
    # config
    path('api/config/',    views.actualizar_config,      name='actualizar_config'),
    # CRUD genérico
    path('api/crud/<str:tabla>/leer/',      views.crud_leer,       name='crud_leer'),
    path('api/crud/<str:tabla>/esquema/',   views.crud_esquema,    name='crud_esquema'),
    path('api/crud/<str:tabla>/insertar/',  views.crud_insertar,   name='crud_insertar'),
    path('api/crud/<str:tabla>/actualizar/',views.crud_actualizar, name='crud_actualizar'),
    path('api/crud/<str:tabla>/eliminar/',  views.crud_eliminar,   name='crud_eliminar'),
    # salidas / viajes
    path('api/salidas/',              views.salidas_json,          name='salidas_json'),
    path('api/viaje/opciones/',       views.agregar_viaje_opciones,name='viaje_opciones'),
    path('api/viaje/agregar/',        views.agregar_viaje,         name='agregar_viaje'),
    # KPIs
    path('api/kpi/generales/',        views.kpi_generales,         name='kpi_generales'),
    path('api/kpi/especificos/',      views.kpi_especificos,       name='kpi_especificos'),
    path('api/kpi/filtros/',          views.kpi_filtros_opciones,  name='kpi_filtros'),
]
=======
    path('login/', views.login_view, name='login'),
    path('registro/', views.registro_view, name='registro'),
    path('panel/', views.panel_principal, name='panel_principal'),
    path('admin-panel/', views.panel_admin, name='panel_admin'),
    path('logout/', views.logout_view, name='logout'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('salidas/', views.salidas, name='salidas'),
]
>>>>>>> c4fff904d5b176ea6bbc7a23e5b00d75e0e96531
