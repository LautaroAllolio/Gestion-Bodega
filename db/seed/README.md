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
```

Sin `--reset`, el script aborta si detecta datos en `Cepa`, `Vino` o
`ComprobanteVenta`.

## Opciones

| Opción | Descripción |
|---|---|
| `--dsn` | Cadena de conexión completa. Tiene prioridad sobre las variables `PG*`. |
| `--reset` | Ejecuta `TRUNCATE ... RESTART IDENTITY CASCADE` sobre las 31 tablas. |
| `--scale` | Factor de escala de los volúmenes. Por defecto `1.0`. |
| `--seed` | Semilla del generador. Por defecto `20261101`. |
| `--base-date` | Fecha base ISO para el historial. Por defecto `2026-11-01`. |
| `--dry-run` | Genera y valida en memoria, sin conectarse a PostgreSQL. |
| `--report` | Escribe un JSON con conteos, tiempos y resultados de control. |

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
   `DetalleVenta`, `Transferencia`, `DetalleIngreso`, `DetalleTransferencia`,
   `Vino` y `VinoCepa`. Así se puede cargar el historial sin que los triggers
   operativos (fecha actual, bloqueo de renglones, descuento de stock) rechacen
   los datos.
3. Las tablas se cargan con `COPY` en orden topológico.
4. La dependencia circular `Localidad → Empleado → SalaDeVenta → Localidad` se
   resuelve cargando `Localidad.cuit_encargado` en `NULL` y actualizándolo
   después de cargar `Empleado`.
5. Los totales de `ComprobanteVenta` se calculan en Python a partir de los
   renglones, con la misma fórmula de los triggers y funciones de la etapa 2.
6. Se ajustan las secuencias con `setval`, se ejecuta `ANALYZE` y se vuelven a
   habilitar los triggers.
7. Se ejecutan consultas de control antes del `COMMIT`. Cualquier fallo revierte
   toda la carga.

## Controles

El script falla si alguna de estas consultas devuelve un valor distinto de cero:

- Vinos cuya composición de cepas no suma 100.
- Comprobantes cuyos totales no coinciden con la suma de sus renglones.
- Comprobantes sin renglones.
- Stock negativo en depósito o sala.
- Renglones huérfanos de comprobante, vino, ingreso o transferencia.
- Lotes sin parcela, clientes sin localidad, empleados sin sala, vinos sin
  bodega o permisos sin exportador.
