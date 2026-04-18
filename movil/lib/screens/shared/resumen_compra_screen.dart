import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // se usa en _buildExito para el correo
import 'package:printing/printing.dart'; // se usa en _imprimirBoleto
import '../taquillero/home_screen.dart';
import '../cliente/home_screen.dart';
import '../invitado/home_screen.dart';
import '../../main.dart';
import '../../config.dart';
import '../../utils/pdf_boleto.dart';
import 'dart:typed_data';

class ResumenCompraScreen extends StatefulWidget {
  final int pagoId;
  final String origenNombre;
  final String destinoNombre;
  final String horaSalida;
  final String horaLlegada;
  final String fechaViaje;
  final double montoTotal;
  final List<Map<String, dynamic>> pasajeros;
  final int metodoPago;
  final String tipoUsuario;
  final Map<String, dynamic>? datosUsuario;

  const ResumenCompraScreen({
    super.key,
    required this.pagoId,
    required this.origenNombre,
    required this.destinoNombre,
    required this.horaSalida,
    this.horaLlegada = '',
    this.fechaViaje = '',
    required this.montoTotal,
    required this.pasajeros,
    required this.metodoPago,
    this.tipoUsuario = 'taquillero',
    this.datosUsuario,
  });

  @override
  State<ResumenCompraScreen> createState() => _ResumenCompraScreenState();
}

class _ResumenCompraScreenState extends State<ResumenCompraScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  Color get colorPrimario =>
      widget.tipoUsuario == 'taquillero' ? naranja : azul;

  static const Map<String, int> _descuentos = {
    'Adulto': 0,
    'Estudiante': 25,
    'INAPAM': 30,
    'Discapacidad': 15,
  };

  bool _imprimiendo = false;

  Future<Uint8List> _generarPdf() async {
    return PdfBoleto.generar(
      pagoId: widget.pagoId,
      origenNombre: widget.origenNombre,
      destinoNombre: widget.destinoNombre,
      horaSalida: widget.horaSalida,
      horaLlegada: widget.horaLlegada,
      fechaViaje: widget.fechaViaje,
      montoTotal: widget.montoTotal,
      pasajeros: widget.pasajeros,
      metodoPago: widget.metodoPago,
    );
  }

  Future<void> _imprimirBoleto() async {
    setState(() => _imprimiendo = true);
    try {
      final pdfBytes = await _generarPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Boleto_Folio_${widget.pagoId}.pdf',
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
      if (mounted) setState(() => _imprimiendo = false);
    }
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    _buildExito(),
                    const SizedBox(height: 16),
                    _buildResumenViaje(),
                    const SizedBox(height: 16),
                    _buildListaPasajeros(),
                    const SizedBox(height: 16),
                    _buildResumenPago(),
                    const SizedBox(height: 24),
                    _buildBotones(context),
                    const SizedBox(height: 20),
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
              Icons.confirmation_number_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compra confirmada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tu boleto ha sido generado',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExito() {
    final contacto = widget.pasajeros.firstWhere(
      (p) => p['esContacto'] == true,
      orElse: () => {},
    );
    final correo = contacto['correo']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '¡Pago exitoso!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Folio de compra #${widget.pagoId}',
            style: TextStyle(fontSize: 13, color: textoSecundario),
          ),
          if (correo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorPrimario.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_rounded,
                    color: colorPrimario,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Boleto enviado a $correo',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorPrimario,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenViaje() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: colorPrimario,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Detalles del viaje',
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
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorPrimario,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(width: 2, height: 30, color: Colors.grey.shade300),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: naranja,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.origenNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.destinoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                widget.horaSalida,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colorPrimario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListaPasajeros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: colorPrimario,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pasajeros',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.pasajeros.length} boleto(s)',
                style: TextStyle(fontSize: 12, color: textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.pasajeros.asMap().entries.map((entry) {
            final index = entry.key;
            final p = entry.value;
            final esContacto = p['esContacto'] as bool? ?? false;
            final tipo = p['tipo'] as String? ?? 'Adulto';
            final descuento =
                p['descuento'] as int? ?? (_descuentos[tipo] ?? 0);
            final precioUnitario = p['precio_unitario'] as double?;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorPrimario.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorPrimario,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${p['nombre']} ${p['primer_apellido']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textoPrincipal,
                              ),
                            ),
                            if (esContacto) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: naranja.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Contacto',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: naranja,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$tipo · Asiento ${p['asiento_etiqueta'] ?? p['asiento_id']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (precioUnitario != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (descuento > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-$descuento%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${precioUnitario.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: naranja,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResumenPago() {
    double subtotalSinDescuento = 0;
    double totalConDescuento = 0;

    for (final p in widget.pasajeros) {
      final precioUnitario = p['precio_unitario'] as double?;
      final descuento = p['descuento'] as int? ?? 0;
      if (precioUnitario != null) {
        totalConDescuento += precioUnitario;
        if (descuento > 0) {
          subtotalSinDescuento += precioUnitario / (1 - descuento / 100);
        } else {
          subtotalSinDescuento += precioUnitario;
        }
      }
    }

    final ahorro = subtotalSinDescuento - totalConDescuento;
    final hayDescuentos = ahorro > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                'Resumen de pago',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                widget.metodoPago == 2
                    ? Icons.credit_card_rounded
                    : Icons.payments_rounded,
                color: colorPrimario,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.metodoPago == 2
                    ? 'Tarjeta de crédito/débito'
                    : 'Efectivo en taquilla',
                style: const TextStyle(fontSize: 13, color: textoPrincipal),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 10),
          if (hayDescuentos) ...[
            Row(
              children: [
                Text(
                  'Subtotal:',
                  style: TextStyle(fontSize: 13, color: textoSecundario),
                ),
                const Spacer(),
                Text(
                  '\$${subtotalSinDescuento.toStringAsFixed(2)} MXN',
                  style: TextStyle(
                    fontSize: 13,
                    color: textoSecundario,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Descuentos aplicados:',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade600),
                ),
                const Spacer(),
                Text(
                  '- \$${ahorro.toStringAsFixed(2)} MXN',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: Colors.grey.shade100),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              const Text(
                'Total pagado:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textoPrincipal,
                ),
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
          if (hayDescuentos) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.savings_rounded,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '¡Ahorraste \$${ahorro.toStringAsFixed(2)} MXN con descuentos!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotones(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _imprimiendo ? null : _imprimirBoleto,
            style: ElevatedButton.styleFrom(
              backgroundColor: azul,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: azul.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            icon: _imprimiendo
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
              _imprimiendo ? 'Generando PDF...' : 'Imprimir / Guardar PDF',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                AppRoutes.fadeSlideUp(() {
                  if (widget.tipoUsuario == 'taquillero' &&
                      widget.datosUsuario != null) {
                    return HomeNavigationScreen(
                      taquillero: widget.datosUsuario!,
                    );
                  } else if (widget.tipoUsuario == 'cliente' &&
                      widget.datosUsuario != null) {
                    return HomeClienteScreen(cliente: widget.datosUsuario!);
                  } else {
                    return const HomeInvitadoScreen();
                  }
                }()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: naranja,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: naranja.withOpacity(0.4),
            ),
            icon: const Icon(Icons.home_rounded),
            label: const Text(
              'Volver al inicio',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
