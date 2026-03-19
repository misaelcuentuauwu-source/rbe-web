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
  List<dynamic> historialFiltrado = [];
  bool cargando = true;

  // Filtros
  DateTime? fechaDesde;
  DateTime? fechaHasta;
  String? origenFiltro;
  String? destinoFiltro;
  bool mostrarFiltros = false;

  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

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
            Uri.parse('${Config.baseUrl}/api/historial/${widget.vendedorId}/'),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          historial = jsonDecode(response.body) as List;
          historialFiltrado = List.from(historial);
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
      _origenController.clear();
      _destinoController.clear();
      historialFiltrado = List.from(historial);
    });
  }

  bool get hayFiltrosActivos =>
      fechaDesde != null ||
      fechaHasta != null ||
      (origenFiltro != null && origenFiltro!.isNotEmpty) ||
      (destinoFiltro != null && destinoFiltro!.isNotEmpty);

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

  String _formatFechaCorta(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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
            if (mostrarFiltros) _buildPanelFiltros(),
            if (hayFiltrosActivos) _buildBarraResultados(),
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
                cargando
                    ? ''
                    : hayFiltrosActivos
                    ? '${historialFiltrado.length} de ${historial.length} venta(s)'
                    : '${historial.length} venta(s)',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          // Botón filtros
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
          const SizedBox(width: 8),
          // Botón refresh
          GestureDetector(
            onTap: () {
              limpiarFiltros();
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
                fecha != null ? _formatFechaCorta(fecha) : label,
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

  Widget _buildBarraResultados() {
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: historialFiltrado.length,
      itemBuilder: (context, index) => _buildTarjeta(historialFiltrado[index]),
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
