import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../../utils/transitions.dart';
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
  // ── Paleta ──────────────────────────────────────────────────────────────────
  static const azul = Color(0xFF2C7FB1); // disponible
  static const grisOc = Color(0xFFB0B8C1); // ocupado
  static const naranja = Color(0xFFE9713A); // seleccionado
  static const morado = Color(0xFF7B2FBE); // discapacidad
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

  // ── API ─────────────────────────────────────────────────────────────────────
  Future<void> cargarAsientos() async {
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/viajes/${widget.viajeId}/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          asientos = List<dynamic>.from(data['asientos']);
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

  // ── Color del asiento ────────────────────────────────────────────────────────
  Color _colorAsiento(Map asiento) {
    final numero = asiento['asiento']['numero'] as int;
    final ocupado = asiento['ocupado'] == 1;
    final tipo = asiento['asiento']['tipo']['codigo'] as String;

    if (seleccionados.contains(numero)) return naranja;
    if (ocupado) return grisOc;
    if (tipo == 'DIS') return morado;
    return azul;
  }

  bool _isOcupado(Map asiento) => asiento['ocupado'] == 1;

  void _toggleAsiento(Map asiento) {
    if (_isOcupado(asiento)) return;
    final numero = asiento['asiento']['numero'] as int;
    final total = widget.pasajeros.length;
    setState(() {
      if (seleccionados.contains(numero)) {
        seleccionados.remove(numero);
      } else {
        if (seleccionados.length < total) {
          seleccionados.add(numero);
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
    final disA = asientos
        .where((a) => a['asiento']['tipo']['codigo'] == 'DIS')
        .toList();
    final normA = asientos
        .where((a) => a['asiento']['tipo']['codigo'] != 'DIS')
        .toList();
    for (int i = 0; i < disA.length; i++) {
      if (disA[i]['asiento']['numero'] == numeroAsiento) return 'D${i + 1}';
    }
    for (int i = 0; i < normA.length; i++) {
      if (normA[i]['asiento']['numero'] == numeroAsiento) {
        final fila = i ~/ 4;
        final col = i % 4;
        return '${letras[fila % letras.length]}${col + 1}';
      }
    }
    return '$numeroAsiento';
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoApp,
      appBar: _buildAppBar(),
      body: cargando ? _buildLoader() : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
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

  Widget _buildLoader() =>
      const Center(child: CircularProgressIndicator(color: azul));

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(scale: _scaleAnim, child: _buildBus()),
            ),
          ),
        ),
        _buildLeyendaBar(),
        _buildBotonConfirmar(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTOBÚS completo
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBus() {
    return LayoutBuilder(
      builder: (ctx, bc) {
        final busW = bc.maxWidth.clamp(260.0, 360.0);

        final disA = asientos
            .where((a) => a['asiento']['tipo']['codigo'] == 'DIS')
            .toList();
        final normA = asientos
            .where((a) => a['asiento']['tipo']['codigo'] != 'DIS')
            .toList();

        const seatGap = 4.0;
        const aisleW = 38.0;
        const hPad = 14.0;

        final seatW = ((busW - hPad * 2 - seatGap * 3) / 4).clamp(28.0, 60.0);
        final seatH = seatW * 1.12;

        final rowH = seatH + seatGap;
        final cabH = seatH * 1.9;

        final numFilas = (normA.length / 4).ceil();
        final busH = cabH + rowH + numFilas * rowH + seatH * 0.6 + 24;

        return Center(
          child: SizedBox(
            width: busW,
            height: busH,
            child: Stack(
              children: [
                // ── NUEVO MARCO ──
                Positioned.fill(
                  child: CustomPaint(painter: const _BusCarroceriaPainter()),
                ),

                // ── CONTENIDO INTERNO ──
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Frente
                        SizedBox(
                          height: cabH,
                          child: _buildFrente(busW, cabH, seatW, seatH),
                        ),

                        // Discapacidad
                        Padding(
                          padding: const EdgeInsets.only(bottom: seatGap),
                          child: _buildFila(
                            izq: [disA.isNotEmpty ? disA[0] : null, null],
                            der: [null, disA.length > 1 ? disA[1] : null],
                            seatW: seatW,
                            seatH: seatH,
                            seatGap: seatGap,
                            aisleW: aisleW,
                            labels: [
                              disA.isNotEmpty ? 'D1' : '',
                              '',
                              '',
                              disA.length > 1 ? 'D2' : '',
                            ],
                          ),
                        ),

                        // Filas normales
                        ...List.generate(numFilas, (fi) {
                          const letras = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
                          final start = fi * 4;
                          final end = min(start + 4, normA.length);
                          final fila = normA.sublist(start, end);

                          while (fila.length < 4) fila.add(null);

                          final l = letras[fi % 26];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: seatGap),
                            child: _buildFila(
                              izq: [fila[0], fila[1]],
                              der: [fila[2], fila[3]],
                              seatW: seatW,
                              seatH: seatH,
                              seatGap: seatGap,
                              aisleW: aisleW,
                              labels: [
                                fila[0] != null ? '${l}1' : '',
                                fila[1] != null ? '${l}2' : '',
                                fila[2] != null ? '${l}3' : '',
                                fila[3] != null ? '${l}4' : '',
                              ],
                            ),
                          );
                        }),

                        SizedBox(height: seatH * 0.4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Frente del bus ───────────────────────────────────────────────────────────
  // Fondo teal oscuro (pintado en la carrocería).
  // Izquierda: asiento conductor + volante blanco.
  // Derecha: panel con líneas verticales (ventana/rejilla).
  Widget _buildFrente(double busW, double cabH, double seatW, double seatH) {
    return SizedBox(
      width: busW,
      height: cabH,
      child: CustomPaint(painter: _FrenteFlatPainter()),
    );
  }

  // ── Fila de asientos ─────────────────────────────────────────────────────────
  Widget _buildFila({
    required List izq,
    required List der,
    required double seatW,
    required double seatH,
    required double seatGap,
    required double aisleW,
    required List<String> labels,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Grupo izquierdo: col1 pegada a orilla, col2 más al centro
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seat(izq[0], seatW, seatH, labels[0]),
            SizedBox(width: seatGap * 3.5), // 👈 gap mayor entre col1 y col2
            _seat(izq[1], seatW, seatH, labels[1]),
          ],
        ),
        // Grupo derecho: col3 más al centro, col4 pegada a orilla
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seat(der[0], seatW, seatH, labels[2]),
            SizedBox(width: seatGap * 3.5), // 👈 gap mayor entre col3 y col4
            _seat(der[1], seatW, seatH, labels[3]),
          ],
        ),
      ],
    );
  }

  Widget _seat(dynamic asiento, double w, double h, String etiqueta) {
    if (asiento == null) return SizedBox(width: w, height: h);

    final color = _colorAsiento(asiento);
    final ocupado = _isOcupado(asiento);
    final numero = asiento['asiento']['numero'] as int;
    final selected = seleccionados.contains(numero);

    return GestureDetector(
      onTap: () => _toggleAsiento(asiento),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: w,
        height: h,
        child: CustomPaint(
          painter: _SeatPainter(
            color: color,
            selected: selected,
            ocupado: ocupado,
          ),
          child: Center(
            child: Align(
              alignment: const Alignment(0, -0.3),
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ocupado ? Colors.white60 : Colors.white,
                  fontSize: min(w, h) * 0.22,
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

  // ── Leyenda ──────────────────────────────────────────────────────────────────
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

  // ── Botón confirmar ──────────────────────────────────────────────────────────
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
// _BusCarroceriaPainter
// Cuerpo blanco con borde oscuro. Frente también blanco.
// ═══════════════════════════════════════════════════════════════════════════════
class _BusCarroceriaPainter extends CustomPainter {
  const _BusCarroceriaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final relleno = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borde = Paint()
      ..color = const Color(0xFF0F4C5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // ── Marco principal ──
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(28),
    );

    canvas.drawRRect(rect, relleno);
    canvas.drawRRect(rect, borde);

    // ── Borde superior grueso ──
    final topBorder = Paint()
      ..color = const Color(0xFF0F4C5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const r = 28.0;
    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    canvas.drawPath(path, topBorder);

    // ── Salientes laterales ──
    final sidePaint = Paint()..color = const Color(0xFF0F4C5C);
    final sideW = w * 0.04;
    final sideH = h * 0.08;

    // arriba izquierda
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-sideW / 2, h * 0.15, sideW, sideH),
        const Radius.circular(4),
      ),
      sidePaint,
    );

    // arriba derecha
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - sideW / 2, h * 0.15, sideW, sideH),
        const Radius.circular(4),
      ),
      sidePaint,
    );

    // ── Llantas inferiores ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-sideW / 2, h * 0.75, sideW, sideH),
        const Radius.circular(4),
      ),
      sidePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - sideW / 2, h * 0.75, sideW, sideH),
        const Radius.circular(4),
      ),
      sidePaint,
    );

    // ── Retrovisores ──
    // Variables compartidas para que brazo y espejo estén siempre alineados
    final retroY = h * 0.02;
    final brazoH = h * 0.025;
    final brazoW = w * 0.06;
    final espejoH = h * 0.09;
    final espejoW = w * 0.06;
    // El espejo se centra verticalmente respecto al brazo
    final espejoY = retroY - (brazoH * 0.5);

    // Retrovisor izquierdo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-brazoW, retroY, brazoW, brazoH),
        const Radius.circular(2),
      ),
      sidePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-brazoW - espejoW, espejoY, espejoW, espejoH),
        const Radius.circular(4),
      ),
      sidePaint,
    );

    // Retrovisor derecho
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w, retroY, brazoW, brazoH),
        const Radius.circular(2),
      ),
      sidePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w + brazoW, espejoY, espejoW, espejoH),
        const Radius.circular(4),
      ),
      sidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// _EscalerasFrentePainter
