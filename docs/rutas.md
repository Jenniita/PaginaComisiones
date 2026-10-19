# Rutas y pantallas

Documento de detalle de endpoints y pantallas del proyecto de comisiones de
dibujos. Complementa las secciones 5 y 6 de `docs/README.md`.

## 1. Principio general

Todas las pantallas se generan en el servidor:

1. El navegador pide una URL.
2. El servidor consulta la base de datos.
3. El servidor mezcla los datos con una plantilla.
4. El servidor devuelve HTML completo.

No hay `fetch`, AJAX, JSON de datos ni JavaScript de cliente para cargar
contenido. Los formularios usan `POST` normal y el servidor responde con un
redirect o con la misma pantalla si hay errores.

## 2. Rutas de Node.js

Prefijo público: `http://localhost:3000`.

| Método | Ruta | Controlador | Vista / resultado | Estado |
| ------ | ---- | ----------- | ----------------- | ------ |
| `GET` | `/` | `home.index` | `home.ejs` | Placeholder |
| `GET` | `/health` | `home.health` | JSON `{"status":"ok"}` | Funcional |
| `GET` | `/comisiones` | `comisiones.listar` | `comisiones/index.ejs` | Placeholder |
| `GET` | `/comisiones/nueva` | `comisiones.formulario` | `comisiones/form.ejs` | Placeholder |
| `POST` | `/comisiones` | `comisiones.crear` | Redirect a `/comisiones` | Pendiente de lógica |
| `GET` | `/comisiones/:id` | `comisiones.detalle` | `comisiones/show.ejs` | Placeholder |
| `GET` | `/comisiones/:id/editar` | `comisiones.editar` | `comisiones/form.ejs` | Placeholder |
| `POST` | `/comisiones/:id` | `comisiones.actualizar` | Redirect a `/comisiones` | Pendiente de lógica |
| `POST` | `/comisiones/:id/estado` | `comisiones.cambiarEstado` | Redirect a `/comisiones` | Pendiente de lógica |
| Cualquiera | Ruta no definida | Middleware 404 | `404.ejs` | Funcional |

Archivos implicados:

- Rutas: `node/src/routes/index.routes.js`,
  `node/src/routes/comisiones.routes.js`.
- Controladores: `node/src/controllers/home.controller.js`,
  `node/src/controllers/comisiones.controller.js`.
- Vistas: `node/src/views/`.
- Estáticos: `node/src/public/`.

## 3. Rutas de PHP

Prefijo público: `http://localhost:8000`.

| Método | Ruta | Controlador / archivo | Vista / resultado | Estado |
| ------ | ---- | --------------------- | ----------------- | ------ |
| `GET` | `/` | `templates/layout.php` | Página de inicio | Placeholder |
| `GET` | `/health` | `public/index.php` | JSON `{"status":"ok"}` | Funcional |
| `GET` | `/comisiones` | `ComisionController::index` | `templates/comisiones/index.php` | Placeholder |
| `GET` | `/comisiones/{id}` | `ComisionController::show` | `templates/comisiones/show.php` | Placeholder |
| Cualquiera | Ruta no definida | `public/index.php` | `templates/layout.php` con HTTP 404 | Funcional |

Rutas previstas pero todavía no implementadas en PHP:

| Método | Ruta | Pantalla prevista |
| ------ | ---- | ----------------- |
| `GET` | `/comisiones/nueva` | Formulario de alta |
| `POST` | `/comisiones` | Procesar alta |
| `GET` | `/comisiones/{id}/editar` | Formulario de edición |
| `POST` | `/comisiones/{id}` | Procesar actualización |
| `POST` | `/comisiones/{id}/estado` | Cambiar estado |

Archivos implicados:

- Front controller: `php/public/index.php`.
- Reescritura: `php/public/.htaccess`.
- Controlador: `php/src/Controllers/ComisionController.php`.
- Plantillas: `php/templates/`.
- Estáticos: `php/public/css/`.

## 4. Pantallas de Node.js

### 4.1 Inicio (`/`)

- Archivo: `node/src/views/home.ejs`.
- Controlador: `home.index`.
- Datos previstos: comisiones recientes o destacadas.
- Estado actual: título y texto de estructura inicial.

### 4.2 Listado de comisiones (`/comisiones`)

- Archivo: `node/src/views/comisiones/index.ejs`.
- Controlador: `comisiones.listar`.
- Datos previstos: lista de comisiones con título, artista, tipo, estado y
  precio.
- Estado actual: no recorre datos; el controlador envía un array vacío.

### 4.3 Detalle de comisión (`/comisiones/:id`)

