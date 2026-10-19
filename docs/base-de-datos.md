# Base de datos

Documento de ampliación del modelo de datos del proyecto de comisiones de
dibujos. Complementa la sección 7 de `docs/README.md`.

## 1. Propósito

Describir qué datos guarda la aplicación, cómo se relacionan las tablas, qué
tipos y restricciones tiene cada columna y cómo se inicializa PostgreSQL.

## 2. Estado actual

- Motor: PostgreSQL 16.
- Base de datos: `comisiones`.
- Usuario de aplicación: `comisiones`.
- Esquema creado por: `database/init/001-schema.sql`.
- Datos iniciales: `database/init/002-seed.sql` está vacío.
- El esquema se aplica solo la primera vez que se crea el volumen
  `postgres_data`.
- Todavía no hay consultas reales desde Node ni desde PHP.
- Prisma no está instalado; el esquema SQL es la fuente de verdad actual.

## 3. Archivos relacionados

| Archivo | Función |
| ------- | ------- |
| `database/init/001-schema.sql` | Crea tablas, claves, restricciones e índices |
| `database/init/002-seed.sql` | Insertará estados, tipos y datos de ejemplo (pendiente) |
| `docker-compose.yml` | Crea el contenedor `db` y monta `database/init/` |
| `node/src/config/db.js` | Pool de conexiones de Node (pendiente de usar) |
| `php/src/Config/Database.php` | Conexión PDO de PHP (pendiente de usar) |
| `docs/restricciones.md` | Detalle de restricciones y validaciones |

## 4. Modelo relacional

```text
usuarios
  | 1
  | 1
artistas
  | 1
  | N
comisiones N --- 1 tipos_comision
  | 1
  | N
archivos_comision

comisiones N --- 1 estados_comision
comisiones N --- 1 usuarios        (cliente)
comisiones 1 --- N pagos
```

En palabras:

- Un usuario puede ser cliente, artista o administrador.
- Un usuario artista tiene como máximo un perfil en `artistas`.
- Un cliente puede solicitar muchas comisiones.
- Un artista puede recibir muchas comisiones.
- Cada comisión tiene un tipo y un estado.
- Cada comisión puede tener varios archivos y varios pagos.

## 5. Diccionario de datos

### 5.1 `estados_comision`

