import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../taquillero/home_screen.dart';
import '../cliente/home_screen.dart';
import '../invitado/home_screen.dart';
import '../../main.dart';

class ResumenCompraScreen extends StatefulWidget {
  final int pagoId;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final double montoTotal;
  final List<Map<String, dynamic>> pasajeros;
  final int metodoPago;
  final String tipoUsuario;
  final Map<String, dynamic>? datosUsuario;

  const ResumenCompraScreen({
    super.key,
    required this.pagoId,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    required this.montoTotal,
    required this.pasajeros,
    required this.metodoPago,
    this.tipoUsuario = 'taquillero',
    this.datosUsuario,
  });

  @override
  State<ResumenCompraScreen> createState() => _ResumenCompraScreenState();
}

class _ResumenCompraScreenState extends State<ResumenCompraScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  static const Map<String, int> _descuentos = {
    'Adulto': 0,
    'Estudiante': 25,
    'INAPAM': 30,
    'Discapacidad': 15,
  };

  bool _imprimiendo = false;

  // ── Generar QR como imagen PNG ─────────────────────────────────

  // ── Generar QR como imagen PNG ─────────────────────────────────
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

  Future<Uint8List> _generarPdf() async {
    final doc = pw.Document();
    final folio = widget.pagoId;
    final origen = widget.origenNombre;
    final destino = widget.destinoNombre;
    final salida = widget.horaSalida;
    final monto = widget.montoTotal.toStringAsFixed(2);
    final metodo = widget.metodoPago == 2 ? 'Tarjeta' : 'Efectivo';
    final fecha = _hoyStr();

    final colorPrimario = widget.tipoUsuario == 'taquillero'
        ? PdfColor.fromHex('E9713A')
        : PdfColor.fromHex('2C7FB1');
    final colorSecundario = widget.tipoUsuario == 'taquillero'
        ? PdfColor.fromHex('2C7FB1')
        : PdfColor.fromHex('E9713A');
    final pdfOscuro = PdfColor.fromHex('1C2D3A');
    final pdfGris = PdfColor.fromHex('6B8FA8');
    final pdfBlanco = PdfColors.white;
    final pdfGrisClaro = PdfColor.fromHex('E8ECF0');

    for (final p in widget.pasajeros) {
      final nombre = '${p['nombre'] ?? ''} ${p['primer_apellido'] ?? ''}'
          .trim();
      final asiento = p['asiento_id']?.toString() ?? '-';
      final tipo = p['tipo']?.toString() ?? 'Adulto';
      final precio =
          (p['precio_unitario'] as double?)?.toStringAsFixed(2) ?? '0.00';

      final qrData = jsonEncode({
        'folio': folio,
        'pasajero': nombre,
        'asiento': asiento,
        'origen': origen,
        'destino': destino,
        'fecha': fecha,
        'salida': salida,
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
                                salida,
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
                                fecha,
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
                        _chip('PAGO', metodo, pdfGris, pdfOscuro, pdfGrisClaro),
                        pw.SizedBox(width: 10),
                        _chip(
                          'PRECIO',
                          '\$$precio MXN',
                          pdfGris,
                          colorSecundario,
                          pdfGrisClaro,
                        ),
                        pw.SizedBox(width: 10),
                        _chip(
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

                  // LÍNEA PUNTEADA
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

  static pw.Widget _chip(
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

  Future<void> _imprimirBoleto() async {
    setState(() => _imprimiendo = true);
    try {
      final pdfBytes = await _generarPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Boleto_Folio_${widget.pagoId}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  String _hoyStr() {
    final now = DateTime.now();
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
    return '${now.day} ${meses[now.month]} ${now.year}';
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildExito(),
                    const SizedBox(height: 16),
                    _buildResumenViaje(),
                    const SizedBox(height: 16),
                    _buildListaPasajeros(),
                    const SizedBox(height: 16),
                    _buildResumenPago(),
                    const SizedBox(height: 24),
                    _buildBotones(context),
                    const SizedBox(height: 20),
                  ],
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
              Icons.confirmation_number_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compra confirmada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tu boleto ha sido generado',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExito() {
    // Obtener correo del contacto si existe
    final contacto = widget.pasajeros.firstWhere(
      (p) => p['esContacto'] == true,
      orElse: () => {},
    );
    final correo = contacto['correo']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '¡Pago exitoso!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Folio de compra #${widget.pagoId}',
            style: TextStyle(fontSize: 13, color: textoSecundario),
          ),
          if (correo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: azul.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mark_email_read_rounded, color: azul, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Boleto enviado a $correo',
                      style: TextStyle(
                        fontSize: 12,
                        color: azul,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenViaje() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'Detalles del viaje',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: azul,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 30, color: Colors.grey.shade300),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: naranja,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.origenNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.destinoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                widget.horaSalida,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: azul,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaPasajeros() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                '${widget.pasajeros.length} boleto(s)',
                style: TextStyle(fontSize: 12, color: textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.pasajeros.asMap().entries.map((entry) {
            final index = entry.key;
            final p = entry.value;
            final esContacto = p['esContacto'] as bool? ?? false;
            final tipo = p['tipo'] as String? ?? 'Adulto';
            final descuento =
                p['descuento'] as int? ?? (_descuentos[tipo] ?? 0);
            final precioUnitario = p['precio_unitario'] as double?;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: azul.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: azul,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${p['nombre']} ${p['primer_apellido']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textoPrincipal,
                              ),
                            ),
                            if (esContacto) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: naranja.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Contacto',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: naranja,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$tipo · Asiento ${p['asiento_id']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (precioUnitario != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (descuento > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-$descuento%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${precioUnitario.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: naranja,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResumenPago() {
    double subtotalSinDescuento = 0;
    double totalConDescuento = 0;

    for (final p in widget.pasajeros) {
      final precioUnitario = p['precio_unitario'] as double?;
      final descuento = p['descuento'] as int? ?? 0;
      if (precioUnitario != null) {
        totalConDescuento += precioUnitario;
        if (descuento > 0) {
          subtotalSinDescuento += precioUnitario / (1 - descuento / 100);
        } else {
          subtotalSinDescuento += precioUnitario;
        }
      }
    }

    final ahorro = subtotalSinDescuento - totalConDescuento;
    final hayDescuentos = ahorro > 0;

    return Container(
      padding: const EdgeInsets.all(16),
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
                  color: naranja,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Resumen de pago',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                widget.metodoPago == 2
                    ? Icons.credit_card_rounded
                    : Icons.payments_rounded,
                color: azul,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.metodoPago == 2
                    ? 'Tarjeta de crédito/débito'
                    : 'Efectivo en taquilla',
                style: const TextStyle(fontSize: 13, color: textoPrincipal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 10),

          if (hayDescuentos) ...[
            Row(
              children: [
                Text(
                  'Subtotal:',
                  style: TextStyle(fontSize: 13, color: textoSecundario),
                ),
                const Spacer(),
                Text(
                  '\$${subtotalSinDescuento.toStringAsFixed(2)} MXN',
                  style: TextStyle(
                    fontSize: 13,
                    color: textoSecundario,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Descuentos aplicados:',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade600),
                ),
                const Spacer(),
                Text(
                  '- \$${ahorro.toStringAsFixed(2)} MXN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 10),
          ],

          Row(
            children: [
              const Text(
                'Total pagado:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
              const Spacer(),
              Text(
                '\$${widget.montoTotal.toStringAsFixed(2)} MXN',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: naranja,
                ),
              ),
            ],
          ),

          if (hayDescuentos) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.savings_rounded,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '¡Ahorraste \$${ahorro.toStringAsFixed(2)} MXN con descuentos!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotones(BuildContext context) {
    return Column(
      children: [
        // ── BOTÓN IMPRIMIR / PDF ────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _imprimiendo ? null : _imprimirBoleto,
            style: ElevatedButton.styleFrom(
              backgroundColor: azul,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: azul.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            icon: _imprimiendo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 22),
            label: Text(
              _imprimiendo ? 'Generando PDF...' : 'Imprimir / Guardar PDF',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── BOTÓN VOLVER AL INICIO ──────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) {
                    if (widget.tipoUsuario == 'taquillero' &&
                        widget.datosUsuario != null) {
                      return HomeNavigationScreen(
                        taquillero: widget.datosUsuario!,
                      );
                    } else if (widget.tipoUsuario == 'cliente' &&
                        widget.datosUsuario != null) {
                      return HomeClienteScreen(cliente: widget.datosUsuario!);
                    } else {
                      return const HomeInvitadoScreen();
                    }
                  },
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: naranja,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: naranja.withOpacity(0.4),
            ),
            icon: const Icon(Icons.home_rounded),
            label: const Text(
              'Volver al inicio',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
