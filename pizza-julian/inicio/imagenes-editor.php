<?php
declare(strict_types=1);

// Manejo de imágenes compartido por los editores de contenido (index-formulario.php y productos-formulario.php)

// Tipos de imagen aceptados (se valida el contenido real del archivo, no solo la extensión)
const TIPOS_IMAGEN_PERMITIDOS = [
    "image/jpeg" => "jpg",
    "image/png" => "png",
    "image/gif" => "gif",
    "image/webp" => "webp",
];
const TAMANO_MAXIMO_IMAGEN = 5 * 1024 * 1024; // 5 MB por imagen

// Guarda una imagen subida y devuelve su ruta relativa (./carpeta/archivo); null si no se envió archivo.
// Si el archivo no es válido deja el código de estado en $error.
function guardarImagenSubida(?array $archivo, string $directorio, string $prefijo, ?string &$error): ?string
{
    if (!$archivo || $archivo["error"] === UPLOAD_ERR_NO_FILE) {
        return null;
    }
    if ($archivo["error"] !== UPLOAD_ERR_OK || $archivo["size"] <= 0 || $archivo["size"] > TAMANO_MAXIMO_IMAGEN) {
        $error = "error_imagen";
        return null;
    }

    $tipoMime = (new finfo(FILEINFO_MIME_TYPE))->file($archivo["tmp_name"]);
    $dimensiones = @getimagesize($archivo["tmp_name"]);
    if (!isset(TIPOS_IMAGEN_PERMITIDOS[$tipoMime]) || $dimensiones === false || $dimensiones[0] <= 0 || $dimensiones[1] <= 0) {
        $error = "error_imagen";
        return null;
    }

    $nombreArchivo = uniqid($prefijo, true) . "." . TIPOS_IMAGEN_PERMITIDOS[$tipoMime];
    if (!move_uploaded_file($archivo["tmp_name"], "$directorio/$nombreArchivo")) {
        $error = "error";
        return null;
    }
    return "./" . basename($directorio) . "/$nombreArchivo";
}

// Descarta del disco las imágenes subidas en un envío que no llegó a guardarse en la BD
function descartarImagenesSubidas(array $rutas, string $directorio): void
{
    foreach ($rutas as $ruta) {
        $archivo = "$directorio/" . basename((string) $ruta);
        if (is_file($archivo)) {
            unlink($archivo);
        }
    }
}

// Borra del almacenamiento las imágenes antiguas que fueron reemplazadas o cuyo registro se eliminó.
// No borra un archivo si otro registro de la tabla todavía lo usa ni si el sitio lo usa fijo ($protegidas).
function eliminarImagenesReemplazadas(mysqli $mysqli, string $tabla, array $columnasImagen, array $rutas, string $directorio, array $protegidas = []): void
{
    $condiciones = implode(" OR ", array_map(fn($c) => "`$c` = ?", $columnasImagen));
    $carpeta = basename($directorio);

    foreach (array_unique(array_filter(array_map("strval", $rutas))) as $ruta) {
        $nombreArchivo = basename($ruta);
        // solo archivos de la carpeta de imágenes del editor (basename impide salir de ella)
        if ($nombreArchivo === "" || $nombreArchivo[0] === "." || in_array($nombreArchivo, $protegidas, true)) {
            continue;
        }

        $rutaNormalizada = "./$carpeta/$nombreArchivo";
        $parametros = array_fill(0, count($columnasImagen), $rutaNormalizada);
        $stmt = $mysqli->prepare("SELECT COUNT(*) FROM `$tabla` WHERE $condiciones");
        $stmt->bind_param(str_repeat("s", count($parametros)), ...$parametros);
        $stmt->execute();
        $stmt->bind_result($usos);
        $stmt->fetch();
        $stmt->close();

        $archivo = "$directorio/$nombreArchivo";
        if ($usos === 0 && is_file($archivo)) {
            unlink($archivo);
        }
    }
}
