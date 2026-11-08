import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../config.dart';
import '../navegacion.dart';
import '../tema.dart';
import 'login_dialogo.dart';

const mensajeWhatsapp = 'Hola, quiero más información acerca de las PIZZA JULIAN';

Future<void> abrirUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    mostrarAviso(context, 'No fue posible abrir el enlace.', error: true);
  }
}

Future<void> abrirWhatsapp(BuildContext context, [String mensaje = mensajeWhatsapp]) =>
    abrirUrl(context, 'https://wa.me/${temaSitio.whatsapp}?text=${Uri.encodeComponent(mensaje)}');

void mostrarAviso(BuildContext context, String mensaje, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? const Color(0xFFB02A37) : const Color(0xFF146C43),
    ));
}

// Estructura común de todas las pantallas: banner, menú, contenido, pie de página y botón de WhatsApp
class PaginaPizzeria extends StatelessWidget {
  const PaginaPizzeria({
    super.key,
    required this.seccion,
    required this.hijos,
    this.editor = false,
    this.alRefrescar,
  });

  final Seccion seccion;
  final bool editor;
  final List<Widget> hijos;
  final Future<void> Function()? alRefrescar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: temaSitio,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: pz.naranja,
            onRefresh: () async {
              await temaSitio.sincronizar();
              await alRefrescar?.call();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                const BannerSitio(),
                const SizedBox(height: 16),
                NavPizzeria(seccion: seccion, editor: editor),
                const SizedBox(height: 16),
                ...hijos,
                const SizedBox(height: 16),
                FooterPizzeria(editor: editor),
              ],
            ),
          ),
        ),
        floatingActionButton: editor ? null : const WhatsappFlotante(),
      ),
    );
  }
}

class ImagenRed extends StatelessWidget {
  const ImagenRed(this.ruta, {super.key, this.ajuste = BoxFit.cover, this.alto});

  final String ruta;
  final BoxFit ajuste;
  final double? alto;

  @override
  Widget build(BuildContext context) {
    if (ruta.isEmpty) {
      return _vacia();
    }
    return Image.network(
      urlMedia(ruta),
      fit: ajuste,
      height: alto,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _vacia(),
      loadingBuilder: (_, hijo, progreso) => progreso == null
          ? hijo
          : SizedBox(height: alto ?? 120, child: Center(child: CircularProgressIndicator(color: pz.naranja, strokeWidth: 2))),
    );
  }

  Widget _vacia() => Container(
        height: alto ?? 120,
        color: pz.negro,
        alignment: Alignment.center,
        child: Icon(Icons.local_pizza, color: pz.naranja, size: 40),
      );
}

class BannerSitio extends StatelessWidget {
  const BannerSitio({super.key});

  @override
  Widget build(BuildContext context) => ImagenRed(temaSitio.banner, ajuste: BoxFit.fitWidth);
}

// Equivale a .nav-pizzeria de Bootstrap en tamaño de celular: marca + botón hamburguesa que despliega el menú
class NavPizzeria extends StatefulWidget {
  const NavPizzeria({super.key, required this.seccion, required this.editor});

  final Seccion seccion;
  final bool editor;

  @override
  State<NavPizzeria> createState() => _NavPizzeriaState();
}

class _NavPizzeriaState extends State<NavPizzeria> {
  bool _abierto = false;

