## Informe por escrito de pasos y decisiones

# Etapa 1

    - 1 (Pasetti): Subrayamos entidades, atributos, relaciones y cardinalidades
    - 2 (Allolio y Gimenez): Elaboramos el DER

# Etapa 2

## Funciones implementadas (`003_funciones.sql`)

Se implementaron cuatro funciones de solo lectura. Todas son `STABLE` porque consultan tablas o dependen de `CURRENT_DATE`; ninguna es `IMMUTABLE`.

| Función | Regla | Propósito | Parámetros | Retorno | Volatilidad |
|---|---|---|---|---|---|
| `fn_total_comprobante` | RN-08 | Total del comprobante a partir de sus renglones con descuento | `p_nro_comprobante integer` | `numeric(12,2)` | `STABLE` |
| `fn_stock_sala` | RN-09 | Stock de un vino en una sala; 0 si no existe | `p_id_sala integer`, `p_codigo_vino varchar(50)` | `integer` | `STABLE` |
| `fn_descuento_cliente` | RN-06 | Descuento según tipo de cliente: Socio 10 %, Distribuidor 20 %, Exportador 30 % | `p_id_cliente integer` | `numeric(5,2)` | `STABLE` |
| `fn_antiguedad_anios` | U2 / D3 | Años cumplidos desde una fecha de ingreso | `p_fecha_ingreso date` | `integer` | `STABLE` |

### Decisiones de diseño

- `fn_total_comprobante` suma `DetalleVenta.subtotal` para no duplicar la fórmula del descuento por renglón. El trigger de la etapa 2 será el encargado de mantener actualizado ese subtotal y el total de la cabecera.
- `fn_stock_sala` devuelve `0` cuando no existe fila en `StockSala`, de modo que la validación de RN-09 rechace la venta por stock insuficiente.
- `fn_descuento_cliente` es la fuente de verdad del RN-06. La columna `Cliente.descuento_porcentaje` sigue respaldada por su CHECK de rango entre 0 y 100.
- `fn_antiguedad_anios` usa `CURRENT_DATE`, por eso es `STABLE` y no `IMMUTABLE`. No se utiliza dentro de un CHECK, tal como advierte el PDF.
- Los casos de prueba de estas funciones se incorporarán a `db/tests/db_tests.sql` cuando se completen los triggers y procedimientos de la etapa.

## Procedimientos transaccionales (`004_procedimientos.sql`)

| Procedimiento | Regla | Propósito | Parámetros | Efecto |
|---|---|---|---|---|
| `sp_procesar_ingreso` | RN-10 | Procesa un ingreso terminado y lo pasa a procesado | `p_id_ingreso integer` | Suma botellas a `StockDeposito` |
| `sp_procesar_transferencia` | RN-11 | Procesa una transferencia terminada | `p_nro_transferencia integer` | Descuenta del depósito y suma a `StockSala` |

### Decisiones de diseño

- Se bloquean las filas del documento, sus renglones y las filas de stock con `FOR UPDATE`.
- El orden de bloqueo es documento → renglones → stock del depósito → stock de la sala, ordenando por `codigo_vino` para evitar deadlocks.
- Los ingresos crean la fila de `StockDeposito` si no existe.
- Las transferencias rechazan el procesamiento si falta la fila de stock del depósito o si la cantidad es insuficiente, cubriendo el caso advertido en el Anexo A.6.
- Los procedimientos no hacen `COMMIT` ni `ROLLBACK`: la atomicidad queda garantizada por la transacción del llamador.
- Solo se permite la transición `terminado → procesado`; no se reprocesa un documento.
- Los triggers de estados, bloqueo de renglones y fecha de confección se implementan en `005_triggers.sql`.
- Los casos de prueba de los procedimientos se incorporarán a `db/tests/db_tests.sql` junto con el resto de las pruebas de la etapa.

## Triggers implementados (`005_triggers.sql`)

