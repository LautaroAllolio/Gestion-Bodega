/* ============================================================
   db/tests/db_tests.sql - TPI Bases de Datos, Bodegas del Atuel
   Pruebas de la Etapa 2: reglas de negocio RN-01 a RN-15.

   Como ejecutar:
       psql -U postgres -d <nombre_base> -f db/tests/db_tests.sql

   IMPORTANTE:
   - No usar -v ON_ERROR_STOP=1: los errores de los casos "FALLA"
     son esperados y el script tiene que continuar.
   - Todo corre dentro de una transaccion que termina con ROLLBACK,
     por lo que no quedan datos de prueba en la base.
   - Cada caso esta entre SAVEPOINT y ROLLBACK TO SAVEPOINT. Asi un
     error esperado no cancela toda la transaccion.
   ============================================================ */

\set ON_ERROR_STOP off
\set ON_ERROR_ROLLBACK off

BEGIN;

/* ============================================================
   DATOS BASE MINIMOS PARA LAS PRUEBAS
   ============================================================ */

\echo '--- DATOS BASE ---'

INSERT INTO Departamento (id_departamento, nombre, provincia)
VALUES (9001, 'San Rafael', 'Mendoza');

INSERT INTO Localidad (id_localidad, nombre, provincia, codigo_postal, cuit_encargado)
VALUES (9001, 'San Rafael', 'Mendoza', '5600', NULL);

INSERT INTO SalaDeVenta (id_sala, calle, dia_cierre, id_localidad, numero_calle)
VALUES (9001, 'Av. Siempre Viva', 'Lunes', 9001, 742);

INSERT INTO Empleado (cuit, nombre, fecha_ingreso, salario, id_sala)
VALUES ('27900000001', 'Ana Perez', '2015-03-01', 850000.00, 9001);

UPDATE Localidad
   SET cuit_encargado = '27900000001'
 WHERE id_localidad = 9001;

INSERT INTO Cepa (id_cepa, nombre, tipo)
VALUES (9001, 'Malbec', 'Tinta'),
       (9002, 'Cabernet Sauvignon', 'Tinta');

INSERT INTO Bodega (cuit, razon_social, calle_bodega, num_calle_bodega)
VALUES ('30900000001', 'Bodega Test S.A.', 'Ruta 40', '100');

INSERT INTO DepositoCentral (id_deposito, nombre)
VALUES (9001, 'Deposito Central Test');

INSERT INTO Transportista (id_transporte, razon_social, cuit, email, telefono, calle_transporte, nro_calle_transporte)
VALUES (9001, 'Transporte Test S.R.L.', '40900000001', 'transporte@test.com', '2604000000', 'Calle Transporte', '50');

INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('VINO_TEST', 'Malbec Test', 'Tinto', 2021, 750, 14.00, 12500.00, '30900000001');

INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
VALUES ('VINO_TEST', 9001, 85.00),
       ('VINO_TEST', 9002, 15.00);

INSERT INTO Maridaje (id_maridaje, nombre, temperatura_servicio)
VALUES (9001, 'Carnes rojas', 17.0);

INSERT INTO VinoMaridaje (codigo_vino, id_maridaje)
VALUES ('VINO_TEST', 9001);

INSERT INTO Cliente (id_cliente, apellido, nombre, cuit, tipo_cliente, tipo_documento, nro_documento, calle_cliente, nro_calle_cliente, id_localidad, fecha_alta, descuento_porcentaje)
VALUES (9001, 'Perez', 'Juan', '20900000001', 'Socio', 'DNI', '30000001', 'Calle Cliente', 10, 9001, CURRENT_DATE, 10.00),
       (9002, 'Gomez', 'Maria', '20900000002', 'Distribuidor', 'CUIT', '30000002', 'Calle Cliente', 20, 9001, CURRENT_DATE, 20.00),
       (9003, 'Exportadora', 'Sur', '20900000003', 'Exportador', 'CUIT', '30000003', 'Calle Cliente', 30, 9001, CURRENT_DATE, 30.00);

