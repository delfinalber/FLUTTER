<?php
declare(strict_types=1);

require_once __DIR__ . "/../inicio/sesion.php";
require_once __DIR__ . "/../inicio/tema.php";
iniciarSesionSegura();
enviarCabecerasSinCache();
$tokenCsrfLogin = generarTokenCsrf();

$mysqli = new mysqli("localhost", "root", "", "tecnico-2026-pagina");
if ($mysqli->connect_error) {
    die("Error de conexión: " . $mysqli->connect_error);
}
// Banner y paleta de colores compartidos por todas las páginas
$temaSitio = obtenerTemaSitio($mysqli);

// Todo el contenido de la tabla `productos` se vuelca a variables PHP antes de imprimir HTML
$productos = [];
$resultadoProductos = $mysqli->query("SELECT * FROM `productos` ORDER BY id_producto ASC");
if ($resultadoProductos) {
    $productos = $resultadoProductos->fetch_all(MYSQLI_ASSOC);
}
$mysqli->close();

$filasProductos = array_chunk($productos, 4);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PIZZA-JULIAN-PRODUCTOS</title>
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
                    <a class="nav-link" href="../inicio/index.php">Inicio</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link active" aria-current="page" href="./productos.php">Productos</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link" href="../contacto/contactos.php">Contacto</a>
                    </li>
                </ul>
                <form class="d-flex" role="search">
                  <button class="btn btn-outline-success" type="button" data-bs-toggle="modal" data-bs-target="#loginModal">Inicio Sesion</button>
                </form>
                </div>
            </div>
    </nav>
    <!-- Fin Sección Nav -->

    <br>

    <?php foreach ($filasProductos as $indiceFila => $filaProductos): ?>
    <!-- Inicio Productos Fila <?= $indiceFila + 1 ?> -->
    <div class="container text-center">
      <div class="row tarjetas-fila">
        <?php foreach ($filaProductos as $producto): ?>
            <?php $idCarrusel = "carouselProducto" . (int) $producto["id_producto"]; ?>
            <div class="col">
              <div class="card producto-card">
                <div id="<?= $idCarrusel ?>" class="carousel slide" data-bs-ride="carousel" data-bs-interval="3000" data-bs-pause="false">
                  <div class="carousel-inner">
                    <div class="carousel-item active">
                      <img src="<?= htmlspecialchars($producto["img1_carru_productos"], ENT_QUOTES) ?>" class="d-block w-100" alt="<?= htmlspecialchars($producto["card_title_productos"], ENT_QUOTES) ?> 1">
                    </div>
                    <div class="carousel-item">
                      <img src="<?= htmlspecialchars($producto["img2_carru_productos"], ENT_QUOTES) ?>" class="d-block w-100" alt="<?= htmlspecialchars($producto["card_title_productos"], ENT_QUOTES) ?> 2">
                    </div>
                    <div class="carousel-item">
                      <img src="<?= htmlspecialchars($producto["img3_carru_productos"], ENT_QUOTES) ?>" class="d-block w-100" alt="<?= htmlspecialchars($producto["card_title_productos"], ENT_QUOTES) ?> 3">
                    </div>
                  </div>
                  <button class="carousel-control-prev" type="button" data-bs-target="#<?= $idCarrusel ?>" data-bs-slide="prev">
                    <span class="carousel-control-prev-icon" aria-hidden="true"></span>
                    <span class="visually-hidden">Previous</span>
                  </button>
                  <button class="carousel-control-next" type="button" data-bs-target="#<?= $idCarrusel ?>" data-bs-slide="next">
                    <span class="carousel-control-next-icon" aria-hidden="true"></span>
                    <span class="visually-hidden">Next</span>
                  </button>
                </div>
                <div class="card-body">
                  <h5 class="card-title"><?= htmlspecialchars($producto["card_title_productos"], ENT_QUOTES) ?></h5>
                  <p class="card-text"><?= htmlspecialchars($producto["card_texto_productos"], ENT_QUOTES) ?></p>
                  <a href="#" class="btn btn-primary"><?= htmlspecialchars($producto["btn_primary_productos"], ENT_QUOTES) ?></a>
                </div>
              </div>
            </div>
        <?php endforeach; ?>
      </div>
    </div>
    <!-- Fin Productos Fila <?= $indiceFila + 1 ?> -->
    <br>
    <?php endforeach; ?>

    <?php if (empty($productos)): ?>
    <div class="container text-center">
      <p class="text-white">Todavía no hay productos publicados.</p>
    </div>
    <br>
    <?php endif; ?>

