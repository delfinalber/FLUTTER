<?php
declare(strict_types=1);

require_once __DIR__ . "/sesion.php";
require_once __DIR__ . "/tema.php";
require_once __DIR__ . "/imagenes-editor.php";
iniciarSesionSegura();
enviarCabecerasSinCache();

// Solo usuarios autenticados (tabla `usuario`) pueden ver o modificar este editor
if (!usuarioAutenticado()) {
    header("Location: index.php");
    exit;
}

$tokenCsrfLogout = generarTokenCsrf();

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");
if ($mysqli->connect_error) {
    die("Error de conexión: " . $mysqli->connect_error);
}
// Banner y paleta de colores compartidos por todas las páginas
$temaSitio = obtenerTemaSitio($mysqli);

// Convierte enlaces de YouTube (watch, youtu.be, shorts) al formato /embed/ requerido por el iframe
function normalizarUrlYoutubeEmbed(string $url): string
{
    $url = trim($url);
    if ($url === "") {
        return $url;
    }
    if (preg_match('~(?:youtu\.be/|youtube\.com/(?:embed/|watch\?v=|shorts/))([A-Za-z0-9_-]{6,})~i', $url, $coincidencia)) {
        return "https://www.youtube.com/embed/" . $coincidencia[1];
    }
    return $url;
}

// Columnas de la tabla `inicio` que alimentan las variables de index.php
$columnasInicio = [
    "banner_inicio", "carru-1", "carru-2", "carru-3", "url_video_inicio",
    "acor1_titulo_inicio", "acor1_texto_inicio",
    "acor2_titulo_inicio", "acor2_texto_inicio",
    "acor3_titulo_inicio", "acor3_texto_inicio",
    "acor4_titulo_inicio", "acor4_texto_inicio",
    "acor5_titulo_inicio", "acor5_texto_inicio",
    "colapsar1_titulo_inicio", "colapsar1_texto_inicio",
    "colapsar2_titulo_inicio", "colapsar2_texto_inicio",
    "colapsar3_titulo_inicio", "colapsar3_texto_inicio",
    "numero_whatsapp", "paleta_banner",
];
$camposImagen = ["banner_inicio", "carru-1", "carru-2", "carru-3"];
$directorioImagenes = __DIR__ . "/img-inicio";
// Imágenes que el sitio usa de forma fija (respaldo de index.php y fondos en inicio.css): nunca se borran
$imagenesProtegidas = ["banner.png", "footer.png", "1.jpeg", "2.jpeg", "3.jpeg"];

