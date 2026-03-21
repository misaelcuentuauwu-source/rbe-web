import 'package:flutter/material.dart';
import '../../main.dart';

class PerfilScreen extends StatelessWidget {
  final Map<String, dynamic> taquillero;

  const PerfilScreen({super.key, required this.taquillero});

  static const naranja = Color(0xFFE9713A);
  static const azul = Color(0xFF2C7FB1);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  @override
  Widget build(BuildContext context) {
    final terminal = taquillero['terminal'] as Map<String, dynamic>;
    final nombreCompleto =
        '${taquillero['nombre']} ${taquillero['primer_apellido']} ${taquillero['segundo_apellido']}'
            .trim();

    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(nombreCompleto),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildInfoCard(terminal),
                    const SizedBox(height: 16),
                    _buildBotonCerrarSesion(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String nombreCompleto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: naranja,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            nombreCompleto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Taquillero',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> terminal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: naranja,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Información del empleado',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.badge_outlined,
            'No. Empleado',
            '#${taquillero['registro']}',
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.person_outline_rounded,
            'Usuario',
            taquillero['usuario'],
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.location_on_outlined,
            'Terminal',
            terminal['nombre'],
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.location_city_outlined,
            'Ciudad',
            terminal['ciudad'],
          ),
          _buildDivider(),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Fecha de contrato',
            _formatFecha(taquillero['fecha_contrato']),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: naranja.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, size: 18, color: naranja),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: textoSecundario),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.shade100, height: 1);
  }

  String _formatFecha(String fecha) {
    final parts = fecha.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return fecha;
  }

  Widget _buildBotonCerrarSesion(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade400,
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(Icons.logout_rounded, color: Colors.red.shade400),
        label: Text(
          'Cerrar sesión',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade400,
          ),
        ),
      ),
    );
  }
}
