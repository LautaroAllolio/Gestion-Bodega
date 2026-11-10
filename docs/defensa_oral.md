# Defensa oral

Material de preparación para la defensa. Distribución de áreas por integrante, preguntas esperadas y tres ejercicios de modificación en vivo por integrante. Los ejercicios corren sobre el stack local de Docker Compose o sobre `bodega_seed` en el PostgreSQL local; salvo indicación contraria, se hacen dentro de `BEGIN ... ROLLBACK` para no alterar el dataset.

## Reparto de áreas

| Integrante | Áreas | Archivos clave |
|---|---|---|
| Pasetti23 | Modelo entidad-relación, esquema relacional, 3FN, diccionario de datos, constraints | `db/migrations/001_esquema.sql`, `002_constraints.sql`, `docs/Diagrama DER/`, `docs/Diccionario/`, secciones 2, 3 y 4.1–4.4 de `docs/Informe_Bodegas_del_Atuel.md` |
| LGG2405 | Funciones, triggers, procedimientos, concurrencia, carga masiva | `db/migrations/003` a `005`, `007`, `009_descuento_exportador.sql`, `db/seed/`, demo de concurrencia en `docs/informe.md` |
| LautaroAllolio | Índices y EXPLAIN, consultas SQL, API REST, front, Docker | `db/migrations/008_indices.sql`, `consultas/`, `api/`, `front/`, `docker-compose.yml` |

## Pasetti23 — Modelo y esquema

### Preguntas esperadas

- Por qué `codigo_vino` y no un id subrogado, y por qué `Cliente` usa `id_cliente` (clave subrogada) con CUIT natural indexado.
- Cómo se resolvió la jerarquía de clientes: supertipo `Cliente` + subtipos `SocioClub`, `Distribuidor`, `Exportador`; por qué esa versión y no una tabla por tipo ni una sola tabla con columnas nulas.
- Por qué `Parcela` es entidad débil de `Finca` (clave parcial `nro_parcela` + FK).
- Justificación de cada acción referencial: `RESTRICT` en `Vino`, `Bodega`, `Transportista` (RN-14); `CASCADE` en renglones y subtipos; `SET NULL` en `Localidad.cuit_encargado` y la FK diferible que resuelve la dependencia circular `Localidad → Empleado → SalaDeVenta → Localidad`.
- Qué garantiza 3FN y qué dependencias se aceptaron fuera (por ejemplo, `Cliente.descuento_porcentaje` derivable del tipo, persistido por RN-06).
- Diferencia entre `ENUM` (`estado_documento`), `DOMAIN` (`cuit_dom`) y `CHECK` de tabla.

### Ejercicios en vivo

1. **Unicidad RN-01.** Duplicar un vino existente:

   ```sql
   BEGIN;
   SELECT nombre_comercial, anada, presentacion_ml FROM Vino LIMIT 1;
   INSERT INTO Vino (codigo_vino, cuit_bodega, nombre_comercial, tipo, anada,
                     presentacion_ml, graduacion_alcoholica, precio_venta)
   SELECT 'V9999', cuit_bodega, nombre_comercial, tipo, anada,
          presentacion_ml, graduacion_alcoholica, precio_venta
     FROM Vino LIMIT 1;
   ROLLBACK;
   ```

   Falla con `23505` por `Uq_vino_nombre_anada_presentacion`.

2. **RN-14: borrar maestro con historia.** Elegir un vino con movimientos y borrarlo:

   ```sql
   BEGIN;
   DELETE FROM Vino WHERE codigo_vino = (SELECT codigo_vino FROM DetalleVenta LIMIT 1);
   ROLLBACK;
   ```

   Falla con `23503`: `ON DELETE RESTRICT` impide borrar un vino con ingresos, transferencias o ventas asociadas.

3. **Dominio y CHECK.** Poner un precio negativo:

   ```sql
   BEGIN;
   UPDATE Vino SET precio_venta = -1 WHERE codigo_vino LIKE 'V001%';
   ROLLBACK;
   ```

   Falla con `23514` por `Check_vino_precio`.

