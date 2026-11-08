import 'package:flutter/material.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import '../widgets/comunes.dart';

// Pantalla pública de Productos (productos/productos.php): tarjetas con carrusel de 3 imágenes
class PantallaProductos extends StatefulWidget {
  const PantallaProductos({super.key});

  @override
  State<PantallaProductos> createState() => _PantallaProductosState();
}

class _PantallaProductosState extends State<PantallaProductos> {
  List<Map<String, dynamic>>? _productos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final productos = await api.productos();
      if (mounted) setState(() => (_productos = productos, _error = null));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productos = _productos;
    return PaginaPizzeria(
      seccion: Seccion.productos,
      alRefrescar: _cargar,
      hijos: [
        if (productos == null)
          EstadoCarga(error: _error, alReintentar: _cargar)
        else if (productos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Todavía no hay productos publicados.', textAlign: TextAlign.center),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, restricciones) {
                // 1 columna en celular, 2 en tablet, 4 en pantallas grandes (como la grilla de la web)
                final columnas = restricciones.maxWidth >= 992 ? 4 : (restricciones.maxWidth >= 576 ? 2 : 1);
                const espacio = 16.0;
                final ancho = (restricciones.maxWidth - espacio * (columnas - 1)) / columnas;
                return Wrap(
                  spacing: espacio,
                  runSpacing: espacio,
                  children: [for (final p in productos) SizedBox(width: ancho, child: TarjetaProducto(producto: p))],
                );
              },
            ),
          ),
      ],
    );
  }
}

class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto});

  final Map<String, dynamic> producto;

  String _campo(String clave) => (producto[clave] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final titulo = _campo('card_title_productos');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pz.negro,
        border: Border.all(color: mezclar(pz.rojoProfundo, 25, pz.negroSuave)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Carrusel(
            key: ValueKey('carrusel-${producto['id_producto']}'),
            imagenes: [_campo('img1_carru_productos'), _campo('img2_carru_productos'), _campo('img3_carru_productos')],
            intervalo: const Duration(seconds: 3),
            relacion: 1,
            ajuste: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(titulo, textAlign: TextAlign.center, style: TextStyle(color: pz.blanco, fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(_campo('card_texto_productos'), textAlign: TextAlign.center, style: TextStyle(color: pz.gris)),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => abrirWhatsapp(context, 'Hola, quiero pedir la $titulo de PIZZA JULIAN'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pz.blanco,
                    side: BorderSide(color: pz.blanco),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: Text(_campo('btn_primary_productos')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
