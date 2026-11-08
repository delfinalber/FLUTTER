<?php
declare(strict_types=1);

require_once __DIR__ . "/sesion.php";
require_once __DIR__ . "/tema.php";
iniciarSesionSegura();
enviarCabecerasSinCache();
$tokenCsrfLogin = generarTokenCsrf();

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

// Valores de respaldo si la tabla `inicio` aún no tiene registros
$datosInicio = [
    "banner_inicio" => "./img-inicio/banner.png",
    "carru-1" => "./img-inicio/1.jpeg",
    "carru-2" => "./img-inicio/2.jpeg",
    "carru-3" => "./img-inicio/3.jpeg",
    "url_video_inicio" => "https://www.youtube.com/embed/crdtrzZj3fo?si=__NqB1aheTtDAYfc",
    "acor1_titulo_inicio" => "Margarita (Margherita)",
    "acor1_texto_inicio" => "La reina de las pizzas. Salsa de tomate, mozzarella fresca, albahaca y aceite de oliva.",
    "acor2_titulo_inicio" => "Cuatro Quesos (Quattro Formaggi)",
    "acor2_texto_inicio" => "Una mezcla de quesos fundidos, usualmente mozzarella, gorgonzola (azul), fontina y parmesano.",
    "acor3_titulo_inicio" => "Napolitana",
    "acor3_texto_inicio" => "Salsa de tomate, anchoas, ajo, orégano y aceite de oliva (tradicionalmente no lleva queso).",
    "acor4_titulo_inicio" => "Mexicana",
    "acor4_texto_inicio" => "Incluye carne molida o chorizo, frijoles negros, jalapeños, cebolla y un toque de aguacate o cilantro.",
    "acor5_titulo_inicio" => "Barbacoa (BBQ)",
    "acor5_texto_inicio" => "Sustituye la salsa de tomate por salsa barbacoa, acompañada de pollo, carne picada, cebolla y bacon.",
    "colapsar1_titulo_inicio" => "Vegetariana",
    "colapsar1_texto_inicio" => "Cubierta de vegetales frescos o salteados, como pimientos, cebolla, champiñones, aceitunas y tomates cherry.",
    "colapsar2_titulo_inicio" => "Funghi (Champiñones)",
    "colapsar2_texto_inicio" => "Base de mozzarella con abundantes hongos salteados, a veces con un toque de aceite de trufa.",
    "colapsar3_titulo_inicio" => "Cuatro Estaciones (Quattro Stagioni)",
    "colapsar3_texto_inicio" => "Dividida en cuatro secciones, cada una representando una estación con ingredientes distintos (por ejemplo: alcachofas, champiñones, jamón y albahaca).",
    "numero_whatsapp" => "573132345685",
];

$resultadoInicio = $mysqli->query("SELECT * FROM `inicio` ORDER BY id_inicio ASC LIMIT 1");
if ($resultadoInicio && $resultadoInicio->num_rows > 0) {
    $filaInicio = $resultadoInicio->fetch_assoc();
    foreach ($datosInicio as $campo => $valorPorDefecto) {
        $valor = trim((string) ($filaInicio[$campo] ?? ""));
        $datosInicio[$campo] = $valor !== "" ? $valor : $valorPorDefecto;
    }
}

$mysqli->close();

