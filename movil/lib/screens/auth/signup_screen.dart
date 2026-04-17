import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/transitions.dart';
import '../cliente/home_screen.dart';
import 'package:flutter/services.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _telefonoController = TextEditingController(); // ← NUEVO
  DateTime? _fechaNacimiento; // ← NUEVO: fecha de nacimiento del cliente
  bool _obscurePassword = true;
  bool _cargando = false;
  bool _cargandoGoogle = false;

  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _telefonoController.dispose();
    super.dispose();
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

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Formatea la fecha para mostrarla en el botón ─────────────────────────
  String _formatearFecha(DateTime? fn) {
    if (fn == null) return 'Selecciona tu fecha de nacimiento';
    return '${fn.day.toString().padLeft(2, '0')}/'
        '${fn.month.toString().padLeft(2, '0')}/'
        '${fn.year}';
  }

  // ── Calcula la edad a partir de la fecha ─────────────────────────────────
  int? _calcularEdad(DateTime? fn) {
    if (fn == null) return null;
    final hoy = DateTime.now();
    int edad = hoy.year - fn.year;
    if (hoy.month < fn.month || (hoy.month == fn.month && hoy.day < fn.day)) {
      edad--;
    }
    return edad;
  }

  // ── Abre el DatePicker para fecha de nacimiento ──────────────────────────
  Future<void> _seleccionarFechaNacimiento() async {
    final hoy = DateTime.now();
    // El cliente debe ser mayor de edad (>= 18) para crear cuenta
    final fechaMax = DateTime(hoy.year - 18, hoy.month, hoy.day);
    final fechaMin = DateTime(hoy.year - 120, hoy.month, hoy.day);
    final fechaInicial =
        _fechaNacimiento ?? DateTime(hoy.year - 25, hoy.month, hoy.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: fechaInicial.isBefore(fechaMax) ? fechaInicial : fechaMax,
      firstDate: fechaMin,
      lastDate: fechaMax,
      locale: const Locale('es', 'MX'),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: azul,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textoPrincipal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _registrarse() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (nombre.isEmpty ||
        apellido.isEmpty ||
        correo.isEmpty ||
        contrasena.isEmpty ||
        telefono.isEmpty) {
      _mostrarError('Completa todos los campos');
      return;
    }
    if (telefono.length < 10) {
      _mostrarError('El teléfono debe tener 10 dígitos');
      return;
    }
    if (_fechaNacimiento == null) {
      _mostrarError('Selecciona tu fecha de nacimiento');
      return;
    }

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(correo)) {
      _mostrarError('Ingresa un correo electrónico válido');
      return;
    }
    if (contrasena.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    final edad = _calcularEdad(_fechaNacimiento);
    if (edad == null || edad < 18) {
      _mostrarError('Debes tener al menos 18 años para crear una cuenta');
      return;
    }

    setState(() => _cargando = true);

    final fn = _fechaNacimiento!;
    final fnStr =
        '${fn.year}-${fn.month.toString().padLeft(2, '0')}-${fn.day.toString().padLeft(2, '0')}';

    try {
      // Directo al backend, sin Firebase
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/api/cliente/registro/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nombre': nombre,
              'apellido': apellido,
              'correo': correo,
              'contrasena': contrasena,
              'fecha_nacimiento': fnStr,
              'telefono': telefono,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _mostrarExito('Cuenta creada exitosamente');
          Navigator.pop(context);
        }
      } else {
        _mostrarError(data['error'] ?? 'Error al registrarse');
      }
    } catch (e) {
      _mostrarError('Error de conexión');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _loginConGoogle() async {
    setState(() => _cargandoGoogle = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _cargandoGoogle = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null && mounted) {
        final response = await http
            .post(
              Uri.parse('${Config.baseUrl}/api/cliente/google-login/'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'firebase_uid': user.uid,
                'correo': user.email,
                'nombre': user.displayName ?? '',
                'foto': user.photoURL ?? '',
                'proveedor': 'google',
                // Google no provee fecha de nacimiento; se deja en blanco
                // para que el usuario la complete en su perfil si lo desea.
              }),
            )
            .timeout(const Duration(seconds: 10));

        final data = jsonDecode(response.body);
        if (response.statusCode == 200 && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            AppRoutes.fadeSlideUp(HomeClienteScreen(cliente: data)),
            (route) => false,
          );
        } else {
          _mostrarError(data['error'] ?? 'Error al registrarse con Google');
        }
      }
    } catch (e) {
      _mostrarError('Error con Google: $e');
    } finally {
      if (mounted) setState(() => _cargandoGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edad = _calcularEdad(_fechaNacimiento);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: naranja.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Crear cuenta',
            style: TextStyle(
              color: textoPrincipal,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Regístrate como pasajero',
            style: TextStyle(color: textoSecundario, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // ── Nombre + Apellido ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _nombreController,
                  label: 'Nombre',
                  hint: 'María',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _apellidoController,
                  label: 'Apellido',
                  hint: 'García',
                  icon: Icons.person_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Correo ────────────────────────────────────────
          _buildInput(
            controller: _correoController,
            label: 'Correo',
            hint: 'm.garcia@correo.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // ── Contraseña ────────────────────────────────────
          _buildInput(
            controller: _contrasenaController,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 16),

          // ── Fecha de nacimiento ───────────────────────────
          Text(
            'FECHA DE NACIMIENTO',
            style: TextStyle(
              color: textoSecundario,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          InkWell(
            onTap: _seleccionarFechaNacimiento,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _fechaNacimiento == null
                      ? naranja.withOpacity(0.3)
                      : azul.withOpacity(0.5),
                  width: _fechaNacimiento == null ? 1 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, color: textoSecundario, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatearFecha(_fechaNacimiento),
                      style: TextStyle(
                        color: _fechaNacimiento == null
                            ? const Color(0xFFB0BEC5)
                            : textoPrincipal,
                        fontSize: 14,
                        fontWeight: _fechaNacimiento != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  // Muestra la edad calculada
                  if (edad != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: azul.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$edad años',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: azul,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.calendar_month_rounded,
                    color: _fechaNacimiento != null
                        ? azul
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Mensaje de ayuda
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              'Debes tener 18 años o más para crear una cuenta.',
              style: TextStyle(fontSize: 11, color: textoSecundario),
            ),
          ),
          const SizedBox(height: 16),
          _buildInput(
            controller: _telefonoController,
            label: 'Teléfono',
            hint: '6641234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // solo números
              LengthLimitingTextInputFormatter(10), // máximo 10 dígitos
            ],
          ),
          const SizedBox(height: 28),

          // ── Botón Registrarse ─────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _cargando ? null : _registrarse,
              style: ElevatedButton.styleFrom(
                backgroundColor: naranja,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _cargando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'REGISTRARSE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Divider "o continúa con" ──────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'o continúa con',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Google ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _cargandoGoogle ? null : _loginConGoogle,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _cargandoGoogle
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.google.com/favicon.ico',
                          height: 20,
                          width: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.g_mobiledata, size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continuar con Google',
                          style: TextStyle(
                            color: textoPrincipal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: textoSecundario,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: textoPrincipal),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
            prefixIcon: Icon(icon, color: textoSecundario, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: textoSecundario,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF0F4F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: naranja.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: naranja.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: naranja, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
