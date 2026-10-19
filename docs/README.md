# Trabajo Comisiones

Aplicación web de comisiones de dibujos con dos interfaces independientes
(Node.js y PHP) que comparten PostgreSQL y se ejecutan con Docker Compose.

La idea central es el **renderizado en el servidor**: el navegador pide una
página, el servidor consulta la base de datos, mezcla los datos con una
plantilla y devuelve el HTML completo. No hay JavaScript de cliente que pida
datos después de cargar la página.

Documentación complementaria:

- [`base-de-datos.md`](base-de-datos.md): modelo de datos y diccionario completo.
- [`rutas.md`](rutas.md): endpoints y pantallas de Node y PHP.
- [`restricciones.md`](restricciones.md): restricciones SQL, validaciones y
  seguridad.

## 1. Arquitectura

```text
Navegador
   |
   +--> http://localhost:3000 --> Node.js + Express + EJS --+
   |                                                        |
   +--> http://localhost:8000 --> PHP + Apache + PDO -------+--> PostgreSQL
                                                            |
                                                     volumen postgres_data
```

| Servicio | Imagen | Puerto host | Puerto interno | Función |
| -------- | ------ | ----------- | -------------- | ------- |
| `node` | `node:22-alpine` | 3000 | 3000 | Interfaz principal con EJS |
| `php` | `php:8.3-apache` | 8000 | 80 | Interfaz PHP |
| `db` | `postgres:16` | 5432 | 5432 | Base de datos compartida |

Node y PHP hablan con PostgreSQL usando el host interno `db`. El navegador nunca
se conecta a la base de datos.

## 2. Flujo de renderizado en el servidor

```text
1. Navegador: GET /comisiones
2. Servidor: enruta la petición al controlador
3. Controlador: pide los datos al modelo
4. Modelo: ejecuta SQL contra PostgreSQL
5. PostgreSQL: devuelve las filas
6. Servidor: mezcla datos + plantilla y genera HTML
7. Navegador: recibe y pinta el HTML completo
```

Ejemplo en Node.js:

```js
const comisiones = await comisionesModel.listarTodas();
res.render('comisiones/index.ejs', { titulo: 'Comisiones', comisiones });
```

Ejemplo en PHP:

```php
$comisiones = $comisionModel->listarTodas();
require __DIR__ . '/../templates/comisiones/index.php';
```

Qué implica:

- No se usa `fetch`, AJAX, `XMLHttpRequest` ni una API JSON para cargar datos.
- No hay React, Vue ni SPA.
- Los formularios usan `POST` normal.
- Cada navegación devuelve una página HTML nueva y completa.
- La seguridad y la validación se concentran en el servidor.

### Formularios: POST / Redirect / GET

1. `GET /comisiones/nueva` muestra el formulario HTML.
2. El usuario lo envía con `POST /comisiones`.
3. El servidor valida e inserta.
4. Si hay errores, vuelve a renderizar el formulario con los mensajes.
5. Si todo es correcto, responde `303` a `/comisiones/:id`.
6. El navegador hace `GET /comisiones/:id` y recibe el detalle en HTML.

Esto evita duplicados al recargar y no necesita JavaScript.

## 3. Estructura del proyecto

