-- 08. Pruebas de integridad y transacciones
-- A, B, C y D tienen que dar error.

-- A. Póliza duplicada
INSERT INTO financiero.polizas_seguro (id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion)
SELECT id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion
FROM financiero.polizas_seguro
ORDER BY id_poliza
LIMIT 1;

-- B. Estado inválido
UPDATE operativo.vuelos
SET estado = 'Perdido'
WHERE id_vuelo = (SELECT MIN(id_vuelo) FROM operativo.vuelos);

-- C. Borrar un vuelo con pólizas
DELETE FROM operativo.vuelos
WHERE id_vuelo = (SELECT MIN(id_vuelo) FROM financiero.polizas_seguro);

-- D. Falla dentro de una transacción -> ROLLBACK
SELECT COUNT(*) AS liquidadas_antes_de_la_transaccion
FROM financiero.polizas_seguro
WHERE estado_liquidacion = 'Liquidada';

BEGIN;

UPDATE financiero.polizas_seguro p
SET estado_liquidacion = 'Liquidada',
    fecha_liquidacion  = NOW()
FROM operativo.vuelos v, financiero.contratos_corporativos c
WHERE p.id_vuelo    = v.id_vuelo
  AND p.id_contrato = c.id_contrato
  AND p.estado_liquidacion = 'Pendiente'
  AND (v.estado = 'Cancelled' OR v.demora_min > c.umbral_sla_min);

SELECT COUNT(*) AS liquidadas_dentro_de_la_transaccion
FROM financiero.polizas_seguro
WHERE estado_liquidacion = 'Liquidada';

-- Esto falla (póliza duplicada)
INSERT INTO financiero.polizas_seguro (id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion)
SELECT id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion
FROM financiero.polizas_seguro
ORDER BY id_poliza
LIMIT 1;

ROLLBACK;

SELECT COUNT(*) AS liquidadas_despues_del_rollback
FROM financiero.polizas_seguro
WHERE estado_liquidacion = 'Liquidada';

-- E. Liquidación

SELECT p.id_poliza,
       c.razon_social,
       a.codigo_iata || ' ' || v.nro_vuelo AS vuelo,
       v.fecha_hora_programada,
       v.estado,
       v.demora_min,
       c.umbral_sla_min,
       p.monto_indemnizacion
FROM financiero.polizas_seguro p
JOIN financiero.contratos_corporativos c ON c.id_contrato  = p.id_contrato
JOIN operativo.vuelos                  v ON v.id_vuelo     = p.id_vuelo
JOIN operativo.aerolineas              a ON a.id_aerolinea = v.id_aerolinea
WHERE p.estado_liquidacion = 'Pendiente'
  AND (v.estado = 'Cancelled' OR v.demora_min > c.umbral_sla_min)
ORDER BY p.id_poliza;

BEGIN;

UPDATE financiero.polizas_seguro p
SET estado_liquidacion = 'Liquidada',
    fecha_liquidacion  = NOW()
FROM operativo.vuelos v, financiero.contratos_corporativos c
WHERE p.id_vuelo    = v.id_vuelo
  AND p.id_contrato = c.id_contrato
  AND p.estado_liquidacion = 'Pendiente'
  AND (v.estado = 'Cancelled' OR v.demora_min > c.umbral_sla_min);

UPDATE financiero.polizas_seguro p
SET estado_liquidacion = 'No corresponde'
FROM operativo.vuelos v, financiero.contratos_corporativos c
WHERE p.id_vuelo    = v.id_vuelo
  AND p.id_contrato = c.id_contrato
  AND p.estado_liquidacion = 'Pendiente'
  AND v.estado <> 'Cancelled'
  AND v.demora_min <= c.umbral_sla_min;

COMMIT;

SELECT estado_liquidacion,
       COUNT(*)                 AS polizas,
       SUM(monto_indemnizacion) AS monto_asegurado
FROM financiero.polizas_seguro
GROUP BY estado_liquidacion
ORDER BY estado_liquidacion;
