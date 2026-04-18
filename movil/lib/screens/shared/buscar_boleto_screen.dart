import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config.dart';
import '../../utils/pdf_boleto.dart';

class BuscarBoletoScreen extends StatefulWidget {
  final String tipoUsuario;

  const BuscarBoletoScreen({super.key, this.tipoUsuario = 'taquillero'});

  @override
  State<BuscarBoletoScreen> createState() => _BuscarBoletoScreenState();
}

class _BuscarBoletoScreenState extends State<BuscarBoletoScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  Color get colorPrimario =>
      widget.tipoUsuario == 'taquillero' ? naranja : azul;
  Color get colorSecundario =>
      widget.tipoUsuario == 'taquillero' ? azul : naranja;

  final _folioCtrl = TextEditingController();
  Map<String, dynamic>? boleto;
  bool cargando = false;
  bool imprimiendo = false;
  String? error;

  @override
  void dispose() {
    _folioCtrl.dispose();
    super.dispose();
  }

  // ── Buscar boleto ──────────────────────────────────────────────
  Future<void> _buscar([String? folioOverride]) async {
    final folio = (folioOverride ?? _folioCtrl.text).trim();
    if (folio.isEmpty) return;
    if (folioOverride != null) {
      _folioCtrl.text = folioOverride;
    }
    setState(() {
      cargando = true;
      error = null;
      boleto = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/boleto/$folio/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          boleto = jsonDecode(response.body);
          cargando = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          error = data['error'] ?? 'Folio no encontrado';
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

  // ── Abrir escáner QR ──────────────────────────────────────────
  Future<void> _abrirEscaner() async {
    final result = await Navigator.push<String>(
      context,
      AppRoutes.zoomFade(const _QrScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      String folio = result;
      try {
        final data = jsonDecode(result);
        if (data is Map && data.containsKey('folio')) {
          folio = data['folio'].toString();
        }
      } catch (_) {}
      await _buscar(folio);
    }
  }

  Future<void> _imprimirBoleto() async {
    setState(() => imprimiendo = true);
    try {
      final viaje = boleto!['viaje'] as Map<String, dynamic>;
      final tickets = boleto!['tickets'] as List;

      // Mapear pasajeros al formato que espera PdfBoleto
      final pasajeros = tickets
          .map<Map<String, dynamic>>(
            (t) => {
              'nombre': t['nombre'] ?? '',
              'primer_apellido': t['primer_apellido'] ?? '',
              'asiento_etiqueta': t['asiento_etiqueta']
                  ?.toString(), // ← ya estaba, verifica que esté
              'tipo': t['tipo_pasajero'] ?? 'Adulto',
              'precio_unitario': double.tryParse(t['precio'].toString()) ?? 0.0,
            },
          )
          .toList();

      final pdfBytes = await PdfBoleto.generar(
        pagoId: boleto!['folio'] as int,
        origenNombre: viaje['origen'].toString(),
        destinoNombre: viaje['destino'].toString(),
        horaSalida: viaje['hora_salida']
            .toString(), // ← directo, sin _formatHora()
        horaLlegada: viaje['hora_llegada'].toString(), // ← directo
        fechaViaje: viaje['fecha_viaje']
            .toString(), // ← directo, sin _formatFecha()
        montoTotal: double.parse(boleto!['monto'].toString()),
        pasajeros: pasajeros,
        metodoPago:
            boleto!['metodo_pago_id']
                as int, // ← el backend también manda metodo_pago_id
      );

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
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => imprimiendo = false);
    }
  }

  // ── Formatters ────────────────────────────────────────────────
  String _formatFecha(String fecha) {
    try {
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
      return '${dt.day} ${meses[dt.month]} ${dt.year}';
    } catch (_) {
      return fecha; // devuelve el string crudo si no puede parsear
    }
  }

  String _formatHora(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      // Si ya viene como "HH:mm", lo devuelve directo
      return fecha;
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.tipoUsuario == 'invitado') return _buildInvitado();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _buildContenido(),
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
              Icons.search_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buscar boleto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ingresa el folio de compra',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _abrirEscaner,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscador() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _folioCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Número de folio',
                hintStyle: TextStyle(color: textoSecundario),
                prefixIcon: Icon(
                  Icons.confirmation_number_outlined,
                  color: colorPrimario,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorPrimario, width: 1.5),
                ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 2,
                shadowColor: colorPrimario.withOpacity(0.3),
              ),
              child: cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search_rounded, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (error != null) {
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
              error!,
              style: const TextStyle(
                color: textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifica el número de folio',
              style: TextStyle(color: textoSecundario, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (boleto == null) {
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
              'Ingresa un folio para buscar',
              style: TextStyle(color: textoSecundario, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _buildTarjeta(),
    );
  }

  Widget _buildTarjeta() {
    final viaje = boleto!['viaje'] as Map<String, dynamic>;
    final tickets = boleto!['tickets'] as List;
    final esTarjeta = boleto!['metodo_pago'].toString().toLowerCase().contains(
      'tarjeta',
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folio + fecha
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorPrimario.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Folio #${boleto!['folio']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorPrimario,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatFecha(boleto!['fecha_pago']),
                  style: TextStyle(fontSize: 12, color: textoSecundario),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Horario
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatHora(viaje['hora_salida'].toString()),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textoPrincipal,
                      ),
                    ),
                    Text(
                      viaje['origen'],
                      style: TextStyle(fontSize: 12, color: textoSecundario),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: Colors.grey.shade200,
                            ),
                          ),
                          Icon(
                            Icons.directions_bus_rounded,
                            color: colorPrimario,
                            size: 20,
                          ),
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: Colors.grey.shade200,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      Text(
                        viaje['duracion'],
                        style: TextStyle(fontSize: 11, color: textoSecundario),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatHora(viaje['hora_llegada']),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textoPrincipal,
                      ),
                    ),
                    Text(
                      viaje['destino'],
                      style: TextStyle(fontSize: 12, color: textoSecundario),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 4),
            Text(
              _formatFecha(viaje['fecha_viaje'].toString()),
              style: TextStyle(fontSize: 11, color: textoSecundario),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),

            // Pasajeros header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorPrimario,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Boletos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textoPrincipal,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tickets.length} pasajero(s)',
                  style: TextStyle(fontSize: 12, color: textoSecundario),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Lista pasajeros
            ...tickets.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorPrimario.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${t['asiento_etiqueta'] ?? t['asiento']}', // ← antes solo era t['asiento']
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorPrimario,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['pasajero'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: textoPrincipal,
                            ),
                          ),
                          Text(
                            '${t['tipo_pasajero']} · ${t['tipo_asiento']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${double.parse(t['precio'].toString()).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: colorSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),

            // Monto y método
            Row(
              children: [
                Icon(
                  esTarjeta
                      ? Icons.credit_card_rounded
                      : Icons.payments_rounded,
                  size: 16,
                  color: textoSecundario,
                ),
                const SizedBox(width: 6),
                Text(
                  boleto!['metodo_pago'],
                  style: TextStyle(fontSize: 13, color: textoSecundario),
                ),
                const Spacer(),
                const Text(
                  'Total: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textoPrincipal,
                  ),
                ),
                Text(
                  '\$${double.parse(boleto!['monto'].toString()).toStringAsFixed(2)} MXN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorSecundario,
                  ),
                ),
              ],
            ),

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
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                  shadowColor: colorPrimario.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                icon: imprimiendo
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
                  imprimiendo ? 'Generando PDF...' : 'Imprimir / Guardar PDF',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
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
        child: Column(
          children: [
            Container(
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
                      Icons.confirmation_number_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis boletos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Modo invitado',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: azul.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          color: azul,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Crea una cuenta para ver tus boletos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pantalla de escáner QR ────────────────────────────────────────
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);

  final MobileScannerController _ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value != null && value.isNotEmpty) {
      _scanned = true;
      Navigator.pop(context, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Cámara
            MobileScanner(controller: _ctrl, onDetect: _onDetect),

            // Overlay con marco
            CustomPaint(
              painter: _ScannerOverlayPainter(),
              child: const SizedBox.expand(),
            ),

            // Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Escanear boleto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Linterna
                    GestureDetector(
                      onTap: () => _ctrl.toggleTorch(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.flashlight_on_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Instrucción inferior
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Apunta al QR del boleto impreso',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay del escáner ───────────────────────────────────────────
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const scanSize = 250.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: scanSize,
      height: scanSize,
    );

    // Fondo oscuro con hueco
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      bgPaint,
    );

    // Marco de esquinas
    final cornerPaint = Paint()
      ..color = const Color(0xFFE9713A)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cLen = 28.0;
    final corners = [
      // Top-left
      [
        rect.topLeft + const Offset(0, cLen),
        rect.topLeft,
        rect.topLeft + const Offset(cLen, 0),
      ],
      // Top-right
      [
        rect.topRight + const Offset(-cLen, 0),
        rect.topRight,
        rect.topRight + const Offset(0, cLen),
      ],
      // Bottom-left
      [
        rect.bottomLeft + const Offset(0, -cLen),
        rect.bottomLeft,
        rect.bottomLeft + const Offset(cLen, 0),
      ],
      // Bottom-right
      [
        rect.bottomRight + const Offset(-cLen, 0),
        rect.bottomRight,
        rect.bottomRight + const Offset(0, -cLen),
      ],
    ];

    for (final c in corners) {
      final path = Path()
        ..moveTo((c[0] as Offset).dx, (c[0] as Offset).dy)
        ..lineTo((c[1] as Offset).dx, (c[1] as Offset).dy)
        ..lineTo((c[2] as Offset).dx, (c[2] as Offset).dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
