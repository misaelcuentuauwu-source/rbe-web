import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../config.dart';
import 'resultados_screen.dart';

class InicioScreen extends StatefulWidget {
  final int? vendedorId;
  final int? clienteId;
  final String? correoCliente;
  final String tipoUsuario;
  final Map<String, dynamic>? datosUsuario;

  const InicioScreen({
    super.key,
    this.vendedorId,
    this.clienteId,
    this.correoCliente,
    this.tipoUsuario = 'invitado',
    this.datosUsuario,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  Color get colorPrimario =>
      widget.tipoUsuario == 'taquillero' ? naranja : azul;
  Color get colorSecundario =>
      widget.tipoUsuario == 'taquillero' ? azul : naranja;

  String? origenSeleccionado;
  // null = "Todas las ciudades"
  String? destinoSeleccionado;
  // Fecha default = hoy
  DateTime fechaSeleccionada = DateTime.now();

  int adultos = 1;
  int estudiantes = 0;
  int inapam = 0;
  int discapacidad = 0;

  int get totalPasajeros => adultos + estudiantes + inapam + discapacidad;

  List<Map<String, dynamic>> terminales = [];
  bool cargandoTerminales = true;
  bool detectandoUbicacion = false;

  // Coordenadas aproximadas de cada ciudad en Baja California
  // Clave: clave de ciudad en BD, Valor: [lat, lng]
  static const Map<String, List<double>> _coordsCiudades = {
    'TJ':  [32.5149, -117.0382], // Tijuana
    'MXL': [32.6245, -115.4523], // Mexicali
    'ENS': [31.8667, -116.5963], // Ensenada
    'TEC': [32.5728, -116.6275], // Tecate
    'RSO': [32.3333, -117.0500], // Rosarito
    'SQN': [30.5333, -115.9500], // San Quintín
    'SFE': [31.0231, -114.8260], // San Felipe
  };

  @override
  void initState() {
    super.initState();
    cargarTerminales();
  }

  Future<void> cargarTerminales() async {
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/terminales/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          terminales = data.map((t) => Map<String, dynamic>.from(t)).toList();
          cargandoTerminales = false;
        });
        // Una vez que tenemos terminales, detectar ubicación
        _detectarOrigenPorGPS();
      } else {
        setState(() => cargandoTerminales = false);
      }
    } catch (e) {
      debugPrint('Error cargando terminales: $e');
      setState(() => cargandoTerminales = false);
    }
  }

  // ── GPS: detectar ciudad más cercana ──────────────────────────
  Future<void> _detectarOrigenPorGPS() async {
    setState(() => detectandoUbicacion = true);

    try {
      // Verificar permisos
      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        // Sin permiso: no asignamos origen, el usuario lo elige manualmente
        setState(() => detectandoUbicacion = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 8));

      // Buscar la ciudad más cercana comparando distancia
      String? ciudadMasCercana;
      double menorDistancia = double.infinity;

      _coordsCiudades.forEach((clave, coords) {
        final distancia = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          coords[0],
          coords[1],
        );
        if (distancia < menorDistancia) {
          menorDistancia = distancia;
          ciudadMasCercana = clave;
        }
      });

      if (ciudadMasCercana != null) {
        // Buscar la terminal que corresponde a esa ciudad
        final terminal = terminales.firstWhere(
          (t) => t['ciudad']['clave'] == ciudadMasCercana,
          orElse: () => {},
        );
        if (terminal.isNotEmpty && mounted) {
          setState(() {
            origenSeleccionado = terminal['numero'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error detectando ubicación: $e');
      // Silencioso: si falla GPS el usuario elige manualmente
    } finally {
      if (mounted) setState(() => detectandoUbicacion = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day), // desde hoy
      lastDate: DateTime(2027, 12, 31),
      locale: const Locale('es'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorPrimario,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textoPrincipal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (fecha != null) setState(() => fechaSeleccionada = fecha);
  }

  void _incrementar(String tipo) {
    setState(() {
      if (tipo == 'discapacidad') {
        if (discapacidad < 2 && totalPasajeros < 5) discapacidad++;
      } else {
        if (totalPasajeros < 5) {
          if (tipo == 'adultos') adultos++;
          if (tipo == 'estudiantes') estudiantes++;
          if (tipo == 'inapam') inapam++;
        }
      }
    });
  }

  void _decrementar(String tipo) {
    setState(() {
      if (tipo == 'adultos' && adultos > 0) adultos--;
      if (tipo == 'estudiantes' && estudiantes > 0) estudiantes--;
      if (tipo == 'inapam' && inapam > 0) inapam--;
      if (tipo == 'discapacidad' && discapacidad > 0) discapacidad--;
    });
  }

  void _buscar() {
    if (origenSeleccionado == null) {
      _mostrarError('Selecciona un origen');
      return;
    }
    // destinoSeleccionado == null significa "Todas"
    if (destinoSeleccionado != null &&
        origenSeleccionado == destinoSeleccionado) {
      _mostrarError('El origen y destino no pueden ser iguales');
      return;
    }
    if (totalPasajeros == 0) {
      _mostrarError('Agrega al menos un pasajero');
      return;
    }

    final origenNombre = terminales.firstWhere(
      (t) => t['numero'].toString() == origenSeleccionado,
    )['ciudad']['nombre'];

    final destinoNombre = destinoSeleccionado == null
        ? 'Todas'
        : terminales.firstWhere(
            (t) => t['numero'].toString() == destinoSeleccionado,
          )['ciudad']['nombre'];

    Navigator.push(
      context,
      AppRoutes.slideLeft(ResultadosScreen(
        origen: origenSeleccionado!,
        destino: destinoSeleccionado ?? 'todas',
        origenNombre: origenNombre,
        destinoNombre: destinoNombre,
        fecha: fechaSeleccionada,
        pasajeros: {
          'adultos': adultos,
          'estudiantes': estudiantes,
          'inapam': inapam,
          'discapacidad': discapacidad,
        },
        vendedorId: widget.vendedorId ?? widget.clienteId ?? 0,
        correoCliente: widget.correoCliente,
        tipoUsuario: widget.tipoUsuario,
        buscarCercanos: true,
        datosUsuario: widget.datosUsuario,
      )),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return isLandscape ? _buildLandscape() : _buildPortrait();
          },
        ),
      ),
    );
  }

  Widget _buildPortrait() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildRutaFecha(),
                const SizedBox(height: 16),
                _buildPasajerosCard(),
                const SizedBox(height: 20),
                _buildBotonBuscar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscape() {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildRutaFecha(),
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, color: Color(0xFFE0E0E0)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildPasajerosCard(),
                const SizedBox(height: 16),
                _buildBotonBuscar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: colorPrimario,
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
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rutas Baja Express',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '¿A dónde viajas hoy?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          // Botón para re-detectar ubicación
          GestureDetector(
            onTap: detectandoUbicacion ? null : _detectarOrigenPorGPS,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: detectandoUbicacion
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRutaFecha() {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: cargandoTerminales
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: colorPrimario),
                    const SizedBox(height: 10),
                    Text(
                      'Cargando terminales...',
                      style: TextStyle(color: textoSecundario, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: colorPrimario,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ruta',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                    const Spacer(),
                    // Indicador GPS si está detectando
                    if (detectandoUbicacion)
                      Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: colorPrimario,
                              strokeWidth: 1.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Detectando ubicación...',
                            style: TextStyle(
                              fontSize: 11,
                              color: textoSecundario,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Origen (con GPS) ──
                _buildDropdownOrigen(),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorPrimario.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: colorPrimario,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ── Destino (con opción "Todas") ──
                _buildDropdownDestino(),
                const SizedBox(height: 18),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: colorSecundario,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Fecha de viaje',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Selector de fecha (default: hoy) ──
                GestureDetector(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorPrimario,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: colorPrimario.withOpacity(0.04),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: colorPrimario,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatearFecha(fechaSeleccionada),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textoPrincipal,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_esHoy(fechaSeleccionada))
                                Text(
                                  'Hoy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorPrimario,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_rounded,
                          color: colorPrimario.withOpacity(0.6),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Nota sobre viajes cercanos
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorSecundario.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: colorSecundario,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Si no hay viajes en esta fecha, te mostramos los más cercanos disponibles',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorSecundario,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Dropdown de origen (sin opción "Todas") ───────────────────
  Widget _buildDropdownOrigen() {
    return DropdownButtonFormField<String>(
      value: origenSeleccionado,
      decoration: InputDecoration(
        hintText: detectandoUbicacion ? 'Detectando ubicación...' : 'Origen',
        hintStyle: TextStyle(color: textoSecundario, fontSize: 14),
        prefixIcon: Icon(
          Icons.trip_origin_rounded,
          color: colorPrimario,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorPrimario, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: terminales
          .map(
            (t) => DropdownMenuItem<String>(
              value: t['numero'].toString(),
              child: Text(
                t['ciudad']['nombre'],
                style: const TextStyle(fontSize: 14, color: textoPrincipal),
              ),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => origenSeleccionado = val),
    );
  }

  // ── Dropdown de destino (con opción "Todas las ciudades") ──────
  Widget _buildDropdownDestino() {
    return DropdownButtonFormField<String>(
      value: destinoSeleccionado,
      decoration: InputDecoration(
        hintText: 'Destino',
        hintStyle: TextStyle(color: textoSecundario, fontSize: 14),
        prefixIcon: Icon(
          Icons.location_on_rounded,
          color: colorPrimario,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorPrimario, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: [
        // Opción especial "Todas"
        DropdownMenuItem<String>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.public_rounded, color: colorPrimario, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Todas las ciudades',
                style: TextStyle(
                  fontSize: 14,
                  color: textoPrincipal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ...terminales.map(
          (t) => DropdownMenuItem<String>(
            value: t['numero'].toString(),
            child: Text(
              t['ciudad']['nombre'],
              style: const TextStyle(fontSize: 14, color: textoPrincipal),
            ),
          ),
        ),
      ],
      onChanged: (val) => setState(() => destinoSeleccionado = val),
    );
  }

  // ── Helpers de fecha ──────────────────────────────────────────
  String _formatearFecha(DateTime fecha) {
    const meses = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[fecha.weekday - 1]} ${fecha.day} ${meses[fecha.month]} ${fecha.year}';
  }

  bool _esHoy(DateTime fecha) {
    final hoy = DateTime.now();
    return fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
  }

  Widget _buildPasajerosCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  color: colorPrimario,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pasajeros',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: totalPasajeros >= 5
                      ? Colors.red.shade50
                      : colorPrimario.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalPasajeros / 5',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: totalPasajeros >= 5
                        ? Colors.red.shade700
                        : colorPrimario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContador('Adulto', 'adultos', adultos, Icons.person_rounded),
          Divider(height: 20, color: Colors.grey.shade100),
          _buildContador(
            'Estudiante',
            'estudiantes',
            estudiantes,
            Icons.school_rounded,
          ),
          Divider(height: 20, color: Colors.grey.shade100),
          _buildContador('INAPAM', 'inapam', inapam, Icons.elderly_rounded),
          Divider(height: 20, color: Colors.grey.shade100),
          _buildContador(
            'Discapacidad',
            'discapacidad',
            discapacidad,
            Icons.accessible_rounded,
            max: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildContador(
    String label,
    String tipo,
    int valor,
    IconData icono, {
    int max = 5,
  }) {
    final bool puedeIncrementar = totalPasajeros < 5 && valor < max;
    final bool puedeDecrementar = valor > 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colorPrimario.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: colorPrimario, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textoPrincipal,
                ),
              ),
              if (tipo == 'discapacidad')
                Text(
                  'Máx. 2 por viaje',
                  style: TextStyle(fontSize: 11, color: textoSecundario),
                ),
            ],
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: puedeDecrementar ? () => _decrementar(tipo) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: puedeDecrementar
                      ? colorPrimario.withOpacity(0.08)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: puedeDecrementar
                      ? colorPrimario
                      : Colors.grey.shade300,
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$valor',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textoPrincipal,
                ),
              ),
            ),
            GestureDetector(
              onTap: puedeIncrementar ? () => _incrementar(tipo) : null,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: puedeIncrementar
                      ? colorPrimario.withOpacity(0.08)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: puedeIncrementar
                      ? colorPrimario
                      : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotonBuscar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _buscar,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          shadowColor: colorPrimario.withOpacity(0.3),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Buscar viajes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
