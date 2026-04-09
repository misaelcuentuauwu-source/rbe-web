import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'resumen_compra_screen.dart';
// Imports a agregar
import 'dart:convert';
import '../../utils/pdf_boleto.dart';

class PagoScreen extends StatefulWidget {
  final int viajeId;
  final List<Map<String, dynamic>> pasajeros;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final String horaLlegada;
  final String fechaViaje;
  final double montoTotal;
  final int vendedorId;
  final String tipoUsuario;
  final Map<String, dynamic>? datosUsuario;

  const PagoScreen({
    super.key,
    required this.viajeId,
    required this.pasajeros,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    this.horaLlegada = '',
    this.fechaViaje = '',
    required this.montoTotal,
    required this.vendedorId,
    this.tipoUsuario = 'invitado',
    this.datosUsuario,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  final _formKey = GlobalKey<FormState>();
  int metodoPago = 2;
  bool procesando = false;

  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _efectivoCtrl = TextEditingController();

  double get _cambio {
    final recibido = double.tryParse(_efectivoCtrl.text) ?? 0;
    return recibido - widget.montoTotal;
  }

  @override
  void initState() {
    super.initState();
    if (widget.tipoUsuario != 'taquillero') {
      metodoPago = 2;
    }
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    _fechaCtrl.dispose();
    _cvvCtrl.dispose();
    _efectivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarPago() async {
    if (metodoPago == 2 && !_formKey.currentState!.validate()) return;

    if (metodoPago == 1) {
      final recibido = double.tryParse(_efectivoCtrl.text) ?? 0;
      if (recibido < widget.montoTotal) {
        _mostrarError('El monto recibido es insuficiente');
        return;
      }
    }

    setState(() => procesando = true);
    try {
      final contacto = widget.pasajeros.firstWhere(
        (p) => p['esContacto'] == true,
        orElse: () => {},
      );
      final correo = contacto['correo'] ?? '';

      // 1. Primero hacer el POST sin pdf_base64
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/api/comprar/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'viaje_id': widget.viajeId,
              'tipo_pago': metodoPago,
              'monto_total': widget.montoTotal,
              'pasajeros': widget.pasajeros,
              'vendedor_id': widget.vendedorId,
              'correo_contacto': correo,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final pagoId = data['pago_id'];

        // 2. Ya con el pago_id real, generar el PDF y mandarlo
        if (correo.isNotEmpty) {
          try {
            final pdfBytes = await PdfBoleto.generar(
              pagoId: pagoId, // ← ahora sí es el número real
              origenNombre: widget.origenNombre,
              destinoNombre: widget.destinoNombre,
              horaSalida: widget.horaSalida,
              horaLlegada: widget.horaLlegada,
              fechaViaje: widget.fechaViaje,
              montoTotal: widget.montoTotal,
              pasajeros: widget.pasajeros,
              metodoPago: metodoPago,
            );
            final pdfBase64 = base64Encode(pdfBytes);

            // 3. Mandar el PDF al backend para adjuntarlo al correo
            await http
                .post(
                  Uri.parse(
                    '${Config.baseUrl}/api/boleto/$pagoId/adjuntar_pdf/',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'correo': correo, 'pdf_base64': pdfBase64}),
                )
                .timeout(const Duration(seconds: 30));
          } catch (e) {
            debugPrint('Error enviando PDF por correo: $e');
            // No interrumpimos el flujo si falla el correo
          }
        }

        // 4. Navegar a resumen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            AppRoutes.slideLeft(
              ResumenCompraScreen(
                pagoId: pagoId,
                origenNombre: widget.origenNombre,
                destinoNombre: widget.destinoNombre,
                horaSalida: widget.horaSalida,
                horaLlegada: widget.horaLlegada,
                fechaViaje: widget.fechaViaje,
                montoTotal: widget.montoTotal,
                pasajeros: widget.pasajeros,
                metodoPago: metodoPago,
                tipoUsuario: widget.tipoUsuario,
                datosUsuario: widget.datosUsuario,
              ),
            ),
          );
        }
      } else {
        final error = jsonDecode(response.body);
        _mostrarError(error['error'] ?? 'Error al procesar el pago');
      }
    } catch (e) {
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => procesando = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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
                    _buildResumen(),
                    const SizedBox(height: 16),
                    _buildSelectorMetodo(),
                    const SizedBox(height: 16),
                    if (metodoPago == 2) _buildFormTarjeta(),
                    if (metodoPago == 1) _buildEfectivo(),
                    const SizedBox(height: 24),
                    _buildBotonPagar(),
                    const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: azul,
        boxShadow: [
          BoxShadow(
            color: azul.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Método de pago',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Confirma tu compra',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                'Resumen de compra',
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
              const Icon(Icons.trip_origin_rounded, color: azul, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.origenNombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textoPrincipal,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: textoSecundario,
                size: 14,
              ),
              const SizedBox(width: 6),
              const Icon(Icons.location_on_rounded, color: naranja, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.destinoNombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textoPrincipal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: azul.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.horaSalida,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: azul,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                'Pasajeros',
                style: TextStyle(fontSize: 13, color: textoSecundario),
              ),
              const Spacer(),
              Text(
                '${widget.pasajeros.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.attach_money_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              const Text(
                'Total a pagar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textoPrincipal,
                ),
              ),
              const Spacer(),
              Text(
                '\$${widget.montoTotal.toStringAsFixed(2)} MXN',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: naranja,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorMetodo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                'Método de pago',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.tipoUsuario == 'taquillero')
            Row(
              children: [
                Expanded(
                  child: _buildOpcionPago(
                    2,
                    Icons.credit_card_rounded,
                    'Tarjeta',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOpcionPago(
                    1,
                    Icons.payments_rounded,
                    'Efectivo',
                  ),
                ),
              ],
            )
          else
            _buildOpcionPago(2, Icons.credit_card_rounded, 'Tarjeta'),
        ],
      ),
    );
  }

  Widget _buildOpcionPago(int tipo, IconData icono, String label) {
    final seleccionado = metodoPago == tipo;
    return GestureDetector(
      onTap: () => setState(() => metodoPago = tipo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: seleccionado ? azul : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? azul : Colors.grey.shade200,
            width: seleccionado ? 2 : 1,
          ),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: azul.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? Colors.white : Colors.grey.shade500,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: seleccionado ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTarjeta() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                  'Datos de tarjeta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textoPrincipal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCampoTarjeta(
              ctrl: _numeroCtrl,
              label: 'Número de tarjeta',
              icono: Icons.credit_card_rounded,
              hint: '0000 0000 0000 0000',
              maxLength: 19,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
              validator: (val) {
                if (val == null || val.isEmpty) return 'Requerido';
                if (val.replaceAll(' ', '').length < 16)
                  return 'Número inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildCampoTarjeta(
              ctrl: _nombreCtrl,
              label: 'Nombre en la tarjeta',
              icono: Icons.person_outline_rounded,
              hint: 'NOMBRE APELLIDO',
              keyboardType: TextInputType.text,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Requerido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCampoTarjeta(
                    ctrl: _fechaCtrl,
                    label: 'Vencimiento',
                    icono: Icons.calendar_today_outlined,
                    hint: 'MM/AA',
                    maxLength: 5,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryDateFormatter(),
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Requerido';
                      if (val.length < 5) return 'Inválida';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCampoTarjeta(
                    ctrl: _cvvCtrl,
                    label: 'CVV',
                    icono: Icons.lock_outline_rounded,
                    hint: '000',
                    maxLength: 3,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Requerido';
                      if (val.length < 3) return 'CVV inválido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoTarjeta({
    required TextEditingController ctrl,
    required String label,
    required IconData icono,
    required String hint,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: textoSecundario),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 13),
        prefixIcon: Icon(icono, size: 18, color: azul),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azul, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildEfectivo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.payments_rounded,
                  color: Colors.green.shade600,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pago en efectivo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total a cobrar: \$${widget.montoTotal.toStringAsFixed(2)} MXN',
                      style: TextStyle(fontSize: 12, color: textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 16),
          TextField(
            controller: _efectivoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Cantidad recibida',
              labelStyle: const TextStyle(fontSize: 13, color: textoSecundario),
              prefixIcon: const Icon(
                Icons.attach_money_rounded,
                color: azul,
                size: 20,
              ),
              prefixText: '\$ ',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: azul, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cambio >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _cambio >= 0
                    ? Colors.green.shade200
                    : Colors.red.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _cambio >= 0
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: _cambio >= 0
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _cambio >= 0
                      ? 'Cambio: \$${_cambio.toStringAsFixed(2)} MXN'
                      : 'Monto insuficiente',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _cambio >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPagar() {
    final bool efectivoValido = metodoPago == 1 && _cambio >= 0;
    final bool botonActivo = metodoPago == 2 || efectivoValido;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: procesando || !botonActivo ? null : _confirmarPago,
        style: ElevatedButton.styleFrom(
          backgroundColor: naranja,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          shadowColor: naranja.withOpacity(0.4),
        ),
        child: procesando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    metodoPago == 2
                        ? 'Pagar \$${widget.montoTotal.toStringAsFixed(2)} MXN'
                        : 'Confirmar pago en efectivo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digitsOnly[i]);
    }
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digitsOnly[i]);
    }
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
