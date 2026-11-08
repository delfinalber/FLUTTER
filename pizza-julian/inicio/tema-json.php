<?php
declare(strict_types=1);

// Devuelve el tema actual (banner + paleta) para que las páginas abiertas se actualicen sin recargar
require_once __DIR__ . "/tema.php";

header("Content-Type: application/json; charset=utf-8");
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");
if ($mysqli->connect_error) {
    http_response_code(500);
    echo json_encode(["ok" => false]);
    exit;
}
$tema = obtenerTemaSitio($mysqli);
$mysqli->close();

echo json_encode(["ok" => true] + $tema, JSON_UNESCAPED_SLASHES);
