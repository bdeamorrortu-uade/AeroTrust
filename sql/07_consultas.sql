-- =====================================================================
-- 07. Consultas de negocio
-- ---------------------------------------------------------------------
-- Responden las preguntas que AeroTrust Index promete a sus clientes
-- (Actividad 1): qué aerolínea, ruta y horario es más confiable, y
-- cuánto se indemnizó.
-- =====================================================================


-- ---------------------------------------------------------------------
-- C1. Ranking de aerolíneas por confiabilidad
-- Se calcula sobre todos sus vuelos. RANK() es una función de ventana:
-- numera las filas según el índice sin agrupar los resultados.
-- ---------------------------------------------------------------------
SELECT
    RANK() OVER (ORDER BY indice DESC)  AS puesto,
    codigo_iata,
    nombre,
    total_vuelos,
    pct_demorados,
    pct_cancelados,
    indice
FROM (
    SELECT a.codigo_iata,
           a.nombre,
           COUNT(*) AS total_vuelos,
           ROUND(100.0 * AVG(CASE WHEN v.estado = 'Delayed'   THEN 1 ELSE 0 END), 1) AS pct_demorados,
           ROUND(100.0 * AVG(CASE WHEN v.estado = 'Cancelled' THEN 1 ELSE 0 END), 1) AS pct_cancelados,
           ROUND(100 * (1
                 - 0.6 * AVG(CASE WHEN v.estado = 'Delayed'   THEN 1 ELSE 0 END)
                 - 0.4 * AVG(CASE WHEN v.estado = 'Cancelled' THEN 1 ELSE 0 END)), 2) AS indice
    FROM operativo.vuelos v
    JOIN operativo.aerolineas a ON a.id_aerolinea = v.id_aerolinea
    GROUP BY a.codigo_iata, a.nombre
) t
ORDER BY puesto;


-- ---------------------------------------------------------------------
-- C2. ¿Qué franja horaria conviene? (todas las aerolíneas)
-- ---------------------------------------------------------------------
SELECT
    franja_horaria,
    COUNT(*)                                                                 AS total_vuelos,
    ROUND(100.0 * AVG(CASE WHEN estado = 'Delayed'   THEN 1 ELSE 0 END), 1) AS pct_demorados,
    ROUND(100.0 * AVG(CASE WHEN estado = 'Cancelled' THEN 1 ELSE 0 END), 1) AS pct_cancelados,
    ROUND(AVG(demora_min) FILTER (WHERE estado = 'Delayed'), 1)              AS demora_prom_demorados_min
FROM operativo.v_vuelos_con_franja
GROUP BY franja_horaria
ORDER BY pct_demorados;


-- ---------------------------------------------------------------------
-- C3. Motor de recomendación: para viajar de LAX a JFK, ¿qué aerolínea
-- y franja horaria elegir? Ordena las opciones por índice.
-- (Cambiar los códigos de aeropuerto para consultar otra ruta.)
-- ---------------------------------------------------------------------
SELECT
    r.aeropuerto_origen  AS origen,
    r.aeropuerto_destino AS destino,
    a.nombre             AS aerolinea,
    e.franja_horaria,
    e.total_vuelos,
    e.indice_confiabilidad
FROM analitico.evaluacion_riesgo e
JOIN operativo.rutas      r ON r.id_ruta      = e.id_ruta
JOIN operativo.aerolineas a ON a.id_aerolinea = e.id_aerolinea
WHERE r.aeropuerto_origen  = 'LAX'
  AND r.aeropuerto_destino = 'JFK'
  AND e.fecha_calculo = (SELECT MAX(fecha_calculo) FROM analitico.evaluacion_riesgo)
ORDER BY e.indice_confiabilidad DESC, e.total_vuelos DESC;


-- ---------------------------------------------------------------------
-- C4. Rutas más riesgosas (con al menos 10 vuelos, para que el
-- porcentaje sea representativo).
-- ---------------------------------------------------------------------
SELECT
    r.aeropuerto_origen  AS origen,
    r.aeropuerto_destino AS destino,
    r.distancia_km,
    COUNT(*)                                                                   AS total_vuelos,
    ROUND(100.0 * AVG(CASE WHEN v.estado <> 'On-Time' THEN 1 ELSE 0 END), 1)  AS pct_con_problemas
FROM operativo.vuelos v
JOIN operativo.rutas r ON r.id_ruta = v.id_ruta
GROUP BY r.aeropuerto_origen, r.aeropuerto_destino, r.distancia_km
HAVING COUNT(*) >= 10
ORDER BY pct_con_problemas DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- C5. Evolución mensual de la puntualidad (insumo para dashboards)
-- ---------------------------------------------------------------------
SELECT
    EXTRACT(MONTH FROM fecha_hora_programada)                                AS mes,
    COUNT(*)                                                                 AS total_vuelos,
    ROUND(100.0 * AVG(CASE WHEN estado = 'Delayed'   THEN 1 ELSE 0 END), 1) AS pct_demorados,
    ROUND(100.0 * AVG(CASE WHEN estado = 'Cancelled' THEN 1 ELSE 0 END), 1) AS pct_cancelados
FROM operativo.vuelos
GROUP BY EXTRACT(MONTH FROM fecha_hora_programada)
ORDER BY mes;


-- ---------------------------------------------------------------------
-- C6. Resumen financiero por contrato: primas cobradas e indemnizaciones
-- pagadas (ejecutar después del script 08 para ver las liquidaciones).
-- ---------------------------------------------------------------------
SELECT
    c.razon_social,
    c.nivel_cobertura,
    c.umbral_sla_min,
    COUNT(p.id_poliza)                                                            AS polizas,
    COUNT(*) FILTER (WHERE p.estado_liquidacion = 'Liquidada')                    AS liquidadas,
    COALESCE(SUM(p.prima), 0)                                                     AS total_primas,
    COALESCE(SUM(p.monto_indemnizacion)
             FILTER (WHERE p.estado_liquidacion = 'Liquidada'), 0)                AS total_indemnizado
FROM financiero.contratos_corporativos c
LEFT JOIN financiero.polizas_seguro p ON p.id_contrato = c.id_contrato
GROUP BY c.id_contrato, c.razon_social, c.nivel_cobertura, c.umbral_sla_min
ORDER BY c.id_contrato;
