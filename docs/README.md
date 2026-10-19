# Infraestructura del proyecto: página de comisiones de dibujos

> Documento de diseño. Describe la infraestructura y el funcionamiento propuesto
> antes de montarla. El repositorio contiene una base mínima (Node.js plano, PHP
> y PostgreSQL); las secciones marcadas como "propuesta" indican lo que se
> implementará después de validar este documento.

## 1. Objetivo

Construir una aplicación web de comisiones de dibujos con dos clientes web
independientes (Node.js y PHP) que comparten la misma base de datos PostgreSQL,
todo ejecutado con Docker Compose.

La aplicación sigue el modelo clásico de **renderizado en el servidor**: el
navegador pide una página, el servidor consulta la base de datos, mezcla los
datos con una plantilla y devuelve el HTML ya completo. No hay JavaScript que
pida datos después de cargar la página.

Requisitos de organización:

- Toda la documentación vive en `docs/`.
- Cada lenguaje tiene su propia carpeta: `node/` y `php/`.
- No hay archivos sueltos en la raíz salvo configuración global del proyecto
  (`docker-compose.yml`, `.env.example`, `.gitignore`, `.dockerignore`, `README`
  raíz opcional).
- La base de datos y sus scripts viven en `database/`.
- No se versionan secretos ni dependencias instaladas.

## 2. La idea central: el servidor genera el HTML completo

Esta es la parte más importante del proyecto y la que hay que entender antes de
programar: **el HTML que ve el usuario se construye en el servidor**, no en el
navegador.

### 2.1 Esquema del proceso

```text
 Navegador                        Servidor (Node.js o PHP)              PostgreSQL
     |                                        |                             |
     | 1. GET /comisiones                     |                             |
     |--------------------------------------->|                             |
     |                                        | 2. Consulta SQL             |
     |                                        |---------------------------->|
     |                                        |                             |
     |                                        | 3. Filas de datos           |
     |                                        |<----------------------------|
     |                                        |                             |
     |                                        | 4. Mezcla los datos con la  |
     |                                        |    plantilla (EJS o PHP)    |
     |                                        |    y genera un HTML completo|
     |                                        |                             |
     | 5. Respuesta: HTML completo (200 OK)   |                             |
     |<---------------------------------------|                             |
     |                                        |                             |
     | 6. El navegador solo pinta el HTML     |                             |
     |    y descarga CSS e imágenes           |                             |
```

### 2.2 Paso a paso

1. **El navegador pide una página.** El usuario escribe una URL (por ejemplo
   `/comisiones`) o envía un formulario. Es una petición HTTP normal.
2. **El servidor recibe la petición y la enruta.** Express (Node.js) o
   `public/index.php` (PHP) deciden qué controlador debe atenderla.
3. **El controlador pide los datos al modelo.** El modelo ejecuta una consulta
   SQL parametrizada contra PostgreSQL.
4. **La base de datos devuelve las filas.** No devuelve HTML ni JSON al
   navegador: devuelve datos al servidor.
5. **El servidor mezcla datos y plantilla.** El motor de plantillas sustituye
   las etiquetas de la plantilla por los valores reales y genera una cadena de
   HTML completa.
6. **El servidor envía el HTML terminado.** La respuesta tiene
   `Content-Type: text/html`.
7. **El navegador muestra la página.** Solo interpreta el HTML y descarga los
   recursos estáticos (CSS e imágenes). No ejecuta ninguna petición adicional
   para obtener los datos.

### 2.3 Qué significa "sin JavaScript que pida datos después"

- No se usa `fetch`, `XMLHttpRequest`, AJAX ni ninguna llamada a una API desde
  el navegador para cargar o refrescar datos.
- No hay React, Vue, Angular ni una SPA. Cada navegación devuelve una página
  HTML nueva y completa.
- Los formularios se envían de forma tradicional (`<form method="post">`) y el
  servidor responde con otra página HTML.
- El proyecto no necesita JavaScript para funcionar. Solo se usan HTML, CSS,
  enlaces y formularios.
- Toda la lógica de negocio y todas las consultas SQL ocurren en el servidor.

### 2.4 Ejemplo: listado de comisiones

Petición:

```http
GET /comisiones HTTP/1.1
Host: localhost:3000
```

El servidor ejecuta una consulta:

```sql
SELECT c.id,
       c.titulo,
       c.precio_acordado,
       e.nombre AS estado,
       a.nombre_artistico
FROM comisiones c
JOIN estados_comision e ON e.id = c.estado_id
JOIN artistas a ON a.id = c.artista_id
ORDER BY c.creado_en DESC;
```

El controlador pasa las filas a la plantilla:

```js
const comisiones = await comisionesModel.listarTodas();
res.render('comisiones/index.ejs', { titulo: 'Comisiones', comisiones });
```

La plantilla EJS recorre los datos y genera HTML:

```ejs
<% comisiones.forEach((comision) => { %>
  <tr>
    <td>
      <a href="/comisiones/<%= comision.id %>"><%= comision.titulo %></a>
    </td>
    <td><%= comision.nombre_artistico %></td>
    <td><%= comision.estado %></td>
    <td><%= comision.precio_acordado %> EUR</td>
  </tr>
<% }) %>
```

El navegador recibe algo como:

```html
<tr>
  <td><a href="/comisiones/7">Retrato de mi personaje</a></td>
  <td>Kira</td>
  <td>en_proceso</td>
  <td>45.00 EUR</td>
</tr>
```

El navegador nunca supo que existía una base de datos: solo recibió HTML.

### 2.5 Ejemplo: detalle de una comisión

1. El usuario pulsa el enlace `/comisiones/7`.
2. El servidor ejecuta `SELECT ... FROM comisiones WHERE id = $1` con el valor
   `7`.
3. Si la fila existe, renderiza `comisiones/show.ejs` con esos datos.
4. Si no existe, responde con la página `404.ejs` y el código HTTP 404.

### 2.6 Ejemplo: crear una comisión (formulario tradicional)

1. `GET /comisiones/nueva`: el servidor consulta artistas y tipos de comisión,
   y renderiza el formulario vacío.
2. El navegador muestra el formulario con `action="/comisiones"` y
   `method="post"`.
3. El usuario lo rellena y pulsa "Enviar". El navegador hace un `POST` normal,
   sin JavaScript.
4. El servidor lee los datos, valida, ejecuta el `INSERT` y responde con un
   redirect `303` a `/comisiones/8`.
5. El navegador hace `GET /comisiones/8` y recibe la ficha completa en HTML.

Este patrón se llama **POST / Redirect / GET** y evita que al recargar se vuelva
a crear la comisión. Si hay errores de validación, el servidor vuelve a
renderizar el formulario con los datos introducidos y los mensajes de error,
también sin JavaScript.

### 2.7 Ejemplo equivalente en PHP

```php
// public/index.php decide la ruta y llama al controlador
$comisiones = $comisionModel->listarTodas();
require __DIR__ . '/../templates/comisiones/index.php';
```

```php
<!-- templates/comisiones/index.php -->
<?php foreach ($comisiones as $comision): ?>
  <tr>
    <td>
      <a href="/comisiones/<?= (int) $comision['id'] ?>">
        <?= htmlspecialchars($comision['titulo']) ?>
      </a>
    </td>
    <td><?= htmlspecialchars($comision['nombre_artistico']) ?></td>
    <td><?= htmlspecialchars($comision['estado']) ?></td>
    <td><?= htmlspecialchars($comision['precio_acordado']) ?> EUR</td>
  </tr>
<?php endforeach; ?>
```

El resultado es el mismo: PHP consulta la base de datos, mezcla los datos con la
plantilla y devuelve HTML completo al navegador.

### 2.8 Responsabilidades de cada capa

| Capa          | Responsabilidad                                      | Tecnología              |
| ------------- | ---------------------------------------------------- | ----------------------- |
| Navegador     | Pedir páginas, mostrar HTML y enviar formularios     | HTML y CSS              |
| Rutas         | Decidir qué controlador atiende cada URL             | Express Router / PHP    |
| Controlador   | Validar la entrada y coordinar el flujo              | JavaScript / PHP        |
| Modelo        | Ejecutar las consultas SQL                           | `pg` / PDO              |
| Plantilla     | Mezclar datos y estructura HTML                      | EJS / PHP               |
| Base de datos | Almacenar y devolver los datos                       | PostgreSQL              |

### 2.9 Consecuencias de este modelo

- Es sencillo de entender, depurar y explicar en una clase.
- El HTML llega listo al navegador; no hay estados de carga ni pantallas vacías
  esperando datos.
- Cada acción implica una recarga completa de la página.
- No hay actualizaciones parciales ni tiempo real; si se necesitara, sería otro
  tipo de arquitectura.
- La seguridad y la validación se concentran en el servidor.

## 3. Arquitectura general

```text
                         Navegador
                       /           \
                      /             \
             http://localhost:3000  http://localhost:8000
                      |                       |
              +-------+-------+       +-------+-------+
              |  Node.js      |       |  PHP + Apache |
              |  Express+EJS  |       |  PDO pgsql    |
              +-------+-------+       +-------+-------+
                      |                       |
                      +-----------+-----------+
                                  |
                         +--------+--------+
                         |   PostgreSQL    |
                         |   puerto 5432   |
                         |   volumen datos |
                         +-----------------+
```

Tres contenedores en la red interna de Compose:

| Servicio | Imagen base      | Puerto host | Puerto interno | Función                          |
| -------- | ---------------- | ----------- | -------------- | -------------------------------- |
| `node`   | `node:22-alpine` | 3000        | 3000           | Interfaz principal con EJS       |
| `php`    | `php:8.3-apache` | 8000        | 80             | Interfaz alternativa con PHP     |
| `db`     | `postgres:16`    | 5432        | 5432           | Base de datos compartida         |

Comunicación:

- El navegador accede a los servicios por los puertos publicados.
- Node y PHP acceden a PostgreSQL por el nombre de servicio `db` dentro de la red
  de Compose.
- Solo la base de datos se conecta a un volumen persistente.
- Ni Node ni PHP exponen la base de datos al navegador: son los únicos que
  hablan con PostgreSQL.

## 4. Estructura de carpetas propuesta

```text
TrabajoComisiones/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── .dockerignore
├── docs/
│   ├── README.md              # este documento
│   ├── base-de-datos.md       # ampliación del modelo de datos (opcional)
│   └── rutas.md               # detalle de endpoints y pantallas (opcional)
├── database/
│   └── init/
│       ├── 001-schema.sql     # tablas, índices y restricciones
│       └── 002-seed.sql       # datos iniciales (estados, tipos, demo)
├── node/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── app.js             # configuración de Express
│       ├── server.js          # arranque del servidor
│       ├── config/
│       │   └── db.js          # pool de PostgreSQL
│       ├── routes/
│       │   ├── index.routes.js
│       │   └── comisiones.routes.js
│       ├── controllers/
│       │   ├── home.controller.js
│       │   └── comisiones.controller.js
│       ├── models/
│       │   └── comisiones.model.js
│       ├── middlewares/
│       │   └── error.middleware.js
│       ├── views/
│       │   ├── partials/
│       │   │   ├── head.ejs
│       │   │   ├── header.ejs
│       │   │   └── footer.ejs
│       │   ├── home.ejs
│       │   ├── comisiones/
│       │   │   ├── index.ejs  # listado
│       │   │   ├── show.ejs   # detalle
│       │   │   └── form.ejs   # crear/editar
│       │   ├── error.ejs
│       │   └── 404.ejs
│       └── public/
│           ├── css/styles.css
│           └── img/
└── php/
    ├── Dockerfile
    ├── .dockerignore
    ├── public/
    │   ├── index.php          # front controller
    │   └── css/styles.css
    ├── src/
    │   ├── Config/
    │   │   └── Database.php   # conexión PDO singleton
    │   ├── Models/
    │   │   └── Comision.php
    │   └── Controllers/
    │       └── ComisionController.php
    └── templates/
        ├── layout.php
        ├── partials/
        │   ├── header.php
        │   └── footer.php
        └── comisiones/
            ├── index.php
            └── show.php
```

Reglas de organización:

- `node/src/` separa rutas, controladores, modelos, vistas y estáticos.
- `php/public/` es el único directorio expuesto por Apache; el resto del código
  queda fuera del DocumentRoot.
- `database/init/` contiene únicamente scripts que PostgreSQL ejecuta al crear
  el volumen por primera vez.
- Los archivos de configuración global se quedan en la raíz; ningún código de
  aplicación vive en la raíz.
