import 'package:flutter/material.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';
import '../widgets/editor.dart';

// Editor de la tabla `productos` (productos/productos-formulario.php)
class EditorProductos extends StatefulWidget {
  const EditorProductos({super.key});

  @override
  State<EditorProductos> createState() => _EditorProductosState();
}

class _EditorProductosState extends State<EditorProductos> {
  List<Map<String, dynamic>>? _productos;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    exigirSesion(context, Seccion.productos);
    if (sesion.activa) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final productos = await api.productos();
      if (mounted) setState(() => (_productos = productos, _error = null));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  Future<void> _abrirFormulario(Map<String, dynamic>? producto) async {
    final mensaje = await Navigator.of(context).push<String>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => FormularioProducto(producto: producto)),
    );
    if (mensaje != null && mounted) {
      setState(() => _mensaje = mensaje);
      await _cargar();
    }
  }

  Future<void> _eliminar(int id) async {
    if (!await confirmar(context, '¿Eliminar este producto?')) return;
    try {
      final mensaje = await api.eliminarProducto(id);
      setState(() => _mensaje = mensaje);
      await _cargar();
    } catch (e) {
      if (mounted) manejarErrorEditor(context, Seccion.productos, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = _productos;
    return PaginaPizzeria(
      seccion: Seccion.productos,
      editor: true,
      alRefrescar: _cargar,
      hijos: [
        PanelEditor(
          titulo: 'Editor de Contenido - Productos',
          descripcion: 'Administra las tarjetas que se muestran en Productos: las 3 imágenes del carrusel, el título, el texto y el botón.',
          hijos: [
            if (_mensaje != null) Alerta(_mensaje!, alCerrar: () => setState(() => _mensaje = null)),
            Align(
              alignment: Alignment.centerLeft,
              child: BotonEditar(texto: 'Agregar producto', icono: Icons.add_circle_outline, alPresionar: () => _abrirFormulario(null)),
            ),
            const SizedBox(height: 14),
            if (productos == null)
              EstadoCarga(error: _error, alReintentar: _cargar)
            else if (productos.isEmpty)
              Text('Todavía no hay productos publicados.', style: TextStyle(color: pz.gris))
            else
              for (final p in productos) _tarjeta(p),
          ],
        ),
      ],
    );
  }

  Widget _tarjeta(Map<String, dynamic> p) {
    final id = p['id_producto'] as int;
    return TarjetaEditor(
      hijo: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(width: 84, height: 84, child: ImagenRed((p['img1_carru_productos'] ?? '').toString(), alto: 84)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#$id ${p['card_title_productos']}', style: TextStyle(color: pz.blanco, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text((p['card_texto_productos'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Text('Botón: ${p['btn_primary_productos']}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BotonEditar(texto: 'Editar', alPresionar: () => _abrirFormulario(p)),
                    BotonEliminar(alPresionar: () => _eliminar(id)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FormularioProducto extends StatefulWidget {
  const FormularioProducto({super.key, required this.producto});

  final Map<String, dynamic>? producto; // null = crear

  @override
  State<FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<FormularioProducto> {
  late final _titulo = TextEditingController(text: _actual('card_title_productos'));
  late final _texto = TextEditingController(text: _actual('card_texto_productos'));
  late final _boton = TextEditingController(text: widget.producto == null ? 'Pedir ahora' : _actual('btn_primary_productos'));
  final _imagenes = <String, ImagenElegida>{};
  bool _guardando = false;

  String _actual(String campo) => (widget.producto?[campo] ?? '').toString();

  @override
  void dispose() {
    _titulo.dispose();
    _texto.dispose();
    _boton.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // cada tarjeta necesita sus 3 imágenes de carrusel
    for (var i = 1; i <= 3; i++) {
      final campo = 'img${i}_carru_productos';
      if (!_imagenes.containsKey(campo) && _actual(campo).isEmpty) {
        mostrarAviso(context, 'Cada producto necesita las 3 imágenes del carrusel.', error: true);
        return;
      }
    }
    if (_titulo.text.trim().isEmpty) {
      mostrarAviso(context, 'El título del producto es obligatorio.', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      final mensaje = await api.guardarProducto(widget.producto?['id_producto'] as int?, {
        'card_title_productos': _titulo.text.trim(),
        'card_texto_productos': _texto.text.trim(),
        'btn_primary_productos': _boton.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final id = widget.producto?['id_producto'];
    return FormularioEditor(
      titulo: id == null ? 'Agregar producto' : 'Editar producto #$id',
      guardando: _guardando,
      alGuardar: _guardar,
      hijos: [
        const Leyenda('Carrusel del producto'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'La vista previa muestra cómo quedará cada imagen dentro de la tarjeta (recorte cuadrado). JPG, PNG, GIF o WEBP, máximo 5 MB.',
            style: TextStyle(color: pz.gris, fontSize: 13),
          ),
        ),
        for (var i = 1; i <= 3; i++)
          SelectorImagen(
            etiqueta: 'Imagen $i',
            rutaActual: _actual('img${i}_carru_productos'),
            nueva: _imagenes['img${i}_carru_productos'],
            relacion: 1,
            anchoMaximo: 1200,
            alElegir: (img) => setState(() => _imagenes['img${i}_carru_productos'] = img),
          ),
        const Leyenda('Contenido de la tarjeta'),
        CampoEditor(etiqueta: 'Título', controlador: _titulo, maximo: 200),
        CampoEditor(etiqueta: 'Texto', controlador: _texto, lineas: 3, maximo: 500),
        CampoEditor(etiqueta: 'Texto del botón', controlador: _boton, maximo: 200),
      ],
    );
  }
}
