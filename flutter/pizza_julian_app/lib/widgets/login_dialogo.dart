import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../api.dart';
import '../tema.dart';
import 'comunes.dart';

// Ventana de "Inicio de sesion" con contador de 30 segundos, igual que el modal #loginModal de la web.
// Devuelve true si el usuario entró.
Future<bool?> mostrarLogin(BuildContext context) => showDialog<bool>(
      context: context,
      barrierDismissible: false, // data-bs-backdrop="static"
      builder: (_) => const LoginDialogo(),
    );

class LoginDialogo extends StatefulWidget {
  const LoginDialogo({super.key});

  @override
  State<LoginDialogo> createState() => _LoginDialogoState();
}

class _LoginDialogoState extends State<LoginDialogo> {
  static const _segundosIniciales = 30;

  final _usuario = TextEditingController();
  final _password = TextEditingController();
  Timer? _contador;
  int _segundos = _segundosIniciales;
  String? _alerta;
  bool _alertaError = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _contador = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _segundos--);
      if (_segundos <= 0) {
        _contador?.cancel();
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _contador?.cancel();
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final usuario = _usuario.text.trim();
    if (usuario.isEmpty || _password.text.isEmpty) {
      setState(() {
        _alerta = 'Usuario y contraseña son obligatorios.';
        _alertaError = true;
      });
      return;
    }
    setState(() {
      _enviando = true;
      _alerta = null;
    });
    try {
      await api.login(usuario, _password.text);
      _contador?.cancel();
      setState(() {
        _alerta = 'Acceso correcto, redirigiendo...';
        _alertaError = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      _password.clear();
      setState(() {
        _alerta = e.mensaje;
        _alertaError = true;
        _enviando = false;
      });
    }
  }

  InputDecoration _decoracion(String sugerencia) => InputDecoration(
        hintText: sugerencia,
        filled: true,
        fillColor: mezclar(pz.naranja, 10, pz.blanco),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: mezclar(mezclar(pz.negroSuave, 60, pz.amarillo), 65, pz.rojoVivo)),
        ),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: pz.naranja, width: 2)),
      );

  Widget _etiqueta(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto, style: TextStyle(color: pz.amarillo, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final borde = mezclar(mezclar(pz.negro, 75, pz.rojo), 85, pz.blanco);
    // PointerInterceptor: en la versión web evita que el mapa (iframe) de debajo se quede con los clics
    return PointerInterceptor(
        child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borde),
            borderRadius: BorderRadius.circular(14),
            color: pz.negro,
          ),
          child: Stack(
            children: [
              // Fondo: el banner oscurecido
              Positioned.fill(child: ImagenRed(temaSitio.banner)),
              Positioned.fill(child: Container(color: pz.negro.withAlpha(227))),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Inicio de sesion', style: TextStyle(color: pz.amarillo, fontSize: 20, fontWeight: FontWeight.w700))),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: Icon(Icons.close, color: pz.blanco),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: mezclar(pz.naranja, 12, Colors.transparent),
                          border: Border.all(color: borde),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: 'Tiempo restante: ',
                            style: TextStyle(color: pz.gris, fontSize: 13),
                            children: [
                              TextSpan(text: '${_segundos.clamp(0, _segundosIniciales)}', style: TextStyle(color: pz.amarillo, fontWeight: FontWeight.w700)),
                              const TextSpan(text: 's'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(color: mezclar(mezclar(pz.negro, 85, pz.rojo), 85, pz.gris), height: 28),
                    if (_alerta != null) Alerta(_alerta!, error: _alertaError),
                    _etiqueta('Usuario'),
                    TextField(
                      controller: _usuario,
                      maxLength: 200,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: _decoracion('Digite su usuario').copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 14),
                    _etiqueta('Contrasena'),
                    TextField(
                      controller: _password,
                      maxLength: 200,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _entrar(),
                      decoration: _decoracion('Digite su contrasena').copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 18),
                    BotonGradiente(
                      texto: 'Entrar',
                      cargando: _enviando,
                      colores: [pz.rojo, mezclar(mezclar(pz.naranja, 80, pz.rojoProfundo), 60, pz.rojoVivo)],
                      borde: mezclar(mezclar(pz.naranja, 70, pz.rojoVivo), 90, pz.blanco),
                      alPresionar: _entrar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
