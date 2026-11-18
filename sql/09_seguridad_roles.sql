-- 09. Seguridad: roles, usuarios y permisos
-- Correr con un usuario que pueda crear roles. En D, las marcadas tienen que dar error.

-- A. Limpieza
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['usr_analista', 'usr_liquidador',
                             'rol_analista_bi', 'rol_liquidador'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END;
$$;

-- B. Roles y usuarios
CREATE ROLE rol_analista_bi NOLOGIN;
CREATE ROLE rol_liquidador  NOLOGIN;

CREATE ROLE usr_analista   LOGIN;
CREATE ROLE usr_liquidador LOGIN;

GRANT rol_analista_bi TO usr_analista;
GRANT rol_liquidador  TO usr_liquidador;

-- C. Permisos

-- Analista
GRANT USAGE  ON SCHEMA analitico, operativo TO rol_analista_bi;
GRANT SELECT ON ALL TABLES IN SCHEMA analitico TO rol_analista_bi;
GRANT SELECT ON operativo.aerolineas,
                operativo.rutas,
                operativo.v_vuelos_con_franja TO rol_analista_bi;

-- Liquidador
GRANT USAGE  ON SCHEMA financiero, operativo TO rol_liquidador;
GRANT SELECT ON financiero.contratos_corporativos,
                financiero.polizas_seguro,
                operativo.vuelos TO rol_liquidador;
GRANT UPDATE (estado_liquidacion, fecha_liquidacion)
             ON financiero.polizas_seguro TO rol_liquidador;

REVOKE EXECUTE ON PROCEDURE financiero.sp_liquidar_polizas FROM PUBLIC;
GRANT  EXECUTE ON PROCEDURE financiero.sp_liquidar_polizas TO rol_liquidador;

-- D. Pruebas

SET ROLE usr_analista;
SELECT COUNT(*) AS evaluaciones_visibles FROM analitico.evaluacion_riesgo;
SELECT COUNT(*) AS vuelos_por_la_vista   FROM operativo.v_vuelos_con_franja;
SELECT COUNT(*) FROM operativo.vuelos;               -- error
SELECT COUNT(*) FROM financiero.polizas_seguro;      -- error
RESET ROLE;

SET ROLE usr_liquidador;
SELECT estado_liquidacion, COUNT(*) AS polizas
FROM financiero.polizas_seguro
GROUP BY estado_liquidacion
ORDER BY estado_liquidacion;
CALL financiero.sp_liquidar_polizas(NULL, NULL, NULL);
UPDATE financiero.polizas_seguro SET prima = 1 WHERE id_poliza = 1;  -- error
DELETE FROM financiero.polizas_seguro WHERE id_poliza = 1;           -- error
RESET ROLE;

-- E. Permisos otorgados
SELECT grantee,
       table_schema || '.' || table_name AS objeto,
       STRING_AGG(privilege_type, ', ' ORDER BY privilege_type) AS permisos
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_analista_bi', 'rol_liquidador')
GROUP BY grantee, table_schema, table_name
ORDER BY grantee, objeto;

SELECT grantee,
       table_schema || '.' || table_name AS objeto,
       column_name,
       privilege_type
FROM information_schema.column_privileges
WHERE grantee = 'rol_liquidador'
  AND privilege_type = 'UPDATE'
ORDER BY column_name;