- No hay carpeta de JavaScript de cliente: no se necesita para obtener ni
  renderizar datos.

## 5. Aplicación Node.js con EJS

### 5.1 Tecnologías

- Node.js 22 con módulos CommonJS o ESM (se decidirá al implementar; se
  recomienda ESM por coherencia con versiones actuales).
- Express como servidor HTTP.
- EJS como motor de plantillas.
- `pg` como cliente de PostgreSQL con pool de conexiones.
- `dotenv` solo para desarrollo local fuera de Docker; dentro de Docker la
  configuración llega por variables de entorno.
- Sin JavaScript de cliente para datos: no hay `fetch`, AJAX ni API JSON.

### 5.2 Dependencias previstas

```json
{
  "dependencies": {
    "ejs": "^3.x",
    "express": "^4.x",
    "pg": "^8.x"
  }
}
```

### 5.3 Rutas y pantallas

| Método | Ruta                     | Pantalla / función                    |
| ------ | ------------------------ | ------------------------------------- |
| GET    | `/`                      | Inicio con comisiones destacadas      |
| GET    | `/comisiones`            | Listado con filtros por estado/tipo   |
| GET    | `/comisiones/:id`        | Detalle de una comisión               |
| GET    | `/comisiones/nueva`      | Formulario de nueva comisión          |
| POST   | `/comisiones`            | Crear comisión                        |
| GET    | `/comisiones/:id/editar` | Formulario de edición                 |
| POST   | `/comisiones/:id`        | Actualizar comisión                   |
| POST   | `/comisiones/:id/estado` | Cambiar estado                        |
| GET    | `/health`                | Estado del servicio y de la BD        |

Todas las rutas `GET` devuelven una página HTML completa. Las rutas `POST`
procesan el formulario y responden con un redirect (patrón POST / Redirect /
GET), salvo que haya errores de validación, en cuyo caso vuelven a renderizar el
formulario con los mensajes correspondientes.

Validaciones mínimas:

- Campos obligatorios: cliente, artista, tipo, descripción y precio.
- Precio numérico mayor o igual que cero.
- Fecha de entrega válida y no anterior a hoy al crear.
- Mensajes de error mostrados en la misma vista del formulario.

### 5.4 Vistas EJS

- `partials/head.ejs`: metadatos, CSS y fuentes.
- `partials/header.ejs`: navegación común.
- `partials/footer.ejs`: cierre de página.
- `home.ejs`: presentación y comisiones recientes.
- `comisiones/index.ejs`: tabla o tarjetas con estado, artista y precio.
- `comisiones/show.ejs`: ficha completa y acciones.
- `comisiones/form.ejs`: alta y edición reutilizando la misma plantilla.
- `error.ejs` y `404.ejs`: páginas de error.

Las plantillas reciben los datos ya consultados por el controlador. No hacen
peticiones por su cuenta ni cargan datos de forma asíncrona.

### 5.5 Dockerfile de Node

- Imagen base `node:22-alpine`.
- `WORKDIR /app`.
- Copiar primero `package*.json` e instalar dependencias con
  `npm ci --omit=dev`.
- Copiar el resto del código.
- Usuario no root.
- `EXPOSE 3000`.
- `CMD ["npm", "start"]`.
- En desarrollo se podrá montar el código como volumen para recarga, pero la
  configuración por defecto será una imagen reproducible.

## 6. Aplicación PHP

### 6.1 Tecnologías

- PHP 8.3 con Apache.
- PDO con extensión `pdo_pgsql`.
- Sin framework: front controller, controladores y plantillas PHP.
- Sin JavaScript de cliente para datos.
- Mismas consultas y reglas de negocio que Node, pero implementadas de forma
  independiente para demostrar el uso de ambos lenguajes.

### 6.2 Rutas y pantallas

| Método | Ruta                      | Pantalla / función              |
| ------ | ------------------------- | ------------------------------- |
| GET    | `/`                       | Inicio                          |
| GET    | `/comisiones`             | Listado                         |
| GET    | `/comisiones/{id}`        | Detalle                         |
| GET    | `/comisiones/nueva`       | Formulario                      |
| POST   | `/comisiones`             | Crear                           |
| POST   | `/comisiones/{id}/estado` | Cambiar estado                  |
| GET    | `/health`                 | Estado del servicio y de la BD  |

El enrutamiento se resolverá en `php/public/index.php` mediante un parámetro
`?ruta=` o mediante reglas de reescritura de Apache. Se recomienda reescritura
con `.htaccess` o configuración de Apache para obtener URLs limpias.

Igual que en Node, cada `GET` renderiza una plantilla PHP con los datos
obtenidos de PostgreSQL, y cada `POST` termina en un redirect o vuelve a mostrar
el formulario con errores.

### 6.3 Dockerfile de PHP

- Imagen base `php:8.3-apache`.
- Instalar `libpq-dev` y habilitar `pdo_pgsql`.
- Configurar `DocumentRoot` a `/var/www/html/public`.
- Copiar `public/`, `src/` y `templates/`.
- `EXPOSE 80`.

## 7. Base de datos PostgreSQL

### 7.1 Modelo de datos propuesto

El dominio gira en torno a clientes, artistas, tipos de comisión, comisiones,
estados, archivos entregados y pagos.

```sql
-- Estados posibles de una comisión
CREATE TABLE estados_comision (
    id     SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL UNIQUE
);

-- Usuarios de la aplicación (clientes, artistas y administradores)
CREATE TABLE usuarios (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(120) NOT NULL,
    email         VARCHAR(180) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol           VARCHAR(20) NOT NULL DEFAULT 'cliente'
                  CHECK (rol IN ('cliente', 'artista', 'admin')),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Perfil público del artista; un usuario puede tener como máximo uno
CREATE TABLE artistas (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id       BIGINT NOT NULL UNIQUE
                     REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre_artistico VARCHAR(120) NOT NULL,
    biografia        TEXT,
    portafolio_url   VARCHAR(500),
    disponible       BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Catálogo de tipos de comisión (retrato, chibi, ilustración, etc.)
CREATE TABLE tipos_comision (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    precio_base NUMERIC(10, 2) NOT NULL DEFAULT 0
                CHECK (precio_base >= 0),
    activo      BOOLEAN NOT NULL DEFAULT TRUE
);

-- Comisión solicitada por un cliente a un artista
CREATE TABLE comisiones (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id      BIGINT NOT NULL REFERENCES usuarios(id),
    artista_id      BIGINT NOT NULL REFERENCES artistas(id),
    tipo_id         BIGINT NOT NULL REFERENCES tipos_comision(id),
    estado_id       SMALLINT NOT NULL REFERENCES estados_comision(id),
    titulo          VARCHAR(160) NOT NULL,
    descripcion     TEXT NOT NULL,
    referencias     TEXT,
    precio_acordado NUMERIC(10, 2) NOT NULL
                    CHECK (precio_acordado >= 0),
    fecha_entrega   DATE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Archivos o enlaces de entregas y referencias
CREATE TABLE archivos_comision (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    comision_id BIGINT NOT NULL REFERENCES comisiones(id) ON DELETE CASCADE,
    url         VARCHAR(500) NOT NULL,
    tipo        VARCHAR(20) NOT NULL DEFAULT 'entrega'
                CHECK (tipo IN ('referencia', 'entrega')),
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Registro de pagos asociados a una comisión
CREATE TABLE pagos (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    comision_id BIGINT NOT NULL REFERENCES comisiones(id) ON DELETE CASCADE,
    monto       NUMERIC(10, 2) NOT NULL CHECK (monto > 0),
    metodo      VARCHAR(40),
    estado      VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente', 'pagado', 'reembolsado')),
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_comisiones_cliente ON comisiones(cliente_id);
CREATE INDEX idx_comisiones_artista ON comisiones(artista_id);
CREATE INDEX idx_comisiones_estado  ON comisiones(estado_id);
CREATE INDEX idx_comisiones_fecha   ON comisiones(creado_en DESC);
```

### 7.2 Datos iniciales

`002-seed.sql` insertará:

- Estados: `pendiente`, `en_proceso`, `entregada`, `cancelada`.
- Tipos de comisión de ejemplo: `retrato`, `chibi`, `ilustracion`.
- Un usuario administrador y un artista de demostración con contraseñas
  hasheadas, nunca en texto plano.
- Opcionalmente, dos o tres comisiones de ejemplo para que ambas interfaces
  muestren datos desde el primer arranque.

### 7.3 Reglas de acceso

- Node y PHP usan sentencias preparadas (consultas parametrizadas).
- El usuario de base de datos de la aplicación no es un superusuario.
- Las credenciales llegan por variables de entorno y nunca se escriben en el
  código.
- La base de datos solo se publica en el host para desarrollo; en producción no
  debería exponerse el puerto 5432.
- El navegador no tiene acceso directo a PostgreSQL.

## 8. Docker Compose

### 8.1 Servicios

```yaml
services:
  node:
    build: ./node
    ports: ["${APP_PORT:-3000}:3000"]
    environment: { ... }
    depends_on:
      db: { condition: service_healthy }
    restart: unless-stopped

  php:
    build: ./php
    ports: ["${PHP_PORT:-8000}:80"]
    environment: { ... }
    depends_on:
      db: { condition: service_healthy }
    restart: unless-stopped

  db:
    image: postgres:16
    environment: { ... }
    ports: ["${POSTGRES_PORT:-5432}:5432"]
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

volumes:
  postgres_data:
```

Consideraciones:

- Se usa una red interna creada por Compose; los servicios se resuelven por
  nombre (`db`).
- `db` tiene `healthcheck` para que Node y PHP arranquen cuando PostgreSQL esté
  listo.
- El volumen `postgres_data` conserva los datos entre reinicios.
- Los scripts de `database/init/` solo se ejecutan la primera vez que se crea el
  volumen. Para volver a inicializar: `docker compose down --volumes`.
- Cada servicio recibe las variables `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`
  y `DB_PASSWORD`; el host siempre es `db` dentro de Docker.

### 8.2 Variables de entorno

`.env.example` (sin secretos reales):

```dotenv
APP_PORT=3000
PHP_PORT=8000
POSTGRES_DB=comisiones
POSTGRES_USER=comisiones
POSTGRES_PASSWORD=comisiones_dev
POSTGRES_PORT=5432
```

El archivo `.env` real se crea copiando el ejemplo, está en `.gitignore` y no se
incluye en las imágenes Docker gracias a `.dockerignore`.

### 8.3 Comandos de trabajo

```sh
# Primera puesta en marcha
cp .env.example .env
docker compose up --build

# Segundo plano
docker compose up -d --build

# Logs
docker compose logs -f node
docker compose logs -f php
docker compose logs -f db

# Parada
docker compose down

# Borrado completo de datos y reinicialización
docker compose down --volumes
```

URLs previstas:

- Node.js: <http://localhost:3000>
- PHP: <http://localhost:8000>
- PostgreSQL: `localhost:5432` (solo desarrollo)

## 9. Flujo funcional de una comisión

1. El cliente entra en la web (Node o PHP) y consulta el listado. El servidor
   consulta la base de datos y devuelve el HTML del listado.
2. Entra en el formulario de nueva comisión. El servidor consulta artistas y
   tipos, y devuelve el formulario HTML.
3. Envía el formulario por `POST`. El servidor valida, inserta la comisión en
   estado `pendiente` y redirige al detalle.
4. El navegador pide el detalle y recibe la ficha completa en HTML.
5. El artista o el administrador cambia el estado a `en_proceso`, `entregada` o
   `cancelada` mediante otro formulario `POST`.
6. Las entregas se registran en `archivos_comision`.
7. Los pagos se registran en `pagos`.
8. Ambas interfaces leen y escriben en las mismas tablas, por lo que los cambios
   se ven desde Node y desde PHP.

En ningún paso el navegador consulta la base de datos ni recibe JSON: siempre
recibe una página HTML generada por el servidor.

## 10. Seguridad y buenas prácticas

- No versionar `.env` ni contraseñas reales.
- Escapar la salida en EJS con `<%= %>` y en PHP con `htmlspecialchars`.
- Usar consultas preparadas y validar todos los datos de entrada.
- Aplicar el principio de mínimo privilegio en el usuario de PostgreSQL.
- No ejecutar contenedores como root cuando sea posible.
- Limitar los puertos publicados en producción; solo exponer el proxy o los
  servicios necesarios.
- Mantener las imágenes con versiones fijas (`node:22-alpine`,
  `php:8.3-apache`, `postgres:16`) en lugar de `latest`.
