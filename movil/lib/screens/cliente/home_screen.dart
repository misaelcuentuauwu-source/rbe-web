import 'package:flutter/material.dart';
import '../shared/inicio_screen.dart';
import 'perfil_cliente_screen.dart';
import 'historial_cliente_screen.dart';

class HomeClienteScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const HomeClienteScreen({super.key, required this.cliente});

  @override
  State<HomeClienteScreen> createState() => _HomeClienteScreenState();
}

class _HomeClienteScreenState extends State<HomeClienteScreen> {
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);

  int _tabActual = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      InicioScreen(
        clienteId: widget.cliente['pasajero_num'],
        correoCliente: widget.cliente['correo'],
        tipoUsuario: 'cliente',
        datosUsuario: widget.cliente,
      ),
      HistorialClienteScreen(
        clienteId: widget.cliente['pasajero_num'],
        datosUsuario: widget.cliente,
      ),
      PerfilClienteScreen(cliente: widget.cliente),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: _tabs[_tabActual],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              currentIndex: _tabActual,
              onTap: (i) => setState(() => _tabActual = i),
              backgroundColor: Colors.white,
              selectedItemColor: naranja,
              unselectedItemColor: Colors.grey.shade400,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.confirmation_number_outlined),
                  label: 'Mis boletos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
