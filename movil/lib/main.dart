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

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late AnimationController _orientationController;
  late Animation<double> _orientationFade;
  late Animation<Offset> _orientationSlide;

  bool _wasLandscape = false;

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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    _entryController.forward();

    _orientationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _orientationFade = CurvedAnimation(
      parent: _orientationController,
      curve: Curves.easeOut,
    );
    _orientationSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _orientationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _orientationController.value = 1.0;
  }

  @override
  void dispose() {
    _entryController.dispose();
    _orientationController.dispose();
    super.dispose();
  }

  void _triggerOrientationAnim(bool isLandscape) {
    if (isLandscape != _wasLandscape) {
      _wasLandscape = isLandscape;
      _orientationController.forward(from: 0.0);
    }
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
      // resizeToAvoidBottomInset: true (default) — permite que el teclado
      // empuje el contenido hacia arriba sin tapar campos de texto.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final isTablet = constraints.maxWidth > 600;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerOrientationAnim(isLandscape);
          });

          return Container(
            color: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/images/fondo.png'),
                  fit: isLandscape ? BoxFit.cover : BoxFit.fitWidth,
                  alignment: isLandscape
                      ? Alignment.centerRight
                      : isTablet
                      ? const Alignment(0.0, -2.0)
                      : Alignment.topCenter,
                ),
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _orientationFade,
                    child: SlideTransition(
                      position: _orientationSlide,
                      child: isLandscape
                          ? _buildLandscape(context)
                          : _buildPortrait(context, isTablet),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Portrait ──────────────────────────────────────────────────────────────

  Widget _buildPortrait(BuildContext context, bool isTablet) {
    return SafeArea(
      // bottom:false para que la ola de fondo llegue hasta el borde inferior
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight +
              MediaQuery.of(context).padding.bottom;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: screenHeight * 0.65,
                child: CustomPaint(
                  painter: _WavePainter(color: const Color(0xFF2C7FB1)),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                bottom: 70 + MediaQuery.of(context).padding.bottom,
                left: 32,
                right: 32,
                child: _buildButtons(context, isLandscape: false),
              ),
              Positioned(
                top: screenHeight * 0.36,
                left: 32,
                right: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LogoIcon(),
                    const SizedBox(height: 20),
                    _buildTitle(isLandscape: false),
                    const SizedBox(height: 20),
                    const _AnimatedBusRoute(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Landscape ─────────────────────────────────────────────────────────────

  Widget _buildLandscape(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradiente izquierdo: oscurece el fondo para legibilidad del texto
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xCC1A5276), Color(0x001A5276)],
                    ),
                  ),
                ),
              ),
              const Expanded(flex: 5, child: SizedBox()),
            ],
          ),
        ),

        // Gradiente derecho: fondo oscuro para los botones
        Positioned.fill(
          child: Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Color(0xDD1B2A3B), Color(0x001B2A3B)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Contenido principal
        SafeArea(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LogoIcon(size: 52),
                      const SizedBox(height: 10),
                      _buildTitle(isLandscape: true),
                      const SizedBox(height: 14),
                      const _AnimatedBusRoute(),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_buildButtons(context, isLandscape: true)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Título ────────────────────────────────────────────────────────────────

  Widget _buildTitle({required bool isLandscape}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rutas Baja\nExpress',
          style: TextStyle(
            color: Colors.white,
            fontSize: isLandscape ? 26 : 36,
            fontWeight: FontWeight.bold,
            height: 1.1,
            shadows: isLandscape
                ? const [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(height: isLandscape ? 6 : 12),
        Text(
          'Tu sistema de viajes en\nBaja California',
          style: TextStyle(
            color: isLandscape ? Colors.white.withOpacity(0.9) : Colors.white70,
            fontSize: isLandscape ? 12 : 15,
            height: 1.5,
            shadows: isLandscape
                ? const [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }

  // ── Botones ───────────────────────────────────────────────────────────────

  Widget _buildButtons(BuildContext context, {required bool isLandscape}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _AnimatedButton(
                onTap: () => _showBottomSheet(context, const LoginScreen()),
                isOutlined: true,
                label: 'Iniciar sesión',
                compact: isLandscape,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnimatedButton(
                onTap: () => _showBottomSheet(context, const SignupScreen()),
                isOutlined: false,
                label: 'Registrarse',
                compact: isLandscape,
              ),
            ),
          ],
        ),
        SizedBox(height: isLandscape ? 8 : 12),
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
            child: Text(
              'Entrar como invitado',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isLandscape ? 12 : 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
                shadows: isLandscape
                    ? const [Shadow(color: Colors.black45, blurRadius: 6)]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Logo con ciclo de colores ────────────────────────────────────────────────

class _LogoIcon extends StatefulWidget {
  final double size;
  const _LogoIcon({this.size = 72});

  @override
  State<_LogoIcon> createState() => _LogoIconState();
}

class _LogoIconState extends State<_LogoIcon>
    with SingleTickerProviderStateMixin {
  static const _colors = [
    Color(0xFFE9713A),
    Color(0xFFC0392B),
    Color(0xFF27AE60),
  ];

  int _colorIndex = 0;

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTap() => setState(() {
    _colorIndex = (_colorIndex + 1) % _colors.length;
  });

  @override
  Widget build(BuildContext context) {
    final color = _colors[_colorIndex];
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        _onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.size * 0.25),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_bus,
            color: Colors.white,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );
  }
}

// ─── Botón animado ────────────────────────────────────────────────────────────

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isOutlined;
  final String label;
  final bool compact;

  const _AnimatedButton({
    required this.onTap,
    required this.isOutlined,
    required this.label,
    this.compact = false,
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
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vertPad = widget.compact ? 10.0 : 14.0;
    final fontSize = widget.compact ? 13.0 : 15.0;

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
                  padding: EdgeInsets.symmetric(vertical: vertPad),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: widget.onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: naranja,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: naranja.withOpacity(0.45),
                  padding: EdgeInsets.symmetric(vertical: vertPad),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Bus animado ──────────────────────────────────────────────────────────────

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
                      radius: 5,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pos,
                    builder: (_, __) => Positioned(
                      left: 4 + _pos.value * (w - 36),
                      top: 3,
                      child: const Text('🚌', style: TextStyle(fontSize: 20)),
                    ),
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
            Text(
              'Tijuana',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            Text(
              'Tecate',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Wave painter ─────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final Color color;
  const _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, size.height * 0.02);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.02,
      size.width * 0.60,
      size.height * 0.38,
      size.width,
      size.height * 0.28,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
