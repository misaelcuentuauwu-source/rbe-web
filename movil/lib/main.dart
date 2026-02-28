import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rutas Baja Express',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const azul = Color(0xFF2C7FB1);
  static const azulOscuro = Color(0xFF1C5278);
  static const naranja = Color(0xFFE9713A);

  void _showBottomSheet(BuildContext context, Widget screen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.75,
        builder: (_, controller) =>
            SingleChildScrollView(controller: controller, child: screen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          return Container(
            color: const Color(0xFF008FD4),
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/fondo.png'),
                  fit: BoxFit.fitWidth,
                  alignment: isLandscape
                      ? Alignment.centerLeft
                      : isTablet
                      ? const Alignment(0.0, -2.0)
                      : Alignment.topCenter,
                ),
              ),
              child: isLandscape
                  ? _buildLandscape(context)
                  : _buildPortrait(context, isTablet),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortrait(BuildContext context, bool isTablet) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: screenHeight * 0.37), // 45% de la pantalla
            _buildLogo(),
            const SizedBox(height: 24),
            _buildTitle(),
            const SizedBox(height: 24),
            _buildRutaVisual(),
            const Spacer(),
            _buildButtons(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscape(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 16),
                  _buildTitle(),
                  const SizedBox(height: 24),
                  _buildRutaVisual(),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildButtons(context)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: naranja,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: naranja.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.directions_bus, color: Colors.white, size: 40),
    );
  }

  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rutas Baja\nExpress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Tu sistema de viajes en\nBaja California',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildRutaVisual() {
    return Column(
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 5, backgroundColor: naranja),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [naranja, Colors.white]),
                ),
              ),
            ),
            const Text('🚌', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white54,
              ),
            ),
            const CircleAvatar(radius: 5, backgroundColor: Colors.white),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tijuana',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Text(
              'La Paz',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showBottomSheet(context, const LoginScreen()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    _showBottomSheet(context, const SignupScreen()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: naranja,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              'Entrar como invitado',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white60,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
