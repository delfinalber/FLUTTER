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

// El contenido de la tabla `contacto` se vuelca a variables PHP antes de imprimir HTML
$urlContacto = "https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d18953.883843598873!2d-75.2785308969908!3d2.9410217172291766!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x8e3b7464ac59aa5b%3A0x7e513d68543b6eec!2sDomino's%20Pizza%20Las%20Brisas!5e0!3m2!1ses-419!2sco!4v1784748693148!5m2!1ses-419!2sco";
$resultadoContacto = $mysqli->query("SELECT * FROM `contacto` ORDER BY id_contacto ASC LIMIT 1");
if ($resultadoContacto && $resultadoContacto->num_rows > 0) {
    $filaContacto = $resultadoContacto->fetch_assoc();
    $valor = trim((string) ($filaContacto["url_contacto"] ?? ""));
    if ($valor !== "") {
        $urlContacto = $valor;
    }
}
$mysqli->close();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PIZZA-JULIAN-CONTACTO</title>
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
                    <a class="nav-link" href="../inicio/index.php">Inicio</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link" href="../productos/productos.php">Productos</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link active" aria-current="page" href="./contactos.php">Contacto</a>
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
<!--Inicio mapa y formulario-->
      <div class="container text-center">
  <div class="row">
    <div class="col-8">
      <!--Inicio mapa-->
      <iframe src="<?= htmlspecialchars($urlContacto, ENT_QUOTES) ?>" width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="strict-origin-when-cross-origin"></iframe>
      <!--Fin mapa-->
    </div>
    <div class="col-4">
      <!--Inicio Formulario-->
        <div id="formularioContactoMensaje"></div>
        <form id="formularioContacto" action="formulario-contacto.php" method="post">
                <div class="mb-3">
                  <label for="exampleInputEmail1" class="form-label"><b> Email</b></label>
                  <input type="email" class="form-control" id="exampleInputEmail1" aria-describedby="emailHelp" placeholder="Digite su Correo" name="correo">
                  <div id="emailHelp" class="form-text">No comparta el correo.</div>
                </div>
                <div class="mb-3">
                  <label for="exampleInputNombre" class="form-label"><b>Nombre</b></label>
                  <input type="text" class="form-control" id="exampleInputNombre" placeholder="Digite su Nombre" name="nombre">
                </div>
                <div class="mb-3">
                  <label for="exampleInputTelefono" class="form-label"><b>Teléfono</b></label>
                  <input type="text" class="form-control" id="exampleInputTelefono" placeholder="Digite su Telefono" name="telefono">
                </div>
                <div class="mb-3">
                  <label for="exampleInputComentario" class="form-label"><b>Comentario</b></label>
                  <textarea class="form-control" id="exampleInputComentario" rows="3" placeholder="Digite su Comentario" maxlength="500" name="texto_area"></textarea>
                </div>
                <button type="submit" class="btn btn-primary">Submit</button>
        </form>
      <!--Fin Formulario-->
    </div>
  </div>
</div>
<!--Fin mapa y formulario-->

<br>

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
        <a href="../productos/productos.php">Productos</a>
        <a href="./contactos.php">Contactos</a>
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
      // Tras un envío exitoso, limpia el formulario, avisa al usuario y quita el parámetro de la URL/historial.
      document.addEventListener('DOMContentLoaded', function () {
        var params = new URLSearchParams(window.location.search);
        var formulario = document.getElementById('formularioContacto');
        var mensajeContenedor = document.getElementById('formularioContactoMensaje');

        if (params.get('envio') === 'ok') {
          if (formulario) {
            formulario.reset();
          }
          if (mensajeContenedor) {
            mensajeContenedor.innerHTML = '<div class="alert alert-success alert-dismissible fade show" role="alert">' +
              'Tu mensaje se envió correctamente.' +
              '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>' +
              '</div>';
          }
          history.replaceState(null, '', window.location.pathname);
        }
      });

      window.addEventListener('pageshow', function (event) {
        if (event.persisted) {
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
              window.location.replace("contactos.php");
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
                window.location.replace("contactos-formulario.php");
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
