import 'package:flutter/material.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/editor.dart';

// Editor de la tabla `contacto` (contacto/contactos-formulario.php): URL del mapa de Google
class EditorContacto extends StatefulWidget {
  const EditorContacto({super.key});

  @override
  State<EditorContacto> createState() => _EditorContactoState();
}

class _EditorContactoState extends State<EditorContacto> {
  Map<String, dynamic>? _contacto;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    exigirSesion(context, Seccion.contacto);
    if (sesion.activa) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final contacto = await api.contacto();
      if (mounted) setState(() => (_contacto = contacto, _error = null));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _abrirFormulario() async {
    final mensaje = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FormularioContactoEditor(id: _contacto?['id_contacto'] as int?, url: (_contacto?['url_contacto'] ?? '').toString()),
      ),
    );
    if (mensaje != null && mounted) {
      setState(() => _mensaje = mensaje);
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacto = _contacto;
    final existe = contacto?['id_contacto'] != null;
    return PaginaPizzeria(
      seccion: Seccion.contacto,
      editor: true,
      alRefrescar: _cargar,
      hijos: [
        PanelEditor(
          titulo: 'Editor de Contenido - Contacto',
          descripcion: 'Administra el mapa de ubicación que se muestra en Contacto.',
          hijos: [
            if (_mensaje != null) Alerta(_mensaje!, alCerrar: () => setState(() => _mensaje = null)),
            if (contacto == null)
              EstadoCarga(error: _error, alReintentar: _cargar)
            else
              TarjetaEditor(
                hijo: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(existe ? 'Registro #${contacto['id_contacto']}' : 'Sin registro (se usa el mapa por defecto)',
                        style: TextStyle(color: pz.blanco, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(contacto['url_contacto'].toString(), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),
                    BotonEditar(
                      texto: existe ? 'Editar' : 'Crear URL del mapa',
                      icono: existe ? Icons.edit_square : Icons.add_circle_outline,
                      alPresionar: _abrirFormulario,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class FormularioContactoEditor extends StatefulWidget {
  const FormularioContactoEditor({super.key, required this.id, required this.url});

  final int? id;
  final String url;

  @override
  State<FormularioContactoEditor> createState() => _FormularioContactoEditorState();
}

class _FormularioContactoEditorState extends State<FormularioContactoEditor> {
  late final _url = TextEditingController(text: widget.url);
  bool _guardando = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // Si pegan el código <iframe> completo de Google Maps, se toma solo la URL del src
    var url = _url.text.trim();
    final src = RegExp(r'src="([^"]+)"').firstMatch(url);
    if (src != null) url = src.group(1)!;
    if (url.isEmpty) {
      mostrarAviso(context, 'Escriba la URL del mapa.', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      final mensaje = await api.guardarContacto(widget.id, url);
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

  @override
  Widget build(BuildContext context) {
    return FormularioEditor(
      titulo: widget.id == null ? 'Crear URL del mapa' : 'Editar mapa #${widget.id}',
      guardando: _guardando,
      alGuardar: _guardar,
      hijos: [
        const Leyenda('Mapa de ubicación'),
        CampoEditor(
          etiqueta: 'URL de Google Maps (embed)',
          controlador: _url,
          lineas: 4,
          maximo: 1000,
          teclado: TextInputType.url,
          ayuda: 'En Google Maps: Compartir > Insertar un mapa > Copiar HTML. Puede pegar el código completo o solo la URL.',
        ),
      ],
    );
  }
}
