<?php
declare(strict_types=1);

require_once __DIR__ . "/../inicio/sesion.php";
require_once __DIR__ . "/../inicio/tema.php";
iniciarSesionSegura();
enviarCabecerasSinCache();

// Solo usuarios autenticados (tabla `usuario`) pueden ver o modificar este editor
if (!usuarioAutenticado()) {
    header("Location: contactos.php");
    exit;
}

$tokenCsrfLogout = generarTokenCsrf();

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");
if ($mysqli->connect_error) {
    die("Error de conexión: " . $mysqli->connect_error);
}
// Banner y paleta de colores compartidos por todas las páginas
$temaSitio = obtenerTemaSitio($mysqli);

// Tras procesar el POST se redirige (patrón PRG) a contactos-formulario.php sin caché ni reenvío del formulario
// Rechaza envíos del editor sin token CSRF válido (evita modificaciones desde otros sitios)
if ($_SERVER["REQUEST_METHOD"] === "POST" && !csrfValido($_POST["csrf_token"] ?? null)) {
    header("Location: contactos-formulario.php?estado=error", true, 303);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $accion = $_POST["accion"] ?? "";
    $estado = "error";
    $urlContacto = trim((string) ($_POST["url_contacto"] ?? ""));

    if ($urlContacto !== "") {
        if ($accion === "crear") {
            $stmt = $mysqli->prepare("INSERT INTO `contacto` (url_contacto) VALUES (?)");
            $stmt->bind_param("s", $urlContacto);
            $estado = $stmt->execute() ? "creado" : "error";
            $stmt->close();
        } elseif ($accion === "editar") {
            $id = (int) ($_POST["id_contacto"] ?? 0);
            $stmt = $mysqli->prepare("UPDATE `contacto` SET url_contacto = ? WHERE id_contacto = ?");
            $stmt->bind_param("si", $urlContacto, $id);
            $estado = $stmt->execute() ? "actualizado" : "error";
            $stmt->close();
        }
    }

    $mysqli->close();
    header("Location: contactos-formulario.php?estado=" . urlencode($estado), true, 303);
    exit;
}

$mensajesPorEstado = [
    "creado" => ["URL del mapa creada correctamente.", "success"],
    "actualizado" => ["URL del mapa actualizada correctamente.", "success"],
    "error" => ["No fue posible completar la operación.", "danger"],
];
$estadoActual = $_GET["estado"] ?? "";
[$mensaje, $tipoMensaje] = $mensajesPorEstado[$estadoActual] ?? ["", "success"];

$filaContacto = [];
$resultado = $mysqli->query("SELECT * FROM `contacto` ORDER BY id_contacto ASC LIMIT 1");
if ($resultado && $resultado->num_rows > 0) {
    $filaContacto = $resultado->fetch_assoc();
}
$mysqli->close();

function campoContacto(array $fila, string $campo): string
{
    return htmlspecialchars((string) ($fila[$campo] ?? ""), ENT_QUOTES);
}

