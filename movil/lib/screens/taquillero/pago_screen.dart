import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'resumen_compra_screen.dart';

class PagoScreen extends StatefulWidget {
  final int viajeId;
  final List<Map<String, dynamic>> pasajeros;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final double montoTotal;
  final int vendedorId;

  const PagoScreen({
    super.key,
    required this.viajeId,
    required this.pasajeros,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    required this.montoTotal,
    required this.vendedorId,
  });

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFF008FD4);

  final _formKey = GlobalKey<FormState>();
  int metodoPago = 2; // 1=Efectivo, 2=Tarjeta
  bool procesando = false;

  // Controladores tarjeta
  final _numeroCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nombreCtrl.dispose();
    _fechaCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarPago() async {
    if (metodoPago == 2 && !_formKey.currentState!.validate()) return;

    setState(() => procesando = true);

    try {
      final contacto = widget.pasajeros.firstWhere(
        (p) => p['esContacto'] == true,
        orElse: () => {},
      );

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
              'correo_contacto': contacto['correo'] ?? '',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResumenCompraScreen(
                pagoId: data['pago_id'],
                origenNombre: widget.origenNombre,
                destinoNombre: widget.destinoNombre,
                horaSalida: widget.horaSalida,
                montoTotal: widget.montoTotal,
                pasajeros: widget.pasajeros,
                metodoPago: metodoPago,
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
                    const SizedBox(height: 20),
                    _buildBotonPagar(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, color: azul, size: 16),
              const SizedBox(width: 6),
              Text(
                widget.origenNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 6),
              const Icon(Icons.location_on_rounded, color: naranja, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.destinoNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                widget.horaSalida,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: azul,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Pasajeros:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Spacer(),
              Text(
                '${widget.pasajeros.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Total a pagar:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '\$${widget.montoTotal.toStringAsFixed(2)} MXN',
                style: const TextStyle(
                  fontSize: 18,
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Método de pago',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
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
                child: _buildOpcionPago(1, Icons.payments_rounded, 'Efectivo'),
              ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: seleccionado ? azul : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? azul : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? Colors.white : Colors.grey.shade600,
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos de tarjeta',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Número de tarjeta
            _buildCampoTarjeta(
              ctrl: _numeroCtrl,
              label: 'Número de tarjeta',
              icono: Icons.credit_card_rounded,
              hint: '0000 0000 0000 0000',
              maxLength: 19,
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
            // Nombre
            _buildCampoTarjeta(
              ctrl: _nombreCtrl,
              label: 'Nombre en la tarjeta',
              icono: Icons.person_outline_rounded,
              hint: 'NOMBRE APELLIDO',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              ],
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Requerido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Fecha y CVV
            Row(
              children: [
                Expanded(
                  child: _buildCampoTarjeta(
                    ctrl: _fechaCtrl,
                    label: 'Fecha vencimiento',
                    icono: Icons.calendar_today_outlined,
                    hint: 'MM/AA',
                    maxLength: 5,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryDateFormatter(),
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Requerido';
                      if (val.length < 5) return 'Fecha inválida';
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
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: TextInputType.number,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icono, size: 18, color: azul),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: azul, width: 1.5),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.payments_rounded,
              color: Colors.green.shade600,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pago en efectivo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Realiza tu pago en taquilla al momento de abordar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPagar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: procesando ? null : _confirmarPago,
        style: ElevatedButton.styleFrom(
          backgroundColor: naranja,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
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
                        : 'Confirmar reserva',
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

// Formateador número de tarjeta: 0000 0000 0000 0000
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

// Formateador fecha vencimiento: MM/AA
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