- Escapar y validar también en los formularios PHP; no confiar en el navegador.

## 11. Estado actual y siguiente paso

Estado actual del repositorio:

- Estructura de carpetas creada según la sección 4.
- `docker-compose.yml` con servicios `node`, `php` y `db`, imágenes fijadas y
  healthcheck de PostgreSQL.
- Node.js con Express + EJS, rutas y vistas de ejemplo; `/health` operativo.
- PHP con front controller, plantillas y `/health`; Apache con `pdo_pgsql`.
- PostgreSQL inicializado con el esquema de comisiones; `002-seed.sql` está
  vacío.
- Contenedores construidos y probados: Node en el puerto 3000 y PHP en el 8000.

Pendiente de implementar:

1. Rellenar `002-seed.sql` con estados, tipos y datos de demostración.
2. Implementar las consultas de Node en `node/src/models/` y completar sus
   controladores.
3. Implementar las consultas PDO en PHP y completar sus controladores.
4. Completar formularios y vistas de listado, detalle y edición.
5. Añadir estilos y validaciones.
6. Actualizar la documentación con el resultado final.

### Orden de implementación sugerido

1. Datos iniciales.
2. Modelo y controladores de Node.
3. Vistas EJS y formularios.
4. Modelo y controladores PHP.
5. Estilos y validaciones.
6. Pruebas completas y actualización del README.

## 12. Guía exhaustiva de la estructura y de cada archivo

Esta sección explica, archivo por archivo, qué contiene el proyecto y para qué
sirve cada pieza. No sustituye a las secciones anteriores: las complementa. El
objetivo es que cualquier persona pueda abrir el repositorio y entender qué hace
cada archivo sin necesidad de ejecutarlo.

### 12.1 Alcance de esta guía

Se explican los archivos fuente que están versionados en el repositorio. No se
explican los archivos generados o ignorados, como `.env`, `node_modules/`, el
volumen `postgres_data` o las imágenes de Docker; se mencionan al final para
dejar claro que no forman parte del código fuente.

Árbol actual del proyecto:

```text
TrabajoComisiones/
├── .dockerignore
├── .env.example
├── .gitignore
├── docker-compose.yml
├── opencode.json
├── database/
│   └── init/
│       ├── 001-schema.sql
│       └── 002-seed.sql
├── docs/
│   └── README.md
├── node/
│   ├── .dockerignore
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│       ├── app.js
│       ├── server.js
│       ├── config/
│       │   └── db.js
│       ├── controllers/
│       │   ├── comisiones.controller.js
│       │   └── home.controller.js
│       ├── middlewares/
│       │   └── error.middleware.js
│       ├── models/
│       │   └── comisiones.model.js
│       ├── public/
│       │   ├── css/
│       │   │   └── styles.css
│       │   └── img/
│       │       └── .gitkeep
│       ├── routes/
│       │   ├── comisiones.routes.js
│       │   └── index.routes.js
│       └── views/
│           ├── 404.ejs
│           ├── error.ejs
│           ├── home.ejs
│           ├── comisiones/
│           │   ├── form.ejs
│           │   ├── index.ejs
│           │   └── show.ejs
│           └── partials/
│               ├── footer.ejs
│               ├── head.ejs
│               └── header.ejs
└── php/
    ├── .dockerignore
    ├── Dockerfile
    ├── public/
    │   ├── .htaccess
    │   ├── index.php
    │   └── css/
    │       └── styles.css
    ├── src/
    │   ├── Config/
    │   │   └── Database.php
    │   ├── Controllers/
    │   │   └── ComisionController.php
    │   └── Models/
    │       └── Comision.php
    └── templates/
        ├── layout.php
        ├── partials/
        │   ├── footer.php
        │   └── header.php
        └── comisiones/
            ├── index.php
            └── show.php
```

### 12.2 Archivos de la raíz

#### `.gitignore`

Contiene las rutas que Git no debe versionar:

```text
.env
node_modules/
npm-debug.log*
```

- `.env`: guarda variables de entorno reales, como contraseñas. No debe subirse
  al repositorio.
- `node_modules/`: dependencias instaladas de Node.js. Se reconstruyen con
  `npm install` o dentro de la imagen Docker.
- `npm-debug.log*`: archivos de registro que genera npm cuando falla.

Gracias a este archivo, el repositorio solo contiene código y configuración, no
secretos ni dependencias pesadas.

#### `.dockerignore`

Se usa cuando el contexto de construcción de Docker es la raíz del proyecto.
Contiene:

```text
.git
.env
node_modules
npm-debug.log
```

- `.git`: evita copiar el historial de Git a la imagen.
- `.env`: evita meter secretos en la imagen.
- `node_modules`: evita copiar dependencias locales; la imagen instala las
  suyas.
- `npm-debug.log`: evita copiar registros de error.

En la configuración actual, Docker Compose construye cada servicio con su propio
contexto (`./node` y `./php`), por lo que también se aplican los
`.dockerignore` de esas carpetas. Este archivo de la raíz queda como protección
general si en el futuro se construye una imagen desde la raíz.

#### `.env.example`

Es la plantilla de variables de entorno. No contiene secretos reales; sirve para
crear el archivo `.env`:

```dotenv
APP_PORT=3000
PHP_PORT=8000
POSTGRES_DB=comisiones
POSTGRES_USER=comisiones
POSTGRES_PASSWORD=comisiones_dev
POSTGRES_PORT=5432
```

- `APP_PORT`: puerto del host para Node.js. Docker Compose lo publica en el
  contenedor en el puerto 3000.
- `PHP_PORT`: puerto del host para PHP. Dentro del contenedor Apache escucha en
  el 80.
- `POSTGRES_DB`: nombre de la base de datos que se crea al inicializar
  PostgreSQL.
- `POSTGRES_USER`: usuario propietario de la base de datos.
- `POSTGRES_PASSWORD`: contraseña del usuario. El valor del ejemplo es solo para
  desarrollo local.
- `POSTGRES_PORT`: puerto del host para conectarse a PostgreSQL.

El archivo `.env` real se crea copiando este ejemplo:

```sh
cp .env.example .env
```

Docker Compose lee `.env` automáticamente y sustituye los valores `${...}` del
`docker-compose.yml`. El `.env` está ignorado por Git.

#### `docker-compose.yml`

Define los tres servicios del proyecto y cómo se conectan. Su contenido actual:

```yaml
services:
  node:
    build: ./node
    ports:
      - "${APP_PORT:-3000}:3000"
    environment:
      PORT: 3000
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB:-comisiones}
      DB_USER: ${POSTGRES_USER:-comisiones}
      DB_PASSWORD: ${POSTGRES_PASSWORD:-comisiones_dev}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  php:
    build: ./php
    ports:
      - "${PHP_PORT:-8000}:80"
    environment:
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: ${POSTGRES_DB:-comisiones}
      DB_USER: ${POSTGRES_USER:-comisiones}
      DB_PASSWORD: ${POSTGRES_PASSWORD:-comisiones_dev}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-comisiones}
      POSTGRES_USER: ${POSTGRES_USER:-comisiones}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-comisiones_dev}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\" -d \"$${POSTGRES_DB}\""]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

volumes:
  postgres_data:
```

Explicación detallada:

- `services`: agrupa los contenedores que forman la aplicación.
- `node`: servicio de la interfaz Node.js.
  - `build: ./node`: construye la imagen usando `node/Dockerfile`.
  - `ports`: publica el puerto del host indicado por `APP_PORT` en el puerto
    3000 del contenedor. El valor `:-3000` significa "usa 3000 si la variable no
    está definida".
  - `environment`: variables que recibe el proceso Node dentro del contenedor.
    `PORT` es el puerto de escucha; `DB_HOST` es `db`, el nombre del servicio de
    PostgreSQL dentro de la red de Compose; el resto son credenciales y nombre
    de la base de datos.
  - `depends_on` con `condition: service_healthy`: Node no arranca hasta que
    PostgreSQL pase su healthcheck.
  - `restart: unless-stopped`: reinicia el contenedor si falla, salvo que se
    haya detenido manualmente.
- `php`: servicio de la interfaz PHP.
  - `build: ./php`: construye usando `php/Dockerfile`.
  - `ports`: publica el puerto del host `PHP_PORT` en el puerto 80 del
    contenedor.
  - `environment`: las mismas credenciales de base de datos, con `DB_HOST=db`.
  - `depends_on` y `restart` funcionan igual que en Node.
- `db`: servicio de PostgreSQL.
  - `image: postgres:16`: usa una versión fija de la imagen oficial.
  - `environment`: crea la base de datos y el usuario indicados por las
    variables `POSTGRES_*`.
  - `ports`: publica el puerto de PostgreSQL en el host para poder conectarse
    con un cliente externo durante el desarrollo.
  - `volumes`:
    - `postgres_data:/var/lib/postgresql/data`: guarda los datos en un volumen
      para que no se pierdan al recrear el contenedor.
    - `./database/init:/docker-entrypoint-initdb.d:ro`: monta los scripts SQL en
      modo solo lectura. PostgreSQL los ejecuta en orden alfabético la primera
      vez que se inicializa el volumen.
  - `healthcheck`: ejecuta `pg_isready` cada 5 segundos, con 5 segundos de
    espera y 10 reintentos. El `$$` se traduce en un `$` literal para que la
    variable se expanda dentro del contenedor y no en el host.
  - `restart: unless-stopped`: reinicia PostgreSQL si se cae.
- `volumes`: declara el volumen con nombre `postgres_data`, que Docker gestiona
  fuera de la carpeta del proyecto.

Docker Compose crea además una red interna por defecto. Gracias a ella, Node y
PHP pueden resolver el nombre `db` sin conocer la IP del contenedor. El
navegador nunca se conecta directamente a la base de datos.

#### `opencode.json`

