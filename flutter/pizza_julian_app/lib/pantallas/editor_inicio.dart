import 'package:flutter/material.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/editor.dart';

// Editor de la tabla `inicio` (inicio/index-formulario.php)
class EditorInicio extends StatefulWidget {
  const EditorInicio({super.key});

  @override
  State<EditorInicio> createState() => _EditorInicioState();
}

class _EditorInicioState extends State<EditorInicio> {
  List<Map<String, dynamic>>? _registros;
  String? _error;
  String? _mensaje;
  bool _mensajeError = false;

  @override
  void initState() {
    super.initState();
    exigirSesion(context, Seccion.inicio);
    if (sesion.activa) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final registros = await api.registrosInicio();
      if (mounted) setState(() => (_registros = registros, _error = null));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      manejarErrorEditor(context, Seccion.inicio, e);
    }
  }

  Future<void> _abrirFormulario(Map<String, dynamic>? fila, bool controlaTema) async {
    final mensaje = await Navigator.of(context).push<String>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => FormularioInicio(fila: fila, controlaTema: controlaTema)),
    );
    if (mensaje != null && mounted) {
      setState(() => (_mensaje = mensaje, _mensajeError = false));
      await temaSitio.sincronizar(); // banner y paleta nuevos para toda la app
      await _cargar();
    }
  }

  Future<void> _eliminar(int id) async {
    if (!await confirmar(context, '¿Eliminar este contenido?')) return;
    try {
      final mensaje = await api.eliminarInicio(id);
      setState(() => (_mensaje = mensaje, _mensajeError = false));
      await temaSitio.sincronizar();
      await _cargar();
    } catch (e) {
      if (mounted) manejarErrorEditor(context, Seccion.inicio, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registros = _registros;
    return PaginaPizzeria(
      seccion: Seccion.inicio,
      editor: true,
      alRefrescar: _cargar,
      hijos: [
        PanelEditor(
          titulo: 'Editor de Contenido - Inicio',
          descripcion: 'Administra la información que se muestra en Inicio: banner, carrusel, video, acordeón, secciones colapsables y contacto.',
          hijos: [
            if (_mensaje != null) Alerta(_mensaje!, error: _mensajeError, alCerrar: () => setState(() => _mensaje = null)),
            if (registros == null)
              EstadoCarga(error: _error, alReintentar: _cargar)
            else if (registros.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: BotonEditar(texto: 'Crear contenido inicial', icono: Icons.add_circle_outline, alPresionar: () => _abrirFormulario(null, true)),
              )
            else
              for (final fila in registros) _tarjeta(fila, fila['id_inicio'] == registros.first['id_inicio']),
          ],
        ),
      ],
    );
  }

  Widget _tarjeta(Map<String, dynamic> fila, bool controlaTema) {
    final id = fila['id_inicio'] as int;
    final video = (fila['url_video_inicio'] ?? '').toString();
    return TarjetaEditor(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: ImagenRed((fila['banner_inicio'] ?? '').toString(), ajuste: BoxFit.fitWidth)),
          const SizedBox(height: 10),
          Text('Registro #$id', style: TextStyle(color: pz.blanco, fontSize: 18, fontWeight: FontWeight.w600)),
          Text('Video: ${video.isEmpty ? '-' : video}', style: const TextStyle(fontSize: 13)),
          Text('WhatsApp: ${fila['numero_whatsapp'] ?? ''}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BotonEditar(texto: 'Editar', alPresionar: () => _abrirFormulario(fila, controlaTema)),
              BotonEliminar(alPresionar: () => _eliminar(id)),
            ],
          ),
        ],
      ),
    );
  }
}

class FormularioInicio extends StatefulWidget {
  const FormularioInicio({super.key, required this.fila, required this.controlaTema});

  final Map<String, dynamic>? fila; // null = crear
  final bool controlaTema; // el primer registro define banner y paleta de toda la app

  @override
  State<FormularioInicio> createState() => _FormularioInicioState();
}

