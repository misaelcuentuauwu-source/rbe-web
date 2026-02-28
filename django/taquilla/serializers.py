from rest_framework import serializers
from .models import Viaje, Ruta, Terminal, Ciudad, EdoViaje, ViajeAsiento

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

class ViajeSerializer(serializers.ModelSerializer):
    ruta = RutaSerializer()
    estado = EstadoSerializer()
    class Meta:
        model = Viaje
        fields = ['numero', 'fechorasalida', 'fechoraentrada', 'ruta', 'estado']