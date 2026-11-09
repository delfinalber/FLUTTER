import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../api.dart';
import '../navegacion.dart';
import '../tema.dart';
import 'comunes.dart';

// Piezas compartidas por los tres editores de contenido (index-formulario.php, productos-formulario.php, contactos-formulario.php)

// Si no hay sesión (o expiró) se vuelve a la pantalla pública, como el header("Location: ...") de PHP
void exigirSesion(BuildContext context, Seccion seccion) {
  if (!sesion.activa) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) irA(context, seccion);
    });
  }
}

void manejarErrorEditor(BuildContext context, Seccion seccion, Object error) {
  final mensaje = error is ApiError ? error.mensaje : 'No fue posible completar la operación.';
  mostrarAviso(context, mensaje, error: true);
  if (error is ApiError && error.sesionExpirada) {
    irA(context, seccion);
  }
}

Future<bool> confirmar(BuildContext context, String pregunta) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => PointerInterceptor(
          child: AlertDialog(
        content: Text(pregunta),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: pz.rojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar'),
          ),
        ],
      )),
    ) ??
    false;

class PanelEditor extends StatelessWidget {
  const PanelEditor({super.key, required this.titulo, required this.descripcion, required this.hijos});

  final String titulo;
  final String descripcion;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: RadialGradient(center: Alignment.topCenter, radius: 1.4, colors: [mezclar(pz.negroSuave, 95, pz.rojoVivo), pz.negro], stops: const [0, 0.65]),
        border: Border.all(color: mezclar(mezclar(pz.negro, 85, pz.gris), 90, pz.rojoProfundo)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: pz.amarillo, size: 30),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: TextStyle(color: pz.blanco, fontSize: 22, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          Text(descripcion, style: TextStyle(color: pz.gris)),
          const SizedBox(height: 18),
          ...hijos,
        ],
      ),
    );
  }
}

class TarjetaEditor extends StatelessWidget {
  const TarjetaEditor({super.key, required this.hijo});

  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: pz.negroSuave,
        border: Border(
          left: BorderSide(color: pz.naranja, width: 4),
          top: BorderSide(color: mezclar(mezclar(pz.negroSuave, 90, pz.gris), 95, pz.rojo)),
          right: BorderSide(color: mezclar(mezclar(pz.negroSuave, 90, pz.gris), 95, pz.rojo)),
          bottom: BorderSide(color: mezclar(mezclar(pz.negroSuave, 90, pz.gris), 95, pz.rojo)),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(14),
      child: DefaultTextStyle.merge(style: TextStyle(color: pz.gris), child: hijo),
    );
  }
}

class BotonEditar extends StatelessWidget {
  const BotonEditar({super.key, required this.texto, required this.alPresionar, this.icono = Icons.edit_square, this.cargando = false});

  final String texto;
  final VoidCallback? alPresionar;
  final IconData icono;
  final bool cargando;

  @override
  Widget build(BuildContext context) => BotonGradiente(
        texto: texto,
        icono: icono,
        cargando: cargando,
        colores: [pz.naranja, pz.amarillo],
        borde: pz.naranja,
        colorTexto: mezclar(pz.naranja, 15, Colors.black),
        alPresionar: alPresionar,
      );
}

class BotonEliminar extends StatelessWidget {
  const BotonEliminar({super.key, required this.alPresionar});

  final VoidCallback? alPresionar;

  @override
  Widget build(BuildContext context) => BotonGradiente(
        texto: 'Eliminar',
        icono: Icons.delete_outline,
        colores: [pz.rojo, pz.rojoProfundo],
        borde: pz.rojo,
        alPresionar: alPresionar,
      );
}

// Pantalla de formulario (equivale al modal .editor-modal): encabezado, cuerpo con scroll y botones Cancelar / Guardar
class FormularioEditor extends StatelessWidget {
  const FormularioEditor({super.key, required this.titulo, required this.hijos, required this.alGuardar, this.guardando = false});

