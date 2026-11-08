<?php

use PHPMailer\PHPMailer\Exception;
use PHPMailer\PHPMailer\PHPMailer;

require_once __DIR__ . "/vendor/autoload.php";

function loadLocalEnv(string $path): array
{
    if (!is_readable($path)) {
        return [];
    }

    $values = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }

        [$key, $value] = explode('=', $line, 2);
        $values[trim($key)] = trim($value, " \t\n\r\0\x0B\"");
    }

    return $values;
}

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");

if ($mysqli->connect_error) {
    die("Error de conexión: " . $mysqli->connect_error);
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    $email = filter_var(trim($_POST["correo"] ?? ""), FILTER_VALIDATE_EMAIL);
    $nombre = trim($_POST["nombre"] ?? "");
    $telefono = trim($_POST["telefono"] ?? "");
    $texto_area = trim($_POST["texto_area"] ?? "");

    if ($email === false || $nombre === "" || $texto_area === "") {
        http_response_code(422);
        exit("Por favor, completa el nombre, un correo válido y el mensaje.");
    }

    $stmt = $mysqli->prepare("INSERT INTO `formulario-contacto` (correo_formulario, nombre_formulario, telefono_formulario, mensaje_formulario) VALUES (?, ?, ?, ?)");
    if ($stmt === false) {
        error_log("Error al preparar el registro del formulario: " . $mysqli->error);
        http_response_code(500);
        exit("No fue posible procesar el formulario.");
    }

    $stmt->bind_param('ssss', $email, $nombre, $telefono, $texto_area);
    if (!$stmt->execute()) {
        error_log("Error al guardar el formulario: " . $stmt->error);
        $stmt->close();
        $mysqli->close();
        http_response_code(500);
        exit("No fue posible guardar la información del formulario.");
    }

    $stmt->close();
    $mysqli->close();

    $env = loadLocalEnv(__DIR__ . "/.env");
    $smtpUsername = getenv("GMAIL_USERNAME") ?: ($env["GMAIL_USERNAME"] ?? "delfin.alber@gmail.com");
    $smtpPassword = getenv("GMAIL_APP_PASSWORD") ?: ($env["GMAIL_APP_PASSWORD"] ?? "");

    if ($smtpPassword === "") {
        error_log("No está configurada GMAIL_APP_PASSWORD para el formulario de contacto.");
        http_response_code(500);
        exit("La información se guardó, pero el correo no está configurado.");
    }

    try {
        $mail = new PHPMailer(true);
        $mail->isSMTP();
        $mail->Host = "smtp.gmail.com";
        $mail->SMTPAuth = true;
        $mail->Username = $smtpUsername;
        $mail->Password = $smtpPassword;
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;
        $mail->CharSet = "UTF-8";

        $mail->setFrom($smtpUsername, "Formulario PIZZERIA-JULIAN");
        $mail->addAddress("delfin.alber@gmail.com");
        $mail->addReplyTo($email, $nombre);
        $mail->isHTML(false);
        $mail->Subject = "Nuevo mensaje del formulario de contacto";
        $mail->Body = "Nombre: {$nombre}\nCorreo: {$email}\nTeléfono: {$telefono}\n\nMensaje:\n{$texto_area}";
        $mail->send();
    } catch (Exception $exception) {
        error_log("Error SMTP del formulario de contacto: " . $exception->getMessage());
        http_response_code(502);
        exit("La información se guardó, pero no se pudo enviar el correo.");
    }

    header("Cache-Control: no-store, no-cache, must-revalidate");
    header("Location: contactos.php?envio=ok", true, 303);
    exit;
}

