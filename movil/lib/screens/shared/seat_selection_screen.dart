import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../config.dart';
import '../../utils/transitions.dart';
import 'pago_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SeatSelectionScreen  —  completamente responsiva
//
//  Cambios v2:
//  1. En LANDSCAPE el bus rota 90°: viaja de derecha → izquierda.
//     El contenido interior (cabina, filas, pasillo) se reorganiza
//     para que tenga sentido en orientación horizontal.
//  2. Animación staggered por filas: cada fila de asientos aparece
//     con un fade + slide con delay incremental.
//  3. La animación de entrada global (fade/scale) sigue funcionando.
// ─────────────────────────────────────────────────────────────────────────────
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
  static const _azul = Color(0xFF2C7FB1);
  static const _grisOc = Color(0xFFB0B8C1);
  static const _naranja = Color(0xFFE9713A);
  static const _morado = Color(0xFF7B2FBE);
  static const _fondo = Color(0xFFF0F4F8);
  static const _casco = Color(0xFF0F4C5C);

  List<dynamic> _asientos = [];
  final List<int> _seleccionados = [];
  bool _cargando = true;

  // ── Controlador de entrada global (fade + scale del bus completo) ───────────
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween(
    begin: 0.95,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutBack));

  // ── Controladores staggered por fila ────────────────────────────────────────
  // Se inicializan después de cargar los asientos.
  final List<AnimationController> _rowCtrls = [];
  final List<Animation<double>> _rowFades = [];
  final List<Animation<Offset>> _rowSlides = [];

  // ── Dimensiones internas de referencia (modo PORTRAIT) ──────────────────────
  static const double _refW = 320.0;
  static const double _hPad = 18.0;
  static const double _vPad = 14.0;
  static const double _gap = 7.0;
  static const double _aisleW = 22.0;
  static const double _seatW = (_refW - 2 * _hPad - 3 * _gap - _aisleW) / 4;
  static const double _seatH = _seatW * 1.18;
  static const double _rowH = _seatH + _gap;
  static const double _cabH = _seatH * 1.80;

  // ── Dimensiones internas de referencia (modo LANDSCAPE) ─────────────────────
  // El bus gira: el eje largo es ahora horizontal.
  // "columnas" → lo que eran filas; la cabina queda a la DERECHA.
  static const double _lRefH = 260.0; // alto de referencia en landscape
  static const double _lHPad = 14.0; // padding vertical (era horizontal)
  static const double _lVPad = 12.0; // padding horizontal (era vertical)
  static const double _lGap = 6.0;
  static const double _lAisleH = 20.0; // pasillo ahora es horizontal
  // seatH en landscape: 4 asientos + 3 gaps + 1 pasillo dentro de (lRefH - 2*lHPad)
  static const double _lSeatH =
      (_lRefH - 2 * _lHPad - 3 * _lGap - _lAisleH) / 4;
  static const double _lSeatW = _lSeatH * 1.18;
  static const double _lColW = _lSeatW + _lGap;
  static const double _lCabW = _lSeatW * 1.80; // cabina a la derecha

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    for (final c in _rowCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ── API ─────────────────────────────────────────────────────────────────────
  Future<void> _cargar() async {
    try {
      final res = await http
          .get(Uri.parse('${Config.baseUrl}/api/viajes/${widget.viajeId}/'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _asientos = List<dynamic>.from(data['asientos']);
          _cargando = false;
        });
        _iniciarAnimaciones();
      } else {
        setState(() => _cargando = false);
      }
    } catch (e) {
      debugPrint('Error cargando asientos: $e');
      setState(() => _cargando = false);
    }
  }

  // ── Iniciar animaciones: entrada global + stagger por fila ───────────────────
  void _iniciarAnimaciones() {
    // 1. Entrada global del bus
    _entryCtrl.forward();

    // 2. Calcular cuántas filas hay (dis + normales)
    final norm = _asientos
        .where((a) => a['asiento']['tipo']['codigo'] != 'DIS')
        .toList();
    final numFilas =
        1 + (norm.length / 4).ceil(); // +1 por fila de discapacidad

    // 3. Crear un AnimationController por fila
    for (int i = 0; i < numFilas; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      );
      _rowCtrls.add(ctrl);
      _rowFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _rowSlides.add(
        Tween<Offset>(
          begin: const Offset(0.0, 0.18), // desliza desde abajo
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)),
      );

      // Delay escalonado: 80ms por fila, empieza tras 200ms (espera la entrada global)
      final delay = 200 + i * 80;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) ctrl.forward();
      });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  List<dynamic> get _dis =>
      _asientos.where((a) => a['asiento']['tipo']['codigo'] == 'DIS').toList();
  List<dynamic> get _norm =>
      _asientos.where((a) => a['asiento']['tipo']['codigo'] != 'DIS').toList();

  Color _color(dynamic a) {
    final n = a['asiento']['numero'] as int;
    if (_seleccionados.contains(n)) return _naranja;
    if (a['ocupado'] == 1) return _grisOc;
    if (a['asiento']['tipo']['codigo'] == 'DIS') return _morado;
    return _azul;
  }

  bool _esOcupado(dynamic a) => a['ocupado'] == 1;

  bool _esDIS(dynamic a) => a['asiento']['tipo']['codigo'] == 'DIS';

  /// Cuántos pasajeros de tipo Discapacidad vienen en este viaje.
  int get _totalPasajerosDiscapacidad =>
      widget.pasajeros.where((p) => p['tipo'] == 'Discapacidad').length;

  /// Cuántos asientos DIS ya están seleccionados.
  int get _disSeleccionados => _seleccionados.where((n) {
    try {
      final asiento = _asientos.firstWhere((a) => a['asiento']['numero'] == n);
      return _esDIS(asiento);
    } catch (_) {
      return false;
    }
  }).length;

  void _toggle(dynamic a) {
    if (_esOcupado(a)) return;

    final n = a['asiento']['numero'] as int;
    final esDIS = _esDIS(a);
    final totalDis = _totalPasajerosDiscapacidad;

    // Asiento DIS: bloquear si no hay pasajeros con discapacidad
    if (esDIS && totalDis == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Este asiento está reservado para pasajeros con discapacidad.',
          ),
          backgroundColor: Colors.purple.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // Asiento DIS: bloquear si ya se seleccionaron todos los DIS permitidos
    if (esDIS && !_seleccionados.contains(n) && _disSeleccionados >= totalDis) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            totalDis == 1
                ? 'Solo 1 pasajero con discapacidad — ya seleccionaste su asiento.'
                : 'Ya seleccionaste los $totalDis asientos de discapacidad.',
          ),
          backgroundColor: Colors.purple.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final total = widget.pasajeros.length;
    setState(() {
      if (_seleccionados.contains(n)) {
        _seleccionados.remove(n);
      } else if (_seleccionados.length < total) {
        _seleccionados.add(n);
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
    });
  }

  String _etiqueta(int numero) {
    const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final dis = _dis;
    final norm = _norm;
    for (int i = 0; i < dis.length; i++) {
      if (dis[i]['asiento']['numero'] == numero) return 'D${i + 1}';
    }
    for (int i = 0; i < norm.length; i++) {
      if (norm[i]['asiento']['numero'] == numero) {
        return '${abc[(i ~/ 4) % 26]}${(i % 4) + 1}';
      }
    }
    return '$numero';
  }

  // ── Altura total del bus PORTRAIT ────────────────────────────────────────────
  double _refH() {
    final rows = (_norm.length / 4).ceil();
    return _vPad + _cabH + _gap + _rowH + rows * _rowH + _seatH * 0.5 + _vPad;
  }

  // ── Ancho total del bus LANDSCAPE ────────────────────────────────────────────
  double _lRefW() {
    final cols = (_norm.length / 4).ceil();
    return _lVPad +
        _lCabW +
        _lGap +
        _lColW +
        cols * _lColW +
        _lSeatW * 0.5 +
        _lVPad;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: _appBar(),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _azul))
          : OrientationBuilder(
              builder: (ctx, orientation) {
                final isLandscape = orientation == Orientation.landscape;
                return Column(
                  children: [
                    Expanded(
                      child: isLandscape
                          ? _scrollableBusLandscape()
                          : _scrollableBusPortrait(),
                    ),
                    _leyenda(),
                    _boton(),
                  ],
                );
              },
            ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: _azul,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
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
  );

  // ══════════════════════════════════════════════════════════════════════════════
  //  PORTRAIT — mismo comportamiento que antes
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _scrollableBusPortrait() {
    return LayoutBuilder(
      builder: (ctx, bc) {
        final availW = bc.maxWidth;
        final availH = bc.maxHeight;
        final refH = _refH();
        final scale = (availW - 32) / _refW;
        final scaledH = refH * scale;

        final busWidget = FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: FittedBox(
              fit: BoxFit.fitWidth,
              child: ClipRect(
                child: SizedBox(
                  width: _refW,
                  height: refH,
                  child: _busContentPortrait(),
                ),
              ),
            ),
          ),
        );

        if (scaledH + 24 <= availH) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: busWidget,
            ),
          );
        }
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: busWidget,
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  LANDSCAPE — bus horizontal: viaja de derecha → izquierda
  //  La cabina queda a la DERECHA (frente del bus).
  //  El scroll es HORIZONTAL si el bus no cabe.
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _scrollableBusLandscape() {
    return LayoutBuilder(
      builder: (ctx, bc) {
        final availW = bc.maxWidth;
        final availH = bc.maxHeight;
        final refW = _lRefW();

        // Escala para que el alto del bus quepa en el alto disponible
        final scale = (availH - 32) / _lRefH;
        final scaledW = refW * scale;

        final busWidget = FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: FittedBox(
              fit: BoxFit.fitHeight,
              child: ClipRect(
                child: SizedBox(
                  width: refW,
                  height: _lRefH,
                  child: _busContentLandscape(),
                ),
              ),
            ),
          ),
        );

        if (scaledW + 24 <= availW) {
          // Cabe sin scroll
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: busWidget,
            ),
          );
        }

        // No cabe → scroll horizontal con rebote
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: busWidget,
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  CONTENIDO PORTRAIT (vertical, igual que antes + stagger)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _busContentPortrait() {
    final dis = _dis;
    final norm = _norm;
    final numFilas = (norm.length / 4).ceil();

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _CarroceriaPainter(_casco)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _hPad,
            vertical: _vPad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabina conductor
              SizedBox(
                height: _cabH,
                child: CustomPaint(painter: _CabinaPainter(_casco)),
              ),
              const SizedBox(height: _gap),

              // Fila discapacidad — índice de animación 0
              _filaAnimadaPortrait(
                rowIndex: 0,
                asientos: [
                  dis.isNotEmpty ? dis[0] : null,
                  null,
                  null,
                  dis.length > 1 ? dis[1] : null,
                ],
                labels: [
                  dis.isNotEmpty ? 'D1' : '',
                  '',
                  '',
                  dis.length > 1 ? 'D2' : '',
                ],
              ),
              const SizedBox(height: _gap),

              // Filas normales — índices 1..numFilas
              ...List.generate(numFilas, (fi) {
                const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
                final start = fi * 4;
                final end = min(start + 4, norm.length);
                final row = norm.sublist(start, end).cast<dynamic>();
                while (row.length < 4) row.add(null);
                final l = abc[fi % 26];
                return Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: _filaAnimadaPortrait(
                    rowIndex: fi + 1,
                    asientos: [row[0], row[1], row[2], row[3]],
                    labels: [
                      row[0] != null ? '${l}1' : '',
                      row[1] != null ? '${l}2' : '',
                      row[2] != null ? '${l}3' : '',
                      row[3] != null ? '${l}4' : '',
                    ],
                  ),
                );
              }),

              SizedBox(height: _seatH * 0.5),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  CONTENIDO LANDSCAPE (horizontal)
  //  Layout: [columnas de asientos de izquierda a derecha] → [cabina a la derecha]
  //  El pasajero "sube" por la izquierda y el frente del bus está a la derecha.
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _busContentLandscape() {
    final dis = _dis;
    final norm = _norm;
    final numCols = (norm.length / 4)
        .ceil(); // cada "columna" = lo que era una fila

    return Stack(
      children: [
        // Carrocería horizontal
        Positioned.fill(
          child: CustomPaint(painter: _CarroceriaHPainter(_casco)),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _lVPad,
            vertical: _lHPad,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Columna discapacidad (a la izquierda del todo) ──────────────
              _columnaAnimadaLandscape(
                colIndex: 0,
                asientos: [
                  dis.isNotEmpty ? dis[0] : null,
                  null,
                  null,
                  dis.length > 1 ? dis[1] : null,
                ],
                labels: [
                  dis.isNotEmpty ? 'D1' : '',
                  '',
                  '',
                  dis.length > 1 ? 'D2' : '',
                ],
              ),
              const SizedBox(width: _lGap),

              // ── Columnas normales ───────────────────────────────────────────
              ...List.generate(numCols, (ci) {
                const abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
                final start = ci * 4;
                final end = min(start + 4, norm.length);
                final col = norm.sublist(start, end).cast<dynamic>();
                while (col.length < 4) col.add(null);
                final l = abc[ci % 26];
                return Padding(
                  padding: const EdgeInsets.only(right: _lGap),
                  child: _columnaAnimadaLandscape(
                    colIndex: ci + 1,
                    asientos: [col[0], col[1], col[2], col[3]],
                    labels: [
                      col[0] != null ? '${l}1' : '',
                      col[1] != null ? '${l}2' : '',
                      col[2] != null ? '${l}3' : '',
                      col[3] != null ? '${l}4' : '',
                    ],
                  ),
                );
              }),

              SizedBox(width: _lSeatW * 0.5),

              // ── Cabina conductor (a la derecha = frente del bus) ────────────
              SizedBox(
                width: _lCabW,
                child: CustomPaint(painter: _CabinaHPainter(_casco)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  FILA ANIMADA (portrait) — envuelve una fila en FadeTransition + SlideTransition
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _filaAnimadaPortrait({
    required int rowIndex,
    required List<dynamic> asientos,
    required List<String> labels,
  }) {
    if (rowIndex >= _rowFades.length) {
      return _filaPortrait(asientos, labels);
    }
    return FadeTransition(
      opacity: _rowFades[rowIndex],
      child: SlideTransition(
        position: _rowSlides[rowIndex],
        child: _filaPortrait(asientos, labels),
      ),
    );
  }

  // ── Fila portrait (4 asientos + pasillo) ─────────────────────────────────────
  Widget _filaPortrait(List<dynamic> asientos, List<String> labels) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _asientoW(asientos[0], labels[0]),
        const SizedBox(width: _gap),
        _asientoW(asientos[1], labels[1]),
        const SizedBox(width: _aisleW),
        _asientoW(asientos[2], labels[2]),
        const SizedBox(width: _gap),
        _asientoW(asientos[3], labels[3]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  COLUMNA ANIMADA (landscape) — columna = lo que era fila en portrait
  //  La animación slide ahora viene desde la DERECHA (dirección de marcha)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _columnaAnimadaLandscape({
    required int colIndex,
    required List<dynamic> asientos,
    required List<String> labels,
  }) {
    final col = _columnaLandscape(asientos, labels);

    if (colIndex >= _rowFades.length) return col;

    // En landscape el slide viene desde la derecha
    final slideL =
        Tween<Offset>(begin: const Offset(0.18, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _rowCtrls[colIndex],
            curve: Curves.easeOutCubic,
          ),
        );

    return FadeTransition(
      opacity: _rowFades[colIndex],
      child: SlideTransition(position: slideL, child: col),
    );
  }

  // ── Columna landscape (4 asientos en vertical + pasillo horizontal) ───────────
  Widget _columnaLandscape(List<dynamic> asientos, List<String> labels) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _asientoWL(asientos[0], labels[0]),
        const SizedBox(height: _lGap),
        _asientoWL(asientos[1], labels[1]),
        const SizedBox(height: _lAisleH), // pasillo horizontal
        _asientoWL(asientos[2], labels[2]),
        const SizedBox(height: _lGap),
        _asientoWL(asientos[3], labels[3]),
      ],
    );
  }

  // ── Asiento portrait ─────────────────────────────────────────────────────────
  Widget _asientoW(dynamic a, String etiqueta) {
    if (a == null) return const SizedBox(width: _seatW, height: _seatH);
    final c = _color(a);
    final ocu = _esOcupado(a);
    final n = a['asiento']['numero'] as int;
    final selected = _seleccionados.contains(n);

    return GestureDetector(
      onTap: () => _toggle(a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: _seatW,
        height: _seatH,
        child: CustomPaint(
          painter: _AsientoPainter(color: c, selected: selected, ocupado: ocu),
          child: Align(
            alignment: const Alignment(0, -0.25),
            child: Text(
              etiqueta,
              style: TextStyle(
                color: ocu ? Colors.white54 : Colors.white,
                fontSize: _seatW * 0.20,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Asiento landscape (girado 90°: el respaldo queda a la izquierda) ──────────
  Widget _asientoWL(dynamic a, String etiqueta) {
    if (a == null) return const SizedBox(width: _lSeatW, height: _lSeatH);
    final c = _color(a);
    final ocu = _esOcupado(a);
    final n = a['asiento']['numero'] as int;
    final selected = _seleccionados.contains(n);

    return GestureDetector(
      onTap: () => _toggle(a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: _lSeatW,
        height: _lSeatH,
        // Rotamos el painter 90° para que el asiento mire hacia la derecha
        child: Transform.rotate(
          angle: -pi / 2,
          child: SizedBox(
            width: _lSeatH,
            height: _lSeatW,
            child: CustomPaint(
              painter: _AsientoPainter(
                color: c,
                selected: selected,
                ocupado: ocu,
              ),
              child: Align(
                alignment: const Alignment(0, -0.25),
                child: Text(
                  etiqueta,
                  style: TextStyle(
                    color: ocu ? Colors.white54 : Colors.white,
                    fontSize: _lSeatH * 0.20,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Leyenda ──────────────────────────────────────────────────────────────────
  Widget _leyenda() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _chip(_azul, 'Disponible'),
        _chip(_grisOc, 'Ocupado'),
        _chip(_naranja, 'Seleccionado'),
        _chip(_morado, 'Discapacidad'),
      ],
    ),
  );

  Widget _chip(Color c, String l) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        l,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF555555),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  // ── Botón confirmar ──────────────────────────────────────────────────────────
  Widget _boton() {
    final total = widget.pasajeros.length;
    final listos = _seleccionados.length == total;
    final faltan = total - _seleccionados.length;
    final texto = _seleccionados.isEmpty
        ? 'Selecciona $total asiento${total > 1 ? "s" : ""}'
        : listos
        ? 'Confirmar ${_seleccionados.length} asiento${_seleccionados.length > 1 ? "s" : ""}'
        : 'Faltan $faltan asiento${faltan > 1 ? "s" : ""}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.white,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: listos ? _naranja : _grisOc,
          boxShadow: listos
              ? [
                  BoxShadow(
                    color: _naranja.withOpacity(0.38),
                    blurRadius: 14,
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

  // ── Confirmar ────────────────────────────────────────────────────────────────
  void _confirmar() {
    const descMap = {
      'Adulto': 0,
      'Estudiante': 25,
      'INAPAM': 30,
      'Discapacidad': 15,
    };
    double total = 0;
    final pax = widget.pasajeros.asMap().entries.map((e) {
      final p = Map<String, dynamic>.from(e.value);
      p['asiento_id'] = _seleccionados[e.key];
      p['asiento_etiqueta'] = _etiqueta(_seleccionados[e.key]);
      total += widget.precioPorPasajero * (1 - (descMap[p['tipo']] ?? 0) / 100);
      return p;
    }).toList();

    Navigator.push(
      context,
      AppRoutes.slideLeft(
        PagoScreen(
          viajeId: widget.viajeId,
          pasajeros: pax,
          origenNombre: widget.origenNombre,
          destinoNombre: widget.destinoNombre,
          horaSalida: widget.horaSalida,
          horaLlegada: widget.horaLlegada,
          fechaViaje: widget.fechaViaje,
          montoTotal: total,
          vendedorId: widget.vendedorId,
          tipoUsuario: widget.tipoUsuario,
          datosUsuario: widget.datosUsuario,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  _CarroceriaPainter  —  PORTRAIT (vertical, igual que antes)
// ═════════════════════════════════════════════════════════════════════════════
class _CarroceriaPainter extends CustomPainter {
  final Color color;
  const _CarroceriaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = Radius.circular(22.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );
    canvas.drawLine(
      const Offset(22, 2.5),
      Offset(w - 22, 2.5),
      Paint()
        ..color = color
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );

    final sideP = Paint()..color = color;
    final sw = max(w * 0.036, 4.0);
    final sh = h * 0.058;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.13, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - sw, h * 0.13, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.73, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w - sw, h * 0.73, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
  }

  @override
  bool shouldRepaint(covariant _CarroceriaPainter o) => o.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
//  _CarroceriaHPainter  —  LANDSCAPE (horizontal)
//  Frente del bus a la DERECHA. El "techo" es el borde derecho.
// ═════════════════════════════════════════════════════════════════════════════
class _CarroceriaHPainter extends CustomPainter {
  final Color color;
  const _CarroceriaHPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = Radius.circular(22.0);

    // Fondo blanco
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()..color = Colors.white,
    );

    // Borde exterior
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );

    // "Techo" del bus = borde DERECHO (frente)
    canvas.drawLine(
      Offset(w - 2.5, 22),
      Offset(w - 2.5, h - 22),
      Paint()
        ..color = color
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );

    final sideP = Paint()..color = color;
    final sh = max(h * 0.036, 4.0); // alto de espejos/llantas
    final sw = w * 0.058; // ancho de los salientes

    // Espejos (derecha — frente)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.87, 0, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.87, h - sh, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );

    // Llantas (izquierda — trasera)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h - sh, sw, sh),
        const Radius.circular(3),
      ),
      sideP,
    );
  }

  @override
  bool shouldRepaint(covariant _CarroceriaHPainter o) => o.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
//  _CabinaPainter  —  PORTRAIT (volante, asiento, puerta)
// ═════════════════════════════════════════════════════════════════════════════
class _CabinaPainter extends CustomPainter {
  final Color color;
  const _CabinaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final f = Paint()..color = color;
    final s = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.28, h * 0.03, w * 0.44, h * 0.10),
        const Radius.circular(7),
      ),
      f,
    );

    final cx = w * 0.21;
    final cy = h * 0.40;
    final r = w * 0.072;
    canvas.drawCircle(Offset(cx, cy), r, s);
    canvas.drawCircle(Offset(cx, cy), r * 0.20, f);
    canvas.drawLine(Offset(cx, cy), Offset(cx, cy - r), s);
    canvas.drawLine(Offset(cx, cy), Offset(cx - r * 0.78, cy + r * 0.48), s);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.78, cy + r * 0.48), s);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.10, h * 0.62, w * 0.17, h * 0.20),
        const Radius.circular(4),
      ),
      f,
    );

    for (int i = 0; i < 4; i++) {
      final x = w * 0.72 + i * w * 0.052;
      canvas.drawLine(
        Offset(x, h * 0.46),
        Offset(x, h * 0.78),
        s..strokeWidth = 1.6,
      );
    }
    canvas.drawLine(
      Offset(w * 0.72, h * 0.78),
      Offset(w * 0.93, h * 0.78),
      s..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _CabinaPainter o) => o.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
//  _CabinaHPainter  —  LANDSCAPE (cabina girada 90°, frente a la derecha)
// ═════════════════════════════════════════════════════════════════════════════
class _CabinaHPainter extends CustomPainter {
  final Color color;
  const _CabinaHPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final f = Paint()..color = color;
    final s = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Parabrisas (lado derecho — frente)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.87, h * 0.28, w * 0.10, h * 0.44),
        const Radius.circular(7),
      ),
      f,
    );

    // Volante (rotado: ahora el conductor mira a la derecha)
    final cx = w * 0.60;
    final cy = h * 0.21;
    final r = h * 0.072;
    canvas.drawCircle(Offset(cx, cy), r, s);
    canvas.drawCircle(Offset(cx, cy), r * 0.20, f);
    canvas.drawLine(Offset(cx, cy), Offset(cx + r, cy), s);
    canvas.drawLine(Offset(cx, cy), Offset(cx - r * 0.48, cy - r * 0.78), s);
    canvas.drawLine(Offset(cx, cy), Offset(cx - r * 0.48, cy + r * 0.78), s);

    // Asiento conductor (debajo del volante)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.10, w * 0.20, h * 0.17),
        const Radius.circular(4),
      ),
      f,
    );

    // Puerta / escalones (lado izquierdo de la cabina)
    for (int i = 0; i < 4; i++) {
      final y = h * 0.72 + i * h * 0.052;
      canvas.drawLine(
        Offset(w * 0.22, y),
        Offset(w * 0.54, y),
        s..strokeWidth = 1.6,
      );
    }
    canvas.drawLine(
      Offset(w * 0.22, h * 0.72),
      Offset(w * 0.22, h * 0.93),
      s..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _CabinaHPainter o) => o.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
//  _AsientoPainter  —  mismo para portrait y landscape
//  (en landscape se aplica Transform.rotate externamente)
// ═════════════════════════════════════════════════════════════════════════════
class _AsientoPainter extends CustomPainter {
  final Color color;
  final bool selected;
  final bool ocupado;

  const _AsientoPainter({
    required this.color,
    required this.selected,
    required this.ocupado,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = ocupado ? color.withOpacity(0.42) : color;
    final dark = Color.lerp(
      color,
      Colors.black,
      0.14,
    )!.withOpacity(ocupado ? 0.42 : 1.0);
    final ar = Radius.circular(w * 0.16);

    // Apoyabrazos
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.28, w * 0.15, h * 0.57),
        ar,
      ),
      Paint()..color = dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.85, h * 0.28, w * 0.15, h * 0.57),
        ar,
      ),
      Paint()..color = dark,
    );

    // Respaldo
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.13, 0, w * 0.74, h * 0.76),
      Radius.circular(w * 0.20),
    );
    canvas.drawRRect(body, Paint()..color = base);

    // Cojín
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.09, h * 0.72, w * 0.82, h * 0.25),
        Radius.circular(w * 0.10),
      ),
      Paint()..color = dark,
    );

    // Borde selección
    if (selected) {
      canvas.drawRRect(
        body,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AsientoPainter o) =>
      o.color != color || o.selected != selected || o.ocupado != ocupado;
}
