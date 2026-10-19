# Restricciones

Documento de restricciones de la base de datos, reglas de validación y límites
operativos del proyecto de comisiones de dibujos. Complementa
`docs/base-de-datos.md`.

## 1. Restricciones de PostgreSQL

### 1.1 Claves primarias

Todas las tablas tienen una clave primaria autogenerada:

| Tabla | Clave primaria |
| ----- | -------------- |
| `estados_comision` | `id SMALLINT GENERATED ALWAYS AS IDENTITY` |
| `usuarios` | `id BIGINT GENERATED ALWAYS AS IDENTITY` |
| `artistas` | `id BIGINT GENERATED ALWAYS AS IDENTITY` |
| `tipos_comision` | `id BIGINT GENERATED ALWAYS AS IDENTITY` |
| `comisiones` | `id BIGINT GENERATED ALWAYS AS IDENTITY` |
| `archivos_comision` | `id BIGINT GENERATED ALWAYS AS IDENTITY` |
| `pagos` | `id BIGINT GENERATED ALWAYS AS IDENTITY` |

`GENERATED ALWAYS` impide asignar manualmente un `id`; PostgreSQL lo genera.

### 1.2 Valores obligatorios

Estas columnas no admiten `NULL`:

- `estados_comision.nombre`.
- `usuarios.nombre`, `email`, `password_hash`, `rol`, `creado_en`.
- `artistas.usuario_id`, `nombre_artistico`, `disponible`, `creado_en`.
- `tipos_comision.nombre`, `precio_base`, `activo`.
- `comisiones.cliente_id`, `artista_id`, `tipo_id`, `estado_id`, `titulo`,
  `descripcion`, `precio_acordado`, `creado_en`, `actualizado_en`.
- `archivos_comision.comision_id`, `url`, `tipo`, `creado_en`.
- `pagos.comision_id`, `monto`, `estado`, `creado_en`.

Son opcionales:

- `artistas.biografia`, `artistas.portafolio_url`.
- `tipos_comision.descripcion`.
- `comisiones.referencias`, `comisiones.fecha_entrega`.
- `pagos.metodo`.

### 1.3 Unicidad

| Tabla | Columna | Motivo |
| ----- | ------- | ------ |
| `estados_comision` | `nombre` | No repetir estados |
| `usuarios` | `email` | Un correo por usuario |
| `artistas` | `usuario_id` | Un perfil de artista por usuario |
| `tipos_comision` | `nombre` | No repetir tipos |

### 1.4 Comprobaciones (`CHECK`)

| Tabla | Columna | Regla |
| ----- | ------- | ----- |
| `usuarios` | `rol` | Solo `cliente`, `artista` o `admin` |
| `tipos_comision` | `precio_base` | Debe ser `>= 0` |
| `comisiones` | `precio_acordado` | Debe ser `>= 0` |
| `archivos_comision` | `tipo` | Solo `referencia` o `entrega` |
| `pagos` | `monto` | Debe ser `> 0` |
| `pagos` | `estado` | Solo `pendiente`, `pagado` o `reembolsado` |

### 1.5 Claves foráneas e integridad referencial

| Tabla | Columna | Referencia | Al borrar |
| ----- | ------- | ---------- | --------- |
| `artistas` | `usuario_id` | `usuarios.id` | `CASCADE` |
| `comisiones` | `cliente_id` | `usuarios.id` | Restringido |
| `comisiones` | `artista_id` | `artistas.id` | Restringido |
| `comisiones` | `tipo_id` | `tipos_comision.id` | Restringido |
| `comisiones` | `estado_id` | `estados_comision.id` | Restringido |
| `archivos_comision` | `comision_id` | `comisiones.id` | `CASCADE` |
| `pagos` | `comision_id` | `comisiones.id` | `CASCADE` |

Consecuencias:

- No se puede crear una comisión con un cliente, artista, tipo o estado
  inexistente.
