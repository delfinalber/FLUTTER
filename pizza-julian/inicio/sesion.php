<?php
declare(strict_types=1);

// Arranca la sesión con cookies httponly/samesite para mitigar robo de sesión (XSS/CSRF)
function iniciarSesionSegura(): void
{
    if (session_status() === PHP_SESSION_NONE) {
        session_set_cookie_params([
            "lifetime" => 0,
            "path" => "/",
            "domain" => "",
            "secure" => isset($_SERVER["HTTPS"]) && $_SERVER["HTTPS"] !== "off",
            "httponly" => true,
            "samesite" => "Lax",
        ]);
        session_start();
    }
}

function usuarioAutenticado(): bool
{
    return !empty($_SESSION["usuario_id"]);
}

// Token anti-CSRF asociado a la sesión del visitante
function generarTokenCsrf(): string
{
    if (empty($_SESSION["csrf_token"])) {
        $_SESSION["csrf_token"] = bin2hex(random_bytes(32));
    }
    return $_SESSION["csrf_token"];
}

function csrfValido(?string $token): bool
{
    return is_string($token) && $token !== "" && !empty($_SESSION["csrf_token"]) && hash_equals($_SESSION["csrf_token"], $token);
}

// Encabezados para impedir que el navegador guarde en caché páginas con datos de sesión
function enviarCabecerasSinCache(): void
{
    header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
    header("Pragma: no-cache");
    header("Expires: 0");
}