| Trigger | Evento | Regla | Qué garantiza |
|---|---|---|---|
| `trg_renglon_1_completar` | `BEFORE INSERT` en `DetalleVenta` | RN-06, RN-08 | Completa precio unitario, descuento del cliente y subtotal del renglón; no se cargan a mano |
| `trg_renglon_2_valida_stock` | `BEFORE INSERT` en `DetalleVenta` | RN-09 | Rechaza la venta si la sala no tiene stock; bloquea la fila con `FOR UPDATE` |
| `trg_renglon_3_stock_y_totales` | `AFTER INSERT` en `DetalleVenta` | RN-08, RN-09 | Descuenta stock de la sala y recalcula subtotal, descuento y total del comprobante |
| `trg_ingreso_estado` / `trg_transferencia_estado` | `BEFORE UPDATE OF estado` | RN-10, RN-11 | Solo permite `en_confeccion → terminado → procesado`, sin retrocesos |
| `trg_transferencia_fecha` | `BEFORE INSERT OR UPDATE OF fecha_confeccion` | RN-11 | Fuerza la fecha actual al insertar y prohíbe modificarla |
| `trg_detalle_ingreso_bloqueo` / `trg_detalle_transferencia_bloqueo` | `BEFORE INSERT/UPDATE/DELETE` en renglones | RN-12 | No admite cambios en renglones si el documento no está en `en_confeccion` |
| `trg_vino_auditoria_precio` | `AFTER UPDATE OF precio_venta` en `Vino` | RN-13 | Audita precio anterior, precio nuevo, fecha y usuario |
| `trg_vinocepa_suma_100` / `trg_vino_suma_100` | `CONSTRAINT TRIGGER` diferido | RN-05 | Al cerrar la transacción, los porcentajes de corte de cada vino suman 100 |

### Decisiones de diseño

- El orden de los triggers de `DetalleVenta` está fijado por el prefijo numérico del nombre: primero se completa el renglón, después se valida el stock y por último se descuenta y se recalculan los totales.
- `trg_renglon_1_completar` bloquea la cabecera del comprobante con `FOR UPDATE`. Así, dos altas simultáneas de renglones del mismo comprobante se serializan y la segunda recalcula los totales viendo el renglón de la primera.
- `trg_renglon_2_valida_stock` usa `FOR UPDATE` sobre `StockSala`. Si dos sesiones intentan vender la última botella, la segunda espera a que la primera termine y luego falla por stock insuficiente; el stock nunca queda negativo.
- Los triggers de estado usan el tipo ENUM y solo habilitan las transiciones hacia adelante. Los procedimientos de `004_procedimientos.sql` son los que mueven el stock y cambian el estado.
- Los triggers de bloqueo de renglones usan `FOR SHARE` sobre la cabecera para que el documento no cambie de estado mientras se carga un renglón. Si la cabecera ya no existe por un borrado en cascada, el trigger permite borrar los renglones.
- RN-05 se implementa con `CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED` para permitir cargar las cepas de a una dentro de la misma transacción; la validación ocurre al hacer `COMMIT`. Por eso un vino debe insertarse junto con su composición.
- La auditoría de precios usa `CURRENT_USER` y el `DEFAULT CURRENT_TIMESTAMP` de `AuditoriaPrecio.fecha_hora`; el trigger solo inserta precio anterior, precio nuevo y usuario.
- Para la carga masiva de la etapa 3 se pueden deshabilitar temporalmente los triggers de usuario y volver a habilitarlos, validando la composición de los vinos con consultas de control.
- Los casos de prueba de los triggers se incorporarán a `db/tests/db_tests.sql` junto con el resto de las pruebas de la etapa.

# Etapa 3

## Catálogos reales (Anexo B)

El paso 1 de la etapa pide cargar los catálogos reales desde archivos CSV, sin generarlos al azar. Los archivos se guardan en `db/seed/` con codificación UTF-8, encabezado, coma como separador e identificadores explícitos y determinísticos, de modo que dos ejecuciones del futuro script de carga produzcan los mismos datos.

| Archivo | Tabla destino | Filas | Columnas | Fuente |
|---|---|---|---|---|
| `cepas.csv` | `Cepa` | 12 | `id_cepa`, `nombre`, `tipo` | Anexo B.1 |
| `maridajes.csv` | `Maridaje` | 8 | `id_maridaje`, `nombre`, `temperatura_servicio` | Anexo B.2 |
| `tipos_vino.csv` | — (catálogo de referencia) | 4 | `tipo` | Anexo B.4 |
| `departamentos.csv` | `Departamento` | 18 | `id_departamento`, `nombre`, `provincia` | Anexo B.3 |
| `localidades.csv` | `Localidad` | 18 | `id_localidad`, `nombre`, `provincia`, `codigo_postal`, `cuit_encargado` | Anexo B.3 (capitales) |

