## Informe por escrito de pasos y decisiones

# Etapa 1

## Entregables

| Entregable | Archivo |
|---|---|
| DER (imagen) | `docs/Diagrama DER/DER_BODEGA_2.0.drawio.png` |
| DER (fuente editable) | `docs/Diagrama DER/DER_BODEGA_2.0.drawio` |
| Esquema relacional | `docs/Diagrama Relacional/Relacional_Bodega.EAP` |
| Esquema relacional (1FN) | `docs/Diagrama Relacional/Relacional_BD_1NF.EAP` |
| Imagen del modelo lógico | `docs/Diagrama Relacional/Logical Model.bmp` |
| Diccionario de datos | `docs/Diccionario/Diccionario_Datos_Bodegas_del_Atuel-v3.pdf` |
| DDL del esquema | `db/migrations/001_esquema.sql` |
| Restricciones de integridad | `db/migrations/002_constraints.sql` |

## DER

El DER usa una notación consistente para entidades, atributos, claves, cardinalidades mínima y máxima, entidades débiles y relaciones N:M con atributos. Las decisiones principales son:

- **Entidad débil `Parcela`:** depende de `Finca`; su clave es compuesta `(nro_parcela, id_finca)` y no existe sin la finca.
- **Jerarquía de `Cliente`:** supertipo `Cliente` con los subtipos `SocioClub`, `Distribuidor` y `Exportador`. El supertipo concentra los datos comunes y cada subtipo agrega sus atributos propios.
- **Relaciones N:M con atributos:** `VinoCepa` (porcentaje de corte), `VinoMaridaje`, `TransportistaLocalidad` y los renglones de comprobante, ingreso y transferencia.
- **Cardinalidades:** una bodega elabora muchos vinos; un vino pertenece a una bodega; una finca tiene muchas parcelas; una parcela produce muchos lotes de uva; un comprobante tiene muchos renglones y cada renglón referencia un vino; una sala tiene stock de muchos vinos y un vino puede estar en muchas salas.
- **Catálogos:** `Cepa`, `Maridaje`, `Departamento`, `Localidad` y `Transportista` se modelan como entidades independientes para evitar duplicar descripciones.

La imagen del DER y su archivo fuente están enlazados en la tabla de entregables; el DER completo se entrega junto con este informe.

![DER de Bodegas del Atuel](Diagrama%20DER/DER_BODEGA_2.0.drawio.png)

## Esquema relacional

La transformación del DER al modelo relacional sigue estas reglas:

- Una relación por entidad y una relación por cada N:M. Las claves primarias se declaran en `001_esquema.sql` y las restricciones adicionales en `002_constraints.sql`.
- `Parcela` conserva la clave compuesta `(nro_parcela, id_finca)` y una FK `id_finca → Finca(id_finca)`.
- La jerarquía de clientes se mapea con **supertipo más subtipos**: `Cliente(id_cliente)` es el supertipo y `SocioClub`, `Distribuidor` y `Exportador` tienen `id_cliente` como PK y FK hacia `Cliente`. Así los atributos propios de cada subtipo no quedan como columnas nulas en una tabla única.
- Los renglones (`DetalleVenta`, `DetalleIngreso`, `DetalleTransferencia`) son relaciones débiles de su cabecera y usan claves compuestas. `VinoCepa` usa `(codigo_vino, id_cepa)`; `StockSala` usa `(id_sala, codigo_vino)`.
- `TransportistaLocalidad` y `VinoMaridaje` no tienen atributos propios y usan claves compuestas.
- `AuditoriaPrecio` es una relación independiente con PK subrogada `id_auditoria` y FK hacia `Vino`.

### Claves naturales y subrogadas

| Relación | Clave | Tipo | Justificación |
|---|---|---|---|
| `Bodega` | `cuit` | Natural | Es el identificador real de la bodega, estable y usado por las FK de ingresos, lotes y vinos. |
| `Empleado` | `cuit` | Natural | Identificador real y estable; se usa como encargado de localidad. |
| `Vino` | `codigo_vino` | Natural | Código de negocio que aparece en renglones, stock y auditoría. |
| `Cliente` | `id_cliente` | Subrogada | El CUIT no se declara único y el cliente puede cambiar de datos; el identificador interno evita propagar cambios. |
| `Localidad` | `id_localidad` | Subrogada | Se agrega `UNIQUE (nombre, provincia)` como clave candidata natural; el ID simplifica las FK. |
| `ComprobanteVenta` | `nro_comprobante` | Subrogada | La numeración la administra el sistema y no depende de datos del negocio. |
| `Parcela` | `(nro_parcela, id_finca)` | Natural compuesta | Es una entidad débil: el número de parcela solo es único dentro de su finca. |

