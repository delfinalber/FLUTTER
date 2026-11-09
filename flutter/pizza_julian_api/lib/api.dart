import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'config.dart';
import 'imagenes.dart';
import 'paleta.dart';

// API REST que usa la app Flutter. Replica lo que hacen los .php de pizza-julian:
//   inicio/index.php + index-formulario.php, productos/*.php, contacto/*.php, login.php, logout.php y tema.php

const _bannerPorDefecto = 'inicio/banner.png';
const _urlMapaPorDefecto =
    "https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d18953.883843598873!2d-75.2785308969908!3d2.9410217172291766!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x8e3b7464ac59aa5b%3A0x7e513d68543b6eec!2sDomino's%20Pizza%20Las%20Brisas!5e0!3m2!1ses-419!2sco!4v1784748693148!5m2!1ses-419!2sco";
const _duracionSesion = Duration(hours: 8);

// Valores de respaldo si la tabla `inicio` aún no tiene registros (igual que index.php)
const _datosInicioPorDefecto = <String, String>{
  'banner_inicio': _bannerPorDefecto,
  'carru_1': 'inicio/1.jpeg',
  'carru_2': 'inicio/2.jpeg',
  'carru_3': 'inicio/3.jpeg',
  'url_video_inicio': 'https://www.youtube.com/embed/crdtrzZj3fo',
  'acor1_titulo_inicio': 'Margarita (Margherita)',
  'acor1_texto_inicio': 'La reina de las pizzas. Salsa de tomate, mozzarella fresca, albahaca y aceite de oliva.',
  'acor2_titulo_inicio': 'Cuatro Quesos (Quattro Formaggi)',
  'acor2_texto_inicio': 'Una mezcla de quesos fundidos, usualmente mozzarella, gorgonzola (azul), fontina y parmesano.',
  'acor3_titulo_inicio': 'Napolitana',
  'acor3_texto_inicio': 'Salsa de tomate, anchoas, ajo, orégano y aceite de oliva (tradicionalmente no lleva queso).',
  'acor4_titulo_inicio': 'Mexicana',
  'acor4_texto_inicio': 'Incluye carne molida o chorizo, frijoles negros, jalapeños, cebolla y un toque de aguacate o cilantro.',
  'acor5_titulo_inicio': 'Barbacoa (BBQ)',
  'acor5_texto_inicio': 'Sustituye la salsa de tomate por salsa barbacoa, acompañada de pollo, carne picada, cebolla y bacon.',
  'colapsar1_titulo_inicio': 'Vegetariana',
  'colapsar1_texto_inicio': 'Cubierta de vegetales frescos o salteados, como pimientos, cebolla, champiñones, aceitunas y tomates cherry.',
  'colapsar2_titulo_inicio': 'Funghi (Champiñones)',
  'colapsar2_texto_inicio': 'Base de mozzarella con abundantes hongos salteados, a veces con un toque de aceite de trufa.',
  'colapsar3_titulo_inicio': 'Cuatro Estaciones (Quattro Stagioni)',
  'colapsar3_texto_inicio':
      'Dividida en cuatro secciones, cada una representando una estación con ingredientes distintos (por ejemplo: alcachofas, champiñones, jamón y albahaca).',
  'numero_whatsapp': '573132345685',
};

