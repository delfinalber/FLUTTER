import 'dart:io';

// Configuración del servidor: se lee de .env y las variables de entorno del sistema tienen prioridad
class Config {
  Config._(this._valores);

  final Map<String, String> _valores;

  static Config cargar([String ruta = '.env']) {
    final valores = <String, String>{};
    final archivo = File(ruta);
    if (archivo.existsSync()) {
      for (var linea in archivo.readAsLinesSync()) {
        linea = linea.trim();
        if (linea.isEmpty || linea.startsWith('#') || !linea.contains('=')) {
          continue;
        }
        final indice = linea.indexOf('=');
        final clave = linea.substring(0, indice).trim();
        var valor = linea.substring(indice + 1).trim();
        if (valor.length >= 2 && valor.startsWith('"') && valor.endsWith('"')) {
          valor = valor.substring(1, valor.length - 1);
        }
        valores[clave] = valor;
      }
    }
    valores.addAll(Platform.environment);
    return Config._(valores);
  }

  String texto(String clave, [String porDefecto = '']) {
    final valor = _valores[clave];
    return (valor == null || valor.isEmpty) ? porDefecto : valor;
  }

  int entero(String clave, int porDefecto) => int.tryParse(texto(clave)) ?? porDefecto;

  String get dbHost => texto('DB_HOST', 'localhost');
  int get dbPort => entero('DB_PORT', 5432);
  String get dbName => texto('DB_NAME', 'pizza_julian');
  String get dbUser => texto('DB_USER', 'postgres');
  String get dbPassword => texto('DB_PASSWORD');
  int get puerto => entero('PORT', 8080);
  String get gmailUsuario => texto('GMAIL_USERNAME', 'delfin.alber@gmail.com');
  String get gmailClave => texto('GMAIL_APP_PASSWORD');
  String get correoDestino => texto('CORREO_DESTINO', 'delfin.alber@gmail.com');
  String get carpetaMedia => texto('MEDIA_DIR', 'media');
}
