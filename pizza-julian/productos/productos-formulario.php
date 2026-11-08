<?php
declare(strict_types=1);

require_once __DIR__ . "/../inicio/sesion.php";
require_once __DIR__ . "/../inicio/tema.php";
require_once __DIR__ . "/../inicio/imagenes-editor.php";
iniciarSesionSegura();
enviarCabecerasSinCache();

// Solo usuarios autenticados (tabla `usuario`) pueden ver o modificar este editor
if (!usuarioAutenticado()) {
    header("Location: productos.php");
    exit;
}

$tokenCsrfLogout = generarTokenCsrf();

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");
if ($mysqli->connect_error) {
    die("Error de conexión: " . $mysqli->connect_error);
}
// Banner y paleta de colores compartidos por todas las páginas
$temaSitio = obtenerTemaSitio($mysqli);

// Columnas de la tabla `productos` que alimentan las variables de productos.php
$columnasProductos = [
    "img1_carru_productos", "img2_carru_productos", "img3_carru_productos",
    "card_title_productos", "card_texto_productos", "btn_primary_productos",
];
$camposImagen = ["img1_carru_productos", "img2_carru_productos", "img3_carru_productos"];
$directorioImagenes = __DIR__ . "/img-productos";

// Imágenes que el sitio usa de forma fija: nunca se borran al reemplazar
$imagenesProtegidas = ["banner.png", "footer.png"];

function obtenerProducto(mysqli $mysqli, int $id): ?array
{
    $stmt = $mysqli->prepare("SELECT * FROM `productos` WHERE id_producto = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $fila = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $fila ?: null;
}

// Tras procesar el POST se redirige (patrón PRG) a productos-formulario.php sin caché ni reenvío del formulario
// Rechaza envíos del editor sin token CSRF válido (evita modificaciones desde otros sitios)
if ($_SERVER["REQUEST_METHOD"] === "POST" && !csrfValido($_POST["csrf_token"] ?? null)) {
    header("Location: productos-formulario.php?estado=error", true, 303);
    exit;
}

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $accion = $_POST["accion"] ?? "";
    $estado = "error";

    if ($accion === "eliminar") {
        $id = (int) ($_POST["id_producto"] ?? 0);
        $productoActual = $id > 0 ? obtenerProducto($mysqli, $id) : null;
        if ($productoActual) {
            $stmt = $mysqli->prepare("DELETE FROM `productos` WHERE id_producto = ?");
            $stmt->bind_param("i", $id);
            $estado = $stmt->execute() ? "eliminado" : "error";
            $stmt->close();
            if ($estado === "eliminado") {
                eliminarImagenesReemplazadas($mysqli, "productos", $camposImagen, array_map(fn($c) => $productoActual[$c], $camposImagen), $directorioImagenes, $imagenesProtegidas);
            }
        }
    } elseif ($accion === "crear" || $accion === "editar") {
        $id = (int) ($_POST["id_producto"] ?? 0);
        // Las imágenes actuales se leen de la BD (no de campos ocultos que el navegador podría alterar)
        $productoActual = $accion === "editar" ? obtenerProducto($mysqli, $id) : [];
        $valoresImagen = [];
        $imagenesNuevas = [];
        $errorImagen = null;

        if ($productoActual === null) {
            $errorImagen = "error";
        } else {
            foreach ($camposImagen as $campo) {
                $rutaNueva = guardarImagenSubida($_FILES[$campo] ?? null, $directorioImagenes, "producto_", $errorImagen);
                if ($rutaNueva !== null) {
                    $imagenesNuevas[] = $rutaNueva;
                }
                // conservar la imagen actual si no se seleccionó un archivo nuevo
                $valoresImagen[$campo] = $rutaNueva ?? (string) ($productoActual[$campo] ?? "");
                if ($errorImagen === null && $valoresImagen[$campo] === "") {
                    $errorImagen = "imagen_requerida"; // cada tarjeta necesita sus 3 imágenes de carrusel
                }
            }
        }

        if ($errorImagen !== null) {
            // No se guarda nada: se descartan los archivos que sí alcanzaron a subirse en este envío
            descartarImagenesSubidas($imagenesNuevas, $directorioImagenes);
            $mysqli->close();
            header("Location: productos-formulario.php?estado=" . urlencode($errorImagen), true, 303);
            exit;
        }

        $valores = [];
        foreach ($columnasProductos as $columna) {
            $valores[] = in_array($columna, $camposImagen, true)
                ? $valoresImagen[$columna]
                : trim((string) ($_POST[$columna] ?? ""));
        }

        if ($accion === "crear") {
            $columnasSql = implode(", ", array_map(fn($c) => "`$c`", $columnasProductos));
            $marcadores = implode(", ", array_fill(0, count($columnasProductos), "?"));
            $stmt = $mysqli->prepare("INSERT INTO `productos` ($columnasSql) VALUES ($marcadores)");
            $tipos = str_repeat("s", count($valores));
            $stmt->bind_param($tipos, ...$valores);
            $estado = $stmt->execute() ? "creado" : "error";
            $stmt->close();
        } else {
            $setClause = implode(", ", array_map(fn($c) => "`$c` = ?", $columnasProductos));
            $stmt = $mysqli->prepare("UPDATE `productos` SET $setClause WHERE id_producto = ?");
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
            eliminarImagenesReemplazadas($mysqli, "productos", $camposImagen, array_map(fn($c) => $productoActual[$c], $camposImagen), $directorioImagenes, $imagenesProtegidas);
        }
    }

    $mysqli->close();
    header("Location: productos-formulario.php?estado=" . urlencode($estado), true, 303);
    exit;
}

