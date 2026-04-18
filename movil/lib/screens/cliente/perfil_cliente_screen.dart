import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart';
import '../../../main.dart';

class PerfilClienteScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const PerfilClienteScreen({super.key, required this.cliente});

  @override
  State<PerfilClienteScreen> createState() => _PerfilClienteScreenState();
}

class _PerfilClienteScreenState extends State<PerfilClienteScreen> {
  static const azul = Color(0xFF2C7FB1);
  static const naranja = Color(0xFFE9713A);
  static const fondo = Color(0xFFF4F6F9);
  static const textoPrincipal = Color(0xFF1C2D3A);
  static const textoSecundario = Color(0xFF6B8FA8);

  // DESPUÉS
  String? fotoUrl;
  bool subiendoFoto = false;
  bool _editando = false;
  bool _guardando = false;
  final _telefonoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  DateTime? _fechaNacimiento;

  // DESPUÉS
  @override
  void initState() {
    super.initState();
    fotoUrl = widget.cliente['foto']?.toString();
    _telefonoCtrl.text = widget.cliente['telefono']?.toString() ?? '';
    _nombreCtrl.text = widget.cliente['nombre']?.toString() ?? '';
    _apellidoCtrl.text = widget.cliente['primer_apellido']?.toString() ?? '';
    final fnStr = widget.cliente['fecha_nacimiento']?.toString() ?? '';
    if (fnStr.isNotEmpty && fnStr != '2000-01-01') {
      try {
        final p = fnStr.split('-');
        _fechaNacimiento = DateTime(
          int.parse(p[0]),
          int.parse(p[1]),
          int.parse(p[2]),
        );
      } catch (_) {}
    }
  }

