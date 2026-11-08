-- =====================================================================
-- 05. Motor de índice de confiabilidad -> analitico.evaluacion_riesgo
-- ---------------------------------------------------------------------
-- Agrupa el historial de vuelos por aerolínea + ruta + franja horaria.
--
-- Franja horaria (según la hora PROGRAMADA de salida, hora local):
--   Mañana: 06:00 a 11:59   Tarde: 12:00 a 18:59   Noche: 19:00 a 05:59
--
-- Tasas (sobre el total de vuelos del grupo, incluidos los cancelados):
--   tasa_demora      = vuelos 'Delayed'   / total
--   tasa_cancelacion = vuelos 'Cancelled' / total
--
-- Índice de confiabilidad (0 a 100, más alto = más confiable):
--   indice = 100 * (1 - 0,6 * tasa_demora - 0,4 * tasa_cancelacion)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Vista auxiliar: cada vuelo con su franja horaria.
-- La franja NO se guarda en vuelos porque se deduce de la hora
-- programada (guardarla sería redundante). La vista la calcula al vuelo
-- y se reutiliza en este script y en los siguientes.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW operativo.v_vuelos_con_franja AS
SELECT v.*,
       CASE WHEN EXTRACT(HOUR FROM v.fecha_hora_programada) BETWEEN 6  AND 11 THEN 'Mañana'
            WHEN EXTRACT(HOUR FROM v.fecha_hora_programada) BETWEEN 12 AND 18 THEN 'Tarde'
            ELSE 'Noche'
       END AS franja_horaria
FROM operativo.vuelos v;

-- ---------------------------------------------------------------------
-- Cálculo del índice.
-- Si se ejecuta dos veces el mismo día, actualiza los valores
-- (ON CONFLICT ... DO UPDATE) en lugar de duplicar filas.
-- ---------------------------------------------------------------------
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

-- Control
SELECT COUNT(*)                            AS evaluaciones,
       ROUND(AVG(indice_confiabilidad), 2) AS indice_promedio,
       MIN(indice_confiabilidad)           AS indice_minimo,
       MAX(indice_confiabilidad)           AS indice_maximo
FROM analitico.evaluacion_riesgo;