  Future<void> _botonSesion() async {
    if (widget.editor) {
      await api.logout();
      if (mounted) irA(context, Seccion.inicio);
      return;
    }
    final entro = await mostrarLogin(context);
    if (entro == true && mounted) {
      irA(context, widget.seccion, editor: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [pz.negro, pz.rojoProfundo, pz.negro], stops: const [0, 0.48, 1]),
        border: Border(top: BorderSide(color: pz.naranja, width: 3), bottom: BorderSide(color: pz.rojo, width: 3)),
        boxShadow: const [BoxShadow(color: Color(0x52000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Pizzeria Julian', style: TextStyle(color: pz.naranja, fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _abierto = !_abierto),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: mezclar(pz.naranja, 8, Colors.transparent),
                    border: Border.all(color: pz.naranja),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_abierto ? Icons.close : Icons.menu, color: pz.blanco, size: 28),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: !_abierto
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in Seccion.values)
                          InkWell(
                            onTap: () => irA(context, s, editor: widget.editor),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                s.titulo,
                                style: TextStyle(
                                  color: s == widget.seccion ? pz.amarillo : pz.blanco,
                                  fontSize: 16,
                                  fontWeight: s == widget.seccion ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _botonSesion,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: pz.amarillo,
                            side: BorderSide(color: pz.naranja),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(widget.editor ? 'Cerrar sesion' : 'Inicio Sesion'),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class FooterPizzeria extends StatelessWidget {
  const FooterPizzeria({super.key, this.editor = false});

  final bool editor;

  Widget _enlace(String texto, VoidCallback alTocar) => InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(texto, style: TextStyle(color: pz.gris, fontWeight: FontWeight.w500)),
        ),
      );

  Widget _social(BuildContext context, IconData icono, VoidCallback? alTocar) => Padding(
        padding: const EdgeInsets.all(5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: alTocar,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mezclar(mezclar(pz.rojo, 65, pz.blanco), 10, pz.negroSuave),
              border: Border.all(color: mezclar(mezclar(pz.negro, 75, pz.rojo), 85, pz.blanco)),
            ),
            alignment: Alignment.center,
            child: FaIcon(icono, color: pz.blanco, size: 18),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [pz.negroSuave, pz.negro])),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 90),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0x05FFFFFF),
          border: Border.all(color: mezclar(mezclar(pz.negroSuave, 90, pz.gris), 95, pz.rojo)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                _social(context, FontAwesomeIcons.facebookF, null),
                _social(context, FontAwesomeIcons.instagram, null),
                _social(context, FontAwesomeIcons.xTwitter, null),
                _social(context, FontAwesomeIcons.whatsapp, () => abrirWhatsapp(context)),
                _social(context, FontAwesomeIcons.youtube, null),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                _enlace('Inicio', () => irA(context, Seccion.inicio)),
                _enlace('Productos', () => irA(context, Seccion.productos)),
                _enlace('Contactos', () => irA(context, Seccion.contacto)),
                _enlace('Nuestro equipo', () {}),
              ],
            ),
            if (editor) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Editor de contenido:', style: TextStyle(color: pz.amarillo, fontWeight: FontWeight.w700)),
                  _enlace('Inicio', () => irA(context, Seccion.inicio, editor: true)),
                  _enlace('Productos', () => irA(context, Seccion.productos, editor: true)),
                  _enlace('Contacto', () => irA(context, Seccion.contacto, editor: true)),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Copyright 2026. Designed by JULIAN',
              textAlign: TextAlign.center,
              style: TextStyle(color: mezclar(mezclar(pz.negro, 70, pz.naranja), 20, pz.gris), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class WhatsappFlotante extends StatelessWidget {
  const WhatsappFlotante({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Enviar mensaje por WhatsApp',
      child: Semantics(
        button: true,
        label: 'Enviar mensaje por WhatsApp',
        child: GestureDetector(
          onTap: () => abrirWhatsapp(context),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: pz.naranja, width: 3),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pz.rojo, pz.rojoProfundo]),
              boxShadow: [
                BoxShadow(color: mezclar(pz.naranja, 20, Colors.transparent), spreadRadius: 4),
                const BoxShadow(color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 8)),
              ],
            ),
            alignment: Alignment.center,
            child: FaIcon(FontAwesomeIcons.whatsapp, color: pz.blanco, size: 30),
          ),
        ),
      ),
    );
  }
}

// Botón con degradado (btn-login, btn-editar, btn-eliminar, btn-colapsar de la web)
class BotonGradiente extends StatelessWidget {
  const BotonGradiente({
    super.key,
    required this.texto,
    required this.colores,
    required this.alPresionar,
    this.colorTexto,
    this.borde,
    this.icono,
    this.cargando = false,
  });

