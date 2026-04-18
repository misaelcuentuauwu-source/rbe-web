import 'package:flutter/material.dart';
import '../shared/inicio_screen.dart';
import '../shared/buscar_boleto_screen.dart';
import 'perfil_invitado_screen.dart';

class HomeInvitadoScreen extends StatefulWidget {
  const HomeInvitadoScreen({super.key});

  @override
  State<HomeInvitadoScreen> createState() => _HomeInvitadoScreenState();
}

class _HomeInvitadoScreenState extends State<HomeInvitadoScreen>
    with TickerProviderStateMixin {
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);

  int _tabActual = 0;

  late final List<Widget> _tabs;
  late final List<AnimationController> _tabControllers;
  late final List<Animation<double>> _tabFades;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const InicioScreen(tipoUsuario: 'invitado'),
      const BuscarBoletoScreen(tipoUsuario: 'invitado'),
      const PerfilInvitadoScreen(),
    ];

    _tabControllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _tabFades = _tabControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();

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
    if (index == _tabActual) return;
    _tabControllers[_tabActual].reverse();
    setState(() => _tabActual = index);
    _tabControllers[index].forward();
  }

  @override
  Widget build(BuildContext context) {
    // padding.bottom = altura del indicador de inicio (iPhone) o barra de navegación (Android)
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: fondo,
      body: Stack(
        children: List.generate(_tabs.length, (i) {
          return FadeTransition(
            opacity: _tabFades[i],
            child: Offstage(
              offstage: _tabActual != i,
              child: _tabs[i],
            ),
          );
        }),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: bottomPad > 0 ? bottomPad : 16,
          left: 16,
          right: 16,
          top: 8,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  selected: _tabActual,
                  icon: Icons.search_rounded,
                  label: 'Buscar viaje',
                  color: naranja,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  index: 1,
                  selected: _tabActual,
                  icon: Icons.confirmation_number_outlined,
                  label: 'Mis boletos',
                  color: naranja,
                  onTap: _onTabTap,
                ),
                _NavItem(
                  index: 2,
                  selected: _tabActual,
                  icon: Icons.person_outline_rounded,
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
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
              Icon(
                widget.icon,
                color: _isSelected ? widget.color : Colors.grey.shade400,
                size: 22,
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
