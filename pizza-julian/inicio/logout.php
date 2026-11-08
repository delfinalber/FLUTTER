<?php
declare(strict_types=1);

require_once __DIR__ . "/sesion.php";
iniciarSesionSegura();
enviarCabecerasSinCache();

// Página pública a la que se regresa según el editor desde el que se cerró la sesión (lista cerrada: evita redirecciones abiertas)
$paginasDestino = [
    "inicio" => "index.php",
    "productos" => "../productos/productos.php",
    "contacto" => "../contacto/contactos.php",
];
$destinoSolicitado = is_string($_POST["destino"] ?? null) ? $_POST["destino"] : "";
$paginaDestino = $paginasDestino[$destinoSolicitado] ?? "index.php";

// El cierre de sesión es una acción que cambia estado: solo se acepta por POST con token CSRF válido
if ($_SERVER["REQUEST_METHOD"] !== "POST" || !csrfValido($_POST["csrf_token"] ?? null)) {
    header("Location: " . $paginaDestino);
    exit;
}

$_SESSION = [];
if (ini_get("session.use_cookies")) {
    $parametrosCookie = session_get_cookie_params();
    setcookie(
        session_name(),
        "",
        time() - 42000,
        $parametrosCookie["path"],
        $parametrosCookie["domain"],
        $parametrosCookie["secure"],
        $parametrosCookie["httponly"]
    );
}
session_destroy();

// Pide al navegador borrar la caché del sitio para que no queden copias de los editores protegidos
header('Clear-Site-Data: "cache"');

header("Location: " . $paginaDestino);
exit;
