# AeroTrust Index – Base de datos (TPO Ingeniería de Datos I – Grupo 2)

Implementación en PostgreSQL del modelo de la Actividad 2, poblada con el dataset
**Flight Delay Dataset 2024** (Kaggle, datos de BTS On-Time Performance, licencia CC0).
Se usa la muestra de 10.000 vuelos (`data/flight_data_2024_sample.csv`).

## Estructura

```
data/
  flight_data_2024_sample.csv          muestra del dataset (10.000 vuelos)
  flight_data_2024_data_dictionary.csv diccionario de columnas
sql/
  00_ejecutar_todo.sql                 corre todo en orden
  01_esquemas_y_tablas.sql             esquemas, tablas, PK/FK, UNIQUE, CHECK, índice
  02_staging_carga_csv.sql             tabla cruda + carga del CSV (\copy)
  03_carga_maestros.sql                aerolineas y rutas (normalización)
  04_carga_vuelos.sql                  vuelos: transformación y validación
  05_evaluacion_riesgo.sql             vista con franja + cálculo del índice
  06_contratos_polizas.sql             contratos y pólizas (datos ficticios)
  07_consultas.sql                     6 consultas de negocio
  08_demo_integridad_transaccion.sql   demo de restricciones y transacciones
```

## Cómo ejecutarlo

Requisito: PostgreSQL 14 o superior.

Crear la base (una sola vez):

```bash
createdb aerotrust
```

Ejecutar todo desde la **raíz del proyecto** (la ruta del CSV es relativa a esta carpeta):

```bash
psql -d aerotrust -f sql/00_ejecutar_todo.sql
```

También se puede correr cada script por separado, en orden del 01 al 08.

**Con pgAdmin:** ejecutar cada script con la herramienta de consultas. En el 02, la línea
`\copy` no funciona en pgAdmin: crear la tabla con el resto del script y cargar el CSV con
clic derecho sobre `staging.vuelos_raw` → *Import/Export Data* (formato CSV, Header = Yes).

> En el script 08, los bloques A, B, C y D **tienen que dar error**: son las pruebas de las
> restricciones. En pgAdmin conviene ejecutarlos de a uno.

## Esquemas

| Esquema | Tablas | Capa de la arquitectura |
|---|---|---|
| `staging` | `vuelos_raw` | Ingesta y validación |
| `operativo` | `aerolineas`, `rutas`, `vuelos` (+ vista `v_vuelos_con_franja`) | Núcleo – operativo |
| `analitico` | `evaluacion_riesgo` | Núcleo – analítico |
| `financiero` | `contratos_corporativos`, `polizas_seguro` | Núcleo – financiero |

## Decisiones tomadas (para el informe)

**Reglas de transformación**
- `fecha_hora_programada` = `fl_date` + `crs_dep_time` (hora local).
- `demora_min` = `dep_delay` (demora de salida). `fecha_hora_real` = programada + demora.
- `estado`: `Cancelled` si `cancelled = 1`; `Delayed` si la demora es de 15 minutos o más
  (criterio de la BTS); si no, `On-Time`. Los vuelos desviados se tratan según su demora de salida.
- Distancia convertida de millas a km.
- Los nombres de las aerolíneas se cargan a mano (el dataset solo trae el código IATA).

**Índice de confiabilidad**
- Franjas: Mañana 06–11:59, Tarde 12–18:59, Noche 19–05:59 (hora programada).
- `indice = 100 × (1 − 0,6 × tasa_demora − 0,4 × tasa_cancelacion)`.

**Normalización (hasta 3FN)**
- `staging.vuelos_raw` queda sin normalizar a propósito (copia fiel de la fuente).
- 2FN: la distancia depende de (origen, destino) → tabla `rutas`.
- 3FN: el nombre depende del código de aerolínea → tabla `aerolineas`.
- No se cargan ciudad ni estado del aeropuerto (dependerían del aeropuerto, no de la ruta).
- La franja horaria no se guarda: se calcula en la vista `v_vuelos_con_franja`.
- **Cambio respecto de la Actividad 2:** se quitó `umbral_demora_min` de `polizas_seguro`;
  el umbral se toma de `contratos_corporativos.umbral_sla_min` (evita una dependencia transitiva).
- Redundancias controladas y justificadas: `demora_min`/`estado` en `vuelos` (vienen de la
  fuente) y `evaluacion_riesgo` (foto del riesgo al emitir cada póliza).

**Fuera de alcance (mencionado en la Actividad 2, no implementado)**
- Particionamiento de `vuelos` por fecha, índices BRIN/parciales, vistas materializadas con
  refresco programado y réplica de lectura. Con 10.000 vuelos no aportan y suman complejidad.

**Limitaciones**
- Datos de EE.UU. como prueba de concepto: las fuentes abiertas argentinas (ANAC) no
  publican hora programada, demoras ni cancelaciones.
- Con la muestra de 10.000 vuelos, muchas combinaciones aerolínea + ruta + franja tienen
  pocos vuelos; por eso las consultas filtran rutas con un mínimo de vuelos. Con el dataset
  completo (o un mes completo) el índice es más representativo, y los scripts funcionan
  igual cambiando el nombre del archivo en el 02.
- Contratos y pólizas son ficticios.
- El índice se calcula con los mismos vuelos de 2024 que cubren las pólizas (en un sistema
  real se usaría el historial anterior a la emisión).
