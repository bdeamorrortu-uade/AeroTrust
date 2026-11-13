-- 04. Carga de vuelos

INSERT INTO operativo.vuelos
    (id_aerolinea, id_ruta, nro_vuelo, fecha_hora_programada,
     fecha_hora_real, demora_min, estado)
SELECT
    a.id_aerolinea,
    r.id_ruta,
    (s.op_carrier_fl_num::NUMERIC)::INT::TEXT                 AS nro_vuelo,
    s.programada                                              AS fecha_hora_programada,
    CASE WHEN s.cancelled = '1' THEN NULL
         ELSE s.programada + (s.dep_delay::NUMERIC)::INT * INTERVAL '1 minute'
    END                                                       AS fecha_hora_real,
    CASE WHEN s.cancelled = '1' THEN NULL
         ELSE (s.dep_delay::NUMERIC)::INT
    END                                                       AS demora_min,
    CASE WHEN s.cancelled = '1'          THEN 'Cancelled'
         WHEN s.dep_delay::NUMERIC >= 15 THEN 'Delayed'
         ELSE 'On-Time'
    END                                                       AS estado
FROM (
    SELECT raw.*,
           raw.fl_date::DATE
         + (raw.crs_dep_time::INT / 100) * INTERVAL '1 hour'
         + (raw.crs_dep_time::INT % 100) * INTERVAL '1 minute' AS programada
    FROM staging.vuelos_raw raw
    WHERE raw.crs_dep_time <> ''
      AND (raw.cancelled = '1' OR raw.dep_delay <> '')
) s
JOIN operativo.aerolineas a ON a.codigo_iata        = s.op_unique_carrier
JOIN operativo.rutas      r ON r.aeropuerto_origen  = s.origin
                           AND r.aeropuerto_destino = s.dest
ON CONFLICT (id_aerolinea, nro_vuelo, fecha_hora_programada) DO NOTHING;

SELECT (SELECT COUNT(*) FROM staging.vuelos_raw)  AS filas_staging,
       (SELECT COUNT(*) FROM operativo.vuelos)    AS vuelos_cargados,
       (SELECT COUNT(*) FROM staging.vuelos_raw)
     - (SELECT COUNT(*) FROM operativo.vuelos)    AS filas_descartadas;

SELECT estado, COUNT(*) AS cantidad
FROM operativo.vuelos
GROUP BY estado
ORDER BY cantidad DESC;
