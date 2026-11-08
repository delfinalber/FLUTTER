import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pizza_julian_app/pantallas/inicio.dart';
import 'package:pizza_julian_app/tema.dart';

void main() {
  test('convierte enlaces de YouTube al id del video', () {
    expect(idYoutube('https://www.youtube.com/embed/crdtrzZj3fo'), 'crdtrzZj3fo');
    expect(idYoutube('https://youtu.be/crdtrzZj3fo'), 'crdtrzZj3fo');
    expect(idYoutube('https://www.youtube.com/watch?v=crdtrzZj3fo'), 'crdtrzZj3fo');
    expect(idYoutube('no es un video'), isNull);
  });

  test('lee la paleta del servidor y usa la de respaldo si falta un color', () {
    final paleta = Paleta.desdeJson({'naranja': '#ff0000', 'rojo': 'malo'});
    expect(paleta.naranja, const Color(0xFFFF0000));
    expect(paleta.rojo, Paleta.porDefecto.rojo);
  });

  testWidgets('el acordeón abre un elemento a la vez', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AcordeonPizzeria(elementos: [('Uno', 'Texto uno'), ('Dos', 'Texto dos')])),
    ));
    expect(find.textContaining('Texto uno'), findsOneWidget);
    expect(find.textContaining('Texto dos'), findsNothing);
    await tester.tap(find.text('Dos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Texto uno'), findsNothing);
    expect(find.textContaining('Texto dos'), findsOneWidget);
  });
}
