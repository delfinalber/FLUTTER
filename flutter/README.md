# Pizza Julian — App móvil en Flutter

App móvil con el mismo diseño y las mismas funciones del sitio web `pizza-julian`, usando PostgreSQL.

```
D:\FLUTTER\flutter
├── base_de_datos\pizza_julian_postgres.sql   Base de datos PostgreSQL (tablas + datos iniciales)
├── crear_base_de_datos.ps1                   Crea la base de datos con un comando
├── pizza_julian_api\                         Servidor API en Dart (conecta la app con PostgreSQL)
│   ├── bin\server.dart
│   ├── lib\api.dart        rutas: tema, login, inicio, productos, contacto
│   ├── lib\paleta.dart     calcula la paleta de colores a partir del banner
│   ├── lib\imagenes.dart   guarda/valida las imágenes subidas (JPG, PNG, GIF, WEBP, máx. 5 MB)
│   ├── media\              imágenes (banner, carrusel, productos)
│   └── .env                datos de conexión (no se sube a GitHub)
└── pizza_julian_app\                         App Flutter (Android / iOS)
    └── lib\
        ├── main.dart, config.dart, api.dart, tema.dart, navegacion.dart
        ├── pantallas\  inicio, productos, contacto + editor_inicio, editor_productos, editor_contacto
        └── widgets\    banner, menú, pie de página, WhatsApp, carrusel, login, piezas del editor
```

¿Por qué hay un servidor API? Una app móvil **no debe** conectarse directo a PostgreSQL: tendría que
llevar la contraseña de la base de datos dentro del APK. La API (como hacían los `.php`) es la única que
habla con la base de datos; la app solo habla con la API.

## Qué hace la app (igual que la web)

| Web (`pizza-julian`) | App |
|---|---|
| `inicio/index.php` | Banner, menú, carrusel, video de YouTube, acordeón, secciones desplegables, pie de página y botón flotante de WhatsApp |
| `productos/productos.php` | Tarjetas con carrusel automático de 3 imágenes (el botón abre WhatsApp con el nombre de la pizza) |
| `contacto/contactos.php` + `formulario-contacto.php` | Mapa de Google + formulario; el mensaje se guarda en `formulario_contacto` y se envía por Gmail |
| Modal "Inicio Sesion" (30 s) + `login.php` | Mismo diálogo con contador de 30 s; bloqueo de 5 min tras 5 intentos fallidos |
| `index-formulario.php`, `productos-formulario.php`, `contactos-formulario.php` | Editores: crear, editar y eliminar contenido, subir imágenes desde la galería |
| `tema.php` / `tema.js` | El banner del primer registro de Inicio define la paleta de colores de toda la app |

## Puesta en marcha

### 1. Base de datos (PostgreSQL 16 ya está instalado en este equipo)

```powershell
cd D:\FLUTTER\flutter
.\crear_base_de_datos.ps1
```

Pide la contraseña del usuario `postgres`. Crea la base `pizza_julian` con las tablas
`usuario`, `sesion_api`, `inicio`, `productos`, `contacto` y `formulario_contacto`.

El usuario del editor es el mismo de la web (`alberdelfin`, con la misma contraseña).
Para crear otro usuario:

```sql
INSERT INTO usuario (usuario, password) VALUES ('nuevo', crypt('su-clave', gen_salt('bf', 10)));
```

### 2. Servidor API

Requiere el SDK de Dart (viene incluido con Flutter).

1. Abra `pizza_julian_api\.env` y escriba la contraseña de PostgreSQL en `DB_PASSWORD=`.
2. Ejecute:

```powershell
cd D:\FLUTTER\flutter\pizza_julian_api
dart pub get
dart run bin/server.dart
```

Debe aparecer `API Pizza Julian escuchando en http://0.0.0.0:8080`.
Prueba rápida en el navegador: http://localhost:8080/api/productos

### 3. App Flutter

```powershell
cd D:\FLUTTER\flutter\pizza_julian_app
flutter pub get
flutter run                                              # emulador Android (usa http://10.0.2.2:8080)
flutter run --dart-define=API_URL=http://192.168.1.10:8080   # celular real: IP del PC en la red Wi-Fi
```

Para un celular real, el PC y el celular deben estar en la misma red Wi-Fi y el Firewall de Windows debe
permitir el puerto 8080. La IP del PC se ve con `ipconfig` (Dirección IPv4).

Generar el APK para instalar:

```powershell
flutter build apk --release --dart-define=API_URL=http://192.168.1.10:8080
# queda en build\app\outputs\flutter-apk\app-release.apk
```

## Diferencias con la web (por ser app móvil)

- La sesión del editor usa un token (8 horas) en vez de la cookie de PHP; al cerrar la app se cierra la sesión.
- El video de YouTube se muestra como miniatura y se abre en la app de YouTube.
- La paleta de colores del banner se calcula en el servidor al guardar (en la web se calculaba en el navegador).
- Los nombres con guion pasan a guion bajo: `formulario-contacto` → `formulario_contacto`, `carru-1` → `carru_1`.
- Se agregó la tabla `contacto` (la usaba `contactos.php` pero no estaba en el archivo `.sql`).
