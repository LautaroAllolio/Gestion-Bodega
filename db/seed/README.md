# Carga masiva reproducible

Script `load.py` para poblar la base de Bodegas del Atuel con datos sintéticos
determinísticos. Genera y carga los catálogos del Anexo B más el volumen de
operación, respetando el grafo de claves foráneas y las restricciones del
esquema.

## Requisitos

- Python 3.10 o superior.
- PostgreSQL con las migraciones `001` a `007` aplicadas.
- Dependencias de `requirements.txt` (`psycopg` 3 y `Faker`).

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r db/seed/requirements.txt
```

## Base de datos

El script se conecta con `--dsn`, con `DATABASE_URL`, o con las variables
estándar `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER` y `PGPASSWORD`. La
contraseña no se guarda en el repositorio.

```powershell
$env:PGPASSWORD = "<password>"
$env:PGDATABASE = "bodega_seed"
```

Para una base vacía:

```powershell
$env:PGPASSWORD = "<password>"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "CREATE DATABASE bodega_seed"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/001_esquema.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/002_contraints.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/003_funciones.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/004_procedimientos.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/005_triggers.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/006_vistas.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/migrations/007_roles.sql
```

## Uso

```powershell
$env:PGPASSWORD = "<password>"

# Validación sin base: genera, valida y muestra conteos.
.\.venv\Scripts\python.exe db/seed/load.py --dry-run --scale 0.01

# Carga completa sobre una base vacía.
.\.venv\Scripts\python.exe db/seed/load.py --scale 1.0

# Recarga completa: trunca las 31 tablas y vuelve a cargar.
.\.venv\Scripts\python.exe db/seed/load.py --reset --scale 1.0

# Reporte JSON con conteos, tiempos y controles.
.\.venv\Scripts\python.exe db/seed/load.py --reset --scale 1.0 --report report.json

# Comparación de estrategias con rollback (no modifica la base).
.\.venv\Scripts\python.exe db/seed/load.py --benchmark --benchmark-scale 1.0 `
  --benchmark-report db/seed/benchmark_report.json
```

Sin `--reset`, el script aborta si detecta datos en `Cepa`, `Vino` o
`ComprobanteVenta`.

## Opciones

| Opción | Descripción |
|---|---|
| `--dsn` | Cadena de conexión completa. Tiene prioridad sobre las variables `PG*`. |
| `--reset` | Ejecuta `TRUNCATE ... RESTART IDENTITY CASCADE` sobre las 31 tablas. |
| `--scale` | Factor de escala de los volúmenes. Por defecto `1.0`. |
| `--strategy` | Estrategia de inserción: `copy` (default), `executemany` o `individual`. |
| `--seed` | Semilla del generador. Por defecto `20261101`. |
| `--base-date` | Fecha base ISO para el historial. Por defecto `2026-11-01`. |
| `--dry-run` | Genera y valida en memoria, sin conectarse a PostgreSQL. |
| `--report` | Escribe un JSON con conteos, tiempos y resultados de control. |
| `--benchmark` | Compara las tres estrategias dentro de una transacción con rollback. |
| `--benchmark-scale` | Escala del benchmark. Por defecto `1.0`. |
| `--benchmark-report` | Escribe el JSON con el detalle del benchmark. |

## Volúmenes (escala 1.0)

| Tabla | Filas | Tabla | Filas |
|---|---:|---|---:|
| `cepa` | 12 | `maridaje` | 8 |
| `departamento` | 18 | `localidad` | 18 |
| `bodega` | 20 | `transportista` | 18 |
| `depositocentral` | 1 | `saladeventa` | 20 |
| `empleado` | 120 | `transportistalocalidad` | 49 |
| `finca` | 30 | `parcela` | 900 |
| `loteuva` | 4000 | `analisiscalidad` | 8029 |
| `cliente` | 20000 | `socioclub` | 14016 |
| `distribuidor` | 3946 | `exportador` | 2038 |
| `permisoexportacion` | 4558 | `vino` | 600 |
| `vinocepa` | 880 | `vinomaridaje` | 903 |
| `stockdeposito` | 600 | `ingreso` | 2000 |
| `detalleingreso` | 7125 | `transferencia` | 3000 |
| `detalletransferencia` | 9277 | `stocksala` | 3000 |
| `comprobanteventa` | 150000 | `detalleventa` | 510382 |
| `auditoriaprecio` | 1 | **Total** | **745569** |

`vino` se fija en 600 para que `vinocepa` y `vinomaridaje` queden dentro del
rango recomendado de 300 a 1000 filas.

## Reproducibilidad

- Semilla fija `20261101` y fecha base fija `2026-11-01` (configurables).
- Un `random.Random` independiente por sección, derivado de `seed:seccion`.
- `Faker` con locale `es_AR` y `Faker.seed(seed)`.
- No se usa `date.today()` ni `CURRENT_TIMESTAMP` para generar datos.
- Dos ejecuciones con la misma semilla, escala y fecha base producen exactamente
  el mismo dataset.

