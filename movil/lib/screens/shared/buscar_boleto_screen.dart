import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import '../../config.dart';

class BuscarBoletoScreen extends StatefulWidget {
  final String tipoUsuario;

  const BuscarBoletoScreen({super.key, this.tipoUsuario = 'taquillero'});

  @override
  State<BuscarBoletoScreen> createState() => _BuscarBoletoScreenState();
}

class _BuscarBoletoScreenState extends State<BuscarBoletoScreen> {
  static const azul    = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo   = Color(0xFFF4F6F9);
  static const textoPrincipal  = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  Color get colorPrimario  => widget.tipoUsuario == 'taquillero' ? naranja : azul;
  Color get colorSecundario => widget.tipoUsuario == 'taquillero' ? azul : naranja;

  final _folioCtrl = TextEditingController();
  Map<String, dynamic>? boleto;
  bool cargando     = false;
  bool imprimiendo  = false;
  String? error;

  @override
  void dispose() {
    _folioCtrl.dispose();
    super.dispose();
  }

  // ── Buscar boleto ──────────────────────────────────────────────
  Future<void> _buscar() async {
    final folio = _folioCtrl.text.trim();
    if (folio.isEmpty) return;
    setState(() { cargando = true; error = null; boleto = null; });
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/boleto/$folio/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() { boleto = jsonDecode(response.body); cargando = false; });
      } else {
        final data = jsonDecode(response.body);
        setState(() { error = data['error'] ?? 'Folio no encontrado'; cargando = false; });
      }
    } catch (e) {
      setState(() { error = 'Error de conexión'; cargando = false; });
    }
  }

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

  // ── Generar boarding pass PDF (un pass por pasajero) ──────────
  Future<Uint8List> _generarPdf() async {
    final viaje    = boleto!['viaje'] as Map<String, dynamic>;
    final tickets  = boleto!['tickets'] as List;
    final folio    = boleto!['folio'] as int;
    final monto    = double.parse(boleto!['monto'].toString()).toStringAsFixed(2);
    final metodoPago = boleto!['metodo_pago'].toString();
    final vendedor   = boleto!['vendedor']?.toString() ?? 'App';
    final horaSalida  = _formatHora(viaje['hora_salida']);
    final horaLlegada = _formatHora(viaje['hora_llegada']);
    final fechaViaje  = _formatFecha(viaje['hora_salida']);
    final duracion    = viaje['duracion']?.toString() ?? '';

    final doc = pw.Document();

    final colorPrimario = widget.tipoUsuario == 'taquillero'
        ? PdfColor.fromHex('E9713A') : PdfColor.fromHex('2C7FB1');
    final colorSecundario = widget.tipoUsuario == 'taquillero'
        ? PdfColor.fromHex('2C7FB1') : PdfColor.fromHex('E9713A');
    final pdfOscuro    = PdfColor.fromHex('1C2D3A');
    final pdfGris      = PdfColor.fromHex('6B8FA8');
    final pdfBlanco    = PdfColors.white;
    final pdfGrisClaro = PdfColor.fromHex('E8ECF0');

    for (final ticket in tickets) {
      final nombrePasajero = ticket['pasajero']?.toString() ?? '';
      final asiento        = ticket['asiento']?.toString() ?? '-';
      final tipoAsiento    = ticket['tipo_asiento']?.toString() ?? '';
      final tipoPasajero   = ticket['tipo_pasajero']?.toString() ?? 'Adulto';
      final precio = double.tryParse(ticket['precio']?.toString() ?? '0')
              ?.toStringAsFixed(2) ?? '0.00';

      final qrData = jsonEncode({
        'folio':    folio,
        'pasajero': nombrePasajero,
        'asiento':  asiento,
        'origen':   viaje['origen'],
        'destino':  viaje['destino'],
        'fecha':    fechaViaje,
        'salida':   horaSalida,
        'llegada':  horaLlegada,
      });
      final qrBytes = await _generarQrBytes(qrData);
      final qrImage = pw.MemoryImage(qrBytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 60),
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
                            pw.Text('RUTAS BAJA EXPRESS',
                                style: pw.TextStyle(color: pdfBlanco,
                                    fontSize: 16, fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 1.5)),
                            pw.SizedBox(height: 2),
                            pw.Text('BOARDING PASS',
                                style: pw.TextStyle(color: pdfBlanco,
                                    fontSize: 9, letterSpacing: 2)),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('FOLIO', style: pw.TextStyle(
                                color: PdfColor.fromHex('FFFFFF99'),
                                fontSize: 9, letterSpacing: 1)),
                            pw.Text('#$folio', style: pw.TextStyle(
                                color: pdfBlanco, fontSize: 18,
                                fontWeight: pw.FontWeight.bold)),
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
                              pw.Text('DE', style: pw.TextStyle(color: pdfGris,
                                  fontSize: 9, letterSpacing: 2)),
                              pw.SizedBox(height: 2),
                              pw.Text(viaje['origen'].toString().toUpperCase(),
                                  style: pw.TextStyle(color: pdfOscuro,
                                      fontSize: 28, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text(horaSalida, style: pw.TextStyle(
                                  color: colorPrimario, fontSize: 20,
                                  fontWeight: pw.FontWeight.bold)),
                              pw.Text('SALIDA', style: pw.TextStyle(
                                  color: pdfGris, fontSize: 8, letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                        pw.Column(
                          children: [
                            pw.Text('→', style: pw.TextStyle(
                                color: pdfGris, fontSize: 28)),
                            pw.Text(duracion, style: pw.TextStyle(
                                color: pdfGris, fontSize: 9)),
                          ],
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('HACIA', style: pw.TextStyle(color: pdfGris,
                                  fontSize: 9, letterSpacing: 2)),
                              pw.SizedBox(height: 2),
                              pw.Text(viaje['destino'].toString().toUpperCase(),
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(color: pdfOscuro,
                                      fontSize: 28, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text(horaLlegada, style: pw.TextStyle(
                                  color: colorSecundario, fontSize: 20,
                                  fontWeight: pw.FontWeight.bold)),
                              pw.Text('LLEGADA', style: pw.TextStyle(
                                  color: pdfGris, fontSize: 8, letterSpacing: 1.5)),
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
                                pw.Text('NOMBRE PASAJERO',
                                    style: pw.TextStyle(color: pdfGris,
                                        fontSize: 8, letterSpacing: 1.5)),
                                pw.SizedBox(height: 4),
                                pw.Text(nombrePasajero, style: pw.TextStyle(
                                    color: pdfOscuro, fontSize: 14,
                                    fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 2),
                                pw.Text(tipoPasajero, style: pw.TextStyle(
                                    color: pdfGris, fontSize: 9)),
                              ],
                            ),
                          ),
                          pw.Container(width: 1, height: 46, color: pdfGrisClaro),
                          pw.SizedBox(width: 14),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text('ASIENTO', style: pw.TextStyle(
                                  color: pdfGris, fontSize: 8, letterSpacing: 1.5)),
                              pw.SizedBox(height: 4),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: pw.BoxDecoration(
                                  color: colorPrimario,
                                  borderRadius: pw.BorderRadius.circular(8),
                                ),
                                child: pw.Text(asiento, style: pw.TextStyle(
                                    color: pdfBlanco, fontSize: 20,
                                    fontWeight: pw.FontWeight.bold)),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(tipoAsiento, style: pw.TextStyle(
                                  color: pdfGris, fontSize: 8)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  // CHIPS: fecha, pago, precio
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 28),
                    child: pw.Row(
                      children: [
                        _chip('FECHA', fechaViaje, pdfGris, pdfOscuro, pdfGrisClaro),
                        pw.SizedBox(width: 10),
                        _chip('PAGO', metodoPago, pdfGris, pdfOscuro, pdfGrisClaro),
                        pw.SizedBox(width: 10),
                        _chip('PRECIO', '\$$precio MXN', pdfGris,
                            colorSecundario, pdfGrisClaro),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 18),

                  // LÍNEA PUNTEADA
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 0),
                    child: pw.Row(
                      children: [
                        pw.Container(width: 14, height: 14,
                            decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('EEEEEE'),
                                shape: pw.BoxShape.circle)),
                        pw.Expanded(child: pw.Container(
                            height: 1, color: pdfGrisClaro)),
                        pw.Container(width: 14, height: 14,
                            decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('EEEEEE'),
                                shape: pw.BoxShape.circle)),
                      ],
                    ),
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
                            pw.Text('EMITIDO POR', style: pw.TextStyle(
                                color: pdfGris, fontSize: 8, letterSpacing: 1.5)),
                            pw.SizedBox(height: 3),
                            pw.Text(vendedor, style: pw.TextStyle(
                                color: pdfOscuro, fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 12),
                            pw.Text('Preséntate 30 min antes de la salida.',
                                style: pw.TextStyle(color: pdfGris, fontSize: 8)),
                            pw.SizedBox(height: 4),
                            pw.Text('www.rutasbaja.mx', style: pw.TextStyle(
                                color: colorPrimario, fontSize: 8,
                                fontWeight: pw.FontWeight.bold)),
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
                            pw.Text('Escanea para verificar',
                                style: pw.TextStyle(color: pdfGris, fontSize: 7)),
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

  static pw.Widget _chip(String label, String value,
      PdfColor labelColor, PdfColor valueColor, PdfColor bgColor) {
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
            pw.Text(label, style: pw.TextStyle(
                color: labelColor, fontSize: 7, letterSpacing: 1)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(
                color: valueColor, fontSize: 9,
                fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _imprimirBoleto() async {
    setState(() => imprimiendo = true);
    try {
      final pdfBytes = await _generarPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Boleto_Folio_${boleto!['folio']}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => imprimiendo = false);
    }
  }

  // ── Formatters ────────────────────────────────────────────────
  String _formatFecha(String fecha) {
    final dt = DateTime.parse(fecha);
    const meses = ['','Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  String _formatHora(String fecha) {
    final dt = DateTime.parse(fecha);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.tipoUsuario == 'invitado') return _buildInvitado();
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBuscador(),
            ),
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
        color: colorPrimario,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buscar boleto',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.bold, letterSpacing: 0.3)),
            SizedBox(height: 2),
            Text('Ingresa el folio de compra',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ]),
    );
  }

  Widget _buildBuscador() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _folioCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Número de folio',
              hintStyle: TextStyle(color: textoSecundario),
              prefixIcon: Icon(Icons.confirmation_number_outlined,
                  color: colorPrimario, size: 20),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorPrimario, width: 1.5)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onSubmitted: (_) => _buscar(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: cargando ? null : _buscar,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorPrimario,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 2,
              shadowColor: colorPrimario.withOpacity(0.3),
            ),
            child: cargando
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search_rounded, size: 22),
          ),
        ),
      ]),
    );
  }

  Widget _buildContenido() {
    if (error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search_off_rounded, color: Colors.grey.shade300, size: 60),
          const SizedBox(height: 16),
          Text(error!, style: const TextStyle(color: textoPrincipal,
              fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Verifica el número de folio',
              style: TextStyle(color: textoSecundario, fontSize: 13)),
        ]),
      );
    }
    if (boleto == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.confirmation_number_outlined,
              color: Colors.grey.shade300, size: 60),
          const SizedBox(height: 16),
          Text('Ingresa un folio para buscar',
              style: TextStyle(color: textoSecundario, fontSize: 14)),
        ]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildTarjeta(),
    );
  }

  Widget _buildTarjeta() {
    final viaje   = boleto!['viaje'] as Map<String, dynamic>;
    final tickets = boleto!['tickets'] as List;
    final esTarjeta = boleto!['metodo_pago'].toString().toLowerCase()
        .contains('tarjeta');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Folio + fecha
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorPrimario.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Folio #${boleto!['folio']}',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: colorPrimario)),
              ),
              const Spacer(),
              Text(_formatFecha(boleto!['fecha_pago']),
                  style: TextStyle(fontSize: 12, color: textoSecundario)),
            ]),

            const SizedBox(height: 16),

            // Horario
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_formatHora(viaje['hora_salida']),
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold, color: textoPrincipal)),
                Text(viaje['origen'],
                    style: TextStyle(fontSize: 12, color: textoSecundario)),
              ]),
              Expanded(
                child: Column(children: [
                  Row(children: [
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1.5,
                        color: Colors.grey.shade200)),
                    Icon(Icons.directions_bus_rounded,
                        color: colorPrimario, size: 20),
                    Expanded(child: Container(height: 1.5,
                        color: Colors.grey.shade200)),
                    const SizedBox(width: 8),
                  ]),
                  Text(viaje['duracion'],
                      style: TextStyle(fontSize: 11, color: textoSecundario)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_formatHora(viaje['hora_llegada']),
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold, color: textoPrincipal)),
                Text(viaje['destino'],
                    style: TextStyle(fontSize: 12, color: textoSecundario)),
              ]),
            ]),

            const SizedBox(height: 4),
            Text(_formatFecha(viaje['hora_salida']),
                style: TextStyle(fontSize: 11, color: textoSecundario)),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),

            // Pasajeros header
            Row(children: [
              Container(width: 4, height: 16,
                  decoration: BoxDecoration(color: colorPrimario,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              const Text('Boletos', style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13, color: textoPrincipal)),
              const Spacer(),
              Text('${tickets.length} pasajero(s)',
                  style: TextStyle(fontSize: 12, color: textoSecundario)),
            ]),

            const SizedBox(height: 10),

            // Lista pasajeros
            ...tickets.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: colorPrimario.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${t['asiento']}',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: colorPrimario, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t['pasajero'], style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13,
                        color: textoPrincipal)),
                    Text('${t['tipo_pasajero']} · ${t['tipo_asiento']}',
                        style: TextStyle(fontSize: 11, color: textoSecundario)),
                  ]),
                ),
                Text('\$${double.parse(t['precio'].toString()).toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 13, color: colorSecundario)),
              ]),
            )),

            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),

            // Monto y método
            Row(children: [
              Icon(esTarjeta
                  ? Icons.credit_card_rounded : Icons.payments_rounded,
                  size: 16, color: textoSecundario),
              const SizedBox(width: 6),
              Text(boleto!['metodo_pago'],
                  style: TextStyle(fontSize: 13, color: textoSecundario)),
              const Spacer(),
              const Text('Total: ', style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 14, color: textoPrincipal)),
              Text('\$${double.parse(boleto!['monto'].toString()).toStringAsFixed(2)} MXN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: colorSecundario)),
            ]),

            const SizedBox(height: 16),

            // ── BOTÓN IMPRIMIR ──────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: imprimiendo ? null : _imprimirBoleto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimario,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  shadowColor: colorPrimario.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: imprimiendo
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: Text(
                  imprimiendo ? 'Generando PDF...' : 'Imprimir / Guardar PDF',
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pantalla invitado ─────────────────────────────────────────
  Widget _buildInvitado() {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(color: azul,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 2))]),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.confirmation_number_outlined,
                    color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              const Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mis boletos', style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Modo invitado',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
            ]),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: azul.withOpacity(0.08), shape: BoxShape.circle),
                      child: const Icon(Icons.badge_outlined, color: azul, size: 56)),
                    const SizedBox(height: 24),
                    const Text('Crea una cuenta para ver tus boletos',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold, color: textoPrincipal)),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
