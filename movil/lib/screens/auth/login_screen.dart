import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../../config.dart';
import '../../utils/transitions.dart';
import '../taquillero/home_screen.dart';
import '../cliente/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _obscurePassword = true;
  bool _cargando = false;
  bool _cargandoGoogle = false;
  bool _cargandoFacebook = false;

  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final usuario = _usuarioController.text.trim();
    final contrasena = _contrasenaController.text.trim();

    if (usuario.isEmpty || contrasena.isEmpty) {
      _mostrarError('Completa todos los campos');
      return;
    }

    setState(() => _cargando = true);

    try {
      // Paso 1: intentar login como taquillero
      final responseTaquillero = await http
          .post(
            Uri.parse('${Config.baseUrl}/api/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'usuario': usuario, 'contrasena': contrasena}),
          )
          .timeout(const Duration(seconds: 10));

      final dataTaquillero = jsonDecode(responseTaquillero.body);

      if (responseTaquillero.statusCode == 200 &&
          dataTaquillero['tipo'] == 'taquillero') {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            AppRoutes.fadeSlideUp(
              HomeNavigationScreen(taquillero: dataTaquillero),
            ),
            (route) => false,
          );
        }
        return;
      }

      // Paso 2: si no es taquillero, intentar login como cliente con Firebase
      // El campo "usuario" en este caso debe ser un correo electrónico
      final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
      if (!emailRegex.hasMatch(usuario)) {
        _mostrarError('Credenciales incorrectas');
        return;
      }

      // Autenticar con Firebase
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: usuario, password: contrasena);

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        _mostrarError('Error al iniciar sesión');
        return;
      }

      // Obtener datos del cliente desde el backend
      final responseCliente = await http
          .post(
            Uri.parse('${Config.baseUrl}/api/cliente/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firebase_uid': firebaseUser.uid,
              'correo': firebaseUser.email,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final dataCliente = jsonDecode(responseCliente.body);

      if (responseCliente.statusCode == 200 && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          AppRoutes.fadeSlideUp(HomeClienteScreen(cliente: dataCliente)),
          (route) => false,
        );
      } else {
        _mostrarError(dataCliente['error'] ?? 'Error al iniciar sesión');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        _mostrarError('Correo o contraseña incorrectos');
      } else if (e.code == 'too-many-requests') {
        _mostrarError('Demasiados intentos. Intenta más tarde.');
      } else if (e.code == 'user-disabled') {
        _mostrarError('Esta cuenta ha sido deshabilitada.');
      } else {
        _mostrarError('Error: ${e.message}');
      }
    } catch (e) {
      _mostrarError('Error de conexión');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Login con Google ───────────────────────────────────────
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
          _mostrarError(data['error'] ?? 'Error al iniciar sesión con Google');
        }
      }
    } catch (e) {
      _mostrarError('Error con Google: $e');
    } finally {
      if (mounted) setState(() => _cargandoGoogle = false);
    }
  }

  // ── Login con Facebook ─────────────────────────────────────
  Future<void> _loginConFacebook() async {
    setState(() => _cargandoFacebook = true);
    try {
      await FacebookAuth.instance.logOut();

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        setState(() => _cargandoFacebook = false);
        return;
      }

      if (result.status != LoginStatus.success) {
        _mostrarError('Error al iniciar sesión con Facebook');
        return;
      }

      final OAuthCredential credential = FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
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
                'correo': user.email ?? '',
                'nombre': user.displayName ?? '',
                'foto': user.photoURL ?? '',
                'proveedor': 'facebook',
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
          _mostrarError(
            data['error'] ?? 'Error al iniciar sesión con Facebook',
          );
        }
      }
    } catch (e) {
      _mostrarError('Error con Facebook: $e');
    } finally {
      if (mounted) setState(() => _cargandoFacebook = false);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                color: azul.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Bienvenido de nuevo',
            style: TextStyle(
              color: Color(0xFF1C2D3A),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inicia sesión con tu cuenta',
            style: TextStyle(color: Color(0xFF6B8FA8), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildInput(
            controller: _usuarioController,
            label: 'Usuario o correo',
            hint: 'tu_usuario o correo@ejemplo.com',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildInput(
            controller: _contrasenaController,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _cargando ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: azul,
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
                      'INICIAR SESIÓN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
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
                            color: Color(0xFF1C2D3A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _cargandoFacebook ? null : _loginConFacebook,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _cargandoFacebook
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.facebook,
                          color: Colors.blue.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continuar con Facebook',
                          style: TextStyle(
                            color: Color(0xFF1C2D3A),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF6B8FA8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          style: const TextStyle(color: Color(0xFF1C2D3A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
            prefixIcon: Icon(icon, color: const Color(0xFF6B8FA8), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF6B8FA8),
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
              borderSide: BorderSide(color: azul.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: azul.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: azul, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
