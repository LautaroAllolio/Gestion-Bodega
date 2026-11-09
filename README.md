# Gestion-Bodega

Proyecto de Bases de Datos de la UTN FRSR 2026. Implementa el escenario de
Bodegas del Atuel en PostgreSQL: modelado, integridad, lógica en la base, carga
masiva reproducible, pruebas y documentación.

## Estructura

| Ruta | Contenido |
|---|---|
| `db/migrations/` | Esquema, constraints, funciones, procedimientos, triggers, vistas y roles |
| `db/seed/` | Catálogos CSV, generador `load.py` y documentación de la carga masiva |
| `db/tests/` | Pruebas de las reglas RN-01 a RN-15 y verificación de la carga |
| `db/dump_completo.sql.gz` | Volcado completo de la base cargada |
| `docs/` | Enunciado, DER, esquema relacional, diccionario e informe |
| `docs/informe.md` | Informe de pasos, decisiones, trazabilidad y concurrencia |

## Requisitos

- PostgreSQL 14 o superior.
- Python 3.10 o superior para la carga masiva.
- `psql`, `pg_dump` y `gzip` (o 7-Zip) disponibles.
- Dependencias de `db/seed/requirements.txt`.

## Puesta en marcha

### 1. Crear la base

```powershell
$env:PGPASSWORD = "<password>"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "CREATE DATABASE bodega_seed"
```

### 2. Aplicar las migraciones

Se ejecutan en orden. Cada archivo debe terminar sin errores antes de pasar al
siguiente:

```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$db = "bodega_seed"

& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/001_esquema.sql
& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/002_constraints.sql
& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/003_funciones.sql
& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/004_procedimientos.sql
& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/005_triggers.sql
& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/006_vistas.sql
& $psql -U postgres -d $db -v ON_ERROR_STOP=1 -f db/migrations/007_roles.sql
```

### 3. Cargar los datos

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r db/seed/requirements.txt
$env:PGPASSWORD = "<password>"
$env:PGDATABASE = "bodega_seed"
.\.venv\Scripts\python.exe db/seed/load.py --reset --scale 1.0
```

La semilla es fija (`20261101`) y la fecha base por defecto es `2026-11-01`.
Para que las consultas que dependen de `CURRENT_DATE` tengan datos cercanos a la
fecha de la defensa, recargar con una fecha base reciente:

```powershell
.\.venv\Scripts\python.exe db/seed/load.py --reset --scale 1.0 --base-date 2026-11-20
```

El detalle de volúmenes, estrategias y controles está en `db/seed/README.md`.

### 4. Ejecutar las pruebas

```powershell
# No usar ON_ERROR_STOP: hay casos que deben fallar con un error esperado.
& $psql -U postgres -d bodega_seed -f db/tests/db_tests.sql
& $psql -U postgres -d bodega_seed -v ON_ERROR_STOP=1 -f db/tests/verificacion_etapa3.sql
```

`db_tests.sql` incluye casos que deben funcionar y casos que deben fallar con un
error esperado; los comentarios indican el SQLSTATE. `verificacion_etapa3.sql`
ejecuta 22 controles y falla si alguno devuelve un valor distinto de cero.

### 5. Roles

`007_roles.sql` crea los roles `bodega_propietario`, `bodega_api` y
`bodega_lectura`. Las contraseñas no se versionan: se asignan en el despliegue
con `ALTER ROLE ... PASSWORD` usando variables de entorno.

## Volcado y restauración

El volcado se genera sin propietarios ni privilegios para que no dependa de los
roles del clúster:

```powershell
$pgdump = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"
& $pgdump -U postgres -d bodega_seed --no-owner --no-privileges -f db/dump_completo.sql
gzip -9 -f db/dump_completo.sql
```

El archivo versionado es `db/dump_completo.sql.gz`. Su tamaño y checksum
actuales son (hay que regenerarlo y actualizar estos valores después de cambiar
funciones, triggers o datos):

```text
10.105.169 bytes
SHA-256 08d0915c4a6f890ffc845e8c0632cc34a4a9fb340b244245a7ca9f1f709230b1
```

El volcado actual incluye la versión corregida de `fn_descuento_cliente`, que lee
`Cliente.descuento_porcentaje` en lugar de aplicar un porcentaje fijo por tipo.

Para verificar el checksum:

```powershell
Get-FileHash db\dump_completo.sql.gz -Algorithm SHA256
```

Para restaurar en una base vacía:

```powershell
& $psql -U postgres -d postgres -c "CREATE DATABASE bodega_restore"
gzip -dc db/dump_completo.sql.gz | & $psql -U postgres -d bodega_restore -v ON_ERROR_STOP=1
& $psql -U postgres -d bodega_restore -v ON_ERROR_STOP=1 -f db/migrations/007_roles.sql
```

El último paso es necesario porque el volcado usa `--no-privileges`; los roles y
sus permisos se recrean con la migración `007`.

## Documentación

- `docs/TPI_Bodegas_del_Atuel.pdf`: enunciado del trabajo.
- `docs/informe.md`: informe de las etapas, decisiones de diseño, trazabilidad
  RN-01 a RN-15 y demostración de concurrencia.
- `docs/Diagrama DER/`: DER en imagen y fuente editable.
- `docs/Diagrama Relacional/`: esquema relacional.
- `docs/Diccionario/`: diccionario de datos.
- `db/seed/README.md`: procedimiento detallado de la carga masiva.

## Notas

- No se guardan contraseñas ni secretos en el repositorio.
- La API no debe recalcular totales, descuentos ni stock: debe llamar a las
  funciones y procedimientos de la base.
- El volcado actual fue generado con PostgreSQL 18.3 y 745.569 filas.