## Normalización hasta 3FN

Las dependencias funcionales relevantes son:

- `Cliente`: `id_cliente → apellido, nombre, cuit, tipo_cliente, tipo_documento, nro_documento, calle_cliente, nro_calle_cliente, id_localidad, fecha_alta, descuento_porcentaje`. La PK es simple, por lo que no hay dependencias parciales. `tipo_cliente → descuento_porcentaje` no es una dependencia funcional global porque el escenario permite descuentos especiales por cliente (por ejemplo, exportadores con más de tres permisos al 35 %); por eso el descuento efectivo se guarda en la columna y no se deriva del tipo.
- `Localidad`: `id_localidad → nombre, provincia, codigo_postal, cuit_encargado`; `(nombre, provincia)` es clave candidata. No hay dependencias transitivas dentro de la relación.
- `Vino`: `codigo_vino → nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega`; `(nombre_comercial, anada, presentacion_ml)` es clave candidata.
- `ComprobanteVenta`: `nro_comprobante → fecha, id_cliente, id_sala, subtotal, descuento, total`.
- `DetalleVenta`: `(nro_comprobante, codigo_vino) → cantidad, precio_unitario, descuento_aplicado, subtotal`. `precio_unitario` y `descuento_aplicado` son valores históricos del renglón, no del vino actual; dependen de la clave completa. `subtotal` depende de la clave completa y se mantiene por trigger.
- `DetalleIngreso`: `(id_ingreso, codigo_vino) → cantidad_botellas`.
- `DetalleTransferencia`: `(nro_transferencia, codigo_vino) → cantidad`.
- `VinoCepa`: `(codigo_vino, id_cepa) → porcentaje_corte`; la clave es completa.
- `StockSala`: `(id_sala, codigo_vino) → cantidad`.
- `StockDeposito`: `(id_deposito, codigo_vino) → cantidad`.
- `PermisoExportacion`: `id_permiso → id_cliente, codigo_permiso, fecha_emision, fecha_vencimiento`.
- `Empleado`: `cuit → nombre, apellido, salario, id_sala`.
- `Parcela`: `(nro_parcela, id_finca) → superficie, anio_plantacion, id_cepa`; no hay dependencias parciales porque `superficie`, `anio_plantacion` e `id_cepa` dependen de la parcela completa.
- `TransportistaLocalidad` y `VinoMaridaje`: solo contienen la clave compuesta, sin atributos no clave.

En todas las relaciones los atributos no clave dependen de la clave completa y no existen dependencias transitivas dentro de la misma relación. Las referencias entre relaciones se resuelven con FK, no duplicando datos. Por eso el esquema está en 3FN.

Los importes usan `NUMERIC(p,s)` y nunca `FLOAT`; las fechas usan `DATE` o `TIMESTAMP`; los estados usan el ENUM `estado_documento` o columnas con CHECK, no texto libre.

## Decisiones de diseño de la sección 5

### Jerarquía de clientes

Se eligió **supertipo más subtipos**. Ventajas: los atributos comunes viven en `Cliente`, cada subtipo tiene solo sus columnas obligatorias y se pueden agregar subtipos sin llenar de nulos la tabla principal. Desventajas: consultar un cliente completo requiere unir el supertipo con su subtipo y la exclusividad de subtipos debe cuidarse en la carga o en la API. Se descartó la tabla única porque obligaría a columnas nulas y CHECK condicionales, y se descartó una tabla por subtipo porque duplicaría los datos comunes y complicaría las FK de comprobantes.

### Tipos de datos

- Dinero y cantidades: `NUMERIC`, nunca `FLOAT`.
- Fechas: `DATE`; fecha y hora de auditoría: `TIMESTAMP`.
- Estados de documentos: ENUM `estado_documento` con `en_confeccion`, `terminado` y `procesado`.
- CUIT: DOMAIN `cuit_dom` de 11 caracteres.
- Tipos de cliente, vino, cepa y día de cierre: `varchar` con CHECK de valores permitidos.

### Atributos derivados

