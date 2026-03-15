from rest_framework import serializers
from django.db import connection
from .models import Viaje, Ruta, Terminal, Ciudad, EdoViaje, ViajeAsiento, Asiento, TipoAsiento

class CiudadSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ciudad
        fields = ['clave', 'nombre']

class TerminalSerializer(serializers.ModelSerializer):
    ciudad = CiudadSerializer()
    class Meta:
        model = Terminal
        fields = ['numero', 'nombre', 'ciudad']

class RutaSerializer(serializers.ModelSerializer):
    origen = TerminalSerializer()
    destino = TerminalSerializer()
    class Meta:
        model = Ruta
        fields = ['codigo', 'duracion', 'origen', 'destino', 'precio']

class EstadoSerializer(serializers.ModelSerializer):
    class Meta:
        model = EdoViaje
        fields = ['numero', 'nombre']

class TipoAsientoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoAsiento
        fields = ['codigo', 'descripcion']

class AsientoSerializer(serializers.ModelSerializer):
    tipo = TipoAsientoSerializer()
    class Meta:
        model = Asiento
        fields = ['numero', 'tipo']

class ViajeAsientoSerializer(serializers.ModelSerializer):
    asiento = AsientoSerializer()
    class Meta:
        model = ViajeAsiento
        fields = ['asiento', 'ocupado']

# Serializer ligero para la LISTA de viajes (sin asientos)
class ViajeListSerializer(serializers.ModelSerializer):
    ruta = RutaSerializer()
    estado = EstadoSerializer()
    asientos_disponibles = serializers.SerializerMethodField()

    def get_asientos_disponibles(self, viaje):
        with connection.cursor() as cur:
            cur.execute(
                "SELECT COUNT(*) FROM viaje_asiento WHERE viaje = %s AND ocupado = 1",
                [viaje.numero]
            )
            ocupados = cur.fetchone()[0]
        total = Asiento.objects.filter(autobus=viaje.autobus).count()
        return total - ocupados

    class Meta:
        model = Viaje
        fields = ['numero', 'fechorasalida', 'fechoraentrada', 'ruta', 'estado', 'asientos_disponibles']

# Serializer completo para el DETALLE de un viaje (con asientos)
class ViajeSerializer(serializers.ModelSerializer):
    ruta = RutaSerializer()
    estado = EstadoSerializer()
    asientos = serializers.SerializerMethodField()

    def get_asientos(self, viaje):
        asientos = Asiento.objects.filter(autobus=viaje.autobus)
        with connection.cursor() as cur:
            cur.execute(
                "SELECT asiento FROM viaje_asiento WHERE viaje = %s AND ocupado = 1",
                [viaje.numero]
            )
            ocupados = set(row[0] for row in cur.fetchall())
        resultado = []
        for asiento in asientos:
            resultado.append({
                'asiento': {
                    'numero': asiento.numero,
                    'tipo': {
                        'codigo': asiento.tipo.codigo,
                        'descripcion': asiento.tipo.descripcion,
                    }
                },
                'ocupado': 1 if asiento.numero in ocupados else 0
            })
        return resultado

    class Meta:
        model = Viaje
        fields = ['numero', 'fechorasalida', 'fechoraentrada', 'ruta', 'estado', 'asientos']