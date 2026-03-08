import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'seat_selection_screen.dart';

class DatosBoletoScreen extends StatefulWidget {
  final int viajeId;
  final Map<String, int> pasajeros;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final String precio;
  final int vendedorId;

  const DatosBoletoScreen({
    super.key,
    required this.viajeId,
    required this.pasajeros,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    required this.precio,
    required this.vendedorId,
  });

  @override
  State<DatosBoletoScreen> createState() => _DatosBoletoScreenState();
}

class _DatosBoletoScreenState extends State<DatosBoletoScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFF008FD4);

  final _formKey = GlobalKey<FormState>();
  late List<Map<String, dynamic>> pasajerosList;

  @override
  void initState() {
    super.initState();
    _generarPasajeros();
  }

  void _generarPasajeros() {
    pasajerosList = [];

    if (widget.pasajeros['adultos']! > 0) {
      pasajerosList.add(_crearPasajero('Adulto', esContacto: true));
    }
    for (int i = 1; i < (widget.pasajeros['adultos'] ?? 0); i++) {
      pasajerosList.add(_crearPasajero('Adulto'));
    }
    for (int i = 0; i < (widget.pasajeros['estudiantes'] ?? 0); i++) {
      pasajerosList.add(_crearPasajero('Estudiante'));
    }
    for (int i = 0; i < (widget.pasajeros['inapam'] ?? 0); i++) {
      pasajerosList.add(_crearPasajero('INAPAM'));
    }
    for (int i = 0; i < (widget.pasajeros['discapacidad'] ?? 0); i++) {
      pasajerosList.add(_crearPasajero('Discapacidad'));
    }
  }

  Map<String, dynamic> _crearPasajero(String tipo, {bool esContacto = false}) {
    return {
      'tipo': tipo,
      'esContacto': esContacto,
      'nombreCtrl': TextEditingController(),
      'apPaternoCtrl': TextEditingController(),
      'apMaternoCtrl': TextEditingController(),
      'edadCtrl': TextEditingController(),
      'telefonoCtrl': TextEditingController(),
      'correoCtrl': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final p in pasajerosList) {
      p['nombreCtrl'].dispose();
      p['apPaternoCtrl'].dispose();
      p['apMaternoCtrl'].dispose();
      p['edadCtrl'].dispose();
      p['telefonoCtrl'].dispose();
      p['correoCtrl'].dispose();
    }
    super.dispose();
  }

  void _continuar() {
    if (_formKey.currentState!.validate()) {
      final pasajerosData = pasajerosList
          .map(
            (p) => {
              'nombre': (p['nombreCtrl'] as TextEditingController).text.trim(),
              'primer_apellido': (p['apPaternoCtrl'] as TextEditingController)
                  .text
                  .trim(),
              'segundo_apellido': (p['apMaternoCtrl'] as TextEditingController)
                  .text
                  .trim(),
              'edad': int.parse(
                (p['edadCtrl'] as TextEditingController).text.trim(),
              ),
              'tipo': p['tipo'],
              'esContacto': p['esContacto'],
              'telefono': (p['telefonoCtrl'] as TextEditingController).text
                  .trim(),
              'correo': (p['correoCtrl'] as TextEditingController).text.trim(),
            },
          )
          .toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeatSelectionScreen(
            viajeId: widget.viajeId,
            pasajeros: pasajerosData,
            origenNombre: widget.origenNombre,
            destinoNombre: widget.destinoNombre,
            horaSalida: widget.horaSalida,
            precioPorPasajero: double.parse(widget.precio),
            vendedorId: widget.vendedorId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildResumen(),
            const SizedBox(height: 12),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pasajerosList.length + 1,
                  itemBuilder: (context, index) {
                    if (index == pasajerosList.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: _buildBotonContinuar(),
                      );
                    }
                    return _buildTarjetaPasajero(pasajerosList[index], index);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del boleto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Completa la información de cada pasajero',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.trip_origin_rounded, color: azul, size: 16),
          const SizedBox(width: 6),
          Text(
            widget.origenNombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 14),
          const SizedBox(width: 6),
          const Icon(Icons.location_on_rounded, color: naranja, size: 16),
          const SizedBox(width: 4),
          Text(
            widget.destinoNombre,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          Text(
            widget.horaSalida,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: azul,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPasajero(Map<String, dynamic> pasajero, int index) {
    final esContacto = pasajero['esContacto'] as bool;
    final tipo = pasajero['tipo'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                    color: azul.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Pasajero ${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: azul,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorTipo(tipo).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tipo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _colorTipo(tipo),
                    ),
                  ),
                ),
                if (esContacto) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: naranja.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Contacto',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: naranja,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildCampo(
                    ctrl: pasajero['nombreCtrl'],
                    label: 'Nombre',
                    icono: Icons.person_outline_rounded,
                    requerido: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCampo(
                    ctrl: pasajero['apPaternoCtrl'],
                    label: 'Primer apellido',
                    icono: Icons.person_outline_rounded,
                    requerido: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCampo(
                    ctrl: pasajero['apMaternoCtrl'],
                    label: 'Segundo apellido',
                    icono: Icons.person_outline_rounded,
                    requerido: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCampo(
                    ctrl: pasajero['edadCtrl'],
                    label: 'Edad',
                    icono: Icons.cake_outlined,
                    requerido: true,
                    soloNumeros: true,
                  ),
                ),
              ],
            ),
            if (esContacto) ...[
              const SizedBox(height: 10),
              _buildCampo(
                ctrl: pasajero['telefonoCtrl'],
                label: 'Teléfono de contacto',
                icono: Icons.phone_outlined,
                requerido: true,
                soloNumeros: true,
              ),
              const SizedBox(height: 10),
              _buildCampo(
                ctrl: pasajero['correoCtrl'],
                label: 'Correo electrónico',
                icono: Icons.email_outlined,
                requerido: true,
                esCorreo: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCampo({
    required TextEditingController ctrl,
    required String label,
    required IconData icono,
    required bool requerido,
    bool soloNumeros = false,
    bool esCorreo = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: esCorreo
          ? TextInputType.emailAddress
          : soloNumeros
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: soloNumeros
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icono, size: 18, color: azul),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: azul, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: requerido
          ? (val) {
              if (val == null || val.trim().isEmpty) return 'Requerido';
              if (esCorreo && !val.contains('@')) return 'Correo inválido';
              if (label == 'Edad') {
                final edad = int.tryParse(val);
                if (edad == null || edad < 1 || edad > 120)
                  return 'Edad inválida';
              }
              if (label == 'Teléfono de contacto' && val.length < 10) {
                return 'Mín. 10 dígitos';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildBotonContinuar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _continuar,
        style: ElevatedButton.styleFrom(
          backgroundColor: naranja,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: naranja.withOpacity(0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Continuar a selección de asientos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'Estudiante':
        return Colors.green.shade600;
      case 'INAPAM':
        return Colors.purple.shade400;
      case 'Discapacidad':
        return Colors.orange.shade600;
      default:
        return azul;
    }
  }
}