Estados posibles de una comisión.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `SMALLINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `nombre` | `VARCHAR(30)` | `NOT NULL`, `UNIQUE` | Nombre del estado |

Valores previstos: `pendiente`, `en_proceso`, `entregada`, `cancelada`.

### 5.2 `usuarios`

Personas que usan la aplicación.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `nombre` | `VARCHAR(120)` | `NOT NULL` | Nombre visible |
| `email` | `VARCHAR(180)` | `NOT NULL`, `UNIQUE` | Correo de acceso |
| `password_hash` | `VARCHAR(255)` | `NOT NULL` | Contraseña cifrada |
| `rol` | `VARCHAR(20)` | `NOT NULL`, `CHECK`, por defecto `cliente` | Tipo de usuario |
| `creado_en` | `TIMESTAMPTZ` | `NOT NULL`, por defecto `CURRENT_TIMESTAMP` | Fecha de alta |

Valores permitidos en `rol`: `cliente`, `artista`, `admin`.

### 5.3 `artistas`

Perfil público de un usuario artista.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `usuario_id` | `BIGINT` | `NOT NULL`, `UNIQUE`, FK a `usuarios` | Usuario asociado |
| `nombre_artistico` | `VARCHAR(120)` | `NOT NULL` | Nombre público |
| `biografia` | `TEXT` | Opcional | Presentación |
| `portafolio_url` | `VARCHAR(500)` | Opcional | Enlace al portafolio |
| `disponible` | `BOOLEAN` | `NOT NULL`, por defecto `TRUE` | Si acepta encargos |
| `creado_en` | `TIMESTAMPTZ` | `NOT NULL`, por defecto `CURRENT_TIMESTAMP` | Fecha de alta |

La relación con `usuarios` es uno a uno. Si se borra el usuario, se borra el
perfil (`ON DELETE CASCADE`).

### 5.4 `tipos_comision`

Catálogo de tipos de encargo.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `nombre` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | Nombre del tipo |
| `descripcion` | `TEXT` | Opcional | Detalle |
| `precio_base` | `NUMERIC(10, 2)` | `NOT NULL`, por defecto `0`, `>= 0` | Precio orientativo |
| `activo` | `BOOLEAN` | `NOT NULL`, por defecto `TRUE` | Si se ofrece |

### 5.5 `comisiones`

Tabla central del proyecto.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `cliente_id` | `BIGINT` | `NOT NULL`, FK a `usuarios` | Quien encarga |
| `artista_id` | `BIGINT` | `NOT NULL`, FK a `artistas` | Quien dibuja |
| `tipo_id` | `BIGINT` | `NOT NULL`, FK a `tipos_comision` | Tipo de encargo |
| `estado_id` | `SMALLINT` | `NOT NULL`, FK a `estados_comision` | Estado actual |
| `titulo` | `VARCHAR(160)` | `NOT NULL` | Título breve |
| `descripcion` | `TEXT` | `NOT NULL` | Detalle del encargo |
| `referencias` | `TEXT` | Opcional | Enlaces o notas |
| `precio_acordado` | `NUMERIC(10, 2)` | `NOT NULL`, `>= 0` | Precio final |
| `fecha_entrega` | `DATE` | Opcional | Fecha prevista |
| `creado_en` | `TIMESTAMPTZ` | `NOT NULL`, por defecto `CURRENT_TIMESTAMP` | Alta |
| `actualizado_en` | `TIMESTAMPTZ` | `NOT NULL`, por defecto `CURRENT_TIMESTAMP` | Última modificación |

### 5.6 `archivos_comision`

Referencias y entregas asociadas a una comisión.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `comision_id` | `BIGINT` | `NOT NULL`, FK a `comisiones`, `ON DELETE CASCADE` | Comisión |
| `url` | `VARCHAR(500)` | `NOT NULL` | Enlace al archivo |
| `tipo` | `VARCHAR(20)` | `NOT NULL`, `CHECK`, por defecto `entrega` | Tipo de archivo |
| `creado_en` | `TIMESTAMPTZ` | `NOT NULL`, por defecto `CURRENT_TIMESTAMP` | Alta |

Valores permitidos en `tipo`: `referencia`, `entrega`.

### 5.7 `pagos`

Pagos registrados para una comisión.

| Columna | Tipo | Restricciones | Descripción |
| ------- | ---- | ------------- | ----------- |
| `id` | `BIGINT GENERATED ALWAYS AS IDENTITY` | Clave primaria | Identificador |
| `comision_id` | `BIGINT` | `NOT NULL`, FK a `comisiones`, `ON DELETE CASCADE` | Comisión |
| `monto` | `NUMERIC(10, 2)` | `NOT NULL`, `> 0` | Importe |
| `metodo` | `VARCHAR(40)` | Opcional | Forma de pago |
| `estado` | `VARCHAR(20)` | `NOT NULL`, `CHECK`, por defecto `pendiente` | Situación |
| `creado_en` | `TIMESTAMPTZ` | `NOT NULL`, por defecto `CURRENT_TIMESTAMP` | Alta |

Valores permitidos en `estado`: `pendiente`, `pagado`, `reembolsado`.

## 6. Relaciones y borrado

| Relación | Cardinalidad | Clave foránea | Borrado |
| -------- | ------------ | ------------- | ------- |
| `usuarios` - `artistas` | 1 a 1 | `artistas.usuario_id` | `CASCADE` |
| `usuarios` - `comisiones` | 1 a N | `comisiones.cliente_id` | Restringido |
| `artistas` - `comisiones` | 1 a N | `comisiones.artista_id` | Restringido |
| `tipos_comision` - `comisiones` | 1 a N | `comisiones.tipo_id` | Restringido |
| `estados_comision` - `comisiones` | 1 a N | `comisiones.estado_id` | Restringido |
| `comisiones` - `archivos_comision` | 1 a N | `archivos_comision.comision_id` | `CASCADE` |
| `comisiones` - `pagos` | 1 a N | `pagos.comision_id` | `CASCADE` |

"Restringido" significa que PostgreSQL impide borrar un usuario, artista, tipo
o estado que tenga comisiones asociadas. Esto protege el historial.

## 7. Índices

| Índice | Tabla | Columna | Uso |
| ------ | ----- | ------- | --- |
| `idx_comisiones_cliente` | `comisiones` | `cliente_id` | Buscar comisiones de un cliente |
| `idx_comisiones_artista` | `comisiones` | `artista_id` | Buscar comisiones de un artista |
| `idx_comisiones_estado` | `comisiones` | `estado_id` | Filtrar por estado |
| `idx_comisiones_fecha` | `comisiones` | `creado_en DESC` | Ordenar por más recientes |

## 8. Datos iniciales previstos

`002-seed.sql` está vacío. Cuando se complete, deberá insertar:

1. Los cuatro estados de `estados_comision`.
2. Varios tipos en `tipos_comision`: retrato, chibi e ilustración.
3. Un usuario administrador y un artista de demostración con contraseñas
   cifradas.
4. Opcionalmente, comisiones de ejemplo en distintos estados.

Los `INSERT` deben ser idempotentes o ejecutarse solo sobre una base de datos
recién creada.

## 9. Ciclo de vida de la base de datos

1. `docker compose up` crea el contenedor `db`.
2. Si el volumen `postgres_data` no existe, PostgreSQL lo inicializa.
3. Ejecuta en orden alfabético los scripts de `database/init/`.
4. `001-schema.sql` crea las tablas y los índices.
5. `002-seed.sql` no inserta nada porque está vacío.
6. El healthcheck `pg_isready` marca la base de datos como sana.
7. Node y PHP pueden conectarse usando el host `db`.

Para volver a ejecutar los scripts de inicialización:

```sh
docker compose down --volumes
docker compose up --build
```

Esto borra todos los datos existentes.

## 10. Restricciones

Las restricciones de columnas, claves foráneas, `CHECK`, unicidad, índices y
reglas de validación de la aplicación se detallan en
[`restricciones.md`](restricciones.md).

## 11. Pendiente

- Completar `002-seed.sql`.
- Implementar las consultas de Node y PHP.
- Decidir si Prisma será la fuente de verdad del esquema.
- Añadir autenticación y hash de contraseñas reales.
- Definir la política de borrado de usuarios y comisiones.
