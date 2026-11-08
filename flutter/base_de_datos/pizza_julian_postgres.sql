-- =====================================================================
-- Base de datos PostgreSQL para la app móvil PIZZA JULIAN (Flutter)
-- Basada en: pizza-julian/bd/tecnico-2026-pagina.sql (MariaDB)
--
-- Cambios respecto a la versión MariaDB:
--   * Nombres con guion pasan a guion bajo (PostgreSQL no los admite sin comillas):
--       `formulario-contacto` -> formulario_contacto, `carru-1` -> carru_1, `fecha-formulario` -> fecha_formulario
--   * AUTO_INCREMENT -> GENERATED ALWAYS AS IDENTITY
--   * Se agrega la tabla `contacto` (la usa contactos.php pero no estaba en el volcado)
--   * Se agrega la tabla `sesion_api` (tokens de inicio de sesión de la app móvil)
--   * Las contraseñas se verifican en la base con pgcrypto (bcrypt), igual que password_verify de PHP
--   * Las rutas de imágenes son relativas a la carpeta /media del servidor API
--
-- Uso (desde PowerShell):
--   & "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE DATABASE pizza_julian ENCODING 'UTF8';"
--   & "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -d pizza_julian -f base_de_datos\pizza_julian_postgres.sql
-- =====================================================================

SET client_encoding = 'UTF8';

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS sesion_api;
DROP TABLE IF EXISTS formulario_contacto;
DROP TABLE IF EXISTS contacto;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS inicio;
DROP TABLE IF EXISTS usuario;

-- ---------------------------------------------------------------------
-- Usuarios que pueden entrar a los editores de contenido
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
  id_usuario  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario     VARCHAR(200) NOT NULL UNIQUE,
  password    VARCHAR(200) NOT NULL -- hash bcrypt
);

-- Mismo usuario y hash del sitio web. PHP genera "$2y$" y pgcrypto usa "$2a$":
-- son el mismo algoritmo, por eso solo se cambia el prefijo y la contraseña sigue siendo la misma.
INSERT INTO usuario (usuario, password) VALUES
('alberdelfin', '$2a$10$eGR.EOb270JBg7t30CyVNO7Z9HK4j3L.APJsD12lsRX8OfGx4FzUG');

-- Para crear otro usuario o cambiar una contraseña:
--   INSERT INTO usuario (usuario, password) VALUES ('nuevo', crypt('su-clave', gen_salt('bf', 10)));
--   UPDATE usuario SET password = crypt('nueva-clave', gen_salt('bf', 10)) WHERE usuario = 'alberdelfin';

