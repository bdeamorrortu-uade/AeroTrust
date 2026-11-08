-- =====================================================================
-- 06. Datos financieros: contratos corporativos y pólizas
-- ---------------------------------------------------------------------
-- Estos datos no existen en ninguna fuente pública: son FICTICIOS y se
-- cargan a mano para poder demostrar el circuito contrato -> póliza ->
-- liquidación. Las empresas y los CUIT son inventados.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Contratos corporativos
-- umbral_sla_min: demora (min) a partir de la cual se paga la póliza.
-- ---------------------------------------------------------------------
INSERT INTO financiero.contratos_corporativos
    (razon_social, cuit, fecha_inicio, fecha_fin, nivel_cobertura, umbral_sla_min, estado)
VALUES
    ('Andes Consultores S.A.',          '30-71000001-1', '2024-01-01', '2024-12-31', 'Premium',   60, 'Activo'),
    ('Pampa Tech S.R.L.',               '30-71000002-2', '2024-01-01', '2024-12-31', 'Estándar',  90, 'Activo'),
    ('Río de la Plata Auditores S.A.',  '30-71000003-3', '2024-03-01', '2025-02-28', 'Básico',   120, 'Activo'),
    ('Cuyo Logística S.A.',             '30-71000004-4', '2023-01-01', '2023-12-31', 'Estándar', 120, 'Vencido'),
    ('Patagonia Energía S.A.',          '30-71000005-5', '2024-06-01', '2025-05-31', 'Premium',   45, 'Activo');

-- ---------------------------------------------------------------------
-- Pólizas
-- Cada contrato cubre los viajes de sus empleados en ciertas rutas, con
-- un monto de indemnización pactado por ruta (tabla "cobertura").
--
-- Regla de negocio: no puede existir una póliza sin un contrato ACTIVO
-- y VIGENTE en la fecha del vuelo -> se filtra en el WHERE.
-- (El contrato 4 está vencido: no genera pólizas.)
--
-- id_evaluacion: el riesgo vigente de esa aerolínea + ruta + franja.
-- prima = 2 % del monto + recargo según riesgo (100 - índice) %.
-- ---------------------------------------------------------------------
INSERT INTO financiero.polizas_seguro
    (id_contrato, id_vuelo, id_evaluacion, prima, monto_indemnizacion)
SELECT
    c.id_contrato,
    v.id_vuelo,
    e.id_evaluacion,
    ROUND(cob.monto * (0.02 + (100 - e.indice_confiabilidad) / 100 * 0.10), 2) AS prima,
    cob.monto                                                                  AS monto_indemnizacion
FROM (VALUES
        -- (id_contrato, origen, destino, monto en USD)
        (1, 'LAX', 'JFK', 500.00),
        (1, 'JFK', 'LAX', 500.00),
        (1, 'LAX', 'DFW', 450.00),
        (1, 'ORD', 'DFW', 450.00),
        (2, 'LAX', 'SFO', 250.00),
        (2, 'SFO', 'LAX', 250.00),
        (2, 'DCA', 'ATL', 300.00),
        (2, 'LGA', 'ORD', 300.00),
        (3, 'DCA', 'BOS', 200.00),
        (3, 'DEN', 'LAX', 300.00),
        (3, 'ATL', 'DFW', 300.00),
        (4, 'LAX', 'JFK', 400.00),     -- contrato vencido: no debe generar pólizas
        (5, 'OGG', 'HNL', 350.00),
        (5, 'HNL', 'OGG', 350.00),
        (5, 'BOS', 'MCO', 400.00),
        (5, 'LAX', 'PDX', 400.00)
     ) AS cob (id_contrato, origen, destino, monto)
JOIN financiero.contratos_corporativos c ON c.id_contrato        = cob.id_contrato
JOIN operativo.rutas                   r ON r.aeropuerto_origen  = cob.origen
                                        AND r.aeropuerto_destino = cob.destino
JOIN operativo.v_vuelos_con_franja     v ON v.id_ruta            = r.id_ruta
JOIN analitico.evaluacion_riesgo       e ON e.id_aerolinea       = v.id_aerolinea
                                        AND e.id_ruta            = v.id_ruta
                                        AND e.franja_horaria     = v.franja_horaria
WHERE c.estado = 'Activo'
  AND v.fecha_hora_programada::DATE BETWEEN c.fecha_inicio AND c.fecha_fin
  AND e.fecha_calculo = (SELECT MAX(fecha_calculo) FROM analitico.evaluacion_riesgo);

-- Control
SELECT c.razon_social,
       c.estado AS estado_contrato,
       COUNT(p.id_poliza) AS polizas_emitidas
FROM financiero.contratos_corporativos c
LEFT JOIN financiero.polizas_seguro p ON p.id_contrato = c.id_contrato
GROUP BY c.id_contrato, c.razon_social, c.estado
ORDER BY c.id_contrato;