Es configuración de la herramienta de desarrollo OpenCode, no forma parte de la
aplicación web. Contiene:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "fetch": {
      "type": "local",
      "enabled": true,
      "command": ["npx", "-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
```

- `$schema`: indica el esquema de configuración.
- `mcp.fetch`: habilita un servidor MCP local para realizar peticiones HTTP
  durante el desarrollo.
- `command`: comando con el que se lanza ese servidor.

No afecta al funcionamiento de la página ni a los contenedores. Se puede omitir
al entregar el proyecto si no se usa OpenCode.

#### `docs/README.md`

Es este documento. Contiene:

1. El objetivo del proyecto.
2. La explicación del renderizado en el servidor, con el flujo navegador,
   servidor, base de datos y HTML final.
3. La arquitectura general y los puertos.
4. La estructura de carpetas.
5. La explicación de la aplicación Node.js con EJS.
6. La explicación de la aplicación PHP.
7. El modelo de datos de PostgreSQL.
8. La configuración de Docker Compose.
9. El flujo funcional de una comisión.
10. Las buenas prácticas de seguridad.
11. El estado actual y las tareas pendientes.
12. Esta guía exhaustiva de archivos.

Es la documentación principal que se debe leer antes de tocar el código.

### 12.3 Carpeta `database/`

#### `database/init/001-schema.sql`

Contiene el esquema inicial de PostgreSQL. PostgreSQL ejecuta este archivo
automáticamente la primera vez que se crea el volumen de datos. Define las
siguientes tablas:

##### `estados_comision`

Guarda los estados posibles de una comisión.

| Columna  | Tipo                                  | Restricciones              |
| -------- | ------------------------------------- | -------------------------- |
| `id`     | `SMALLINT GENERATED ALWAYS AS IDENTITY` | Clave primaria             |
| `nombre` | `VARCHAR(30)`                         | `NOT NULL` y `UNIQUE`      |

Los valores previstos son `pendiente`, `en_proceso`, `entregada` y `cancelada`.
El archivo de datos inicial está vacío, así que esos valores todavía no se
insertan.

##### `usuarios`

Guarda clientes, artistas y administradores.

| Columna         | Tipo                                   | Restricciones                                  |
| --------------- | -------------------------------------- | ---------------------------------------------- |
| `id`            | `BIGINT GENERATED ALWAYS AS IDENTITY`  | Clave primaria                                 |
| `nombre`        | `VARCHAR(120)`                         | `NOT NULL`                                     |
| `email`         | `VARCHAR(180)`                         | `NOT NULL` y `UNIQUE`                          |
| `password_hash` | `VARCHAR(255)`                         | `NOT NULL`                                     |
| `rol`           | `VARCHAR(20)`                          | `NOT NULL`, por defecto `cliente`, con `CHECK` |
| `creado_en`     | `TIMESTAMPTZ`                          | `NOT NULL`, por defecto la fecha actual        |

El `CHECK` de `rol` solo permite `cliente`, `artista` o `admin`.

##### `artistas`

Guarda el perfil público de un artista. Tiene una relación uno a uno con
`usuarios`.

| Columna           | Tipo                                  | Restricciones                                  |
| ----------------- | ------------------------------------- | ---------------------------------------------- |
| `id`              | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria                                 |
| `usuario_id`      | `BIGINT`                              | `NOT NULL`, `UNIQUE`, referencia a `usuarios`  |
| `nombre_artistico`| `VARCHAR(120)`                        | `NOT NULL`                                     |
| `biografia`       | `TEXT`                                | Opcional                                       |
| `portafolio_url`  | `VARCHAR(500)`                        | Opcional                                       |
| `disponible`      | `BOOLEAN`                             | `NOT NULL`, por defecto `TRUE`                 |
| `creado_en`       | `TIMESTAMPTZ`                         | `NOT NULL`, por defecto la fecha actual        |

`usuario_id` es `UNIQUE`, por lo que un usuario solo puede tener un perfil de
artista. `ON DELETE CASCADE` elimina el perfil si se borra el usuario.

##### `tipos_comision`

Es el catálogo de tipos de encargo, por ejemplo retrato, chibi o ilustración.

| Columna       | Tipo                                  | Restricciones                                  |
| ------------- | ------------------------------------- | ---------------------------------------------- |
| `id`          | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria                                 |
| `nombre`      | `VARCHAR(100)`                        | `NOT NULL` y `UNIQUE`                          |
| `descripcion` | `TEXT`                                | Opcional                                       |
| `precio_base` | `NUMERIC(10, 2)`                      | `NOT NULL`, por defecto `0`, debe ser `>= 0`   |
| `activo`      | `BOOLEAN`                             | `NOT NULL`, por defecto `TRUE`                 |

##### `comisiones`

Es la tabla central del proyecto. Relaciona un cliente, un artista, un tipo de
comisión y un estado.

| Columna           | Tipo                                  | Restricciones                                  |
| ----------------- | ------------------------------------- | ---------------------------------------------- |
| `id`              | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria                                 |
| `cliente_id`      | `BIGINT`                              | `NOT NULL`, referencia a `usuarios`            |
| `artista_id`      | `BIGINT`                              | `NOT NULL`, referencia a `artistas`            |
| `tipo_id`         | `BIGINT`                              | `NOT NULL`, referencia a `tipos_comision`      |
| `estado_id`       | `SMALLINT`                            | `NOT NULL`, referencia a `estados_comision`    |
| `titulo`          | `VARCHAR(160)`                        | `NOT NULL`                                     |
| `descripcion`     | `TEXT`                                | `NOT NULL`                                     |
| `referencias`     | `TEXT`                                | Opcional                                       |
| `precio_acordado` | `NUMERIC(10, 2)`                      | `NOT NULL`, debe ser `>= 0`                    |
| `fecha_entrega`   | `DATE`                                | Opcional                                       |
| `creado_en`       | `TIMESTAMPTZ`                         | `NOT NULL`, por defecto la fecha actual        |
| `actualizado_en`  | `TIMESTAMPTZ`                         | `NOT NULL`, por defecto la fecha actual        |

Esta tabla es la que consultarán las vistas de listado y detalle. Todavía no hay
consultas implementadas en Node ni en PHP.

##### `archivos_comision`

Guarda enlaces o rutas de archivos asociados a una comisión, tanto referencias
enviadas por el cliente como entregas del artista.

| Columna       | Tipo                                  | Restricciones                                      |
| ------------- | ------------------------------------- | -------------------------------------------------- |
| `id`          | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria                                     |
| `comision_id` | `BIGINT`                              | `NOT NULL`, referencia a `comisiones`, `CASCADE`   |
| `url`         | `VARCHAR(500)`                        | `NOT NULL`                                         |
| `tipo`        | `VARCHAR(20)`                         | `NOT NULL`, por defecto `entrega`, `CHECK`         |
| `creado_en`   | `TIMESTAMPTZ`                         | `NOT NULL`, por defecto la fecha actual            |

El `CHECK` de `tipo` solo permite `referencia` o `entrega`. Si se borra la
comisión, se borran sus archivos asociados.

##### `pagos`

Registra los pagos de una comisión.

| Columna       | Tipo                                  | Restricciones                                      |
| ------------- | ------------------------------------- | -------------------------------------------------- |
| `id`          | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria                                     |
| `comision_id` | `BIGINT`                              | `NOT NULL`, referencia a `comisiones`, `CASCADE`   |
| `monto`       | `NUMERIC(10, 2)`                      | `NOT NULL`, debe ser `> 0`                         |
| `metodo`      | `VARCHAR(40)`                         | Opcional                                           |
| `estado`      | `VARCHAR(20)`                         | `NOT NULL`, por defecto `pendiente`, `CHECK`       |
| `creado_en`   | `TIMESTAMPTZ`                         | `NOT NULL`, por defecto la fecha actual            |

El `CHECK` de `estado` solo permite `pendiente`, `pagado` o `reembolsado`.

##### Índices

Al final del archivo se crean cuatro índices:

- `idx_comisiones_cliente`: acelera las búsquedas por cliente.
- `idx_comisiones_artista`: acelera las búsquedas por artista.
- `idx_comisiones_estado`: acelera los filtros por estado.
- `idx_comisiones_fecha`: acelera el orden por fecha de creación descendente.

##### Cuándo se ejecuta

Solo se ejecuta cuando el volumen `postgres_data` se crea por primera vez. Si se
cambia el esquema y el volumen ya existe, el cambio no se aplica solo. Para
reinicializar:

```sh
docker compose down --volumes
docker compose up --build
```

#### `database/init/002-seed.sql`

Está vacío. Su función prevista es insertar datos iniciales:

- Los cuatro estados de comisión.
- Los tipos de comisión de ejemplo.
- Un usuario administrador y un artista de demostración.
- Comisiones de ejemplo.

PostgreSQL ejecuta el archivo al inicializar el volumen, pero al estar vacío no
inserta nada. Las tablas se crean, pero no tienen filas. Se ha dejado así porque
en esta fase solo se montó la estructura.

### 12.4 Carpeta `node/`

#### `node/Dockerfile`

Construye la imagen de Node.js:

```dockerfile
FROM node:22-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY src ./src

EXPOSE 3000

CMD ["npm", "start"]
```

Línea a línea:

- `FROM node:22-alpine`: parte de Node.js 22 sobre Alpine Linux, una imagen
  ligera.
- `WORKDIR /app`: establece `/app` como directorio de trabajo dentro del
  contenedor.
- `COPY package.json ./`: copia solo el manifiesto de dependencias. Se hace
  antes de copiar el código para aprovechar la caché de Docker: si el código
  cambia pero `package.json` no, no se reinstalan dependencias.
- `RUN npm install --omit=dev`: instala las dependencias de producción dentro de
  la imagen. No se copia `node_modules` desde el host.
- `COPY src ./src`: copia todo el código fuente: servidor, rutas,
  controladores, modelos, vistas y archivos públicos. Las vistas están en
  `src/views` y los estáticos en `src/public`, por eso una sola copia incluye
  todo.
- `EXPOSE 3000`: documenta que el contenedor escucha en el puerto 3000. No
  publica el puerto por sí solo; eso lo hace `docker-compose.yml`.
- `CMD ["npm", "start"]`: comando por defecto. Ejecuta el script `start` de
  `package.json`, que lanza `node src/server.js`.

#### `node/.dockerignore`

Evita enviar archivos innecesarios al contexto de construcción de Node:

```text
node_modules
npm-debug.log*
.env
```

- `node_modules`: las dependencias se instalan dentro de la imagen.
- `npm-debug.log*`: registros de errores de npm.
- `.env`: evita incluir secretos en la imagen.

#### `node/package.json`

Es el manifiesto de la aplicación Node:

```json
{
  "name": "trabajo-comisiones",
  "version": "1.0.0",
  "private": true,
  "description": "Página de comisiones de dibujos con Node.js, EJS y PostgreSQL",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js"
  },
  "dependencies": {
    "ejs": "^3.1.10",
    "express": "^4.21.2",
    "pg": "^8.13.1"
  }
}
```

- `name`: nombre interno del paquete.
- `version`: versión del proyecto.
- `private: true`: evita publicarlo por accidente en npm.
- `description`: descripción breve.
- `main`: archivo de entrada, `src/server.js`.
- `scripts.start`: comando que ejecuta Docker y también se puede usar en local
  con `npm start`.
- `dependencies`:
  - `ejs`: motor de plantillas que mezcla datos y HTML.
  - `express`: framework HTTP que gestiona rutas, middlewares y respuestas.
  - `pg`: cliente de PostgreSQL con soporte de pool de conexiones.

No hay `devDependencies` porque en esta fase no se han añadido herramientas de
desarrollo. Tampoco hay `package-lock.json` en el repositorio; la imagen genera
su propio árbol de dependencias con `npm install`.

#### `node/src/server.js`

Es el punto de entrada de la aplicación:

```js
const app = require('./app');

const port = Number(process.env.PORT || 3000);

app.listen(port, '0.0.0.0', () => {
  console.log(`Servidor disponible en el puerto ${port}`);
});
```

- `require('./app')`: carga la aplicación Express ya configurada.
- `port`: lee `PORT` del entorno y lo convierte a número. Si no existe, usa
  3000.
- `app.listen(port, '0.0.0.0', ...)`: escucha en todas las interfaces del
  contenedor, no solo en `localhost`, para que Docker pueda publicar el puerto.
- El callback imprime un mensaje cuando el servidor está listo.

#### `node/src/app.js`

Configura Express y conecta todas las piezas:

```js
const express = require('express');
const { join } = require('node:path');

const indexRoutes = require('./routes/index.routes');
const comisionesRoutes = require('./routes/comisiones.routes');
const errorMiddleware = require('./middlewares/error.middleware');

const app = express();

app.set('view engine', 'ejs');
app.set('views', join(__dirname, 'views'));

app.use(express.urlencoded({ extended: false }));
app.use(express.static(join(__dirname, 'public')));

app.use('/', indexRoutes);
app.use('/comisiones', comisionesRoutes);

app.use((req, res) => {
  res.status(404).render('404', { titulo: 'Página no encontrada' });
});

app.use(errorMiddleware);

module.exports = app;
```

- Importa Express, la utilidad `join` para construir rutas de archivos, las dos
  colecciones de rutas y el middleware de errores.
- `app.set('view engine', 'ejs')`: indica que las vistas usan EJS.
- `app.set('views', ...)`: indica que las plantillas están en `src/views`.
- `express.urlencoded(...)`: permite leer datos enviados por formularios HTML
  tradicionales (`application/x-www-form-urlencoded`). Es lo que se usará en los
  `POST` sin JavaScript.
- `express.static(...)`: sirve los archivos de `src/public` en la raíz de la
  URL. Por ejemplo, `src/public/css/styles.css` se pide como
  `/css/styles.css`.
- `app.use('/', indexRoutes)`: monta las rutas de inicio y salud.
- `app.use('/comisiones', comisionesRoutes)`: monta las rutas de comisiones
  bajo el prefijo `/comisiones`.
- El `app.use` final sin ruta actúa como 404: cualquier petición que no haya
  coincidido antes recibe la vista `404.ejs` con código HTTP 404.
- `app.use(errorMiddleware)`: registra el manejador de errores. Express lo
  reconoce porque tiene cuatro argumentos.
- `module.exports = app`: exporta la aplicación para que `server.js` la use.

El orden importa: primero se configuran vistas y estáticos, después las rutas,
después el 404 y al final el manejador de errores.

#### `node/src/config/db.js`

Crea el pool de conexiones a PostgreSQL:

```js
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'comisiones',
  user: process.env.DB_USER || 'comisiones',
  password: process.env.DB_PASSWORD || 'comisiones_dev',
});

module.exports = pool;
```

- `Pool`: agrupa varias conexiones y las reutiliza, evitando abrir una conexión
  nueva en cada consulta.
- `host`: dentro de Docker es `db`; fuera de Docker se puede cambiar por
  `localhost`.
- `port`: 5432 por defecto.
- `database`, `user`, `password`: valores por defecto para desarrollo, que
  Docker sobrescribe con las variables de entorno del `docker-compose.yml`.
- `module.exports = pool`: el pool se exporta para que los futuros modelos
  ejecuten consultas con `pool.query(...)`.

Actualmente ningún controlador importa este archivo; se ha creado como
infraestructura para la siguiente fase.

#### `node/src/routes/index.routes.js`

Define las rutas generales:

```js
const { Router } = require('express');
const homeController = require('../controllers/home.controller');

