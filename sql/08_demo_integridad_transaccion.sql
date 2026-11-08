-- =====================================================================
-- 08. Demo de integridad y transacciones (para la presentación)
-- ---------------------------------------------------------------------
-- Demuestra las promesas de la Actividad 2:
--   A. UNIQUE (id_contrato, id_vuelo): no se puede asegurar dos veces lo mismo
--   B. CHECK en vuelos.estado: solo On-Time / Delayed / Cancelled
--   C. ON DELETE RESTRICT: no se puede borrar un vuelo con pólizas
--   D. Atomicidad (ACID): si algo falla en la liquidación, no se aplica nada
--   E. Motor de pagos paramétricos: liquidación real con COMMIT
--
-- Las pruebas A, B, C y D DEBEN dar error: eso es lo que se quiere mostrar.
-- En psql, ejecutar SIN la opción ON_ERROR_STOP. En pgAdmin, ejecutar
-- cada bloque por separado (seleccionarlo y F5).
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Póliza duplicada -> ERROR: viola uq_poliza_contrato_vuelo
-- Se intenta copiar la primera póliza (mismo contrato y mismo vuelo).
-- ---------------------------------------------------------------------
INSERT INTO financiero.polizas_seguro (id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion)
SELECT id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion
FROM financiero.polizas_seguro
ORDER BY id_poliza
LIMIT 1;


-- ---------------------------------------------------------------------
-- B. Estado inválido -> ERROR: viola el CHECK de vuelos.estado
-- ---------------------------------------------------------------------
UPDATE operativo.vuelos
SET estado = 'Perdido'
WHERE id_vuelo = (SELECT MIN(id_vuelo) FROM operativo.vuelos);


-- ---------------------------------------------------------------------
-- C. Borrar un vuelo asegurado -> ERROR: ON DELETE RESTRICT
-- (se perdería la trazabilidad de la póliza)
-- ---------------------------------------------------------------------
DELETE FROM operativo.vuelos
WHERE id_vuelo = (SELECT MIN(id_vuelo) FROM financiero.polizas_seguro);


-- ---------------------------------------------------------------------
-- D. Atomicidad: transacción que falla a mitad de camino.
--   1) se marcan como liquidadas las pólizas que corresponden;
--   2) un paso posterior falla (se repite una póliza);
--   3) ROLLBACK: la base vuelve al estado anterior, nada quedó liquidado.
-- ---------------------------------------------------------------------
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

-- Dentro de la transacción ya se ven como liquidadas:
SELECT COUNT(*) AS liquidadas_dentro_de_la_transaccion
FROM financiero.polizas_seguro
WHERE estado_liquidacion = 'Liquidada';

-- Paso que falla (póliza duplicada). A partir de acá la transacción queda abortada.
INSERT INTO financiero.polizas_seguro (id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion)
SELECT id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion
FROM financiero.polizas_seguro
ORDER BY id_poliza
LIMIT 1;

ROLLBACK;

-- Después del ROLLBACK el número es el mismo que antes del BEGIN
-- (0 la primera vez que se ejecuta): la liquidación parcial se deshizo.
SELECT COUNT(*) AS liquidadas_despues_del_rollback
FROM financiero.polizas_seguro
WHERE estado_liquidacion = 'Liquidada';


-- ---------------------------------------------------------------------
-- E. Motor de pagos paramétricos: liquidación correcta (todo o nada)
-- Regla: se paga si el vuelo se canceló o si la demora superó el
-- umbral del contrato. Si no, la póliza pasa a 'No corresponde'.
-- ---------------------------------------------------------------------

-- Antes de liquidar: pólizas que corresponde pagar
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

-- 1) Pagar las que cumplen la condición
UPDATE financiero.polizas_seguro p
SET estado_liquidacion = 'Liquidada',
    fecha_liquidacion  = NOW()
FROM operativo.vuelos v, financiero.contratos_corporativos c
WHERE p.id_vuelo    = v.id_vuelo
  AND p.id_contrato = c.id_contrato
  AND p.estado_liquidacion = 'Pendiente'
  AND (v.estado = 'Cancelled' OR v.demora_min > c.umbral_sla_min);

-- 2) Cerrar las que no cumplen (el vuelo ya ocurrió sin superar el umbral)
UPDATE financiero.polizas_seguro p
SET estado_liquidacion = 'No corresponde'
FROM operativo.vuelos v, financiero.contratos_corporativos c
WHERE p.id_vuelo    = v.id_vuelo
  AND p.id_contrato = c.id_contrato
  AND p.estado_liquidacion = 'Pendiente'
  AND v.estado <> 'Cancelled'
  AND v.demora_min <= c.umbral_sla_min;

COMMIT;

-- Resultado final
SELECT estado_liquidacion,
       COUNT(*)                 AS polizas,
       SUM(monto_indemnizacion) AS monto_asegurado
FROM financiero.polizas_seguro
GROUP BY estado_liquidacion
ORDER BY estado_liquidacion;
