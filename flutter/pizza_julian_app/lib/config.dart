// Dirección del servidor API (carpeta pizza_julian_api).
// - Emulador Android: http://10.0.2.2:8080 (valor por defecto)
// - Celular real: la IP del computador en la red Wi-Fi, por ejemplo http://192.168.1.10:8080
// Se cambia sin tocar el código con:  flutter run --dart-define=API_URL=http://192.168.1.10:8080
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

// Las imágenes se guardan en el servidor como rutas relativas ("productos/pizza1.png")
String urlMedia(String ruta) => '$apiUrl/media/$ruta';