class _FormularioInicioState extends State<FormularioInicio> {
  static const _camposTexto = [
    'url_video_inicio',
    'acor1_titulo_inicio',
    'acor1_texto_inicio',
    'acor2_titulo_inicio',
    'acor2_texto_inicio',
    'acor3_titulo_inicio',
    'acor3_texto_inicio',
    'acor4_titulo_inicio',
    'acor4_texto_inicio',
    'acor5_titulo_inicio',
    'acor5_texto_inicio',
    'colapsar1_titulo_inicio',
    'colapsar1_texto_inicio',
    'colapsar2_titulo_inicio',
    'colapsar2_texto_inicio',
    'colapsar3_titulo_inicio',
    'colapsar3_texto_inicio',
    'numero_whatsapp',
  ];

  late final Map<String, TextEditingController> _textos = {
    for (final c in _camposTexto) c: TextEditingController(text: (widget.fila?[c] ?? '').toString()),
  };
  final _imagenes = <String, ImagenElegida>{};
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _actual(String campo) => (widget.fila?[campo] ?? '').toString();

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final mensaje = await api.guardarInicio(widget.fila?['id_inicio'] as int?, {
        for (final e in _textos.entries) e.key: e.value.text.trim(),
        'imagenes': {for (final e in _imagenes.entries) e.key: e.value.base64},
      });
      if (mounted) Navigator.pop(context, mensaje);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      if (e is ApiError && e.sesionExpirada) {
        Navigator.pop(context);
      }
      mostrarAviso(context, e.toString(), error: true);
    }
  }

  Widget _imagen(String campo, String etiqueta, {double relacion = 16 / 10, double ancho = 1600}) => SelectorImagen(
        etiqueta: etiqueta,
        rutaActual: _actual(campo),
        nueva: _imagenes[campo],
        relacion: relacion,
        anchoMaximo: ancho,
        alElegir: (img) => setState(() => _imagenes[campo] = img),
      );

  @override
  Widget build(BuildContext context) {
    final id = widget.fila?['id_inicio'];
    return FormularioEditor(
      titulo: id == null ? 'Crear contenido inicial' : 'Editar contenido #$id',
      guardando: _guardando,
      alGuardar: _guardar,
      hijos: [
        const Leyenda('Banner y multimedia'),
        _imagen('banner_inicio', 'Imagen del banner', relacion: 3, ancho: 2400),
        if (widget.controlaTema)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Este banner se muestra en todas las pantallas y de él sale la paleta de colores de la app (se calcula al pulsar Guardar).',
              style: TextStyle(color: pz.amarillo, fontSize: 13),
            ),
          ),
        _imagen('carru_1', 'Carrusel imagen 1'),
        _imagen('carru_2', 'Carrusel imagen 2'),
        _imagen('carru_3', 'Carrusel imagen 3'),
        CampoEditor(
          etiqueta: 'URL video de YouTube',
          controlador: _textos['url_video_inicio']!,
          maximo: 200,
          teclado: TextInputType.url,
          ayuda: 'Acepta enlaces de YouTube normales, youtu.be o shorts; se convierten automáticamente.',
        ),
        const Leyenda('Acordeón'),
        for (var i = 1; i <= 5; i++) ...[
          CampoEditor(etiqueta: 'Título $i', controlador: _textos['acor${i}_titulo_inicio']!, maximo: 150),
          CampoEditor(etiqueta: 'Texto $i', controlador: _textos['acor${i}_texto_inicio']!, lineas: 2, maximo: 500),
        ],
        const Leyenda('Secciones colapsables'),
        for (var i = 1; i <= 3; i++) ...[
          CampoEditor(etiqueta: 'Título $i', controlador: _textos['colapsar${i}_titulo_inicio']!, maximo: 150),
          CampoEditor(etiqueta: 'Texto $i', controlador: _textos['colapsar${i}_texto_inicio']!, lineas: 2, maximo: 500),
        ],
        const Leyenda('Contacto'),
        CampoEditor(
          etiqueta: 'Número de WhatsApp',
          controlador: _textos['numero_whatsapp']!,
          sugerencia: '573132345685',
          maximo: 20,
          teclado: TextInputType.phone,
        ),
      ],
    );
  }
}
