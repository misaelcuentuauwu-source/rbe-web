import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'pago_screen.dart';

class SeatSelectionScreen extends StatefulWidget {
  final int viajeId;
  final List<Map<String, dynamic>> pasajeros;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final String horaLlegada;
  final String fechaViaje;
  final double precioPorPasajero;
  final int vendedorId;
  final String tipoUsuario;
  final Map<String, dynamic>? datosUsuario;

  const SeatSelectionScreen({
    super.key,
    required this.viajeId,
    required this.pasajeros,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    this.horaLlegada = '',
    this.fechaViaje = '',
    required this.precioPorPasajero,
    required this.vendedorId,
    this.tipoUsuario = 'invitado',
    this.datosUsuario,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen>
    with TickerProviderStateMixin {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const morado = Color(0xFF7B2FBE);
  static const grisOc = Color(0xFFB0B8C1);
  static const fondoApp = Color(0xFFF0F4F8);

  List<dynamic> asientos = [];
  List<int> seleccionados = [];
  bool cargando = true;

  late AnimationController _entradaCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOutBack));
    cargarAsientos();
  }

  @override
  void dispose() {
    _entradaCtrl.dispose();
    super.dispose();
  }

  Future<void> cargarAsientos() async {
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/viajes/${widget.viajeId}/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = List<dynamic>.from(data['asientos']);
        setState(() {
          asientos = lista;
          cargando = false;
        });
        _entradaCtrl.forward();
      } else {
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Error cargando asientos: $e');
      setState(() => cargando = false);
    }
  }

  Color _colorAsiento(Map asiento) {
    final num = asiento['asiento']['numero'];
    final ocupado = asiento['ocupado'] == 1;
    final tipo = asiento['asiento']['tipo']['codigo'];
    if (seleccionados.contains(num)) return naranja;
    if (ocupado) return grisOc;
    if (tipo == 'DIS') return morado;
    return azul;
  }

  bool _isOcupado(Map asiento) => asiento['ocupado'] == 1;

  void _toggleAsiento(Map asiento) {
    if (_isOcupado(asiento)) return;
    final num = asiento['asiento']['numero'];
    final total = widget.pasajeros.length;
    setState(() {
      if (seleccionados.contains(num)) {
        seleccionados.remove(num);
      } else {
        if (seleccionados.length < total) {
          seleccionados.add(num);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Solo puedes seleccionar $total asiento(s)'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    });
  }

  String _etiquetaDeAsiento(int numeroAsiento) {
    const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final disAsientos = asientos
        .where((a) => a['asiento']['tipo']['codigo'] == 'DIS')
        .toList();
    final normAsientos = asientos
        .where((a) => a['asiento']['tipo']['codigo'] != 'DIS')
        .toList();
    for (int i = 0; i < disAsientos.length; i++) {
      if (disAsientos[i]['asiento']['numero'] == numeroAsiento)
        return 'D${i + 1}';
    }
    for (int i = 0; i < normAsientos.length; i++) {
      if (normAsientos[i]['asiento']['numero'] == numeroAsiento) {
        final filaIndex = i ~/ 4;
        final colIndex = i % 4;
        return '${letras[filaIndex % letras.length]}${colIndex + 1}';
      }
    }
    return '$numeroAsiento';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoApp,
      appBar: _buildAppBar(),
      body: cargando ? _buildLoader() : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: azul,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        children: [
          const Text(
            'Seleccionar asiento',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            '${widget.origenNombre} → ${widget.destinoNombre}  ·  ${widget.horaSalida}',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoader() =>
      const Center(child: CircularProgressIndicator(color: azul));

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        return isLandscape
            ? _buildLandscape(constraints)
            : _buildPortrait(constraints);
      },
    );
  }

  Widget _buildPortrait(BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(child: _buildScrollArea(constraints, isLandscape: false)),
        _buildLeyendaBar(),
        _buildBotonConfirmar(),
      ],
    );
  }

  Widget _buildLandscape(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(child: _buildScrollArea(constraints, isLandscape: true)),
        Container(
          width: 160,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeyendaVertical(),
              const Spacer(),
              _buildBotonConfirmar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScrollArea(
    BoxConstraints constraints, {
    required bool isLandscape,
  }) {
    return LayoutBuilder(
      builder: (ctx, inner) {
        return SingleChildScrollView(
          scrollDirection: isLandscape ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: isLandscape ? _buildBusH(inner) : _buildBusV(inner),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUS VERTICAL (portrait)
  // ═══════════════════════════════════════════════════════
  Widget _buildBusV(BoxConstraints constraints) {
    final busW = constraints.maxWidth.clamp(260.0, 400.0);

    final disA = asientos
        .where((a) => a['asiento']['tipo']['codigo'] == 'DIS')
        .toList();
    final normA = asientos
        .where((a) => a['asiento']['tipo']['codigo'] != 'DIS')
        .toList();

    final sW = ((busW * 0.70) / (4 + 3 * 0.16 + 0.55)).clamp(34.0, 56.0);
    final sH = sW * 1.15;
    final gap = sW * 0.16;
    final pasillo = sW * 0.55;
    final cabH = sH * 2.4;

    final totalSeatsW = sW * 4 + gap * 3 + pasillo;
    final hPad = (busW - totalSeatsW) / 2;

    final numFilas = (normA.length / 4).ceil();
    final busH = cabH + (sH + gap) + numFilas * (sH + gap) + sH * 0.5;

    return CustomPaint(
      painter: _BusPainterV(busW: busW, busH: busH, cabH: cabH),
      child: SizedBox(
        width: busW,
        height: busH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabina con conductor y volante
            // Cabina con conductor y volante
            // Cabina tipo autobús real (chofer izquierda + entrada derecha)
            SizedBox(
              height: cabH,
              width: busW,
              child: Stack(
                children: [
                  // Asiento del conductor (más a la izquierda)
                  Positioned(
                    left: busW * 0.06,
                    bottom: cabH * 0.10,
                    child: CustomPaint(
                      painter: _SeatPainter(
                        color: const Color(0xFF8B96A0),
                        selected: false,
                        ocupado: true,
                      ),
                      child: SizedBox(width: sW * 0.85, height: sW * 0.95),
                    ),
                  ),

                  // Volante
                  Positioned(
                    left: busW * 0.16,
                    bottom: cabH * 0.18,
                    child: CustomPaint(
                      painter: _VolantePainter(),
                      child: SizedBox(width: sW * 0.55, height: sW * 0.55),
                    ),
                  ),

                  // Pared divisoria entre cabina y pasajeros
                  Positioned(
                    right: busW * 0.22,
                    bottom: 0,
                    top: cabH * 0.35,
                    child: Container(width: 3, color: const Color(0xFF8B96A0)),
                  ),

                  // Espacio de entrada (puerta/escaleras)
                  Positioned(
                    right: busW * 0.05,
                    bottom: cabH * 0.05,
                    child: Container(
                      width: sW * 1.0,
                      height: sH * 1.4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),

                  // Barandal de entrada
                  Positioned(
                    right: busW * 0.18,
                    bottom: cabH * 0.05,
                    child: Container(
                      width: 3,
                      height: sH * 1.4,
                      color: const Color(0xFF8B96A0),
                    ),
                  ),
                ],
              ),
            ),

            // Fila DIS
            Padding(
              padding: EdgeInsets.only(left: hPad, right: hPad, bottom: gap),
              child: _buildFilaDIS(disA, sW, sH, gap, pasillo),
            ),

            // Filas normales
            ...List.generate(numFilas, (fi) {
              const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
              final start = fi * 4;
              final end = min(start + 4, normA.length);
              final fila = normA.sublist(start, end);
              while (fila.length < 4) fila.add(null);
              return Padding(
                padding: EdgeInsets.only(left: hPad, right: hPad, bottom: gap),
                child: _buildFilaNormal(
                  fila,
                  letras[fi % 26],
                  sW,
                  sH,
                  gap,
                  pasillo,
                ),
              );
            }),

            SizedBox(height: sH * 0.35),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUS HORIZONTAL (landscape)
  // ═══════════════════════════════════════════════════════
  Widget _buildBusH(BoxConstraints constraints) {
    final busH = constraints.maxHeight.clamp(200.0, 320.0);

    final disA = asientos
        .where((a) => a['asiento']['tipo']['codigo'] == 'DIS')
        .toList();
    final normA = asientos
        .where((a) => a['asiento']['tipo']['codigo'] != 'DIS')
        .toList();

    final sH = ((busH * 0.70) / (4 + 3 * 0.16 + 0.55)).clamp(30.0, 50.0);
    final sW = sH * 1.05;
    final gap = sH * 0.16;
    final pasillo = sH * 0.55;
    final cabW = sW * 2.4;

    final totalSeatsH = sH * 4 + gap * 3 + pasillo;
    final vPad = (busH - totalSeatsH) / 2;

    final numFilas = (normA.length / 4).ceil();
    final busW = cabW + (sW + gap) + numFilas * (sW + gap) + sW * 0.5;

    return CustomPaint(
      painter: _BusPainterH(busW: busW, busH: busH, cabW: cabW),
      child: SizedBox(
        width: busW,
        height: busH,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabina
            SizedBox(
              width: cabW,
              height: busH,
              child: Stack(
                children: [
                  Positioned(
                    bottom: busH * 0.12,
                    left: cabW * 0.10,
                    child: CustomPaint(
                      painter: _SeatPainter(
                        color: const Color(0xFF8B96A0),
                        selected: false,
                        ocupado: true,
                      ),
                      child: SizedBox(width: sH * 0.88, height: sH * 0.98),
                    ),
                  ),
                  Positioned(
                    bottom: busH * 0.18,
                    left: cabW * 0.40,
                    child: CustomPaint(
                      painter: _VolantePainter(),
                      child: SizedBox(width: sH * 0.52, height: sH * 0.52),
                    ),
                  ),
                ],
              ),
            ),

            // Columna DIS
            Padding(
              padding: EdgeInsets.only(top: vPad, bottom: vPad, right: gap),
              child: _buildColumnaDIS(disA, sW, sH, gap, pasillo),
            ),

            // Columnas normales
            ...List.generate(numFilas, (fi) {
              const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
              final start = fi * 4;
              final end = min(start + 4, normA.length);
              final fila = normA.sublist(start, end);
              while (fila.length < 4) fila.add(null);
              return Padding(
                padding: EdgeInsets.only(top: vPad, bottom: vPad, right: gap),
                child: _buildColumnaNormal(
                  fila,
                  letras[fi % 26],
                  sW,
                  sH,
                  gap,
                  pasillo,
                ),
              );
            }),

            SizedBox(width: sW * 0.3),
          ],
        ),
      ),
    );
  }

  // ─── Filas y columnas ──────────────────────────────────────────────────────
  Widget _buildFilaDIS(
    List dis,
    double sW,
    double sH,
    double gap,
    double pasillo,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dis.isNotEmpty
            ? _seat(dis[0], sW, sH, 'D1')
            : SizedBox(width: sW, height: sH),
        SizedBox(width: gap),
        SizedBox(width: sW, height: sH),
        SizedBox(width: pasillo),
        SizedBox(width: sW, height: sH),
        SizedBox(width: gap),
        dis.length > 1
            ? _seat(dis[1], sW, sH, 'D2')
            : SizedBox(width: sW, height: sH),
      ],
    );
  }

  Widget _buildFilaNormal(
    List fila,
    String letra,
    double sW,
    double sH,
    double gap,
    double pas,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _seat(fila[0], sW, sH, fila[0] != null ? '${letra}1' : ''),
        SizedBox(width: gap),
        _seat(fila[1], sW, sH, fila[1] != null ? '${letra}2' : ''),
        SizedBox(width: pas),
        _seat(fila[2], sW, sH, fila[2] != null ? '${letra}3' : ''),
        SizedBox(width: gap),
        _seat(fila[3], sW, sH, fila[3] != null ? '${letra}4' : ''),
      ],
    );
  }

  Widget _buildColumnaDIS(
    List dis,
    double sW,
    double sH,
    double gap,
    double pasillo,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dis.isNotEmpty
            ? _seat(dis[0], sW, sH, 'D1')
            : SizedBox(width: sW, height: sH),
        SizedBox(height: gap),
        SizedBox(width: sW, height: sH),
        SizedBox(height: pasillo),
        SizedBox(width: sW, height: sH),
        SizedBox(height: gap),
        dis.length > 1
            ? _seat(dis[1], sW, sH, 'D2')
            : SizedBox(width: sW, height: sH),
      ],
    );
  }

  Widget _buildColumnaNormal(
    List fila,
    String letra,
    double sW,
    double sH,
    double gap,
    double pas,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _seat(fila[0], sW, sH, fila[0] != null ? '${letra}1' : ''),
        SizedBox(height: gap),
        _seat(fila[1], sW, sH, fila[1] != null ? '${letra}2' : ''),
        SizedBox(height: pas),
        _seat(fila[2], sW, sH, fila[2] != null ? '${letra}3' : ''),
        SizedBox(height: gap),
        _seat(fila[3], sW, sH, fila[3] != null ? '${letra}4' : ''),
      ],
    );
  }

  Widget _seat(dynamic asiento, double w, double h, String etiqueta) {
    if (asiento == null) return SizedBox(width: w, height: h);
    final color = _colorAsiento(asiento);
    final ocupado = _isOcupado(asiento);
    final numero = asiento['asiento']['numero'];
    final selected = seleccionados.contains(numero);

    return GestureDetector(
      onTap: () => _toggleAsiento(asiento),
      child: SizedBox(
        width: w,
        height: h,
        child: CustomPaint(
          painter: _SeatPainter(
            color: color,
            selected: selected,
            ocupado: ocupado,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: h * 0.20),
              child: Text(
                etiqueta,
                style: TextStyle(
                  color: ocupado ? Colors.white54 : Colors.white,
                  fontSize: min(w, h) * 0.21,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Leyenda ───────────────────────────────────────────────────────────────
  Widget _buildLeyendaBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _chip(azul, 'Disponible'),
          _chip(grisOc, 'Ocupado'),
          _chip(naranja, 'Seleccionado'),
          _chip(morado, 'Discapacidad'),
        ],
      ),
    );
  }

  Widget _buildLeyendaVertical() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leyenda',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 12),
        _chip(azul, 'Disponible'),
        const SizedBox(height: 8),
        _chip(grisOc, 'Ocupado'),
        const SizedBox(height: 8),
        _chip(naranja, 'Seleccionado'),
        const SizedBox(height: 8),
        _chip(morado, 'Discapacidad'),
      ],
    );
  }

  Widget _chip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF555555),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Botón confirmar ───────────────────────────────────────────────────────
  Widget _buildBotonConfirmar() {
    final total = widget.pasajeros.length;
    final listos = seleccionados.length == total;
    String texto;
    if (seleccionados.isEmpty) {
      texto = 'Selecciona $total asiento${total > 1 ? "s" : ""}';
    } else if (listos) {
      texto =
          'Confirmar ${seleccionados.length} asiento${seleccionados.length > 1 ? "s" : ""}';
    } else {
      final faltan = total - seleccionados.length;
      texto = 'Faltan $faltan asiento${faltan > 1 ? "s" : ""}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.white,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: listos ? naranja : grisOc,
          boxShadow: listos
              ? [
                  BoxShadow(
                    color: naranja.withOpacity(0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: listos ? _confirmar : null,
            child: Center(
              child: Text(
                texto,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: listos ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmar() {
    const descuentos = {
      'Adulto': 0,
      'Estudiante': 25,
      'INAPAM': 30,
      'Discapacidad': 15,
    };
    double montoTotal = 0;
    final pasajerosConAsiento = widget.pasajeros.asMap().entries.map((e) {
      final p = Map<String, dynamic>.from(e.value);
      p['asiento_id'] = seleccionados[e.key];
      p['asiento_etiqueta'] = _etiquetaDeAsiento(seleccionados[e.key]);
      final desc = descuentos[p['tipo']] ?? 0;
      montoTotal += widget.precioPorPasajero * (1 - desc / 100);
      return p;
    }).toList();

    Navigator.push(
      context,
      AppRoutes.slideLeft(
        PagoScreen(
          viajeId: widget.viajeId,
          pasajeros: pasajerosConAsiento,
          origenNombre: widget.origenNombre,
          destinoNombre: widget.destinoNombre,
          horaSalida: widget.horaSalida,
          horaLlegada: widget.horaLlegada,
          fechaViaje: widget.fechaViaje,
          montoTotal: montoTotal,
          vendedorId: widget.vendedorId,
          tipoUsuario: widget.tipoUsuario,
          datosUsuario: widget.datosUsuario,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Painter del bus VERTICAL — vista top-down, frente arriba
// ═══════════════════════════════════════════════════════════════════════════════
class _BusPainterV extends CustomPainter {
  final double busW, busH, cabH;
  const _BusPainterV({
    required this.busW,
    required this.busH,
    required this.cabH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final pBody = Paint()..color = const Color(0xFFD8DDE4);
    final pInner = Paint()..color = const Color(0xFFF5F7FA);
    final pStroke = Paint()
      ..color = const Color(0xFF5A6270)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final pWheel = Paint()..color = const Color(0xFF1E1E1E);
    final pMirror = Paint()..color = const Color(0xFF444B52);

    // Carrocería — frente muy redondeado (arriba), trasera menos (abajo)
    final r = w * 0.17;
    final rB = w * 0.05;
    final bodyPath = Path()
      ..moveTo(w * 0.09 + r, h * 0.01)
      ..lineTo(w * 0.91 - r, h * 0.01)
      ..quadraticBezierTo(w * 0.91, h * 0.01, w * 0.91, h * 0.01 + r)
      ..lineTo(w * 0.91, h * 0.99 - rB)
      ..quadraticBezierTo(w * 0.91, h * 0.99, w * 0.91 - rB, h * 0.99)
      ..lineTo(w * 0.09 + rB, h * 0.99)
      ..quadraticBezierTo(w * 0.09, h * 0.99, w * 0.09, h * 0.99 - rB)
      ..lineTo(w * 0.09, h * 0.01 + r)
      ..quadraticBezierTo(w * 0.09, h * 0.01, w * 0.09 + r, h * 0.01)
      ..close();
    canvas.drawPath(bodyPath, pBody);
    canvas.drawPath(bodyPath, pStroke);

    // Interior zona asientos
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.14, cabH * 0.97, w * 0.86, h * 0.975),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      pInner,
    );

    // Parabrisas — grande, redondeado arriba, ocupa casi todo el ancho
    final wr = w * 0.15;
    final wT = h * 0.016;
    final wB = cabH * 0.75;
    final windPath = Path()
      ..moveTo(w * 0.13 + wr, wT)
      ..lineTo(w * 0.87 - wr, wT)
      ..quadraticBezierTo(w * 0.87, wT, w * 0.87, wT + wr)
      ..lineTo(w * 0.87, wB)
      ..lineTo(w * 0.13, wB)
      ..lineTo(w * 0.13, wT + wr)
      ..quadraticBezierTo(w * 0.13, wT, w * 0.13 + wr, wT)
      ..close();
    canvas.drawPath(
      windPath,
      Paint()..color = const Color(0xFFADD8E6).withOpacity(0.55),
    );
    canvas.drawPath(windPath, pStroke);

    // Marco interior del parabrisas
    final wi = w * 0.022;
    final wri = wr * 0.65;
    final windInner = Path()
      ..moveTo(w * 0.13 + wi + wri, wT + wi)
      ..lineTo(w * 0.87 - wi - wri, wT + wi)
      ..quadraticBezierTo(w * 0.87 - wi, wT + wi, w * 0.87 - wi, wT + wi + wri)
      ..lineTo(w * 0.87 - wi, wB - wi)
      ..lineTo(w * 0.13 + wi, wB - wi)
      ..lineTo(w * 0.13 + wi, wT + wi + wri)
      ..quadraticBezierTo(w * 0.13 + wi, wT + wi, w * 0.13 + wi + wri, wT + wi)
      ..close();
    canvas.drawPath(
      windInner,
      Paint()
        ..color = const Color(0xFF5A6270)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Línea divisoria cabina/pasajeros
    canvas.drawLine(
      Offset(w * 0.13, cabH),
      Offset(w * 0.78, cabH),
      Paint()
        ..color = const Color(0xFF8B96A0)
        ..strokeWidth = 1.5,
    );

    // Ruedas delanteras
    final wW = w * 0.085;
    final wH = cabH * 0.20;
    final wY = cabH * 0.65;
    for (final x in [w * 0.025, w * 0.89]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, wY, wW, wH),
          const Radius.circular(3),
        ),
        pWheel,
      );
    }

    // Ruedas traseras
    final rY = h * 0.82;
    final rH = wH * 1.2;
    final rW = wW * 1.1;
    for (final x in [w * 0.025, w * 0.89 - (rW - wW)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, rY, rW, rH),
          const Radius.circular(3),
        ),
        pWheel,
      );
    }

    // Espejos
    final mW = w * 0.052;
    final mH = cabH * 0.13;
    final mY = cabH * 0.20;
    for (final x in [w * 0.028, w * 0.92]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mY, mW, mH),
          const Radius.circular(3),
        ),
        pMirror,
      );
    }

    // Parachoque trasero
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.966, w * 0.68, h * 0.02),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8B96A0),
    );
  }

  @override
  bool shouldRepaint(covariant _BusPainterV old) =>
      old.busW != busW || old.busH != busH || old.cabH != cabH;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Painter del bus HORIZONTAL — vista top-down, frente izquierda
// ═══════════════════════════════════════════════════════════════════════════════
class _BusPainterH extends CustomPainter {
  final double busW, busH, cabW;
  const _BusPainterH({
    required this.busW,
    required this.busH,
    required this.cabW,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final pBody = Paint()..color = const Color(0xFFD8DDE4);
    final pInner = Paint()..color = const Color(0xFFF5F7FA);
    final pStroke = Paint()
      ..color = const Color(0xFF5A6270)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final pWheel = Paint()..color = const Color(0xFF1E1E1E);
    final pMirror = Paint()..color = const Color(0xFF444B52);

    // Carrocería — frente muy redondeado (izquierda), trasera menos (derecha)
    final r = h * 0.17;
    final rB = h * 0.05;
    final bodyPath = Path()
      ..moveTo(w * 0.01, h * 0.09 + r)
      ..quadraticBezierTo(w * 0.01, h * 0.09, w * 0.01 + r, h * 0.09)
      ..lineTo(w * 0.99 - rB, h * 0.09)
      ..quadraticBezierTo(w * 0.99, h * 0.09, w * 0.99, h * 0.09 + rB)
      ..lineTo(w * 0.99, h * 0.91 - rB)
      ..quadraticBezierTo(w * 0.99, h * 0.91, w * 0.99 - rB, h * 0.91)
      ..lineTo(w * 0.01 + r, h * 0.91)
      ..quadraticBezierTo(w * 0.01, h * 0.91, w * 0.01, h * 0.91 - r)
      ..close();
    canvas.drawPath(bodyPath, pBody);
    canvas.drawPath(bodyPath, pStroke);

    // Interior
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(cabW * 0.97, h * 0.14, w * 0.975, h * 0.86),
        topRight: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      pInner,
    );

    // Parabrisas
    final wr = h * 0.15;
    final wL = w * 0.016;
    final wR = cabW * 0.75;
    final windPath = Path()
      ..moveTo(wL, h * 0.13 + wr)
      ..quadraticBezierTo(wL, h * 0.13, wL + wr, h * 0.13)
      ..lineTo(wR, h * 0.13)
      ..lineTo(wR, h * 0.87)
      ..lineTo(wL + wr, h * 0.87)
      ..quadraticBezierTo(wL, h * 0.87, wL, h * 0.87 - wr)
      ..close();
    canvas.drawPath(
      windPath,
      Paint()..color = const Color(0xFFADD8E6).withOpacity(0.55),
    );
    canvas.drawPath(windPath, pStroke);

    // Marco interior
    final wi = h * 0.022;
    final wri = wr * 0.65;
    final windInner = Path()
      ..moveTo(wL + wi, h * 0.13 + wi + wri)
      ..quadraticBezierTo(wL + wi, h * 0.13 + wi, wL + wi + wri, h * 0.13 + wi)
      ..lineTo(wR - wi, h * 0.13 + wi)
      ..lineTo(wR - wi, h * 0.87 - wi)
      ..lineTo(wL + wi + wri, h * 0.87 - wi)
      ..quadraticBezierTo(wL + wi, h * 0.87 - wi, wL + wi, h * 0.87 - wi - wri)
      ..close();
    canvas.drawPath(
      windInner,
      Paint()
        ..color = const Color(0xFF5A6270)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Línea divisoria
    canvas.drawLine(
      Offset(cabW, h * 0.13),
      Offset(cabW, h * 0.87),
      Paint()
        ..color = const Color(0xFF8B96A0)
        ..strokeWidth = 1.5,
    );

    // Ruedas delanteras
    final wH2 = h * 0.085;
    final wW2 = cabW * 0.20;
    final wX = cabW * 0.62;
    for (final y in [h * 0.025, h * 0.89]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(wX, y, wW2, wH2),
          const Radius.circular(3),
        ),
        pWheel,
      );
    }

    // Ruedas traseras
    final rX = w * 0.83;
    final rW2 = wW2 * 1.2;
    final rH2 = wH2 * 1.1;
    for (final y in [h * 0.025, h * 0.89 - (rH2 - wH2)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rX, y, rW2, rH2),
          const Radius.circular(3),
        ),
        pWheel,
      );
    }

    // Espejos
    final mH2 = h * 0.052;
    final mW2 = cabW * 0.13;
    final mX = cabW * 0.20;
    for (final y in [h * 0.028, h * 0.92]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(mX, y, mW2, mH2),
          const Radius.circular(3),
        ),
        pMirror,
      );
    }

    // Parachoque trasero
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.966, h * 0.16, w * 0.02, h * 0.68),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8B96A0),
    );
  }

  @override
  bool shouldRepaint(covariant _BusPainterH old) =>
      old.busW != busW || old.busH != busH || old.cabW != cabW;
}