## LGG2405 — Lógica en la base

### Preguntas esperadas

- Dónde vive cada regla y por qué: `CHECK` para una fila, FK para referencialidad, función/trigger para varias filas o agregados, procedimiento para operaciones multi-tabla (tabla completa en `docs/informe.md`, sección "Dónde va cada regla").
- Por qué `fn_total_comprobante` suma `DetalleVenta.subtotal` en lugar de recalcular el descuento (el renglón guarda el histórico).
- RN-05 con `CONSTRAINT TRIGGER` diferidos: por qué la composición de cepas no se puede validar fila por fila al insertar.
- RN-06 completo: `fn_descuento_cliente` lee la columna, `trg_validar_descuento_cliente` rechaza descuentos que no corresponden al tipo (`P0001`), `fn_descuento_exportador` + `trg_sincronizar_descuento_exportador` mantienen 30 %/35 % según permisos (migración `009`), y por qué la regla se bajó de la API a la base.
- Estados `en_confeccion → terminado → procesado` (RN-10/11) y por qué los renglones se congelan fuera de `en_confeccion` (RN-12).
- `SELECT ... FOR UPDATE` en la prueba de concurrencia: qué pasa sin él (dos sesiones venden el mismo stock) y con él (la segunda espera y ve el stock actualizado).
- Carga masiva: `COPY` vs `executemany` vs fila por fila, triggers deshabilitados dentro de la misma transacción, 17 controles antes del `COMMIT`, semilla fija y reproducibilidad.

### Ejercicios en vivo

1. **RN-09: venta sin stock.** Insertar un renglón por encima del stock de la sala:

   ```sql
   BEGIN;
   INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad)
   SELECT c.nro_comprobante, v.codigo_vino, 99999
     FROM ComprobanteVenta c
     JOIN Vino v ON v.precio_venta > 0
     JOIN StockSala s ON s.codigo_vino = v.codigo_vino
                     AND s.id_sala = c.id_sala
                     AND s.cantidad > 0
    WHERE c.fecha = (SELECT MAX(fecha) FROM ComprobanteVenta)
    LIMIT 1;
   ROLLBACK;
   ```

   Falla con `P0001`: `trg_renglon_2_valida_stock` bloquea la fila de stock y rechaza la venta.

2. **RN-06 estricto.** Forzar un descuento que no corresponde al tipo:

   ```sql
   BEGIN;
   UPDATE Cliente
      SET descuento_porcentaje = 50
    WHERE id_cliente = (SELECT id_cliente FROM Exportador LIMIT 1);
   ROLLBACK;
   ```

   Falla con `P0001` de `trg_validar_descuento_cliente`: el descuento del exportador solo puede ser 30 o 35 según sus permisos.

3. **RN-11: retroceso de estado.** Reabrir una transferencia ya procesada:

   ```sql
   BEGIN;
   UPDATE Transferencia SET estado = 'terminado'
    WHERE nro_transferencia = (SELECT nro_transferencia FROM Transferencia
                                WHERE estado = 'procesado' LIMIT 1);
   ROLLBACK;
   ```

   Falla con `P0001`: la máquina de estados no admite retrocesos.

## LautaroAllolio — Rendimiento, API, front y despliegue

### Preguntas esperadas