- Archivo: `node/src/views/comisiones/show.ejs`.
- Controlador: `comisiones.detalle`.
- Datos previstos: cliente, artista, tipo, estado, descripción, referencias,
  precio, fecha de entrega, archivos y pagos.
- Estado actual: muestra el `id` y un texto pendiente.

### 4.4 Formulario de alta y edición (`/comisiones/nueva` y
`/comisiones/:id/editar`)

- Archivo: `node/src/views/comisiones/form.ejs`.
- Controladores: `comisiones.formulario` y `comisiones.editar`.
- Datos previstos: artistas disponibles, tipos de comisión, estado y datos de la
  comisión en caso de edición.
- Estado actual: título dinámico y texto pendiente; no hay formulario real.

### 4.5 Página 404

- Archivo: `node/src/views/404.ejs`.
- Se muestra para cualquier ruta no definida.
- Código HTTP: 404.

### 4.6 Página de error

- Archivo: `node/src/views/error.ejs`.
- Se muestra cuando el middleware de errores captura una excepción.
- Código HTTP: 500.

### 4.7 Parciales

- `partials/head.ejs`: `<head>`, título y CSS.
- `partials/header.ejs`: navegación y apertura de `<main>`.
- `partials/footer.ejs`: cierre de `<main>`, `<body>` y `<html>`.

## 5. Pantallas de PHP

### 5.1 Inicio (`/`)

- Archivo: `php/templates/layout.php`.
- Datos previstos: presentación y comisiones recientes.
- Estado actual: título y texto de estructura inicial.

### 5.2 Listado (`/comisiones`)

- Archivo: `php/templates/comisiones/index.php`.
- Controlador: `ComisionController::index`.
- Datos previstos: listado de comisiones.
- Estado actual: título y texto pendiente.

### 5.3 Detalle (`/comisiones/{id}`)

- Archivo: `php/templates/comisiones/show.php`.
- Controlador: `ComisionController::show`.
- Datos previstos: ficha completa de la comisión.
- Estado actual: muestra el `id` y un texto pendiente.

### 5.4 Parciales

- `partials/header.php`: `<head>`, navegación y apertura de `<main>`.
- `partials/footer.php`: cierre de `<main>`, `<body>` y `<html>`.

### 5.5 Pantallas pendientes en PHP

Para igualar el flujo de Node faltan:

- `templates/comisiones/form.php` para alta y edición.
- Una pantalla de error 500.
- Una pantalla 404 propia, distinta del layout de inicio.
- Los métodos del controlador y las rutas correspondientes.

## 6. Mapa de navegación

```text
Inicio
  |
  +-- /comisiones
  |     |
  |     +-- /comisiones/nueva
  |     |
  |     +-- /comisiones/:id
  |           |
  |           +-- /comisiones/:id/editar
  |           |
  |           +-- POST /comisiones/:id/estado
  |
  +-- /health
```

Los enlaces actuales de la cabecera son:

- Inicio: `/`.
- Comisiones: `/comisiones`.
- Nueva comisión: `/comisiones/nueva` (solo en Node).

## 7. Flujo de los formularios

1. `GET /comisiones/nueva`: el servidor consulta artistas y tipos y renderiza
   el formulario.
2. El usuario envía el formulario con `POST /comisiones`.
3. El servidor valida.
4. Si hay errores: vuelve a renderizar el formulario con los datos y mensajes.
5. Si todo es correcto: inserta la comisión y responde `303` a
   `/comisiones/:id`.
6. El navegador hace `GET /comisiones/:id` y recibe el detalle en HTML.

Este es el patrón POST / Redirect / GET. Evita duplicados al recargar.

## 8. Ejemplos de peticiones

### Listado

```http
GET /comisiones HTTP/1.1
Host: localhost:3000
```

Respuesta: `200 OK` con HTML completo del listado.

### Detalle

```http
GET /comisiones/7 HTTP/1.1
Host: localhost:3000
```

Respuesta: `200 OK` con la ficha, o `404` si no existe.

### Alta

```http
POST /comisiones HTTP/1.1
Host: localhost:3000
Content-Type: application/x-www-form-urlencoded

titulo=Retrato&descripcion=Mi%20personaje&precio_acordado=45
```

Respuesta prevista: `303 See Other` con `Location: /comisiones/8`.

## 9. Estado actual y pendientes

- Las rutas y vistas existen como estructura.
- Los listados y detalles son placeholders.
- No hay consultas a PostgreSQL desde Node ni PHP.
- Los formularios reales no están implementados.
- Las rutas de PHP para alta, edición y cambio de estado están pendientes.
- Cuando se integre Prisma, solo cambiará la capa de datos de Node; las rutas y
  pantallas seguirán devolviendo HTML generado en el servidor.
