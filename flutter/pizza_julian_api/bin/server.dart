import 'dart:io';

import 'package:pizza_julian_api/api.dart';
import 'package:pizza_julian_api/config.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final config = Config.cargar();

  final db = Pool.withEndpoints(
    [
      Endpoint(
        host: config.dbHost,
        port: config.dbPort,
        database: config.dbName,
        username: config.dbUser,
        password: config.dbPassword,
      ),
    ],
    settings: const PoolSettings(maxConnectionCount: 5, sslMode: SslMode.disable),
  );

  // Verifica la conexión antes de aceptar peticiones
  try {
    await db.execute('SELECT 1');
  } catch (e) {
    stderr.writeln('No fue posible conectar con PostgreSQL (${config.dbHost}:${config.dbPort}/${config.dbName}): $e');
    stderr.writeln('Revise el archivo .env (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD).');
    exit(1);
  }

  final api = PizzaJulianApi(config, db);
  // 0.0.0.0 para que el celular o el emulador puedan llegar al servidor por la red local
  final servidor = await io.serve(api.handler, InternetAddress.anyIPv4, config.puerto);
  servidor.autoCompress = true;
  print('API Pizza Julian escuchando en http://${servidor.address.host}:${servidor.port}');
}
