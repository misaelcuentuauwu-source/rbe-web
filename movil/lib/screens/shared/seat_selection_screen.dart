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
  // ─── Colores ───────────────────────────────────────────────────────────────
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const morado = Color(0xFF7B2FBE);
  static const grisOc = Color(0xFFB0B8C1);
  static const fondoApp = Color(0xFFF0F4F8);

  // ─── Estado ────────────────────────────────────────────────────────────────
  List<dynamic> asientos = [];
  List<int> seleccionados = [];
  bool cargando = true;

  // ─── Animaciones ───────────────────────────────────────────────────────────
  late AnimationController _busEntradaCtrl;
  late Animation<Offset> _busSlide;
  late Animation<double> _busFade;

  late AnimationController _asientosCtrl;
  late Animation<double> _asientosFade;
  late Animation<double> _asientosScale;

  @override
  void initState() {
    super.initState();

    // Autobús: entra desde la derecha
    _busEntradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _busSlide = Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _busEntradaCtrl, curve: Curves.easeOutCubic),
        );
    _busFade = CurvedAnimation(
      parent: _busEntradaCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    // Asientos: aparecen después del autobús
    _asientosCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _asientosFade = CurvedAnimation(
      parent: _asientosCtrl,
      curve: Curves.easeOut,
    );
    _asientosScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _asientosCtrl, curve: Curves.easeOutBack),
    );

    cargarAsientos();
  }

  @override
  void dispose() {
    _busEntradaCtrl.dispose();
    _asientosCtrl.dispose();
    super.dispose();
  }

  // ─── Carga de datos ────────────────────────────────────────────────────────
  Future<void> cargarAsientos() async {
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/viajes/${widget.viajeId}/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = List<dynamic>.from(data['asientos']);
        lista.sort((a, b) {
          final at = a['asiento']['tipo']['codigo'];
          final bt = b['asiento']['tipo']['codigo'];
          if (at == 'DIS' && bt != 'DIS') return -1;
          if (at != 'DIS' && bt == 'DIS') return 1;
          return 0;
        });
        setState(() {
          asientos = lista;
          cargando = false;
        });
        // Secuencia de animación
        await _busEntradaCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 120));
        _asientosCtrl.forward();
      } else {
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Error cargando asientos: $e');
      setState(() => cargando = false);
    }
  }

  // ─── Lógica de asientos ────────────────────────────────────────────────────
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

  // ─── Build principal ───────────────────────────────────────────────────────
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

  Widget _buildLoader() {
    return const Center(child: CircularProgressIndicator(color: azul));
  }

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

  // ─── Portrait ──────────────────────────────────────────────────────────────
  Widget _buildPortrait(BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          child: _buildBusArea(constraints: constraints, isLandscape: false),
        ),
        _buildLeyendaBar(),
        _buildBotonConfirmar(),
      ],
    );
  }

  // ─── Landscape ─────────────────────────────────────────────────────────────
  Widget _buildLandscape(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          child: _buildBusArea(constraints: constraints, isLandscape: true),
        ),
        Container(
          width: 172,
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

  // ─── Área del autobús ──────────────────────────────────────────────────────
  Widget _buildBusArea({
    required BoxConstraints constraints,
    required bool isLandscape,
  }) {
    return LayoutBuilder(
      builder: (ctx, inner) {
        return SingleChildScrollView(
          scrollDirection: isLandscape ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(12),
          child: Center(child: _buildBusAnimado(inner, isLandscape)),
        );
      },
    );
  }

  Widget _buildBusAnimado(BoxConstraints constraints, bool isLandscape) {
    double busWidth;

    if (isLandscape) {
      // En landscape el bus está rotado 90°:
      // su "ancho" (busWidth) se convierte en la altura visible del área.
      // Calculamos cuánto alto disponemos y lo usamos como busWidth.
      final availH = constraints.maxHeight - 24;
      busWidth = availH.clamp(200.0, 340.0);
    } else {
      final availW = constraints.maxWidth - 24;
      busWidth = availW.clamp(240.0, 480.0);
    }

    final numFilas = (asientos.length / 4).ceil();
    final cabinHeight = busWidth * 0.22;
    final seatSize = ((busWidth * 0.68) / 4.86).clamp(26.0, 52.0);
    final seatsHeight = numFilas * (seatSize + 8.0) + 24;
    final busHeight = cabinHeight + seatsHeight + busWidth * 0.16;

    final totalSeatsW = seatSize * 4 + seatSize * 0.15 * 3 + seatSize * 0.5;
    final hPad = (busWidth - totalSeatsW) / 2;

    Widget busCuerpo = CustomPaint(
      painter: BusPainter(
        busWidth: busWidth,
        busHeight: busHeight,
        cabinHeight: cabinHeight,
      ),
      child: SizedBox(
        width: busWidth,
        height: busHeight,
        child: Padding(
          padding: EdgeInsets.only(
            top: cabinHeight + seatSize * 0.12,
            left: hPad,
            right: hPad,
            bottom: 12,
          ),
          child: FadeTransition(
            opacity: _asientosFade,
            child: ScaleTransition(
              scale: _asientosScale,
              child: _buildAsientos(seatSize),
            ),
          ),
        ),
      ),
    );

    if (isLandscape) {
      // Rotamos el bus 90°: su ancho (busWidth) queda como alto visible,
      // su largo (busHeight) se extiende horizontalmente — el scroll lo cubre.
      busCuerpo = RotatedBox(quarterTurns: 1, child: busCuerpo);
    }

    return FadeTransition(
      opacity: _busFade,
      child: SlideTransition(position: _busSlide, child: busCuerpo),
    );
  }

  // ─── Grid de asientos ──────────────────────────────────────────────────────
  Widget _buildAsientos(double seatSize) {
    List<List<dynamic>> filas = [];
    for (int i = 0; i < asientos.length; i += 4) {
      final end = min(i + 4, asientos.length);
      final fila = List<dynamic>.from(asientos.sublist(i, end));
      while (fila.length < 4) fila.add(null);
      filas.add(fila);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: filas.map((fila) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: seatSize * 0.06),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAsiento(fila[0], seatSize),
              SizedBox(width: seatSize * 0.15),
              _buildAsiento(fila[1], seatSize),
              SizedBox(width: seatSize * 0.5), // pasillo
              _buildAsiento(fila[2], seatSize),
              SizedBox(width: seatSize * 0.15),
              _buildAsiento(fila[3], seatSize),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAsiento(dynamic asiento, double size) {
    if (asiento == null) return SizedBox(width: size, height: size);

    final color = _colorAsiento(asiento);
    final ocupado = _isOcupado(asiento);
    final numero = asiento['asiento']['numero'];
    final selected = seleccionados.contains(numero);

    return GestureDetector(
      onTap: () => _toggleAsiento(asiento),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.20),
          border: selected
              ? Border.all(color: Colors.white.withOpacity(0.6), width: 2)
              : null,
          boxShadow: ocupado
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(selected ? 0.55 : 0.30),
                    blurRadius: selected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_seat_rounded,
              color: ocupado
                  ? Colors.white54
                  : selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.92),
              size: size * 0.42,
            ),
            Text(
              '$numero',
              style: TextStyle(
                color: ocupado ? Colors.white54 : Colors.white,
                fontSize: size * 0.20,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ],
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
          _leyendaChip(azul, 'Disponible'),
          _leyendaChip(grisOc, 'Ocupado'),
          _leyendaChip(naranja, 'Seleccionado'),
          _leyendaChip(morado, 'Discapacidad'),
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
        _leyendaChip(azul, 'Disponible'),
        const SizedBox(height: 8),
        _leyendaChip(grisOc, 'Ocupado'),
        const SizedBox(height: 8),
        _leyendaChip(naranja, 'Seleccionado'),
        const SizedBox(height: 8),
        _leyendaChip(morado, 'Discapacidad'),
      ],
    );
  }

  Widget _leyendaChip(Color color, String label) {
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

  // ─── Navegar a pago ────────────────────────────────────────────────────────
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
// BusPainter — versión limpia y bien proporcionada
// ═══════════════════════════════════════════════════════════════════════════════
class BusPainter extends CustomPainter {
  final double busWidth;
  final double busHeight;
  final double cabinHeight;

  const BusPainter({
    required this.busWidth,
    required this.busHeight,
    required this.cabinHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Colores base ──────────────────────────────────────────────────────────
    final pCuerpo = Paint()..color = const Color(0xFFD8DDE4);
    final pInterior = Paint()..color = const Color(0xFFF5F7FA);
    final pCabina = Paint()..color = const Color(0xFFC2C8D0);
    final pBorde = Paint()
      ..color = const Color(0xFF8B96A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010;
    final pRueda = Paint()..color = const Color(0xFF2E2E2E);
    final pRuedaRim = Paint()
      ..color = const Color(0xFF777777)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014;
    final pVolante = Paint()..color = const Color(0xFF888E94);
    final pSpoke = Paint()
      ..color = const Color(0xFF9EA5AB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round;

    // ── Cuerpo principal ──────────────────────────────────────────────────────
    final bodyR = w * 0.07;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.06, w * 0.03, w * 0.94, h * 0.97),
      topLeft: Radius.circular(bodyR * 2.8),
      topRight: Radius.circular(bodyR * 2.8),
      bottomLeft: Radius.circular(bodyR * 0.8),
      bottomRight: Radius.circular(bodyR * 0.8),
    );
    canvas.drawRRect(body, pCuerpo);
    canvas.drawRRect(body, pBorde);

    // ── Interior (zona asientos) ──────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.11, cabinHeight - 2, w * 0.89, h * 0.94),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      pInterior,
    );

    // ── Cabina ────────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.11, w * 0.06, w * 0.89, cabinHeight),
        topLeft: Radius.circular(bodyR * 2.2),
        topRight: Radius.circular(bodyR * 2.2),
      ),
      pCabina,
    );

    // Línea divisoria cabina / pasajeros
    canvas.drawLine(
      Offset(w * 0.11, cabinHeight),
      Offset(w * 0.89, cabinHeight),
      Paint()
        ..color = const Color(0xFF8B96A0)
        ..strokeWidth = w * 0.006,
    );

    // ── Parabrisas (dos ventanas tipo bus) ────────────────────────────────────
    final winTop = w * 0.085;
    final winBot = cabinHeight * 0.82;
    final winPaint = Paint()..color = const Color(0xFFADD8E6).withOpacity(0.55);
    final winBorder = Paint()
      ..color = const Color(0xFF7A8A95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;

    // Ventana izq
    final winLRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.13, winTop, w * 0.28, winBot - winTop),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(winLRect, winPaint);
    canvas.drawRRect(winLRect, winBorder);

    // Ventana der
    final winRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.59, winTop, w * 0.28, winBot - winTop),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(winRRect, winPaint);
    canvas.drawRRect(winRRect, winBorder);

    // ── Volante ───────────────────────────────────────────────────────────────
    final steerX = w * 0.75;
    final steerY = (w * 0.06 + cabinHeight) / 2 + cabinHeight * 0.04;
    final steerR = min(cabinHeight * 0.30, w * 0.10);

    canvas.drawCircle(Offset(steerX, steerY), steerR, pVolante);
    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR * 0.65,
      Paint()..color = const Color(0xFF1C1C1C),
    );
    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR,
      Paint()
        ..color = const Color(0xFF6A7077)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.013,
    );

    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * pi / 180;
      canvas.drawLine(
        Offset(steerX, steerY),
        Offset(
          steerX + steerR * 0.60 * cos(angle),
          steerY + steerR * 0.60 * sin(angle),
        ),
        pSpoke,
      );
    }
    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR * 0.14,
      Paint()..color = const Color(0xFF6A7077),
    );

    // ── Ruedas delanteras ─────────────────────────────────────────────────────
    final wheelW = w * 0.09;
    final wheelH = cabinHeight * 0.52;
    final frontWheelY = cabinHeight * 0.68;

    for (final x in [w * 0.03, w * 0.88]) {
      final wr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, frontWheelY, wheelW, wheelH),
        Radius.circular(w * 0.025),
      );
      canvas.drawRRect(wr, pRueda);
      // Rin
      final cx = x + wheelW / 2;
      final cy = frontWheelY + wheelH / 2;
      canvas.drawCircle(Offset(cx, cy), wheelW * 0.35, pRuedaRim);
    }

    // ── Ruedas traseras ───────────────────────────────────────────────────────
    final rearY = h * 0.82;
    final rearH = wheelH * 1.12;
    final rearW = wheelW * 1.08;

    for (final x in [w * 0.03, w * 0.89 - (rearW - wheelW)]) {
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, rearY, rearW, rearH),
        Radius.circular(w * 0.025),
      );
      canvas.drawRRect(rr, pRueda);
      final cx = x + rearW / 2;
      final cy = rearY + rearH / 2;
      canvas.drawCircle(Offset(cx, cy), rearW * 0.32, pRuedaRim);
    }

    // ── Espejos ───────────────────────────────────────────────────────────────
    final mirrorPaint = Paint()
      ..color = const Color(0xFF555C63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.020
      ..strokeCap = StrokeCap.round;
    final mirrorBox = Paint()..color = const Color(0xFF444B52);

    // Izq
    canvas.drawLine(
      Offset(w * 0.12, cabinHeight * 0.30),
      Offset(w * 0.04, w * 0.04),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.0, w * 0.02, w * 0.08, w * 0.036),
        Radius.circular(w * 0.008),
      ),
      mirrorBox,
    );

    // Der
    canvas.drawLine(
      Offset(w * 0.88, cabinHeight * 0.30),
      Offset(w * 0.96, w * 0.04),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.92, w * 0.02, w * 0.08, w * 0.036),
        Radius.circular(w * 0.008),
      ),
      mirrorBox,
    );

    // ── Parachoque trasero ─────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.945, w * 0.72, w * 0.025),
        Radius.circular(w * 0.008),
      ),
      Paint()..color = const Color(0xFF8B96A0),
    );
  }

  @override
  bool shouldRepaint(covariant BusPainter old) =>
      old.busWidth != busWidth ||
      old.busHeight != busHeight ||
      old.cabinHeight != cabinHeight;
}
