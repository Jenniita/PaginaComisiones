CREATE TABLE estados_comision (
    id     SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL UNIQUE
);

CREATE TABLE usuarios (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(120) NOT NULL,
    email         VARCHAR(180) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    rol           VARCHAR(20) NOT NULL DEFAULT 'cliente'
                  CHECK (rol IN ('cliente', 'artista', 'admin')),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

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

CREATE TABLE tipos_comision (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    precio_base NUMERIC(10, 2) NOT NULL DEFAULT 0
                CHECK (precio_base >= 0),
    activo      BOOLEAN NOT NULL DEFAULT TRUE
);

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

CREATE TABLE archivos_comision (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    comision_id BIGINT NOT NULL REFERENCES comisiones(id) ON DELETE CASCADE,
    url         VARCHAR(500) NOT NULL,
    tipo        VARCHAR(20) NOT NULL DEFAULT 'entrega'
                CHECK (tipo IN ('referencia', 'entrega')),
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

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
