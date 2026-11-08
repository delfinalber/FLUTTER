<?php
declare(strict_types=1);

// Tema visual compartido por todas las páginas (inicio, productos, contacto y sus editores).
// El banner y la paleta de colores salen del primer registro de la tabla `inicio`,
// así al cambiar el banner en el editor de Inicio todas las páginas se actualizan juntas.

const PALETA_POR_DEFECTO = [
    "negro" => "#0f090a",
    "negro-suave" => "#1a1113",
    "naranja" => "#ff8b1a",
    "amarillo" => "#ffc21a",
    "rojo" => "#d90a0a",
    "rojo-profundo" => "#8f0909",
    "rojo-vivo" => "#ff2e2e",
    "blanco" => "#f7f5f3",
    "gris" => "#e7e2de",
];
const BANNER_POR_DEFECTO = "./img-inicio/banner.png";

// Devuelve la paleta solo si trae todos los colores en formato #rrggbb; si no, null
function normalizarPaleta(?string $json): ?array
{
    $datos = json_decode((string) $json, true);
    if (!is_array($datos)) {
        return null;
    }
    $paleta = [];
    foreach (array_keys(PALETA_POR_DEFECTO) as $clave) {
        $color = strtolower(trim((string) ($datos[$clave] ?? "")));
        if (!preg_match('/^#[0-9a-f]{6}$/', $color)) {
            return null;
        }
        $paleta[$clave] = $color;
    }
    return $paleta;
}

function obtenerTemaSitio(mysqli $mysqli): array
{
    $banner = BANNER_POR_DEFECTO;
    $paleta = PALETA_POR_DEFECTO;

    $resultado = $mysqli->query("SELECT banner_inicio, paleta_banner FROM `inicio` ORDER BY id_inicio ASC LIMIT 1");
    if ($resultado && ($fila = $resultado->fetch_assoc())) {
        $valor = trim((string) $fila["banner_inicio"]);
        // solo rutas dentro de img-inicio (evita inyectar CSS en url())
        if (preg_match('~^\./img-inicio/[A-Za-z0-9._-]+$~', $valor)) {
            $banner = $valor;
        }
        $paleta = normalizarPaleta($fila["paleta_banner"]) ?? PALETA_POR_DEFECTO;
    }

    // Todas las páginas están un nivel dentro del proyecto, por eso la ruta sale desde ../inicio/
    $rutaBanner = "../inicio/" . substr($banner, 2);
    return [
        "banner" => $rutaBanner,
        "paleta" => $paleta,
        "version" => substr(md5($rutaBanner . json_encode($paleta)), 0, 12),
    ];
}

// Se imprime dentro de <head>: paleta del banner en variables CSS + script que sincroniza el tema al instante
function imprimirTemaSitio(array $tema): void
{
    $variables = "";
    foreach ($tema["paleta"] as $clave => $color) {
        $variables .= "--pizza-$clave: $color; ";
    }
    $variables .= "--banner-url: url(\"{$tema["banner"]}\");";
    ?>
    <link rel="stylesheet" href="../inicio/tema.css">
    <style id="tema-sitio" data-version="<?= htmlspecialchars($tema["version"], ENT_QUOTES) ?>">:root { <?= $variables ?> }</style>
    <script src="../inicio/tema.js" defer></script>
    <?php
}