### Contenido de los catálogos

- **Cepas (12):** 7 tintas (Malbec, Cabernet Sauvignon, Merlot, Syrah, Bonarda, Tempranillo y Pinot Noir) y 5 blancas (Chardonnay, Sauvignon Blanc, Torrontés, Chenin Blanc y Semillón).
- **Maridajes (8):** Carnes rojas (17 °C), Quesos duros (16 °C), Pastas con salsa roja (16 °C), Carnes blancas (12 °C), Quesos blandos (10 °C), Pescados y mariscos (8 °C), Entradas y fiambres (10 °C) y Postres (8 °C).
- **Tipos de vino (4):** Tinto, Blanco, Rosado y Espumante, con la misma grafía que exige el `CHECK` de `Vino.tipo`.
- **Departamentos y localidades (18):** se tomó una localidad cabecera por cada departamento del Anexo B.3.

| ID | Departamento | Localidad cabecera | Código postal |
|---|---|---|---|
| 1 | San Rafael | San Rafael | 5600 |
| 2 | General Alvear | General Alvear | 5620 |
| 3 | Malargüe | Malargüe | 5613 |
| 4 | Luján de Cuyo | Luján de Cuyo | 5507 |
| 5 | Maipú | Maipú | 5515 |
| 6 | Tupungato | Tupungato | 5561 |
| 7 | Tunuyán | Tunuyán | 5560 |
| 8 | San Carlos | Villa San Carlos | 5569 |
| 9 | Lavalle | Villa Tulumaya | 5533 |
| 10 | Rivadavia | Rivadavia | 5577 |
| 11 | Junín | Junín | 5573 |
| 12 | San Martín | San Martín | 5570 |
| 13 | Santa Rosa | Santa Rosa | 5596 |
| 14 | La Paz | La Paz | 5590 |
| 15 | Godoy Cruz | Godoy Cruz | 5501 |
| 16 | Guaymallén | Villa Nueva | 5521 |
| 17 | Las Heras | Las Heras | 5539 |
| 18 | Capital | Mendoza | 5500 |

### Decisiones de diseño

- Se usan IDs enteros explícitos en los CSV en lugar de dejar que la base los genere: así las claves foráneas de las etapas posteriores son predecibles y la carga es reproducible con semilla fija.
- `tipos_vino.csv` es un catálogo de referencia y no tiene tabla destino. El esquema no define una tabla `TipoVino`; la fuente de verdad es el `CHECK` de `Vino.tipo`, y el futuro generador de vinos toma de este CSV los cuatro valores válidos.
- `Localidad` no tiene clave foránea hacia `Departamento` en el esquema de la etapa 1. Los departamentos se usan para las fincas y como referencia para definir las capitales departamentales; por eso `localidades.csv` no incluye una columna `departamento` y la correspondencia queda documentada en la tabla anterior.
- `cuit_encargado` se carga vacío (NULL) porque referencia a `Empleado` y existe una dependencia circular `Localidad → Empleado → SalaDeVenta → Localidad`. Se completará recién después de cargar salas y empleados.
- Los acentos se conservan en UTF-8 (Malargüe, Luján de Cuyo, Guaymallén, Torrontés, Semillón, Junín, Maipú). Los valores de `tipo` de cepa y de vino respetan las mayúsculas y la ortografía de los `CHECK` del esquema.
- Todos los datos respetan las restricciones existentes: tipo de cepa en `{Tinta, Blanca}`, temperatura de maridaje entre 5 y 25, y nombres de localidad únicos dentro de la provincia.

## Script de carga masiva (`db/seed/load.py`)

El segundo paso de la etapa pide un script reproducible que genere y cargue el volumen de datos. Se implementó en Python 3 con `psycopg` 3, `Faker` (locale `es_AR`) y `random`, con semilla fija `20261101` y fecha base `2026-11-01` (ambas configurables). Las dependencias están en `db/seed/requirements.txt` y el procedimiento completo en `db/seed/README.md`.