<!-- Inicio Modal de Sesion -->
<div class="modal fade login-modal" id="loginModal" tabindex="-1" aria-labelledby="loginModalLabel" aria-hidden="true" data-bs-backdrop="static">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="loginModalLabel">Inicio de sesion</h5>
        <span class="login-contador">Tiempo restante: <strong id="loginContadorSegundos">30</strong>s</span>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body">
        <div id="loginAlerta" class="alert d-none" role="alert"></div>
        <form id="formLogin" autocomplete="off" novalidate>
          <input type="hidden" id="csrfTokenLogin" value="<?= htmlspecialchars($tokenCsrfLogin, ENT_QUOTES) ?>">
          <div class="mb-3">
            <label for="usuarioLogin" class="form-label">Usuario</label>
            <input type="text" class="form-control" id="usuarioLogin" name="usuario" placeholder="Digite su usuario" maxlength="200" autocomplete="username" required>
          </div>
          <div class="mb-3">
            <label for="contrasenaLogin" class="form-label">Contrasena</label>
            <input type="password" class="form-control" id="contrasenaLogin" name="password" placeholder="Digite su contrasena" maxlength="200" autocomplete="current-password" required>
          </div>
          <button type="submit" class="btn btn-login w-100" id="btnLoginEntrar">Entrar</button>
        </form>
      </div>
    </div>
  </div>
</div>
<!-- Fin Modal de Sesion -->

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

      <p class="footer-copy">Copyright 2026. Designed by JULIAN</p>
    </div>
  </div>
</footer>
<!-- Fin footer -->

<!-- Inicio boton flotante de whatsapp-->
    <a href="https://wa.me/573132345685?text=Hola%2C+quiero+m%C3%A1s+informaci%C3%B3n+acerca+de+las+PIZZA+JULIAN" class="whatsapp-float" target="_blank" rel="noopener" title="Enviar mensaje por WhatsApp" aria-label="Enviar mensaje por WhatsApp">
     <i class="bi bi-whatsapp" aria-hidden="true"></i>
        <span class="visually-hidden">Enviar mensaje por WhatsApp</span>
    </a>
    <!-- Fin boton flotante de whatsapp-->

  <script src="../bootstrap-5.3.8-dist/js/bootstrap.bundle.min.js"></script>
  <script>
    document.querySelectorAll('.producto-card .carousel').forEach(function (carouselElement) {
      new bootstrap.Carousel(carouselElement, { interval: 3000, ride: 'carousel' });
    });

    // Si el navegador muestra la página desde la caché al pulsar "Atrás", se recarga para reflejar el estado real de la sesión
    window.addEventListener("pageshow", function (evento) {
      if (evento.persisted) {
        window.location.reload();
      }
    });

    (function () {
      const modalEl = document.getElementById("loginModal");
      const formLogin = document.getElementById("formLogin");
      const alertaEl = document.getElementById("loginAlerta");
      const contadorEl = document.getElementById("loginContadorSegundos");
      const btnEntrar = document.getElementById("btnLoginEntrar");
      const modalBootstrap = new bootstrap.Modal(modalEl);
      const SEGUNDOS_INICIALES = 30;
      let segundosRestantes = SEGUNDOS_INICIALES;
      let intervaloId = null;

      function mostrarAlerta(mensaje, tipo) {
        alertaEl.textContent = mensaje;
        alertaEl.className = "alert alert-" + tipo;
      }

      function ocultarAlerta() {
        alertaEl.className = "alert d-none";
        alertaEl.textContent = "";
      }

      function detenerContador() {
        if (intervaloId !== null) {
          clearInterval(intervaloId);
          intervaloId = null;
        }
      }

      function iniciarContador() {
        segundosRestantes = SEGUNDOS_INICIALES;
        contadorEl.textContent = String(segundosRestantes);
        detenerContador();
        intervaloId = setInterval(function () {
          segundosRestantes--;
          contadorEl.textContent = String(Math.max(segundosRestantes, 0));
          if (segundosRestantes <= 0) {
            detenerContador();
            modalBootstrap.hide();
            window.location.replace("productos.php");
          }
        }, 1000);
      }

      modalEl.addEventListener("shown.bs.modal", function () {
        ocultarAlerta();
        formLogin.reset();
        iniciarContador();
        document.getElementById("usuarioLogin").focus();
      });

      modalEl.addEventListener("hidden.bs.modal", function () {
        detenerContador();
        formLogin.reset();
      });

      formLogin.addEventListener("submit", function (evento) {
        evento.preventDefault();
        ocultarAlerta();
        btnEntrar.disabled = true;

        const usuario = document.getElementById("usuarioLogin").value.trim();
        const password = document.getElementById("contrasenaLogin").value;
        const csrfToken = document.getElementById("csrfTokenLogin").value;

        fetch("../inicio/login.php", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          credentials: "same-origin",
          body: JSON.stringify({ usuario: usuario, password: password, csrf_token: csrfToken }),
        })
          .then(function (respuesta) { return respuesta.json(); })
          .then(function (datos) {
            btnEntrar.disabled = false;
            if (datos.ok) {
              detenerContador();
              mostrarAlerta("Acceso correcto, redirigiendo...", "success");
              window.location.replace("productos-formulario.php");
            } else {
              mostrarAlerta(datos.mensaje || "No fue posible iniciar sesión.", "danger");
              document.getElementById("contrasenaLogin").value = "";
            }
          })
          .catch(function () {
            btnEntrar.disabled = false;
            mostrarAlerta("Error de comunicación con el servidor.", "danger");
          });
      });
    })();
  </script>
</body>
</html>