INSERT INTO SocioClub (id_cliente, numero_socio)
VALUES (9001, 9001);

INSERT INTO Distribuidor (id_cliente, zona_cobertura, nro_habilitacion)
VALUES (9002, 'Zona Sur', 'HAB-9002');

INSERT INTO Exportador (id_cliente, pais_destino_principal)
VALUES (9003, 'Brasil');

INSERT INTO StockSala (id_sala, codigo_vino, cantidad)
VALUES (9001, 'VINO_TEST', 10);

INSERT INTO StockDeposito (id_deposito, codigo_vino, cantidad)
VALUES (9001, 'VINO_TEST', 100);

INSERT INTO Finca (id_finca, nombre, superficie_total, id_departamento)
VALUES (9001, 'Finca Test', 100.00, 9001);

INSERT INTO Parcela (nro_parcela, id_finca, superficie, anio_plantacion, id_cepa)
VALUES (1, 9001, 10.00, 2010, 9001);


/* ============================================================
   RN-01: precio de vino unico y mayor que cero
   ============================================================ */

\echo '--- RN-01 OK: vino con precio positivo ---'
SAVEPOINT rn01_ok;
INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('V01_OK', 'Vino RN01 OK', 'Tinto', 2022, 750, 13.50, 1000.00, '30900000001');
INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
VALUES ('V01_OK', 9001, 100.00);
SELECT codigo_vino, precio_venta FROM Vino WHERE codigo_vino = 'V01_OK';
ROLLBACK TO SAVEPOINT rn01_ok;

\echo '--- RN-01 FALLA: vino con precio cero ---'
SAVEPOINT rn01_falla;
-- ERROR ESPERADO: check_vino_precio (SQLSTATE 23514)
INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('V01_MAL', 'Vino RN01 malo', 'Tinto', 2022, 750, 13.50, 0.00, '30900000001');
ROLLBACK TO SAVEPOINT rn01_falla;


/* ============================================================
   RN-02: una sala pertenece a una localidad y cada localidad
          tiene un unico encargado regional
   ============================================================ */

\echo '--- RN-02 OK: localidad con sala y encargado ---'
SAVEPOINT rn02_ok;
INSERT INTO Localidad (id_localidad, nombre, provincia, codigo_postal, cuit_encargado)
VALUES (9002, 'San Rafael RN02', 'Mendoza', '5601', NULL);
INSERT INTO SalaDeVenta (id_sala, calle, dia_cierre, id_localidad, numero_calle)
VALUES (9002, 'Calle RN02', 'Martes', 9002, 123);
INSERT INTO Empleado (cuit, nombre, fecha_ingreso, salario, id_sala)
VALUES ('27900000002', 'Encargado RN02', '2018-01-01', 700000.00, 9002);
UPDATE Localidad SET cuit_encargado = '27900000002' WHERE id_localidad = 9002;
SELECT l.nombre AS localidad, l.cuit_encargado, s.id_sala
  FROM Localidad l
  JOIN SalaDeVenta s ON s.id_localidad = l.id_localidad
 WHERE l.id_localidad = 9002;
ROLLBACK TO SAVEPOINT rn02_ok;

\echo '--- RN-02 FALLA: sala con localidad inexistente ---'
SAVEPOINT rn02_falla;
-- ERROR ESPERADO: foreign key fk_saladeventa_localidad (SQLSTATE 23503)
INSERT INTO SalaDeVenta (id_sala, calle, dia_cierre, id_localidad, numero_calle)
VALUES (9003, 'Calle Inexistente', 'Lunes', 999999, 1);
ROLLBACK TO SAVEPOINT rn02_falla;


/* ============================================================
   RN-03: cada empleado trabaja en una sola sala
   ============================================================ */

\echo '--- RN-03 OK: empleado con sala ---'
SAVEPOINT rn03_ok;
INSERT INTO Empleado (cuit, nombre, fecha_ingreso, salario, id_sala)
VALUES ('27900000003', 'Empleado RN03', '2021-05-01', 650000.00, 9001);
SELECT cuit, id_sala FROM Empleado WHERE cuit = '27900000003';
ROLLBACK TO SAVEPOINT rn03_ok;

