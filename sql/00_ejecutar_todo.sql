-- =====================================================================
-- 00. Ejecuta todos los scripts en orden (desde la raíz del proyecto):
--     psql -d aerotrust -f sql/00_ejecutar_todo.sql
-- El orden lo imponen las claves foráneas:
--     aerolineas -> rutas -> vuelos -> evaluacion_riesgo -> contratos -> polizas
-- =====================================================================
\echo '== 01. Esquemas y tablas =='
\ir 01_esquemas_y_tablas.sql
\echo '== 02. Staging (carga del CSV) =='
\ir 02_staging_carga_csv.sql
\echo '== 03. Maestros =='
\ir 03_carga_maestros.sql
\echo '== 04. Vuelos =='
\ir 04_carga_vuelos.sql
\echo '== 05. Evaluación de riesgo =='
\ir 05_evaluacion_riesgo.sql
\echo '== 06. Contratos y pólizas =='
\ir 06_contratos_polizas.sql
\echo '== 07. Consultas =='
\ir 07_consultas.sql
\echo '== 08. Demo de integridad (los errores de A, B, C y D son esperados) =='
\ir 08_demo_integridad_transaccion.sql
