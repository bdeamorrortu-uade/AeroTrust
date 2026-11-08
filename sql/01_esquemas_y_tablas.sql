-- =====================================================================
-- AeroTrust Index - Ingeniería de Datos I - Grupo 2
-- 01. Esquemas, tablas y restricciones
-- ---------------------------------------------------------------------
-- Implementa el modelo de la Actividad 2 (6 entidades) normalizado
-- hasta 3FN, separado en los esquemas lógicos de la arquitectura:
--   operativo  -> aerolineas, rutas, vuelos
--   analitico  -> evaluacion_riesgo
--   financiero -> contratos_corporativos, polizas_seguro
--   staging    -> copia cruda del CSV (capa de Ingesta y validación)
--
-- ATENCIÓN: el script borra y vuelve a crear los esquemas para poder
-- ejecutarse varias veces desde cero.
-- =====================================================================

DROP SCHEMA IF EXISTS financiero CASCADE;
DROP SCHEMA IF EXISTS analitico  CASCADE;
DROP SCHEMA IF EXISTS operativo  CASCADE;
DROP SCHEMA IF EXISTS staging    CASCADE;

CREATE SCHEMA staging;
CREATE SCHEMA operativo;
CREATE SCHEMA analitico;
CREATE SCHEMA financiero;


-- ---------------------------------------------------------------------
-- DATOS MAESTROS
-- ---------------------------------------------------------------------

-- Una fila por aerolínea. El nombre depende solo del código IATA,
-- por eso vive acá y no en vuelos (3FN).
CREATE TABLE operativo.aerolineas (
    id_aerolinea      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo_iata       CHAR(2)      NOT NULL UNIQUE,
    nombre            VARCHAR(100) NOT NULL,
    pais_jurisdiccion VARCHAR(60)  NOT NULL
);

-- Una fila por par origen-destino. La distancia depende solo del par
-- (origen, destino), que es clave candidata (2FN / 3FN).
-- No se guardan ciudad ni estado del aeropuerto: dependen del aeropuerto
-- y no de la ruta (serían una dependencia transitiva).
CREATE TABLE operativo.rutas (
    id_ruta            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    aeropuerto_origen  CHAR(3) NOT NULL,
    aeropuerto_destino CHAR(3) NOT NULL,
    distancia_km       INT     CHECK (distancia_km > 0),
    CONSTRAINT uq_rutas_origen_destino UNIQUE (aeropuerto_origen, aeropuerto_destino),
    CONSTRAINT ck_rutas_distintos CHECK (aeropuerto_origen <> aeropuerto_destino)
);


-- ---------------------------------------------------------------------
-- OPERATIVO
-- ---------------------------------------------------------------------

-- Un vuelo concreto (una fila del dataset).
-- demora_min y estado son una redundancia controlada: vienen de la
-- fuente (dep_delay, cancelled) y se guardan para no recalcularlos.
CREATE TABLE operativo.vuelos (
    id_vuelo              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aerolinea          INT NOT NULL
        REFERENCES operativo.aerolineas (id_aerolinea) ON DELETE RESTRICT,
    id_ruta               INT NOT NULL
        REFERENCES operativo.rutas (id_ruta) ON DELETE RESTRICT,
    nro_vuelo             VARCHAR(10) NOT NULL,
    fecha_hora_programada TIMESTAMP   NOT NULL,
    fecha_hora_real       TIMESTAMP,              -- NULL si se canceló
    demora_min            INT,                    -- NULL si se canceló; negativo = adelantado
    estado                VARCHAR(10) NOT NULL
        CHECK (estado IN ('On-Time', 'Delayed', 'Cancelled')),
    -- Evita cargar dos veces el mismo vuelo (deduplicación).
    CONSTRAINT uq_vuelos_natural UNIQUE (id_aerolinea, nro_vuelo, fecha_hora_programada),
    -- Un vuelo cancelado no tiene hora real ni demora; uno no cancelado sí.
    CONSTRAINT ck_vuelos_cancelado CHECK (
        (estado =  'Cancelled' AND fecha_hora_real IS NULL     AND demora_min IS NULL) OR
        (estado <> 'Cancelled' AND fecha_hora_real IS NOT NULL AND demora_min IS NOT NULL)
    )
);

