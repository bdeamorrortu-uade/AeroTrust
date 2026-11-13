-- 02. Staging: copia cruda del CSV, todas las columnas como TEXT

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

-- En pgAdmin: Import/Export Data sobre staging.vuelos_raw (CSV, Header = Yes)
\copy staging.vuelos_raw FROM 'data/flight_data_2024_sample.csv' WITH (FORMAT csv, HEADER true)

SELECT COUNT(*) AS filas_en_staging FROM staging.vuelos_raw;