$datosInicio["url_video_inicio"] = normalizarUrlYoutubeEmbed($datosInicio["url_video_inicio"]);
$whatsappInicio = preg_replace('/\D/', '', $datosInicio["numero_whatsapp"]);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PIZZA-JULIAN</title>
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
                    <a class="nav-link active" aria-current="page" href="./index.php">Inicio</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link" href="../productos/productos.php">Productos</a>
                    </li>
                    <li class="nav-item">
                    <a class="nav-link" href="../contacto/contactos.php">
                        Contacto
                    </a>
                    
                    </li>
                    
                </ul>
                <form class="d-flex" role="search">
                  <button class="btn btn-outline-success" type="button" data-bs-toggle="modal" data-bs-target="#loginModal">Inicio Sesion</button>
                </form>
                </div>
            </div>
    </nav>
    <!-- Fin Sección Nav -->
    <!-- Sección Carrusel y video Youtube -->
     <br>

    <div class="container-fluid p-0 text-center media-section">
            <div class="row g-0 align-items-stretch">
                <div class="col-12 col-lg-8 p-0 media-column">
                    <div id="carouselExampleAutoplaying" class="carousel slide p-0" data-bs-ride="carousel">
                        <div class="carousel-inner">
                                <div class="carousel-item active">
                                <img src="<?= htmlspecialchars($datosInicio["carru-1"], ENT_QUOTES) ?>" class="d-block w-100" alt="...">
                                </div>
                                <div class="carousel-item">
                                <img src="<?= htmlspecialchars($datosInicio["carru-2"], ENT_QUOTES) ?>" class="d-block w-100" alt="...">
                                </div>
                                <div class="carousel-item">
                                <img src="<?= htmlspecialchars($datosInicio["carru-3"], ENT_QUOTES) ?>" class="d-block w-100" alt="...">
                                </div>
                            </div>
                            <button class="carousel-control-prev" type="button" data-bs-target="#carouselExampleAutoplaying" data-bs-slide="prev">
                                <span class="carousel-control-prev-icon" aria-hidden="true"></span>
                                <span class="visually-hidden">Previous</span>
                            </button>
                            <button class="carousel-control-next" type="button" data-bs-target="#carouselExampleAutoplaying" data-bs-slide="next">
                                <span class="carousel-control-next-icon" aria-hidden="true"></span>
                                <span class="visually-hidden">Next</span>
                            </button>
                    </div>
                </div>
                    <div class="col-12 col-lg-4 p-0 media-column">
                        
                        <iframe class="promo-video" src="<?= htmlspecialchars($datosInicio["url_video_inicio"], ENT_QUOTES) ?>" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
                        
                    </div>                
                </div>
    </div>
    <!--Fin Sección Carrusel video Youtube -->
    <br>
    <!--Insertar acordeon-->
    <div class="container">
            <div class="row">
                <div class="col-12">
                <div class="accordion" id="accordionExample">
                    <div class="accordion-item">
                        <h2 class="accordion-header">
                        <button class="accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#collapseOne" aria-expanded="true" aria-controls="collapseOne">
                            <?= htmlspecialchars($datosInicio["acor1_titulo_inicio"]) ?>
                        </button>
                        </h2>
                        <div id="collapseOne" class="accordion-collapse collapse show" data-bs-parent="#accordionExample">
                        <div class="accordion-body accordion-justify">
                            <strong><?= htmlspecialchars($datosInicio["acor1_titulo_inicio"]) ?>.</strong> <?= htmlspecialchars($datosInicio["acor1_texto_inicio"]) ?>
                        </div>
                        </div>
                    </div>
                    <div class="accordion-item">
                        <h2 class="accordion-header">
                        <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseTwo" aria-expanded="false" aria-controls="collapseTwo">
                           <?= htmlspecialchars($datosInicio["acor2_titulo_inicio"]) ?>
                        </button>
                        </h2>
                        <div id="collapseTwo" class="accordion-collapse collapse" data-bs-parent="#accordionExample">
                        <div class="accordion-body accordion-justify">
                            <strong><?= htmlspecialchars($datosInicio["acor2_titulo_inicio"]) ?>.</strong> <?= htmlspecialchars($datosInicio["acor2_texto_inicio"]) ?>
                        </div>
                        </div>
                    </div>
                    <div class="accordion-item">
                        <h2 class="accordion-header">
                        <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseThree" aria-expanded="false" aria-controls="collapseThree">
                            <?= htmlspecialchars($datosInicio["acor3_titulo_inicio"]) ?>
                        </button>
                        </h2>
                        <div id="collapseThree" class="accordion-collapse collapse" data-bs-parent="#accordionExample">
                        <div class="accordion-body accordion-justify">
                            <strong><?= htmlspecialchars($datosInicio["acor3_titulo_inicio"]) ?>.</strong> <?= htmlspecialchars($datosInicio["acor3_texto_inicio"]) ?>
                        </div>
                        </div>
                    </div>
                    <div class="accordion-item">
                        <h2 class="accordion-header">
                        <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseFour" aria-expanded="false" aria-controls="collapseFour">
                           <?= htmlspecialchars($datosInicio["acor4_titulo_inicio"]) ?>
                        </button>
                        </h2>
                        <div id="collapseFour" class="accordion-collapse collapse" data-bs-parent="#accordionExample">
                        <div class="accordion-body accordion-justify">
                            <strong><?= htmlspecialchars($datosInicio["acor4_titulo_inicio"]) ?>.</strong> <?= htmlspecialchars($datosInicio["acor4_texto_inicio"]) ?>
                        </div>
                        </div>
                    </div>
                    <div class="accordion-item">
                        <h2 class="accordion-header">
                        <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseFive" aria-expanded="false" aria-controls="collapseFive">
                           <?= htmlspecialchars($datosInicio["acor5_titulo_inicio"]) ?>
                        </button>
                        </h2>
                        <div id="collapseFive" class="accordion-collapse collapse" data-bs-parent="#accordionExample">
                        <div class="accordion-body accordion-justify">
                            <strong><?= htmlspecialchars($datosInicio["acor5_titulo_inicio"]) ?>.</strong> <?= htmlspecialchars($datosInicio["acor5_texto_inicio"]) ?>
                        </div>
                        </div>
                    </div>
                    </div>
                </div>
    
            </div>
    </div>
    <br>
    <!--Fin acordeon-->
    <!-- Inicio Colapsar -->
    <div class="container text-center colapsar-pizzeria">
  <div class="row">
    <div class="col">
      <p>
  <button class="btn btn-colapsar" type="button" data-bs-toggle="collapse" data-bs-target="#collapseTecnico" aria-expanded="false" aria-controls="collapseTecnico">
    <?= htmlspecialchars($datosInicio["colapsar1_titulo_inicio"]) ?>
  </button>