\echo '--- RN-03 FALLA: empleado sin sala ---'
SAVEPOINT rn03_falla;
-- ERROR ESPERADO: null value in column "id_sala" (SQLSTATE 23502)
INSERT INTO Empleado (cuit, nombre, fecha_ingreso, salario, id_sala)
VALUES ('27900000004', 'Empleado sin sala', '2021-05-01', 650000.00, NULL);
ROLLBACK TO SAVEPOINT rn03_falla;


/* ============================================================
   RN-04: una parcela tiene una sola cepa y se cosecha como
          maximo una vez por campania
   ============================================================ */

\echo '--- RN-04 OK: primer lote de la parcela en la campania ---'
SAVEPOINT rn04_ok;
INSERT INTO LoteUva (id_lote, nro_lote, fecha_cosecha, kilos, cuit_bodega, nro_parcela, id_finca, campania)
VALUES (9001, 1, CURRENT_DATE, 1000.00, '30900000001', 1, 9001, 2026);
SELECT nro_lote, nro_parcela, id_finca, campania FROM LoteUva WHERE id_lote = 9001;
ROLLBACK TO SAVEPOINT rn04_ok;

\echo '--- RN-04 FALLA: segunda cosecha de la misma parcela y campania ---'
SAVEPOINT rn04_falla;
INSERT INTO LoteUva (id_lote, nro_lote, fecha_cosecha, kilos, cuit_bodega, nro_parcela, id_finca, campania)
VALUES (9002, 2, CURRENT_DATE, 900.00, '30900000001', 1, 9001, 2026);
-- ERROR ESPERADO: unique constraint lote_uva_campania (SQLSTATE 23505)
INSERT INTO LoteUva (id_lote, nro_lote, fecha_cosecha, kilos, cuit_bodega, nro_parcela, id_finca, campania)
VALUES (9003, 3, CURRENT_DATE, 800.00, '30900000001', 1, 9001, 2026);
ROLLBACK TO SAVEPOINT rn04_falla;


/* ============================================================
   RN-05: los porcentajes de corte de un vino suman 100
   El trigger es diferido, por eso se fuerza con SET CONSTRAINTS.
   ============================================================ */

\echo '--- RN-05 OK: composicion 60/40 ---'
SAVEPOINT rn05_ok;
INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('V05_OK', 'Vino RN05 OK', 'Tinto', 2022, 750, 13.00, 2000.00, '30900000001');
INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
VALUES ('V05_OK', 9001, 60.00),
       ('V05_OK', 9002, 40.00);
SET CONSTRAINTS trg_vino_suma_100, trg_vinocepa_suma_100 IMMEDIATE;
SELECT codigo_vino, SUM(porcentaje_corte) AS suma_cortes
  FROM VinoCepa
 WHERE codigo_vino = 'V05_OK'
 GROUP BY codigo_vino;
SET CONSTRAINTS ALL DEFERRED;
ROLLBACK TO SAVEPOINT rn05_ok;
SET CONSTRAINTS ALL DEFERRED;

\echo '--- RN-05 FALLA: composicion que suma 80 ---'
SAVEPOINT rn05_falla;
INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('V05_MAL', 'Vino RN05 malo', 'Tinto', 2022, 750, 13.00, 2000.00, '30900000001');
INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
VALUES ('V05_MAL', 9001, 60.00),
       ('V05_MAL', 9002, 20.00);
-- ERROR ESPERADO: los porcentajes suman 80, deben sumar 100 (RN-05) (SQLSTATE P0001)
SET CONSTRAINTS trg_vino_suma_100, trg_vinocepa_suma_100 IMMEDIATE;
ROLLBACK TO SAVEPOINT rn05_falla;
SET CONSTRAINTS ALL DEFERRED;


