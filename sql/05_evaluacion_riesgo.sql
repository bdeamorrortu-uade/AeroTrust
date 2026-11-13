-- 05. Índice de confiabilidad por aerolínea, ruta y franja horaria
-- indice = 100 * (1 - 0.6 * tasa_demora - 0.4 * tasa_cancelacion)

CREATE OR REPLACE VIEW operativo.v_vuelos_con_franja AS
SELECT v.*,
       CASE WHEN EXTRACT(HOUR FROM v.fecha_hora_programada) BETWEEN 6  AND 11 THEN 'Mañana'
            WHEN EXTRACT(HOUR FROM v.fecha_hora_programada) BETWEEN 12 AND 18 THEN 'Tarde'
            ELSE 'Noche'
       END AS franja_horaria
FROM operativo.vuelos v;

INSERT INTO analitico.evaluacion_riesgo
    (id_aerolinea, id_ruta, franja_horaria, total_vuelos,
     tasa_demora, tasa_cancelacion, indice_confiabilidad, fecha_calculo)
SELECT
    id_aerolinea,
    id_ruta,
    franja_horaria,
    COUNT(*)                                                        AS total_vuelos,
    ROUND(AVG(CASE WHEN estado = 'Delayed'   THEN 1 ELSE 0 END), 4) AS tasa_demora,
    ROUND(AVG(CASE WHEN estado = 'Cancelled' THEN 1 ELSE 0 END), 4) AS tasa_cancelacion,
    ROUND(100 * (1
          - 0.6 * AVG(CASE WHEN estado = 'Delayed'   THEN 1 ELSE 0 END)
          - 0.4 * AVG(CASE WHEN estado = 'Cancelled' THEN 1 ELSE 0 END)), 2)
                                                                    AS indice_confiabilidad,
    CURRENT_DATE                                                    AS fecha_calculo
FROM operativo.v_vuelos_con_franja
GROUP BY id_aerolinea, id_ruta, franja_horaria
ON CONFLICT (id_aerolinea, id_ruta, franja_horaria, fecha_calculo) DO UPDATE
SET total_vuelos         = EXCLUDED.total_vuelos,
    tasa_demora          = EXCLUDED.tasa_demora,
    tasa_cancelacion     = EXCLUDED.tasa_cancelacion,
    indice_confiabilidad = EXCLUDED.indice_confiabilidad;

SELECT COUNT(*)                            AS evaluaciones,
       ROUND(AVG(indice_confiabilidad), 2) AS indice_promedio,
       MIN(indice_confiabilidad)           AS indice_minimo,
       MAX(indice_confiabilidad)           AS indice_maximo
FROM analitico.evaluacion_riesgo;