const router = Router();

router.get('/', homeController.index);
router.get('/health', homeController.health);

module.exports = router;
```

- `Router()`: crea un enrutador de Express.
- `GET /`: muestra la página de inicio.
- `GET /health`: devuelve un JSON con el estado del servicio.
- `module.exports`: exporta el enrutador para montarlo en `app.js`.

#### `node/src/routes/comisiones.routes.js`

Define las rutas del recurso de comisiones:

```js
const { Router } = require('express');
const comisionesController = require('../controllers/comisiones.controller');

const router = Router();

router.get('/', comisionesController.listar);
router.get('/nueva', comisionesController.formulario);
router.post('/', comisionesController.crear);
router.get('/:id', comisionesController.detalle);
router.get('/:id/editar', comisionesController.editar);
router.post('/:id', comisionesController.actualizar);
router.post('/:id/estado', comisionesController.cambiarEstado);

module.exports = router;
```

El orden es importante:

- `GET /comisiones`: listado.
- `GET /comisiones/nueva`: formulario de alta. Debe declararse antes de `/:id`
  para que Express no interprete `nueva` como un identificador.
- `POST /comisiones`: procesa el alta.
- `GET /comisiones/:id`: detalle.
- `GET /comisiones/:id/editar`: formulario de edición.
- `POST /comisiones/:id`: procesa la actualización.
- `POST /comisiones/:id/estado`: procesa el cambio de estado.

`:id` es un parámetro dinámico que Express deja en `req.params.id`.

#### `node/src/controllers/home.controller.js`

Contiene las funciones de la página de inicio y del healthcheck:

```js
exports.index = (req, res) => {
  res.render('home', { titulo: 'Comisiones de dibujos' });
};

exports.health = (req, res) => {
  res.json({ status: 'ok' });
};
```

- `index`: renderiza `views/home.ejs` y le pasa la variable `titulo`, que la
  plantilla usa en la etiqueta `<title>`.
- `health`: responde con `{"status":"ok"}`. Actualmente no consulta la base de
  datos; solo confirma que el servidor HTTP responde.

#### `node/src/controllers/comisiones.controller.js`

Contiene los manejadores de las rutas de comisiones. En esta fase son
placeholders que renderizan vistas o redirigen, sin consultar la base de datos:

```js
exports.listar = (req, res) => {
  res.render('comisiones/index', {
    titulo: 'Comisiones',
    comisiones: [],
  });
};

exports.detalle = (req, res) => {
  res.render('comisiones/show', {
    titulo: 'Detalle de comisión',
    id: req.params.id,
  });
};

exports.formulario = (req, res) => {
  res.render('comisiones/form', {
    titulo: 'Nueva comisión',
    comision: null,
  });
};

exports.crear = (req, res) => {
  res.redirect('/comisiones');
};

exports.editar = (req, res) => {
  res.render('comisiones/form', {
    titulo: 'Editar comisión',
    comision: null,
    id: req.params.id,
  });
};

exports.actualizar = (req, res) => {
  res.redirect('/comisiones');
};

exports.cambiarEstado = (req, res) => {
  res.redirect('/comisiones');
};
```

- `listar`: pasa un array vacío a la vista del listado. La vista todavía no
  recorre datos reales.
- `detalle`: pasa el `id` de la URL a la vista de detalle.
- `formulario`: pasa `comision: null`, lo que la plantilla interpreta como alta
  nueva.
- `crear`: por ahora redirige al listado. Aquí irá en el futuro la validación y
  el `INSERT`.
- `editar`: reutiliza el formulario con el `id` de la comisión.
- `actualizar`: redirige al listado. Aquí irá el `UPDATE`.
- `cambiarEstado`: redirige al listado. Aquí irá el cambio de estado.

Ninguno de estos métodos usa todavía `config/db.js` ni el modelo.

#### `node/src/models/comisiones.model.js`

Contiene únicamente:

```js
module.exports = {};
```

Es un placeholder. Su función prevista es concentrar las consultas SQL de
comisiones, por ejemplo `listarTodas()`, `buscarPorId(id)`, `crear(datos)` o
`cambiarEstado(id, estadoId)`. Al estar vacío, el controlador no realiza ninguna
consulta todavía.

#### `node/src/middlewares/error.middleware.js`

Es el manejador central de errores:

```js
module.exports = (error, req, res, next) => {
  console.error(error);
  res.status(500).render('error', { titulo: 'Error del servidor' });
};
```

- Tiene cuatro parámetros (`error`, `req`, `res`, `next`). Express solo reconoce
  un middleware de error si tiene exactamente cuatro.
- `console.error(error)`: escribe el error en los logs del contenedor.
- `res.status(500).render('error', ...)`: devuelve la vista `error.ejs` con
  código HTTP 500.
- `next` no se usa en esta implementación, pero debe estar en la firma.

#### `node/src/views/partials/head.ejs`

Abre el documento y contiene la cabecera HTML:

```ejs
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= titulo %></title>
  <link rel="stylesheet" href="/css/styles.css">
</head>
```

- `<!doctype html>`: indica HTML5.
- `lang="es"`: idioma de la página.
- `meta charset`: codificación UTF-8.
- `meta viewport`: adaptación a dispositivos móviles.
- `<title><%= titulo %></title>`: inserta la variable `titulo` escapando el
  contenido. Por eso todas las vistas que lo incluyen deben recibir `titulo`.
- `link`: carga la hoja de estilos servida desde `src/public/css/styles.css`.

#### `node/src/views/partials/header.ejs`

Abre el cuerpo y pinta la navegación:

```ejs
<body>
  <header>
    <nav>
      <a href="/">Inicio</a>
      <a href="/comisiones">Comisiones</a>
      <a href="/comisiones/nueva">Nueva comisión</a>
    </nav>
  </header>
  <main>
```

- Abre `<body>`, el `<header>` y el `<main>`.
- Los enlaces son navegación normal: el navegador hace una petición GET y
  recibe HTML completo.
- El `<main>` queda abierto para que cada vista escriba su contenido.

#### `node/src/views/partials/footer.ejs`

Cierra la estructura abierta por el header:

```ejs
  </main>
</body>
</html>
```

No contiene scripts. Esto refuerza que la aplicación no usa JavaScript de
cliente para cargar datos.

#### `node/src/views/home.ejs`

Página de inicio:

```ejs
<%- include('partials/head') %>
<%- include('partials/header') %>
<h1>Comisiones de dibujos</h1>
<p>Estructura inicial del proyecto.</p>
<%- include('partials/footer') %>
```

- `<%- include(...) %>` inserta el contenido de otro archivo sin escaparlo. Se
  usa para componer la página con parciales.
- Incluye `head`, `header`, el contenido propio y `footer`.
- El texto es un placeholder; aquí irá la presentación y las comisiones
  destacadas.

#### `node/src/views/comisiones/index.ejs`

Vista del listado:

```ejs
<%- include('../partials/head') %>
<%- include('../partials/header') %>
<h1>Comisiones</h1>
<p>Listado pendiente de implementar.</p>
<%- include('../partials/footer') %>
```

- Igual que la home, pero con rutas relativas `../partials/...` porque está en
  la subcarpeta `comisiones/`.
- Recibe `comisiones`, pero de momento no lo recorre porque el controlador envía
  un array vacío. En la siguiente fase incluirá un bucle para pintar cada fila.

#### `node/src/views/comisiones/show.ejs`

Vista de detalle:

```ejs
<%- include('../partials/head') %>
<%- include('../partials/header') %>
<h1>Detalle de la comisión <%= id %></h1>
<p>Detalle pendiente de implementar.</p>
<%- include('../partials/footer') %>
```

- Muestra el `id` recibido de la URL.
- El resto de datos de la comisión se añadirán cuando el modelo consulte la base
  de datos.

#### `node/src/views/comisiones/form.ejs`

Vista compartida para crear y editar:

```ejs
<%- include('../partials/head') %>
<%- include('../partials/header') %>
<h1><%= comision ? 'Editar comisión' : 'Nueva comisión' %></h1>
<p>Formulario pendiente de implementar.</p>
<%- include('../partials/footer') %>
```

- Usa un operador ternario en EJS: si `comision` tiene valor, muestra
  "Editar comisión"; si es `null`, muestra "Nueva comisión".
- El formulario real, con `method="post"`, todavía no está implementado.

#### `node/src/views/404.ejs`

Página de recurso no encontrado:

```ejs
<%- include('partials/head') %>
<%- include('partials/header') %>
<h1>404</h1>
<p>La página solicitada no existe.</p>
<%- include('partials/footer') %>
```

Se renderiza desde el middleware 404 de `app.js` con el código HTTP 404.

#### `node/src/views/error.ejs`

Página de error interno:

```ejs
<%- include('partials/head') %>
<%- include('partials/header') %>
<h1>Error del servidor</h1>
<p>No se pudo completar la solicitud.</p>
<%- include('partials/footer') %>
```

Se renderiza desde `error.middleware.js` con el código HTTP 500.

#### `node/src/public/css/styles.css`

Está vacío. Es la hoja de estilos que enlaza `head.ejs` en todas las páginas.
Aquí se añadirán los estilos visuales de la web. Al estar en `src/public`, se
sirve como `/css/styles.css`.

#### `node/src/public/img/.gitkeep`

Está vacío. Su única función es mantener la carpeta `img/` dentro de Git, ya que
Git no versiona carpetas vacías. Aquí se guardarán las imágenes del proyecto.

### 12.5 Carpeta `php/`

#### `php/Dockerfile`

Construye la imagen de PHP con Apache:

```dockerfile
FROM php:8.3-apache

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev \
    && docker-php-ext-install pdo_pgsql \
    && a2enmod rewrite \
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' \
    '<VirtualHost *:80>' \
    '    DocumentRoot /var/www/html/public' \
    '    <Directory /var/www/html/public>' \
    '        AllowOverride All' \
    '        Require all granted' \
    '    </Directory>' \
    '</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

COPY public /var/www/html/public
COPY src /var/www/html/src
COPY templates /var/www/html/templates

