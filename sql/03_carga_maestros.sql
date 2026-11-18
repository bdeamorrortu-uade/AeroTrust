-- 03. Aerolíneas y rutas

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

-- Códigos que no estén en la lista anterior
INSERT INTO operativo.aerolineas (codigo_iata, nombre, pais_jurisdiccion)
SELECT DISTINCT UPPER(TRIM(s.op_unique_carrier)),
                UPPER(TRIM(s.op_unique_carrier)),
                'Estados Unidos'
FROM staging.vuelos_raw s
WHERE LENGTH(TRIM(s.op_unique_carrier)) = 2
  AND NOT EXISTS (SELECT 1 FROM operativo.aerolineas a
                  WHERE a.codigo_iata = UPPER(TRIM(s.op_unique_carrier)));

-- distancia en millas -> km
INSERT INTO operativo.rutas (aeropuerto_origen, aeropuerto_destino, distancia_km)
SELECT UPPER(TRIM(origin)),
       UPPER(TRIM(dest)),
       ROUND(MAX(distance::NUMERIC) * 1.609344)::INT
FROM staging.vuelos_raw
WHERE LENGTH(TRIM(origin)) = 3
  AND LENGTH(TRIM(dest))   = 3
  AND UPPER(TRIM(origin)) <> UPPER(TRIM(dest))
GROUP BY UPPER(TRIM(origin)), UPPER(TRIM(dest));

SELECT (SELECT COUNT(*) FROM operativo.aerolineas) AS aerolineas,
       (SELECT COUNT(*) FROM operativo.rutas)      AS rutas;