  // Agregar después del initState
  @override
  void dispose() {
    _telefonoCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _cambiarFoto() async {
    final proveedor = widget.cliente['proveedor'] ?? 'local';

    // Si usa Google, la foto viene de Firebase — solo informamos
    if (proveedor == 'google') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Tu foto se sincroniza automáticamente desde tu cuenta Google',
          ),
          backgroundColor: azul,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Foto de perfil',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textoPrincipal,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: azul.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: azul),
              ),
              title: const Text(
                'Tomar foto',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Usar la cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: naranja.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: naranja),
              ),
              title: const Text(
                'Elegir de galería',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Seleccionar desde el dispositivo'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final imagen = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (imagen == null) return;

    setState(() => subiendoFoto = true);
    try {
      final id = widget.cliente['pasajero_num'] ?? widget.cliente['num'];
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${Config.baseUrl}/api/pasajero/$id/foto/'),
      );
      request.files.add(await http.MultipartFile.fromPath('foto', imagen.path));
      final response = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        setState(() => fotoUrl = data['foto_url']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Foto actualizada'),
                ],
              ),
              backgroundColor: Colors.green.shade500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception('Error al subir');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo actualizar la foto'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => subiendoFoto = false);
    }
  }

  // Agregar después de _cambiarFoto()
  Future<void> _guardarPerfil() async {
    final id = widget.cliente['pasajero_num'] ?? widget.cliente['num'];
    setState(() => _guardando = true);
    try {
      String? fnStr;
      if (_fechaNacimiento != null) {
        final fn = _fechaNacimiento!;
        fnStr =
            '${fn.year}-${fn.month.toString().padLeft(2, '0')}-${fn.day.toString().padLeft(2, '0')}';
      }
      final response = await http
          .post(
            Uri.parse('${Config.baseUrl}/api/cliente/$id/actualizar-perfil/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'telefono': _telefonoCtrl.text.trim(),
              'fecha_nacimiento': fnStr ?? '',
              'nombre': _nombreCtrl.text.trim(),
              'primer_apellido': _apellidoCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() => _editando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Perfil actualizado'),
              backgroundColor: Colors.green.shade500,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al guardar'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = fotoUrl ?? '';
    final nombre =
        '${widget.cliente['nombre']} ${widget.cliente['primer_apellido']}';
    final correo = widget.cliente['correo'] ?? '';
    final proveedor = widget.cliente['proveedor'] ?? 'local';
    final esGoogle = proveedor == 'google';

    return Scaffold(
      backgroundColor: fondo,
      body: SafeArea(
        child: Column(
          children: [
            // Header azul
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: azul,
                boxShadow: [
                  BoxShadow(
                    color: azul.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Mi perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ── Avatar con botón cámara ──────────────
                    GestureDetector(
                      onTap: subiendoFoto ? null : _cambiarFoto,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: azul.withOpacity(0.1),
                              border: Border.all(color: azul, width: 2.5),
                            ),
                            child: ClipOval(
                              child: subiendoFoto
                                  ? Center(
                                      child: CircularProgressIndicator(
                                        color: azul,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : foto.isNotEmpty
                                  ? Image.network(
                                      foto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.person,
                                        size: 50,
                                        color: azul,
                                      ),
                                    )
                                  : Icon(Icons.person, size: 50, color: azul),
                            ),
                          ),
                          // Ícono cámara — si es Google muestra candado
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: esGoogle ? Colors.red.shade400 : azul,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                esGoogle
                                    ? Icons.g_mobiledata_rounded
                                    : Icons.camera_alt_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      correo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: esGoogle
                            ? Colors.red.shade50
                            : azul.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        esGoogle ? '🔴 Cuenta Google' : '📧 Cuenta local',
                        style: TextStyle(
                          fontSize: 12,
                          color: esGoogle ? Colors.red.shade700 : azul,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // DESPUÉS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: azul,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Información de cuenta',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textoPrincipal,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _editando = !_editando),
                                icon: Icon(
                                  _editando ? Icons.close : Icons.edit_rounded,
                                  size: 16,
                                ),
                                label: Text(_editando ? 'Cancelar' : 'Editar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: azul,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!_editando) ...[
                            _buildInfoRow(
                              Icons.person_outline,
                              'Nombre',
                              nombre,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.email_outlined,
                              'Correo',
                              correo,
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.phone_outlined,
                              'Teléfono',
                              widget.cliente['telefono']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? widget.cliente['telefono'].toString()
                                  : 'No registrado',
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.cake_outlined,
                              'Fecha de nacimiento',
                              _fechaNacimiento != null
                                  ? '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'
                                  : 'No registrada',
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.login_rounded,
                              'Método de acceso',
                              esGoogle ? 'Google' : 'Correo y contraseña',
                            ),
                          ] else ...[
                            // Nombre (solo editable en Google o si quiere)
                            TextField(
                              controller: _nombreCtrl,
                              decoration: InputDecoration(
                                labelText: 'Nombre',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _apellidoCtrl,
                              decoration: InputDecoration(
                                labelText: 'Primer apellido',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _telefonoCtrl,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: InputDecoration(
                                labelText: 'Teléfono',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Selector de fecha
                            InkWell(
                              onTap: () async {
                                final hoy = DateTime.now();
                                final max = DateTime(
                                  hoy.year - 18,
                                  hoy.month,
                                  hoy.day,
                                );
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _fechaNacimiento ??
                                      DateTime(
                                        hoy.year - 25,
                                        hoy.month,
                                        hoy.day,
                                      ),
                                  firstDate: DateTime(
                                    hoy.year - 120,
                                    hoy.month,
                                    hoy.day,
                                  ),
                                  lastDate: max,
                                  locale: const Locale('es', 'MX'),
                                  helpText: 'Fecha de nacimiento',
                                );
                                if (picked != null)
                                  setState(() => _fechaNacimiento = picked);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cake_outlined,
                                      color: azul,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _fechaNacimiento != null
                                            ? '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'
                                            : 'Seleccionar fecha de nacimiento',
                                        style: TextStyle(
                                          color: _fechaNacimiento != null
                                              ? textoPrincipal
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: azul,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _guardando ? null : _guardarPerfil,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: azul,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _guardando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Guardar cambios',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cerrarSesion(context),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Cerrar sesión',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: azul, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: textoSecundario),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textoPrincipal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
