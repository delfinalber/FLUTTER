import 'package:flutter/material.dart';

import 'navegacion.dart';
import 'tema.dart';

void main() {
  runApp(const PizzaJulianApp());
}

class PizzaJulianApp extends StatefulWidget {
  const PizzaJulianApp({super.key});

  @override
  State<PizzaJulianApp> createState() => _PizzaJulianAppState();
}

class _PizzaJulianAppState extends State<PizzaJulianApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    temaSitio.sincronizar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al volver a la app se revisa si otro editor cambió el banner y la paleta
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      temaSitio.sincronizar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: temaSitio,
      builder: (context, _) => MaterialApp(
        title: 'PIZZA-JULIAN',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: pz.naranja, primary: pz.rojo, secondary: pz.naranja),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),
        home: paginaDe(Seccion.inicio),
      ),
    );
  }
}
