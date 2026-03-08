import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'seat_selection_screen.dart';
import 'datos_boleto_screen.dart';

class ResultadosScreen extends StatefulWidget {
  final String origen;
  final String destino;
  final String origenNombre;
  final String destinoNombre;
  final DateTime fecha;
  final Map<String, int> pasajeros;
  final int vendedorId;

  const ResultadosScreen({
    super.key,
    required this.origen,
    required this.destino,
    required this.origenNombre,
    required this.destinoNombre,
    required this.fecha,
    required this.pasajeros,
    required this.vendedorId,
  });

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFF008FD4);

  List<dynamic> viajes = [];
  bool cargando = true;

  int get totalPasajeros => widget.pasajeros.values.reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();
    cargarViajes();
  }

  Future<void> cargarViajes() async {
    setState(() => cargando = true);
    try {
      final fecha =
          '${widget.fecha.year}-${widget.fecha.month.toString().padLeft(2, '0')}-${widget.fecha.day.toString().padLeft(2, '0')}';
      final url =
          '${Config.baseUrl}/api/viajes/?origen=${widget.origen}&destino=${widget.destino}&fecha=$fecha';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          viajes = jsonDecode(response.body) as List;
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => cargando = false);
    }
  }

  String _formatHora(String fechaHora) {
    final dt = DateTime.parse(fechaHora);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFecha(String fechaHora) {
    final dt = DateTime.parse(fechaHora);
    const meses = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildResumenBusqueda(),
            const SizedBox(height: 12),
            _buildTituloLista(),
            const SizedBox(height: 8),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Viajes disponibles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenBusqueda() {
    // Buscar nombres de ciudades
    final origenNombre = widget.origenNombre;
    final destinoNombre = widget.destinoNombre;
    final fechaStr = _formatFecha(widget.fecha.toIso8601String());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, color: azul, size: 18),
              const SizedBox(width: 8),
              Text(
                origenNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.location_on_rounded, color: naranja, size: 18),
              const SizedBox(width: 4),
              Text(
                destinoNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                fechaStr,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.people_rounded, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(
                '$totalPasajeros pasajero(s)',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getNombreCiudad(String numero) {
    const ciudades = {
      '1': 'Tijuana',
      '2': 'Mexicali',
      '3': 'Ensenada',
      '4': 'San Quintín',
      '5': 'La Paz',
    };
    return ciudades[numero] ?? numero;
  }

  Widget _buildTituloLista() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Text(
            'Resultados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (!cargando)
            Text(
              '${viajes.length} encontrado(s)',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (viajes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: Colors.white54,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay viajes disponibles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Intenta con otra fecha',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: azul,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Volver a buscar'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: viajes.length,
      itemBuilder: (context, index) => _buildViajeCard(viajes[index]),
    );
  }

  Widget _buildViajeCard(Map viaje) {
    final ruta = viaje['ruta'];
    final origen = ruta['origen']['ciudad']['nombre'];
    final destino = ruta['destino']['ciudad']['nombre'];
    final horaSalida = _formatHora(viaje['fechorasalida']);
    final horaLlegada = _formatHora(viaje['fechoraentrada']);
    final fecha = _formatFecha(viaje['fechorasalida']);
    final duracion = ruta['duracion'];
    final precio = ruta['precio'];
    final asientosDisp = viaje['asientos_disponibles'];
    final precioTotal = (double.parse(precio) * totalPasajeros).toStringAsFixed(
      2,
    );
    final hayLugares = asientosDisp >= totalPasajeros;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Fecha y lugares
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  fecha,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: hayLugares
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hayLugares
                        ? '$asientosDisp lugares disp.'
                        : 'Sin lugares suficientes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hayLugares
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Horario
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      horaSalida,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      origen,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          const Icon(
                            Icons.directions_bus_rounded,
                            color: azul,
                            size: 20,
                          ),
                          Expanded(
                            child: Container(
                              height: 1.5,
                              color: Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      Text(
                        duracion,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      horaLlegada,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      destino,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Precio y botón
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$$precioTotal MXN',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: naranja,
                      ),
                    ),
                    Text(
                      '$totalPasajeros pasajero(s) × \$$precio',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: hayLugares
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DatosBoletoScreen(
                                viajeId: viaje['numero'],
                                pasajeros: widget.pasajeros,
                                origenNombre: widget.origenNombre,
                                destinoNombre: widget.destinoNombre,
                                horaSalida: _formatHora(viaje['fechorasalida']),
                                precio: ruta['precio'],
                                vendedorId: widget.vendedorId,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: naranja,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Seleccionar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
