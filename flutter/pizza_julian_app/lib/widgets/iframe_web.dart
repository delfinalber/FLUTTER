import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _registrados = <String>{};

Widget? iframeWeb(String url) {
  final tipo = 'iframe-${url.hashCode}';
  if (_registrados.add(tipo)) {
    ui_web.platformViewRegistry.registerViewFactory(tipo, (int id) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..allowFullscreen = true;
      iframe.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      return iframe;
    });
  }
  return HtmlElementView(viewType: tipo);
}