-- Índice compuesto definido en la Actividad 2 para acelerar las
-- agregaciones del índice de confiabilidad (aerolínea + ruta + fecha).
CREATE INDEX ix_vuelos_aerolinea_ruta_fecha
    ON operativo.vuelos (id_aerolinea, id_ruta, fecha_hora_programada);


-- ---------------------------------------------------------------------
-- ANALÍTICO
-- ---------------------------------------------------------------------

-- Resumen por aerolínea + ruta + franja horaria en una fecha de cálculo.
-- Es una desnormalización intencional: se guarda la "foto" del riesgo
-- para que cada póliza registre el riesgo vigente al emitirse.
CREATE TABLE analitico.evaluacion_riesgo (
    id_evaluacion         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aerolinea          INT NOT NULL
        REFERENCES operativo.aerolineas (id_aerolinea) ON DELETE RESTRICT,
    id_ruta               INT NOT NULL
        REFERENCES operativo.rutas (id_ruta) ON DELETE RESTRICT,
    franja_horaria        VARCHAR(10)  NOT NULL
        CHECK (franja_horaria IN ('Mañana', 'Tarde', 'Noche')),
    total_vuelos          INT          NOT NULL CHECK (total_vuelos > 0),
    tasa_demora           NUMERIC(5,4) NOT NULL CHECK (tasa_demora BETWEEN 0 AND 1),
    tasa_cancelacion      NUMERIC(5,4) NOT NULL CHECK (tasa_cancelacion BETWEEN 0 AND 1),
    indice_confiabilidad  NUMERIC(5,2) NOT NULL CHECK (indice_confiabilidad BETWEEN 0 AND 100),
    fecha_calculo         DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_evaluacion UNIQUE (id_aerolinea, id_ruta, franja_horaria, fecha_calculo)
);


-- ---------------------------------------------------------------------
-- FINANCIERO
-- ---------------------------------------------------------------------

-- Cliente corporativo. umbral_sla_min es la demora (en minutos) a partir
-- de la cual se activa la indemnización de todas sus pólizas.
CREATE TABLE financiero.contratos_corporativos (
    id_contrato     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    razon_social    VARCHAR(150) NOT NULL,
    cuit            VARCHAR(13)  NOT NULL UNIQUE,     -- formato 30-12345678-9
    fecha_inicio    DATE         NOT NULL,
    fecha_fin       DATE         NOT NULL,
    nivel_cobertura VARCHAR(10)  NOT NULL
        CHECK (nivel_cobertura IN ('Básico', 'Estándar', 'Premium')),
    umbral_sla_min  INT          NOT NULL CHECK (umbral_sla_min > 0),
    estado          VARCHAR(10)  NOT NULL
        CHECK (estado IN ('Activo', 'Vencido', 'Suspendido')),
    CONSTRAINT ck_contrato_fechas CHECK (fecha_fin > fecha_inicio)
);

-- Seguro paramétrico sobre un vuelo concreto.
-- El umbral de demora NO se repite acá: se toma del contrato
-- (evita una dependencia transitiva id_poliza -> id_contrato -> umbral).
CREATE TABLE financiero.polizas_seguro (
    id_poliza           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_contrato         INT    NOT NULL
        REFERENCES financiero.contratos_corporativos (id_contrato) ON DELETE RESTRICT,
    id_vuelo            BIGINT NOT NULL
        REFERENCES operativo.vuelos (id_vuelo) ON DELETE RESTRICT,
    id_evaluacion       BIGINT NOT NULL
        REFERENCES analitico.evaluacion_riesgo (id_evaluacion) ON DELETE RESTRICT,
    prima               NUMERIC(10,2) NOT NULL CHECK (prima > 0),
    monto_indemnizacion NUMERIC(10,2) NOT NULL CHECK (monto_indemnizacion > 0),
    estado_liquidacion  VARCHAR(15)   NOT NULL DEFAULT 'Pendiente'
        CHECK (estado_liquidacion IN ('Pendiente', 'Liquidada', 'No corresponde')),
    fecha_liquidacion   TIMESTAMP,
    -- Impide emitir (y por lo tanto liquidar) dos veces la misma cobertura.
    CONSTRAINT uq_poliza_contrato_vuelo UNIQUE (id_contrato, id_vuelo),
    -- Solo una póliza liquidada tiene fecha de liquidación.
    CONSTRAINT ck_poliza_liquidacion CHECK (
        (estado_liquidacion = 'Liquidada') = (fecha_liquidacion IS NOT NULL)
    )
);