const _camposImagenInicio = ['banner_inicio', 'carru_1', 'carru_2', 'carru_3'];
const _camposTextoInicio = [
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
// Imágenes que la app usa como respaldo: nunca se borran
const _imagenesProtegidasInicio = {'banner.png', '1.jpeg', '2.jpeg', '3.jpeg'};

const _camposImagenProductos = ['img1_carru_productos', 'img2_carru_productos', 'img3_carru_productos'];
const _camposTextoProductos = ['card_title_productos', 'card_texto_productos', 'btn_primary_productos'];

// Longitud máxima de cada campo de texto (igual a la columna VARCHAR de PostgreSQL)
int _limiteCampo(String campo) {
  if (campo == 'numero_whatsapp') return 20;
  if (campo == 'url_video_inicio' || campo == 'card_title_productos' || campo == 'btn_primary_productos') return 200;
  if (campo.contains('_titulo_')) return 150;
  return 500;
}

// Convierte enlaces de YouTube (watch, youtu.be, shorts) al formato /embed/
String normalizarUrlYoutubeEmbed(String url) {
  url = url.trim();
  final coincidencia = RegExp(r'(?:youtu\.be/|youtube\.com/(?:embed/|watch\?v=|shorts/))([A-Za-z0-9_-]{6,})', caseSensitive: false).firstMatch(url);
  return coincidencia == null ? url : 'https://www.youtube.com/embed/${coincidencia.group(1)}';
}

class _Intentos {
  int fallidos = 0;
  DateTime bloqueoHasta = DateTime.fromMillisecondsSinceEpoch(0);
}

class PizzaJulianApi {
  PizzaJulianApi(this.config, this.db);

  final Config config;
  final Pool db;
  final _intentosPorIp = <String, _Intentos>{};
  final _aleatorio = Random.secure();

  Handler get handler {
    final router = Router()
      ..get('/api/salud', (Request r) => _json({'ok': true}))
      ..get('/api/tema', _tema)
      ..post('/api/login', _login)
      ..post('/api/logout', _logout)
      ..get('/api/sesion', _sesion)
      ..get('/api/inicio', _inicioPublico)
      ..get('/api/inicio/registros', _inicioRegistros)
      ..post('/api/inicio', (Request r) => _guardarInicio(r, null))
      ..put('/api/inicio/<id>', (Request r, String id) => _guardarInicio(r, int.tryParse(id) ?? 0))
      ..delete('/api/inicio/<id>', _eliminarInicio)
      ..get('/api/productos', _productos)
      ..post('/api/productos', (Request r) => _guardarProducto(r, null))
      ..put('/api/productos/<id>', (Request r, String id) => _guardarProducto(r, int.tryParse(id) ?? 0))
      ..delete('/api/productos/<id>', _eliminarProducto)
      ..get('/api/contacto', _contacto)
      ..post('/api/contacto', (Request r) => _guardarContacto(r, null))
      ..put('/api/contacto/<id>', (Request r, String id) => _guardarContacto(r, int.tryParse(id) ?? 0))
      ..post('/api/contacto/mensaje', _mensajeContacto)
      ..mount('/media/', createStaticHandler(config.carpetaMedia));

    return const Pipeline().addMiddleware(logRequests()).addMiddleware(_cors()).addMiddleware(_errores()).addHandler(router.call);
  }

  // ------------------------------------------------------------------ utilidades

  Response _json(Object datos, {int estado = 200}) => Response(
        estado,
        body: jsonEncode(datos),
        headers: {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store'},
      );

  Response _error(String mensaje, {int estado = 400}) => _json({'ok': false, 'mensaje': mensaje}, estado: estado);

  Middleware _cors() => (inner) => (request) async {
        const cabeceras = {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'access-control-allow-headers': 'content-type, authorization',
        };
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: cabeceras);
        }
        final respuesta = await inner(request);
        return respuesta.change(headers: cabeceras);
      };

  Middleware _errores() => (inner) => (request) async {
        try {
          return await inner(request);
        } on ErrorImagen catch (e) {
          return _error(e.mensaje, estado: 422);
        } on FormatException {
          return _error('Datos enviados no válidos.');
        } catch (e, pila) {
          stderr.writeln('Error en ${request.method} ${request.url}: $e\n$pila');
          return _error('No fue posible completar la operación.', estado: 500);
        }
      };

  Future<Map<String, dynamic>> _cuerpo(Request request) async {
    final texto = await request.readAsString();
    final datos = texto.isEmpty ? <String, dynamic>{} : jsonDecode(texto);
    if (datos is! Map<String, dynamic>) {
      throw const FormatException();
    }
    return datos;
  }

  String _texto(Map<String, dynamic> datos, String clave) => (datos[clave] ?? '').toString().trim();

  Map<String, dynamic> _fila(ResultRow fila) => fila.toColumnMap().map((clave, valor) => MapEntry(clave, valor is DateTime ? valor.toIso8601String() : valor));

  Future<List<Map<String, dynamic>>> _consulta(String sql, [Map<String, dynamic>? parametros]) async {
    final resultado = await db.execute(Sql.named(sql), parameters: parametros);
    return resultado.map(_fila).toList();
  }

  // Devuelve el id del usuario si el token "Authorization: Bearer ..." es válido
  Future<int?> _usuarioAutenticado(Request request) async {
    final cabecera = request.headers['authorization'] ?? '';
    if (!cabecera.startsWith('Bearer ')) {
      return null;
    }
    final token = cabecera.substring(7).trim();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      return null;
    }
    final filas = await _consulta('SELECT id_usuario FROM sesion_api WHERE token = @token AND expira > now()', {'token': token});
    return filas.isEmpty ? null : filas.first['id_usuario'] as int;
  }

  Response _noAutorizado() => _error('La sesión expiró, inicie sesión nuevamente.', estado: 401);

  // ------------------------------------------------------------------ tema (banner y paleta)

  Future<Map<String, dynamic>> _datosTema() async {
    var banner = _bannerPorDefecto;
    var whatsapp = _datosInicioPorDefecto['numero_whatsapp']!;
    Map<String, String> paleta = paletaPorDefecto;
    final filas = await _consulta('SELECT banner_inicio, paleta_banner, numero_whatsapp FROM inicio ORDER BY id_inicio ASC LIMIT 1');
    if (filas.isNotEmpty) {
      final numero = (filas.first['numero_whatsapp'] as String).replaceAll(RegExp(r'\D'), '');
      if (numero.isNotEmpty) {
        whatsapp = numero;
      }
      final valor = (filas.first['banner_inicio'] as String).trim();
      if (rutaValida(valor, 'inicio')) {
        banner = valor;
      }
      try {
        paleta = normalizarPaleta(jsonDecode(filas.first['paleta_banner'] as String)) ?? paletaPorDefecto;
      } on FormatException {
        paleta = paletaPorDefecto;
      }
    }
    final version = (banner + jsonEncode(paleta) + whatsapp).hashCode.toRadixString(16);
    return {'banner': banner, 'paleta': paleta, 'version': version, 'whatsapp': whatsapp};
  }

  Future<Response> _tema(Request request) async => _json({'ok': true, ...await _datosTema()});

  // ------------------------------------------------------------------ sesión

  Future<Response> _login(Request request) async {
    final info = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    final ip = info?.remoteAddress.address ?? 'desconocida';
    final intentos = _intentosPorIp.putIfAbsent(ip, _Intentos.new);

    // Bloqueo temporal tras varios intentos fallidos (mitiga fuerza bruta)
    if (DateTime.now().isBefore(intentos.bloqueoHasta)) {
      return _error('Demasiados intentos fallidos. Intente de nuevo en unos minutos.', estado: 429);
    }

    final datos = await _cuerpo(request);
    final usuario = _texto(datos, 'usuario');
    final password = (datos['password'] ?? '').toString();
    if (usuario.isEmpty || password.isEmpty || usuario.length > 200 || password.length > 200) {
      return _error('Usuario y contraseña son obligatorios.');
    }

    // crypt() de pgcrypto compara contra el hash bcrypt guardado, nunca en texto plano
    final filas = await _consulta(
      'SELECT id_usuario, usuario FROM usuario WHERE usuario = @usuario AND password = crypt(@password, password) LIMIT 1',
      {'usuario': usuario, 'password': password},
    );
    if (filas.isEmpty) {
      intentos.fallidos++;
      if (intentos.fallidos >= 5) {
        intentos.bloqueoHasta = DateTime.now().add(const Duration(minutes: 5));
        intentos.fallidos = 0;
      }
      return _error('Usuario o contraseña incorrectos.', estado: 401);
    }
    _intentosPorIp.remove(ip);

    final token = List.generate(32, (_) => _aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await db.execute('DELETE FROM sesion_api WHERE expira <= now()');
    await db.execute(
      Sql.named('INSERT INTO sesion_api (token, id_usuario, expira) VALUES (@token, @id, @expira)'),
      parameters: {'token': token, 'id': filas.first['id_usuario'], 'expira': DateTime.now().toUtc().add(_duracionSesion)},
    );
    return _json({'ok': true, 'mensaje': 'Inicio de sesión correcto.', 'token': token, 'usuario': filas.first['usuario']});
  }

  Future<Response> _logout(Request request) async {
    final cabecera = request.headers['authorization'] ?? '';
    if (cabecera.startsWith('Bearer ')) {
      await db.execute(Sql.named('DELETE FROM sesion_api WHERE token = @token'), parameters: {'token': cabecera.substring(7).trim()});
    }
    return _json({'ok': true, 'mensaje': 'Sesión cerrada.'});
  }

  Future<Response> _sesion(Request request) async => await _usuarioAutenticado(request) == null ? _noAutorizado() : _json({'ok': true});

  // ------------------------------------------------------------------ inicio

  Future<Response> _inicioPublico(Request request) async {
    final datos = Map<String, String>.of(_datosInicioPorDefecto);
    final filas = await _consulta('SELECT * FROM inicio ORDER BY id_inicio ASC LIMIT 1');
    if (filas.isNotEmpty) {
      for (final campo in datos.keys.toList()) {
        final valor = (filas.first[campo] ?? '').toString().trim();
        if (valor.isNotEmpty) {
          datos[campo] = valor;
        }
      }
    }
    datos['url_video_inicio'] = normalizarUrlYoutubeEmbed(datos['url_video_inicio']!);
    datos['numero_whatsapp'] = datos['numero_whatsapp']!.replaceAll(RegExp(r'\D'), '');
    return _json({'ok': true, 'datos': datos});
  }

  Future<Response> _inicioRegistros(Request request) async {
    if (await _usuarioAutenticado(request) == null) return _noAutorizado();
    return _json({'ok': true, 'registros': await _consulta('SELECT * FROM inicio ORDER BY id_inicio ASC')});
  }

  // Rutas de imagen que siguen usándose en alguna fila de la tabla (para no borrarlas)
  Future<Set<String>> _imagenesEnUso(String tabla, List<String> columnas) async {
    final filas = await _consulta('SELECT ${columnas.join(', ')} FROM $tabla');
    return {
      for (final fila in filas)
        for (final c in columnas) (fila[c] ?? '').toString()
    };
  }

  Future<void> _borrarNoUsadas(String tabla, List<String> columnas, Iterable<String> anteriores, String carpeta, Set<String> protegidas) async {
    final enUso = await _imagenesEnUso(tabla, columnas);
    await borrarArchivos(anteriores.where((r) => !enUso.contains(r)), config.carpetaMedia, carpeta, protegidas: protegidas);
  }

  // Decodifica todas las imágenes nuevas antes de guardar nada (si una falla, no se guarda ninguna)
  Map<String, Uint8List> _imagenesNuevas(Map<String, dynamic> datos, List<String> campos) {
    final imagenes = datos['imagenes'];
    final nuevas = <String, Uint8List>{};
    if (imagenes is Map) {
      for (final campo in campos) {
        final valor = imagenes[campo];
        if (valor is String && valor.isNotEmpty) {
          nuevas[campo] = decodificarImagen(valor);
        }
      }
    }
    return nuevas;
  }

  // Devuelve un error 422 si algún campo de texto supera la longitud de su columna
  Response? _validarLongitudes(Map<String, dynamic> datos, List<String> campos) {
    for (final campo in campos) {
      if (_texto(datos, campo).length > _limiteCampo(campo)) {
        return _error('El campo "$campo" supera ${_limiteCampo(campo)} caracteres. No se guardaron cambios.', estado: 422);
      }
    }
    return null;
  }

  Future<Response> _guardarInicio(Request request, int? id) async {
    if (await _usuarioAutenticado(request) == null) return _noAutorizado();
    final datos = await _cuerpo(request);
    final errorLongitud = _validarLongitudes(datos, _camposTextoInicio);
    if (errorLongitud != null) return errorLongitud;

    Map<String, dynamic> actual = {};
    if (id != null) {
      final filas = await _consulta('SELECT * FROM inicio WHERE id_inicio = @id', {'id': id});
      if (filas.isEmpty) return _error('El registro no existe.', estado: 404);
      actual = filas.first;
    }

    final nuevas = _imagenesNuevas(datos, _camposImagenInicio);
    final valores = <String, dynamic>{};
    final guardadas = <String>[];
    try {
      for (final campo in _camposImagenInicio) {
        valores[campo] = nuevas.containsKey(campo)
            ? (guardadas..add(await guardarImagen(nuevas[campo]!, config.carpetaMedia, 'inicio', 'inicio_'))).last
            : (actual[campo] ?? '').toString();
      }
      // Con un banner nuevo se guarda la paleta calculada de esa imagen; si no, se conserva la actual
      if (nuevas.containsKey('banner_inicio')) {
        final paleta = extraerPaletaBanner(nuevas['banner_inicio']!);
        valores['paleta_banner'] = paleta == null ? '' : jsonEncode(paleta);
      } else {
        valores['paleta_banner'] = (actual['paleta_banner'] ?? '').toString();
      }
      for (final campo in _camposTextoInicio) {
        var valor = _texto(datos, campo);
        if (campo == 'url_video_inicio') valor = normalizarUrlYoutubeEmbed(valor);
        if (campo == 'numero_whatsapp') valor = valor.replaceAll(RegExp(r'\D'), '');
        valores[campo] = valor;
      }

      final columnas = valores.keys.toList();
      if (id == null) {
        await db.execute(
          Sql.named('INSERT INTO inicio (${columnas.join(', ')}) VALUES (${columnas.map((c) => '@$c').join(', ')})'),
          parameters: valores,
        );
      } else {
        await db.execute(
          Sql.named('UPDATE inicio SET ${columnas.map((c) => '$c = @$c').join(', ')}, actualizado = now() WHERE id_inicio = @id_inicio'),
          parameters: {...valores, 'id_inicio': id},
        );
      }
    } catch (_) {
      // No se guarda nada: se descartan los archivos que sí alcanzaron a guardarse
      await borrarArchivos(guardadas, config.carpetaMedia, 'inicio');
      rethrow;
    }

    if (id != null) {
      // La imagen antigua que fue reemplazada se borra del almacenamiento
      await _borrarNoUsadas('inicio', _camposImagenInicio, _camposImagenInicio.map((c) => (actual[c] ?? '').toString()), 'inicio', _imagenesProtegidasInicio);
    }
    return _json({'ok': true, 'mensaje': id == null ? 'Contenido creado correctamente.' : 'Contenido actualizado correctamente.'});
  }

  Future<Response> _eliminarInicio(Request request, String idTexto) async {
    if (await _usuarioAutenticado(request) == null) return _noAutorizado();
    final id = int.tryParse(idTexto) ?? 0;
    final filas = await _consulta('SELECT * FROM inicio WHERE id_inicio = @id', {'id': id});
    if (filas.isEmpty) return _error('El registro no existe.', estado: 404);
    await db.execute(Sql.named('DELETE FROM inicio WHERE id_inicio = @id'), parameters: {'id': id});
    await _borrarNoUsadas(
        'inicio', _camposImagenInicio, _camposImagenInicio.map((c) => (filas.first[c] ?? '').toString()), 'inicio', _imagenesProtegidasInicio);
    return _json({'ok': true, 'mensaje': 'Contenido eliminado correctamente.'});
  }

  // ------------------------------------------------------------------ productos

  Future<Response> _productos(Request request) async => _json({'ok': true, 'productos': await _consulta('SELECT * FROM productos ORDER BY id_producto ASC')});

  Future<Response> _guardarProducto(Request request, int? id) async {
    if (await _usuarioAutenticado(request) == null) return _noAutorizado();
    final datos = await _cuerpo(request);
    final errorLongitud = _validarLongitudes(datos, _camposTextoProductos);
    if (errorLongitud != null) return errorLongitud;

    Map<String, dynamic> actual = {};
    if (id != null) {
      final filas = await _consulta('SELECT * FROM productos WHERE id_producto = @id', {'id': id});
      if (filas.isEmpty) return _error('El producto no existe.', estado: 404);
      actual = filas.first;
    }

    final nuevas = _imagenesNuevas(datos, _camposImagenProductos);
    for (final campo in _camposImagenProductos) {
      if (!nuevas.containsKey(campo) && (actual[campo] ?? '').toString().isEmpty) {
        return _error('Cada producto necesita las 3 imágenes del carrusel. No se guardaron cambios.', estado: 422);
      }
    }
    if (_texto(datos, 'card_title_productos').isEmpty) {
      return _error('El título del producto es obligatorio.', estado: 422);
    }

    final valores = <String, dynamic>{};
    final guardadas = <String>[];
    try {
      for (final campo in _camposImagenProductos) {
        valores[campo] = nuevas.containsKey(campo)
            ? (guardadas..add(await guardarImagen(nuevas[campo]!, config.carpetaMedia, 'productos', 'producto_'))).last
            : (actual[campo] ?? '').toString();
      }
      for (final campo in _camposTextoProductos) {
        valores[campo] = _texto(datos, campo);
      }
      final columnas = valores.keys.toList();
      if (id == null) {
        await db.execute(
          Sql.named('INSERT INTO productos (${columnas.join(', ')}) VALUES (${columnas.map((c) => '@$c').join(', ')})'),
          parameters: valores,
        );
      } else {
        await db.execute(
          Sql.named('UPDATE productos SET ${columnas.map((c) => '$c = @$c').join(', ')} WHERE id_producto = @id_producto'),
          parameters: {...valores, 'id_producto': id},
        );
      }
    } catch (_) {
      await borrarArchivos(guardadas, config.carpetaMedia, 'productos');
      rethrow;
    }

    if (id != null) {
      await _borrarNoUsadas('productos', _camposImagenProductos, _camposImagenProductos.map((c) => (actual[c] ?? '').toString()), 'productos', const {});
    }
    return _json({'ok': true, 'mensaje': id == null ? 'Producto creado correctamente.' : 'Producto actualizado correctamente.'});
  }

  Future<Response> _eliminarProducto(Request request, String idTexto) async {
    if (await _usuarioAutenticado(request) == null) return _noAutorizado();
    final id = int.tryParse(idTexto) ?? 0;
    final filas = await _consulta('SELECT * FROM productos WHERE id_producto = @id', {'id': id});
    if (filas.isEmpty) return _error('El producto no existe.', estado: 404);
    await db.execute(Sql.named('DELETE FROM productos WHERE id_producto = @id'), parameters: {'id': id});
    await _borrarNoUsadas('productos', _camposImagenProductos, _camposImagenProductos.map((c) => (filas.first[c] ?? '').toString()), 'productos', const {});
    return _json({'ok': true, 'mensaje': 'Producto eliminado correctamente.'});
  }

  // ------------------------------------------------------------------ contacto

  Future<Response> _contacto(Request request) async {
    final filas = await _consulta('SELECT * FROM contacto ORDER BY id_contacto ASC LIMIT 1');
    final fila = filas.isEmpty ? null : filas.first;
    final url = (fila?['url_contacto'] ?? '').toString().trim();
    return _json({
      'ok': true,
      'id_contacto': fila?['id_contacto'],
      'url_contacto': url.isEmpty ? _urlMapaPorDefecto : url,
    });
  }

  Future<Response> _guardarContacto(Request request, int? id) async {
    if (await _usuarioAutenticado(request) == null) return _noAutorizado();
    final url = _texto(await _cuerpo(request), 'url_contacto');
    if (url.isEmpty || !url.startsWith('https://')) {
      return _error('Escriba una URL de Google Maps válida (https://...).', estado: 422);
    }
    if (id == null) {
      await db.execute(Sql.named('INSERT INTO contacto (url_contacto) VALUES (@url)'), parameters: {'url': url});
      return _json({'ok': true, 'mensaje': 'URL del mapa creada correctamente.'});
    }
    final resultado = await db.execute(Sql.named('UPDATE contacto SET url_contacto = @url WHERE id_contacto = @id'), parameters: {'url': url, 'id': id});
    if (resultado.affectedRows == 0) return _error('El registro no existe.', estado: 404);
    return _json({'ok': true, 'mensaje': 'URL del mapa actualizada correctamente.'});
  }

  Future<Response> _mensajeContacto(Request request) async {
    final datos = await _cuerpo(request);
    final correo = _texto(datos, 'correo');
    final nombre = _texto(datos, 'nombre');
    final telefono = _texto(datos, 'telefono');
    final mensaje = _texto(datos, 'mensaje');

    final correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo);
    if (!correoValido || nombre.isEmpty || mensaje.isEmpty) {
      return _error('Por favor, completa el nombre, un correo válido y el mensaje.', estado: 422);
    }
    if (correo.length > 150 || nombre.length > 150 || telefono.length > 20 || mensaje.length > 500) {
      return _error('Algún campo supera la longitud permitida.', estado: 422);
    }

    await db.execute(
      Sql.named('INSERT INTO formulario_contacto (correo_formulario, nombre_formulario, telefono_formulario, mensaje_formulario) '
          'VALUES (@correo, @nombre, @telefono, @mensaje)'),
      parameters: {'correo': correo, 'nombre': nombre, 'telefono': telefono, 'mensaje': mensaje},
    );

    if (config.gmailClave.isEmpty) {
      stderr.writeln('No está configurada GMAIL_APP_PASSWORD: el mensaje se guardó pero no se envió por correo.');
      return _json({'ok': true, 'mensaje': 'Tu mensaje se guardó correctamente.'});
    }

    try {
      final correoSalida = Message()
        ..from = Address(config.gmailUsuario, 'Formulario PIZZERIA-JULIAN')
        ..recipients.add(config.correoDestino)
        ..headers = {'Reply-To': '$nombre <$correo>'}
        ..subject = 'Nuevo mensaje del formulario de contacto'
        ..text = 'Nombre: $nombre\nCorreo: $correo\nTeléfono: $telefono\n\nMensaje:\n$mensaje';
      await send(correoSalida, gmail(config.gmailUsuario, config.gmailClave));
    } catch (e) {
      stderr.writeln('Error SMTP del formulario de contacto: $e');
      return _error('La información se guardó, pero no se pudo enviar el correo.', estado: 502);
    }
    return _json({'ok': true, 'mensaje': 'Tu mensaje se envió correctamente.'});
  }
}