### Ejecución

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r db/seed/requirements.txt
$env:PGPASSWORD = "<password>"
.\.venv\Scripts\python.exe db/seed/load.py --dry-run --scale 0.01
.\.venv\Scripts\python.exe db/seed/load.py --reset --scale 1.0
```

Opciones: `--dsn`, `--reset`, `--scale`, `--strategy`, `--seed`, `--base-date`, `--dry-run`, `--report`, `--benchmark`, `--benchmark-scale` y `--benchmark-report`. Sin `--reset`, el script aborta si la base ya tiene datos.

Para comparar estrategias sin modificar la base:

```powershell
.\.venv\Scripts\python.exe db/seed/load.py --benchmark --benchmark-scale 1.0 `
  --benchmark-report db/seed/benchmark_report.json
```

### Volúmenes cargados (escala 1.0)

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

`vino` se fija en 600 en lugar de 800 para que `vinocepa` y `vinomaridaje` queden dentro del rango recomendado de 300 a 1000 filas.

### Decisiones de carga

- **Reproducibilidad:** un `random.Random` independiente por sección derivado de `seed:seccion`, `Faker.seed(seed)` y ninguna dependencia de `date.today()` ni `CURRENT_TIMESTAMP`. La generación se probó dos veces con la misma semilla y produjo datasets idénticos.
- **Validación previa:** antes de conectarse, el script verifica claves primarias únicas, referencias existentes, composición de vinos, subtotales de renglones, totales de comprobantes, stock no negativo y coherencia del descuento por tipo de cliente.
- **Orden topológico:** catálogos, bodegas, transportistas y depósito; localidades; salas y empleados; fincas, parcelas, lotes y análisis; clientes y subtipos; vinos, composición, maridajes y stock; ingresos y transferencias; ventas y auditoría.
- **Dependencia circular:** `Localidad → Empleado → SalaDeVenta → Localidad` se resuelve cargando `cuit_encargado` en `NULL` y actualizándolo después de cargar `Empleado`.
- **Estrategia eficiente:** la carga usa `COPY` por defecto; `--strategy` permite probar `executemany` e `individual`. Las tres variantes comparten generación, orden topológico y controles.
- **Triggers:** dentro de una única transacción se deshabilitan los triggers de usuario de `DetalleVenta`, `Transferencia`, `DetalleIngreso`, `DetalleTransferencia`, `Vino` y `VinoCepa`, se carga, se habilitan de nuevo y se ejecutan controles. Un fallo revierte todo, incluidos los `DISABLE/ENABLE`.
- **Totales:** los importes de `ComprobanteVenta` se calculan en Python con la misma fórmula que los triggers de la etapa 2 (subtotal bruto, descuento en monto y total neto).
- **Secuencias:** después de insertar IDs explícitos se ejecuta `setval` para las 14 tablas con `serial`, y `ANALYZE` al final.
- **Controles:** el script falla si quedan triggers de usuario deshabilitados, si hay vinos cuya composición no suma 100, comprobantes con totales inconsistentes o sin renglones, stock negativo, renglones huérfanos o referencias faltantes en las relaciones principales.

### Eficiencia de carga

Se agregó el modo `--benchmark`, que genera un único dataset y lo inserta con `copy`, `executemany` e `individual` dentro de transacciones con `force_rollback=True`. Así se comparan tiempos sin alterar datos, secuencias ni triggers. Las tres corridas usan las mismas 745.569 filas, con triggers deshabilitados y claves foráneas activas.

| Estrategia | Inserción | Tiempo total | Filas/s | vs. individual |
|---|---:|---:|---:|---:|
| `copy` | 20,481 s | 21,975 s | 36.403,0 | 10,06x |
| `executemany` | 40,831 s | 42,412 s | 18.259,9 | 5,05x |
| `individual` | 206,065 s | 207,406 s | 3.618,1 | 1,00x |

La generación previa tardó 7,87 s y los 15 controles dieron cero en las tres estrategias. `COPY` resultó 10,06 veces más rápido que la inserción fila por fila y 2 veces más rápido que el lote con `executemany`; por eso es la estrategia por defecto. `psycopg` 3 no expone `execute_values` de `psycopg2`, así que la alternativa por lotes se implementó con `executemany`. El detalle por tabla quedó en `db/seed/benchmark_report.json`.