</p>
<div class="collapse-min-height">
  <div class="collapse collapse-horizontal" id="collapseTecnico">
    <div class="card card-body collapse-card-width">
      <?= htmlspecialchars($datosInicio["colapsar1_texto_inicio"]) ?>
    </div>
  </div>
</div>
    </div>
    <div class="col order-5">
      <p>
  <button class="btn btn-colapsar" type="button" data-bs-toggle="collapse" data-bs-target="#collapseDelfin" aria-expanded="false" aria-controls="collapseDelfin">
    <?= htmlspecialchars($datosInicio["colapsar3_titulo_inicio"]) ?>
  </button>
</p>
<div class="collapse-min-height">
  <div class="collapse collapse-horizontal" id="collapseDelfin">
    <div class="card card-body collapse-card-width">
      <?= htmlspecialchars($datosInicio["colapsar3_texto_inicio"]) ?>
    </div>
  </div>
</div>
    </div>
    <div class="col order-1">
      <p>
  <button class="btn btn-colapsar" type="button" data-bs-toggle="collapse" data-bs-target="#collapseColegio" aria-expanded="false" aria-controls="collapseColegio">
    <?= htmlspecialchars($datosInicio["colapsar2_titulo_inicio"]) ?>
  </button>
</p>
<div class="collapse-min-height">
  <div class="collapse collapse-horizontal" id="collapseColegio">
    <div class="card card-body collapse-card-width">
      <?= htmlspecialchars($datosInicio["colapsar2_texto_inicio"]) ?>
    </div>
  </div>
</div>
    </div>
  </div>
</div>
    <!-- Fin Colapsar -->
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
        <a href="./index.php">Inicio</a>
        <a href="../productos/productos.php">Productos</a>
        <a href="../contacto/contactos.php">Contactos</a> 
        
        <a href="#">Nuestro equipo</a>
      </nav>

      <p class="footer-copy">Copyright 2026. Designed by JULIAN</p>
    </div>
  </div>
</footer>

 <!-- Fin footer   -->
<!-- Inicio boton flotante de whatsapp-->
    <!-- Enlace del Botón de WhatsApp (URL estática: este archivo es .html y no procesa PHP) -->
    <a href="https://wa.me/<?= htmlspecialchars($whatsappInicio, ENT_QUOTES) ?>?text=Hola%2C+quiero+m%C3%A1s+informaci%C3%B3n+acerca+de+las+PIZZA+JULIAN" class="whatsapp-float" target="_blank" rel="noopener" title="Enviar mensaje por WhatsApp" aria-label="Enviar mensaje por WhatsApp">
     <i class="bi bi-whatsapp" aria-hidden="true"></i>
        <span class="visually-hidden">Enviar mensaje por WhatsApp</span>
    </a>
    <!-- Fin boton flotante de whatsapp-->


  <script src="../bootstrap-5.3.8-dist/js/bootstrap.bundle.min.js"></script>
  <script>
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
          window.location.replace("index.php");
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

      fetch("login.php", {
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
            window.location.replace("index-formulario.php");
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