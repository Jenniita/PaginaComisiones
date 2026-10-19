# Trabajo Comisiones

Documentación inicial del proyecto. Aquí se irán registrando las decisiones,
la configuración y la evolución de la aplicación.

## Tecnologías

- Node.js con la imagen `node:latest`.
- PHP con Apache y la imagen `php:apache`.
- PostgreSQL con la imagen `postgres:latest`.
- Docker Compose para ejecutar los tres servicios.

## Requisitos

- Docker Desktop (o Docker Engine) con Docker Compose.

## Configuración y arranque

1. Copia `.env.example` a `.env` y cambia la contraseña de PostgreSQL si el
   entorno no es únicamente local.
2. Desde la raíz del proyecto, ejecuta:

   ```sh
   docker compose up --build
   ```

3. Abre <http://localhost:3000> para Node.js o <http://localhost:8000> para
   PHP.
4. La ruta <http://localhost:3000/health> devuelve el estado del servidor
   Node.js.

Para detener los contenedores, pulsa `Ctrl+C` o ejecuta
`docker compose down`. Los datos de PostgreSQL se conservan en el volumen
`postgres_data`. Para eliminar también esos datos, ejecuta
`docker compose down --volumes`.

## Base de datos

La base de datos inicial se llama `comisiones`. Al inicializar por primera vez
el volumen, PostgreSQL ejecuta los scripts de `database/init/`.

Se crea la tabla `registros`, vacía de filas, con un identificador autogenerado
y una fecha de creación. La estructura está pensada como punto de partida y se
podrá adaptar cuando se definan los datos del proyecto. Los scripts de
inicialización solo se ejecutan al crear un volumen de datos nuevo.

Los valores de `.env.example` son únicamente para desarrollo local; no deben
usarse como credenciales de producción.

El servicio PHP incluye la extensión PDO PostgreSQL y recibe la configuración
de conexión mediante las variables `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`
y `DB_PASSWORD`. Dentro de Docker, el host de la base de datos es `db`.

## Estructura del proyecto

- `node/`: servidor Node.js, página HTML, `package.json` e imagen Docker.
- `php/`: aplicación PHP servida por Apache y su imagen Docker.
- `docker-compose.yml`: servicios de Node.js, PHP y PostgreSQL.
- `database/init/`: scripts de inicialización de la base de datos.
- `docs/README.md`: documentación del proyecto.
