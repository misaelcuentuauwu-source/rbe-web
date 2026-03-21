import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';

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

  // Color dinámico según tipo de usuario
  Color get colorPrimario =>
      widget.tipoUsuario == 'taquillero' ? naranja : azul;
  Color get colorSecundario =>
      widget.tipoUsuario == 'taquillero' ? azul : naranja;

  final _folioCtrl = TextEditingController();
  Map<String, dynamic>? boleto;
  bool cargando = false;
  String? error;

  @override
  void dispose() {
    _folioCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final folio = _folioCtrl.text.trim();
    if (folio.isEmpty) return;

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
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  String _formatHora(String fecha) {
    final dt = DateTime.parse(fecha);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tipoUsuario == 'invitado') {
      return _buildInvitado();
    }
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

  // ── Pantalla invitado ──────────────────────────────────────────────────────

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
                          letterSpacing: 0.3,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
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
                        '¿Cómo recuperar tus boletos?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Como usuario invitado, no es posible consultar tus boletos desde la app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: textoSecundario,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildPaso(
                              numero: '1',
                              texto:
                                  'Dirígete a cualquier taquilla de Rutas Baja Express.',
                            ),
                            const SizedBox(height: 16),
                            _buildPaso(
                              numero: '2',
                              texto:
                                  'Presenta tu identificación oficial al taquillero.',
                            ),
                            const SizedBox(height: 16),
                            _buildPaso(
                              numero: '3',
                              texto:
                                  'El taquillero buscará y te entregará tus boletos.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: naranja.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: naranja.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: naranja,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Crea una cuenta para acceder a tus boletos en cualquier momento.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: naranja,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildPaso({required String numero, required String texto}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: azul, shape: BoxShape.circle),
          child: Center(
            child: Text(
              numero,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                color: textoPrincipal,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Pantalla taquillero/cliente ────────────────────────────────────────────

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
          const Column(
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
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatHora(viaje['hora_salida']),
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
              _formatFecha(viaje['hora_salida']),
              style: TextStyle(fontSize: 11, color: textoSecundario),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),
            Row(
              children: [
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
                  ],
                ),
                const Spacer(),
                Text(
                  '${tickets.length} pasajero(s)',
                  style: TextStyle(fontSize: 12, color: textoSecundario),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                          '${t['asiento']}',
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
                      '\$${double.parse(t['precio']).toStringAsFixed(2)}',
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
                  '\$${double.parse(boleto!['monto']).toStringAsFixed(2)} MXN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorSecundario,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Próximamente: impresión de boletos'),
                      backgroundColor: colorPrimario,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorPrimario,
                  side: BorderSide(color: colorPrimario, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 20),
                label: const Text(
                  'Imprimir boletos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