## Estrategia de carga

1. Se generan todos los datos en memoria y se validan invariantes antes de
   tocar la base.
2. Se abre una única transacción y se deshabilitan los triggers de usuario de
   las tablas indicadas abajo. Así se puede cargar el historial sin que los
   triggers operativos (fecha actual, bloqueo de renglones, descuento de stock)
   rechacen los datos.
3. Las tablas se cargan en orden topológico con la estrategia elegida:
   `COPY` por defecto, `executemany` o `individual`.
4. La dependencia circular `Localidad → Empleado → SalaDeVenta → Localidad` se
   resuelve cargando `Localidad.cuit_encargado` en `NULL` y actualizándolo
   después de cargar `Empleado`.
5. Los totales de `ComprobanteVenta` se calculan en Python a partir de los
   renglones, con la misma fórmula de los triggers y funciones de la etapa 2.
6. Se ajustan las secuencias con `setval`, se ejecuta `ANALYZE` y se vuelven a
   habilitar los triggers.
7. Se ejecutan consultas de control antes del `COMMIT`. Cualquier fallo revierte
   toda la carga.

### Comparación de estrategias

El modo `--benchmark` genera un único dataset y lo inserta tres veces dentro de
transacciones con `force_rollback=True`: no modifica datos, secuencias ni
triggers al finalizar. Las tres corridas usan la misma semilla, fecha base y
escala.

Resultado con escala `1.0` (745.569 filas, triggers deshabilitados y FKs
activas):

| Estrategia | Inserción | Tiempo total | Filas/s | vs. individual |
|---|---:|---:|---:|---:|
| `copy` | 20,481 s | 21,975 s | 36.403,0 | 10,06x |
| `executemany` | 40,831 s | 42,412 s | 18.259,9 | 5,05x |
| `individual` | 206,065 s | 207,406 s | 3.618,1 | 1,00x |

La generación previa tardó 7,87 s. Los 15 controles dieron cero en las tres
estrategias. El detalle por tabla queda en `db/seed/benchmark_report.json`.

`COPY` es la estrategia usada por defecto porque es la más rápida y la que
mejor se adapta a una carga histórica masiva. `executemany` se incluye como
alternativa por lotes; `psycopg` 3 no expone `execute_values` de `psycopg2`.

## Manejo de triggers

| Tabla | Triggers deshabilitados | Motivo |
|---|---|---|
| `detalleventa` | `trg_renglon_1_completar`, `trg_renglon_2_valida_stock`, `trg_renglon_3_stock_y_totales` | Las ventas históricas no deben descontar stock actual ni recalcular totales ya calculados. |
| `transferencia` | `trg_transferencia_estado`, `trg_transferencia_fecha` | La fecha histórica no debe reemplazarse por `CURRENT_DATE`; los documentos se cargan ya terminados. |
| `detalleingreso` | `trg_detalle_ingreso_bloqueo` | El ingreso se carga cerrado y el trigger rechazaría sus renglones. |
| `detalletransferencia` | `trg_detalle_transferencia_bloqueo` | La transferencia se carga cerrada y el trigger rechazaría sus renglones. |
| `vino` | `trg_vino_auditoria_precio`, `trg_vino_suma_100` | Los precios son históricos; la composición se valida después de cargar todas las cepas. |
| `vinocepa` | `trg_vinocepa_suma_100` | La composición se controla al finalizar la carga. |

`trg_ingreso_estado` no se desactiva porque es `BEFORE UPDATE OF estado` y la
carga solo hace `INSERT`. Las claves foráneas siguen activas: son triggers
internos y `DISABLE TRIGGER USER` no las afecta.

Riesgos y mitigaciones:

- **Reglas de negocio suspendidas:** el `ALTER TABLE ... DISABLE TRIGGER USER`
  toma un lock exclusivo y la carga corre en una única transacción; se ejecuta
  en un entorno controlado y sin sesiones concurrentes.
- **Olvido de rehabilitar:** los `DISABLE` y `ENABLE` están en la misma
  transacción; cualquier error revierte ambos.
- **Datos inconsistentes:** se validan invariantes en Python y se ejecutan 15
  controles SQL antes del `COMMIT`.
- **Triggers de FK:** no se desactivan, por lo que las referencias siguen
  validadas fila por fila durante toda la carga.

## Controles

El script falla si alguna de estas consultas devuelve un valor distinto de cero:

- Triggers de usuario deshabilitados.
- Vinos cuya composición de cepas no suma 100.
- Comprobantes cuyos totales no coinciden con la suma de sus renglones.
- Comprobantes sin renglones.
- Stock negativo en depósito o sala.
- Renglones huérfanos de comprobante, vino, ingreso o transferencia.
- Lotes sin parcela, clientes sin localidad, empleados sin sala, vinos sin
  bodega o permisos sin exportador.