// Simula las escaleras de acceso al autobús (lado derecho del frente).
// Dibuja escalones en perspectiva isométrica ligera: rectángulos con huella
// y contrahuella diferenciados, más pequeños que el panel anterior.
// ═══════════════════════════════════════════════════════════════════════════════
class _EscalerasFrentePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const numEscalones = 3;
    final escalonH = h / numEscalones;

    // 🔥 ancho más pequeño para que se note que están a la derecha
    final anchoBase = w * 0.65;

    final pHuella = Paint()..color = const Color(0xFFDDDDDD);
    final pContra = Paint()..color = const Color(0xFFAAAAAA);

    final pBorde = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < numEscalones; i++) {
      final escalonIndex = numEscalones - 1 - i;

      // más profundidad visible
      final retroceso = escalonIndex * w * 0.08;

      final anchoEsc = anchoBase - retroceso;

      // 🔥 ahora sí pegado al borde derecho REAL
      final xLeft = w - anchoEsc;
      final yTop = i * escalonH;

      final huella = Rect.fromLTWH(xLeft, yTop, anchoEsc, escalonH * 0.42);

      canvas.drawRect(huella, pHuella);
      canvas.drawRect(huella, pBorde);

      final contra = Rect.fromLTWH(
        xLeft,
        yTop + escalonH * 0.42,
        anchoEsc,
        escalonH * 0.58,
      );

      canvas.drawRect(contra, pContra);
      canvas.drawRect(contra, pBorde);

      // sombra
      canvas.drawLine(
        Offset(xLeft, yTop + escalonH * 0.42),
        Offset(xLeft + anchoEsc, yTop + escalonH * 0.42),
        Paint()
          ..color = const Color(0xFF333333).withOpacity(0.35)
          ..strokeWidth = 1.4,
      );
    }

    // borde exterior
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = const Color(0xFF555555)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 🔥 LÍNEA GRUESA DERECHA (muy visible)
    canvas.drawRect(
      Rect.fromLTWH(w - 6, 0, 6, h),
      Paint()..color = const Color(0xFF555555),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// _SeatPainter — Asiento (vista cenital)
// ═══════════════════════════════════════════════════════════════════════════════
class _SeatPainter extends CustomPainter {
  final Color color;
  final bool selected;
  final bool ocupado;
  final bool esIcono;

  const _SeatPainter({
    required this.color,
    required this.selected,
    required this.ocupado,
    this.esIcono = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final mainColor = ocupado ? color.withOpacity(0.45) : color;
    final armColor = Color.lerp(
      color,
      Colors.black,
      0.12,
    )!.withOpacity(ocupado ? 0.45 : 1.0);

    final armRadius = Radius.circular(w * 0.18);

    // ── Apoyabrazos izquierdo ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * 0.10, h * 0.30, w * 0.26, h * 0.55),
        armRadius,
      ),
      Paint()..color = armColor,
    );

    // ── Apoyabrazos derecho ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.84, h * 0.30, w * 0.26, h * 0.55),
        armRadius,
      ),
      Paint()..color = armColor,
    );

    // ── Cuerpo principal (respaldo) ──
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, 0, w * 0.88, h * 0.78),
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(body, Paint()..color = mainColor);

    // ── Cojín abajo (rectángulo con esquinas suaves) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.02, h * 0.74, w * 0.96, h * 0.24),
        Radius.circular(w * 0.08), // 👈 poco radio, casi rectangular
      ),
      Paint()..color = armColor,
    );

    // ── Borde seleccionado ──
    if (selected) {
      canvas.drawRRect(
        body,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeatPainter old) =>
      old.color != color || old.selected != selected || old.ocupado != ocupado;
}

