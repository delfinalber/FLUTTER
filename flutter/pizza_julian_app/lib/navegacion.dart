import 'package:flutter/material.dart';

import 'pantallas/contacto.dart';
import 'pantallas/editor_contacto.dart';
import 'pantallas/editor_inicio.dart';
import 'pantallas/editor_productos.dart';
import 'pantallas/inicio.dart';
import 'pantallas/productos.dart';

enum Seccion { inicio, productos, contacto }

extension NombreSeccion on Seccion {
  String get titulo => switch (this) {
        Seccion.inicio => 'Inicio',
        Seccion.productos => 'Productos',
        Seccion.contacto => 'Contacto',
      };
}

Widget paginaDe(Seccion seccion, {bool editor = false}) => switch ((seccion, editor)) {
      (Seccion.inicio, false) => const PantallaInicio(),
      (Seccion.productos, false) => const PantallaProductos(),
      (Seccion.contacto, false) => const PantallaContacto(),
      (Seccion.inicio, true) => const EditorInicio(),
      (Seccion.productos, true) => const EditorProductos(),
      (Seccion.contacto, true) => const EditorContacto(),
    };

// Reemplaza la pantalla actual (como window.location.replace en la web): "Atrás" no vuelve a un editor protegido
void irA(BuildContext context, Seccion seccion, {bool editor = false}) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => paginaDe(seccion, editor: editor),
      transitionsBuilder: (_, animacion, __, hijo) => FadeTransition(opacity: animacion, child: hijo),
      transitionDuration: const Duration(milliseconds: 220),
    ),
    (_) => false,
  );
}