/* ============================================================
   RN-06: descuento segun el tipo de cliente
   ============================================================ */

\echo '--- RN-06 OK: descuentos 10, 20 y 30 ---'
SAVEPOINT rn06_ok;
SELECT fn_descuento_cliente(9001) AS socio,
       fn_descuento_cliente(9002) AS distribuidor,
       fn_descuento_cliente(9003) AS exportador;
ROLLBACK TO SAVEPOINT rn06_ok;

\echo '--- RN-06 OK: descuento especial cargado en la columna (12.50) ---'
SAVEPOINT rn06_especial;
INSERT INTO Cliente (id_cliente, apellido, nombre, cuit, tipo_cliente, tipo_documento, nro_documento, calle_cliente, nro_calle_cliente, id_localidad, fecha_alta, descuento_porcentaje)
VALUES (9006, 'Especial', 'Cliente', '20900000006', 'Socio', 'DNI', '30000006', 'Calle Cliente', 60, 9001, CURRENT_DATE, 12.50);
SELECT fn_descuento_cliente(9006) AS descuento_especial;
ROLLBACK TO SAVEPOINT rn06_especial;

\echo '--- RN-06 FALLA: cliente con descuento fuera de rango ---'
SAVEPOINT rn06_falla;
-- ERROR ESPERADO: check_cliente_descuento (SQLSTATE 23514)
INSERT INTO Cliente (id_cliente, apellido, nombre, cuit, tipo_cliente, tipo_documento, nro_documento, calle_cliente, nro_calle_cliente, id_localidad, fecha_alta, descuento_porcentaje)
VALUES (9004, 'Cliente', 'Malo', '20900000004', 'Socio', 'DNI', '30000004', 'Calle Cliente', 40, 9001, CURRENT_DATE, 150.00);
ROLLBACK TO SAVEPOINT rn06_falla;


/* ============================================================
   RN-07: un exportador puede tener varios permisos y el
          vencimiento debe ser posterior a la emision
   ============================================================ */

\echo '--- RN-07 OK: permiso con vencimiento posterior ---'
SAVEPOINT rn07_ok;
INSERT INTO PermisoExportacion (id_permiso, id_cliente, codigo_permiso, fecha_emision, fecha_vencimiento)
VALUES (9001, 9003, 'PERM-9001', '2025-01-01', '2026-01-01');
SELECT codigo_permiso, fecha_emision, fecha_vencimiento
  FROM PermisoExportacion
 WHERE id_permiso = 9001;
ROLLBACK TO SAVEPOINT rn07_ok;

\echo '--- RN-07 FALLA: permiso vencido antes de emitirse ---'
SAVEPOINT rn07_falla;
-- ERROR ESPERADO: check_permiso_fechas (SQLSTATE 23514)
INSERT INTO PermisoExportacion (id_permiso, id_cliente, codigo_permiso, fecha_emision, fecha_vencimiento)
VALUES (9002, 9003, 'PERM-9002', '2026-01-01', '2025-01-01');
ROLLBACK TO SAVEPOINT rn07_falla;


/* ============================================================
   RN-08: total del comprobante calculado por funcion y trigger
   ============================================================ */

