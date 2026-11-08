import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Manejo de imágenes subidas desde los editores (equivalente a inicio/imagenes-editor.php)

const tamanoMaximoImagen = 5 * 1024 * 1024; // 5 MB por imagen

class ErrorImagen implements Exception {
  ErrorImagen(this.mensaje);
  final String mensaje;
}

final _aleatorio = Random.secure();

String _extension(img.ImageFormat formato) {
  switch (formato) {
    case img.ImageFormat.jpg:
      return 'jpg';
    case img.ImageFormat.png:
      return 'png';
    case img.ImageFormat.gif:
      return 'gif';
    case img.ImageFormat.webp:
      return 'webp';
    default:
      throw ErrorImagen('Imagen no válida: usa archivos JPG, PNG, GIF o WEBP de máximo 5 MB. No se guardaron cambios.');
  }
}

// Decodifica la imagen en base64 y valida tipo y tamaño (no se confía en la extensión que envía la app)
Uint8List decodificarImagen(String base64Imagen) {
  final Uint8List bytes;
  try {
    bytes = base64Decode(base64Imagen.contains(',') ? base64Imagen.split(',').last : base64Imagen);
  } on FormatException {
    throw ErrorImagen('Imagen no válida: usa archivos JPG, PNG, GIF o WEBP de máximo 5 MB. No se guardaron cambios.');
  }
  if (bytes.isEmpty || bytes.length > tamanoMaximoImagen) {
    throw ErrorImagen('Imagen no válida: usa archivos JPG, PNG, GIF o WEBP de máximo 5 MB. No se guardaron cambios.');
  }
  _extension(img.findFormatForData(bytes));
  return bytes;
}

// Guarda la imagen en media/<carpeta>/ con nombre aleatorio y devuelve la ruta relativa ("productos/producto_xxx.png")
Future<String> guardarImagen(Uint8List bytes, String carpetaMedia, String carpeta, String prefijo) async {
  final extension = _extension(img.findFormatForData(bytes));
  final sufijo = List.generate(8, (_) => _aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  final nombre = '$prefijo${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}$sufijo.$extension';
  final directorio = Directory('$carpetaMedia/$carpeta');
  await directorio.create(recursive: true);
  await File('${directorio.path}/$nombre').writeAsBytes(bytes, flush: true);
  return '$carpeta/$nombre';
}

// Ruta relativa segura dentro de una carpeta de media (evita "../")
bool rutaValida(String ruta, String carpeta) => RegExp('^$carpeta/[A-Za-z0-9._-]+\$').hasMatch(ruta);

Future<void> borrarArchivos(Iterable<String> rutas, String carpetaMedia, String carpeta, {Set<String> protegidas = const {}}) async {
  for (final ruta in rutas) {
    if (!rutaValida(ruta, carpeta) || protegidas.contains(ruta.split('/').last)) {
      continue;
    }
    final archivo = File('$carpetaMedia/$ruta');
    if (await archivo.exists()) {
      await archivo.delete();
    }
  }
}