- `DetalleVenta.subtotal`, `ComprobanteVenta.subtotal`, `ComprobanteVenta.descuento` y `ComprobanteVenta.total` se almacenan como resultados históricos y los mantienen los triggers de la Etapa 2. La función `fn_total_comprobante` permite recalcular el total desde los renglones.
- `DetalleVenta.precio_unitario` y `DetalleVenta.descuento_aplicado` son copias históricas del precio y del descuento al momento de la venta; no se recalculan con los valores actuales del vino o del cliente.
- El stock se almacena en `StockDeposito` y `StockSala` y lo modifican los procedimientos y triggers; los CHECK impiden valores negativos.
- La consistencia de los derivados se garantiza con triggers, CHECK, funciones de recálculo y los controles de `db/tests/verificacion_etapa3.sql`.

### Acciones referenciales

- `ON DELETE RESTRICT` en los maestros con movimientos que no deben borrarse: `Vino`, `Bodega` y `Transportista`. También se usa en las referencias con historia de `Localidad` y `SalaDeVenta`. Así no se borra un maestro que todavía tiene operaciones asociadas.
- `ON DELETE CASCADE` en filas que no existen sin su cabecera: renglones de comprobante, ingreso y transferencia; subtipos de cliente; permisos de exportación; parcelas de una finca.
- `ON DELETE SET NULL` en `Localidad.cuit_encargado`, porque una localidad puede quedar temporalmente sin encargado.
- `ON UPDATE CASCADE` en claves naturales (`cuit`, `codigo_vino`, `id_localidad` cuando corresponde) para propagar un cambio de identificador; `ON UPDATE NO ACTION` en claves subrogadas, que no deberían cambiar.
- `ON DELETE NO ACTION` en catálogos y referencias sin historia propia (`Departamento`, `Cepa`, `Maridaje`, `DepositoCentral`) y en cabeceras que no deben desaparecer si tienen documentos asociados, para impedir borrados accidentales.

# Etapa 2

## Funciones implementadas (`003_funciones.sql`)

Se implementaron cuatro funciones de solo lectura. Todas son `STABLE` porque consultan tablas o dependen de `CURRENT_DATE`; ninguna es `IMMUTABLE`.

| Función | Regla | Propósito | Parámetros | Retorno | Volatilidad |
|---|---|---|---|---|---|
| `fn_total_comprobante` | RN-08 | Total del comprobante a partir de sus renglones con descuento | `p_nro_comprobante integer` | `numeric(12,2)` | `STABLE` |
| `fn_stock_sala` | RN-09 | Stock de un vino en una sala; 0 si no existe | `p_id_sala integer`, `p_codigo_vino varchar(50)` | `integer` | `STABLE` |
| `fn_descuento_cliente` | RN-06 | Descuento registrado en `Cliente.descuento_porcentaje` (por defecto 10 %, 20 % o 30 % según el tipo) | `p_id_cliente integer` | `numeric(5,2)` | `STABLE` |
| `fn_antiguedad_anios` | U2 / D3 | Años cumplidos desde una fecha de ingreso | `p_fecha_ingreso date` | `integer` | `STABLE` |

### Decisiones de diseño

- `fn_total_comprobante` suma `DetalleVenta.subtotal` para no duplicar la fórmula del descuento por renglón. El trigger de la etapa 2 será el encargado de mantener actualizado ese subtotal y el total de la cabecera.
- `fn_stock_sala` devuelve `0` cuando no existe fila en `StockSala`, de modo que la validación de RN-09 rechace la venta por stock insuficiente.
- `fn_descuento_cliente` es la fuente de verdad del RN-06: devuelve el valor almacenado en `Cliente.descuento_porcentaje`, que el CHECK de rango mantiene entre 0 y 100. El trigger de venta usa esa función, de modo que un descuento especial cargado en la columna se aplica sin cambiar el código de la base.
- `fn_antiguedad_anios` usa `CURRENT_DATE`, por eso es `STABLE` y no `IMMUTABLE`. No se utiliza dentro de un CHECK, tal como advierte el PDF.
- Los casos de prueba de estas funciones están en `db/tests/db_tests.sql`.

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
- Los casos de prueba de los procedimientos están en `db/tests/db_tests.sql`.

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
- Los casos de prueba de los triggers están en `db/tests/db_tests.sql`.

## Vistas implementadas (`006_vistas.sql`)

| Vista | Propósito | Reglas |
|---|---|---|
| `vw_stock_total_vino` | Stock total por vino, sumando depósito y salas | RN-09 |
| `vw_ventas_mensuales_sala` | Ventas mensuales agregadas por sala | RN-08 |
| `vw_documentos_pendientes` | Ingresos y transferencias que aún no están procesados | RN-10, RN-11 |

Las vistas son de solo lectura y se apoyan en las tablas y funciones ya implementadas; no recalculan reglas por fuera de la base.

