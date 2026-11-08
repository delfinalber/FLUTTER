// Tema compartido por todas las páginas: aplica el banner y su paleta de colores sin recargar
(function () {
  var CLAVE_AVISO = "pizzaJulianTemaActualizado";

  function estiloTema() {
    return document.getElementById("tema-sitio");
  }

  function aplicarTema(tema) {
    var raiz = document.documentElement;
    Object.keys(tema.paleta).forEach(function (clave) {
      raiz.style.setProperty("--pizza-" + clave, tema.paleta[clave]);
    });
    raiz.style.setProperty("--banner-url", 'url("' + tema.banner + '")');
    document.querySelectorAll(".banner img").forEach(function (img) {
      img.src = tema.banner;
    });
    if (tema.version && estiloTema()) {
      estiloTema().dataset.version = tema.version;
    }
  }

  // Quita la vista previa y vuelve a los valores que imprimió el servidor
  function restaurarTema(bannerOriginal) {
    var raiz = document.documentElement;
    Array.prototype.slice.call(raiz.style).forEach(function (propiedad) {
      if (propiedad.indexOf("--pizza-") === 0 || propiedad === "--banner-url") {
        raiz.style.removeProperty(propiedad);
      }
    });
    document.querySelectorAll(".banner img").forEach(function (img) {
      img.src = bannerOriginal;
    });
  }

  // Consulta el tema guardado y lo aplica si cambió (otro editor actualizó el banner)
  function sincronizarTema() {
    fetch("../inicio/tema-json.php", { cache: "no-store", credentials: "same-origin" })
      .then(function (respuesta) { return respuesta.json(); })
      .then(function (tema) {
        var versionActual = estiloTema() ? estiloTema().dataset.version : "";
        if (tema.ok && tema.version !== versionActual) {
          aplicarTema(tema);
        }
      })
      .catch(function () {});
  }

  function avisarTemaActualizado() {
    try {
      localStorage.setItem(CLAVE_AVISO, String(Date.now()));
    } catch (e) {}
  }

  // ---- Paleta a partir de la imagen del banner ----
  function hslAHex(h, s, l) {
    h = ((h % 360) + 360) % 360;
    var c = (1 - Math.abs(2 * l - 1)) * s;
    var x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    var m = l - c / 2;
    var rgb = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return "#" + rgb.map(function (v) {
      return ("0" + Math.round((v + m) * 255).toString(16)).slice(-2);
    }).join("");
  }

  function luminancia(hex) {
    var canales = [1, 3, 5].map(function (i) {
      var v = parseInt(hex.substr(i, 2), 16) / 255;
      return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * canales[0] + 0.7152 * canales[1] + 0.0722 * canales[2];
  }

  function rgbAHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255;
    var max = Math.max(r, g, b), min = Math.min(r, g, b);
    var h = 0, s = 0, l = (max + min) / 2;
    if (max !== min) {
      var d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      h = max === r ? (g - b) / d + (g < b ? 6 : 0) : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
      h *= 60;
    }
    return [h, s, l];
  }

  function distanciaTono(a, b) {
    var d = Math.abs(a - b) % 360;
    return d > 180 ? 360 - d : d;
  }

  // Ajusta la luminosidad hasta cumplir el contraste que necesita cada rol del diseño
  function colorConLuminancia(tono, saturacion, luz, paso, cumple) {
    var hex = hslAHex(tono, saturacion, luz);
    while (!cumple(luminancia(hex)) && luz > 0.05 && luz < 0.9) {
      luz += paso;
      hex = hslAHex(tono, saturacion, luz);
    }
    return hex;
  }

  // Devuelve la paleta {negro, naranja, ...} con los tonos del banner, o null si la imagen no tiene colores definidos
  function extraerPaletaBanner(imagen) {
    var ancho = 160;
    var alto = Math.max(1, Math.round(imagen.naturalHeight * ancho / imagen.naturalWidth));
    var lienzo = document.createElement("canvas");
    lienzo.width = ancho;
    lienzo.height = alto;
    var contexto = lienzo.getContext("2d", { willReadFrequently: true });
    contexto.drawImage(imagen, 0, 0, ancho, alto);
    var pixeles = contexto.getImageData(0, 0, ancho, alto).data;

    // histograma de tonos (36 grupos de 10°) de los píxeles con color vivo
    var pesos = new Array(36).fill(0);
    for (var i = 0; i < pixeles.length; i += 4) {
      var hsl = rgbAHsl(pixeles[i], pixeles[i + 1], pixeles[i + 2]);
      if (hsl[1] > 0.45 && hsl[2] > 0.25 && hsl[2] < 0.75) {
        pesos[Math.floor(hsl[0] / 10) % 36] += hsl[1];
      }
    }
    var maximo = Math.max.apply(null, pesos);
    if (maximo < ancho * alto * 0.01) {
      return null; // imagen casi en blanco y negro: se usa la paleta por defecto
    }

    // tono principal: promedio circular del grupo dominante y sus vecinos
    var principal = pesos.indexOf(maximo);
    var sumaX = 0, sumaY = 0;
    [-1, 0, 1].forEach(function (desplazamiento) {
      var grupo = (principal + desplazamiento + 36) % 36;
      var angulo = (grupo * 10 + 5) * Math.PI / 180;
      sumaX += Math.cos(angulo) * pesos[grupo];
      sumaY += Math.sin(angulo) * pesos[grupo];
    });
    var tonoNaranja = (Math.atan2(sumaY, sumaX) * 180 / Math.PI + 360) % 360;

    // entre los tonos importantes, el más oscuro hace de "rojo" y el más claro de "amarillo"
    var luzDeTono = function (tono) { return luminancia(hslAHex(tono, 1, 0.5)); };
    var tonoRojo = tonoNaranja, tonoAmarillo = tonoNaranja;
    pesos.forEach(function (peso, grupo) {
      if (peso < maximo * 0.15) {
        return;
      }
      var tono = grupo * 10 + 5;
      if (luzDeTono(tono) < luzDeTono(tonoRojo)) { tonoRojo = tono; }
      if (luzDeTono(tono) > luzDeTono(tonoAmarillo)) { tonoAmarillo = tono; }
    });
    if (distanciaTono(tonoRojo, tonoNaranja) < 15) {
      tonoRojo = luzDeTono(tonoNaranja - 25) < luzDeTono(tonoNaranja + 25) ? tonoNaranja - 25 : tonoNaranja + 25;
    }
    if (distanciaTono(tonoAmarillo, tonoNaranja) < 10) {
      tonoAmarillo = luzDeTono(tonoNaranja - 15) > luzDeTono(tonoNaranja + 15) ? tonoNaranja - 15 : tonoNaranja + 15;
    }

    // mismas saturaciones y luces que el diseño original: solo cambian los tonos
    var naranja = colorConLuminancia(tonoNaranja, 1, 0.55, 0.02, function (lum) { return lum >= 0.38; });
    return {
      "negro": hslAHex(tonoRojo, 0.25, 0.047),
      "negro-suave": hslAHex(tonoRojo, 0.21, 0.084),
      "naranja": naranja,
      "amarillo": colorConLuminancia(tonoAmarillo, 1, 0.55, 0.02, function (lum) { return lum >= Math.max(0.55, luminancia(naranja) + 0.1); }),
      "rojo": colorConLuminancia(tonoRojo, 0.91, 0.445, -0.02, function (lum) { return lum <= 0.16; }),
      "rojo-profundo": colorConLuminancia(tonoRojo, 0.88, 0.3, -0.02, function (lum) { return lum <= 0.07; }),
      "rojo-vivo": colorConLuminancia(tonoRojo, 1, 0.59, -0.02, function (lum) { return lum <= 0.3; }),
      "blanco": hslAHex(tonoNaranja, 0.2, 0.96),
      "gris": hslAHex(tonoNaranja, 0.17, 0.89),
    };
  }

  // Otra pestaña guardó un banner nuevo: aplicar el tema al instante
  window.addEventListener("storage", function (evento) {
    if (evento.key === CLAVE_AVISO) {
      sincronizarTema();
    }
  });
  // Al volver a una pestaña que estaba en segundo plano se revisa si el tema cambió
  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "visible") {
      sincronizarTema();
    }
  });

  window.temaSitio = {
    aplicarTema: aplicarTema,
    restaurarTema: restaurarTema,
    sincronizarTema: sincronizarTema,
    avisarTemaActualizado: avisarTemaActualizado,
    extraerPaletaBanner: extraerPaletaBanner,
  };
})();
