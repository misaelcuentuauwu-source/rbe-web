import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'resultados_screen.dart';

class InicioScreen extends StatefulWidget {
  final int vendedorId;
  const InicioScreen({super.key, required this.vendedorId});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  String? origenSeleccionado;
  String? destinoSeleccionado;
  DateTime? fechaSeleccionada;

  int adultos = 1;
  int estudiantes = 0;
  int inapam = 0;
  int discapacidad = 0;

  int get totalPasajeros => adultos + estudiantes + inapam + discapacidad;

  List<Map<String, dynamic>> terminales = [];
  bool cargandoTerminales = true;

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
      } else {
        setState(() => cargandoTerminales = false);
      }
    } catch (e) {
      debugPrint('Error cargando terminales: $e');
      setState(() => cargandoTerminales = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 2, 1),
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2026, 12, 31),
      locale: const Locale('es'),
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
    if (destinoSeleccionado == null) {
      _mostrarError('Selecciona un destino');
      return;
    }
    if (origenSeleccionado == destinoSeleccionado) {
      _mostrarError('El origen y destino no pueden ser iguales');
      return;
    }
    if (fechaSeleccionada == null) {
      _mostrarError('Selecciona una fecha');
      return;
    }
    if (totalPasajeros == 0) {
      _mostrarError('Agrega al menos un pasajero');
      return;
    }

    final origenNombre = terminales.firstWhere(
      (t) => t['numero'].toString() == origenSeleccionado,
    )['ciudad']['nombre'];
    final destinoNombre = terminales.firstWhere(
      (t) => t['numero'].toString() == destinoSeleccionado,
    )['ciudad']['nombre'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosScreen(
          origen: origenSeleccionado!,
          destino: destinoSeleccionado!,
          origenNombre: origenNombre,
          destinoNombre: destinoNombre,
          fecha: fechaSeleccionada!,
          pasajeros: {
            'adultos': adultos,
            'estudiantes': estudiantes,
            'inapam': inapam,
            'discapacidad': discapacidad,
          },
          vendedorId: widget.vendedorId,
        ),
      ),
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
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rutas Baja Express',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '¿A dónde viajas hoy?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
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
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: azul),
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
                        color: azul,
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
                  ],
                ),
                const SizedBox(height: 14),
                _buildDropdown(
                  valor: origenSeleccionado,
                  hint: 'Origen',
                  icono: Icons.trip_origin_rounded,
                  onChanged: (val) => setState(() => origenSeleccionado = val),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: azul.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: azul,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildDropdown(
                  valor: destinoSeleccionado,
                  hint: 'Destino',
                  icono: Icons.location_on_rounded,
                  onChanged: (val) => setState(() => destinoSeleccionado = val),
                ),
                const SizedBox(height: 18),
                Divider(color: Colors.grey.shade100, height: 1),
                const SizedBox(height: 14),
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
                GestureDetector(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: fechaSeleccionada != null
                            ? azul
                            : Colors.grey.shade200,
                        width: fechaSeleccionada != null ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: fechaSeleccionada != null
                          ? azul.withOpacity(0.04)
                          : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: fechaSeleccionada != null
                              ? azul
                              : textoSecundario,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          fechaSeleccionada != null
                              ? '${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}'
                              : 'Seleccionar fecha',
                          style: TextStyle(
                            fontSize: 14,
                            color: fechaSeleccionada != null
                                ? textoPrincipal
                                : textoSecundario,
                          ),
                        ),
                        const Spacer(),
                        if (fechaSeleccionada != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => fechaSeleccionada = null),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDropdown({
    required String? valor,
    required String hint,
    required IconData icono,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: valor,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textoSecundario, fontSize: 14),
        prefixIcon: Icon(icono, color: azul, size: 20),
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
          borderSide: const BorderSide(color: azul, width: 1.5),
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
      onChanged: onChanged,
      hint: Text(hint, style: TextStyle(color: textoSecundario, fontSize: 14)),
    );
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
                  color: azul,
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
                      : azul.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalPasajeros / 5',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: totalPasajeros >= 5 ? Colors.red.shade700 : azul,
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
            color: azul.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: azul, size: 18),
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
                      ? azul.withOpacity(0.08)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: puedeDecrementar ? azul : Colors.grey.shade300,
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
                      ? azul.withOpacity(0.08)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: puedeIncrementar ? azul : Colors.grey.shade300,
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
          backgroundColor: naranja,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          shadowColor: naranja.withOpacity(0.3),
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
