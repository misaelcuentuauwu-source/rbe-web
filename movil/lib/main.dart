import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'RBE Test', home: const ViajesScreen());
  }
}

class ViajesScreen extends StatefulWidget {
  const ViajesScreen({super.key});

  @override
  State<ViajesScreen> createState() => _ViajesScreenState();
}

class _ViajesScreenState extends State<ViajesScreen> {
  List viajes = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarViajes();
  }

  Future<void> cargarViajes() async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/viajes/'),
    );
    if (response.statusCode == 200) {
      setState(() {
        viajes = jsonDecode(response.body);
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes disponibles')),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: viajes.length,
              itemBuilder: (context, index) {
                final viaje = viajes[index];
                return ListTile(
                  title: Text(
                    '${viaje['ruta']['origen']['nombre']} → ${viaje['ruta']['destino']['nombre']}',
                  ),
                  subtitle: Text('Salida: ${viaje['fechorasalida']}'),
                  trailing: Text('\$${viaje['ruta']['precio']}'),
                );
              },
            ),
    );
  }
}
