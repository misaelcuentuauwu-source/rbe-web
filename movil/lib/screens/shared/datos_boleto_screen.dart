import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'seat_selection_screen.dart';

class DatosBoletoScreen extends StatefulWidget {
  final int viajeId;
  final Map<String, int> pasajeros;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final String horaLlegada;
  final String fechaViaje;
  final String precio;
  final int vendedorId;
  final String? correoCliente;
  final String tipoUsuario;
  final Map<String, dynamic>? datosUsuario;

  const DatosBoletoScreen({
    super.key,
    required this.viajeId,
    required this.pasajeros,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    this.horaLlegada = '',
    this.fechaViaje = '',
    required this.precio,
    required this.vendedorId,
    this.correoCliente,
    this.tipoUsuario = 'invitado',
    this.datosUsuario,
  });

  @override
  State<DatosBoletoScreen> createState() => _DatosBoletoScreenState();
}

class _DatosBoletoScreenState extends State<DatosBoletoScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  final _formKey = GlobalKey<FormState>();
  late List<Map<String, dynamic>> pasajerosList;
  bool _verificando = false;

  static const Map<String, int> _descuentos = {
    'Adulto': 0,
    'Estudiante': 25,
    'INAPAM': 30,
    'Discapacidad': 15,
  };

  static const List<String> _requierenId = [
    'INAPAM',
    'Estudiante',
    'Discapacidad',
  ];

  @override
  void initState() {
    super.initState();
    _generarPasajeros();
    _prerellenarContacto();
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

  void _prerellenarContacto() {
    if (pasajerosList.isEmpty) return;

    final contacto = pasajerosList.firstWhere(
      (p) => p['esContacto'] == true,
      orElse: () => pasajerosList.first,
    );

    // Rellenar correo siempre que esté disponible
    if (widget.correoCliente != null) {
      (contacto['correoCtrl'] as TextEditingController).text =
          widget.correoCliente!;
    }

    // Si es cliente registrado, rellenar nombre y apellido
    if (widget.tipoUsuario == 'cliente' && widget.datosUsuario != null) {
      final datos = widget.datosUsuario!;
      final nombre = datos['nombre']?.toString() ?? '';
      final apellido = datos['primer_apellido']?.toString() ?? '';

      if (nombre.isNotEmpty) {
        (contacto['nombreCtrl'] as TextEditingController).text = nombre;
      }
      if (apellido.isNotEmpty) {
        (contacto['apPaternoCtrl'] as TextEditingController).text = apellido;
      }
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

  double _calcularPrecioConDescuento(String tipo) {
    final precioBase = double.parse(widget.precio);
    final descuento = _descuentos[tipo] ?? 0;
    return precioBase * (1 - descuento / 100);
  }

  Future<void> _continuar() async {
    if (!_formKey.currentState!.validate()) return;

    final contacto = pasajerosList.firstWhere(
      (p) => p['esContacto'] == true,
      orElse: () => pasajerosList.first,
    );

    final correo =
        widget.correoCliente ??
        (contacto['correoCtrl'] as TextEditingController).text.trim();

    setState(() => _verificando = true);

    try {
      final response = await http
          .get(
            Uri.parse(
              '${Config.baseUrl}/api/cliente/verificar-pasajero/'
              '?correo=${Uri.encodeComponent(correo)}'
              '&viaje_id=${widget.viajeId}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['duplicado'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Este correo ya tiene un boleto registrado para este viaje.',
              ),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Error verificando pasajero: $e');
    } finally {
      if (mounted) setState(() => _verificando = false);
    }

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
            'correo':
                widget.correoCliente ??
                (p['correoCtrl'] as TextEditingController).text.trim(),
            'precio_unitario': _calcularPrecioConDescuento(p['tipo']),
            'descuento': _descuentos[p['tipo']] ?? 0,
          },
        )
        .toList();

    if (mounted) {
      Navigator.push(
        context,
        AppRoutes.slideLeft(
          SeatSelectionScreen(
            viajeId: widget.viajeId,
            pasajeros: pasajerosData,
            origenNombre: widget.origenNombre,
            destinoNombre: widget.destinoNombre,
            horaSalida: widget.horaSalida,
            horaLlegada: widget.horaLlegada,
            fechaViaje: widget.fechaViaje,
            precioPorPasajero: double.parse(widget.precio),
            vendedorId: widget.vendedorId,
            tipoUsuario: widget.tipoUsuario,
            datosUsuario: widget.datosUsuario,
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
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pasajerosList.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildResumen();
                    if (index == pasajerosList.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _buildBotonContinuar(),
                      );
                    }
                    return _buildTarjetaPasajero(
                      pasajerosList[index - 1],
                      index - 1,
                    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: azul,
        boxShadow: [
          BoxShadow(
            color: azul.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.trip_origin_rounded, color: azul, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.origenNombre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textoPrincipal,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: textoSecundario,
            size: 14,
          ),
          const SizedBox(width: 6),
          const Icon(Icons.location_on_rounded, color: naranja, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.destinoNombre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textoPrincipal,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: azul.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.horaSalida,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: azul,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPasajero(Map<String, dynamic> pasajero, int index) {
    final esContacto = pasajero['esContacto'] as bool;
    final tipo = pasajero['tipo'] as String;
    final descuento = _descuentos[tipo] ?? 0;
    final precioFinal = _calcularPrecioConDescuento(tipo);
    final precioBase = double.parse(widget.precio);
    final requiereId = _requierenId.contains(tipo);
    // Detectar si este es el pasajero contacto de un cliente registrado
    // para mostrar badge de autorelleno
    final esClienteRegistrado =
        esContacto &&
        widget.tipoUsuario == 'cliente' &&
        widget.datosUsuario != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Badges ──────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
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
                if (esContacto)
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
                if (descuento > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$descuento% desc.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Aviso de datos autorrellenados ───────────────
            if (esClienteRegistrado)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: azul.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: azul.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded, size: 16, color: azul),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Datos autorrellenados con tu cuenta. Puedes modificarlos si lo deseas.',
                        style: TextStyle(fontSize: 12, color: azul),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Precio con descuento ─────────────────────────
            if (descuento > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Precio base: \$${precioBase.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${precioFinal.toStringAsFixed(2)} MXN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),

            if (descuento > 0) const SizedBox(height: 12),

            // ── Aviso de identificación (RF-APP-013) ─────────
            if (requiereId)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se deberá presentar identificación oficial al momento de abordar para validar la categoría y el descuento aplicado.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Nombre y primer apellido ─────────────────────
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
            const SizedBox(height: 12),
            // ── Segundo apellido y edad ───────────────────────
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
            // ── Campos de contacto ───────────────────────────
            if (esContacto) ...[
              const SizedBox(height: 12),
              _buildCampo(
                ctrl: pasajero['telefonoCtrl'],
                label: 'Teléfono de contacto',
                icono: Icons.phone_outlined,
                requerido: true,
                soloNumeros: true,
              ),
              const SizedBox(height: 12),
              // Si no hay correo de cliente, mostrar campo editable
              if (widget.correoCliente == null)
                _buildCampo(
                  ctrl: pasajero['correoCtrl'],
                  label: 'Correo electrónico',
                  icono: Icons.email_outlined,
                  requerido: true,
                  esCorreo: true,
                ),
              // Si hay correo de cliente (registrado), mostrar como verificado
              if (widget.correoCliente != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: azul.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: azul.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: azul),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Correo electrónico',
                            style: TextStyle(
                              fontSize: 11,
                              color: textoSecundario,
                            ),
                          ),
                          Text(
                            widget.correoCliente!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textoPrincipal,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Verificado',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
        labelStyle: const TextStyle(fontSize: 13, color: textoSecundario),
        prefixIcon: Icon(icono, size: 18, color: azul),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azul, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
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
        onPressed: _verificando ? null : _continuar,
        style: ElevatedButton.styleFrom(
          backgroundColor: naranja,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          shadowColor: naranja.withOpacity(0.4),
        ),
        child: _verificando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
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
