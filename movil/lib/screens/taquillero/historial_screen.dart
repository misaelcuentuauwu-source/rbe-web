import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../config.dart';
import '../../utils/pdf_boleto.dart';

// ─────────────────────────────────────────────────────────
//  HISTORIAL SCREEN  –  RBE v4
//  BUG FIX: crash _dependents.isEmpty resuelto.
//  Causa: _iniciarAnimacionCards() disponía los AnimationController
//  mientras sus CurvedAnimation hijos seguían vivos en el árbol.
//  Solución: guardar los CurvedAnimation en listas propias y
//  disponerlos ANTES de disponer el controller padre.
// ─────────────────────────────────────────────────────────

class HistorialScreen extends StatefulWidget {
  final int vendedorId;
  const HistorialScreen({super.key, required this.vendedorId});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with TickerProviderStateMixin {
  // ── Paleta ────────────────────────────────────────────
  static const naranja = Color(0xFFE9713A);
  static const azul = Color(0xFF2C7FB1);
  static const fondo = Color(0xFFF0F3F8);
  static const surface = Colors.white;
  static const dark = Color(0xFF1C2D3A);
  static const muted = Color(0xFF8FA8BE);

  // ── Estado ────────────────────────────────────────────
  List<dynamic> historial = [];
  List<dynamic> historialFiltrado = [];
  bool cargando = true;
  bool mostrarFiltros = false;

  String _filtroVendedor = 'todas';
  DateTime? fechaDesde;
  DateTime? fechaHasta;
  String? origenFiltro;
  String? destinoFiltro;
  String? estadoFiltro;
  String _tipoFiltroFecha = 'viaje';

  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();

  Set<int> _reimprimiendoFolios = {};

  // ── Animaciones ───────────────────────────────────────
  late AnimationController _filterPanelCtrl;
  late Animation<double> _filterPanelAnim;

  // BUG FIX: guardamos TANTO el controller COMO los CurvedAnimation
  // para poder disponer los hijos antes que el padre.
  final List<AnimationController> _cardCtrls = [];
  final List<CurvedAnimation> _cardFadeCurves = []; // ← nuevo
  final List<CurvedAnimation> _cardSlideCurves = []; // ← nuevo
  final List<Animation<double>> _cardFadeAnims = [];
  final List<Animation<Offset>> _cardSlideAnims = [];

  // ── Metadatos de estados ──────────────────────────────
  static const _estados = {
    'Disponible': _EstadoMeta(
      color: Color(0xFF2E7D32),
      bg: Color(0xFFE8F5E9),
      icon: Icons.check_circle_outline_rounded,
    ),
    'En Ruta': _EstadoMeta(
      color: Color(0xFF1565C0),
      bg: Color(0xFFE3F2FD),
      icon: Icons.directions_bus_rounded,
      pulsa: true,
    ),
    'Finalizado': _EstadoMeta(
      color: Color(0xFF8FA8BE),
      bg: Color(0xFFF0F3F8),
      icon: Icons.flag_rounded,
    ),
    'Cancelado': _EstadoMeta(
      color: Color(0xFFC62828),
      bg: Color(0xFFFFEBEE),
      icon: Icons.cancel_outlined,
    ),
    'Retrasado': _EstadoMeta(
      color: Color(0xFFE65100),
      bg: Color(0xFFFFF3E0),
      icon: Icons.watch_later_outlined,
    ),
  };

  @override
  void initState() {
    super.initState();
    _filterPanelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _filterPanelAnim = CurvedAnimation(
      parent: _filterPanelCtrl,
      curve: Curves.easeInOutCubic,
    );
    cargarHistorial();
  }

  @override
  void dispose() {
    _filterPanelCtrl.dispose();
    _origenCtrl.dispose();
    _destinoCtrl.dispose();
    _limpiarAnimacionCards(); // usa el método seguro
    super.dispose();
  }

  // ── BUG FIX: disponer hijos ANTES que padres ──────────
  void _limpiarAnimacionCards() {
    // 1. Disponer CurvedAnimations (hijos) primero
    for (final c in _cardFadeCurves) {
      c.dispose();
    }
    for (final c in _cardSlideCurves) {
      c.dispose();
    }
    _cardFadeCurves.clear();
    _cardSlideCurves.clear();
    _cardFadeAnims.clear();
    _cardSlideAnims.clear();

    // 2. Ahora sí disponer los controllers (padres)
    for (final c in _cardCtrls) {
      c.dispose();
    }
    _cardCtrls.clear();
  }

  void _iniciarAnimacionCards(int count) {
    _limpiarAnimacionCards(); // limpieza segura antes de crear nuevos

    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );

      final fadeCurve = CurvedAnimation(parent: ctrl, curve: Curves.easeOut);
      final slideCurve = CurvedAnimation(
        parent: ctrl,
        curve: Curves.easeOutCubic,
      );
      final slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(slideCurve);

      _cardCtrls.add(ctrl);
      _cardFadeCurves.add(fadeCurve); // guardamos referencia al hijo
      _cardSlideCurves.add(slideCurve); // guardamos referencia al hijo
      _cardFadeAnims.add(fadeCurve);
      _cardSlideAnims.add(slideAnim);

      Future.delayed(Duration(milliseconds: 60 * i), () {
        if (mounted) ctrl.forward();
      });
    }
  }

  // ── Data ──────────────────────────────────────────────
  Future<void> cargarHistorial() async {
    setState(() => cargando = true);
    try {
      final res = await http
          .get(Uri.parse('${Config.baseUrl}/api/historial/'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          setState(() {
            historial = decoded;
            cargando = false;
          });
          aplicarFiltros();
        } else {
          debugPrint('Respuesta inesperada del backend: $decoded');
          setState(() => cargando = false);
        }
      } else {
        debugPrint('Error HTTP ${res.statusCode}: ${res.body}');
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Excepción al cargar historial: $e');
      setState(() => cargando = false);
    }
  }

  // ── Reimprimir ────────────────────────────────────────
  Future<void> _reimprimir(BuildContext ctx, int folio) async {
    if (_reimprimiendoFolios.contains(folio)) return;
    setState(() => _reimprimiendoFolios.add(folio));

    try {
      final res = await http
          .get(Uri.parse('${Config.baseUrl}/api/boleto/$folio/detalle/'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        _snack(ctx, 'No se pudieron obtener los datos del boleto', true);
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final pasajeros = (data['pasajeros'] as List).map((p) {
        return {
          'nombre': p['nombre'],
          'primer_apellido': p['primer_apellido'],
          'asiento_etiqueta': p['asiento_etiqueta'],
          'asiento_id': p['asiento_id'],
          'tipo': p['tipo'],
          'precio_unitario':
              double.tryParse(p['precio_unitario'].toString()) ?? 0.0,
        };
      }).toList();

      final pdfBytes = await PdfBoleto.generar(
        pagoId: folio,
        origenNombre: data['origen'],
        destinoNombre: data['destino'],
        horaSalida: data['hora_salida'],
        horaLlegada: data['hora_llegada'] ?? '',
        fechaViaje: data['fecha_viaje'] ?? '',
        montoTotal: double.tryParse(data['monto'].toString()) ?? 0.0,
        pasajeros: List<Map<String, dynamic>>.from(pasajeros),
        metodoPago: data['metodo_pago_id'] ?? 1,
      );

      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      debugPrint('Error reimprimir: $e');
      _snack(ctx, 'Error al generar el boleto', true);
    } finally {
      if (mounted) setState(() => _reimprimiendoFolios.remove(folio));
    }
  }

  // ── Filtros ───────────────────────────────────────────
  void aplicarFiltros() {
    setState(() {
      historialFiltrado = historial.where((item) {
        if (_filtroVendedor == 'mias') {
          if (item['vendedor_id']?.toString() != widget.vendedorId.toString()) {
            return false;
          }
        }

        final campo = _tipoFiltroFecha == 'viaje'
            ? item['hora_salida']
            : item['fecha'];

        if (fechaDesde != null) {
          final dt = DateTime.tryParse(campo.toString());
          if (dt == null || dt.isBefore(fechaDesde!)) return false;
        }
        if (fechaHasta != null) {
          final dt = DateTime.tryParse(campo.toString());
          final fin = DateTime(
            fechaHasta!.year,
            fechaHasta!.month,
            fechaHasta!.day,
            23,
            59,
            59,
          );
          if (dt == null || dt.isAfter(fin)) return false;
        }
        if (origenFiltro?.isNotEmpty == true) {
          if (!item['origen'].toString().toLowerCase().contains(
            origenFiltro!.toLowerCase(),
          ))
            return false;
        }
        if (destinoFiltro?.isNotEmpty == true) {
          if (!item['destino'].toString().toLowerCase().contains(
            destinoFiltro!.toLowerCase(),
          ))
            return false;
        }
        if (estadoFiltro?.isNotEmpty == true) {
          if (item['estado'].toString() != estadoFiltro) return false;
        }
        return true;
      }).toList();
    });
    _iniciarAnimacionCards(historialFiltrado.length);
  }

  void limpiarFiltros() {
    setState(() {
      fechaDesde = fechaHasta = origenFiltro = destinoFiltro = estadoFiltro =
          null;
      _filtroVendedor = 'todas';
      _origenCtrl.clear();
      _destinoCtrl.clear();
    });
    aplicarFiltros();
  }

  bool get hayFiltros =>
      fechaDesde != null ||
      fechaHasta != null ||
      (origenFiltro?.isNotEmpty == true) ||
      (destinoFiltro?.isNotEmpty == true) ||
      (estadoFiltro?.isNotEmpty == true) ||
      _filtroVendedor == 'mias';

  Future<void> _selecFecha(BuildContext ctx, bool esDesde) async {
    final p = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: naranja)),
        child: child!,
      ),
    );
    if (p != null) {
      setState(() => esDesde ? fechaDesde = p : fechaHasta = p);
      aplicarFiltros();
    }
  }

  String _fmtCorta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static const _meses = [
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

  String _fmtFecha(String s) {
    final d = DateTime.parse(s);
    return '${d.day} ${_meses[d.month]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtFechaStr(String s) {
    try {
      final d = DateTime.parse(s);
      return '${d.day} ${_meses[d.month]} ${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s.length >= 10 ? s.substring(0, 10) : s;
    }
  }

  void _snack(BuildContext ctx, String msg, bool error) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFC62828) : naranja,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      resizeToAvoidBottomInset: false,
      body: ClipRect(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              SizeTransition(
                sizeFactor: _filterPanelAnim,
                axisAlignment: -1,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _buildPanelFiltros(),
                ),
              ),
              if (hayFiltros) _buildBarraResultados(),
              const SizedBox(height: 8),
              Expanded(child: _buildContenido()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF7D44), Color(0xFFE9713A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: naranja.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historial de ventas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    key: ValueKey('${historialFiltrado.length}-$cargando'),
                    cargando
                        ? 'Cargando…'
                        : hayFiltros
                        ? '${historialFiltrado.length} de ${historial.length} venta(s)'
                        : '${historial.length} venta(s)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          _HeaderBtn(
            activo: mostrarFiltros,
            tieneIndicador: hayFiltros,
            onTap: () {
              setState(() => mostrarFiltros = !mostrarFiltros);
              mostrarFiltros
                  ? _filterPanelCtrl.forward()
                  : _filterPanelCtrl.reverse();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: mostrarFiltros ? naranja : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  'Filtros',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mostrarFiltros ? naranja : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderBtn(
            activo: false,
            onTap: () {
              limpiarFiltros();
              cargarHistorial();
            },
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Ventas a mostrar'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: 'Todas las ventas',
                  icon: Icons.store_rounded,
                  activo: _filtroVendedor == 'todas',
                  onTap: () {
                    setState(() => _filtroVendedor = 'todas');
                    aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleChip(
                  label: 'Mis ventas',
                  icon: Icons.person_rounded,
                  activo: _filtroVendedor == 'mias',
                  onTap: () {
                    setState(() => _filtroVendedor = 'mias');
                    aplicarFiltros();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _SectionLabel('Filtrar fechas por'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: 'Fecha del viaje',
                  icon: Icons.directions_bus_rounded,
                  activo: _tipoFiltroFecha == 'viaje',
                  onTap: () {
                    setState(() => _tipoFiltroFecha = 'viaje');
                    aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToggleChip(
                  label: 'Fecha de venta',
                  icon: Icons.receipt_rounded,
                  activo: _tipoFiltroFecha == 'compra',
                  onTap: () {
                    setState(() => _tipoFiltroFecha = 'compra');
                    aplicarFiltros();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _DateBtn(
                  label: 'Desde',
                  fecha: fechaDesde,
                  onTap: () => _selecFecha(context, true),
                  onClear: fechaDesde != null
                      ? () {
                          setState(() => fechaDesde = null);
                          aplicarFiltros();
                        }
                      : null,
                  fmt: _fmtCorta,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBtn(
                  label: 'Hasta',
                  fecha: fechaHasta,
                  onTap: () => _selecFecha(context, false),
                  onClear: fechaHasta != null
                      ? () {
                          setState(() => fechaHasta = null);
                          aplicarFiltros();
                        }
                      : null,
                  fmt: _fmtCorta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _FilterField(
            controller: _origenCtrl,
            hint: 'Ciudad de origen',
            icon: Icons.trip_origin_rounded,
            iconColor: naranja,
            value: origenFiltro,
            onChanged: (v) {
              setState(() => origenFiltro = v);
              aplicarFiltros();
            },
            onClear: () {
              _origenCtrl.clear();
              setState(() => origenFiltro = null);
              aplicarFiltros();
            },
          ),
          const SizedBox(height: 8),
          _FilterField(
            controller: _destinoCtrl,
            hint: 'Ciudad de destino',
            icon: Icons.location_on_rounded,
            iconColor: azul,
            value: destinoFiltro,
            onChanged: (v) {
              setState(() => destinoFiltro = v);
              aplicarFiltros();
            },
            onClear: () {
              _destinoCtrl.clear();
              setState(() => destinoFiltro = null);
              aplicarFiltros();
            },
          ),
          const SizedBox(height: 12),

          _SectionLabel('Estado del viaje'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChipEstado(null, 'Cualquiera'),
              _buildChipEstado('Disponible', 'Disponible'),
              _buildChipEstado('Finalizado', 'Finalizado'),
            ],
          ),

          // "Limpiar filtros" removido del panel — usar "Limpiar todo" en la barra de resultados
        ],
      ),
    );
  }

  Widget _buildChipEstado(String? valor, String label) {
    final sel = estadoFiltro == valor;
    final info = valor != null ? _estados[valor] : null;
    final color = info?.color ?? naranja;
    final icon = info?.icon ?? Icons.list_rounded;

    return GestureDetector(
      onTap: () {
        setState(() => estadoFiltro = valor);
        aplicarFiltros();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? color : fondo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? color : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: sel ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraResultados() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: naranja.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${historialFiltrado.length} resultado(s)',
              style: const TextStyle(
                fontSize: 12,
                color: naranja,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: azul.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _filtroVendedor == 'mias'
                      ? Icons.person_rounded
                      : Icons.store_rounded,
                  size: 12,
                  color: azul,
                ),
                const SizedBox(width: 4),
                Text(
                  _filtroVendedor == 'mias' ? 'Mis ventas' : 'Todas',
                  style: const TextStyle(
                    fontSize: 12,
                    color: azul,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: limpiarFiltros,
            child: const Text(
              'Limpiar todo',
              style: TextStyle(
                fontSize: 12,
                color: naranja,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (cargando) return _buildShimmer();

    if (historial.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        titulo: 'Sin ventas registradas',
        subtitulo: 'Las ventas realizadas aparecerán aquí',
      );
    }

    if (historialFiltrado.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        titulo: 'Sin resultados',
        subtitulo: 'Intenta cambiar los filtros aplicados',
        showClear: true,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: historialFiltrado.length,
      itemBuilder: (_, i) {
        if (i >= _cardFadeAnims.length) {
          return _buildTarjeta(historialFiltrado[i], i);
        }
        return FadeTransition(
          opacity: _cardFadeAnims[i],
          child: SlideTransition(
            position: _cardSlideAnims[i],
            child: _buildTarjeta(historialFiltrado[i], i),
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 4,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    bool showClear = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.grey.shade300, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              style: const TextStyle(fontSize: 13, color: muted),
              textAlign: TextAlign.center,
            ),
            if (showClear) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: limpiarFiltros,
                style: ElevatedButton.styleFrom(
                  backgroundColor: naranja,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Limpiar filtros',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTarjeta(Map venta, int index) {
    final esTarjeta = venta['metodo_pago'].toString().toLowerCase().contains(
      'tarjeta',
    );
    final estado = venta['estado']?.toString() ?? '';
    final info = _estados[estado];
    final colorE = info?.color ?? Colors.grey.shade500;
    final bgE = info?.bg ?? Colors.grey.shade100;
    final iconE = info?.icon ?? Icons.help_outline_rounded;
    final enRuta = info?.pulsa == true;
    final monto =
        double.tryParse(venta['monto'].toString())?.toStringAsFixed(2) ??
        '0.00';
    final folio = venta['folio'] as int;
    final esPropia =
        venta['vendedor_id']?.toString() == widget.vendedorId.toString();

    return _TarjetaVenta(
      key: ValueKey(folio),
      enRuta: enRuta,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FolioChip(folio: '#$folio'),
                const SizedBox(width: 8),
                if (estado.isNotEmpty)
                  _EstadoChip(
                    label: estado,
                    color: colorE,
                    bg: bgE,
                    icon: iconE,
                    pulsa: enRuta,
                  ),
                const Spacer(),
                if (esPropia)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: azul.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_rounded, size: 10, color: azul),
                        SizedBox(width: 3),
                        Text(
                          'Yo',
                          style: TextStyle(
                            fontSize: 10,
                            color: azul,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  _fmtFecha(venta['fecha']),
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _RutaRow(origen: venta['origen'], destino: venta['destino']),

            const SizedBox(height: 10),

            _DateRow(
              icon: Icons.receipt_outlined,
              label: 'Venta',
              value: venta['fecha'].toString().substring(0, 10),
            ),
            const SizedBox(height: 4),
            _DateRow(
              icon: Icons.directions_bus_outlined,
              label: 'Viaje',
              value: _fmtFechaStr(venta['hora_salida'].toString()),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.shade100, height: 1),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                _MiniChip(
                  icon: Icons.people_outline_rounded,
                  label: '${venta['num_pasajeros']} pax',
                ),
                const SizedBox(width: 8),
                _MiniChip(
                  icon: esTarjeta
                      ? Icons.credit_card_rounded
                      : Icons.payments_outlined,
                  label: venta['metodo_pago'],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$$monto',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: azul,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'MXN',
                      style: TextStyle(
                        fontSize: 10,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            _ReimprimirBtn(
              cargando: _reimprimiendoFolios.contains(folio),
              onTap: () => _reimprimir(context, folio),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════

class _EstadoMeta {
  final Color color;
  final Color bg;
  final IconData icon;
  final bool pulsa;
  const _EstadoMeta({
    required this.color,
    required this.bg,
    required this.icon,
    this.pulsa = false,
  });
}

class _TarjetaVenta extends StatefulWidget {
  final Widget child;
  final bool enRuta;
  const _TarjetaVenta({super.key, required this.child, this.enRuta = false});

  @override
  State<_TarjetaVenta> createState() => _TarjetaVentaState();
}

class _TarjetaVentaState extends State<_TarjetaVenta>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: widget.enRuta
                ? Border.all(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _FolioChip extends StatelessWidget {
  final String folio;
  const _FolioChip({required this.folio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9713A).withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Folio $folio',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE9713A),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatefulWidget {
  final String label;
  final Color color, bg;
  final IconData icon;
  final bool pulsa;

  const _EstadoChip({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
    this.pulsa = false,
  });

  @override
  State<_EstadoChip> createState() => _EstadoChipState();
}

class _EstadoChipState extends State<_EstadoChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.pulsa) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) =>
          Opacity(opacity: widget.pulsa ? _anim.value : 1.0, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: widget.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 12, color: widget.color),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RutaRow extends StatelessWidget {
  final String origen, destino;
  const _RutaRow({required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.radio_button_checked_rounded,
          color: Color(0xFFE9713A),
          size: 15,
        ),
        const SizedBox(width: 6),
        Text(
          origen,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2D3A),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: List.generate(
              5,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 4,
                  height: 1.5,
                  color: Colors.grey.shade300,
                ),
              ),
            ),
          ),
        ),
        const Icon(
          Icons.location_on_rounded,
          color: Color(0xFF2C7FB1),
          size: 15,
        ),
        const SizedBox(width: 4),
        Text(
          destino,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2D3A),
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF8FA8BE)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8FA8BE),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF1C2D3A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF8FA8BE)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1C2D3A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReimprimirBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool cargando;
  const _ReimprimirBtn({required this.onTap, this.cargando = false});

  @override
  State<_ReimprimirBtn> createState() => _ReimprimirBtnState();
}

class _ReimprimirBtnState extends State<_ReimprimirBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.cargando ? null : (_) => _ctrl.forward(),
      onTapUp: widget.cargando
          ? null
          : (_) {
              _ctrl.reverse();
              widget.onTap();
            },
      onTapCancel: widget.cargando ? null : () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.cargando
                  ? [const Color(0xFFBBBBBB), const Color(0xFFAAAAAA)]
                  : [const Color(0xFFEF7D44), const Color(0xFFE9713A)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (widget.cargando ? Colors.grey : const Color(0xFFE9713A))
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.cargando) ...[
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Generando PDF…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reimprimir boleto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final bool activo;
  final bool tieneIndicador;
  final VoidCallback onTap;
  final Widget child;

  const _HeaderBtn({
    required this.activo,
    required this.onTap,
    required this.child,
    this.tieneIndicador = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (tieneIndicador)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C7FB1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFFE9713A) : const Color(0xFFF0F3F8),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: activo ? const Color(0xFFE9713A) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: activo ? Colors.white : const Color(0xFF8FA8BE),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : const Color(0xFF8FA8BE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String Function(DateTime) fmt;
  const _DateBtn({
    required this.label,
    required this.fecha,
    required this.onTap,
    this.onClear,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3F8),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: fecha != null ? const Color(0xFFE9713A) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: fecha != null
                  ? const Color(0xFFE9713A)
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                fecha != null ? fmt(fecha!) : label,
                style: TextStyle(
                  fontSize: 12,
                  color: fecha != null
                      ? const Color(0xFF1C2D3A)
                      : Colors.grey.shade400,
                  fontWeight: fecha != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 13, color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final String? value;
  final void Function(String) onChanged;
  final VoidCallback onClear;
  const _FilterField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        suffixIcon: (value?.isNotEmpty == true)
            ? IconButton(
                icon: const Icon(Icons.close, size: 15),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF0F3F8),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: onChanged,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8FA8BE),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _shimmerBox(80, 22, radius: 20),
                  const SizedBox(width: 8),
                  _shimmerBox(70, 22, radius: 20),
                  const Spacer(),
                  _shimmerBox(90, 14, radius: 6),
                ],
              ),
              const SizedBox(height: 14),
              _shimmerBox(200, 18, radius: 6),
              const SizedBox(height: 10),
              _shimmerBox(140, 13, radius: 6),
              const SizedBox(height: 6),
              _shimmerBox(160, 13, radius: 6),
              const SizedBox(height: 14),
              _shimmerBox(double.infinity, 42, radius: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double w, double h, {double radius = 4}) {
    return Container(
      width: w == double.infinity ? double.infinity : w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
    );
  }
}
