import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config.dart';

// ─────────────────────────────────────────────────────────
//  HISTORIAL SCREEN  –  RBE v2
//  Diseño: cards glassmórficas con animación stagger,
//  header con degradado sutil y shimmer en carga,
//  chip de estado con pulso animado para "En Ruta".
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

  // Filtros
  DateTime? fechaDesde;
  DateTime? fechaHasta;
  String? origenFiltro;
  String? destinoFiltro;
  String? estadoFiltro;
  String _tipoFiltroFecha = 'viaje';

  final _origenCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();

  // ── Animaciones ───────────────────────────────────────
  late AnimationController _filterPanelCtrl;
  late Animation<double> _filterPanelAnim;

  // Controlador de lista para stagger
  final List<AnimationController> _cardCtrls = [];
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
      icon: Icons.schedule_rounded,
    ),
  };

  // ─────────────────────────────────────────────────────
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
    for (final c in _cardCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Stagger para tarjetas ─────────────────────────────
  void _iniciarAnimacionCards(int count) {
    for (final c in _cardCtrls) {
      c.dispose();
    }
    _cardCtrls.clear();
    _cardFadeAnims.clear();
    _cardSlideAnims.clear();

    for (int i = 0; i < count; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );
      _cardCtrls.add(ctrl);
      _cardFadeAnims.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlideAnims.add(
        Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)),
      );
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
          .get(
            Uri.parse('${Config.baseUrl}/api/historial/${widget.vendedorId}/'),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          historial = data;
          historialFiltrado = List.from(data);
          cargando = false;
        });
        _iniciarAnimacionCards(historialFiltrado.length);
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
      _origenCtrl.clear();
      _destinoCtrl.clear();
      historialFiltrado = List.from(historial);
    });
    _iniciarAnimacionCards(historialFiltrado.length);
  }

  bool get hayFiltros =>
      fechaDesde != null ||
      fechaHasta != null ||
      (origenFiltro?.isNotEmpty == true) ||
      (destinoFiltro?.isNotEmpty == true) ||
      (estadoFiltro?.isNotEmpty == true);

  // ── Fecha helpers ─────────────────────────────────────
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

  // ── PDF (sin cambios funcionales) ─────────────────────
  Future<Uint8List> _generarQrBytes(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: const ui.Color(0xFF1C2D3A),
      emptyColor: const ui.Color(0xFFFFFFFF),
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 300.0;
    qrPainter.paint(canvas, const Size(size, size));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  }

  Future<Uint8List> _generarPdf(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final folio = data['folio'];
    final viaje = data['viaje'] as Map<String, dynamic>;
    final tickets = data['tickets'] as List;
    final origen = viaje['origen'].toString();
    final destino = viaje['destino'].toString();
    final monto =
        double.tryParse(data['monto'].toString())?.toStringAsFixed(2) ?? '0.00';
    final metodo = (data['metodo_pago_id'] ?? 1) == 2 ? 'Tarjeta' : 'Efectivo';

    final hsDt = DateTime.tryParse(viaje['hora_salida'].toString());
    final horaSalida = hsDt != null
        ? '${hsDt.hour.toString().padLeft(2, '0')}:${hsDt.minute.toString().padLeft(2, '0')}'
        : viaje['hora_salida'].toString();
    final fechaViaje = hsDt != null
        ? '${hsDt.day} ${_meses[hsDt.month]} ${hsDt.year}'
        : '';

    final cP = PdfColor.fromHex('E9713A');
    final cS = PdfColor.fromHex('2C7FB1');
    final cD = PdfColor.fromHex('1C2D3A');
    final cG = PdfColor.fromHex('6B8FA8');
    final cW = PdfColors.white;
    final cGL = PdfColor.fromHex('E8ECF0');

    for (final t in tickets) {
      final nombre = '${t['nombre'] ?? ''} ${t['primer_apellido'] ?? ''}'
          .trim();
      final asiento = t['asiento']?.toString() ?? '-';
      final tipo = t['tipo_pasajero']?.toString() ?? 'Adulto';
      final precio =
          double.tryParse(t['precio'].toString())?.toStringAsFixed(2) ?? '0.00';

      final qrBytes = await _generarQrBytes(
        jsonEncode({
          'folio': folio,
          'pasajero': nombre,
          'asiento': asiento,
          'origen': origen,
          'destino': destino,
          'fecha': fechaViaje,
          'salida': horaSalida,
        }),
      );

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 50,
              vertical: 60,
            ),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: cW,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: cGL, width: 1),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 18),
                    decoration: pw.BoxDecoration(
                      color: cP,
                      borderRadius: const pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(16),
                        topRight: pw.Radius.circular(16),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'RUTAS BAJA EXPRESS',
                              style: pw.TextStyle(
                                color: cW,
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'BOARDING PASS',
                              style: pw.TextStyle(
                                color: cW,
                                fontSize: 9,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'FOLIO',
                              style: pw.TextStyle(
                                color: PdfColor.fromHex('FFFFFF99'),
                                fontSize: 9,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.Text(
                              '#$folio',
                              style: pw.TextStyle(
                                color: cW,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(28, 22, 28, 0),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'DE',
                                style: pw.TextStyle(
                                  color: cG,
                                  fontSize: 9,
                                  letterSpacing: 2,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                origen.toUpperCase(),
                                style: pw.TextStyle(
                                  color: cD,
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                horaSalida,
                                style: pw.TextStyle(
                                  color: cP,
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'SALIDA',
                                style: pw.TextStyle(
                                  color: cG,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          '→',
                          style: pw.TextStyle(color: cG, fontSize: 28),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'HACIA',
                                style: pw.TextStyle(
                                  color: cG,
                                  fontSize: 9,
                                  letterSpacing: 2,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                destino.toUpperCase(),
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  color: cD,
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                fechaViaje,
                                style: pw.TextStyle(
                                  color: cS,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'FECHA',
                                style: pw.TextStyle(
                                  color: cG,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(14),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F8F9FA'),
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'NOMBRE PASAJERO',
                                  style: pw.TextStyle(
                                    color: cG,
                                    fontSize: 8,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  nombre,
                                  style: pw.TextStyle(
                                    color: cD,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  tipo,
                                  style: pw.TextStyle(color: cG, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                          pw.Container(width: 1, height: 46, color: cGL),
                          pw.SizedBox(width: 14),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'ASIENTO',
                                style: pw.TextStyle(
                                  color: cG,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: cP,
                                  borderRadius: pw.BorderRadius.circular(8),
                                ),
                                child: pw.Text(
                                  asiento,
                                  style: pw.TextStyle(
                                    color: cW,
                                    fontSize: 20,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
                    child: pw.Row(
                      children: [
                        _chipPdf('PAGO', metodo, cG, cD, cGL),
                        pw.SizedBox(width: 10),
                        _chipPdf('PRECIO', '\$$precio MXN', cG, cS, cGL),
                        pw.SizedBox(width: 10),
                        _chipPdf('TOTAL', '\$$monto MXN', cG, cP, cGL),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 14,
                        height: 14,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('EEEEEE'),
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(child: pw.Container(height: 1, color: cGL)),
                      pw.Container(
                        width: 14,
                        height: 14,
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('EEEEEE'),
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 18),
                  pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(28, 0, 28, 24),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'EMITIDO POR',
                              style: pw.TextStyle(
                                color: cG,
                                fontSize: 8,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Rutas Baja Express',
                              style: pw.TextStyle(
                                color: cD,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            pw.Text(
                              'Preséntate 30 min antes de la salida.',
                              style: pw.TextStyle(color: cG, fontSize: 8),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'www.rutasbaja.mx',
                              style: pw.TextStyle(
                                color: cP,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: pw.BoxDecoration(
                                color: cW,
                                border: pw.Border.all(color: cGL),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Image(
                                pw.MemoryImage(qrBytes),
                                width: 90,
                                height: 90,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Escanea para verificar',
                              style: pw.TextStyle(color: cG, fontSize: 7),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _chipPdf(
    String label,
    String value,
    PdfColor lc,
    PdfColor vc,
    PdfColor bg,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(color: lc, fontSize: 7, letterSpacing: 1),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: vc,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reimprimir(BuildContext ctx, int folio) async {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: naranja),
              const SizedBox(height: 16),
              Text(
                'Generando boleto…',
                style: TextStyle(color: dark.withOpacity(.7), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final res = await http
          .get(Uri.parse('${Config.baseUrl}/api/boleto/$folio/'))
          .timeout(const Duration(seconds: 10));

      if (!ctx.mounted) return;
      Navigator.pop(ctx);

      if (res.statusCode != 200) {
        _snack(ctx, 'No se pudo cargar el boleto', true);
        return;
      }

      final pdfBytes = await _generarPdf(jsonDecode(res.body));
      if (!ctx.mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Boleto_Folio_$folio.pdf',
      );
    } catch (e) {
      if (ctx.mounted) {
        Navigator.pop(ctx);
        _snack(ctx, 'Error: $e', true);
      }
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Panel de filtros con animación
            SizeTransition(
              sizeFactor: _filterPanelAnim,
              axisAlignment: -1,
              child: _buildPanelFiltros(),
            ),
            if (hayFiltros) _buildBarraResultados(),
            const SizedBox(height: 8),
            Expanded(child: _buildContenido()),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────
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
          // Icono con fondo semi-transparente
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
          // Botón filtros
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
          // Botón refrescar
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

  // ── Panel Filtros ─────────────────────────────────────
  Widget _buildPanelFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipo fecha toggle
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
          // Rango de fechas
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
          // Origen / Destino
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
              _buildChipEstado(null, 'Todos'),
              ..._estados.keys.map((e) => _buildChipEstado(e, e)),
            ],
          ),
          if (hayFiltros) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: limpiarFiltros,
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Limpiar filtros'),
                style: TextButton.styleFrom(foregroundColor: muted),
              ),
            ),
          ],
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

  // ── Contenido principal ────────────────────────────────
  Widget _buildContenido() {
    if (cargando) return _buildShimmer();

    if (historial.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        titulo: 'Sin ventas registradas',
        subtitulo: 'Las ventas que realices aparecerán aquí',
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
        if (i >= _cardFadeAnims.length)
          return _buildTarjeta(historialFiltrado[i], i);
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

  // ── Shimmer de carga ──────────────────────────────────
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

  // ── Tarjeta de venta ───────────────────────────────────
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

    return _TarjetaVenta(
      key: ValueKey(venta['folio']),
      enRuta: enRuta,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fila 1: folio + estado + fecha ────────────
            Row(
              children: [
                _FolioChip(folio: '#${venta['folio']}'),
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
                Text(
                  _fmtFecha(venta['fecha']),
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Ruta ──────────────────────────────────────
            _RutaRow(origen: venta['origen'], destino: venta['destino']),

            const SizedBox(height: 10),

            // ── Fechas ────────────────────────────────────
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

            // ── Divider decorativo ─────────────────────────
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

            // ── Pasajeros + Pago + Monto ──────────────────
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

            // ── Botón reimprimir ──────────────────────────
            _ReimprimirBtn(onTap: () => _reimprimir(context, venta['folio'])),
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

// ── Tarjeta con efecto press ──────────────────────────────
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
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 4,
                spreadRadius: 0,
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

// ── Folio chip ────────────────────────────────────────────
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

// ── Estado chip con pulso opcional ───────────────────────
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

// ── Ruta row ──────────────────────────────────────────────
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

// ── Fecha row ─────────────────────────────────────────────
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

// ── Mini chip ─────────────────────────────────────────────
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

// ── Botón reimprimir ──────────────────────────────────────
class _ReimprimirBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _ReimprimirBtn({required this.onTap});

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
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF7D44), Color(0xFFE9713A)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE9713A).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 17),
              SizedBox(width: 8),
              Text(
                'Reimprimir boleto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header button ─────────────────────────────────────────
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

// ── Toggle chip ───────────────────────────────────────────
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

// ── Date button ───────────────────────────────────────────
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

// ── Filter field ──────────────────────────────────────────
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

// ── Section label ─────────────────────────────────────────
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

// ── Shimmer card ──────────────────────────────────────────
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