- No se puede borrar un usuario con comisiones como cliente.
- No se puede borrar un artista con comisiones.
- No se puede borrar un tipo o estado en uso.
- Si se borra un usuario artista, el `CASCADE` intenta borrar su perfil; si ese
  artista tiene comisiones, la clave foránea de `comisiones.artista_id` impide
  el borrado y la operación completa falla.
- Si se borra una comisión, se borran sus archivos y pagos.

### 1.6 Índices

Los índices no son restricciones, pero condicionan el rendimiento:

- `idx_comisiones_cliente`.
- `idx_comisiones_artista`.
- `idx_comisiones_estado`.
- `idx_comisiones_fecha`.

## 2. Reglas de validación en la aplicación

Además de las restricciones de PostgreSQL, el servidor debe validar antes de
insertar o actualizar:

### 2.1 Comisiones

- `titulo`: obligatorio, entre 1 y 160 caracteres.
- `descripcion`: obligatoria.
- `cliente_id`, `artista_id`, `tipo_id`, `estado_id`: obligatorios y existentes.
- `precio_acordado`: obligatorio, numérico, mayor o igual que cero.
- `fecha_entrega`: opcional, fecha válida y no anterior a hoy al crear.
- `referencias`: opcional, texto razonable.
- `actualizado_en`: se actualiza en cada cambio.

### 2.2 Usuarios

- `nombre`: obligatorio.
- `email`: obligatorio, formato válido y único.
- `password_hash`: obligatorio; la contraseña original nunca se guarda en
  texto plano.
- `rol`: solo uno de los valores permitidos.

### 2.3 Artistas

- `usuario_id`: obligatorio y único.
- `nombre_artistico`: obligatorio.
- `precio_base` de los tipos: no negativo.
- `disponible`: booleano.

### 2.4 Archivos y pagos

- `url`: obligatoria.
- `tipo`: solo `referencia` o `entrega`.
- `monto`: mayor que cero.
- `estado`: solo `pendiente`, `pagado` o `reembolsado`.
- No registrar pagos negativos ni duplicados sin control.

## 3. Restricciones de seguridad

- No versionar `.env` ni credenciales reales.
- No exponer PostgreSQL al navegador; solo Node y PHP hablan con la base de
  datos.
- Usar consultas preparadas en Node (`pg` o Prisma) y en PHP (PDO).
- Escapar la salida en EJS con `<%= %>` y en PHP con `htmlspecialchars`.
- No confiar en la validación del navegador; repetirla en el servidor.
- Aplicar el principio de mínimo privilegio al usuario de PostgreSQL.
- No mostrar errores internos ni trazas al usuario final.
- No ejecutar contenedores como root cuando sea posible.
- No usar `prisma migrate reset` ni `db push` en producción.

## 4. Restricciones operativas de Docker

- Los scripts de `database/init/` solo se ejecutan cuando el volumen
  `postgres_data` se crea por primera vez.
- Si se cambia el esquema y el volumen ya existe, hay que crear una migración o
  reinicializar con `docker compose down --volumes`.
- `docker compose down --volumes` borra todos los datos de PostgreSQL.
- Node y PHP esperan a que `db` esté sana gracias al `healthcheck`.
- El host de la base de datos dentro de Docker es `db`, no `localhost`.
- Los puertos publicados son solo para desarrollo: 3000, 8000 y 5432.
- Las credenciales de `.env.example` son de ejemplo y no deben usarse en
  producción.

## 5. Restricciones del flujo de pantallas

- No se permite JavaScript de cliente para pedir o renderizar datos.
- Las pantallas deben recibir HTML completo del servidor.
- Los formularios deben usar `POST` y seguir POST / Redirect / GET.
- Si hay errores de validación, se vuelve a renderizar la misma pantalla.
- Las rutas desconocidas deben devolver HTTP 404.
- Los errores internos deben devolver HTTP 500 y una página amigable.

## 6. Pendiente

- Implementar las validaciones en los controladores.
- Completar el seed con datos válidos que respeten las restricciones.
- Definir la autenticación y el control de acceso por rol.
- Decidir si las reglas de negocio se aplicarán también con Prisma.
- Añadir pruebas que verifiquen las restricciones y los borrados.