EXPOSE 80
```

Línea a línea:

- `FROM php:8.3-apache`: PHP 8.3 con Apache ya configurado.
- `apt-get update`: actualiza la lista de paquetes.
- `apt-get install ... libpq-dev`: instala las cabeceras necesarias para
  compilar el driver de PostgreSQL.
- `docker-php-ext-install pdo_pgsql`: compila y activa la extensión PDO para
  PostgreSQL, necesaria para que PHP hable con la base de datos.
- `a2enmod rewrite`: activa el módulo de reescritura de Apache, necesario para
  que `.htaccess` pueda redirigir todas las rutas a `index.php`.
- `apt-get purge -y --auto-remove`: elimina paquetes de compilación que ya no
  hacen falta.
- `rm -rf /var/lib/apt/lists/*`: limpia la caché de paquetes para reducir el
  tamaño de la imagen.
- `RUN printf ...`: escribe un nuevo virtual host de Apache con
  `DocumentRoot /var/www/html/public`. Esto es importante: solo la carpeta
  `public` es accesible desde el navegador; `src` y `templates` quedan fuera del
  DocumentRoot. También permite `AllowOverride All` para que `.htaccess`
  funcione.
- `COPY public`, `COPY src`, `COPY templates`: copia cada parte al contenedor
  manteniendo la estructura.
- `EXPOSE 80`: documenta el puerto de Apache.
- No hay `CMD` porque la imagen base `php:8.3-apache` ya arranca Apache
  automáticamente.

#### `php/.dockerignore`

Evita copiar al contexto de construcción:

```text
.dockerignore
Dockerfile
.env
```

- `.dockerignore`: el propio archivo de exclusión.
- `Dockerfile`: no es necesario dentro de la imagen.
- `.env`: evita incluir secretos.

#### `php/public/.htaccess`

Configura las URLs limpias de Apache:

```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [QSA,L]
```

- `RewriteEngine On`: activa la reescritura.
- `RewriteCond %{REQUEST_FILENAME} !-f`: si la URL no corresponde a un archivo
  real, sigue con la reescritura.
- `RewriteCond %{REQUEST_FILENAME} !-d`: si tampoco corresponde a un directorio
  real, sigue.
- `RewriteRule ^ index.php [QSA,L]`: envía la petición a `index.php`, conserva
  los parámetros de la query string (`QSA`) y detiene el procesamiento (`L`).

Gracias a esto, `/comisiones` y `/comisiones/1` llegan al front controller en
lugar de dar un 404 de Apache.

#### `php/public/index.php`

Es el front controller de PHP. Todo el tráfico dinámico entra por aquí:

```php
<?php

declare(strict_types=1);

use App\Controllers\ComisionController;

require_once __DIR__ . '/../src/Controllers/ComisionController.php';

$ruta = trim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/', '/');
$controlador = new ComisionController();

if ($ruta === 'comisiones') {
    $controlador->index();
    exit;
}

if (preg_match('#^comisiones/(\d+)$#', $ruta, $coincidencias) === 1) {
    $controlador->show((int) $coincidencias[1]);
    exit;
}

if ($ruta === 'health') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['status' => 'ok']);
    exit;
}

if ($ruta !== '') {
    http_response_code(404);
}

require __DIR__ . '/../templates/layout.php';
```

Explicación:

- `declare(strict_types=1)`: activa tipos estrictos en PHP.
- `use App\Controllers\ComisionController`: importa el controlador.
- `require_once`: carga el archivo del controlador porque no se usa Composer ni
  autoload.
- `$ruta`: obtiene la ruta de la URL, elimina la query string y quita las barras
  iniciales y finales. Para `/comisiones` vale `comisiones`; para `/` vale ``.
- `$controlador`: instancia el controlador.
- Si la ruta es `comisiones`, llama a `index()` y termina.
- Si la ruta coincide con `comisiones/{número}`, llama a `show()` con el número
  convertido a entero y termina.
- Si la ruta es `health`, devuelve JSON con `{"status":"ok"}` y termina. No
  consulta la base de datos.
- Si la ruta no está vacía y no coincidió con nada, marca HTTP 404.
- Finalmente carga `layout.php`, que es la página de inicio o la página 404
  según el código fijado.
- `comisiones/nueva` no está implementada en PHP y actualmente cae en el 404.

#### `php/public/css/styles.css`

Está vacío. Es la hoja de estilos que enlaza `templates/partials/header.php`.
Apache la sirve directamente porque está dentro de `public`, en
`/css/styles.css`.

#### `php/src/Config/Database.php`

Define la conexión PDO a PostgreSQL:

```php
<?php

declare(strict_types=1);

namespace App\Config;

use PDO;

class Database
{
    public static function connection(): PDO
    {
        $dsn = sprintf(
            'pgsql:host=%s;port=%s;dbname=%s',
            getenv('DB_HOST') ?: 'db',
            getenv('DB_PORT') ?: '5432',
            getenv('DB_NAME') ?: 'comisiones'
        );

        return new PDO(
            $dsn,
            getenv('DB_USER') ?: 'comisiones',
            getenv('DB_PASSWORD') ?: 'comisiones_dev'
        );
    }
}
```

- `namespace App\Config`: espacio de nombres de la clase.
- `use PDO`: importa la clase PDO.
- `connection()`: método estático que devuelve una conexión PDO.
- `$dsn`: cadena de conexión con host, puerto y base de datos. Usa los valores
  de entorno y cae en valores por defecto si no existen.
- `new PDO(...)`: crea la conexión con usuario y contraseña.
- Actualmente ningún archivo llama a esta clase; es infraestructura para la
  siguiente fase.

#### `php/src/Models/Comision.php`

```php
<?php

declare(strict_types=1);

namespace App\Models;

class Comision
{
}
```

Es un placeholder. La clase está vacía y su función prevista es contener los
métodos de acceso a datos de comisiones, usando `Database::connection()`.

#### `php/src/Controllers/ComisionController.php`

```php
<?php

declare(strict_types=1);

namespace App\Controllers;

class ComisionController
{
    public function index(): void
    {
        require __DIR__ . '/../../templates/comisiones/index.php';
    }

    public function show(int $id): void
    {
        require __DIR__ . '/../../templates/comisiones/show.php';
    }
}
```

- `index()`: carga la plantilla del listado. No consulta la base de datos.
- `show(int $id)`: recibe el identificador y carga la plantilla de detalle. El
  `$id` queda disponible dentro de la plantilla porque `require` se ejecuta en
  el mismo ámbito.
- No hay métodos de creación, edición ni cambio de estado en esta fase.

#### `php/templates/layout.php`

Es la página de inicio:

```php
<?php require __DIR__ . '/partials/header.php'; ?>
<h1>Comisiones de dibujos</h1>
<p>Estructura inicial del proyecto.</p>
<?php require __DIR__ . '/partials/footer.php'; ?>
```

- Incluye el header.
- Muestra un título y un texto de placeholder.
- Incluye el footer.

`__DIR__` apunta a `templates/`, así que la ruta a los parciales es correcta
aunque se ejecute desde otro directorio.

#### `php/templates/partials/header.php`

Abre el documento y pinta la navegación:

```php
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Comisiones de dibujos</title>
    <link rel="stylesheet" href="/css/styles.css">
</head>
<body>
    <header>
        <nav>
            <a href="/">Inicio</a>
            <a href="/comisiones">Comisiones</a>
        </nav>
    </header>
    <main>
```

- Contiene la cabecera HTML y el inicio del cuerpo.
- Enlaza `/css/styles.css`, servido desde `php/public/css/styles.css`.
- Los enlaces son navegación normal, sin JavaScript.
- Deja abierto `<main>` para que la plantilla incluida escriba su contenido.

#### `php/templates/partials/footer.php`

```php
    </main>
</body>
</html>
```

- Cierra `<main>`, `<body>` y `<html>`.
- No incluye scripts.

#### `php/templates/comisiones/index.php`

```php
<?php require __DIR__ . '/../partials/header.php'; ?>
<h1>Comisiones</h1>
<p>Listado pendiente de implementar.</p>
<?php require __DIR__ . '/../partials/footer.php'; ?>
```

- Incluye el header.
- Muestra el título y un placeholder del listado.
- Incluye el footer.
- La ruta relativa `../partials/` es correcta porque este archivo está en
  `templates/comisiones/`.

#### `php/templates/comisiones/show.php`

```php
<?php require __DIR__ . '/../partials/header.php'; ?>
<h1>Detalle de la comisión <?= (int) $id ?></h1>
<p>Detalle pendiente de implementar.</p>
<?php require __DIR__ . '/../partials/footer.php'; ?>
```

- Incluye el header.
- Muestra el `id` recibido, convertido a entero y escapado implícitamente al ser
  un número.
- Muestra un placeholder del detalle.
- Incluye el footer.

### 12.6 Cómo se conectan todos los archivos

#### Flujo de una petición en Node.js

1. El navegador pide `http://localhost:3000/comisiones`.
2. Docker publica el puerto 3000 del host al 3000 del contenedor `node`.
3. `node/src/server.js` ya está escuchando y entrega la petición a
   `node/src/app.js`.
4. `app.js` aplica los middlewares generales y monta `comisiones.routes.js` en
   `/comisiones`.
5. `comisiones.routes.js` selecciona `comisionesController.listar`.
6. `listar` renderiza `views/comisiones/index.ejs` con un array vacío.
7. EJS incluye `head.ejs`, `header.ejs`, el contenido y `footer.ejs`, y genera
   un HTML completo.
8. Express envía ese HTML con código 200. El navegador solo tiene que pintarlo.

Cuando se implemente la base de datos, el paso 6 consultará
`models/comisiones.model.js`, que a su vez usará `config/db.js` para ejecutar
SQL contra PostgreSQL. La respuesta seguirá siendo HTML completo.

#### Flujo de una petición en PHP

1. El navegador pide `http://localhost:8000/comisiones`.
2. Docker publica el puerto 8000 del host al 80 del contenedor `php`.
3. Apache recibe la petición. Como `/comisiones` no es un archivo real,
   `.htaccess` la reescribe a `index.php`.
4. `php/public/index.php` calcula la ruta `comisiones`.
5. Instancia `ComisionController` y llama a `index()`.
6. El controlador incluye `templates/comisiones/index.php`.
7. Esa plantilla incluye `partials/header.php`, escribe el contenido e incluye
   `partials/footer.php`.
8. Apache devuelve el HTML generado. El navegador lo pinta.

Cuando se implemente la base de datos, el controlador o el modelo usarán
`src/Config/Database.php` para consultar PostgreSQL antes de incluir la
plantilla.

#### Flujo de la base de datos

1. `docker compose up` crea el contenedor `db`.
2. PostgreSQL crea el volumen `postgres_data` si no existe.
3. Al inicializar por primera vez, ejecuta en orden los archivos de
   `database/init/`: primero `001-schema.sql` y después `002-seed.sql`.
4. `001-schema.sql` crea las siete tablas y los índices.
5. `002-seed.sql`, al estar vacío, no inserta datos.
6. El healthcheck `pg_isready` marca la base de datos como sana.
7. Node y PHP arrancan y reciben `DB_HOST=db`, por lo que pueden conectarse por
   la red interna de Docker.

#### Flujo futuro de un formulario

1. `GET /comisiones/nueva` muestra el formulario HTML.
2. El usuario lo rellena y pulsa enviar.
3. El navegador hace `POST /comisiones` con los datos del formulario.
4. El controlador valida los datos.
5. El modelo ejecuta el `INSERT` en PostgreSQL.
6. El servidor responde con un redirect a `/comisiones/:id`.
7. El navegador hace `GET /comisiones/:id` y recibe el detalle en HTML.

No hay ninguna llamada `fetch`, ni JSON intermedio, ni JavaScript que consulte
la base de datos. El navegador siempre recibe HTML generado en el servidor.

### 12.7 Archivos que no están en el repositorio

Estos archivos o recursos existen en tiempo de ejecución, pero no se versionan:

- `.env`: se crea a partir de `.env.example` y contiene las credenciales reales.
  Está en `.gitignore`.
- `node_modules/`: lo crea `npm install` al construir la imagen o al instalar en
  local. No se versiona.
- `package-lock.json`: no está en el repositorio. Si se genera con `npm install`
  en local, se puede versionar para fijar las versiones exactas.
- `postgres_data`: es un volumen de Docker, no una carpeta del proyecto. Guarda
  los datos de PostgreSQL y sobrevive a `docker compose down`, pero se borra con
  `docker compose down --volumes`.
- Imágenes Docker: se construyen a partir de los Dockerfiles y no forman parte
  del código fuente.
- Archivos de logs de npm y de contenedores: se generan en ejecución y están
  ignorados o se consultan con `docker compose logs`.

### 12.8 Resumen de responsabilidades

| Archivo o carpeta                         | Responsabilidad principal                                   |
| ----------------------------------------- | ----------------------------------------------------------- |
| `docker-compose.yml`                      | Definir y conectar los tres contenedores                    |
| `.env.example`                            | Documentar las variables de entorno                         |
| `database/init/001-schema.sql`            | Crear el esquema de PostgreSQL                              |
| `database/init/002-seed.sql`              | Insertar datos iniciales (pendiente)                        |
| `node/Dockerfile`                         | Construir la imagen de Node.js                              |
| `node/package.json`                       | Declarar dependencias y el comando de arranque              |
| `node/src/server.js`                      | Arrancar el servidor HTTP                                   |
| `node/src/app.js`                         | Configurar Express, vistas, estáticos, rutas y errores      |
| `node/src/config/db.js`                   | Crear el pool de conexiones a PostgreSQL                    |
| `node/src/routes/*.js`                    | Asociar URLs con controladores                              |
| `node/src/controllers/*.js`               | Decidir qué vista renderizar y preparar sus datos           |
| `node/src/models/*.js`                    | Ejecutar consultas SQL (pendiente)                          |
| `node/src/middlewares/error.middleware.js`| Capturar errores y devolver la página 500                   |
| `node/src/views/**/*.ejs`                 | Generar el HTML con los datos recibidos                     |
| `node/src/public/**`                      | Servir CSS, imágenes y otros estáticos                      |
| `php/Dockerfile`                          | Construir PHP con Apache y `pdo_pgsql`                      |
| `php/public/.htaccess`                    | Reescribir las URLs limpias hacia `index.php`               |
| `php/public/index.php`                    | Front controller y enrutado de PHP                          |
| `php/src/Config/Database.php`             | Crear la conexión PDO a PostgreSQL                          |
| `php/src/Models/Comision.php`             | Acceso a datos de comisiones (pendiente)                    |
| `php/src/Controllers/ComisionController.php` | Cargar las plantillas de comisiones                      |
| `php/templates/**`                        | Generar el HTML de la interfaz PHP                          |
| `docs/README.md`                          | Documentar el proyecto completo                             |

Con esto queda explicado qué contiene cada archivo, qué hace y cómo encaja con
el resto de la infraestructura.

## 13. ORM con Prisma para Node.js

> Este apartado es una explicación de diseño. Todavía no se ha instalado Prisma,
> no se ha creado `prisma/schema.prisma` ni se ha modificado el código. Los
> ejemplos son ilustrativos para entender cómo funcionará.

### 13.1 Qué es un ORM

Un ORM (Object-Relational Mapping, o mapeo objeto-relacional) es una capa de
software que traduce entre dos mundos:

- El mundo de la base de datos relacional: tablas, filas, columnas, claves
  foráneas y SQL.
- El mundo del lenguaje de programación: objetos, clases, propiedades y
  métodos.

Sin ORM, el modelo de Node escribiría SQL manualmente:

```js
const resultado = await pool.query(
  'SELECT * FROM comisiones WHERE estado_id = $1 ORDER BY creado_en DESC',
  [estadoId]
);
```

Con un ORM, el código pide objetos y el ORM genera el SQL por debajo:

```js
const comisiones = await prisma.comision.findMany({
  where: { estadoId },
  orderBy: { creadoEn: 'desc' },
});
```

El ORM no sustituye a PostgreSQL ni elimina el SQL: lo genera, lo parametriza y
convierte los resultados en objetos manejables por JavaScript. La base de datos
sigue siendo la misma y el navegador sigue recibiendo HTML generado en el
servidor.

### 13.2 Por qué Prisma

Prisma es un ORM para Node.js y TypeScript. Se elige para este proyecto porque:

- Se integra bien con PostgreSQL.
- El modelo de datos se declara en un único archivo legible,
  `prisma/schema.prisma`.
- Genera un cliente tipado (`Prisma Client`) con autocompletado y errores
  detectables antes de ejecutar.
- Incluye un sistema de migraciones que guarda los cambios del esquema como
  archivos SQL versionables.
- Permite consultar relaciones sin escribir `JOIN` manuales.
- Tiene herramientas útiles como Prisma Studio para ver la base de datos.
- Usa consultas parametrizadas, lo que ayuda a evitar inyección SQL.

Prisma no es una base de datos: es una capa entre Node.js y PostgreSQL.

### 13.3 Las piezas de Prisma

Prisma se compone de cuatro piezas principales:

| Pieza | Qué es | Dónde vive |
| ----- | ------ | ---------- |
| Prisma Schema | Archivo donde se declaran modelos, relaciones y configuración | `prisma/schema.prisma` |
| Prisma CLI | Herramienta de línea de comandos para migrar, generar y abrir Studio | Dependencia de desarrollo `prisma` |
| Prisma Client | Biblioteca generada que usa el código Node para consultar la base de datos | Dependencia `@prisma/client` |
| Base de datos | PostgreSQL, que almacena los datos reales | Contenedor `db` |

#### El archivo `schema.prisma`

Es la fuente de verdad del modelo. Tiene tres bloques habituales:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Comision {
  id              BigInt   @id @default(autoincrement())
  titulo          String   @db.VarChar(160)
  precioAcordado  Decimal  @map("precio_acordado") @db.Decimal(10, 2)
  creadoEn        DateTime @default(now()) @map("creado_en") @db.Timestamptz()

  @@map("comisiones")
}
```

- `generator client`: indica que se genere el cliente de JavaScript.
- `datasource db`: indica que la base de datos es PostgreSQL y que la URL de
  conexión se lee de la variable de entorno `DATABASE_URL`.
- `model Comision`: declara una tabla y sus columnas.
- `@id`, `@default`, `@unique`, `@relation` y `@@map` son atributos que definen
  claves, valores por defecto, restricciones, relaciones y nombres reales en la
  base de datos.

#### El CLI de Prisma

Se usa para tareas de desarrollo y despliegue:

```sh
npx prisma generate          # genera o actualiza Prisma Client
npx prisma migrate dev       # crea y aplica una migración en desarrollo
npx prisma migrate deploy    # aplica migraciones pendientes en producción/Docker
npx prisma db pull           # lee una base de datos existente y genera el schema
npx prisma db push           # sincroniza el schema sin crear migraciones
npx prisma studio            # abre una interfaz web para ver y editar datos
npx prisma migrate reset     # borra y recrea la base de datos en desarrollo
```

No todos se usan siempre. En el flujo recomendado se usan `migrate dev` durante
el desarrollo y `migrate deploy` al arrancar en Docker.

#### Prisma Client

Es la biblioteca que importa el código de la aplicación:

```js
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

module.exports = prisma;
```

A partir de ahí, el código llama a métodos generados a partir del schema:

```js
await prisma.comision.findMany();
await prisma.comision.findUnique({ where: { id: 1 } });
await prisma.comision.create({ data: { titulo: 'Retrato' } });
await prisma.comision.update({ where: { id: 1 }, data: { titulo: 'Otro' } });
await prisma.comision.delete({ where: { id: 1 } });
```

El cliente debe generarse después de cada cambio del schema. Si se modifica
`schema.prisma` y no se ejecuta `prisma generate`, el código puede no conocer
los modelos nuevos.

### 13.4 Flujo de funcionamiento

#### En desarrollo

```text
1. Se edita prisma/schema.prisma
2. npx prisma migrate dev --name nombre-del-cambio
3. Prisma compara el schema con la base de datos
4. Genera un archivo SQL en prisma/migrations/
5. Aplica ese SQL a PostgreSQL
6. Ejecuta npx prisma generate
7. El código Node ya puede usar los modelos nuevos
```

La migración queda versionada en el repositorio. Así, otro desarrollador puede
aplicar los mismos cambios con `prisma migrate deploy`.

#### En tiempo de ejecución

```text
Navegador
   |
   | GET /comisiones
   v
Express -> Router -> Controlador
                         |
                         | await prisma.comision.findMany(...)
                         v
                   Prisma Client
                         |
                         | genera SQL parametrizado
                         v
                    PostgreSQL
                         |
                         | devuelve filas
                         v
                   Prisma Client
                         |
                         | convierte filas en objetos JS
                         v
Controlador -> res.render('comisiones/index.ejs', { comisiones })
                         |
                         v
                  HTML completo
                         |
                         v
                     Navegador
```

Prisma está solo en el servidor. El navegador no importa Prisma, no habla con
PostgreSQL y no recibe JSON de la base de datos. El flujo de renderizado en el
servidor explicado en la sección 2 no cambia.

### 13.5 Conexión con PostgreSQL y Docker

Prisma necesita una única variable de entorno, `DATABASE_URL`, con este formato:

```text
postgresql://USUARIO:CONTRASEÑA@HOST:PUERTO/BASE_DE_DATOS?schema=public
```

Dentro de Docker, el host es el nombre del servicio de PostgreSQL, `db`:

```dotenv
DATABASE_URL=postgresql://comisiones:comisiones_dev@db:5432/comisiones?schema=public
```

Fuera de Docker, para ejecutar comandos desde el host, el host sería
`localhost`:

```dotenv
DATABASE_URL=postgresql://comisiones:comisiones_dev@localhost:5432/comisiones?schema=public
```

Consideraciones:

- La contraseña debe ir codificada si contiene caracteres especiales como `@`,
  `:`, `/` o `#`.
- `DATABASE_URL` debe estar en `.env` y en `.gitignore`; el `.env.example` solo
  debe contener un valor de ejemplo.
- En `docker-compose.yml`, el servicio `node` tendría que recibir
  `DATABASE_URL` además de las variables `DB_*` actuales, o sustituir estas
  últimas por `DATABASE_URL`.
- El contenedor `db` no necesita cambios: sigue siendo PostgreSQL 16 con su
  volumen y su healthcheck.
- Prisma se ejecuta dentro del contenedor `node`, no en el navegador.

### 13.6 Cómo se representaría el modelo de comisiones

El esquema SQL actual de `database/init/001-schema.sql` se traduciría a modelos
de Prisma. Un ejemplo orientativo, todavía no creado, sería:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum Rol {
  cliente
  artista
  admin
}

enum EstadoComision {
  pendiente
  en_proceso
  entregada
  cancelada
}

enum TipoArchivo {
  referencia
  entrega
}

enum EstadoPago {
  pendiente
  pagado
  reembolsado
}

model Usuario {
  id           BigInt    @id @default(autoincrement())
  nombre       String    @db.VarChar(120)
  email        String    @unique @db.VarChar(180)
  passwordHash String    @map("password_hash") @db.VarChar(255)
  rol          Rol       @default(cliente)
  creadoEn     DateTime  @default(now()) @map("creado_en") @db.Timestamptz()

  artista      Artista?
  comisiones   Comision[] @relation("ClienteComisiones")

  @@map("usuarios")
}

model Artista {
  id              BigInt    @id @default(autoincrement())
  usuarioId       BigInt    @unique @map("usuario_id")
  nombreArtistico String    @map("nombre_artistico") @db.VarChar(120)
  biografia       String?
  portafolioUrl   String?   @map("portafolio_url") @db.VarChar(500)
  disponible      Boolean   @default(true)
  creadoEn        DateTime  @default(now()) @map("creado_en") @db.Timestamptz()

  usuario         Usuario   @relation(fields: [usuarioId], references: [id], onDelete: Cascade)
  comisiones      Comision[]

  @@map("artistas")
}

model TipoComision {
  id          BigInt     @id @default(autoincrement())
  nombre      String     @unique @db.VarChar(100)
  descripcion String?
  precioBase  Decimal    @default(0) @map("precio_base") @db.Decimal(10, 2)
  activo      Boolean    @default(true)

  comisiones  Comision[]

  @@map("tipos_comision")
}

model Comision {
  id             BigInt         @id @default(autoincrement())
  clienteId      BigInt         @map("cliente_id")
  artistaId      BigInt         @map("artista_id")
  tipoId         BigInt         @map("tipo_id")
  estado         EstadoComision @default(pendiente)
  titulo         String         @db.VarChar(160)
  descripcion    String
  referencias    String?
  precioAcordado Decimal        @map("precio_acordado") @db.Decimal(10, 2)
  fechaEntrega   DateTime?      @map("fecha_entrega") @db.Date
  creadoEn       DateTime       @default(now()) @map("creado_en") @db.Timestamptz()
  actualizadoEn  DateTime       @updatedAt @map("actualizado_en") @db.Timestamptz()

  cliente        Usuario        @relation("ClienteComisiones", fields: [clienteId], references: [id])
  artista        Artista        @relation(fields: [artistaId], references: [id])
  tipo           TipoComision   @relation(fields: [tipoId], references: [id])
  archivos       ArchivoComision[]
  pagos          Pago[]

  @@index([clienteId])
  @@index([artistaId])
  @@index([creadoEn(sort: Desc)])
  @@map("comisiones")
}

model ArchivoComision {
  id         BigInt      @id @default(autoincrement())
  comisionId BigInt      @map("comision_id")
  url        String      @db.VarChar(500)
  tipo       TipoArchivo @default(entrega)
  creadoEn   DateTime    @default(now()) @map("creado_en") @db.Timestamptz()

  comision   Comision    @relation(fields: [comisionId], references: [id], onDelete: Cascade)

  @@map("archivos_comision")
}

model Pago {
  id         BigInt      @id @default(autoincrement())
  comisionId BigInt      @map("comision_id")
  monto      Decimal     @db.Decimal(10, 2)
  metodo     String?     @db.VarChar(40)
  estado     EstadoPago  @default(pendiente)
  creadoEn   DateTime    @default(now()) @map("creado_en") @db.Timestamptz()

  comision   Comision    @relation(fields: [comisionId], references: [id], onDelete: Cascade)

  @@map("pagos")
}
```

Notas sobre la traducción:

- `model` equivale a una tabla.
- Cada campo del modelo equivale a una columna.
- `@map("nombre_real")` traduce un nombre camelCase de JavaScript al nombre
  snake_case de la base de datos.
- `@@map("nombre_tabla")` traduce el nombre del modelo al nombre real de la
  tabla.
- `@relation` define las claves foráneas y las relaciones.
- `@unique` crea una restricción de unicidad.
- `@default` define el valor por defecto.
- `onDelete: Cascade` reproduce el borrado en cascada del esquema SQL.
- `@@index` crea índices.
- Los `enum` de Prisma se convierten en tipos enum de PostgreSQL. El esquema SQL
  actual usa `VARCHAR` con `CHECK`; si se parte de cero con Prisma, se pueden
  usar enums; si se conserva el esquema existente, habría que mapear esos campos
  como `String` o crear una migración que cambie los tipos.
- Los identificadores `BigInt` se convierten en `bigint` de PostgreSQL. En
  JavaScript, Prisma los devuelve como `BigInt`, no como `Number`. EJS puede
  imprimirlos, pero si algún día se devuelve JSON habrá que convertirlos a
  cadena o a número.

### 13.7 Cómo se usaría desde Node.js

La estructura actual ya tiene una separación adecuada para introducir Prisma:

```text
node/src/
├── config/
│   └── prisma.js          # instancia única de PrismaClient
├── models/
│   └── comisiones.model.js # consultas con Prisma
├── controllers/
│   └── comisiones.controller.js
└── routes/
    └── comisiones.routes.js
```

`config/prisma.js` sería el equivalente de `config/db.js`, pero creando un
cliente de Prisma en lugar de un pool de `pg`:

```js
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

module.exports = prisma;
```

El modelo de comisiones contendría las consultas:

```js
const prisma = require('../config/prisma');

async function listarTodas() {
  return prisma.comision.findMany({
    include: {
      cliente: true,
      artista: true,
      tipo: true,
    },
    orderBy: {
      creadoEn: 'desc',
    },
  });
}

async function buscarPorId(id) {
  return prisma.comision.findUnique({
    where: { id },
    include: {
      cliente: true,
      artista: true,
      tipo: true,
      archivos: true,
      pagos: true,
    },
  });
}

module.exports = {
  listarTodas,
  buscarPorId,
};
```

El controlador seguiría siendo el mismo en concepto, pero pasaría a ser
asíncrono:

```js
const comisionesModel = require('../models/comisiones.model');

exports.listar = async (req, res, next) => {
  try {
    const comisiones = await comisionesModel.listarTodas();
    res.render('comisiones/index', {
      titulo: 'Comisiones',
      comisiones,
    });
  } catch (error) {
    next(error);
  }
};
```

Y la vista EJS recorrería los objetos igual que recorrería filas:

```ejs
<% comisiones.forEach((comision) => { %>
  <tr>
    <td>
      <a href="/comisiones/<%= comision.id %>">
        <%= comision.titulo %>
      </a>
    </td>
    <td><%= comision.artista.nombreArtistico %></td>
    <td><%= comision.tipo.nombre %></td>
    <td><%= comision.precioAcordado %> EUR</td>
  </tr>
<% }) %>
```

La diferencia principal es que el modelo ya no escribe SQL: llama a métodos de
Prisma. Prisma genera el SQL y devuelve objetos con relaciones incluidas.

### 13.8 Migraciones y relación con `database/init/`

Actualmente la base de datos se crea con `database/init/001-schema.sql`. Prisma
puede sustituir ese mecanismo o convivir con él, pero no es recomendable que
ambos creen las mismas tablas.

#### Opción A: Prisma como fuente de verdad (recomendada)

1. Crear `prisma/schema.prisma` con los modelos.
2. Ejecutar `npx prisma migrate dev --name init` para generar la primera
   migración.
3. Prisma crea la carpeta `prisma/migrations/` con el SQL generado.
4. Dejar de montar `database/init/001-schema.sql` en PostgreSQL, o retirarlo,
   para que no intente crear tablas que Prisma ya crea.
5. Usar `npx prisma migrate deploy` al desplegar o al arrancar el contenedor.
6. Usar `prisma/seed.js` o un script de seed para los datos iniciales.

Ventaja: el schema y las migraciones están en un solo sitio y se versionan
juntos. Es el flujo más habitual en proyectos con Prisma.

#### Opción B: conservar el SQL y leerlo con Prisma

1. Mantener `database/init/001-schema.sql` como creador del esquema.
2. Ejecutar `npx prisma db pull` para que Prisma lea la base de datos y genere
   `schema.prisma`.
3. Ejecutar `npx prisma generate` para crear el cliente.
4. No usar `migrate dev` sobre tablas ya creadas, salvo que se haga un baseline
   de las migraciones.

Ventaja: no se toca el SQL actual. Inconveniente: el schema de Prisma pasa a ser
una consecuencia de la base de datos, no la fuente de verdad, y las migraciones
pueden ser más confusas.

#### Opción C: `prisma db push` sin migraciones

`npx prisma db push` sincroniza el schema con la base de datos sin generar
archivos de migración. Es cómodo para prototipos, pero no deja historial de
cambios. Para un trabajo de clase con entrega y evolución, es preferible usar
migraciones.

#### Reset en desarrollo

Si se cambia el esquema y se quiere empezar de cero:

```sh
docker compose down --volumes
docker compose up --build
```

o, una vez integrado Prisma:

```sh
npx prisma migrate reset
```

`migrate reset` borra la base de datos y vuelve a aplicar todas las migraciones.
No debe usarse en producción.

### 13.9 Cómo encajaría Prisma en Docker

Prisma necesita tres cosas dentro del contenedor de Node:

1. El archivo `prisma/schema.prisma`.
2. El cliente generado de Prisma.
3. La variable `DATABASE_URL`.

Posibles formas de arranque:

#### Opción 1: migrar al arrancar el contenedor

El servicio `node` ejecutaría algo equivalente a:

```sh
npx prisma migrate deploy && npm start
```

Ventaja: con un solo `docker compose up`, las migraciones se aplican antes de
levantar el servidor. Inconveniente: si hay varios contenedores Node a la vez,
varios intentarían migrar. Para este proyecto, con un único contenedor, es
suficiente.

#### Opción 2: servicio de migración separado

Se crearía un servicio que ejecute solo `prisma migrate deploy` y termine. El
servicio `node` dependería de que ese servicio termine correctamente. Es más
robusto, pero añade complejidad al `docker-compose.yml`.

#### Opción 3: migrar manualmente

El contenedor Node arranca solo con `npm start` y las migraciones se aplican
desde el host:

```sh
docker compose exec node npx prisma migrate deploy
```

Es útil para aprender y para un entorno de clase, pero requiere un paso manual.

#### Generación del cliente en la imagen

El Dockerfile tendría que copiar `prisma/` y ejecutar `npx prisma generate`
durante la construcción, o usar un script `postinstall`. Si no se genera el
cliente, el contenedor fallará al hacer `require('@prisma/client')`.

Un esquema orientativo, no implementado, sería:

```dockerfile
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma
RUN npm install --omit=dev
RUN npx prisma generate

COPY src ./src

EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && npm start"]
```

Si `prisma` queda como dependencia de desarrollo, `npm install --omit=dev` no lo
instala. Habría que incluirlo como dependencia normal o usar una etapa de
construcción que lo instale y luego copie el cliente generado. Esta decisión se
tomará al implementarlo.

### 13.10 Cambios previstos en la estructura

Cuando se implemente Prisma, la estructura cambiaría así:

```text
node/
├── prisma/
│   ├── schema.prisma          # modelos y datasource
│   ├── migrations/            # migraciones SQL generadas
│   └── seed.js                # datos iniciales (opcional)
├── src/
│   ├── config/
│   │   └── prisma.js          # instancia de PrismaClient
│   ├── models/
│   │   └── comisiones.model.js # consultas con Prisma
│   └── ...
├── package.json               # añade prisma y @prisma/client
└── Dockerfile                 # copia prisma/ y genera el cliente
```

Archivos afectados:

| Archivo actual | Cambio previsto |
| -------------- | --------------- |
| `node/package.json` | Añadir `prisma` y `@prisma/client` |
| `node/src/config/db.js` | Sustituirse por `node/src/config/prisma.js` o dejar de usarse |
| `node/src/models/comisiones.model.js` | Implementar consultas con Prisma |
| `node/src/controllers/comisiones.controller.js` | Hacer los métodos asíncronos y pasar datos reales a las vistas |
| `node/Dockerfile` | Copiar `prisma/`, generar el cliente y migrar al arrancar |
| `docker-compose.yml` | Añadir `DATABASE_URL` al servicio `node` |
| `.env.example` | Añadir `DATABASE_URL` de ejemplo |
| `database/init/001-schema.sql` | Retirarse del montaje o quedarse como referencia si Prisma pasa a ser la fuente de verdad |
| `database/init/002-seed.sql` | Sustituirse por un seed de Prisma o ejecutarse después de las migraciones |
| `docs/README.md` | Actualizar la explicación cuando esté implementado |

### 13.11 Ventajas e inconvenientes de Prisma en este proyecto

Ventajas:

- Menos SQL repetitivo en los modelos.
- Relaciones declaradas de forma clara.
- Consultas parametrizadas por defecto.
- Un único schema como fuente de verdad.
- Migraciones versionadas y reproducibles.
- Autocompletado y comprobación de tipos si se usa TypeScript o un editor con
  soporte para JSDoc.
- Prisma Studio facilita revisar los datos.
- El flujo de renderizado en el servidor se mantiene igual.

Inconvenientes:

- Añade una dependencia y un paso de generación del cliente.
- Hay que aprender su schema, sus atributos y sus comandos.
- Las migraciones requieren disciplina: no se debe cambiar la base de datos a
  mano sin reflejarlo en el schema.
- Las consultas muy complejas pueden requerir SQL nativo
  (`prisma.$queryRaw`).
- La abstracción puede ocultar el SQL que realmente se ejecuta; conviene
  revisarlo en `prisma/migrations`.
- `BigInt` y `Decimal` tienen particularidades al serializar.
- El contenedor necesita `DATABASE_URL` y el cliente generado.

Para un trabajo de clase, la balanza suele ser positiva: se aprende el modelo
relacional, se evita escribir SQL repetitivo y se obtiene un historial de
migraciones. Aun así, es importante entender el SQL que Prisma genera.

### 13.12 Seguridad y buenas prácticas con Prisma

- No commitear `.env` ni `DATABASE_URL` con credenciales reales.
- Usar un usuario de PostgreSQL con los permisos mínimos necesarios.
- No exponer Prisma ni PostgreSQL al navegador.
- Validar los datos de entrada en el controlador antes de llamar a Prisma; el
  ORM evita inyección SQL, pero no valida reglas de negocio.
- Usar transacciones (`prisma.$transaction`) cuando varias operaciones deban
  ser atómicas.
- No usar `migrate reset` ni `db push` en producción.
- Revisar las migraciones generadas antes de aplicarlas.
- Gestionar los errores de Prisma y no mostrar detalles internos al usuario.
- Cerrar Prisma correctamente al detener el proceso (`prisma.$disconnect()`),
  especialmente en scripts y pruebas.
- Hacer copias de seguridad del volumen de PostgreSQL antes de cambios
  importantes de esquema.

### 13.13 Qué no cambia con Prisma

Aunque se introduzca un ORM, la arquitectura del proyecto sigue siendo la misma:

- El navegador pide páginas HTML.
- El servidor consulta la base de datos.
- La base de datos devuelve datos al servidor.
- El servidor mezcla los datos con EJS.
- El servidor devuelve HTML completo.
- No hay JavaScript de cliente que pida datos después de cargar la página.
- PHP sigue usando PDO y su propio flujo; Prisma solo afecta a Node.js.
- PostgreSQL sigue siendo la misma base de datos y las dos interfaces pueden
  compartirla.

La única diferencia es que, en Node.js, la consulta SQL ya no se escribe a mano:
la genera Prisma a partir del schema.

### 13.14 Plan de implementación propuesto

Cuando se autorice la instalación, el orden sería:

1. Añadir `prisma` y `@prisma/client` a `node/package.json`.
2. Crear `node/prisma/schema.prisma` con los modelos traducidos del esquema
   actual.
3. Decidir si Prisma será la fuente de verdad o si se leerá el esquema SQL
   existente.
4. Generar la migración inicial y revisar el SQL generado.
5. Crear `node/src/config/prisma.js`.
6. Implementar las consultas en `node/src/models/comisiones.model.js`.
7. Adaptar los controladores para usar `async/await` y pasar datos reales a las
   vistas.
8. Completar las vistas EJS con los datos recibidos.
9. Añadir `DATABASE_URL` a `.env.example`, `.env` y `docker-compose.yml`.
10. Actualizar `node/Dockerfile` para copiar `prisma/` y generar el cliente.
11. Decidir cómo se aplican las migraciones en Docker.
12. Probar el flujo completo: listado, detalle, alta y cambio de estado.
13. Actualizar este README con la implementación real.

Estado actual: **Prisma no está instalado, no hay archivos de Prisma creados y
el código Node sigue usando `pg` solo como configuración preparada, sin consultas
reales.**
