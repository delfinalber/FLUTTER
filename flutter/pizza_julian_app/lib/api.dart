import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

class ApiError implements Exception {
  ApiError(this.mensaje, [this.estado = 0]);

  final String mensaje;
  final int estado;

  bool get sesionExpirada => estado == 401;

  @override
  String toString() => mensaje;
}

// Sesión del editor de contenido: el token reemplaza la cookie de sesión de PHP
class Sesion extends ChangeNotifier {
  String? token;
  String? usuario;

  bool get activa => token != null;

  void iniciar(String nuevoToken, String nombre) {
    token = nuevoToken;
    usuario = nombre;
    notifyListeners();
  }

  void cerrar() {
    token = null;
    usuario = null;
    notifyListeners();
  }
}

final sesion = Sesion();

// Cliente del servidor pizza_julian_api
class Api {
  static const _tiempoEspera = Duration(seconds: 30);

  Map<String, String> get _cabeceras => {
        'content-type': 'application/json; charset=utf-8',
        if (sesion.token != null) 'authorization': 'Bearer ${sesion.token}',
      };

  Future<Map<String, dynamic>> _enviar(String metodo, String ruta, [Map<String, dynamic>? cuerpo]) async {
    final uri = Uri.parse('$apiUrl/api/$ruta');
    final http.Response respuesta;
    try {
      final peticion = http.Request(metodo, uri)..headers.addAll(_cabeceras);
      if (cuerpo != null) {
        peticion.body = jsonEncode(cuerpo);
      }
      respuesta = await http.Response.fromStream(await peticion.send().timeout(_tiempoEspera));
    } catch (_) {
      throw ApiError('Error de comunicación con el servidor.');
    }

    Map<String, dynamic> datos;
    try {
      datos = Map<String, dynamic>.from(jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map);
    } catch (_) {
      throw ApiError('Respuesta no válida del servidor.', respuesta.statusCode);
    }
    if (respuesta.statusCode >= 400 || datos['ok'] != true) {
      if (respuesta.statusCode == 401 && sesion.activa) {
        sesion.cerrar();
      }
      throw ApiError((datos['mensaje'] ?? 'No fue posible completar la operación.').toString(), respuesta.statusCode);
    }
    return datos;
  }

  List<Map<String, dynamic>> _lista(Object? valor) => (valor as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ---- público
  Future<Map<String, dynamic>> tema() => _enviar('GET', 'tema');

  Future<Map<String, String>> inicio() async {
    final datos = await _enviar('GET', 'inicio');
    return Map<String, dynamic>.from(datos['datos'] as Map).map((k, v) => MapEntry(k, (v ?? '').toString()));
  }

  Future<List<Map<String, dynamic>>> productos() async => _lista((await _enviar('GET', 'productos'))['productos']);

  Future<Map<String, dynamic>> contacto() => _enviar('GET', 'contacto');

  Future<String> enviarMensaje({required String correo, required String nombre, required String telefono, required String mensaje}) async {
    final datos = await _enviar('POST', 'contacto/mensaje', {'correo': correo, 'nombre': nombre, 'telefono': telefono, 'mensaje': mensaje});
    return datos['mensaje'].toString();
  }

  // ---- sesión
  Future<void> login(String usuario, String password) async {
    final datos = await _enviar('POST', 'login', {'usuario': usuario, 'password': password});
    sesion.iniciar(datos['token'].toString(), datos['usuario'].toString());
  }

  Future<void> logout() async {
    try {
      await _enviar('POST', 'logout');
    } catch (_) {
      // aunque falle la red, la sesión local se cierra
    }
    sesion.cerrar();
  }

  // ---- editores (requieren sesión). Las imágenes nuevas viajan en base64 dentro de "imagenes".
  Future<List<Map<String, dynamic>>> registrosInicio() async => _lista((await _enviar('GET', 'inicio/registros'))['registros']);

  Future<String> guardarInicio(int? id, Map<String, dynamic> datos) async =>
      (await _enviar(id == null ? 'POST' : 'PUT', id == null ? 'inicio' : 'inicio/$id', datos))['mensaje'].toString();

  Future<String> eliminarInicio(int id) async => (await _enviar('DELETE', 'inicio/$id'))['mensaje'].toString();

  Future<String> guardarProducto(int? id, Map<String, dynamic> datos) async =>
      (await _enviar(id == null ? 'POST' : 'PUT', id == null ? 'productos' : 'productos/$id', datos))['mensaje'].toString();

  Future<String> eliminarProducto(int id) async => (await _enviar('DELETE', 'productos/$id'))['mensaje'].toString();

  Future<String> guardarContacto(int? id, String url) async =>
      (await _enviar(id == null ? 'POST' : 'PUT', id == null ? 'contacto' : 'contacto/$id', {'url_contacto': url}))['mensaje'].toString();
}

final api = Api();
