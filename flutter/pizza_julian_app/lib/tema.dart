import 'package:flutter/material.dart';

import 'api.dart';

// Paleta de colores compartida por todas las pantallas (equivale a las variables --pizza-* de tema.css).
// Sale del banner que se sube en el editor de Inicio.
class Paleta {
  const Paleta({
    required this.negro,
    required this.negroSuave,
    required this.naranja,
    required this.amarillo,
    required this.rojo,
    required this.rojoProfundo,
    required this.rojoVivo,
    required this.blanco,
    required this.gris,
  });

  final Color negro;
  final Color negroSuave;
  final Color naranja;
  final Color amarillo;
  final Color rojo;
  final Color rojoProfundo;
  final Color rojoVivo;
  final Color blanco;
  final Color gris;

  static const porDefecto = Paleta(
    negro: Color(0xFF0F090A),
    negroSuave: Color(0xFF1A1113),
    naranja: Color(0xFFFF8B1A),
    amarillo: Color(0xFFFFC21A),
    rojo: Color(0xFFD90A0A),
    rojoProfundo: Color(0xFF8F0909),
    rojoVivo: Color(0xFFFF2E2E),
    blanco: Color(0xFFF7F5F3),
    gris: Color(0xFFE7E2DE),
  );

  static Color? _color(Object? hex) {
    if (hex is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return null;
    }
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  static Paleta desdeJson(Map<String, dynamic> datos) {
    const d = porDefecto;
    return Paleta(
      negro: _color(datos['negro']) ?? d.negro,
      negroSuave: _color(datos['negro-suave']) ?? d.negroSuave,
      naranja: _color(datos['naranja']) ?? d.naranja,
      amarillo: _color(datos['amarillo']) ?? d.amarillo,
      rojo: _color(datos['rojo']) ?? d.rojo,
      rojoProfundo: _color(datos['rojo-profundo']) ?? d.rojoProfundo,
      rojoVivo: _color(datos['rojo-vivo']) ?? d.rojoVivo,
      blanco: _color(datos['blanco']) ?? d.blanco,
      gris: _color(datos['gris']) ?? d.gris,
    );
  }
}

// Igual que color-mix(in srgb, a pct%, b) de CSS
Color mezclar(Color a, double porcentajeA, Color b) => Color.lerp(b, a, porcentajeA / 100)!;

// Banner + paleta actuales. Se vuelve a consultar al abrir cada pantalla y al regresar a la app,
// así cuando el editor cambia el banner, toda la app toma los colores nuevos.
class TemaSitio extends ChangeNotifier {
  Paleta paleta = Paleta.porDefecto;
  String banner = 'inicio/banner.png';
  String whatsapp = '573132345685';
  String _version = '';

  Future<void> sincronizar() async {
    try {
      final datos = await api.tema();
      final version = (datos['version'] ?? '').toString();
      if (version == _version) {
        return;
      }
      _version = version;
      banner = (datos['banner'] ?? banner).toString();
      whatsapp = (datos['whatsapp'] ?? whatsapp).toString();
      paleta = Paleta.desdeJson(Map<String, dynamic>.from(datos['paleta'] as Map? ?? {}));
      notifyListeners();
    } catch (_) {
      // sin conexión: se mantiene la paleta actual
    }
  }
}

final temaSitio = TemaSitio();

// Atajo para leer la paleta dentro de los widgets
Paleta get pz => temaSitio.paleta;