// ═══════════════════════════════════════════════════════════════════════════════
// _SeatPainter — Asiento top-down
// Respaldo redondeado ARRIBA (hacia frente del bus), cuerpo ABAJO
// ═══════════════════════════════════════════════════════════════════════════════
class _SeatPainter extends CustomPainter {
  final Color color;
  final bool selected;
  final bool ocupado;

  const _SeatPainter({
    required this.color,
    required this.selected,
    required this.ocupado,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = selected
          ? Colors.white.withOpacity(0.65)
          : Colors.black.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.8 : 1.0;

    // Sombra
    if (!ocupado) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1.5, 2, w - 3, h - 3),
          Radius.circular(w * 0.18),
        ),
        Paint()
          ..color = color.withOpacity(selected ? 0.38 : 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Respaldo (arriba, muy redondeado) — 28% del alto ──
    final backRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.10, h * 0.01, w * 0.80, h * 0.29),
      topLeft: Radius.circular(w * 0.38),
      topRight: Radius.circular(w * 0.38),
      bottomLeft: Radius.circular(w * 0.04),
      bottomRight: Radius.circular(w * 0.04),
    );
    canvas.drawRRect(backRect, paint);
    canvas.drawRRect(backRect, strokePaint);

    // Arco decorativo dentro del respaldo
    canvas.drawArc(
      Rect.fromLTWH(w * 0.20, h * 0.03, w * 0.60, h * 0.18),
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // ── Cuerpo (abajo) — del 29% al 95% ──
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.04, h * 0.28, w * 0.92, h * 0.67),
      topLeft: Radius.circular(w * 0.07),
      topRight: Radius.circular(w * 0.07),
      bottomLeft: Radius.circular(w * 0.22),
      bottomRight: Radius.circular(w * 0.22),
    );
    canvas.drawRRect(bodyRect, paint);
    canvas.drawRRect(bodyRect, strokePaint);

    // ── Apoyabrazos ──
    final armPaint = Paint()..color = color.withOpacity(0.72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.33, w * 0.07, h * 0.36),
        Radius.circular(w * 0.035),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.93, h * 0.33, w * 0.07, h * 0.36),
        Radius.circular(w * 0.035),
      ),
      armPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SeatPainter old) =>
      old.color != color || old.selected != selected || old.ocupado != ocupado;
}

// ═══════════════════════════════════════════════════════════════════════════════
// _VolantePainter
// ═══════════════════════════════════════════════════════════════════════════════
class _VolantePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFF555C63),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.60,
      Paint()..color = const Color(0xFF8B96A0),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.18,
      Paint()..color = const Color(0xFF1C1C1C),
    );

    final spokePaint = Paint()
      ..color = const Color(0xFF555C63)
      ..strokeWidth = r * 0.20
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * pi / 180;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * 0.55 * cos(angle), cy + r * 0.55 * sin(angle)),
        spokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
