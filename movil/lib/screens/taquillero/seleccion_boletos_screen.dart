import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../config.dart';
import '../../utils/pdf_boleto.dart';

class SeleccionBoletosScreen extends StatefulWidget {
  final int folio;

  const SeleccionBoletosScreen({super.key, required this.folio});

  @override
  State<SeleccionBoletosScreen> createState() => _SeleccionBoletosScreenState();
}

class _SeleccionBoletosScreenState extends State<SeleccionBoletosScreen> {
  static const naranja = Color(0xFFE9713A);
  static const azul = Color(0xFF2C7FB1);
  static const fondo = Color(0xFFF0F3F8);
  static const dark = Color(0xFF1C2D3A);
  static const muted = Color(0xFF8FA8BE);

  List pasajeros = [];
  Map<String, dynamic>? data;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarBoletos();
  }

  Future<void> _cargarBoletos() async {
    try {
      final res = await http.get(
        Uri.parse('${Config.baseUrl}/api/boleto/${widget.folio}/'),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);

        setState(() {
          data = json;
          pasajeros = json['tickets'];
          cargando = false;
        });
      }
    } catch (e) {
      setState(() => cargando = false);
    }
  }

  Future<void> _reimprimir() async {
    if (data == null) return;

    final pdf = await PdfBoleto.generar(
      pagoId: data!['folio'],
      origenNombre: data!['viaje']['origen'],
      destinoNombre: data!['viaje']['destino'],
      horaSalida: data!['viaje']['hora_salida'],
      horaLlegada: data!['viaje']['hora_llegada'] ?? '',
      fechaViaje: data!['viaje']['fecha'],
      montoTotal: double.parse(data!['monto'].toString()),
      pasajeros: List<Map<String, dynamic>>.from(data!['tickets']),
      metodoPago: data!['metodo_pago_id'],
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _contenido(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEF7D44), Color(0xFFE9713A)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Folio #${widget.folio}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    return Column(
      children: [
        const SizedBox(height: 12),

        /// Lista de boletos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pasajeros.length,
            itemBuilder: (_, i) {
              final p = pasajeros[i];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: azul),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['nombre']} ${p['primer_apellido']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: dark,
                            ),
                          ),
                          Text(
                            'Asiento: ${p['asiento_etiqueta'] ?? p['asiento_id']}',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        /// Botón pro
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: _reimprimir,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF7D44), Color(0xFFE9713A)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Reimprimir boletos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