-- ---------------------------------------------------------------------
-- Tokens de sesión de la app (reemplazan la sesión PHP con cookie)
-- ---------------------------------------------------------------------
CREATE TABLE sesion_api (
  token       CHAR(64) PRIMARY KEY,
  id_usuario  INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
  creado      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expira      TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_sesion_api_expira ON sesion_api (expira);

-- ---------------------------------------------------------------------
-- Contenido de la pantalla Inicio (el primer registro define banner y paleta de toda la app)
-- ---------------------------------------------------------------------
CREATE TABLE inicio (
  id_inicio                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  banner_inicio            VARCHAR(200) NOT NULL DEFAULT '',
  paleta_banner            VARCHAR(400) NOT NULL DEFAULT '',
  carru_1                  VARCHAR(200) NOT NULL DEFAULT '',
  carru_2                  VARCHAR(200) NOT NULL DEFAULT '',
  carru_3                  VARCHAR(200) NOT NULL DEFAULT '',
  url_video_inicio         VARCHAR(200) NOT NULL DEFAULT '',
  acor1_titulo_inicio      VARCHAR(150) NOT NULL DEFAULT '',
  acor1_texto_inicio       VARCHAR(500) NOT NULL DEFAULT '',
  acor2_titulo_inicio      VARCHAR(150) NOT NULL DEFAULT '',
  acor2_texto_inicio       VARCHAR(500) NOT NULL DEFAULT '',
  acor3_titulo_inicio      VARCHAR(150) NOT NULL DEFAULT '',
  acor3_texto_inicio       VARCHAR(500) NOT NULL DEFAULT '',
  acor4_titulo_inicio      VARCHAR(150) NOT NULL DEFAULT '',
  acor4_texto_inicio       VARCHAR(500) NOT NULL DEFAULT '',
  acor5_titulo_inicio      VARCHAR(150) NOT NULL DEFAULT '',
  acor5_texto_inicio       VARCHAR(500) NOT NULL DEFAULT '',
  colapsar1_titulo_inicio  VARCHAR(150) NOT NULL DEFAULT '',
  colapsar1_texto_inicio   VARCHAR(500) NOT NULL DEFAULT '',
  colapsar2_titulo_inicio  VARCHAR(150) NOT NULL DEFAULT '',
  colapsar2_texto_inicio   VARCHAR(500) NOT NULL DEFAULT '',
  colapsar3_titulo_inicio  VARCHAR(150) NOT NULL DEFAULT '',
  colapsar3_texto_inicio   VARCHAR(500) NOT NULL DEFAULT '',
  numero_whatsapp          VARCHAR(20)  NOT NULL DEFAULT '',
  actualizado              TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO inicio (
  banner_inicio, carru_1, carru_2, carru_3, url_video_inicio,
  acor1_titulo_inicio, acor1_texto_inicio, acor2_titulo_inicio, acor2_texto_inicio,
  acor3_titulo_inicio, acor3_texto_inicio, acor4_titulo_inicio, acor4_texto_inicio,
  acor5_titulo_inicio, acor5_texto_inicio,
  colapsar1_titulo_inicio, colapsar1_texto_inicio, colapsar2_titulo_inicio, colapsar2_texto_inicio,
  colapsar3_titulo_inicio, colapsar3_texto_inicio, numero_whatsapp
) VALUES (
  'inicio/banner.png', 'inicio/1.jpeg', 'inicio/2.jpeg', 'inicio/3.jpeg', 'https://www.youtube.com/embed/crdtrzZj3fo',
  'Margarita (Margherita)', 'La reina de las pizzas. Salsa de tomate, mozzarella fresca, albahaca y aceite de oliva EUGENIO FERRO FALLA.',
  'Cuatro Quesos (Quattro Formaggi)', 'Una mezcla de quesos fundidos, usualmente mozzarella, gorgonzola (azul), fontina y parmesano.',
  'Napolitana', 'Salsa de tomate, anchoas, ajo, orégano y aceite de oliva (tradicionalmente no lleva queso).',
  'Mexicana', 'Incluye carne molida o chorizo, frijoles negros, jalapeños, cebolla y un toque de aguacate o cilantro.',
  'Barbacoa (BBQ)', 'Sustituye la salsa de tomate por salsa barbacoa, acompañada de pollo, carne picada, cebolla y bacon.',
  'Vegetariana', 'Cubierta de vegetales frescos o salteados, como pimientos, cebolla, champiñones, aceitunas y tomates cherry.',
  'Cuatro Estaciones (Quattro Stagioni)', 'Dividida en cuatro secciones, cada una representando una estación con ingredientes distintos (por ejemplo: alcachofas, champiñones, jamón y albahaca).',
  'Funghi (Champiñones)', 'Base de mozzarella con abundantes hongos salteados, a veces con un toque de aceite de trufa.',
  '573132345685'
);

-- ---------------------------------------------------------------------
-- Tarjetas de la pantalla Productos (cada una con un carrusel de 3 imágenes)
-- ---------------------------------------------------------------------
CREATE TABLE productos (
  id_producto            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  img1_carru_productos   VARCHAR(200) NOT NULL,
  img2_carru_productos   VARCHAR(200) NOT NULL,
  img3_carru_productos   VARCHAR(200) NOT NULL,
  card_title_productos   VARCHAR(200) NOT NULL,
  card_texto_productos   VARCHAR(500) NOT NULL,
  btn_primary_productos  VARCHAR(200) NOT NULL
);

-- Productos que el sitio tenía publicados en productos.html
INSERT INTO productos (img1_carru_productos, img2_carru_productos, img3_carru_productos, card_title_productos, card_texto_productos, btn_primary_productos) VALUES
('productos/pizza1.png',   'productos/pizza2.png',   'productos/pizza3.png',   'Pizza Napolitana',           'Salsa de tomate, anchoas, ajo, orégano y aceite de oliva.', 'Pedir ahora'),
('productos/pizza4.jpeg',  'productos/pizza5.png',   'productos/pizza6.png',   'Pizza Boloñesa',             'Salsa boloñesa de carne, mozzarella y orégano.', 'Pedir ahora'),
('productos/pizza7.jpeg',  'productos/pizza8.png',   'productos/pizza9.png',   'Pizza Hawaiana',             'Jamón, piña, mozzarella y salsa de tomate.', 'Pedir ahora'),
('productos/pizza10.jpeg', 'productos/pizza11.png',  'productos/pizza12.png',  'Pizza Vegetariana',          'Pimientos, cebolla, champiñones, aceitunas y tomates cherry.', 'Pedir ahora'),
('productos/pizza13.jpg',  'productos/pizza14.png',  'productos/pizza15.png',  'Pizza Ranchera',             'Carne, maíz tierno, tocineta y salsa ranchera.', 'Pedir ahora'),
('productos/pizza16.png',  'productos/pizza17.png',  'productos/pizza18.png',  'Pizza Tocineta',             'Tocineta crocante, mozzarella y salsa de la casa.', 'Pedir ahora'),
('productos/pizza19.jpeg', 'productos/pizza20.png',  'productos/pizza21.png',  'Pizza Aceitunas',            'Aceitunas negras y verdes, mozzarella y orégano.', 'Pedir ahora'),
('productos/pizza22.jpeg', 'productos/pizza23.png',  'productos/pizza24.png',  'Pizza de Todito',            'Un poco de todo: carnes, vegetales y mucho queso.', 'Pedir ahora'),
('productos/pizza25.jpeg', 'productos/pizza26.png',  'productos/pizza27.png',  'Pizza Trufa Andina',         'Salsa blanca, queso mozzarella, champinones y toque de trufa.', 'Pedir ahora'),
('productos/pizza28.jpeg', 'productos/pizza29.png',  'productos/pizza30.jpeg', 'Pizza Mediterranea Fina',    'Salsa pomodoro, aceitunas negras, tomate seco y hojas de albahaca.', 'Pedir ahora'),
('productos/pizza31.jpeg', 'productos/pizza32.png',  'productos/pizza33.jpeg', 'Pizza BBQ Ahumada',          'Salsa BBQ casera, pollo ahumado, cebolla morada y queso cheddar.', 'Pedir ahora'),
('productos/pizza43.png',  'productos/pizza44.png',  'productos/pizza45.png',  'Pizza Serrana',              'Jamón serrano, rúcula fresca, queso parmesano y aceite de oliva.', 'Pedir ahora'),
('productos/pizza34.jpeg', 'productos/pizza35.png',  'productos/pizza36.png',  'Pizza Cuatro Quesos Deluxe', 'Mozzarella, parmesano, provolone y azul con toque de oregano.', 'Pedir ahora'),
('productos/pizza37.png',  'productos/pizza38.png',  'productos/pizza39.png',  'Pizza Carbonara',            'Base cremosa, tocineta crocante, cebolla salteada y pimienta negra.', 'Pedir ahora'),
('productos/pizza40.png',  'productos/pizza41.png',  'productos/pizza42.png',  'Pizza Criolla Picante',      'Chorizo artesanal, pimenton rojo, maiz tierno y salsa picante de la casa.', 'Pedir ahora'),
('productos/pizza46.jpeg', 'productos/pizza47.jpeg', 'productos/pizza48.png',  'Pizza Marinera',             'Camarones al ajillo, salsa de tomate, mozzarella y perejil fresco.', 'Pedir ahora');

-- ---------------------------------------------------------------------
-- Mapa de la pantalla Contacto
-- ---------------------------------------------------------------------
CREATE TABLE contacto (
  id_contacto   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  url_contacto  VARCHAR(1000) NOT NULL
);

INSERT INTO contacto (url_contacto) VALUES
('https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d18953.883843598873!2d-75.2785308969908!3d2.9410217172291766!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x8e3b7464ac59aa5b%3A0x7e513d68543b6eec!2sDomino''s%20Pizza%20Las%20Brisas!5e0!3m2!1ses-419!2sco!4v1784748693148!5m2!1ses-419!2sco');

-- ---------------------------------------------------------------------
-- Mensajes que llegan desde el formulario de contacto
-- ---------------------------------------------------------------------
CREATE TABLE formulario_contacto (
  id_formulario        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  correo_formulario    VARCHAR(150) NOT NULL,
  nombre_formulario    VARCHAR(150) NOT NULL,
  telefono_formulario  VARCHAR(20)  NOT NULL DEFAULT '',
  mensaje_formulario   TEXT         NOT NULL,
  fecha_formulario     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO formulario_contacto (correo_formulario, nombre_formulario, telefono_formulario, mensaje_formulario, fecha_formulario) VALUES
('delfin.alber@gmail.com', 'Prueba Automatica', '3132345685', 'Mensaje de prueba desde agente', '2026-08-28 14:37:37+00'),
('delfin.alber@gmail.com', 'DANNA LISETH PULIDO ZABALETA', '3132345685', 'Hola', '2026-08-28 14:40:29+00'),
('delfin.alber@gmail.com', 'ALBER DELFIN PEÑA ORTIGOZA', '3132345685', 'Hola un saludo', '2026-08-28 14:48:52+00'),
('g46113026@gmail.com', 'CUALQUIERA', '3213386504', 'Hola checho estamos en el Tecnico Programando con PHP.', '2026-09-02 18:30:40+00');

COMMIT;
