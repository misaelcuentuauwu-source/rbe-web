import '../../utils/transitions.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../config.dart';
import 'datos_boleto_screen.dart';

class ResultadosScreen extends StatefulWidget {
  final String origen;
  final String destino;       // puede ser 'todas'
  final String origenNombre;
  final String destinoNombre; // puede ser 'Todas'
  final DateTime fecha;
  final Map<String, int> pasajeros;
  final int vendedorId;
  final String? correoCliente;
  final String tipoUsuario;
  final bool buscarCercanos;  // ← NUEVO
  final Map<String, dynamic>? datosUsuario;

  const ResultadosScreen({
    super.key,
    required this.origen,
    required this.destino,
    required this.origenNombre,
    required this.destinoNombre,
    required this.fecha,
    required this.pasajeros,
    required this.vendedorId,
    this.correoCliente,
    this.tipoUsuario = 'invitado',
    this.buscarCercanos = true,
    this.datosUsuario,
  });

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  static const azul    = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo   = Color(0xFFF4F6F9);
  static const textoPrincipal   = Color(0xFF1C2D3A);
  static const textoSecundario  = Color(0xFF6B8FA8);

  List<dynamic> viajes = [];
  bool cargando = true;

  // Cuándo son los viajes encontrados (puede diferir de widget.fecha)
  DateTime? fechaRealEncontrada;
  bool esFechaExacta = true;

