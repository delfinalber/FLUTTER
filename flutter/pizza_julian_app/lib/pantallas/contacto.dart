import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/iframe.dart';

// Pantalla pública de Contacto (contacto/contactos.php): mapa de Google y formulario
class PantallaContacto extends StatefulWidget {
  const PantallaContacto({super.key});

  @override
  State<PantallaContacto> createState() => _PantallaContactoState();
}

class _PantallaContactoState extends State<PantallaContacto> {
  String? _urlMapa;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await api.contacto();
      if (mounted) setState(() => (_urlMapa = datos['url_contacto'].toString(), _error = null));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaginaPizzeria(
      seccion: Seccion.contacto,
      alRefrescar: _cargar,
      hijos: [
        if (_urlMapa == null) EstadoCarga(error: _error, alReintentar: _cargar) else MapaContacto(url: _urlMapa!),
        const SizedBox(height: 16),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: FormularioContacto()),
      ],
    );
  }
}

class MapaContacto extends StatefulWidget {
  const MapaContacto({super.key, required this.url});

  final String url;

  @override
  State<MapaContacto> createState() => _MapaContactoState();
}

class _MapaContactoState extends State<MapaContacto> {
  WebViewController? _controlador;

  bool get _soportaWebView => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_soportaWebView) {
      _controlador = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  void didUpdateWidget(MapaContacto anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.url != widget.url) {
      _controlador?.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: kIsWeb
              ? iframeWeb(widget.url)
              : _controlador != null
                  ? WebViewWidget(
                      controller: _controlador!,
                      // permite mover el mapa con el dedo dentro de la pantalla que hace scroll
                      gestureRecognizers: const {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)},
                    )
                  : Container(
                      color: pz.negroSuave,
                      alignment: Alignment.center,
                      child: Icon(Icons.map_outlined, color: pz.naranja, size: 64),
                    ),
        ),
        TextButton.icon(
          onPressed: () => abrirUrl(context, widget.url),
          icon: Icon(Icons.open_in_new, color: pz.rojo),
          label: Text('Abrir en Google Maps', style: TextStyle(color: pz.rojo, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class FormularioContacto extends StatefulWidget {
  const FormularioContacto({super.key});

  @override
  State<FormularioContacto> createState() => _FormularioContactoState();
}

class _FormularioContactoState extends State<FormularioContacto> {
  final _clave = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _comentario = TextEditingController();
  bool _enviando = false;
  String? _mensaje;
  bool _mensajeError = false;

  @override
  void dispose() {
    for (final c in [_correo, _nombre, _telefono, _comentario]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _mensaje = null);
    if (!_clave.currentState!.validate()) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final respuesta = await api.enviarMensaje(
        correo: _correo.text.trim(),
        nombre: _nombre.text.trim(),
        telefono: _telefono.text.trim(),
        mensaje: _comentario.text.trim(),
      );
      _clave.currentState!.reset();
      for (final c in [_correo, _nombre, _telefono, _comentario]) {
        c.clear();
      }
      setState(() => (_mensaje = respuesta, _mensajeError = false));
    } on ApiError catch (e) {
      setState(() => (_mensaje = e.mensaje, _mensajeError = true));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campo(String etiqueta, TextEditingController controlador, String sugerencia,
      {String? ayuda, int lineas = 1, int? maximo, TextInputType? teclado, String? Function(String)? validar}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controlador,
            minLines: lineas,
            maxLines: lineas == 1 ? 1 : lineas + 2,
            maxLength: maximo,
            keyboardType: teclado,
            validator: validar == null ? null : (v) => validar(v?.trim() ?? ''),
            decoration: InputDecoration(
              hintText: sugerencia,
              helperText: ayuda,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: pz.naranja, width: 2)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _clave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mensaje != null) Alerta(_mensaje!, error: _mensajeError, alCerrar: () => setState(() => _mensaje = null)),
          _campo('Email', _correo, 'Digite su Correo',
              ayuda: 'No comparta el correo.',
              teclado: TextInputType.emailAddress,
              validar: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Escriba un correo válido.'),
          _campo('Nombre', _nombre, 'Digite su Nombre', maximo: 150, validar: (v) => v.isEmpty ? 'El nombre es obligatorio.' : null),
          _campo('Teléfono', _telefono, 'Digite su Telefono', maximo: 20, teclado: TextInputType.phone),
          _campo('Comentario', _comentario, 'Digite su Comentario', lineas: 3, maximo: 500, validar: (v) => v.isEmpty ? 'El comentario es obligatorio.' : null),
          Align(
            alignment: Alignment.centerLeft,
            child: BotonGradiente(
              texto: 'Enviar',
              cargando: _enviando,
              colores: [pz.rojo, pz.rojoProfundo],
              icono: Icons.send,
              alPresionar: _enviar,
            ),
          ),
        ],
      ),
    );
  }
}
