-- 09. Seguridad: roles, usuarios y permisos (DCL)
-- Principio de menor privilegio: cada perfil accede solo a lo que necesita.
--   rol_analista_bi -> solo lectura del esquema analítico y de la vista de vuelos
--   rol_liquidador  -> lee contratos y pólizas, liquida pólizas, no puede borrar
-- Los permisos se dan a los roles (grupos) y los usuarios heredan el rol.
-- Hay que correrlo con un usuario que pueda crear roles (por ejemplo, postgres).
-- En la parte D, las consultas marcadas tienen que dar error.

-- A. Limpieza (para poder correr el script varias veces)
-- Los roles son de todo el servidor; DROP OWNED BY les quita los permisos en esta base.
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

-- B. Roles (grupos, sin login) y usuarios (con login)
CREATE ROLE rol_analista_bi NOLOGIN;
CREATE ROLE rol_liquidador  NOLOGIN;

-- En un entorno real se agrega PASSWORD '...'; acá se prueban con SET ROLE.
CREATE ROLE usr_analista   LOGIN;
CREATE ROLE usr_liquidador LOGIN;

GRANT rol_analista_bi TO usr_analista;
GRANT rol_liquidador  TO usr_liquidador;

-- C. Permisos

-- Analista: lee el esquema analítico y los maestros. A los vuelos accede solo por la
-- vista, sin permiso sobre la tabla operativo.vuelos.
GRANT USAGE  ON SCHEMA analitico, operativo TO rol_analista_bi;
GRANT SELECT ON ALL TABLES IN SCHEMA analitico TO rol_analista_bi;
GRANT SELECT ON operativo.aerolineas,
                operativo.rutas,
                operativo.v_vuelos_con_franja TO rol_analista_bi;

-- Liquidador: lee contratos, pólizas y vuelos; solo puede modificar las columnas de
-- la liquidación (permiso por columna) y ejecutar el procedimiento.
GRANT USAGE  ON SCHEMA financiero, operativo TO rol_liquidador;
GRANT SELECT ON financiero.contratos_corporativos,
                financiero.polizas_seguro,
                operativo.vuelos TO rol_liquidador;
GRANT UPDATE (estado_liquidacion, fecha_liquidacion)
             ON financiero.polizas_seguro TO rol_liquidador;

-- Por defecto cualquier usuario (PUBLIC) puede ejecutar funciones y procedimientos.
-- Se le quita a PUBLIC y se le da solo al liquidador.
REVOKE EXECUTE ON PROCEDURE financiero.sp_liquidar_polizas FROM PUBLIC;
GRANT  EXECUTE ON PROCEDURE financiero.sp_liquidar_polizas TO rol_liquidador;

-- D. Pruebas con cada usuario

SET ROLE usr_analista;
SELECT COUNT(*) AS evaluaciones_visibles FROM analitico.evaluacion_riesgo;
SELECT COUNT(*) AS vuelos_por_la_vista   FROM operativo.v_vuelos_con_franja;
SELECT COUNT(*) FROM operativo.vuelos;               -- error: sin permiso sobre la tabla
SELECT COUNT(*) FROM financiero.polizas_seguro;      -- error: sin permiso sobre el esquema
RESET ROLE;

SET ROLE usr_liquidador;
SELECT estado_liquidacion, COUNT(*) AS polizas
FROM financiero.polizas_seguro
GROUP BY estado_liquidacion
ORDER BY estado_liquidacion;
CALL financiero.sp_liquidar_polizas(NULL, NULL, NULL);  -- ya no quedan pendientes: 0 y 0
UPDATE financiero.polizas_seguro SET prima = 1 WHERE id_poliza = 1;  -- error: columna no permitida
DELETE FROM financiero.polizas_seguro WHERE id_poliza = 1;           -- error: sin DELETE
RESET ROLE;

-- E. Resumen de permisos otorgados
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