```text
TrabajoComisiones/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── .dockerignore
├── docs/
│   ├── README.md
│   ├── base-de-datos.md
│   ├── rutas.md
│   └── restricciones.md
├── database/
│   └── init/
│       ├── 001-schema.sql
│       └── 002-seed.sql
├── node/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   ├── package-lock.json
│   └── src/
│       ├── app.js
│       ├── server.js
│       ├── config/
│       │   └── db.js
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
│       │   │   ├── index.ejs
│       │   │   ├── show.ejs
│       │   │   └── form.ejs
│       │   ├── error.ejs
│       │   └── 404.ejs
│       └── public/
│           ├── css/styles.css
│           └── img/
└── php/
    ├── Dockerfile
    ├── .dockerignore
    ├── public/
    │   ├── index.php
    │   └── css/styles.css
    ├── src/
    │   ├── Config/
    │   │   └── Database.php
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

Archivos de soporte no incluidos en el árbol:

- `php/public/.htaccess`: reescritura de URLs hacia `index.php`.
- `node/src/public/img/.gitkeep`: mantiene la carpeta vacía en Git.
- `opencode.json`: configuración de la herramienta de desarrollo.

### Función de los archivos principales

| Archivo | Función |
| ------- | ------- |
| `docker-compose.yml` | Define y conecta Node, PHP y PostgreSQL |
| `.env.example` | Plantilla de variables de entorno |
| `database/init/001-schema.sql` | Crea tablas, restricciones e índices |
| `database/init/002-seed.sql` | Datos iniciales (vacío por ahora) |
| `node/Dockerfile` | Imagen de Node.js |
| `node/package.json` | Dependencias y comando de arranque |
| `node/src/server.js` | Arranca el servidor HTTP |
| `node/src/app.js` | Configura Express, EJS, estáticos y rutas |
| `node/src/config/db.js` | Pool de conexiones de PostgreSQL |
| `node/src/routes/*.js` | Asocian URLs con controladores |
| `node/src/controllers/*.js` | Preparan los datos y eligen la vista |
| `node/src/models/*.js` | Consultas SQL (pendiente) |
| `node/src/middlewares/error.middleware.js` | Errores HTTP 500 |
| `node/src/views/**/*.ejs` | Plantillas HTML |
| `node/src/public/**` | CSS e imágenes |
| `php/Dockerfile` | Imagen de PHP con Apache y `pdo_pgsql` |
| `php/public/.htaccess` | URLs limpias |
| `php/public/index.php` | Front controller de PHP |
| `php/src/Config/Database.php` | Conexión PDO |
| `php/src/Controllers/ComisionController.php` | Carga las plantillas |
| `php/src/Models/Comision.php` | Acceso a datos (pendiente) |
| `php/templates/**` | Plantillas HTML de PHP |
| `docs/*.md` | Documentación del proyecto |

## 4. Node.js con EJS

- Node.js 22, Express, EJS y `pg`.
- `npm start` ejecuta `node src/server.js`.
- `app.js` monta las rutas, sirve `src/public` y configurar el motor EJS.
- Las vistas están en `src/views` y los estáticos en `src/public`.
- No hay JavaScript de cliente para datos.

### Rutas

| Método | Ruta | Controlador | Vista / resultado |
| ------ | ---- | ----------- | ----------------- |
| `GET` | `/` | `home.index` | `home.ejs` |
| `GET` | `/health` | `home.health` | `{"status":"ok"}` |
| `GET` | `/comisiones` | `comisiones.listar` | `comisiones/index.ejs` |
| `GET` | `/comisiones/nueva` | `comisiones.formulario` | `comisiones/form.ejs` |
| `POST` | `/comisiones` | `comisiones.crear` | Redirect |
| `GET` | `/comisiones/:id` | `comisiones.detalle` | `comisiones/show.ejs` |
| `GET` | `/comisiones/:id/editar` | `comisiones.editar` | `comisiones/form.ejs` |
| `POST` | `/comisiones/:id` | `comisiones.actualizar` | Redirect |
| `POST` | `/comisiones/:id/estado` | `comisiones.cambiarEstado` | Redirect |

El detalle completo de pantallas está en [`rutas.md`](rutas.md).

## 5. PHP con Apache

- PHP 8.3 con Apache y PDO PostgreSQL.
- Front controller en `public/index.php`; `src` y `templates` quedan fuera del
  DocumentRoot.
- `.htaccess` reescribe las URLs limpias hacia `index.php`.
- Sin framework y sin JavaScript de cliente.

### Rutas

| Método | Ruta | Resultado |
| ------ | ---- | --------- |
| `GET` | `/` | Inicio |
| `GET` | `/health` | `{"status":"ok"}` |
| `GET` | `/comisiones` | Listado |
| `GET` | `/comisiones/{id}` | Detalle |
| `GET` | `/comisiones/nueva` | Pendiente |
| `POST` | `/comisiones` | Pendiente |
| `POST` | `/comisiones/{id}/estado` | Pendiente |

## 6. Base de datos PostgreSQL

Base de datos `comisiones`, creada con los scripts de `database/init/`.

| Tabla | Contenido |
| ----- | --------- |
| `estados_comision` | Estados: pendiente, en_proceso, entregada, cancelada |
| `usuarios` | Clientes, artistas y administradores |
| `artistas` | Perfil artístico, uno por usuario artista |
| `tipos_comision` | Catálogo de tipos de encargo |
| `comisiones` | Encargos: cliente, artista, tipo, estado y precio |
| `archivos_comision` | Referencias y entregas |
| `pagos` | Pagos asociados a una comisión |

Relaciones principales:

- `usuarios` 1:1 `artistas`.
- `usuarios` 1:N `comisiones` como cliente.
- `artistas` 1:N `comisiones`.
- `comisiones` N:1 `tipos_comision` y `estados_comision`.
- `comisiones` 1:N `archivos_comision` y `pagos`.

Restricciones destacadas:

- Claves primarias autogeneradas.
- `email`, `nombre` de estado y tipo, y `usuario_id` de artista son únicos.
- `rol`, precios, tipos de archivo y estados de pago tienen `CHECK`.
- Las claves foráneas protegen la integridad referencial.
- Borrar una comisión borra sus archivos y pagos.
- No se puede borrar un cliente, artista, tipo o estado en uso.

Los scripts de inicialización solo se ejecutan la primera vez que se crea el
volumen. Para reinicializar:

```sh
docker compose down --volumes
docker compose up --build
```

El diccionario completo está en [`base-de-datos.md`](base-de-datos.md), las
restricciones en [`restricciones.md`](restricciones.md) y el SQL en
`database/init/001-schema.sql`.

## 7. Docker Compose

- `node`: construye desde `./node`, publica `${APP_PORT:-3000}` y espera a que
  la base de datos esté sana.
- `php`: construye desde `./php`, publica `${PHP_PORT:-8000}` y espera a la base
  de datos.
- `db`: PostgreSQL 16, volumen `postgres_data`, healthcheck con `pg_isready` y
  scripts de `database/init/` montados en modo lectura.

Variables de `.env.example`:

```dotenv
APP_PORT=3000
PHP_PORT=8000
POSTGRES_DB=comisiones
POSTGRES_USER=comisiones
POSTGRES_PASSWORD=comisiones_dev
POSTGRES_PORT=5432
```

Copia el ejemplo y arranca:

```sh
cp .env.example .env
docker compose up --build
```

Comandos útiles:

```sh
docker compose up -d --build     # segundo plano
docker compose logs -f node      # logs
docker compose down              # parar
docker compose down --volumes    # borrar también los datos
```

URLs:

- Node.js: <http://localhost:3000>
- PHP: <http://localhost:8000>
- PostgreSQL: `localhost:5432` (solo desarrollo)

## 8. ORM con Prisma (pendiente)

Prisma es un ORM para Node.js que traduce objetos JavaScript a SQL. No está
instalado todavía.

Piezas:

| Pieza | Función |
| ----- | ------- |
| `prisma/schema.prisma` | Modelos, relaciones y datasource |
| Prisma CLI (`prisma`) | Migraciones, generación del cliente y Studio |
| Prisma Client (`@prisma/client`) | Consultas desde el código Node |
| PostgreSQL | Base de datos real |

Flujo de desarrollo:

```sh
npx prisma migrate dev --name cambio   # crear y aplicar migración
npx prisma generate                    # actualizar Prisma Client
npx prisma migrate deploy              # aplicar migraciones en Docker
```

En ejecución:

```text
Controlador -> Prisma Client -> SQL -> PostgreSQL
            <- objetos JS <- filas
Controlador -> res.render(...) -> HTML completo
```

Conexión mediante una variable `DATABASE_URL`:

```dotenv
DATABASE_URL=postgresql://comisiones:comisiones_dev@db:5432/comisiones?schema=public
```

Ejemplo de modelo:

```prisma
model Comision {
  id             BigInt   @id @default(autoincrement())
  titulo         String   @db.VarChar(160)
  precioAcordado Decimal  @map("precio_acordado") @db.Decimal(10, 2)
  creadoEn       DateTime @default(now()) @map("creado_en") @db.Timestamptz()

  @@map("comisiones")
}
```

Ejemplo de consulta:

```js
const comisiones = await prisma.comision.findMany({
  include: { artista: true, tipo: true },
  orderBy: { creadoEn: 'desc' },
});
```

Cambios previstos:

- Añadir `prisma` y `@prisma/client` a `node/package.json`.
- Crear `prisma/schema.prisma` y `prisma/migrations/`.
- Sustituir `config/db.js` por `config/prisma.js`.
- Implementar las consultas en `models/comisiones.model.js`.
- Añadir `DATABASE_URL` al entorno y al `docker-compose.yml`.
- Copiar `prisma/` y generar el cliente en el Dockerfile.
- Decidir si Prisma o `database/init/001-schema.sql` es la fuente de verdad;
  no deben crear las mismas tablas a la vez.
- Aplicar migraciones con `prisma migrate deploy` antes de arrancar Node.

Ventajas: menos SQL repetitivo, relaciones claras, migraciones versionadas y
consultas parametrizadas. Inconvenientes: dependencia adicional, paso de
generación, disciplina de migraciones y necesidad de entender el SQL generado.

Lo que no cambia: el navegador sigue recibiendo HTML del servidor, sin
JavaScript de cliente y sin JSON de datos. PHP sigue usando PDO.

## 9. Seguridad

- No versionar `.env` ni credenciales reales.
- Escapar la salida en EJS con `<%= %>` y en PHP con `htmlspecialchars`.
- Usar consultas preparadas y validar en el servidor.
- No exponer PostgreSQL al navegador.
- Aplicar mínimo privilegio al usuario de base de datos.
- No mostrar errores internos al usuario.
- No ejecutar contenedores como root cuando sea posible.
- No usar `prisma migrate reset` ni `db push` en producción.

## 10. Estado actual y siguientes pasos

Estado actual:

- Estructura y contenedores montados y probados.
- Node.js con Express + EJS y PHP con front controller.
- PostgreSQL con el esquema de comisiones creado.
- `002-seed.sql` vacío.
- Vistas y controladores son placeholders; no hay consultas reales.
- Prisma no está instalado.

Siguientes pasos:

1. Completar `002-seed.sql`.
2. Implementar las consultas de Node (con Prisma) y PHP (con PDO).
3. Completar listados, detalles y formularios.
4. Añadir estilos y validaciones.
5. Implementar autenticación y control de acceso por rol.
6. Actualizar la documentación con el resultado final.
