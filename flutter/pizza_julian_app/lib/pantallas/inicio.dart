import 'package:flutter/material.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';

// Pantalla pública de Inicio (inicio/index.php): carrusel, video, acordeón y secciones colapsables
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  Map<String, String>? _datos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await api.inicio();
      if (mounted) setState(() => (_datos = datos, _error = null));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return PaginaPizzeria(
      seccion: Seccion.inicio,
      alRefrescar: _cargar,
      hijos: d == null
          ? [EstadoCarga(error: _error, alReintentar: _cargar)]
          : [
              Carrusel(imagenes: [d['carru_1']!, d['carru_2']!, d['carru_3']!]),
              VideoYoutube(url: d['url_video_inicio']!),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AcordeonPizzeria(
                  elementos: [for (var i = 1; i <= 5; i++) (d['acor${i}_titulo_inicio']!, d['acor${i}_texto_inicio']!)],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ColapsablesPizzeria(
                  elementos: [for (var i = 1; i <= 3; i++) (d['colapsar${i}_titulo_inicio']!, d['colapsar${i}_texto_inicio']!)],
                ),
              ),
            ],
    );
  }
}

String? idYoutube(String url) =>
    RegExp(r'(?:youtu\.be/|youtube\.com/(?:embed/|watch\?v=|shorts/))([A-Za-z0-9_-]{6,})', caseSensitive: false).firstMatch(url)?.group(1);

// Miniatura del video; al tocarla se abre en la app de YouTube
class VideoYoutube extends StatelessWidget {
  const VideoYoutube({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final id = idYoutube(url);
    if (id == null) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: () => abrirUrl(context, 'https://www.youtube.com/watch?v=$id'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            Image.network('https://img.youtube.com/vi/$id/hqdefault.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
            Container(color: Colors.black26),
            Center(
              child: Container(
                width: 72,
                height: 50,
                decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Acordeón: solo un elemento abierto a la vez y el primero abierto al iniciar (#accordionExample)
class AcordeonPizzeria extends StatefulWidget {
  const AcordeonPizzeria({super.key, required this.elementos});

  final List<(String, String)> elementos;

  @override
  State<AcordeonPizzeria> createState() => _AcordeonPizzeriaState();
}

class _AcordeonPizzeriaState extends State<AcordeonPizzeria> {
  int? _abierto = 0;

  @override
  Widget build(BuildContext context) {
    final borde = mezclar(mezclar(pz.negro, 95, pz.rojo), 90, pz.gris);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: borde), borderRadius: BorderRadius.circular(6), color: pz.negroSuave),
        child: Column(
          children: [
            for (var i = 0; i < widget.elementos.length; i++) ...[
              if (i > 0) Divider(height: 1, color: borde),
              _encabezado(i),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _abierto == i ? _cuerpo(widget.elementos[i]) : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _encabezado(int i) {
    final abierto = _abierto == i;
    final colorTexto = abierto ? mezclar(pz.naranja, 15, Colors.black) : pz.gris;
    return InkWell(
      onTap: () => setState(() => _abierto = abierto ? null : i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: abierto ? null : pz.negro,
          gradient: abierto ? LinearGradient(colors: [pz.naranja, pz.amarillo]) : null,
        ),
        child: Row(
          children: [
            Expanded(child: Text(widget.elementos[i].$1, style: TextStyle(color: colorTexto, fontSize: 16, fontWeight: abierto ? FontWeight.w700 : FontWeight.w500))),
            AnimatedRotation(
              turns: abierto ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down, color: abierto ? colorTexto : pz.naranja),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo((String, String) elemento) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: mezclar(pz.negroSuave, 95, pz.rojoVivo),
        child: Text.rich(
          TextSpan(
            style: TextStyle(color: pz.blanco, height: 1.6),
            children: [
              TextSpan(text: '${elemento.$1}. ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: elemento.$2),
            ],
          ),
          textAlign: TextAlign.justify,
        ),
      );
}

// Botones rojos que despliegan una tarjeta con texto (.colapsar-pizzeria)
class ColapsablesPizzeria extends StatefulWidget {
  const ColapsablesPizzeria({super.key, required this.elementos});

  final List<(String, String)> elementos;

  @override
  State<ColapsablesPizzeria> createState() => _ColapsablesPizzeriaState();
}

class _ColapsablesPizzeriaState extends State<ColapsablesPizzeria> {
  final _abiertos = <int>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RadialGradient(center: Alignment.topCenter, radius: 1.4, colors: [mezclar(pz.negroSuave, 95, pz.rojoVivo), pz.negro], stops: const [0, 0.65]),
        border: Border.all(color: mezclar(mezclar(pz.negro, 85, pz.gris), 90, pz.rojoProfundo)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < widget.elementos.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: BotonGradiente(
                texto: widget.elementos[i].$1,
                colores: [pz.rojo, mezclar(pz.negroSuave, 20, pz.rojo)],
                borde: pz.rojoVivo,
                alPresionar: () => setState(() => _abiertos.contains(i) ? _abiertos.remove(i) : _abiertos.add(i)),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: !_abiertos.contains(i)
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: mezclar(pz.negroSuave, 95, pz.blanco),
                        border: Border.all(color: mezclar(mezclar(pz.negro, 85, pz.rojo), 85, pz.blanco)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(widget.elementos[i].$2, style: TextStyle(color: pz.gris, height: 1.5)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