## Roles y privilegios (`007_roles.sql`)

| Rol | Uso | Privilegios |
|---|---|---|
| `bodega_propietario` | Administración de la base | Uso y creación en `public`; todos los privilegios sobre tablas, secuencias, funciones y procedimientos |
| `bodega_api` | Lectura/escritura de la API | `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre tablas; secuencias; ejecución de funciones y procedimientos |
| `bodega_lectura` | Reportes | `SELECT` sobre tablas y ejecución de las cuatro funciones |

Se revocan los privilegios de `PUBLIC` sobre la base, el esquema, las tablas, las secuencias, las funciones y los procedimientos. Las contraseñas no se guardan en el repositorio: se asignan en el despliegue con `ALTER ROLE ... PASSWORD` a partir de variables de entorno.

La tabla `AuditoriaPrecio` es **append-only** para `bodega_api`: el trigger de auditoría inserta las filas y la API solo puede consultarlas. Por eso, después del `GRANT` general, se ejecuta:

```sql
REVOKE UPDATE, DELETE ON AuditoriaPrecio FROM bodega_api;
```

El `INSERT` se conserva porque el trigger se ejecuta con los privilegios del usuario que actualiza `Vino`.

## Trazabilidad RN-01 a RN-15

| Regla | Mecanismo en la base | Caso de prueba |
|---|---|---|
| RN-01 | `UNIQUE (nombre_comercial, anada, presentacion_ml)` + `CHECK (precio_venta > 0)` | `db_tests.sql`, sección RN-01 |
| RN-02 | FK `SalaDeVenta.id_localidad` + `Localidad.cuit_encargado` + diseño 3FN | `db_tests.sql`, sección RN-02 |
| RN-03 | FK `Empleado.id_sala` | `db_tests.sql`, sección RN-03 |
| RN-04 | `Parcela.id_cepa` + `UNIQUE (id_finca, nro_parcela, campania)` en `LoteUva` | `db_tests.sql`, sección RN-04 |
| RN-05 | `trg_vinocepa_suma_100` y `trg_vino_suma_100` (constraint trigger diferido) | `db_tests.sql`, sección RN-05 |
| RN-06 | `fn_descuento_cliente` + `CHECK (descuento_porcentaje BETWEEN 0 AND 100)` + `trg_renglon_1_completar` | `db_tests.sql`, sección RN-06 (incluye descuento especial de 12.50) |
| RN-07 | FK `PermisoExportacion.id_cliente` + `CHECK (fecha_vencimiento > fecha_emision)` | `db_tests.sql`, sección RN-07 |
| RN-08 | `fn_total_comprobante` + `trg_renglon_1_completar` + `trg_renglon_3_stock_y_totales` | `db_tests.sql`, sección RN-08 |
| RN-09 | `trg_renglon_2_valida_stock` + `trg_renglon_3_stock_y_totales` + CHECK de stock no negativo | `db_tests.sql`, sección RN-09 |
| RN-10 | `sp_procesar_ingreso` + `trg_ingreso_estado` | `db_tests.sql`, sección RN-10 |
| RN-11 | `sp_procesar_transferencia` + `trg_transferencia_estado` + `trg_transferencia_fecha` | `db_tests.sql`, sección RN-11 |
| RN-12 | `trg_detalle_ingreso_bloqueo` y `trg_detalle_transferencia_bloqueo` | `db_tests.sql`, sección RN-12 |
| RN-13 | `trg_vino_auditoria_precio` + tabla `AuditoriaPrecio` | `db_tests.sql`, sección RN-13 |
| RN-14 | FK con `ON DELETE RESTRICT` en `Vino`, `Bodega` y `Transportista` | `db_tests.sql`, sección RN-14 |
| RN-15 | CHECK de cantidades, precios, superficies, kilos y stock positivos o no negativos | `db_tests.sql`, sección RN-15 |

Cada caso de `db_tests.sql` incluye comentarios con el error esperado y el SQLSTATE cuando corresponde. Los casos que deben fallar se ejecutan dentro de `SAVEPOINT` y se revierten para no dejar datos inconsistentes.

## Dónde va cada regla

| Tipo de regla | Herramienta | Ejemplo en este esquema |
|---|---|---|
| Valor válido de una sola fila, calculable siempre | `NOT NULL`, `CHECK`, `DOMAIN` | `precio_venta > 0`, `cuit_dom` |
| Unicidad de una combinación | `UNIQUE` o PK | `(nombre_comercial, anada, presentacion_ml)` |
| Referencia entre relaciones | FK | `SalaDeVenta.id_localidad → Localidad` |
| Invariante entre varias filas o agregado | Función + trigger | suma de cortes 100, stock disponible |
| Transición de estados | Trigger `BEFORE UPDATE` | `en_confeccion → terminado → procesado` |
| Operación de varios pasos que debe ser atómica | Procedimiento transaccional | procesar una transferencia |
| Dato derivado que debe mantenerse consistente | Trigger y función de recálculo | subtotales y totales de comprobantes |
| Historia de cambios | Trigger `AFTER` | auditoría de precios |
| Seguridad y separación de responsabilidades | Roles, `GRANT` y `REVOKE` | `bodega_api`, `bodega_lectura` |

La regla general es usar la restricción más simple que exprese la regla. Si alcanza con un CHECK o una FK, no se usa un trigger; los triggers quedan para invariantes que involucran varias filas, estados o historia.

## Demostración de concurrencia

El escenario es la venta de la última botella de un vino en una sala. Se usan dos sesiones `psql` conectadas a la misma base y el nivel de aislamiento por defecto de PostgreSQL, `READ COMMITTED`. El ejemplo usa los identificadores de los datos de prueba de `db_tests.sql` (sala 9001, vino `VINO_TEST`, clientes 9001 y 9002); si se ejecuta sobre la base del seed, hay que reemplazarlos por valores existentes.

### Preparación

```sql
-- Dejar una sola botella disponible en la sala de prueba.
UPDATE StockSala
   SET cantidad = 1
 WHERE id_sala = 9001
   AND codigo_vino = 'VINO_TEST';
