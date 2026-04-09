import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

class PdfBoleto {
  static Future<Uint8List> generarQrBytes(String data) async {
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

  static String descAsiento(String tipo) {
    switch (tipo) {
      case 'Estudiante':
        return 'Estudiante 25% desc.';
      case 'INAPAM':
        return 'INAPAM 30% desc.';
      case 'Discapacidad':
        return 'Discapacidad 15% desc.';
      default:
        return 'Adulto';
    }
  }

  static String abreviatura(String ciudad) {
    final words = ciudad.trim().split(' ');
    if (words.length == 1) {
      return ciudad.substring(0, ciudad.length.clamp(0, 3)).toUpperCase();
    }
    final siglas = words
        .where((w) => w.length > 2)
        .take(3)
        .map((w) => w[0].toUpperCase())
        .join();
    return siglas.isEmpty ? ciudad.substring(0, 3).toUpperCase() : siglas;
  }

  static String hoyStr() {
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

  static pw.Widget infoBlock(
    String label,
    String value,
    PdfColor labelColor,
    PdfColor valueColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: labelColor,
            fontSize: 6,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: valueColor,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static Future<Uint8List> generar({
    required int pagoId,
    required String origenNombre,
    required String destinoNombre,
    required String horaSalida,
    required String horaLlegada,
    required String fechaViaje,
    required double montoTotal,
    required List<Map<String, dynamic>> pasajeros,
    required int metodoPago,
  }) async {
    final doc = pw.Document();
    final folio = pagoId;
    final origen = origenNombre;
    final destino = destinoNombre;
    final salida = horaSalida;
    final llegada = horaLlegada.isNotEmpty ? horaLlegada : '--:--';
    final fViaje = fechaViaje.isNotEmpty ? fechaViaje : hoyStr();
    final metodo = metodoPago == 2 ? 'Tarjeta' : 'Efectivo';

    final pdfAzul = PdfColor.fromHex('2C7FB1');
    final pdfNaranja = PdfColor.fromHex('E9713A');
    final pdfOscuro = PdfColor.fromHex('1C2D3A');
    final pdfGris = PdfColor.fromHex('6B8FA8');
    final pdfBlanco = PdfColors.white;
    final pdfFondo = PdfColor.fromHex('F4F6F9');
    final pdfGrisClaro = PdfColor.fromHex('E2E8F0');
    final pdfAzulClaro = PdfColor.fromHex('EBF4FB');
    final pdfNaranjaClaro = PdfColor.fromHex('FDF0EA');

    final double pageW = PdfPageFormat.a4.width;
    final double pageH = PdfPageFormat.a4.height;

    const double ticketW = 230.0;
    const double ticketH = 480.0;
    const double headerH = 52.0;
    const double talonH = 120.0;
    const double pieH = 20.0;
    const double talonY = ticketH - talonH - pieH;
    const double pad = 12.0;

    final double ticketX = (pageW - ticketW) / 2;
    final double ticketY = (pageH - ticketH) / 2;

    for (final p in pasajeros) {
      final nombre = '${p['nombre'] ?? ''} ${p['primer_apellido'] ?? ''}'
          .trim();
      final asiento =
          (p['asiento_etiqueta'] ?? p['asiento_id'])?.toString() ?? '-';
      final tipo = p['tipo']?.toString() ?? 'Adulto';
      final precio =
          (p['precio_unitario'] as double?)?.toStringAsFixed(2) ?? '0.00';
      final tipoDesc = descAsiento(tipo);

      final qrData = jsonEncode({
        'folio': folio,
        'pasajero': nombre,
        'asiento': asiento,
        'origen': origen,
        'destino': destino,
        'fecha': fViaje,
        'salida': salida,
        'llegada': llegada,
      });
      final qrBytes = await generarQrBytes(qrData);
      final qrImage = pw.MemoryImage(qrBytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              // FONDO PÁGINA
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Container(
                  width: pageW,
                  height: pageH,
                  color: PdfColor.fromHex('E8ECF0'),
                ),
              ),

              // SOMBRA

              // FONDO BLANCO BOLETO
              pw.Positioned(
                left: ticketX,
                top: ticketY,
                child: pw.Container(
                  width: ticketW,
                  height: ticketH,
                  decoration: pw.BoxDecoration(
                    color: pdfBlanco,
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                ),
              ),

              // HEADER AZUL
              pw.Positioned(
                left: ticketX,
                top: ticketY,
                child: pw.Container(
                  width: ticketW,
                  height: headerH,
                  decoration: pw.BoxDecoration(
                    color: pdfAzul,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(12),
                      topRight: pw.Radius.circular(12),
                    ),
                  ),
                  padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'RUTAS BAJA',
                            style: pw.TextStyle(
                              color: pdfBlanco,
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.Text(
                            'EXPRESS',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('FFFFFFCC'),
                              fontSize: 7,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'BOARDING PASS',
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('FFFFFFAA'),
                              fontSize: 6,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '#$folio',
                            style: pw.TextStyle(
                              color: pdfBlanco,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // CUERPO BLANCO
              pw.Positioned(
                left: ticketX,
                top: ticketY + headerH,
                child: pw.Container(
                  width: ticketW,
                  height: talonY - headerH,
                  // Sin color para no tapar las muescas
                  padding: const pw.EdgeInsets.fromLTRB(pad, 10, pad, 0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // RUTA
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 8,
                        ),
                        decoration: pw.BoxDecoration(
                          color: pdfFondo,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'ORIGEN',
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  abreviatura(origen),
                                  style: pw.TextStyle(
                                    color: pdfAzul,
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  origen,
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(width: 16),
                            pw.Text(
                              '--->',
                              style: pw.TextStyle(
                                color: pdfNaranja,
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(width: 16),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'DESTINO',
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  abreviatura(destino),
                                  style: pw.TextStyle(
                                    color: pdfOscuro,
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  destino,
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 8),

                      // VIAJE + PAGO
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: infoBlock(
                              'NUMERO DE VIAJE',
                              '#$folio',
                              pdfGris,
                              pdfAzul,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: infoBlock(
                              'METODO DE PAGO',
                              metodo,
                              pdfGris,
                              pdfOscuro,
                            ),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 7),
                      pw.Container(
                        height: 0.5,
                        color: pdfGrisClaro,
                        width: double.infinity,
                      ),
                      pw.SizedBox(height: 7),

                      // SALIDA / LLEGADA
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(7),
                              decoration: pw.BoxDecoration(
                                color: pdfAzulClaro,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'SALIDA',
                                    style: pw.TextStyle(
                                      color: pdfGris,
                                      fontSize: 6,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    fViaje,
                                    style: pw.TextStyle(
                                      color: pdfOscuro,
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    salida,
                                    style: pw.TextStyle(
                                      color: pdfAzul,
                                      fontSize: 13,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(7),
                              decoration: pw.BoxDecoration(
                                color: pdfNaranjaClaro,
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'LLEGADA',
                                    style: pw.TextStyle(
                                      color: pdfGris,
                                      fontSize: 6,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  pw.SizedBox(height: 3),
                                  pw.Text(
                                    fViaje,
                                    style: pw.TextStyle(
                                      color: pdfOscuro,
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    llegada,
                                    style: pw.TextStyle(
                                      color: pdfNaranja,
                                      fontSize: 13,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 7),
                      pw.Container(
                        height: 0.5,
                        color: pdfGrisClaro,
                        width: double.infinity,
                      ),
                      pw.SizedBox(height: 7),

                      // PASAJERO
                      pw.Text(
                        'PASAJERO',
                        style: pw.TextStyle(
                          color: pdfGris,
                          fontSize: 6,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        nombre,
                        style: pw.TextStyle(
                          color: pdfOscuro,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),

                      // FIX 1: Solo texto en azul, sin fondo ni badge
                      pw.Text(
                        tipoDesc.toUpperCase(),
                        style: pw.TextStyle(
                          color: pdfAzul,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),

                      pw.SizedBox(height: 8),
                      pw.Container(
                        height: 0.5,
                        color: pdfGrisClaro,
                        width: double.infinity,
                      ),
                      pw.SizedBox(height: 8),

                      // ASIENTO · TIPO · PRECIO
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'No. ASIENTO',
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  asiento,
                                  style: pw.TextStyle(
                                    color: pdfAzul,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'TIPO',
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  tipo,
                                  style: pw.TextStyle(
                                    color: pdfOscuro,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'PRECIO',
                                  style: pw.TextStyle(
                                    color: pdfGris,
                                    fontSize: 6,
                                    letterSpacing: 1,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  '\$$precio',
                                  style: pw.TextStyle(
                                    color: pdfNaranja,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // TALÓN BLANCO CON QR
              pw.Positioned(
                left: ticketX,
                top: ticketY + talonY,
                child: pw.Container(
                  width: ticketW,
                  height: talonH,
                  color: pdfBlanco,
                  padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          color: pdfBlanco,
                          border: pw.Border.all(color: pdfNaranja, width: 2),
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Image(qrImage, width: 75, height: 75),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Escanea para validar el boleto',
                        style: pw.TextStyle(color: pdfGris, fontSize: 7),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        decoration: pw.BoxDecoration(
                          color: pdfNaranja,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          'FOLIO #$folio',
                          style: pw.TextStyle(
                            color: pdfBlanco,
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // PIE AZUL
              pw.Positioned(
                left: ticketX,
                top: ticketY + talonY + talonH,
                child: pw.Container(
                  width: ticketW,
                  height: pieH,
                  decoration: pw.BoxDecoration(
                    color: pdfAzul,
                    borderRadius: const pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(12),
                      bottomRight: pw.Radius.circular(12),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'RUTAS BAJA EXPRESS  .  BUS TICKET',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('FFFFFFBB'),
                        fontSize: 6,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              // FIX 2: MUESCAS al final del Stack para que queden encima de todo
              pw.Positioned(
                left: ticketX - 8,
                top: ticketY + talonY - 8,
                child: pw.Container(
                  width: 16,
                  height: 16,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('E8ECF0'),
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
              pw.Positioned(
                left: ticketX + ticketW - 8,
                top: ticketY + talonY - 8,
                child: pw.Container(
                  width: 16,
                  height: 16,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('E8ECF0'),
                    shape: pw.BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }
}