function obtenerFilaInicio(mysqli $mysqli, int $id): ?array
{
    $stmt = $mysqli->prepare("SELECT * FROM `inicio` WHERE id_inicio = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $fila ?: null;
}

// Tras procesar el POST se redirige (patrón PRG) a index-formulario.php sin caché ni reenvío del formulario
// Rechaza envíos del editor sin token CSRF válido (evita modificaciones desde otros sitios)
if ($_SERVER["REQUEST_METHOD"] === "POST" && !csrfValido($_POST["csrf_token"] ?? null)) {
    header("Location: index-formulario.php?estado=error", true, 303);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $accion = $_POST["accion"] ?? "";
    $estado = "error";

    if ($accion === "eliminar") {
        $id = (int) ($_POST["id_inicio"] ?? 0);
        $filaActual = $id > 0 ? obtenerFilaInicio($mysqli, $id) : null;
        if ($filaActual) {
            $stmt = $mysqli->prepare("DELETE FROM `inicio` WHERE id_inicio = ?");
            $stmt->bind_param("i", $id);
            $estado = $stmt->execute() ? "eliminado" : "error";
            $stmt->close();
            if ($estado === "eliminado") {
                eliminarImagenesReemplazadas($mysqli, "inicio", $camposImagen, array_map(fn($c) => $filaActual[$c], $camposImagen), $directorioImagenes, $imagenesProtegidas);
            }
        }
    } elseif ($accion === "crear" || $accion === "editar") {
        $id = (int) ($_POST["id_inicio"] ?? 0);
        // Las imágenes actuales se leen de la BD (no de campos ocultos que el navegador podría alterar)
        $filaActual = $accion === "editar" ? obtenerFilaInicio($mysqli, $id) : [];
        $valoresImagen = [];
        $imagenesNuevas = [];
        $errorImagen = $filaActual === null ? "error" : null;

        if ($errorImagen === null) {
            foreach ($camposImagen as $campo) {
                $rutaNueva = guardarImagenSubida($_FILES[$campo] ?? null, $directorioImagenes, "inicio_", $errorImagen);
                if ($rutaNueva !== null) {
                    $imagenesNuevas[] = $rutaNueva;
                }
                // conservar la imagen actual si no se seleccionó un archivo nuevo
                $valoresImagen[$campo] = $rutaNueva ?? (string) ($filaActual[$campo] ?? "");
            }
        }

        if ($errorImagen !== null) {
            // No se guarda nada: se descartan los archivos que sí alcanzaron a subirse en este envío
            descartarImagenesSubidas($imagenesNuevas, $directorioImagenes);
            $mysqli->close();
            header("Location: index-formulario.php?estado=" . urlencode($errorImagen), true, 303);
            exit;
        }

        $valores = [];
        foreach ($columnasInicio as $columna) {
            if (in_array($columna, $camposImagen, true)) {
                $valores[] = $valoresImagen[$columna];
            } elseif ($columna === "paleta_banner") {
                // Con un banner nuevo se guarda la paleta calculada de esa imagen; si no, se conserva la actual
                if (in_array($valoresImagen["banner_inicio"], $imagenesNuevas, true)) {
                    $paleta = normalizarPaleta($_POST["paleta_banner"] ?? "");
                    $valores[] = $paleta ? json_encode($paleta) : "";
                } else {
                    $valores[] = (string) ($filaActual["paleta_banner"] ?? "");
                }
            } elseif ($columna === "url_video_inicio") {
                $valores[] = normalizarUrlYoutubeEmbed(trim((string) ($_POST[$columna] ?? "")));
            } else {
                $valores[] = trim((string) ($_POST[$columna] ?? ""));
            }
        }

        if ($accion === "crear") {
            $columnasSql = implode(", ", array_map(fn($c) => "`$c`", $columnasInicio));
            $marcadores = implode(", ", array_fill(0, count($columnasInicio), "?"));
            $stmt = $mysqli->prepare("INSERT INTO `inicio` ($columnasSql) VALUES ($marcadores)");
            $tipos = str_repeat("s", count($valores));
            $stmt->bind_param($tipos, ...$valores);
            $estado = $stmt->execute() ? "creado" : "error";
            $stmt->close();
        } else {
            $setClause = implode(", ", array_map(fn($c) => "`$c` = ?", $columnasInicio));
            $stmt = $mysqli->prepare("UPDATE `inicio` SET $setClause WHERE id_inicio = ?");
            $tipos = str_repeat("s", count($valores)) . "i";
            $valores[] = $id;
            $stmt->bind_param($tipos, ...$valores);
            $estado = $stmt->execute() ? "actualizado" : "error";
            $stmt->close();
        }

        if ($estado === "error") {
            descartarImagenesSubidas($imagenesNuevas, $directorioImagenes);
        } elseif ($accion === "editar") {
            // La imagen antigua que fue reemplazada se borra del almacenamiento; solo queda guardada la nueva
            eliminarImagenesReemplazadas($mysqli, "inicio", $camposImagen, array_map(fn($c) => $filaActual[$c], $camposImagen), $directorioImagenes, $imagenesProtegidas);
        }
    }

    $mysqli->close();
    header("Location: index-formulario.php?estado=" . urlencode($estado), true, 303);
    exit;
}

$mensajesPorEstado = [
    "creado" => ["Contenido creado correctamente.", "success"],
    "actualizado" => ["Contenido actualizado correctamente.", "success"],
    "eliminado" => ["Contenido eliminado correctamente.", "success"],
    "error_imagen" => ["Imagen no válida: usa archivos JPG, PNG, GIF o WEBP de máximo 5 MB. No se guardaron cambios.", "danger"],
    "error" => ["No fue posible completar la operación.", "danger"],
];
$estadoActual = $_GET["estado"] ?? "";
[$mensaje, $tipoMensaje] = $mensajesPorEstado[$estadoActual] ?? ["", "success"];

$filasInicio = [];
$resultado = $mysqli->query("SELECT * FROM `inicio` ORDER BY id_inicio ASC");
if ($resultado) {
    $filasInicio = $resultado->fetch_all(MYSQLI_ASSOC);
}

$acordeones = [1, 2, 3, 4, 5];
$colapsables = [1, 2, 3];

function campoInicio(array $fila, string $campo): string
{
    return htmlspecialchars((string) ($fila[$campo] ?? ""), ENT_QUOTES);
}

// Genera el modal (crear o editar) reutilizando el mismo formulario
// $controlaTema: el registro es el que define el banner y la paleta de todo el sitio (el primero de la tabla)
function renderModalInicio(string $idModal, string $tituloModal, string $accion, array $fila, array $acordeones, array $colapsables, bool $controlaTema): void
{
    $idInicio = (int) ($fila["id_inicio"] ?? 0);
    ?>
    <div class="modal fade editor-modal" id="<?= htmlspecialchars($idModal, ENT_QUOTES) ?>" tabindex="-1" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered modal-lg modal-dialog-scrollable">
        <div class="modal-content">
          <form method="post" enctype="multipart/form-data">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(generarTokenCsrf(), ENT_QUOTES) ?>">
            <input type="hidden" name="accion" value="<?= htmlspecialchars($accion, ENT_QUOTES) ?>">
            <?php if ($accion === "editar"): ?>
                <input type="hidden" name="id_inicio" value="<?= $idInicio ?>">
            <?php endif; ?>
            <div class="modal-header">
              <h5 class="modal-title"><?= htmlspecialchars($tituloModal) ?></h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <fieldset>
                <legend>Banner y multimedia</legend>
                <div class="mb-3">
                  <label class="form-label">Imagen del banner</label>
                  <?php if (campoInicio($fila, "banner_inicio") !== ""): ?>
                    <div class="mb-2"><img src="<?= campoInicio($fila, "banner_inicio") ?>" alt="Banner actual" class="img-thumbnail" style="max-height:90px;"></div>
                  <?php endif; ?>
                  <input type="file" class="form-control<?= $controlaTema ? " input-banner" : "" ?>" name="banner_inicio" accept="image/jpeg,image/png,image/gif,image/webp">
                  <input type="hidden" name="paleta_banner" value="">
                  <?php if ($controlaTema): ?>
                    <div class="form-text editor-ayuda">Este banner se muestra en todas las páginas y de él sale la paleta de colores del sitio.</div>
                    <div class="paleta-banner mt-2" hidden>
                      <span class="paleta-banner-texto small"></span>
                      <div class="paleta-banner-colores"></div>
                    </div>
                  <?php endif; ?>
                </div>
                <div class="row">
                  <div class="col-md-4 mb-3">
                    <label class="form-label">Carrusel imagen 1</label>
                    <?php if (campoInicio($fila, "carru-1") !== ""): ?>
                      <div class="mb-2"><img src="<?= campoInicio($fila, "carru-1") ?>" alt="Carrusel 1 actual" class="img-thumbnail" style="max-height:70px;"></div>
                    <?php endif; ?>
                    <input type="file" class="form-control" name="carru-1" accept="image/jpeg,image/png,image/gif,image/webp">
                  </div>
                  <div class="col-md-4 mb-3">
                    <label class="form-label">Carrusel imagen 2</label>
                    <?php if (campoInicio($fila, "carru-2") !== ""): ?>
                      <div class="mb-2"><img src="<?= campoInicio($fila, "carru-2") ?>" alt="Carrusel 2 actual" class="img-thumbnail" style="max-height:70px;"></div>
                    <?php endif; ?>
                    <input type="file" class="form-control" name="carru-2" accept="image/jpeg,image/png,image/gif,image/webp">
                  </div>
                  <div class="col-md-4 mb-3">
                    <label class="form-label">Carrusel imagen 3</label>
                    <?php if (campoInicio($fila, "carru-3") !== ""): ?>
                      <div class="mb-2"><img src="<?= campoInicio($fila, "carru-3") ?>" alt="Carrusel 3 actual" class="img-thumbnail" style="max-height:70px;"></div>
                    <?php endif; ?>
                    <input type="file" class="form-control" name="carru-3" accept="image/jpeg,image/png,image/gif,image/webp">
                  </div>
                </div>
                <div class="mb-3">
                  <label class="form-label">URL video de YouTube (embed)</label>
                  <input type="text" class="form-control" name="url_video_inicio" value="<?= campoInicio($fila, "url_video_inicio") ?>">
                </div>
              </fieldset>

              <fieldset>
                <legend>Acordeón</legend>
                <?php foreach ($acordeones as $numero): ?>
                    <div class="row">
                      <div class="col-md-4 mb-3">
                        <label class="form-label">Título <?= $numero ?></label>
                        <input type="text" class="form-control" name="acor<?= $numero ?>_titulo_inicio" value="<?= campoInicio($fila, "acor{$numero}_titulo_inicio") ?>">
                      </div>
                      <div class="col-md-8 mb-3">
                        <label class="form-label">Texto <?= $numero ?></label>
                        <textarea class="form-control" name="acor<?= $numero ?>_texto_inicio" rows="2"><?= campoInicio($fila, "acor{$numero}_texto_inicio") ?></textarea>
                      </div>
                    </div>
                <?php endforeach; ?>
              </fieldset>

              <fieldset>
                <legend>Secciones colapsables</legend>
                <?php foreach ($colapsables as $numero): ?>
                    <div class="row">
                      <div class="col-md-4 mb-3">
                        <label class="form-label">Título <?= $numero ?></label>
                        <input type="text" class="form-control" name="colapsar<?= $numero ?>_titulo_inicio" value="<?= campoInicio($fila, "colapsar{$numero}_titulo_inicio") ?>">
                      </div>
                      <div class="col-md-8 mb-3">
                        <label class="form-label">Texto <?= $numero ?></label>
                        <textarea class="form-control" name="colapsar<?= $numero ?>_texto_inicio" rows="2"><?= campoInicio($fila, "colapsar{$numero}_texto_inicio") ?></textarea>
                      </div>
                    </div>
                <?php endforeach; ?>
              </fieldset>

              <fieldset>
                <legend>Contacto</legend>
                <div class="mb-3">
                  <label class="form-label">Número de WhatsApp</label>
                  <input type="text" class="form-control" name="numero_whatsapp" value="<?= campoInicio($fila, "numero_whatsapp") ?>" placeholder="573132345685">
                </div>
              </fieldset>
            </div>
            <div class="modal-footer">
              <a href="index-formulario.php" class="btn btn-secondary">Cancelar</a>
              <button type="submit" class="btn btn-editar">Guardar</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    <?php
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PIZZA-JULIAN | Editor de Contenido</title>
    <link rel="stylesheet" href="../bootstrap-5.3.8-dist/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="./inicio.css">
    <?php imprimirTemaSitio($temaSitio); ?>
</head>
<body>
    <!-- Banner Section -->
    <div class="container-fluid p-0 text-center">
        <div class="row g-0">
            <div class="banner col-12 p-0">
               <img src="<?= htmlspecialchars($temaSitio["banner"], ENT_QUOTES) ?>" class="img-fluid" alt="...">
            </div>
        </div>
    </div>
    <!-- Fin Banner Section -->
    <!-- Sección Nav -->
     <br>

    <nav class="navbar navbar-expand-lg nav-pizzeria">
            <div class="container-fluid">
                <a class="navbar-brand" href="#">Pizzeria Julian</a>
                <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
                <span class="navbar-toggler-icon"></span>
                </button>
                <div class="collapse navbar-collapse" id="navbarSupportedContent">
                <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                    <li class="nav-item">
                    <a class="nav-link nav-editor active" aria-current="page" href="../inicio/index-formulario.php">Inicio</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link nav-editor" href="../productos/productos-formulario.php">Productos</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link nav-editor" href="../contacto/contactos-formulario.php">Contacto</a>
                    </li>
                </ul>
                <div class="d-flex align-items-center">
                  <form method="post" action="logout.php" id="formCerrarSesion" class="d-inline">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($tokenCsrfLogout, ENT_QUOTES) ?>">
                    <input type="hidden" name="destino" value="inicio">
                    <button type="submit" class="btn btn-outline-success">Cerrar sesion</button>
                  </form>
                </div>
                </div>
            </div>
    </nav>
    <!-- Fin Sección Nav -->

    <br>

    <!-- Editor de Contenido de la tabla `inicio` -->
    <div class="container editor-panel my-4">
        <h2 class="mb-3"><i class="bi bi-pencil-square"></i> Editor de Contenido - Inicio</h2>
        
        <p class="mb-4" style="color: var(--pizza-gris);">Administra la información que se muestra en <strong>index.php</strong>: banner, carrusel, video, acordeón, secciones colapsables y contacto.</p>

        <?php if ($mensaje !== ""): ?>
            <div class="alert alert-<?= $tipoMensaje ?> editor-alert" role="alert"><?= htmlspecialchars($mensaje) ?></div>
        <?php endif; ?>

        <?php if (empty($filasInicio)): ?>
            <button type="button" class="btn btn-editar mb-3" data-bs-toggle="modal" data-bs-target="#modalCrear">
                <i class="bi bi-plus-circle"></i> Crear contenido inicial
            </button>
            <?php renderModalInicio("modalCrear", "Crear contenido inicial", "crear", [], $acordeones, $colapsables, empty($filasInicio)); ?>
        <?php else: ?>
            <div class="row g-3">
                <?php foreach ($filasInicio as $fila): ?>
                    <?php $idFila = (int) $fila["id_inicio"]; ?>
                    <div class="col-12">
                        <div class="card editor-card p-3">
                            <div class="row g-3 align-items-center">
                                <div class="col-md-2 text-center">
                                    <?php if (trim((string) $fila["banner_inicio"]) !== ""): ?>
                                        <img src="<?= htmlspecialchars($fila["banner_inicio"], ENT_QUOTES) ?>" class="img-fluid rounded" alt="Banner">
                                    <?php else: ?>
                                        <span class="text-muted">Sin imagen</span>
                                    <?php endif; ?>
                                </div>
                                <div class="col-md-7">
                                    <h5 class="card-title mb-1">Registro #<?= $idFila ?></h5>
                                    <p class="mb-0 small">Video: <?= htmlspecialchars((string) $fila["url_video_inicio"]) !== "" ? htmlspecialchars((string) $fila["url_video_inicio"]) : "-" ?></p>
                                    <p class="mb-0 small">WhatsApp: <?= htmlspecialchars((string) $fila["numero_whatsapp"]) ?></p>
                                </div>
                                <div class="col-md-3 text-md-end d-flex flex-column flex-md-row gap-2 justify-content-md-end">
                                    <button type="button" class="btn btn-editar" data-bs-toggle="modal" data-bs-target="#modalEditar<?= $idFila ?>">
                                        <i class="bi bi-pencil-square"></i> Editar
                                    </button>
                                    <form method="post" onsubmit="return confirm('¿Eliminar este contenido?');" class="d-inline">
                                      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($tokenCsrfLogout, ENT_QUOTES) ?>">
                                        <input type="hidden" name="accion" value="eliminar">
                                        <input type="hidden" name="id_inicio" value="<?= $idFila ?>">
                                        <button type="submit" class="btn btn-eliminar"><i class="bi bi-trash"></i> Eliminar</button>
                                    </form>
                                </div>
                            </div>
                        </div>
                    </div>
                    <?php renderModalInicio("modalEditar{$idFila}", "Editar contenido #{$idFila}", "editar", $fila, $acordeones, $colapsables, $idFila === (int) $filasInicio[0]["id_inicio"]); ?>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </div>
    <!-- Fin Editor de Contenido -->

<br>
<!-- Inicio Footer -->
<footer class="footer-pizzeria">
  <div class="container">
    <div class="footer-box text-center">
      <div class="footer-social">
        <a href="#" aria-label="Facebook"><i class="bi bi-facebook"></i></a>
        <a href="#" aria-label="Instagram"><i class="bi bi-instagram"></i></a>
        <a href="#" aria-label="Twitter"><i class="bi bi-twitter-x"></i></a>
        <a href="#" aria-label="Whatsapp"><i class="bi bi-whatsapp"></i></a>
        <a href="#" aria-label="Youtube"><i class="bi bi-youtube"></i></a>
      </div>

      <nav class="footer-menu">
        <a href="./index.php">Inicio</a>
        <a href="../productos/productos.php">Productos</a>
        <a href="../contacto/contactos.php">Contactos</a> 
        
        <a href="#">Nuestro equipo</a>
      </nav>

      <nav class="footer-menu footer-menu-editores">
        <span class="footer-menu-label">Editor de contenido:</span>
        <a href="./index-formulario.php">Inicio</a>
        <a href="../productos/productos-formulario.php">Productos</a>
        <a href="../contacto/contactos-formulario.php">Contacto</a>
      </nav>

      <p class="footer-copy">Copyright 2026. Designed by JULIAN</p>
    </div>
  </div>
</footer>

 <!-- Fin footer   -->



  <script src="../bootstrap-5.3.8-dist/js/bootstrap.bundle.min.js"></script>
  <script>
    // Evita que el botón "Atrás" muestre esta página protegida desde la caché del navegador
    window.addEventListener("pageshow", function (evento) {
      if (evento.persisted) {
        window.location.reload();
      }
    });
    history.replaceState(null, "", window.location.href);

    // Tras guardar, las otras pestañas abiertas del sitio aplican el banner y la paleta nuevos al instante
    <?php if (in_array($estadoActual, ["creado", "actualizado", "eliminado"], true)): ?>
    document.addEventListener("DOMContentLoaded", function () {
      window.temaSitio.avisarTemaActualizado();
    });
    <?php endif; ?>

    // Al elegir un banner se calcula su paleta y se aplica como vista previa a esta página
    var PALETA_POR_DEFECTO = <?= json_encode(PALETA_POR_DEFECTO) ?>;
    var bannerGuardado = <?= json_encode($temaSitio["banner"], JSON_UNESCAPED_SLASHES) ?>;

    document.querySelectorAll(".input-banner").forEach(function (input) {
      var formulario = input.form;
      var campoPaleta = formulario.querySelector('input[name="paleta_banner"]');
      var bloquePaleta = formulario.querySelector(".paleta-banner");
      var textoPaleta = bloquePaleta.querySelector(".paleta-banner-texto");
      var coloresPaleta = bloquePaleta.querySelector(".paleta-banner-colores");
      var enviando = false;

      function quitarVistaPrevia() {
        campoPaleta.value = "";
        bloquePaleta.hidden = true;
        window.temaSitio.restaurarTema(bannerGuardado);
      }

      formulario.addEventListener("submit", function () {
        enviando = true;
      });
      // Si se cierra el modal sin guardar, la página vuelve al banner y colores guardados
      input.closest(".modal").addEventListener("hidden.bs.modal", function () {
        if (!enviando && input.value) {
          input.value = "";
          quitarVistaPrevia();
        }
      });

      input.addEventListener("change", function () {
        var archivo = input.files[0];
        if (!archivo || archivo.type.indexOf("image/") !== 0) {
          quitarVistaPrevia();
          return;
        }
        var urlImagen = URL.createObjectURL(archivo);
        var imagen = new Image();
        imagen.onload = function () {
          var paleta = window.temaSitio.extraerPaletaBanner(imagen);
          campoPaleta.value = paleta ? JSON.stringify(paleta) : "";
          textoPaleta.textContent = paleta
            ? "Paleta calculada del banner (vista previa aplicada a esta página; se guarda para todas al pulsar Guardar):"
            : "El banner casi no tiene colores definidos: se usará la paleta original del sitio.";
          coloresPaleta.innerHTML = "";
          Object.keys(paleta || PALETA_POR_DEFECTO).forEach(function (clave) {
            var color = (paleta || PALETA_POR_DEFECTO)[clave];
            var muestra = document.createElement("span");
            muestra.style.backgroundColor = color;
            muestra.title = clave + " " + color;
            coloresPaleta.appendChild(muestra);
          });
          bloquePaleta.hidden = false;
          window.temaSitio.aplicarTema({ banner: urlImagen, paleta: paleta || PALETA_POR_DEFECTO });
        };
        imagen.onerror = quitarVistaPrevia;
        imagen.src = urlImagen;
      });
    });

    // Navega entre los editores reemplazando la entrada del historial (no se acumulan páginas protegidas)
    document.querySelectorAll(".nav-editor").forEach(function (enlace) {
      enlace.addEventListener("click", function (evento) {
        evento.preventDefault();
        window.location.replace(enlace.href);
      });
    });

    // Cierra sesión por fetch y reemplaza el historial para que "Atrás" no regrese al editor protegido
    var formCerrarSesion = document.getElementById("formCerrarSesion");
    if (formCerrarSesion) {
      formCerrarSesion.addEventListener("submit", function (evento) {
        evento.preventDefault();
        var datosFormulario = new FormData(formCerrarSesion);
        fetch("logout.php", {
          method: "POST",
          credentials: "same-origin",
          body: datosFormulario,
        }).finally(function () {
          window.location.replace("index.php");
        });
      });
    }
  </script>
</body>
</html>