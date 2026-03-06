import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _obscurePassword = true;

  static const azul = Color(0xFF2C7FB1);

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
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
            'Accede con tus credenciales de taquillero',
            style: TextStyle(color: Color(0xFF6B8FA8), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildInput(
            controller: _usuarioController,
            label: 'Usuario',
            hint: 'tu_usuario',
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
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: azul,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'INICIAR SESIÓN',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
            prefixIcon: const Icon(
              Icons.person_outline,
              color: Color(0xFF6B8FA8),
              size: 20,
            ),
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