// ═══════════════════════════════════════════════════════════════════════════════
// _VolantePainter — Volante blanco sobre fondo teal
// ═══════════════════════════════════════════════════════════════════════════════
class _VolanteSimplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.9;

    final paint = Paint()
      ..color = const Color(0xFF0F4C5C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.2;

    // aro
    canvas.drawCircle(center, radius, paint);

    // centro
    canvas.drawCircle(
      center,
      radius * 0.2,
      Paint()..color = const Color(0xFF0F4C5C),
    );

    // rayos
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * pi / 180;
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(angle) * radius * 0.6,
          center.dy + sin(angle) * radius * 0.6,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PanelLineasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F4C5C)
      ..strokeWidth = 2;

    final spacing = size.width / 6;

    for (int i = 1; i <= 4; i++) {
      final x = spacing * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // línea curva inferior
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
        size.width / 2,
        size.height - 10,
        size.width,
        size.height,
      );

    canvas.drawPath(path, paint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrenteFlatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final color = const Color(0xFF0F4C5C);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── Línea superior (ventana) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.01, w * 0.5, h * 0.08),
        const Radius.circular(10),
      ),
      fill,
    );

    // ── VOLANTE ──
    final center = Offset(w * 0.20, h * 0.33);
    final radius = w * 0.08;

    canvas.drawCircle(center, radius, stroke);
    canvas.drawCircle(center, radius * 0.25, fill);

    canvas.drawLine(center, Offset(center.dx, center.dy - radius), stroke);
    canvas.drawLine(
      center,
      Offset(center.dx - radius * 0.8, center.dy + radius * 0.5),
      stroke,
    );
    canvas.drawLine(
      center,
      Offset(center.dx + radius * 0.8, center.dy + radius * 0.5),
      stroke,
    );

    // ── ASIENTO ──
    final asientoRect = Rect.fromLTWH(w * 0.10, h * 0.55, w * 0.20, h * 0.24);

    canvas.drawRRect(
      RRect.fromRectAndRadius(asientoRect, const Radius.circular(6)),
      fill,
    );

    final curva = Path()
      ..moveTo(w * 0.10, h * 0.85)
      ..quadraticBezierTo(w * 0.20, h * 0.92, w * 0.30, h * 0.85);

    canvas.drawPath(curva, stroke);

    // ── ESCALONES (líneas delgadas) ──
    final startX = w * 0.75;
    final spacing = w * 0.06;

    for (int i = 0; i < 4; i++) {
      final x = startX + (i * spacing);

      canvas.drawLine(
        Offset(x, h * 0.40),
        Offset(x, h * 0.75),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── LÍNEA GRUESA DERECHA (separada) ──
    canvas.drawRect(Rect.fromLTWH(w - 1, h * 0.40, 6, h * 0.45), fill);

    // ── CURVA DERECHA ──
    final curvaDer = Path()
      ..moveTo(w * 0.70, h * 0.82)
      ..quadraticBezierTo(w * 0.88, h * 0.85, w * 0.98, h * 0.82);

    canvas.drawPath(curvaDer, stroke..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
