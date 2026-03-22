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

class HistorialScreen extends StatefulWidget {
  final int vendedorId;

  const HistorialScreen({super.key, required this.vendedorId});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  static const naranja = Color(0xFFE9713A);
  static const azul = Color(0xFF2C7FB1);
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
  String? estadoFiltro;
  String _tipoFiltroFecha = 'viaje';
  bool mostrarFiltros = false;

  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

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
        final campoFecha = _tipoFiltroFecha == 'viaje'
            ? item['hora_salida']
            : item['fecha'];

        if (fechaDesde != null) {
          final fechaItem = DateTime.tryParse(campoFecha.toString());
          if (fechaItem == null || fechaItem.isBefore(fechaDesde!))
            return false;
        }
        if (fechaHasta != null) {
          final fechaItem = DateTime.tryParse(campoFecha.toString());
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
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: naranja)),
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
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
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
    return '${dt.day} ${meses[dt.month]} ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFechaStr(String fechaStr) {
    try {
      final dt = DateTime.parse(fechaStr);
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
      return '${dt.day} ${meses[dt.month]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fechaStr.toString().substring(0, 10);
    }
  }

  // ── PDF ────────────────────────────────────────────────────────

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
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _generarPdfDesdeHistorial(Map<String, dynamic> data) async {
    final doc = pw.Document();
    final folio = data['folio'];
    final viaje = data['viaje'] as Map<String, dynamic>;
    final tickets = data['tickets'] as List;
    final origen = viaje['origen'].toString();
    final destino = viaje['destino'].toString();
    final monto =
        double.tryParse(data['monto'].toString())?.toStringAsFixed(2) ?? '0.00';
    final metodo = (data['metodo_pago_id'] ?? 1) == 2 ? 'Tarjeta' : 'Efectivo';

    final horaSalidaDt = DateTime.tryParse(viaje['hora_salida'].toString());
    final horaSalida = horaSalidaDt != null
        ? '${horaSalidaDt.hour.toString().padLeft(2, '0')}:'
              '${horaSalidaDt.minute.toString().padLeft(2, '0')}'
        : viaje['hora_salida'].toString();

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
    final fechaViaje = horaSalidaDt != null
        ? '${horaSalidaDt.day} ${meses[horaSalidaDt.month]} ${horaSalidaDt.year}'
        : '';

    // Taquillero usa naranja como primario
    final colorPrimario = PdfColor.fromHex('E9713A');
    final colorSecundario = PdfColor.fromHex('2C7FB1');
    final pdfOscuro = PdfColor.fromHex('1C2D3A');
    final pdfGris = PdfColor.fromHex('6B8FA8');
    final pdfBlanco = PdfColors.white;
    final pdfGrisClaro = PdfColor.fromHex('E8ECF0');

    for (final t in tickets) {
      final nombre = '${t['nombre'] ?? ''} ${t['primer_apellido'] ?? ''}'
          .trim();
      final asiento = t['asiento']?.toString() ?? '-';
      final tipo = t['tipo_pasajero']?.toString() ?? 'Adulto';
      final precio =
          double.tryParse(t['precio'].toString())?.toStringAsFixed(2) ?? '0.00';

      final qrData = jsonEncode({
        'folio': folio,
        'pasajero': nombre,
        'asiento': asiento,
        'origen': origen,
        'destino': destino,
        'fecha': fechaViaje,
        'salida': horaSalida,
      });
      final qrBytes = await _generarQrBytes(qrData);
      final qrImage = pw.MemoryImage(qrBytes);

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
                color: pdfBlanco,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: pdfGrisClaro, width: 1),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // HEADER
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.fromLTRB(28, 18, 28, 18),
                    decoration: pw.BoxDecoration(
                      color: colorPrimario,
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
                                color: pdfBlanco,
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'BOARDING PASS',
                              style: pw.TextStyle(
                                color: pdfBlanco,
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
                                color: pdfBlanco,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // RUTA
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
                                  color: pdfGris,
                                  fontSize: 9,
                                  letterSpacing: 2,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                origen.toUpperCase(),
                                style: pw.TextStyle(
                                  color: pdfOscuro,
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                horaSalida,
                                style: pw.TextStyle(
                                  color: colorPrimario,
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'SALIDA',
                                style: pw.TextStyle(
                                  color: pdfGris,
                                  fontSize: 8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Text(
                          '→',
                          style: pw.TextStyle(color: pdfGris, fontSize: 28),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'HACIA',
                                style: pw.TextStyle(
                                  color: pdfGris,
                                  fontSize: 9,
                                  letterSpacing: 2,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                destino.toUpperCase(),
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                  color: pdfOscuro,
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                fechaViaje,
                                style: pw.TextStyle(
                                  color: colorSecundario,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'FECHA',
                                style: pw.TextStyle(
                                  color: pdfGris,
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

                  // PASAJERO + ASIENTO
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
                                    color: pdfGris,
                                    fontSize: 8,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  nombre,
                                  style: pw.TextStyle(
                                    color: pdfOscuro,
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  tipo,
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.Container(
                            width: 1,
                            height: 46,
                            color: pdfGrisClaro,
                          ),
                          pw.SizedBox(width: 14),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'ASIENTO',
                                style: pw.TextStyle(
                                  color: pdfGris,
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
                                  color: colorPrimario,
                                  borderRadius: pw.BorderRadius.circular(8),
                                ),
                                child: pw.Text(
                                  asiento,
                                  style: pw.TextStyle(
                                    color: pdfBlanco,
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

                  // CHIPS
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
                    child: pw.Row(
                      children: [
                        _chipPdf(
                          'PAGO',
                          metodo,
                          pdfGris,
                          pdfOscuro,
                          pdfGrisClaro,
                        ),
                        pw.SizedBox(width: 10),
                        _chipPdf(
                          'PRECIO',
                          '\$$precio MXN',
                          pdfGris,
                          colorSecundario,
                          pdfGrisClaro,
                        ),
                        pw.SizedBox(width: 10),
                        _chipPdf(
                          'TOTAL',
                          '\$$monto MXN',
                          pdfGris,
                          colorPrimario,
                          pdfGrisClaro,
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 18),

                  // LÍNEA
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
                      pw.Expanded(
                        child: pw.Container(height: 1, color: pdfGrisClaro),
                      ),
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

                  // QR + INFO
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
                                color: pdfGris,
                                fontSize: 8,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Rutas Baja Express',
                              style: pw.TextStyle(
                                color: pdfOscuro,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            pw.Text(
                              'Preséntate 30 min antes de la salida.',
                              style: pw.TextStyle(color: pdfGris, fontSize: 8),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'www.rutasbaja.mx',
                              style: pw.TextStyle(
                                color: colorPrimario,
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
                                color: pdfBlanco,
                                border: pw.Border.all(color: pdfGrisClaro),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Image(qrImage, width: 90, height: 90),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Escanea para verificar',
                              style: pw.TextStyle(color: pdfGris, fontSize: 7),
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
    PdfColor labelColor,
    PdfColor valueColor,
    PdfColor bgColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                color: labelColor,
                fontSize: 7,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: valueColor,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reimprimir(BuildContext context, int folio) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/boleto/$folio/'))
          .timeout(const Duration(seconds: 10));

      if (!context.mounted) return;
      Navigator.pop(context);

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo cargar el boleto'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final data = jsonDecode(response.body);
      final pdfBytes = await _generarPdfDesdeHistorial(data);

      if (!context.mounted) return;

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Boleto_Folio_$folio.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────

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
        color: naranja,
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
                    color: mostrarFiltros ? naranja : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      color: mostrarFiltros ? naranja : Colors.white,
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
                        color: azul,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
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
          // Selector tipo fecha
          const Text(
            'Filtrar fechas por',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _tipoFiltroFecha = 'viaje');
                    aplicarFiltros();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _tipoFiltroFecha == 'viaje' ? naranja : fondo,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _tipoFiltroFecha == 'viaje'
                            ? naranja
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          size: 14,
                          color: _tipoFiltroFecha == 'viaje'
                              ? Colors.white
                              : textoSecundario,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Fecha del viaje',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _tipoFiltroFecha == 'viaje'
                                ? Colors.white
                                : textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _tipoFiltroFecha = 'compra');
                    aplicarFiltros();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _tipoFiltroFecha == 'compra' ? naranja : fondo,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _tipoFiltroFecha == 'compra'
                            ? naranja
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_rounded,
                          size: 14,
                          color: _tipoFiltroFecha == 'compra'
                              ? Colors.white
                              : textoSecundario,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Fecha de venta',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _tipoFiltroFecha == 'compra'
                                ? Colors.white
                                : textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          TextField(
            controller: _origenController,
            decoration: InputDecoration(
              hintText: 'Ciudad de origen',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.trip_origin_rounded,
                color: naranja,
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
          TextField(
            controller: _destinoController,
            decoration: InputDecoration(
              hintText: 'Ciudad de destino',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: azul,
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
              ..._estados.keys.map((e) => _buildChipEstado(e, e)),
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
    final color = info != null ? info['color'] as Color : naranja;
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
            color: fecha != null ? naranja : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: fecha != null ? naranja : Colors.grey,
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
    if (cargando) {
      return const Center(child: CircularProgressIndicator(color: naranja));
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
                style: TextStyle(color: naranja),
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
    final estado = venta['estado']?.toString() ?? '';
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
                    color: naranja.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Folio #${venta['folio']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: naranja,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (estado.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bgEstado,
                      borderRadius: BorderRadius.circular(20),
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
                  _formatFecha(venta['fecha']),
                  style: TextStyle(fontSize: 11, color: textoSecundario),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.trip_origin_rounded, color: naranja, size: 14),
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
                const Icon(Icons.location_on_rounded, color: azul, size: 14),
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
            const SizedBox(height: 8),
            // Fecha de venta
            Row(
              children: [
                Icon(
                  Icons.receipt_rounded,
                  color: Colors.grey.shade400,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  'Venta: ${venta['fecha'].toString().substring(0, 10)}',
                  style: TextStyle(fontSize: 12, color: textoSecundario),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Fecha del viaje
            Row(
              children: [
                Icon(
                  Icons.directions_bus_rounded,
                  color: Colors.grey.shade400,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  'Viaje: ${_formatFechaStr(venta['hora_salida'].toString())}',
                  style: TextStyle(fontSize: 12, color: textoSecundario),
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
                    color: azul,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _reimprimir(context, venta['folio']),
                style: OutlinedButton.styleFrom(
                  foregroundColor: naranja,
                  side: const BorderSide(color: naranja, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text(
                  'Reimprimir boleto',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
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
