import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/taquillero/home_screen.dart';
import 'screens/invitado/home_screen.dart';
import 'utils/transitions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rutas Baja Express',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const naranja = Color(0xFFE9713A);

  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

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
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: isLandscape
                      ? _buildLandscape(context)
                      : _buildPortrait(context, isTablet),
                ),
              ),
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
            SizedBox(height: screenHeight * 0.37),
            _buildLogo(),
            const SizedBox(height: 24),
            _buildTitle(),
            const SizedBox(height: 24),
            const _AnimatedBusRoute(),
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
                  const _AnimatedBusRoute(),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (_, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
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
      ),
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

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AnimatedButton(
                onTap: () => _showBottomSheet(context, const LoginScreen()),
                isOutlined: true,
                label: 'Sign In',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnimatedButton(
                onTap: () => _showBottomSheet(context, const SignupScreen()),
                isOutlined: false,
                label: 'Sign Up',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: AnimatedTapButton(
            onTap: () {
              Navigator.push(
                context,
                AppRoutes.fadeSlideUp(const HomeInvitadoScreen()),
              );
            },
            scaleFactor: 0.97,
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

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isOutlined;
  final String label;

  const _AnimatedButton({
    required this.onTap,
    required this.isOutlined,
    required this.label,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  static const naranja = Color(0xFFE9713A);
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.isOutlined
            ? OutlinedButton(
                onPressed: widget.onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(widget.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            : ElevatedButton(
                onPressed: widget.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: naranja,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: naranja.withOpacity(0.45),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(widget.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }
}

class _AnimatedBusRoute extends StatefulWidget {
  const _AnimatedBusRoute();

  @override
  State<_AnimatedBusRoute> createState() => _AnimatedBusRouteState();
}

class _AnimatedBusRouteState extends State<_AnimatedBusRoute>
    with SingleTickerProviderStateMixin {
  static const naranja = Color(0xFFE9713A);
  late AnimationController _ctrl;
  late Animation<double> _pos;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pos = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: 26,
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 12,
                    child: Container(
                      width: w * 0.36,
                      height: 2,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [naranja, Colors.white],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 12,
                    child: Container(
                      width: w * 0.36,
                      height: 2,
                      color: Colors.white54,
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    top: 8,
                    child: CircleAvatar(radius: 5, backgroundColor: naranja),
                  ),
                  const Positioned(
                    right: 0,
                    top: 8,
                    child: CircleAvatar(
                        radius: 5, backgroundColor: Colors.white),
                  ),
                  AnimatedBuilder(
                    animation: _pos,
                    builder: (_, __) {
                      return Positioned(
                        left: 4 + _pos.value * (w - 36),
                        top: 3,
                        child: const Text('🚌',
                            style: TextStyle(fontSize: 20)),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tijuana',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
            Text('La Paz',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