  final String texto;
  final List<Color> colores;
  final VoidCallback? alPresionar;
  final Color? colorTexto;
  final Color? borde;
  final IconData? icono;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final color = colorTexto ?? pz.blanco;
    return Opacity(
      opacity: alPresionar == null || cargando ? 0.65 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colores),
            border: Border.all(color: borde ?? colores.first),
            borderRadius: BorderRadius.circular(6),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: cargando ? null : alPresionar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (cargando)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                    )
                  else if (icono != null)
                    Padding(padding: const EdgeInsets.only(right: 6), child: Icon(icono, size: 18, color: color)),
                  Flexible(child: Text(texto, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Alerta estilo Bootstrap (alert-success / alert-danger)
class Alerta extends StatelessWidget {
  const Alerta(this.mensaje, {super.key, this.error = false, this.alCerrar});

  final String mensaje;
  final bool error;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final fondo = error ? const Color(0xFFF8D7DA) : const Color(0xFFD1E7DD);
    final texto = error ? const Color(0xFF58151C) : const Color(0xFF0A3622);
    final borde = error ? const Color(0xFFF1AEB5) : const Color(0xFFA3CFBB);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(color: fondo, border: Border.all(color: borde), borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Expanded(child: Text(mensaje, style: TextStyle(color: texto))),
          if (alCerrar != null) IconButton(onPressed: alCerrar, icon: Icon(Icons.close, size: 18, color: texto)),
        ],
      ),
    );
  }
}

// Carrusel automático con flechas (carousel de Bootstrap)
class Carrusel extends StatefulWidget {
  const Carrusel({super.key, required this.imagenes, this.intervalo = const Duration(seconds: 5), this.relacion = 16 / 10, this.ajuste = BoxFit.cover});

  final List<String> imagenes;
  final Duration intervalo;
  final double relacion;
  final BoxFit ajuste;

  @override
  State<Carrusel> createState() => _CarruselState();
}

class _CarruselState extends State<Carrusel> {
  final _controlador = PageController();
  Timer? _temporizador;
  int _actual = 0;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(widget.intervalo, (_) => _mover(1));
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _controlador.dispose();
    super.dispose();
  }

  void _mover(int paso) {
    if (!_controlador.hasClients || widget.imagenes.isEmpty) return;
    final siguiente = (_actual + paso) % widget.imagenes.length;
    _controlador.animateToPage(siguiente < 0 ? widget.imagenes.length - 1 : siguiente, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  Widget _flecha(IconData icono, int paso, Alignment alineacion) => Align(
        alignment: alineacion,
        child: IconButton(
          onPressed: () => _mover(paso),
          icon: Icon(icono, color: Colors.white, size: 34, shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.relacion,
      child: Container(
        color: pz.negro,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controlador,
              itemCount: widget.imagenes.length,
              onPageChanged: (i) => _actual = i,
              itemBuilder: (_, i) => ImagenRed(widget.imagenes[i], ajuste: widget.ajuste),
            ),
            _flecha(Icons.chevron_left, -1, Alignment.centerLeft),
            _flecha(Icons.chevron_right, 1, Alignment.centerRight),
          ],
        ),
      ),
    );
  }
}

// Mensaje de carga / error para las pantallas que consultan la API
class EstadoCarga extends StatelessWidget {
  const EstadoCarga({super.key, this.error, this.alReintentar});

  final String? error;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: error == null
            ? CircularProgressIndicator(color: pz.naranja)
            : Column(
                children: [
                  Alerta(error!, error: true),
                  if (alReintentar != null)
                    BotonGradiente(texto: 'Reintentar', colores: [pz.naranja, pz.amarillo], colorTexto: pz.negro, icono: Icons.refresh, alPresionar: alReintentar),
                ],
              ),
      ),
    );
  }
}
