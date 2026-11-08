import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

// Paleta del sitio: misma lógica que inicio/tema.js (extraerPaletaBanner) de la página web,
// pero calculada en el servidor al guardar un banner nuevo.

const paletaPorDefecto = <String, String>{
  'negro': '#0f090a',
  'negro-suave': '#1a1113',
  'naranja': '#ff8b1a',
  'amarillo': '#ffc21a',
  'rojo': '#d90a0a',
  'rojo-profundo': '#8f0909',
  'rojo-vivo': '#ff2e2e',
  'blanco': '#f7f5f3',
  'gris': '#e7e2de',
};

// Devuelve la paleta solo si trae todos los colores en formato #rrggbb; si no, null
Map<String, String>? normalizarPaleta(Object? datos) {
  if (datos is! Map) {
    return null;
  }
  final paleta = <String, String>{};
  final formato = RegExp(r'^#[0-9a-f]{6}$');
  for (final clave in paletaPorDefecto.keys) {
    final color = (datos[clave] ?? '').toString().trim().toLowerCase();
    if (!formato.hasMatch(color)) {
      return null;
    }
    paleta[clave] = color;
  }
  return paleta;
}

String _hslAHex(double h, double s, double l) {
  h = ((h % 360) + 360) % 360;
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - (((h / 60) % 2) - 1).abs());
  final m = l - c / 2;
  final List<double> rgb;
  if (h < 60) {
    rgb = [c, x, 0];
  } else if (h < 120) {
    rgb = [x, c, 0];
  } else if (h < 180) {
    rgb = [0, c, x];
  } else if (h < 240) {
    rgb = [0, x, c];
  } else if (h < 300) {
    rgb = [x, 0, c];
  } else {
    rgb = [c, 0, x];
  }
  return '#${rgb.map((v) => ((v + m) * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join()}';
}

double _luminancia(String hex) {
  final canales = [1, 3, 5].map((i) {
    final v = int.parse(hex.substring(i, i + 2), radix: 16) / 255;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }).toList();
  return 0.2126 * canales[0] + 0.7152 * canales[1] + 0.0722 * canales[2];
}

List<double> _rgbAHsl(double r, double g, double b) {
  final maximo = math.max(r, math.max(g, b));
  final minimo = math.min(r, math.min(g, b));
  var h = 0.0, s = 0.0;
  final l = (maximo + minimo) / 2;
  if (maximo != minimo) {
    final d = maximo - minimo;
    s = l > 0.5 ? d / (2 - maximo - minimo) : d / (maximo + minimo);
    if (maximo == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (maximo == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
  }
  return [h, s, l];
}

double _distanciaTono(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

// Ajusta la luminosidad hasta cumplir el contraste que necesita cada rol del diseño
String _colorConLuminancia(double tono, double saturacion, double luz, double paso, bool Function(double) cumple) {
  var hex = _hslAHex(tono, saturacion, luz);
  while (!cumple(_luminancia(hex)) && luz > 0.05 && luz < 0.9) {
    luz += paso;
    hex = _hslAHex(tono, saturacion, luz);
  }
  return hex;
}

// Devuelve la paleta con los tonos del banner, o null si la imagen no tiene colores definidos
Map<String, String>? extraerPaletaBanner(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null || original.width == 0) {
    return null;
  }
  const ancho = 160;
  final alto = math.max(1, (original.height * ancho / original.width).round());
  final imagen = img.copyResize(original, width: ancho, height: alto);

  // histograma de tonos (36 grupos de 10°) de los píxeles con color vivo
  final pesos = List<double>.filled(36, 0);
  for (final pixel in imagen) {
    final alfa = pixel.aNormalized.toDouble();
    final hsl = _rgbAHsl(pixel.rNormalized * alfa, pixel.gNormalized * alfa, pixel.bNormalized * alfa);
    if (hsl[1] > 0.45 && hsl[2] > 0.25 && hsl[2] < 0.75) {
      pesos[(hsl[0] / 10).floor() % 36] += hsl[1];
    }
  }
  final maximo = pesos.reduce(math.max);
  if (maximo < ancho * alto * 0.01) {
    return null; // imagen casi en blanco y negro: se usa la paleta por defecto
  }

  // tono principal: promedio circular del grupo dominante y sus vecinos
  final principal = pesos.indexOf(maximo);
  var sumaX = 0.0, sumaY = 0.0;
  for (final desplazamiento in [-1, 0, 1]) {
    final grupo = (principal + desplazamiento + 36) % 36;
    final angulo = (grupo * 10 + 5) * math.pi / 180;
    sumaX += math.cos(angulo) * pesos[grupo];
    sumaY += math.sin(angulo) * pesos[grupo];
  }
  final tonoNaranja = (math.atan2(sumaY, sumaX) * 180 / math.pi + 360) % 360;

  // entre los tonos importantes, el más oscuro hace de "rojo" y el más claro de "amarillo"
  double luzDeTono(double tono) => _luminancia(_hslAHex(tono, 1, 0.5));
  var tonoRojo = tonoNaranja, tonoAmarillo = tonoNaranja;
  for (var grupo = 0; grupo < 36; grupo++) {
    if (pesos[grupo] < maximo * 0.15) {
      continue;
    }
    final tono = grupo * 10 + 5.0;
    if (luzDeTono(tono) < luzDeTono(tonoRojo)) tonoRojo = tono;
    if (luzDeTono(tono) > luzDeTono(tonoAmarillo)) tonoAmarillo = tono;
  }
  if (_distanciaTono(tonoRojo, tonoNaranja) < 15) {
    tonoRojo = luzDeTono(tonoNaranja - 25) < luzDeTono(tonoNaranja + 25) ? tonoNaranja - 25 : tonoNaranja + 25;
  }
  if (_distanciaTono(tonoAmarillo, tonoNaranja) < 10) {
    tonoAmarillo = luzDeTono(tonoNaranja - 15) > luzDeTono(tonoNaranja + 15) ? tonoNaranja - 15 : tonoNaranja + 15;
  }

  // mismas saturaciones y luces que el diseño original: solo cambian los tonos
  final naranja = _colorConLuminancia(tonoNaranja, 1, 0.55, 0.02, (lum) => lum >= 0.38);
  return {
    'negro': _hslAHex(tonoRojo, 0.25, 0.047),
    'negro-suave': _hslAHex(tonoRojo, 0.21, 0.084),
    'naranja': naranja,
    'amarillo': _colorConLuminancia(tonoAmarillo, 1, 0.55, 0.02, (lum) => lum >= math.max(0.55, _luminancia(naranja) + 0.1)),
    'rojo': _colorConLuminancia(tonoRojo, 0.91, 0.445, -0.02, (lum) => lum <= 0.16),
    'rojo-profundo': _colorConLuminancia(tonoRojo, 0.88, 0.3, -0.02, (lum) => lum <= 0.07),
    'rojo-vivo': _colorConLuminancia(tonoRojo, 1, 0.59, -0.02, (lum) => lum <= 0.3),
    'blanco': _hslAHex(tonoNaranja, 0.2, 0.96),
    'gris': _hslAHex(tonoNaranja, 0.17, 0.89),
  };
}