- Índices de `008_indices.sql`: por qué `idx_comprobante_sala_fecha` e `idx_comprobante_fecha_cover` (índice de cobertura) y por qué se descartó el candidato evaluado; costo de escritura de los índices.
- Cómo leer un `EXPLAIN (ANALYZE, BUFFERS)`: `Seq Scan` vs `Index Scan`, filas estimadas vs reales, y qué plan resuelve cada consulta S9–S12.
- Las 30 consignas de Etapa 5: CTE y `UPDATE ... FROM` set-based, `ON CONFLICT DO NOTHING`, `ROW_NUMBER`/`RANK`/ventanas acumuladas, división relacional por `NOT EXISTS`.
- API: FastAPI con routers, Pydantic, paginación, traducción de SQLSTATE a HTTP (`P0001` → 409, `23514` → 422, `42501` → 403, `40001` → 503) y por qué la validación de descuentos ya no vive en la API.
- 36 pruebas automatizadas: base `bodega_api_test` creada desde `bodega_seed`, qué cubren (CRUD, RN-06 con permisos 30/35, venta, transferencia, reportes).
- Front: React 19 + Vite + TypeScript, `CatalogosContext`, `useDebouncedValue`, cotización con rollback, y por qué el front no calcula totales.
- Docker Compose: cuatro servicios, `db-init` corre una sola vez (migraciones `001` a `009` + carga), healthchecks y dependencias (`service_completed_successfully`).

### Ejercicios en vivo

1. **EXPLAIN con y sin índice.**

   ```sql
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT nro_comprobante, id_cliente, total
     FROM ComprobanteVenta
    WHERE id_sala = 1 AND fecha >= DATE '2026-10-01';
   ```

   Muestra `Index Scan` sobre `idx_comprobante_sala_fecha`. Luego:

   ```sql
   BEGIN;
   DROP INDEX idx_comprobante_sala_fecha;
   EXPLAIN (ANALYZE, BUFFERS)
   SELECT nro_comprobante, id_cliente, total
     FROM ComprobanteVenta
    WHERE id_sala = 1 AND fecha >= DATE '2026-10-01';
   ROLLBACK;
   ```

   El mismo `DROP` dentro de transacción: el plan pasa a `Seq Scan` y el `ROLLBACK` restaura el índice.

2. **API: rechazo traducido.** Alta de exportador con descuento inválido:

   ```powershell
   curl -s -X POST http://localhost:8080/api/clientes `
     -H "Content-Type: application/json" `
     -d '{"apellido":"Demo","nombre":"Defensa","cuit":"30707123456","tipo_documento":"DNI","nro_documento":"7123456","calle_cliente":"San Martin","nro_calle_cliente":123,"id_localidad":1,"tipo_cliente":"Exportador","descuento_porcentaje":50,"pais_destino_principal":"Brasil"}'
   ```

   Devuelve 409 con `sqlstate: "P0001"`: el trigger de la base rechazó y la API solo traduce. Repetir con `30` y muestra 201 con el descuento sincronizado.

3. **Operativa del stack.**

   ```powershell
   docker compose ps
   docker compose logs --tail 20 api
   curl http://localhost:8080/api/reportes/s13-ventas-sala-trimestre
   ```

   Explicar healthcheck de `db`, dependencia de `api` de `db-init` completado, y que la API se conecta con el rol `bodega_api` de mínimos privilegios.

## Preguntas cruzadas (cualquiera puede responder)

- Por qué el descuento del exportador se calcula en la base y no en la API (migración `009`): cualquier cliente de la base queda cubierto por la regla.
- Por qué la cotización consume número de secuencia aunque haga rollback (las secuencias no son transaccionales).
- Por qué `AuditoriaPrecio` es append-only para `bodega_api` y quién escribe en ella (el trigger, con los privilegios del usuario que actualiza `Vino`).
- Qué pasaría si se restaura `db/dump_completo.sql.gz` en un clúster sin los roles (nada: `--no-owner --no-privileges`; luego se recrean con `007_roles.sql`).
- Diferencia entre `RESTRICT` y `NO ACTION` en este esquema (ninguna FK es diferible salvo la circular de localidad/empleado, que sí lo es y se resuelve al final de la transacción).

## Logística

- Orden sugerido: demo completa (12 min, guion en `docs/demo.md`), luego cada integrante su tramo de ejercicios (2 min cada uno).
- Cada integrante ejecuta sus tres ejercicios desde su propia terminal; tener el SQL pegado listo para evitar tipeo.
- Si un ejercicio no falla como se espera, mostrar el mecanismo igual (`\df`, `\dy`, el trigger en `005_triggers.sql` o `009`) y explicar el resultado esperado; el código fuente es la referencia.