// Genera el modal (crear o editar) reutilizando el mismo formulario
function renderModalContacto(string $idModal, string $tituloModal, string $accion, array $fila): void
{
    $idContacto = (int) ($fila["id_contacto"] ?? 0);
    ?>
    <div class="modal fade editor-modal" id="<?= htmlspecialchars($idModal, ENT_QUOTES) ?>" tabindex="-1" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered modal-lg modal-dialog-scrollable">
        <div class="modal-content">
          <form method="post">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(generarTokenCsrf(), ENT_QUOTES) ?>">
            <input type="hidden" name="accion" value="<?= htmlspecialchars($accion, ENT_QUOTES) ?>">
            <?php if ($accion === "editar"): ?>
                <input type="hidden" name="id_contacto" value="<?= $idContacto ?>">
            <?php endif; ?>
            <div class="modal-header">
              <h5 class="modal-title"><?= htmlspecialchars($tituloModal) ?></h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <fieldset>
                <legend>Mapa de ubicación</legend>
                <div class="mb-3">
                  <label class="form-label">URL de Google Maps (embed)</label>
                  <textarea class="form-control" name="url_contacto" rows="4" maxlength="500" required><?= campoContacto($fila, "url_contacto") ?></textarea>
                </div>
              </fieldset>
            </div>
            <div class="modal-footer">
              <a href="contactos-formulario.php" class="btn btn-secondary">Cancelar</a>
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
    <title>PIZZA-JULIAN | Editor de Contacto</title>
    <link rel="stylesheet" href="../bootstrap-5.3.8-dist/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="./contactos.css">
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
                    <a class="nav-link nav-editor" href="../inicio/index-formulario.php">Inicio</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link nav-editor" href="../productos/productos-formulario.php">Productos</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link nav-editor active" aria-current="page" href="../contacto/contactos-formulario.php">Contacto</a>
                    </li>
                </ul>
                <div class="d-flex align-items-center">
                  <form method="post" action="../inicio/logout.php" id="formCerrarSesion" class="d-inline">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($tokenCsrfLogout, ENT_QUOTES) ?>">
                    <input type="hidden" name="destino" value="contacto">
                    <button type="submit" class="btn btn-outline-success">Cerrar sesion</button>
                  </form>
                </div>
                </div>
            </div>
    </nav>
    <!-- Fin Sección Nav -->

    <br>

    <!-- Editor de Contenido de la tabla `contacto` -->
    <div class="container editor-panel my-4">
        <h2 class="mb-3"><i class="bi bi-pencil-square"></i> Editor de Contenido - Contacto</h2>

        <p class="mb-4" style="color: var(--pizza-gris);">Administra la URL del mapa de Google que se muestra en <strong>contactos.php</strong>.</p>

        <?php if ($mensaje !== ""): ?>
            <div class="alert alert-<?= $tipoMensaje ?> editor-alert" role="alert"><?= htmlspecialchars($mensaje) ?></div>
        <?php endif; ?>

        <?php if (empty($filaContacto)): ?>
            <button type="button" class="btn btn-editar mb-3" data-bs-toggle="modal" data-bs-target="#modalCrear">
                <i class="bi bi-plus-circle"></i> Crear URL del mapa
            </button>
            <?php renderModalContacto("modalCrear", "Crear URL del mapa", "crear", []); ?>
        <?php else: ?>
            <div class="row g-3">
                <div class="col-12">
                    <div class="card editor-card p-3">
                        <div class="row g-3 align-items-center">
                            <div class="col-md-9">
                                <h5 class="card-title mb-1">URL actual del mapa</h5>
                                <p class="mb-0 small text-break"><?= htmlspecialchars((string) $filaContacto["url_contacto"], ENT_QUOTES) ?></p>
                            </div>
                            <div class="col-md-3 text-md-end">
                                <button type="button" class="btn btn-editar" data-bs-toggle="modal" data-bs-target="#modalEditar">
                                    <i class="bi bi-pencil-square"></i> Editar
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <?php renderModalContacto("modalEditar", "Editar URL del mapa", "editar", $filaContacto); ?>
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
        <a href="../inicio/index.php">Inicio</a>
        <a href="../productos/productos.php">Productos</a>
        <a href="./contactos.php">Contactos</a>
        <a href="#">Nuestro equipo</a>
      </nav>

      <nav class="footer-menu footer-menu-editores">
        <span class="footer-menu-label">Editor de contenido:</span>
        <a href="../inicio/index-formulario.php">Inicio</a>
        <a href="../productos/productos-formulario.php">Productos</a>
        <a href="./contactos-formulario.php">Contacto</a>
      </nav>

      <p class="footer-copy">Copyright 2026. Designed by JULIAN</p>
    </div>
  </div>
</footer>
<!-- Fin footer -->

  <script src="../bootstrap-5.3.8-dist/js/bootstrap.bundle.min.js"></script>
  <script>
    // Evita que el botón "Atrás" muestre esta página protegida desde la caché del navegador
    window.addEventListener("pageshow", function (evento) {
      if (evento.persisted) {
        window.location.reload();
      }
    });
    history.replaceState(null, "", window.location.href);

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
        fetch("../inicio/logout.php", {
          method: "POST",
          credentials: "same-origin",
          body: datosFormulario,
        }).finally(function () {
          window.location.replace("contactos.php");
        });
      });
    }
  </script>
</body>
</html>