$mensajesPorEstado = [
    "creado" => ["Producto creado correctamente.", "success"],
    "actualizado" => ["Producto actualizado correctamente.", "success"],
    "eliminado" => ["Producto eliminado correctamente.", "success"],
    "error_imagen" => ["Imagen no válida: usa archivos JPG, PNG, GIF o WEBP de máximo 5 MB. No se guardaron cambios.", "danger"],
    "imagen_requerida" => ["Cada producto necesita las 3 imágenes del carrusel. No se guardaron cambios.", "danger"],
    "error" => ["No fue posible completar la operación.", "danger"],
];
$estadoActual = $_GET["estado"] ?? "";
[$mensaje, $tipoMensaje] = $mensajesPorEstado[$estadoActual] ?? ["", "success"];

$filasProductos = [];
$resultado = $mysqli->query("SELECT * FROM `productos` ORDER BY id_producto ASC");
if ($resultado) {
    $filasProductos = $resultado->fetch_all(MYSQLI_ASSOC);
}
$mysqli->close();

function campoProducto(array $fila, string $campo): string
{
    return htmlspecialchars((string) ($fila[$campo] ?? ""), ENT_QUOTES);
}

// Genera el modal (crear o editar) reutilizando el mismo formulario
function renderModalProducto(string $idModal, string $tituloModal, string $accion, array $fila): void
{
    $idProducto = (int) ($fila["id_producto"] ?? 0);
    ?>
    <div class="modal fade editor-modal" id="<?= htmlspecialchars($idModal, ENT_QUOTES) ?>" tabindex="-1" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered modal-lg modal-dialog-scrollable">
        <div class="modal-content">
          <form method="post" enctype="multipart/form-data">
            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars(generarTokenCsrf(), ENT_QUOTES) ?>">
            <input type="hidden" name="accion" value="<?= htmlspecialchars($accion, ENT_QUOTES) ?>">
            <?php if ($accion === "editar"): ?>
                <input type="hidden" name="id_producto" value="<?= $idProducto ?>">
            <?php endif; ?>
            <div class="modal-header">
              <h5 class="modal-title"><?= htmlspecialchars($tituloModal) ?></h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <fieldset>
                <legend>Carrusel del producto</legend>
                <p class="small mb-2" style="color: var(--pizza-gris);">La vista previa muestra cómo quedará cada imagen dentro de la tarjeta (recorte cuadrado). JPG, PNG, GIF o WEBP, máximo 5 MB.</p>
                <div class="row">
                  <?php foreach ([1, 2, 3] as $numero): ?>
                    <?php
                    $campo = "img{$numero}_carru_productos";
                    $imagenActual = campoProducto($fila, $campo);
                    ?>
                    <div class="col-md-4 mb-3">
                      <label class="form-label">Imagen <?= $numero ?></label>
                      <div class="editor-img-preview mb-2">
                        <?php if ($imagenActual !== ""): ?>
                          <img src="<?= $imagenActual ?>" alt="Imagen <?= $numero ?> actual">
                        <?php else: ?>
                          <span>Sin imagen</span>
                        <?php endif; ?>
                      </div>
                      <input type="file" class="form-control input-imagen-producto" name="<?= $campo ?>" accept="image/jpeg,image/png,image/gif,image/webp"<?= $imagenActual === "" ? " required" : "" ?>>
                      <div class="invalid-feedback"></div>
                    </div>
                  <?php endforeach; ?>
                </div>
              </fieldset>

              <fieldset>
                <legend>Contenido de la tarjeta</legend>
                <div class="mb-3">
                  <label class="form-label">Título</label>
                  <input type="text" class="form-control" name="card_title_productos" value="<?= campoProducto($fila, "card_title_productos") ?>" maxlength="200">
                </div>
                <div class="mb-3">
                  <label class="form-label">Texto</label>
                  <textarea class="form-control" name="card_texto_productos" rows="3" maxlength="500"><?= campoProducto($fila, "card_texto_productos") ?></textarea>
                </div>
                <div class="mb-3">
                  <label class="form-label">Texto del botón</label>
                  <input type="text" class="form-control" name="btn_primary_productos" value="<?= campoProducto($fila, "btn_primary_productos") ?>" maxlength="200">
                </div>
              </fieldset>
            </div>
            <div class="modal-footer">
              <a href="productos-formulario.php" class="btn btn-secondary">Cancelar</a>
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
    <title>PIZZA-JULIAN | Editor de Productos</title>
    <link rel="stylesheet" href="../bootstrap-5.3.8-dist/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="./productos.css">
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
                    <a class="nav-link nav-editor active" aria-current="page" href="../productos/productos-formulario.php">Productos</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link nav-editor" href="../contacto/contactos-formulario.php">Contacto</a>
                    </li>
                </ul>
                <div class="d-flex align-items-center">
                  <form method="post" action="../inicio/logout.php" id="formCerrarSesion" class="d-inline">
                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($tokenCsrfLogout, ENT_QUOTES) ?>">
                    <input type="hidden" name="destino" value="productos">
                    <button type="submit" class="btn btn-outline-success">Cerrar sesion</button>
                  </form>
                </div>
                </div>
            </div>
    </nav>
    <!-- Fin Sección Nav -->

    <br>

    <!-- Editor de Contenido de la tabla `productos` -->
    <div class="container editor-panel my-4">
        <h2 class="mb-3"><i class="bi bi-pencil-square"></i> Editor de Contenido - Productos</h2>

        <p class="mb-4" style="color: var(--pizza-gris);">Administra las tarjetas de producto que se muestran en <strong>productos.php</strong>: carrusel de imágenes, título, texto y botón.</p>

        <?php if ($mensaje !== ""): ?>
            <div class="alert alert-<?= $tipoMensaje ?> editor-alert" role="alert"><?= htmlspecialchars($mensaje) ?></div>
        <?php endif; ?>

        <button type="button" class="btn btn-editar mb-3" data-bs-toggle="modal" data-bs-target="#modalCrear">
            <i class="bi bi-plus-circle"></i> Agregar producto
        </button>
        <?php renderModalProducto("modalCrear", "Agregar producto", "crear", []); ?>

        <?php if (empty($filasProductos)): ?>
            <p style="color: var(--pizza-gris);">Todavía no hay productos registrados.</p>
        <?php else: ?>
            <div class="row g-3">
                <?php foreach ($filasProductos as $fila): ?>
                    <?php $idFila = (int) $fila["id_producto"]; ?>
                    <div class="col-12">
                        <div class="card editor-card p-3">
                            <div class="row g-3 align-items-center">
                                <div class="col-md-2 text-center">
                                    <div class="editor-miniatura">
                                        <?php if (trim((string) $fila["img1_carru_productos"]) !== ""): ?>
                                            <img src="<?= htmlspecialchars($fila["img1_carru_productos"], ENT_QUOTES) ?>" alt="Imagen 1">
                                        <?php else: ?>
                                            <span>Sin imagen</span>
                                        <?php endif; ?>
                                    </div>
                                </div>
                                <div class="col-md-7">
                                    <h5 class="card-title mb-1">#<?= $idFila ?> - <?= htmlspecialchars((string) $fila["card_title_productos"], ENT_QUOTES) ?></h5>
                                    <p class="mb-0 small"><?= htmlspecialchars((string) $fila["card_texto_productos"], ENT_QUOTES) ?></p>
                                    <p class="mb-0 small">Botón: <?= htmlspecialchars((string) $fila["btn_primary_productos"], ENT_QUOTES) ?></p>
                                </div>
                                <div class="col-md-3 text-md-end d-flex flex-column flex-md-row gap-2 justify-content-md-end">
                                    <button type="button" class="btn btn-editar" data-bs-toggle="modal" data-bs-target="#modalEditar<?= $idFila ?>">
                                        <i class="bi bi-pencil-square"></i> Editar
                                    </button>
                                    <form method="post" onsubmit="return confirm('¿Eliminar este producto?');" class="d-inline">
                                      <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($tokenCsrfLogout, ENT_QUOTES) ?>">
                                        <input type="hidden" name="accion" value="eliminar">
                                        <input type="hidden" name="id_producto" value="<?= $idFila ?>">
                                        <button type="submit" class="btn btn-eliminar"><i class="bi bi-trash"></i> Eliminar</button>
                                    </form>
                                </div>
                            </div>
                        </div>
                    </div>
                    <?php renderModalProducto("modalEditar{$idFila}", "Editar producto #{$idFila}", "editar", $fila); ?>
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
        <a href="../inicio/index.php">Inicio</a>
        <a href="./productos.php">Productos</a>
        <a href="../contacto/contactos.php">Contactos</a>
        <a href="#">Nuestro equipo</a>
      </nav>

      <nav class="footer-menu footer-menu-editores">
        <span class="footer-menu-label">Editor de contenido:</span>
        <a href="../inicio/index-formulario.php">Inicio</a>
        <a href="./productos-formulario.php">Productos</a>
        <a href="../contacto/contactos-formulario.php">Contacto</a>
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

    // Valida cada imagen al seleccionarla y la muestra con el mismo recorte cuadrado de la tarjeta
    var TIPOS_IMAGEN = ["image/jpeg", "image/png", "image/gif", "image/webp"];
    var TAMANO_MAXIMO_IMAGEN = 5 * 1024 * 1024;

    document.querySelectorAll(".input-imagen-producto").forEach(function (input) {
      var contenedor = input.previousElementSibling;
      var htmlOriginal = contenedor.innerHTML;
      var mensaje = input.nextElementSibling;

      input.addEventListener("change", function () {
        var archivo = input.files[0];
        input.classList.remove("is-invalid");
        contenedor.innerHTML = htmlOriginal;
        if (!archivo) {
          return;
        }

        var error = "";
        if (TIPOS_IMAGEN.indexOf(archivo.type) === -1) {
          error = "Formato no permitido. Usa JPG, PNG, GIF o WEBP.";
        } else if (archivo.size > TAMANO_MAXIMO_IMAGEN) {
          error = "La imagen supera los 5 MB.";
        }

        var marcarError = function (texto) {
          input.value = "";
          input.classList.add("is-invalid");
          mensaje.textContent = texto;
          contenedor.innerHTML = htmlOriginal;
        };
        if (error) {
          marcarError(error);
          return;
        }

        var vistaPrevia = new Image();
        vistaPrevia.alt = "Vista previa";
        vistaPrevia.onload = function () {
          contenedor.innerHTML = "";
          contenedor.appendChild(vistaPrevia);
        };
        vistaPrevia.onerror = function () {
          marcarError("El archivo no es una imagen válida.");
        };
        vistaPrevia.src = URL.createObjectURL(archivo);
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
        fetch("../inicio/logout.php", {
          method: "POST",
          credentials: "same-origin",
          body: datosFormulario,
        }).finally(function () {
          window.location.replace("productos.php");
        });
      });
    }
  </script>
</body>
</html>
