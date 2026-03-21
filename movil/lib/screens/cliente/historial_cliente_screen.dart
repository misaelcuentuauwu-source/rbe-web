import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';

class HistorialClienteScreen extends StatefulWidget {
  final int clienteId;

  const HistorialClienteScreen({super.key, required this.clienteId});

  @override
  State<HistorialClienteScreen> createState() => _HistorialClienteScreenState();
}

class _HistorialClienteScreenState extends State<HistorialClienteScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  List<dynamic> historial = [];
  List<dynamic> historialFiltrado = [];
  bool cargando = true;
  String? error;

  // Filtros
  DateTime? fechaDesde;
  DateTime? fechaHasta;
  String? origenFiltro;
  String? destinoFiltro;
  String? estadoFiltro;
  bool mostrarFiltros = false;

  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

  // Estados disponibles con colores e íconos
  static const Map<String, Map<String, dynamic>> _estados = {
    'Disponible': {
      'color': Color(0xFF2E7D32),
      'bg': Color(0xFFE8F5E9),
      'icono': Icons.check_circle_outline_rounded,
    },
    'En Ruta': {
      'color': Color(0xFF1565C0),
      'bg': Color(0xFFE3F2FD),
      'icono': Icons.directions_bus_rounded,
    },
    'Finalizado': {
      'color': Color(0xFF6B8FA8),
      'bg': Color(0xFFF4F6F9),
      'icono': Icons.flag_rounded,
    },
    'Cancelado': {
      'color': Color(0xFFC62828),
      'bg': Color(0xFFFFEBEE),
      'icono': Icons.cancel_outlined,
    },
    'Retrasado': {
      'color': Color(0xFFE65100),
      'bg': Color(0xFFFFF3E0),
      'icono': Icons.schedule_rounded,
    },
  };

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    super.dispose();
  }

  Future<void> cargarHistorial() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${Config.baseUrl}/api/historial/cliente/${widget.clienteId}/',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          historial = jsonDecode(response.body);
          historialFiltrado = List.from(historial);
          cargando = false;
        });
      } else {
        setState(() {
          error = 'Error al cargar historial';
          cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error de conexión';
        cargando = false;
      });
    }
  }

  void aplicarFiltros() {
    setState(() {
      historialFiltrado = historial.where((item) {
        if (fechaDesde != null) {
          final fechaItem = DateTime.tryParse(item['fecha'].toString());
          if (fechaItem == null || fechaItem.isBefore(fechaDesde!))
            return false;
        }
        if (fechaHasta != null) {
          final fechaItem = DateTime.tryParse(item['fecha'].toString());
          final fechaHastaFin = DateTime(
            fechaHasta!.year,
            fechaHasta!.month,
            fechaHasta!.day,
            23,
            59,
            59,
          );
          if (fechaItem == null || fechaItem.isAfter(fechaHastaFin))
            return false;
        }
        if (origenFiltro != null && origenFiltro!.isNotEmpty) {
          if (!item['origen'].toString().toLowerCase().contains(
            origenFiltro!.toLowerCase(),
          ))
            return false;
        }
        if (destinoFiltro != null && destinoFiltro!.isNotEmpty) {
          if (!item['destino'].toString().toLowerCase().contains(
            destinoFiltro!.toLowerCase(),
          ))
            return false;
        }
        if (estadoFiltro != null && estadoFiltro!.isNotEmpty) {
          if (item['estado'].toString() != estadoFiltro) return false;
        }
        return true;
      }).toList();
    });
  }

  void limpiarFiltros() {
    setState(() {
      fechaDesde = null;
      fechaHasta = null;
      origenFiltro = null;
      destinoFiltro = null;
      estadoFiltro = null;
      _origenController.clear();
      _destinoController.clear();
      historialFiltrado = List.from(historial);
    });
  }

  bool get hayFiltrosActivos =>
      fechaDesde != null ||
      fechaHasta != null ||
      (origenFiltro != null && origenFiltro!.isNotEmpty) ||
      (destinoFiltro != null && destinoFiltro!.isNotEmpty) ||
      (estadoFiltro != null && estadoFiltro!.isNotEmpty);

  Future<void> seleccionarFecha(BuildContext context, bool esDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: azul)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (esDesde) {
          fechaDesde = picked;
        } else {
          fechaHasta = picked;
        }
      });
      aplicarFiltros();
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (mostrarFiltros) _buildPanelFiltros(),
            if (hayFiltrosActivos) _buildChipsFiltros(),
            Expanded(child: _buildContenido()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          const Icon(
            Icons.confirmation_number_outlined,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis boletos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Historial de compras',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => mostrarFiltros = !mostrarFiltros),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mostrarFiltros
                    ? Colors.white
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: mostrarFiltros ? azul : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      color: mostrarFiltros ? azul : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hayFiltrosActivos) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: naranja,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fecha desde - hasta
          Row(
            children: [
              Expanded(
                child: _buildBotonFecha(
                  label: 'Desde',
                  fecha: fechaDesde,
                  onTap: () => seleccionarFecha(context, true),
                  onClear: fechaDesde != null
                      ? () {
                          setState(() => fechaDesde = null);
                          aplicarFiltros();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBotonFecha(
                  label: 'Hasta',
                  fecha: fechaHasta,
                  onTap: () => seleccionarFecha(context, false),
                  onClear: fechaHasta != null
                      ? () {
                          setState(() => fechaHasta = null);
                          aplicarFiltros();
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Origen
          TextField(
            controller: _origenController,
            decoration: InputDecoration(
              hintText: 'Ciudad de origen',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.trip_origin_rounded,
                color: azul,
                size: 18,
              ),
              suffixIcon: origenFiltro != null && origenFiltro!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _origenController.clear();
                        setState(() => origenFiltro = null);
                        aplicarFiltros();
                      },
                    )
                  : null,
              filled: true,
              fillColor: fondo,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) {
              setState(() => origenFiltro = val);
              aplicarFiltros();
            },
          ),
          const SizedBox(height: 8),
          // Destino
          TextField(
            controller: _destinoController,
            decoration: InputDecoration(
              hintText: 'Ciudad de destino',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: naranja,
                size: 18,
              ),
              suffixIcon: destinoFiltro != null && destinoFiltro!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        _destinoController.clear();
                        setState(() => destinoFiltro = null);
                        aplicarFiltros();
                      },
                    )
                  : null,
              filled: true,
              fillColor: fondo,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (val) {
              setState(() => destinoFiltro = val);
              aplicarFiltros();
            },
          ),
          const SizedBox(height: 10),
          // Filtro de estado
          const Text(
            'Estado del viaje',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChipEstado(null, 'Todos'),
              ..._estados.keys.map(
                (estado) => _buildChipEstado(estado, estado),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hayFiltrosActivos)
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: limpiarFiltros,
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Limpiar filtros'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChipEstado(String? valor, String etiqueta) {
    final seleccionado = estadoFiltro == valor;
    final info = valor != null ? _estados[valor] : null;
    final color = info != null ? info['color'] as Color : azul;
    final bg = info != null ? info['bg'] as Color : azul.withOpacity(0.1);
    final icono = info != null ? info['icono'] as IconData : Icons.list_rounded;

    return GestureDetector(
      onTap: () {
        setState(() => estadoFiltro = valor);
        aplicarFiltros();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? color : fondo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: seleccionado ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: seleccionado ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: seleccionado ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonFecha({
    required String label,
    required DateTime? fecha,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fecha != null ? azul : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: fecha != null ? azul : Colors.grey,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                fecha != null ? _formatFecha(fecha) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: fecha != null ? textoPrincipal : Colors.grey,
                  fontWeight: fecha != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipsFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '${historialFiltrado.length} resultado(s)',
            style: const TextStyle(fontSize: 12, color: textoSecundario),
          ),
          const Spacer(),
          if (hayFiltrosActivos)
            GestureDetector(
              onTap: limpiarFiltros,
              child: const Text(
                'Limpiar todo',
                style: TextStyle(
                  fontSize: 12,
                  color: azul,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 60),
            const SizedBox(height: 16),
            Text(error!, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    if (historial.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              color: Colors.grey.shade300,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes boletos aún',
              style: TextStyle(color: textoSecundario, fontSize: 15),
            ),
          ],
        ),
      );
    }
    if (historialFiltrado.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.grey.shade300,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin resultados para los filtros aplicados',
              style: TextStyle(color: textoSecundario, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: limpiarFiltros,
              child: const Text(
                'Limpiar filtros',
                style: TextStyle(color: azul),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: cargarHistorial,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: historialFiltrado.length,
        itemBuilder: (context, index) =>
            _buildTarjeta(historialFiltrado[index]),
      ),
    );
  }

  Widget _buildTarjeta(Map<String, dynamic> item) {
    final estado = item['estado']?.toString() ?? '';
    final infoEstado = _estados[estado];
    final colorEstado = infoEstado != null
        ? infoEstado['color'] as Color
        : Colors.grey.shade500;
    final bgEstado = infoEstado != null
        ? infoEstado['bg'] as Color
        : Colors.grey.shade100;
    final iconoEstado = infoEstado != null
        ? infoEstado['icono'] as IconData
        : Icons.help_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Folio #${item['folio']}',
                  style: const TextStyle(
                    color: azul,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Badge de estado
              if (estado.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bgEstado,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconoEstado, size: 12, color: colorEstado),
                      const SizedBox(width: 4),
                      Text(
                        estado,
                        style: TextStyle(
                          color: colorEstado,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                '\$${item['monto']} MXN',
                style: const TextStyle(
                  color: naranja,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, color: azul, size: 14),
              const SizedBox(width: 6),
              Text(
                item['origen'],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.location_on_rounded, color: naranja, size: 14),
              const SizedBox(width: 6),
              Text(
                item['destino'],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.grey.shade400,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                item['fecha'].toString().substring(0, 10),
                style: TextStyle(fontSize: 12, color: textoSecundario),
              ),
              const SizedBox(width: 16),
              Icon(Icons.people_outline, color: Colors.grey.shade400, size: 13),
              const SizedBox(width: 6),
              Text(
                '${item['num_pasajeros']} pasajero(s)',
                style: TextStyle(fontSize: 12, color: textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Próximamente: reimprimir boleto'),
                    backgroundColor: azul,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: azul,
                side: const BorderSide(color: azul, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'Reimprimir boleto',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
