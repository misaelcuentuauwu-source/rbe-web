import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';

class HistorialScreen extends StatefulWidget {
  final int vendedorId;

  const HistorialScreen({super.key, required this.vendedorId});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  List<dynamic> historial = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    try {
      final response = await http
          .get(
            Uri.parse('${Config.baseUrl}/api/historial/${widget.vendedorId}/'),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          historial = jsonDecode(response.body) as List;
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => cargando = false);
    }
  }

  String _formatFecha(String fecha) {
    final dt = DateTime.parse(fecha);
    const meses = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${dt.day} ${meses[dt.month]} ${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(child: _buildContenido()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: azul,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historial de ventas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cargando ? '' : '${historial.length} venta(s)',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => cargando = true);
              cargarHistorial();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (cargando) {
      return const Center(child: CircularProgressIndicator(color: azul));
    }
    if (historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              color: Colors.grey.shade300,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay ventas registradas',
              style: TextStyle(
                color: textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las ventas que realices aparecerán aquí',
              style: TextStyle(color: textoSecundario, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: historial.length,
      itemBuilder: (context, index) => _buildTarjeta(historial[index]),
    );
  }

  Widget _buildTarjeta(Map venta) {
    final esTarjeta = venta['metodo_pago'].toString().toLowerCase().contains(
      'tarjeta',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: azul.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Folio #${venta['folio']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: azul,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatFecha(venta['fecha']),
                  style: TextStyle(fontSize: 11, color: textoSecundario),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded, color: azul, size: 14),
                const SizedBox(width: 6),
                Text(
                  venta['origen'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textoPrincipal,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.grey.shade400,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Icon(Icons.location_on_rounded, color: naranja, size: 14),
                const SizedBox(width: 4),
                Text(
                  venta['destino'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textoPrincipal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoChip(
                  Icons.people_rounded,
                  '${venta['num_pasajeros']} pasajero(s)',
                  textoSecundario,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  esTarjeta
                      ? Icons.credit_card_rounded
                      : Icons.payments_rounded,
                  venta['metodo_pago'],
                  textoSecundario,
                ),
                const Spacer(),
                Text(
                  '\$${double.parse(venta['monto']).toStringAsFixed(2)} MXN',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: naranja,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icono, String label, Color color) {
    return Row(
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
