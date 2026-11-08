<?php
declare(strict_types=1);

require_once __DIR__ . "/sesion.php";
iniciarSesionSegura();
enviarCabecerasSinCache();

header("Content-Type: application/json; charset=UTF-8");

function responderJson(bool $ok, string $mensaje, ?string $redireccion = null): never
{
    echo json_encode(["ok" => $ok, "mensaje" => $mensaje, "redirect" => $redireccion], JSON_UNESCAPED_UNICODE);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] !== "POST") {
    http_response_code(405);
    responderJson(false, "Método no permitido.");
}

$entrada = json_decode((string) file_get_contents("php://input"), true);
if (!is_array($entrada)) {
    $entrada = $_POST;
}

// Protección CSRF: el token debe coincidir con el generado para esta sesión
if (!csrfValido($entrada["csrf_token"] ?? null)) {
    http_response_code(403);
    responderJson(false, "La sesión expiró, recargue la página e intente nuevamente.");
}

// Bloqueo temporal tras varios intentos fallidos (mitiga fuerza bruta)
$_SESSION["intentos_login"] = $_SESSION["intentos_login"] ?? 0;
$_SESSION["bloqueo_login_hasta"] = $_SESSION["bloqueo_login_hasta"] ?? 0;

if (time() < (int) $_SESSION["bloqueo_login_hasta"]) {
    http_response_code(429);
    responderJson(false, "Demasiados intentos fallidos. Intente de nuevo en unos minutos.");
}

$usuario = trim((string) ($entrada["usuario"] ?? ""));
$password = (string) ($entrada["password"] ?? "");

if ($usuario === "" || $password === "" || mb_strlen($usuario) > 200 || mb_strlen($password) > 200) {
    responderJson(false, "Usuario y contraseña son obligatorios.");
}

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");
if ($mysqli->connect_error) {
    http_response_code(500);
    responderJson(false, "Error de conexión con el servidor.");
}

// Consulta preparada con parámetros ligados: evita inyección SQL
$stmt = $mysqli->prepare("SELECT id_usuario, usuario, password FROM usuario WHERE usuario = ? LIMIT 1");
$stmt->bind_param("s", $usuario);
$stmt->execute();
$fila = $stmt->get_result()->fetch_assoc();
$stmt->close();
$mysqli->close();

// password_verify compara contra el hash almacenado (bcrypt), nunca en texto plano
if (!$fila || !password_verify($password, (string) $fila["password"])) {
    $_SESSION["intentos_login"]++;
    if ($_SESSION["intentos_login"] >= 5) {
        $_SESSION["bloqueo_login_hasta"] = time() + 300;
        $_SESSION["intentos_login"] = 0;
    }
    responderJson(false, "Usuario o contraseña incorrectos.");
}

$_SESSION["intentos_login"] = 0;
$_SESSION["bloqueo_login_hasta"] = 0;
session_regenerate_id(true); // evita fijación de sesión al cambiar de privilegio

$_SESSION["usuario_id"] = (int) $fila["id_usuario"];
$_SESSION["usuario_nombre"] = $fila["usuario"];
$_SESSION["login_time"] = time();
unset($_SESSION["csrf_token"]); // el token de login ya no es reutilizable

responderJson(true, "Inicio de sesión correcto.", "index-formulario.php");