  int get totalPasajeros => widget.pasajeros.values.reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();
    cargarViajes();
  }

  Future<void> cargarViajes() async {
    setState(() => cargando = true);
    try {
      final fechaStr = _toFechaStr(widget.fecha);
      String url =
          '${Config.baseUrl}/api/viajes/?origen=${widget.origen}&destino=${widget.destino}&fecha=$fechaStr';

      // Le indicamos al backend que busque cercanos si no hay en la fecha exacta
      if (widget.buscarCercanos) url += '&cercanos=true';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        // El backend puede devolver:
        // A) Lista directa (fecha exacta)
        // B) Objeto con { viajes: [...], fecha_real: "YYYY-MM-DD", exacta: false }
        if (body is List) {
          setState(() {
            viajes = body;
            esFechaExacta = true;
            fechaRealEncontrada = null;
            cargando = false;
          });
        } else if (body is Map) {
          final lista = body['viajes'] as List? ?? [];
          final fechaReal = body['fecha_real'] as String?;
          final exacta = body['exacta'] as bool? ?? true;
          setState(() {
            viajes = lista;
            esFechaExacta = exacta;
            fechaRealEncontrada =
                fechaReal != null ? DateTime.parse(fechaReal) : null;
            cargando = false;
          });
        } else {
          setState(() => cargando = false);
        }
      } else {
        setState(() => cargando = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => cargando = false);
    }
  }

  String _toFechaStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatHora(String fechaHora) {
    final dt = DateTime.parse(fechaHora);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFecha(String fechaHora) {
    final dt = DateTime.parse(fechaHora);
    const meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  String _formatFechaDate(DateTime dt) {
    const meses = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    const dias  = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    return '${dias[dt.weekday - 1]} ${dt.day} ${meses[dt.month]} ${dt.year}';
  }

  // ── Color dinámico según tipo de usuario ─────────────────────
  Color get colorPrimario =>
      widget.tipoUsuario == 'taquillero' ? naranja : azul;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildResumenBusqueda(),
            // Banner de aviso si no es fecha exacta
            if (!cargando && !esFechaExacta && fechaRealEncontrada != null)
              _buildBannerCercanos(),
            const SizedBox(height: 8),
            _buildTituloLista(),
            const SizedBox(height: 8),
            Expanded(child: _buildLista()),
          ],
        ),
      ),
    );
  }

  // ── Banner amarillo cuando los resultados son de otra fecha ───
  Widget _buildBannerCercanos() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE08A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF856404), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF856404)),
                children: [
                  const TextSpan(
                      text: 'No hay viajes el día solicitado. '),
                  const TextSpan(
                      text: 'Viajes más cercanos disponibles: '),
                  TextSpan(
                    text: _formatFechaDate(fechaRealEncontrada!),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colorPrimario,
        boxShadow: [
          BoxShadow(
            color: colorPrimario.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viajes disponibles',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                'Selecciona tu viaje',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenBusqueda() {
    final fechaStr = _formatFechaDate(widget.fecha);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.trip_origin_rounded, color: colorPrimario, size: 16),
              const SizedBox(width: 6),
              Text(widget.origenNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textoPrincipal)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: textoSecundario, size: 16),
              const SizedBox(width: 8),
              const Icon(Icons.location_on_rounded, color: naranja, size: 16),
              const SizedBox(width: 4),
              Text(widget.destinoNombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textoPrincipal)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  color: Colors.grey.shade400, size: 14),
              const SizedBox(width: 6),
              Text(fechaStr,
                  style: TextStyle(fontSize: 12, color: textoSecundario)),
              const SizedBox(width: 16),
              Icon(Icons.people_rounded,
                  color: Colors.grey.shade400, size: 14),
              const SizedBox(width: 6),
              Text('$totalPasajeros pasajero(s)',
                  style: TextStyle(fontSize: 12, color: textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTituloLista() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: colorPrimario,
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Text(
            esFechaExacta ? 'Resultados' : 'Próximos viajes disponibles',
            style: const TextStyle(
                color: textoPrincipal,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!cargando)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: colorPrimario.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${viajes.length} encontrado(s)',
                style: TextStyle(
                    color: colorPrimario,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (cargando) {
      return Center(child: CircularProgressIndicator(color: colorPrimario));
    }
    if (viajes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                color: Colors.grey.shade300, size: 70),
            const SizedBox(height: 16),
            const Text('No hay viajes disponibles',
                style: TextStyle(
                    color: textoPrincipal,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Intenta con otra fecha o ruta',
                style: TextStyle(color: textoSecundario, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver a buscar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Agrupar por fecha para mostrar separadores cuando hay múltiples días
    return _buildListaAgrupada();
  }

  Widget _buildListaAgrupada() {
    // Agrupar viajes por fecha
    final Map<String, List<dynamic>> grupos = {};
    for (final v in viajes) {
      final fecha = _formatFecha(v['fechorasalida']);
      grupos.putIfAbsent(fecha, () => []).add(v);
    }

    final fechas = grupos.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: fechas.fold<int>(
          0, (sum, f) => sum + grupos[f]!.length + 1), // +1 por header
      itemBuilder: (context, index) {
        // Calcular qué item mostrar
        int cursor = 0;
        for (final fecha in fechas) {
          if (index == cursor) {
            // Header de fecha
            return _buildFechaHeader(fecha);
          }
          cursor++;
          final viajesDelDia = grupos[fecha]!;
          if (index < cursor + viajesDelDia.length) {
            return _buildViajeCard(viajesDelDia[index - cursor]);
          }
          cursor += viajesDelDia.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFechaHeader(String fecha) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 13, color: colorPrimario),
          const SizedBox(width: 6),
          Text(
            fecha,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorPrimario,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: colorPrimario.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map viaje) {
    final ruta         = viaje['ruta'];
    final origen       = ruta['origen']['ciudad']['nombre'];
    final destino      = ruta['destino']['ciudad']['nombre'];
    final horaSalida   = _formatHora(viaje['fechorasalida']);
    final horaLlegada  = _formatHora(viaje['fechoraentrada']);
    final duracion     = ruta['duracion'];
    final precio       = ruta['precio'];
    final asientosDisp = viaje['asientos_disponibles'];
    final precioTotal  =
        (double.parse(precio) * totalPasajeros).toStringAsFixed(2);
    final hayLugares   = asientosDisp >= totalPasajeros;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Disponibilidad ──────────────────────────────
            Row(
              children: [
                // Si destino es "Todas" mostramos el destino de cada viaje
                if (widget.destino == 'todas')
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        color: colorPrimario, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$origen → $destino',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorPrimario,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 10),
                  ]),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const SizedBox(height: 14),
            // ── Horario ─────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(horaSalida,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textoPrincipal)),
                    Text(origen,
                        style: TextStyle(
                            fontSize: 12, color: textoSecundario)),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Row(children: [
                        const SizedBox(width: 8),
                        Expanded(
                            child: Container(
                                height: 1.5,
                                color: Colors.grey.shade200)),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: colorPrimario.withOpacity(0.08),
                              shape: BoxShape.circle),
                          child: Icon(Icons.directions_bus_rounded,
                              color: colorPrimario, size: 18),
                        ),
                        Expanded(
                            child: Container(
                                height: 1.5,
                                color: Colors.grey.shade200)),
                        const SizedBox(width: 8),
                      ]),
                      const SizedBox(height: 4),
                      Text(duracion,
                          style: TextStyle(
                              fontSize: 11, color: textoSecundario)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(horaLlegada,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textoPrincipal)),
                    Text(destino,
                        style: TextStyle(
                            fontSize: 12, color: textoSecundario)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 14),
            // ── Precio y botón ───────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$$precioTotal MXN',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: naranja)),
                    Text('$totalPasajeros pasajero(s) × \$$precio',
                        style: TextStyle(
                            fontSize: 11, color: textoSecundario)),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: hayLugares
                      ? () {
                          Navigator.push(
                            context,
                            AppRoutes.slideLeft(DatosBoletoScreen(
                              viajeId: viaje['numero'],
                              pasajeros: widget.pasajeros,
                              origenNombre: origen,
                              destinoNombre: destino,
                              horaSalida: horaSalida,
                              precio: ruta['precio'],
                              vendedorId: widget.vendedorId,
                              correoCliente: widget.correoCliente,
                              tipoUsuario: widget.tipoUsuario,
                              datosUsuario: widget.datosUsuario,
                            )),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: naranja,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    elevation: 2,
                    shadowColor: naranja.withOpacity(0.3),
                  ),
                  child: const Text('Seleccionar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
