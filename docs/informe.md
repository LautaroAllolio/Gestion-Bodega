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

# Etapa 4

# Etapa 5

# Etapa 6

# Etapa 7

# Etapa 8

# Etapa 9