\echo '--- RN-08 OK: renglon completa importes y totales ---'
SAVEPOINT rn08_ok;
INSERT INTO ComprobanteVenta (nro_comprobante, fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (9001, CURRENT_DATE, 9001, 9001, 0, 0, 0);
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (9001, 'VINO_TEST', 2, 0, 0, 0);
SELECT nro_comprobante, subtotal, descuento, total
  FROM ComprobanteVenta
 WHERE nro_comprobante = 9001;
SELECT fn_total_comprobante(9001) AS total_segun_funcion;
ROLLBACK TO SAVEPOINT rn08_ok;

\echo '--- RN-08 FALLA: renglon de comprobante inexistente ---'
SAVEPOINT rn08_falla;
-- ERROR ESPERADO: No existe el comprobante 999999 (RN-08) (SQLSTATE P0001)
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (999999, 'VINO_TEST', 1, 0, 0, 0);
ROLLBACK TO SAVEPOINT rn08_falla;


/* ============================================================
   RN-09: no se puede vender mas de lo que hay en stock y el
          stock nunca puede ser negativo
   ============================================================ */

\echo '--- RN-09 OK: venta con stock suficiente ---'
SAVEPOINT rn09_ok;
INSERT INTO ComprobanteVenta (nro_comprobante, fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (9002, CURRENT_DATE, 9001, 9001, 0, 0, 0);
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (9002, 'VINO_TEST', 3, 0, 0, 0);
SELECT fn_stock_sala(9001, 'VINO_TEST') AS stock_restante;
ROLLBACK TO SAVEPOINT rn09_ok;

\echo '--- RN-09 FALLA: venta con cantidad mayor al stock ---'
SAVEPOINT rn09_falla;
INSERT INTO ComprobanteVenta (nro_comprobante, fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (9003, CURRENT_DATE, 9001, 9001, 0, 0, 0);
-- ERROR ESPERADO: Stock insuficiente del vino VINO_TEST en la sala 9001 (RN-09) (SQLSTATE P0001)
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (9003, 'VINO_TEST', 11, 0, 0, 0);
ROLLBACK TO SAVEPOINT rn09_falla;

\echo '--- RN-09 FALLA: stock negativo ---'
SAVEPOINT rn09_check;
-- ERROR ESPERADO: check_stocksala_cantidad (SQLSTATE 23514)
UPDATE StockSala SET cantidad = -1 WHERE id_sala = 9001 AND codigo_vino = 'VINO_TEST';
ROLLBACK TO SAVEPOINT rn09_check;


/* ============================================================
   RN-10: solo un ingreso terminado impacta el deposito y pasa
          a procesado; las transiciones no retroceden
   ============================================================ */

\echo '--- RN-10 OK: procesar un ingreso terminado ---'
SAVEPOINT rn10_ok;
INSERT INTO Ingreso (id_ingreso, fecha, estado, id_transporte, cuit_bodega, id_deposito)
VALUES (9001, CURRENT_DATE, 'en_confeccion', 9001, '30900000001', 9001);
INSERT INTO DetalleIngreso (id_ingreso, codigo_vino, cantidad_botellas)
VALUES (9001, 'VINO_TEST', 5);
UPDATE Ingreso SET estado = 'terminado' WHERE id_ingreso = 9001;
CALL sp_procesar_ingreso(9001);
SELECT estado FROM Ingreso WHERE id_ingreso = 9001;
SELECT cantidad FROM StockDeposito WHERE id_deposito = 9001 AND codigo_vino = 'VINO_TEST';
ROLLBACK TO SAVEPOINT rn10_ok;

\echo '--- RN-10 FALLA: procesar un ingreso en confeccion ---'
SAVEPOINT rn10_falla;
INSERT INTO Ingreso (id_ingreso, fecha, estado, id_transporte, cuit_bodega, id_deposito)
VALUES (9002, CURRENT_DATE, 'en_confeccion', 9001, '30900000001', 9001);
INSERT INTO DetalleIngreso (id_ingreso, codigo_vino, cantidad_botellas)
VALUES (9002, 'VINO_TEST', 5);
-- ERROR ESPERADO: el ingreso 9002 debe estar terminado para procesarse (RN-10) (SQLSTATE P0001)
CALL sp_procesar_ingreso(9002);
ROLLBACK TO SAVEPOINT rn10_falla;

\echo '--- RN-10 FALLA: salto de estado en_confeccion -> procesado ---'
SAVEPOINT rn10_estado;
INSERT INTO Ingreso (id_ingreso, fecha, estado, id_transporte, cuit_bodega, id_deposito)
VALUES (9003, CURRENT_DATE, 'en_confeccion', 9001, '30900000001', 9001);
-- ERROR ESPERADO: cambio de estado no permitido (RN-10) (SQLSTATE P0001)
UPDATE Ingreso SET estado = 'procesado' WHERE id_ingreso = 9003;
ROLLBACK TO SAVEPOINT rn10_estado;


/* ============================================================
   RN-11: solo una transferencia terminada impacta stock y pasa
          a procesado; la fecha de confeccion no se modifica
   ============================================================ */

\echo '--- RN-11 OK: procesar una transferencia terminada ---'
SAVEPOINT rn11_ok;
INSERT INTO Transferencia (nro_transferencia, id_sala_solicitante, id_deposito, fecha_confeccion, estado)
VALUES (9001, 9001, 9001, '2000-01-01', 'en_confeccion');
SELECT fecha_confeccion = CURRENT_DATE AS fecha_forzada
  FROM Transferencia
 WHERE nro_transferencia = 9001;
INSERT INTO DetalleTransferencia (nro_transferencia, codigo_vino, cantidad)
VALUES (9001, 'VINO_TEST', 5);
UPDATE Transferencia SET estado = 'terminado' WHERE nro_transferencia = 9001;
CALL sp_procesar_transferencia(9001);
SELECT estado FROM Transferencia WHERE nro_transferencia = 9001;
SELECT cantidad FROM StockDeposito WHERE id_deposito = 9001 AND codigo_vino = 'VINO_TEST';
SELECT fn_stock_sala(9001, 'VINO_TEST') AS stock_sala;
ROLLBACK TO SAVEPOINT rn11_ok;

\echo '--- RN-11 FALLA: transferencia sin stock suficiente ---'
SAVEPOINT rn11_falla;
INSERT INTO Transferencia (nro_transferencia, id_sala_solicitante, id_deposito, fecha_confeccion, estado)
VALUES (9002, 9001, 9001, CURRENT_DATE, 'en_confeccion');
INSERT INTO DetalleTransferencia (nro_transferencia, codigo_vino, cantidad)
VALUES (9002, 'VINO_TEST', 999);
UPDATE Transferencia SET estado = 'terminado' WHERE nro_transferencia = 9002;
-- ERROR ESPERADO: stock insuficiente en el deposito (RN-11) (SQLSTATE P0001)
CALL sp_procesar_transferencia(9002);
ROLLBACK TO SAVEPOINT rn11_falla;

\echo '--- RN-11 FALLA: modificar la fecha de confeccion ---'
SAVEPOINT rn11_fecha;
INSERT INTO Transferencia (nro_transferencia, id_sala_solicitante, id_deposito, fecha_confeccion, estado)
VALUES (9003, 9001, 9001, CURRENT_DATE, 'en_confeccion');
-- ERROR ESPERADO: la fecha de confeccion no se puede modificar (RN-11) (SQLSTATE P0001)
UPDATE Transferencia SET fecha_confeccion = CURRENT_DATE - 1 WHERE nro_transferencia = 9003;
ROLLBACK TO SAVEPOINT rn11_fecha;


/* ============================================================
   RN-12: un documento que no esta en confeccion no admite
          agregar, modificar ni quitar renglones
   ============================================================ */

\echo '--- RN-12 OK: agregar renglon mientras esta en confeccion ---'
SAVEPOINT rn12_ok;
INSERT INTO Ingreso (id_ingreso, fecha, estado, id_transporte, cuit_bodega, id_deposito)
VALUES (9004, CURRENT_DATE, 'en_confeccion', 9001, '30900000001', 9001);
INSERT INTO DetalleIngreso (id_ingreso, codigo_vino, cantidad_botellas)
VALUES (9004, 'VINO_TEST', 2);
SELECT id_ingreso, codigo_vino, cantidad_botellas FROM DetalleIngreso WHERE id_ingreso = 9004;
ROLLBACK TO SAVEPOINT rn12_ok;

\echo '--- RN-12 FALLA: modificar renglon de un ingreso terminado ---'
SAVEPOINT rn12_falla;
INSERT INTO Ingreso (id_ingreso, fecha, estado, id_transporte, cuit_bodega, id_deposito)
VALUES (9005, CURRENT_DATE, 'en_confeccion', 9001, '30900000001', 9001);
INSERT INTO DetalleIngreso (id_ingreso, codigo_vino, cantidad_botellas)
VALUES (9005, 'VINO_TEST', 2);
UPDATE Ingreso SET estado = 'terminado' WHERE id_ingreso = 9005;
-- ERROR ESPERADO: el ingreso 9005 esta terminado y no admite cambios en sus renglones (RN-12) (SQLSTATE P0001)
UPDATE DetalleIngreso SET cantidad_botellas = 3 WHERE id_ingreso = 9005 AND codigo_vino = 'VINO_TEST';
ROLLBACK TO SAVEPOINT rn12_falla;

\echo '--- RN-12 FALLA: quitar renglon de una transferencia terminada ---'
SAVEPOINT rn12_transferencia;
INSERT INTO Transferencia (nro_transferencia, id_sala_solicitante, id_deposito, fecha_confeccion, estado)
VALUES (9004, 9001, 9001, CURRENT_DATE, 'en_confeccion');
INSERT INTO DetalleTransferencia (nro_transferencia, codigo_vino, cantidad)
VALUES (9004, 'VINO_TEST', 2);
UPDATE Transferencia SET estado = 'terminado' WHERE nro_transferencia = 9004;
-- ERROR ESPERADO: la transferencia 9004 esta terminada y no admite cambios en sus renglones (RN-12) (SQLSTATE P0001)
DELETE FROM DetalleTransferencia WHERE nro_transferencia = 9004 AND codigo_vino = 'VINO_TEST';
ROLLBACK TO SAVEPOINT rn12_transferencia;


/* ============================================================
   RN-13: todo cambio de precio queda auditado
   ============================================================ */

\echo '--- RN-13 OK: cambio de precio auditado ---'
SAVEPOINT rn13_ok;
UPDATE Vino SET precio_venta = 13000.00 WHERE codigo_vino = 'VINO_TEST';
SELECT codigo_vino, precio_anterior, precio_nuevo, usuario
  FROM AuditoriaPrecio
 WHERE codigo_vino = 'VINO_TEST'
 ORDER BY id_auditoria DESC
 LIMIT 1;
ROLLBACK TO SAVEPOINT rn13_ok;

\echo '--- RN-13 SIN CAMBIO: actualizar al mismo precio no audita ---'
SAVEPOINT rn13_sin_cambio;
UPDATE Vino SET precio_venta = 12500.00 WHERE codigo_vino = 'VINO_TEST';
SELECT COUNT(*) AS auditorias_esperadas_0
  FROM AuditoriaPrecio
 WHERE codigo_vino = 'VINO_TEST';
ROLLBACK TO SAVEPOINT rn13_sin_cambio;


/* ============================================================
   RN-14: no se puede borrar un transportista, una bodega ni un
          vino que tengan movimientos asociados
   ============================================================ */

\echo '--- RN-14 OK: borrar un vino sin movimientos ---'
SAVEPOINT rn14_ok;
INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('V14_OK', 'Vino RN14 OK', 'Tinto', 2022, 750, 13.00, 1800.00, '30900000001');
INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
VALUES ('V14_OK', 9001, 100.00);
DELETE FROM Vino WHERE codigo_vino = 'V14_OK';
SELECT COUNT(*) AS vinos_eliminados FROM Vino WHERE codigo_vino = 'V14_OK';
ROLLBACK TO SAVEPOINT rn14_ok;

\echo '--- RN-14 FALLA: borrar un vino con stock ---'
SAVEPOINT rn14_vino;
-- ERROR ESPERADO: foreign key de StockSala/StockDeposito (SQLSTATE 23503)
DELETE FROM Vino WHERE codigo_vino = 'VINO_TEST';
ROLLBACK TO SAVEPOINT rn14_vino;

\echo '--- RN-14 FALLA: borrar una bodega con vinos ---'
SAVEPOINT rn14_bodega;
-- ERROR ESPERADO: foreign key fk_vino_bodega (SQLSTATE 23503)
DELETE FROM Bodega WHERE cuit = '30900000001';
ROLLBACK TO SAVEPOINT rn14_bodega;

\echo '--- RN-14 FALLA: borrar un transportista con ingresos ---'
SAVEPOINT rn14_transporte;
INSERT INTO Ingreso (id_ingreso, fecha, estado, id_transporte, cuit_bodega, id_deposito)
VALUES (9007, CURRENT_DATE, 'en_confeccion', 9001, '30900000001', 9001);
-- ERROR ESPERADO: foreign key fk_ingreso_transportista (SQLSTATE 23503)
DELETE FROM Transportista WHERE id_transporte = 9001;
ROLLBACK TO SAVEPOINT rn14_transporte;


/* ============================================================
   RN-15: cantidades, superficies, kilos y precios positivos;
          graduacion entre 5 y 20
   ============================================================ */

\echo '--- RN-15 OK: datos base con valores validos ---'
SAVEPOINT rn15_ok;
SELECT graduacion_alcoholica, precio_venta FROM Vino WHERE codigo_vino = 'VINO_TEST';
SELECT superficie_total FROM Finca WHERE id_finca = 9001;
ROLLBACK TO SAVEPOINT rn15_ok;

\echo '--- RN-15 FALLA: cantidad negativa ---'
SAVEPOINT rn15_cantidad;
INSERT INTO ComprobanteVenta (nro_comprobante, fecha, id_cliente, id_sala, subtotal, descuento, total)
VALUES (9004, CURRENT_DATE, 9001, 9001, 0, 0, 0);
-- ERROR ESPERADO: check_detalleventa_cantidad (SQLSTATE 23514)
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad, precio_unitario, descuento_aplicado, subtotal)
VALUES (9004, 'VINO_TEST', -1, 0, 0, 0);
ROLLBACK TO SAVEPOINT rn15_cantidad;

\echo '--- RN-15 FALLA: superficie negativa ---'
SAVEPOINT rn15_superficie;
-- ERROR ESPERADO: check_finca_superficie (SQLSTATE 23514)
INSERT INTO Finca (id_finca, nombre, superficie_total, id_departamento)
VALUES (9002, 'Finca RN15 mala', -5.00, 9001);
ROLLBACK TO SAVEPOINT rn15_superficie;

\echo '--- RN-15 FALLA: graduacion fuera de 5 a 20 ---'
SAVEPOINT rn15_graduacion;
-- ERROR ESPERADO: check_vino_alcohol (SQLSTATE 23514)
INSERT INTO Vino (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml, graduacion_alcoholica, precio_venta, cuit_bodega)
VALUES ('V15_MAL', 'Vino RN15 malo', 'Tinto', 2022, 750, 25.00, 1000.00, '30900000001');
ROLLBACK TO SAVEPOINT rn15_graduacion;


/* ============================================================
   PRUEBAS EXTRA DE FUNCIONES Y VISTAS
   ============================================================ */

\echo '--- FUNCIONES ---'
SELECT fn_descuento_cliente(9001) AS socio,
       fn_descuento_cliente(9002) AS distribuidor,
       fn_descuento_cliente(9003) AS exportador;
SELECT fn_stock_sala(9001, 'VINO_TEST') AS stock_sala;
SELECT fn_antiguedad_anios('2010-01-01') AS antiguedad;
SELECT fn_total_comprobante(999999) AS total_comprobante_inexistente;

\echo '--- VISTAS ---'
SELECT * FROM vw_stock_total_vino WHERE codigo_vino = 'VINO_TEST';
SELECT COUNT(*) AS filas_ventas_mensuales FROM vw_ventas_mensuales_sala;
SELECT COUNT(*) AS filas_documentos_pendientes FROM vw_documentos_pendientes;


/* ============================================================
   FIN: se revierte todo para no dejar datos de prueba
   ============================================================ */

ROLLBACK;

\echo 'FIN: pruebas ejecutadas y transaccion revertida.'