```

### Sesión A

```sql
BEGIN;
SELECT cantidad
  FROM StockSala
 WHERE id_sala = 9001
   AND codigo_vino = 'VINO_TEST'
   FOR UPDATE;              -- devuelve 1 y bloquea la fila
INSERT INTO ComprobanteVenta (fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (CURRENT_DATE, 9001, 9001, 0, 0, 0)
RETURNING nro_comprobante AS nro \gset
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (:nro, 'VINO_TEST', 1, 0, 0, 0);
COMMIT;                     -- el trigger descuenta la botella
```

### Sesión B

```sql
BEGIN;
SELECT cantidad
  FROM StockSala
 WHERE id_sala = 9001
   AND codigo_vino = 'VINO_TEST'
   FOR UPDATE;              -- queda esperando a que A termine
-- Cuando A hace COMMIT, esta consulta devuelve 0.
INSERT INTO ComprobanteVenta (fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (CURRENT_DATE, 9002, 9001, 0, 0, 0)
RETURNING nro_comprobante AS nro \gset
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (:nro, 'VINO_TEST', 1, 0, 0, 0);
-- ERROR ESPERADO: stock insuficiente (RN-09).
ROLLBACK;
```

Con `FOR UPDATE`, la segunda sesión no puede leer la fila mientras la primera la tiene bloqueada. Al continuar, ve el stock ya descontado y el trigger `trg_renglon_2_valida_stock` rechaza la venta. El stock nunca queda negativo.

Si se repite el experimento **sin** `FOR UPDATE`, ambas sesiones pueden leer `cantidad = 1` antes de que alguna escriba. Bajo `READ COMMITTED` cada sentencia ve la última versión confirmada, pero la lectura inicial no bloquea la fila. Sin el bloqueo, las dos podrían creer que hay stock y vender la misma botella; el trigger de validación y el `UPDATE` de stock con bloqueo son los que serializan la operación y evitan la doble venta. Por eso la base es la que protege la regla, no la aplicación.

Las capturas de las dos sesiones se incorporan a continuación:

- `![Concurrencia - sesión A](ruta/a/captura_sesion_a.png)` — pendiente de agregar.
- `![Concurrencia - sesión B](ruta/a/captura_sesion_b.png)` — pendiente de agregar.

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

Para la defensa conviene recargar con `--base-date` cercano a la fecha de la consulta, de modo que las consultas que usan `CURRENT_DATE` encuentren historial reciente. La semilla se mantiene, así que el dataset es el mismo salvo el desplazamiento de las fechas.

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

> **Pendiente de regeneración:** el volcado versionado se generó antes de corregir `fn_descuento_cliente` para leer `Cliente.descuento_porcentaje`. Hay que regenerarlo con el comando de `README.md` y actualizar el tamaño y el SHA-256 de esta sección. Hasta entonces, el hash anterior corresponde a la versión previa de la función.

# Etapa 4

# Etapa 5

# Etapa 6

# Etapa 7

# Etapa 8

# Etapa 9