### Manejo de triggers en la carga histórica

| Tabla | Triggers deshabilitados | Motivo |
|---|---|---|
| `DetalleVenta` | `trg_renglon_1_completar`, `trg_renglon_2_valida_stock`, `trg_renglon_3_stock_y_totales` | Las ventas históricas no deben descontar stock actual ni recalcular totales ya calculados. |
| `Transferencia` | `trg_transferencia_estado`, `trg_transferencia_fecha` | La fecha histórica no debe reemplazarse por `CURRENT_DATE`; los documentos se cargan terminados. |
| `DetalleIngreso` | `trg_detalle_ingreso_bloqueo` | El ingreso se carga cerrado y el trigger rechazaría sus renglones. |
| `DetalleTransferencia` | `trg_detalle_transferencia_bloqueo` | La transferencia se carga cerrada y el trigger rechazaría sus renglones. |
| `Vino` | `trg_vino_auditoria_precio`, `trg_vino_suma_100` | Los precios son históricos; la composición se valida al final. |
| `VinoCepa` | `trg_vinocepa_suma_100` | La composición se controla después de cargar todas las cepas. |

`trg_ingreso_estado` no se desactiva porque es `BEFORE UPDATE OF estado` y la carga solo hace `INSERT`. Las claves foráneas siguen activas porque son triggers internos y `DISABLE TRIGGER USER` no las desactiva.

Riesgos asumidos y mitigaciones:

- **Reglas suspendidas:** el `ALTER TABLE ... DISABLE TRIGGER USER` toma un lock exclusivo y la carga corre en una única transacción, en un entorno controlado y sin sesiones concurrentes.
- **Olvido de rehabilitar:** los `DISABLE` y `ENABLE` están en la misma transacción; cualquier error revierte ambos.
- **Datos inconsistentes:** se validan invariantes en Python y se ejecutan 15 controles SQL antes del `COMMIT`.
- **Referencias:** las FK no se desactivan, por lo que se validan fila por fila durante toda la carga.

### Resultado de la prueba

Sobre `bodega_seed` con las migraciones `001` a `007`, la carga completa terminó en 20,5 segundos, con 745.569 filas y los 15 controles en cero. También se verificó que todos los triggers quedaron habilitados, que las 18 localidades tienen encargado, que las 14 secuencias quedaron por encima del máximo ID y que los 600 vinos tienen composición.

El benchmark completo se ejecutó sin alterar la base: se verificaron los conteos de `DetalleVenta`, `ComprobanteVenta`, `Vino` y `Cliente`, y que no quedaran triggers deshabilitados. La carga normal se probó además en una base temporal `bodega_smoke` con `--scale 0.01` para `copy` y `executemany`, con los 15 controles en cero.

### Verificación final y volcado

Se agregó `db/tests/verificacion_etapa3.sql`, un script independiente del cargador que ejecuta 22 controles y falla si alguno devuelve un valor distinto de cero:

```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d bodega_seed `
  -v ON_ERROR_STOP=1 -f db/tests/verificacion_etapa3.sql
```

| Categoría | Controles | Resultado |
|---|---:|---:|
| Stock negativo en depósito o sala | 2 | 0 |
| Coherencia de importes y composición | 6 | 0 |
| Huérfanos en relaciones principales | 11 | 0 |
| Integridad global (FK, triggers, encargados) | 3 | 0 |

Los 22 controles dieron cero. El volcado se generó con `pg_dump` 18.3 en formato SQL plano, sin propietarios ni privilegios, y se comprimió con gzip:

```text
db/dump_completo.sql.gz
10.106.395 bytes
SHA-256 45cf607865aa4aa331e0cca0fdc7cbcbf02e384ca3d193fea78081d3fdc949ff
31 bloques COPY · 745.569 filas
```

Se probó la restauración en una base temporal `bodega_restore`: las 31 tablas y las 745.569 filas coincidieron con `bodega_seed`, y los 22 controles volvieron a dar cero. Luego se eliminó la base temporal. Al usar `--no-owner --no-privileges`, el volcado no depende de los roles del clúster; para recrearlos se ejecuta `db/migrations/007_roles.sql` después de restaurar.

# Etapa 4

# Etapa 5

# Etapa 6

# Etapa 7

# Etapa 8

# Etapa 9