  final String titulo;
  final List<Widget> hijos;
  final VoidCallback alGuardar;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pz.negro,
      appBar: AppBar(
        backgroundColor: pz.negro,
        foregroundColor: pz.blanco,
        title: Text(titulo, style: TextStyle(color: pz.amarillo, fontWeight: FontWeight.w700)),
        shape: Border(top: BorderSide(color: pz.naranja, width: 4)),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: ImagenRed(temaSitio.banner)),
          Positioned.fill(child: Container(color: pz.negro.withAlpha(237))),
          ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: hijos),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: pz.negro,
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: guardando ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(backgroundColor: const Color(0xFF6C757D), foregroundColor: Colors.white),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
              BotonEditar(texto: 'Guardar', icono: Icons.save, cargando: guardando, alPresionar: alGuardar),
            ],
          ),
        ),
      ),
    );
  }
}

class Leyenda extends StatelessWidget {
  const Leyenda(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16, bottom: 12),
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: mezclar(mezclar(pz.negro, 85, pz.rojo), 85, pz.gris)))),
        child: Text(texto, style: TextStyle(color: pz.amarillo, fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class CampoEditor extends StatelessWidget {
  const CampoEditor({super.key, required this.etiqueta, required this.controlador, this.lineas = 1, this.maximo, this.sugerencia, this.ayuda, this.teclado});

  final String etiqueta;
  final TextEditingController controlador;
  final int lineas;
  final int? maximo;
  final String? sugerencia;
  final String? ayuda;
  final TextInputType? teclado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(color: pz.gris, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: controlador,
            minLines: lineas,
            maxLines: lineas == 1 ? 1 : lineas + 3,
            maxLength: maximo,
            keyboardType: teclado,
            style: TextStyle(color: mezclar(pz.negro, 90, pz.naranja)),
            decoration: InputDecoration(
              hintText: sugerencia,
              helperText: ayuda,
              helperMaxLines: 3,
              helperStyle: TextStyle(color: pz.gris),
              counterStyle: TextStyle(color: pz.gris),
              filled: true,
              fillColor: mezclar(pz.naranja, 6, pz.blanco),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: pz.naranja, width: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

// Imagen elegida desde la galería y lista para enviarse en base64
class ImagenElegida {
  ImagenElegida(this.bytes);

  final Uint8List bytes;

  String get base64 => base64Encode(bytes);
}

// Selector de imagen con vista previa: muestra la actual del servidor o la nueva elegida
class SelectorImagen extends StatelessWidget {
  const SelectorImagen({
    super.key,
    required this.etiqueta,
    required this.rutaActual,
    required this.nueva,
    required this.alElegir,
    this.relacion = 16 / 9,
    this.anchoMaximo = 1600,
  });

  final String etiqueta;
  final String rutaActual;
  final ImagenElegida? nueva;
  final ValueChanged<ImagenElegida> alElegir;
  final double relacion;
  final double anchoMaximo;

  static const tamanoMaximo = 5 * 1024 * 1024;

  Future<void> _elegir(BuildContext context) async {
    try {
      final archivo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: anchoMaximo, imageQuality: 85);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      if (bytes.length > tamanoMaximo) {
        if (context.mounted) mostrarAviso(context, 'La imagen supera 5 MB.', error: true);
        return;
      }
      alElegir(ImagenElegida(bytes));
    } catch (_) {
      if (context.mounted) mostrarAviso(context, 'No fue posible abrir la galería.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(etiqueta, style: TextStyle(color: pz.gris, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AspectRatio(
              aspectRatio: relacion,
              child: Container(
                color: pz.negroSuave,
                child: nueva != null
                    ? Image.memory(nueva!.bytes, fit: BoxFit.cover)
                    : rutaActual.isNotEmpty
                        ? ImagenRed(rutaActual)
                        : Center(child: Text('Sin imagen', style: TextStyle(color: pz.gris))),
              ),
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _elegir(context),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(nueva == null ? 'Elegir imagen' : 'Cambiar imagen (nueva seleccionada)'),
            style: OutlinedButton.styleFrom(foregroundColor: pz.amarillo, side: BorderSide(color: pz.naranja)),
          ),
        ],
      ),
    );
  }
}
