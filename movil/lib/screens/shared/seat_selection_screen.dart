import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:async';
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

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const morado = Color(0xFF7B2FBE);
  static const gris = Color(0xFF9E9E9E);

  List<dynamic> asientos = [];
  List<int> seleccionados = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarAsientos();
  }

  Future<void> cargarAsientos() async {
    try {
      final response = await http
          .get(Uri.parse('${Config.baseUrl}/api/viajes/${widget.viajeId}/'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = List<dynamic>.from(data['asientos']);
        lista.sort((a, b) {
          final aTipo = a['asiento']['tipo']['codigo'];
          final bTipo = b['asiento']['tipo']['codigo'];
          if (aTipo == 'DIS' && bTipo != 'DIS') return -1;
          if (aTipo != 'DIS' && bTipo == 'DIS') return 1;
          return 0;
        });
        setState(() {
          asientos = lista;
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Error cargando asientos: $e');
      setState(() => cargando = false);
    }
  }

  Color _colorAsiento(Map asiento) {
    final numero = asiento['asiento']['numero'];
    final ocupado = asiento['ocupado'] == 1;
    final tipo = asiento['asiento']['tipo']['codigo'];
    if (seleccionados.contains(numero)) return naranja;
    if (ocupado) return gris;
    if (tipo == 'DIS') return morado;
    return azul;
  }

  void _toggleAsiento(Map asiento) {
    final numero = asiento['asiento']['numero'];
    if (asiento['ocupado'] == 1) return;
    final totalPasajeros = widget.pasajeros.length;
    setState(() {
      if (seleccionados.contains(numero)) {
        seleccionados.remove(numero);
      } else {
        if (seleccionados.length < totalPasajeros) {
          seleccionados.add(numero);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Solo puedes seleccionar $totalPasajeros asiento(s)',
              ),
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

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: azul,
        foregroundColor: Colors.white,
        title: const Text(
          'Seleccionar asiento',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : isLandscape
          ? _buildLandscape()
          : _buildPortrait(),
    );
  }

  Widget _buildPortrait() {
    return Column(
      children: [
        Expanded(child: _buildBusScrollable()),
        _buildLeyenda(),
        _buildBotonConfirmar(),
      ],
    );
  }

  Widget _buildLandscape() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildBusScrollable()),
        SizedBox(
          width: 180,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLeyendaVertical(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildBotonConfirmar(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusScrollable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final numFilas = (asientos.length / 4).ceil();

        double busWidth;
        if (isLandscape) {
          busWidth = min(constraints.maxHeight * 0.85, 280.0);
        } else {
          busWidth = min(constraints.maxWidth * 0.92, 420.0);
        }

        final interiorWidth = busWidth * 0.68;
        double seatSize = interiorWidth / 4.86;
        seatSize = min(seatSize, 54.0);

        final cabinHeight = busWidth * 0.30;
        final seatsHeight = numFilas * (seatSize + 6.0) + 16;
        final busHeight = cabinHeight + seatsHeight + busWidth * 0.19;

        final totalSeatsWidth =
            seatSize * 4 + seatSize * 0.12 * 3 + seatSize * 0.5;
        final horizontalPadding = (busWidth - totalSeatsWidth) / 2;

        final busWidget = CustomPaint(
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
                top: cabinHeight + seatSize * 0.15,
                left: horizontalPadding,
                right: horizontalPadding,
                bottom: 8,
              ),
              child: _buildAsientos(seatSize),
            ),
          ),
        );

        return SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isLandscape
                  ? RotatedBox(quarterTurns: 1, child: busWidget)
                  : busWidget,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAsientos(double seatSize) {
    List<List<dynamic>> filas = [];
    for (int i = 0; i < asientos.length; i += 4) {
      final end = i + 4 > asientos.length ? asientos.length : i + 4;
      final fila = List<dynamic>.from(asientos.sublist(i, end));
      while (fila.length < 4) fila.add(null);
      filas.add(fila);
    }

    return Column(
      children: filas.map((fila) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAsiento(fila[0], seatSize),
              SizedBox(width: seatSize * 0.12),
              _buildAsiento(fila[1], seatSize),
              SizedBox(width: seatSize * 0.5),
              _buildAsiento(fila[2], seatSize),
              SizedBox(width: seatSize * 0.12),
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
    final numero = asiento['asiento']['numero'];
    return GestureDetector(
      onTap: () => _toggleAsiento(asiento),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat, color: Colors.white, size: size * 0.42),
            Text(
              '$numero',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeyenda() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLeyendaItem(azul, 'Disponible'),
          _buildLeyendaItem(gris, 'Ocupado'),
          _buildLeyendaItem(naranja, 'Seleccionado'),
          _buildLeyendaItem(morado, 'Discapacidad'),
        ],
      ),
    );
  }

  Widget _buildLeyendaVertical() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leyenda',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _buildLeyendaItem(azul, 'Disponible'),
          const SizedBox(height: 6),
          _buildLeyendaItem(gris, 'Ocupado'),
          const SizedBox(height: 6),
          _buildLeyendaItem(naranja, 'Seleccionado'),
          const SizedBox(height: 6),
          _buildLeyendaItem(morado, 'Discapacidad'),
        ],
      ),
    );
  }

  Widget _buildLeyendaItem(Color color, String label) {
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
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildBotonConfirmar() {
    final totalPasajeros = widget.pasajeros.length;
    final listos = seleccionados.length == totalPasajeros;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: listos
              ? () {
                  final pasajerosConAsiento = widget.pasajeros
                      .asMap()
                      .entries
                      .map((e) {
                        final p = Map<String, dynamic>.from(e.value);
                        p['asiento_id'] = seleccionados[e.key];
                        return p;
                      })
                      .toList();

                  double montoTotal = 0;
                  final descuentos = {
                    'Adulto': 0,
                    'Estudiante': 25,
                    'INAPAM': 30,
                    'Discapacidad': 15,
                  };
                  for (final p in pasajerosConAsiento) {
                    final descuento = descuentos[p['tipo']] ?? 0;
                    montoTotal +=
                        widget.precioPorPasajero * (1 - descuento / 100);
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PagoScreen(
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
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: naranja,
            disabledBackgroundColor: gris,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            seleccionados.isEmpty
                ? 'Selecciona $totalPasajeros asiento(s)'
                : listos
                ? 'Confirmar ${seleccionados.length} asiento(s)'
                : 'Faltan ${totalPasajeros - seleccionados.length} asiento(s)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class BusPainter extends CustomPainter {
  final double busWidth;
  final double busHeight;
  final double cabinHeight;

  BusPainter({
    required this.busWidth,
    required this.busHeight,
    required this.cabinHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintGray = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..style = PaintingStyle.fill;
    final paintDarkGray = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.fill;
    final paintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final paintBorder = Paint()
      ..color = const Color(0xFF777777)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012;
    final paintYellow = Paint()
      ..color = const Color(0xFFFFCC00)
      ..style = PaintingStyle.fill;
    final paintWheel = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.fill;
    final paintMirrorArm = Paint()
      ..color = const Color(0xFF444444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;

    final wheelW = w * 0.11;
    final wheelH = cabinHeight * 0.60;
    final frontWheelY = cabinHeight * 0.65;
    final innerR = w * 0.04;

    final mirrorArmStartX = w * 0.13;
    final mirrorArmStartY = cabinHeight * 0.30;
    final mirrorArmEndX = w * 0.05;
    final mirrorArmEndY = w * 0.05;
    canvas.drawLine(
      Offset(mirrorArmStartX, mirrorArmStartY),
      Offset(mirrorArmEndX, mirrorArmEndY),
      paintMirrorArm,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          mirrorArmEndX - w * 0.08,
          mirrorArmEndY - w * 0.02,
          w * 0.10,
          w * 0.04,
        ),
        Radius.circular(w * 0.01),
      ),
      paintDarkGray,
    );

    final mirrorArmStartXR = w * 0.87;
    final mirrorArmEndXR = w * 0.95;
    canvas.drawLine(
      Offset(mirrorArmStartXR, mirrorArmStartY),
      Offset(mirrorArmEndXR, mirrorArmEndY),
      paintMirrorArm,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          mirrorArmEndXR - w * 0.02,
          mirrorArmEndY - w * 0.02,
          w * 0.10,
          w * 0.04,
        ),
        Radius.circular(w * 0.01),
      ),
      paintDarkGray,
    );

    final bodyR = w * 0.07;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTRB(w * 0.08, w * 0.04, w * 0.92, h * 0.97),
      topLeft: Radius.circular(bodyR * 2.5),
      topRight: Radius.circular(bodyR * 2.5),
      bottomLeft: Radius.circular(bodyR),
      bottomRight: Radius.circular(bodyR),
    );
    canvas.drawRRect(body, paintGray);
    canvas.drawRRect(body, paintBorder);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.13, w * 0.07, w * 0.87, h * 0.94),
        topLeft: Radius.circular(innerR * 2),
        topRight: Radius.circular(innerR * 2),
        bottomLeft: Radius.circular(innerR * 0.5),
        bottomRight: Radius.circular(innerR * 0.5),
      ),
      paintWhite,
    );

    for (final x in [w * 0.02, w * 0.89]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, frontWheelY, wheelW, wheelH),
          Radius.circular(w * 0.02),
        ),
        paintWheel,
      );
    }

    final rearY = h * 0.83;
    final rearH = wheelH * 1.15;
    final rearW = wheelW * 1.1;
    for (final x in [w * 0.02, w * 0.89]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, rearY, rearW, rearH),
          Radius.circular(w * 0.02),
        ),
        paintWheel,
      );
      final lineX = x < w * 0.5 ? x + rearW * 0.48 : x + rearW * 0.52;
      canvas.drawLine(
        Offset(lineX, rearY + 2),
        Offset(lineX, rearY + rearH - 2),
        Paint()
          ..color = const Color(0xFF666666)
          ..strokeWidth = w * 0.008,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(w * 0.13, w * 0.07, w * 0.87, cabinHeight),
        topLeft: Radius.circular(innerR * 2),
        topRight: Radius.circular(innerR * 2),
      ),
      Paint()..color = const Color(0xFF888888),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, w * 0.055, w * 0.10, w * 0.025),
        Radius.circular(w * 0.008),
      ),
      Paint()..color = const Color(0xFF555555),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.74, w * 0.055, w * 0.10, w * 0.025),
        Radius.circular(w * 0.008),
      ),
      Paint()..color = const Color(0xFF555555),
    );
    canvas.drawCircle(
      Offset(w * 0.42, w * 0.068),
      w * 0.018,
      Paint()..color = const Color(0xFF333333),
    );
    canvas.drawCircle(
      Offset(w * 0.42, w * 0.068),
      w * 0.008,
      Paint()..color = const Color(0xFF666666),
    );

    final steerX = w * 0.67;
    final steerY = (w * 0.07 + cabinHeight) / 2;
    final steerR = min(cabinHeight * 0.38, w * 0.14);

    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR,
      Paint()..color = const Color(0xFF999999),
    );
    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR * 0.72,
      Paint()..color = const Color(0xFF111111),
    );
    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR,
      Paint()
        ..color = const Color(0xFF666666)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015,
    );

    final spokePaint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = w * 0.028
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * pi / 180;
      canvas.drawLine(
        Offset(steerX, steerY),
        Offset(
          steerX + steerR * 0.68 * cos(angle),
          steerY + steerR * 0.68 * sin(angle),
        ),
        spokePaint,
      );
    }
    canvas.drawCircle(
      Offset(steerX, steerY),
      steerR * 0.16,
      Paint()..color = const Color(0xFF777777),
    );

    final seatW = w * 0.20;
    final seatH = cabinHeight * 0.20;
    final seatLeft = steerX - seatW / 2;
    final seatTop = steerY + steerR + cabinHeight * 0.04;
    if (seatTop + seatH < cabinHeight) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(seatLeft, seatTop, seatW, seatH),
          Radius.circular(w * 0.03),
        ),
        paintYellow,
      );
    }

    canvas.drawLine(
      Offset(w * 0.13, cabinHeight),
      Offset(w * 0.87, cabinHeight),
      Paint()
        ..color = const Color(0xFF444444)
        ..strokeWidth = w * 0.008,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.18, h * 0.93, w * 0.64, w * 0.03),
        Radius.circular(w * 0.01),
      ),
      Paint()..color = const Color(0xFF888888),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
