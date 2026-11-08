-- =====================================================================
-- 03. Carga de datos maestros: aerolineas y rutas
-- ---------------------------------------------------------------------
-- Normalización aplicada sobre la tabla plana de staging:
--   * 3FN: op_unique_carrier -> nombre de aerolínea  => tabla aerolineas
--   * 2FN: (origin, dest)    -> distance             => tabla rutas
-- Cada aerolínea y cada ruta queda guardada UNA sola vez.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Aerolíneas
-- El dataset trae solo el código IATA. Los nombres se cargan a mano
-- (son las aerolíneas que reportan a la BTS en 2024).
-- ---------------------------------------------------------------------
INSERT INTO operativo.aerolineas (codigo_iata, nombre, pais_jurisdiccion) VALUES
    ('9E', 'Endeavor Air',        'Estados Unidos'),
    ('AA', 'American Airlines',   'Estados Unidos'),
    ('AS', 'Alaska Airlines',     'Estados Unidos'),
    ('B6', 'JetBlue Airways',     'Estados Unidos'),
    ('DL', 'Delta Air Lines',     'Estados Unidos'),
    ('F9', 'Frontier Airlines',   'Estados Unidos'),
    ('G4', 'Allegiant Air',       'Estados Unidos'),
    ('HA', 'Hawaiian Airlines',   'Estados Unidos'),
    ('MQ', 'Envoy Air',           'Estados Unidos'),
    ('NK', 'Spirit Airlines',     'Estados Unidos'),
    ('OH', 'PSA Airlines',        'Estados Unidos'),
    ('OO', 'SkyWest Airlines',    'Estados Unidos'),
    ('UA', 'United Airlines',     'Estados Unidos'),
    ('WN', 'Southwest Airlines',  'Estados Unidos'),
    ('YX', 'Republic Airways',    'Estados Unidos');

-- Red de seguridad: si en los datos aparece un código que no está en la
-- lista anterior, se crea igual (con el código como nombre) para que la
-- carga de vuelos no falle por la clave foránea.
INSERT INTO operativo.aerolineas (codigo_iata, nombre, pais_jurisdiccion)
SELECT DISTINCT s.op_unique_carrier, s.op_unique_carrier, 'Estados Unidos'
FROM staging.vuelos_raw s
WHERE LENGTH(s.op_unique_carrier) = 2
  AND NOT EXISTS (SELECT 1 FROM operativo.aerolineas a
                  WHERE a.codigo_iata = s.op_unique_carrier);

-- ---------------------------------------------------------------------
-- Rutas
-- Una fila por par origen-destino. La distancia viene en millas y se
-- convierte a km (1 milla = 1,609344 km).
-- ---------------------------------------------------------------------
INSERT INTO operativo.rutas (aeropuerto_origen, aeropuerto_destino, distancia_km)
SELECT origin,
       dest,
       ROUND(MAX(distance::NUMERIC) * 1.609344)::INT
FROM staging.vuelos_raw
WHERE LENGTH(origin) = 3
  AND LENGTH(dest)   = 3
  AND origin <> dest
GROUP BY origin, dest;

-- Control
SELECT (SELECT COUNT(*) FROM operativo.aerolineas) AS aerolineas,
       (SELECT COUNT(*) FROM operativo.rutas)      AS rutas;
