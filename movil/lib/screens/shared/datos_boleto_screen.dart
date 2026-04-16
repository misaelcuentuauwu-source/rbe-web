import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'seat_selection_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
// REGLAS DE NEGOCIO
//
// NIÑO  : cualquier edad (0-17).
//         - Edad < 12  → BLOQUEA avance. Mensaje: debe ser >= 12 o ir con adulto.
//         - Edad >= 12 → Puede viajar solo. Se piden datos de contacto.
//
// ESTUDIANTE : cualquier edad, sin restricción de edad.
//         - Edad >= 12 → Se piden datos de contacto (viaja solo).
//         - Edad < 12  → Sin datos de contacto (va con tutor).
//         - Siempre se pide credencial escolar.
//
// INAPAM : debe ser >= 60 años. Validación automática desde fecha de nacimiento.
//          Siempre se piden datos de contacto (teléfono + correo).
//          Siempre se pide credencial INAPAM.
//
// DISCAPACIDAD : cualquier edad.
//         - Edad >= 12 → Se piden datos de contacto (igual que Estudiante).
//         - Edad < 12  → Sin datos de contacto (va con tutor).
//         - Tipo visual   → NO se pide credencial.
//         - Otro tipo     → SÍ se pide credencial de discapacidad.
//
// ADULTO : >= 18 años. El primer adulto es el contacto principal
//          (siempre se piden teléfono + correo).
//
// NOTA: La edad ya NO se captura como número entero. Se captura como
//       fecha de nacimiento mediante DatePicker y se calcula automáticamente.
// ════════════════════════════════════════════════════════════════════════════

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
    'Niño': 0,
    'Estudiante': 25,
    'INAPAM': 30,
    'Discapacidad': 15,
  };

  // ── INICIALIZACIÓN ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _generarPasajeros();
    _prerellenarContacto();
  }

  void _generarPasajeros() {
    pasajerosList = [];

    // El primer adulto siempre es el contacto principal
    if ((widget.pasajeros['adultos'] ?? 0) > 0) {
      pasajerosList.add(_crearPasajero('Adulto', esContacto: true));
    }
    for (int i = 1; i < (widget.pasajeros['adultos'] ?? 0); i++) {
      pasajerosList.add(_crearPasajero('Adulto'));
    }
    for (int i = 0; i < (widget.pasajeros['ninos'] ?? 0); i++) {
      pasajerosList.add(_crearPasajero('Niño'));
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

    // Si no hay adultos, se aplica prioridad de contacto:
    // 1. Estudiante  2. INAPAM  3. Discapacidad
    // (Niño nunca es contacto principal)
    if ((widget.pasajeros['adultos'] ?? 0) == 0 && pasajerosList.isNotEmpty) {
      final candidato = pasajerosList.firstWhere(
        (p) => p['tipo'] == 'Estudiante',
        orElse: () => pasajerosList.firstWhere(
          (p) => p['tipo'] == 'INAPAM',
          orElse: () => pasajerosList.firstWhere(
            (p) => p['tipo'] == 'Discapacidad',
            orElse: () => <String, dynamic>{},
          ),
        ),
      );
      if (candidato.isNotEmpty) {
        candidato['esContacto'] = true;
      }
    }
  }

  // DESPUÉS
  void _prerellenarContacto() {
    if (pasajerosList.isEmpty) return;
    final contacto = pasajerosList.firstWhere(
      (p) => p['esContacto'] == true,
      orElse: () => pasajerosList.first,
    );
    if (widget.correoCliente != null) {
      (contacto['correoCtrl'] as TextEditingController).text =
          widget.correoCliente!;
    }
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

      // ── Autocompletar teléfono ──────────────────────────────
      final tel = datos['telefono']?.toString() ?? '';
      if (tel.isNotEmpty) {
        (contacto['telefonoCtrl'] as TextEditingController).text = tel;
      }

      // ── Autocompletar fecha de nacimiento ───────────────────
      final fnStr = datos['fecha_nacimiento']?.toString() ?? '';
      if (fnStr.isNotEmpty && fnStr != '2000-01-01') {
        try {
          final partes = fnStr.split('-');
          if (partes.length == 3) {
            final fn = DateTime(
              int.parse(partes[0]),
              int.parse(partes[1]),
              int.parse(partes[2]),
            );
            contacto['fechaNacimiento'] = fn;
          }
        } catch (_) {}
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
      // CAMBIO: ya no hay 'edadCtrl'. La fecha se guarda como DateTime? aquí.
      'fechaNacimiento': null, // DateTime?
      'telefonoCtrl': TextEditingController(),
      'correoCtrl': TextEditingController(),
      // Solo para Discapacidad: 'visual' | 'motriz' | 'auditiva' | 'otra'
      'tipoDiscapacidad': null,
    };
  }

  @override
  void dispose() {
    for (final p in pasajerosList) {
      (p['nombreCtrl'] as TextEditingController).dispose();
      (p['apPaternoCtrl'] as TextEditingController).dispose();
      (p['apMaternoCtrl'] as TextEditingController).dispose();
      (p['telefonoCtrl'] as TextEditingController).dispose();
      (p['correoCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  // ── LÓGICA DE NEGOCIO ────────────────────────────────────────────────────

  double _calcularPrecioConDescuento(String tipo) {
    final precioBase = double.parse(widget.precio);
    final descuento = _descuentos[tipo] ?? 0;
    return precioBase * (1 - descuento / 100);
  }

  /// Calcula la edad en años completos a partir de la fecha de nacimiento.
  /// Retorna null si la fecha no ha sido seleccionada.
  int? _edadDe(Map<String, dynamic> p) {
    final fn = p['fechaNacimiento'] as DateTime?;
    if (fn == null) return null;
    final hoy = DateTime.now();
    int edad = hoy.year - fn.year;
    // Aún no ha llegado el cumpleaños este año
    if (hoy.month < fn.month || (hoy.month == fn.month && hoy.day < fn.day)) {
      edad--;
    }
    return edad;
  }

  /// Formatea la fecha de nacimiento para mostrarla en el botón del DatePicker.
  String _formatearFecha(DateTime? fn) {
    if (fn == null) return 'Seleccionar fecha';
    return '${fn.day.toString().padLeft(2, '0')}/'
        '${fn.month.toString().padLeft(2, '0')}/'
        '${fn.year}';
  }

  /// Abre el DatePicker con límites según el tipo de pasajero y actualiza el estado.
  Future<void> _seleccionarFecha(Map<String, dynamic> pasajero) async {
    final tipo = pasajero['tipo'] as String;
    final hoy = DateTime.now();

    // Límites según tipo
    DateTime primerFecha;
    DateTime ultimaFecha;
    DateTime fechaInicial;

    switch (tipo) {
      case 'Adulto':
        // Entre 18 y 120 años
        primerFecha = DateTime(hoy.year - 120, hoy.month, hoy.day);
        ultimaFecha = DateTime(hoy.year - 18, hoy.month, hoy.day);
        fechaInicial =
            pasajero['fechaNacimiento'] as DateTime? ??
            DateTime(hoy.year - 30, hoy.month, hoy.day);
        break;
      case 'Niño':
        // Entre 0 y 17 años
        primerFecha = DateTime(hoy.year - 17, hoy.month, hoy.day);
        ultimaFecha = hoy;
        fechaInicial =
            pasajero['fechaNacimiento'] as DateTime? ??
            DateTime(hoy.year - 8, hoy.month, hoy.day);
        break;
      case 'INAPAM':
        // 60 años o más
        primerFecha = DateTime(hoy.year - 120, hoy.month, hoy.day);
        ultimaFecha = DateTime(hoy.year - 60, hoy.month, hoy.day);
        fechaInicial =
            pasajero['fechaNacimiento'] as DateTime? ??
            DateTime(hoy.year - 65, hoy.month, hoy.day);
        break;
      case 'Estudiante':
      case 'Discapacidad':
        // Sin restricción de edad (0–120)
        primerFecha = DateTime(hoy.year - 120, hoy.month, hoy.day);
        ultimaFecha = hoy;
        fechaInicial =
            pasajero['fechaNacimiento'] as DateTime? ??
            DateTime(hoy.year - 20, hoy.month, hoy.day);
        break;
      default:
        primerFecha = DateTime(hoy.year - 120, hoy.month, hoy.day);
        ultimaFecha = hoy;
        fechaInicial = pasajero['fechaNacimiento'] as DateTime? ?? hoy;
    }

    // Ajustar fechaInicial para que esté dentro del rango
    if (fechaInicial.isBefore(primerFecha)) fechaInicial = primerFecha;
    if (fechaInicial.isAfter(ultimaFecha)) fechaInicial = ultimaFecha;

    final picked = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: primerFecha,
      lastDate: ultimaFecha,
      locale: const Locale('es', 'MX'),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: azul,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textoPrincipal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => pasajero['fechaNacimiento'] = picked);
    }
  }

  /// Decide si este pasajero debe mostrar los campos de contacto
  /// (teléfono + correo). Se evalúa en cada rebuild para reaccionar
  /// en tiempo real al seleccionar la fecha de nacimiento.
  bool _necesitaContacto(Map<String, dynamic> p) {
    // Solo el pasajero marcado como contacto muestra teléfono + correo.
    if (!(p['esContacto'] as bool)) return false;

    final tipo = p['tipo'] as String;
    final edad = _edadDe(p);

    // Adulto: siempre es contacto válido (ya fue validado >=18).
    if (tipo == 'Adulto') return true;

    // INAPAM: siempre válido como contacto (adulto mayor).
    if (tipo == 'INAPAM') return true;

    // Estudiante o Discapacidad: solo si edad >= 12.
    if (tipo == 'Estudiante' || tipo == 'Discapacidad') {
      return edad != null && edad >= 12;
    }

    // Niño nunca es contacto principal.
    return false;
  }

  /// Valida la fecha de nacimiento cruzada con el tipo de pasajero.
  /// Retorna un mensaje de error o null si es válida.
  String? _validarFechaNacimiento(DateTime? fn, String tipo) {
    if (fn == null) return 'Selecciona la fecha de nacimiento';

    final hoy = DateTime.now();
    int edad = hoy.year - fn.year;
    if (hoy.month < fn.month || (hoy.month == fn.month && hoy.day < fn.day)) {
      edad--;
    }

    if (edad < 0 || edad > 120) return 'Fecha de nacimiento inválida';

    switch (tipo) {
      case 'Adulto':
        if (edad < 18) return 'El adulto debe tener 18 años o más';
        break;
      case 'Niño':
        if (edad > 17) return 'El niño debe tener 17 años o menos';
        break;
      case 'INAPAM':
        if (edad < 60) return 'INAPAM requiere 60 años o más';
        break;
      // Estudiante y Discapacidad: sin restricción de edad
    }
    return null;
  }

  /// Detecta si hay un Niño/menor con edad < 12 sin ningún Adulto en el viaje.
  bool _hayNinoMenorSinAdulto() {
    final hayAdulto = pasajerosList.any((p) => p['tipo'] == 'Adulto');
    if (hayAdulto) return false;

    return pasajerosList.any((p) {
      final tipo = p['tipo'] as String;
      final edad = _edadDe(p);
      if (edad == null) return false;

      // Niño, Estudiante o Discapacitado menor de 12 sin adulto → bloquear
      if (tipo == 'Niño' || tipo == 'Estudiante' || tipo == 'Discapacidad') {
        return edad < 12;
      }
      return false;
    });
  }

  // ── CONTINUAR ────────────────────────────────────────────────────────────

  Future<void> _continuar() async {
    // 1. Validar que todas las fechas de nacimiento estén seleccionadas y sean correctas
    bool todasFechasValidas = true;
    for (final p in pasajerosList) {
      final fn = p['fechaNacimiento'] as DateTime?;
      final error = _validarFechaNacimiento(fn, p['tipo'] as String);
      if (error != null) {
        todasFechasValidas = false;
        break;
      }
    }

    // Validar el formulario completo (nombres, correo, teléfono, etc.)
    if (!_formKey.currentState!.validate() || !todasFechasValidas) {
      if (!todasFechasValidas) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Verifica que todas las fechas de nacimiento sean correctas.',
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

    // 2. Bloquear si hay niño < 12 sin adulto
    if (_hayNinoMenorSinAdulto()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'El niño debe tener 12 años o más para viajar solo, '
              'o bien debe ir acompañado de un adulto.',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // 3. Verificar duplicado de correo
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

    // 4. Armar datos y navegar
    // Se manda 'fecha_nacimiento' en formato 'YYYY-MM-DD' y también
    // 'edad' calculada (para compatibilidad hacia atrás si se necesita).
    final pasajerosData = pasajerosList.map((p) {
      final fn = p['fechaNacimiento'] as DateTime;
      final edad = _edadDe(p) ?? 0;
      final fnStr =
          '${fn.year}-${fn.month.toString().padLeft(2, '0')}-${fn.day.toString().padLeft(2, '0')}';
      return {
        'nombre': (p['nombreCtrl'] as TextEditingController).text.trim(),
        'primer_apellido': (p['apPaternoCtrl'] as TextEditingController).text
            .trim(),
        'segundo_apellido': (p['apMaternoCtrl'] as TextEditingController).text
            .trim(),
        'fecha_nacimiento': fnStr, // ← formato YYYY-MM-DD exacto
        'edad': edad, // ← calculado, ya no escrito a mano
        'tipo': p['tipo'],
        'esContacto': p['esContacto'],
        'telefono': (p['telefonoCtrl'] as TextEditingController).text.trim(),
        'correo':
            widget.correoCliente ??
            (p['correoCtrl'] as TextEditingController).text.trim(),
        'precio_unitario': _calcularPrecioConDescuento(p['tipo']),
        'descuento': _descuentos[p['tipo']] ?? 0,
        if (p['tipo'] == 'Discapacidad')
          'tipoDiscapacidad': p['tipoDiscapacidad'],
      };
    }).toList();

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

  // ── BUILD ────────────────────────────────────────────────────────────────

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

  // ── TARJETA POR PASAJERO ─────────────────────────────────────────────────

  Widget _buildTarjetaPasajero(Map<String, dynamic> pasajero, int index) {
    final tipo = pasajero['tipo'] as String;
    final esContacto = pasajero['esContacto'] as bool;
    final descuento = _descuentos[tipo] ?? 0;
    final precioFinal = _calcularPrecioConDescuento(tipo);
    final precioBase = double.parse(widget.precio);

    final fn = pasajero['fechaNacimiento'] as DateTime?;
    final edad = _edadDe(pasajero);
    final errorFecha = _validarFechaNacimiento(fn, tipo);

    // ── Credencial requerida ─────────────────────────────────────────────
    final tipoDisc = pasajero['tipoDiscapacidad'] as String?;
    final requiereCredencial =
        (tipo == 'Estudiante') ||
        (tipo == 'INAPAM') ||
        (tipo == 'Discapacidad' && tipoDisc != null && tipoDisc != 'visual');

    final textoCredencial = tipo == 'Estudiante'
        ? 'Deberá presentar credencial escolar vigente al abordar.'
        : tipo == 'INAPAM'
        ? 'Deberá presentar credencial INAPAM al abordar.'
        : 'Deberá presentar credencial de discapacidad al abordar.';

    // ── Datos de contacto ────────────────────────────────────────────────
    final mostrarContacto = _necesitaContacto(pasajero);

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
                _badge('Pasajero ${index + 1}', azul),
                _badge(tipo, _colorTipo(tipo)),
                if (esContacto) _badge('Contacto', naranja),
                if (descuento > 0)
                  _badge(
                    '$descuento% desc.',
                    Colors.green.shade700,
                    bg: Colors.green.shade50,
                  ),
                // Muestra la edad calculada cuando la fecha ya está seleccionada
                if (fn != null && edad != null && errorFecha == null)
                  _badge(
                    '$edad años',
                    Colors.blueGrey.shade600,
                    bg: Colors.blueGrey.shade50,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Aviso cliente registrado (autorelleno) ───────
            if (esClienteRegistrado)
              _aviso(
                icono: Icons.auto_fix_high_rounded,
                texto:
                    'Datos autorrellenados con tu cuenta. '
                    'Puedes modificarlos si lo deseas.',
                color: azul,
              ),

            // ── Precio con descuento ─────────────────────────
            if (descuento > 0) ...[
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
              const SizedBox(height: 12),
            ],

            // ── Tipo de discapacidad (antes del aviso de credencial) ──
            if (tipo == 'Discapacidad') ...[
              DropdownButtonFormField<String>(
                value: tipoDisc,
                decoration: _inputDeco(
                  label: 'Tipo de discapacidad',
                  icono: Icons.accessible_rounded,
                ),
                items: const [
                  DropdownMenuItem(value: 'visual', child: Text('Visual')),
                  DropdownMenuItem(value: 'motriz', child: Text('Motriz')),
                  DropdownMenuItem(value: 'auditiva', child: Text('Auditiva')),
                  DropdownMenuItem(value: 'otra', child: Text('Otra')),
                ],
                validator: (val) =>
                    val == null ? 'Selecciona el tipo de discapacidad' : null,
                onChanged: (val) =>
                    setState(() => pasajero['tipoDiscapacidad'] = val),
              ),
              const SizedBox(height: 12),
            ],

            // ── Aviso de credencial (reactivo al tipo de discapacidad) ─
            if (requiereCredencial)
              _aviso(
                icono: Icons.info_outline_rounded,
                texto: textoCredencial,
                color: Colors.amber.shade700,
                bg: Colors.amber.shade50,
                border: Colors.amber.shade300,
              ),

            // ── Nombre + Primer apellido ─────────────────────
            Row(
              children: [
                Expanded(
                  child: _campo(
                    ctrl: pasajero['nombreCtrl'],
                    label: 'Nombre',
                    icono: Icons.person_outline_rounded,
                    validator: _requerido,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _campo(
                    ctrl: pasajero['apPaternoCtrl'],
                    label: 'Primer apellido',
                    icono: Icons.person_outline_rounded,
                    validator: _requerido,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Segundo apellido ─────────────────────────────
            _campo(
              ctrl: pasajero['apMaternoCtrl'],
              label: 'Segundo apellido (opcional)',
              icono: Icons.person_outline_rounded,
              validator: null,
            ),
            const SizedBox(height: 12),

            // ── Fecha de nacimiento (reemplaza el campo Edad) ─
            _buildSelectorFecha(pasajero, tipo, fn, edad, errorFecha),

            // ── Campos de contacto ───────────────────────────
            // Aparecen/desaparecen en tiempo real según la fecha capturada.
            if (mostrarContacto) ...[
              const SizedBox(height: 12),
              _campo(
                ctrl: pasajero['telefonoCtrl'],
                label: 'Teléfono de contacto',
                icono: Icons.phone_outlined,
                soloNumeros: true,
                maxLength: 10,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Requerido';
                  if (val.trim().length < 10) return 'Mín. 10 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Cliente con sesión: mostrar correo ya verificado.
              // Invitado / sin sesión: campo editable.
              if (widget.correoCliente == null)
                _campo(
                  ctrl: pasajero['correoCtrl'],
                  label: 'Correo electrónico',
                  icono: Icons.email_outlined,
                  esCorreo: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Requerido';
                    if (!val.contains('@')) return 'Correo inválido';
                    return null;
                  },
                )
              else
                _correoVerificado(),
            ],
          ],
        ),
      ),
    );
  }

  // ── WIDGET: Selector de fecha de nacimiento ─────────────────────────────

  Widget _buildSelectorFecha(
    Map<String, dynamic> pasajero,
    String tipo,
    DateTime? fn,
    int? edad,
    String? errorFecha,
  ) {
    final tieneError = errorFecha != null && fn != null;
    final sinSeleccionar = fn == null;

    return FormField<DateTime>(
      initialValue: fn,
      validator: (_) => _validarFechaNacimiento(
        pasajero['fechaNacimiento'] as DateTime?,
        tipo,
      ),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _seleccionarFecha(pasajero),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: field.hasError
                        ? Colors.red.shade300
                        : sinSeleccionar
                        ? Colors.grey.shade200
                        : tieneError
                        ? Colors.red.shade300
                        : azul.withOpacity(0.5),
                    width: field.hasError ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 18,
                      color: field.hasError ? Colors.red.shade400 : azul,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fecha de nacimiento',
                            style: TextStyle(
                              fontSize: 11,
                              color: field.hasError
                                  ? Colors.red.shade400
                                  : textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatearFecha(fn),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: fn != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: fn != null
                                  ? textoPrincipal
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mostrar edad calculada al lado derecho
                    if (fn != null && edad != null && errorFecha == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: azul.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$edad años',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: azul,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: fn != null ? azul : Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
            // Mensaje de error del FormField
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  field.errorText!,
                  style: TextStyle(fontSize: 11, color: Colors.red.shade600),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── WIDGETS REUTILIZABLES ────────────────────────────────────────────────

  Widget _badge(String texto, Color color, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _aviso({
    required IconData icono,
    required String texto,
    required Color color,
    Color? bg,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border ?? color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icono}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: textoSecundario),
      prefixIcon: Icon(icono, size: 18, color: azul),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
    );
  }

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    required IconData icono,
    required String? Function(String?)? validator,
    bool soloNumeros = false,
    bool esCorreo = false,
    int? maxLength,
    void Function(String)? onChanged,
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
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: _inputDeco(
        label: label,
        icono: icono,
      ).copyWith(counterText: maxLength != null ? '' : null),
      validator: validator,
    );
  }

  Widget _correoVerificado() {
    return Container(
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
                style: TextStyle(fontSize: 11, color: textoSecundario),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    );
  }

  String? _requerido(String? val) =>
      (val == null || val.trim().isEmpty) ? 'Requerido' : null;

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
      case 'Niño':
        return Colors.teal.shade500;
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
