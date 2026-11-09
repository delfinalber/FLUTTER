// Mapa/página embebida: en el navegador se usa un <iframe>; en Android/iOS se usa WebView (ver contacto.dart)
export 'iframe_stub.dart' if (dart.library.js_interop) 'iframe_web.dart';
