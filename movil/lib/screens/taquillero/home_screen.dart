import 'package:flutter/material.dart';
import '../shared/inicio_screen.dart';
import 'perfil_screen.dart';
import 'historial_screen.dart';
import '../shared/buscar_boleto_screen.dart';

class HomeNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> taquillero;

  const HomeNavigationScreen({super.key, required this.taquillero});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  int _prevIndex = 0;

  static const naranja = Color(0xFFE9713A);
  static const azul = Color(0xFF2C7FB1);

  // Cada tab tiene su propio controlador de animación para fade-in
  late final List<AnimationController> _tabControllers;
  late final List<Animation<double>> _tabFades;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      InicioScreen(
        vendedorId: widget.taquillero['registro'],
        tipoUsuario: 'taquillero',
        datosUsuario: widget.taquillero,
      ),
      HistorialScreen(vendedorId: widget.taquillero['registro']),
      BuscarBoletoScreen(),
      PerfilScreen(taquillero: widget.taquillero),
    ];

    _tabControllers = List.generate(
      4,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _tabFades = _tabControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

    // Arranca con el primer tab visible
    _tabControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _tabControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _selectedIndex) return;
    _tabControllers[_selectedIndex].reverse();
    setState(() {
      _prevIndex = _selectedIndex;
      _selectedIndex = index;
    });
    _tabControllers[index].forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: List.generate(_pages.length, (i) {
          return FadeTransition(
            opacity: _tabFades[i],
            child: Offstage(
              offstage: _selectedIndex != i,
              child: _pages[i],
            ),
          );
        }),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  selected: _selectedIndex,
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  color: naranja,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  index: 1,
                  selected: _selectedIndex,
                  icon: Icons.history_rounded,
                  label: 'Historial',
                  color: naranja,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  index: 2,
                  selected: _selectedIndex,
                  icon: Icons.search_rounded,
                  label: 'Buscar',
                  color: naranja,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  index: 3,
                  selected: _selectedIndex,
                  icon: Icons.person_rounded,
                  label: 'Perfil',
                  color: naranja,
                  onTap: _onTabTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de navegación con animación de scale + color
class _NavItem extends StatefulWidget {
  final int index;
  final int selected;
  final IconData icon;
  final String label;
  final Color color;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.selected,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isSelected => widget.index == widget.selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap(widget.index);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _isSelected ? 16 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _isSelected
                ? widget.color.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _iconScale,
                builder: (_, child) => Transform.scale(
                  scale: _isSelected ? 1.0 : 1.0,
                  child: child,
                ),
                child: Icon(
                  widget.icon,
                  color: _isSelected ? widget.color : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
