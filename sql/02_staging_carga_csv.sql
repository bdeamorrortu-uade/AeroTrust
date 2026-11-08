-- =====================================================================
-- 02. Staging: carga cruda del CSV
-- ---------------------------------------------------------------------
-- Capa de "Ingesta" de la arquitectura. La tabla replica las 35
-- columnas del CSV de Kaggle (BTS On-Time Performance 2024), todas como
-- TEXT, para que la carga nunca falle por formato. La conversión de
-- tipos y la validación se hacen después, con SQL (scripts 03 y 04).
--
-- Esta tabla NO está normalizada a propósito: es la copia fiel de la
-- fuente (punto de partida de la normalización).
-- =====================================================================

DROP TABLE IF EXISTS staging.vuelos_raw;

CREATE TABLE staging.vuelos_raw (
    year                 TEXT,
    month                TEXT,
    day_of_month         TEXT,
    day_of_week          TEXT,
    fl_date              TEXT,
    op_unique_carrier    TEXT,
    op_carrier_fl_num    TEXT,
    origin               TEXT,
    origin_city_name     TEXT,
    origin_state_nm      TEXT,
    dest                 TEXT,
    dest_city_name       TEXT,
    dest_state_nm        TEXT,
    crs_dep_time         TEXT,
    dep_time             TEXT,
    dep_delay            TEXT,
    taxi_out             TEXT,
    wheels_off           TEXT,
    wheels_on            TEXT,
    taxi_in              TEXT,
    crs_arr_time         TEXT,
    arr_time             TEXT,
    arr_delay            TEXT,
    cancelled            TEXT,
    cancellation_code    TEXT,
    diverted             TEXT,
    crs_elapsed_time     TEXT,
    actual_elapsed_time  TEXT,
    air_time             TEXT,
    distance             TEXT,
    carrier_delay        TEXT,
    weather_delay        TEXT,
    nas_delay            TEXT,
    security_delay       TEXT,
    late_aircraft_delay  TEXT
);

-- Carga del archivo. \copy es un comando de psql: lee el archivo desde
-- la PC del cliente, así que la ruta es relativa a la carpeta desde
-- donde se ejecuta psql (la raíz del proyecto).
--
-- En pgAdmin: clic derecho sobre staging.vuelos_raw > Import/Export Data,
-- formato CSV, Header = Yes, y elegir data/flight_data_2024_sample.csv.
\copy staging.vuelos_raw FROM 'data/flight_data_2024_sample.csv' WITH (FORMAT csv, HEADER true)

-- Control: cantidad de filas cargadas (la muestra tiene 10.000).
SELECT COUNT(*) AS filas_en_staging FROM staging.vuelos_raw;
