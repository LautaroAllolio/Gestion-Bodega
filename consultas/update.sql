/* ============================================================
   consultas/update.sql
   TPI Bases de Datos - Bodegas del Atuel
   Etapa 5 - Modificacion de datos (U1 a U6)

   Cada consigna se resuelve dentro de BEGIN ... ROLLBACK para no
   alterar el dataset. Los controles previos y posteriores permiten
   ver el estado de las filas y el tag "UPDATE n" de psql informa
   cuantas filas se modificaron.

   Valores concretos tomados de db/dump_completo.sql.gz:
     - Bodega Ponce 01: CUIT 34463830136 (28 vinos)
     - Salas Lunes/Miercoles: 5, 6, 7, 11
     - Empleados con mas de 5 anios: 104
     - Exportadores con mas de 3 permisos: 405
     - 10 vinos menos vendidos:
       V0582, V0488, V0480, V0327, V0356,
       V0419, V0103, V0391, V0162, V0169
   ============================================================ */


/* ============================================================
   U1 - Recalcular el total de todos los comprobantes aplicando
        el descuento que corresponde al tipo de cliente.
   Reglas: RN-06 (descuento por tipo de cliente) y RN-08
           (total = suma de renglones con descuento).
   ============================================================ */

BEGIN;

-- Control previo: estado global
SELECT COUNT(*)                  AS comprobantes,
       ROUND(SUM(subtotal), 2)   AS subtotal_global,
       ROUND(SUM(descuento), 2)  AS descuento_global,
       ROUND(SUM(total), 2)      AS total_global
FROM ComprobanteVenta;

-- Control previo: comprobantes que no cumplen la formula de RN-08
WITH esperado AS (
    SELECT cv.nro_comprobante,
           COALESCE(SUM(ROUND(dv.cantidad * dv.precio_unitario, 2)), 0) AS bruto,
           COALESCE(SUM(ROUND(dv.cantidad * dv.precio_unitario
                              * (1 - cl.descuento_porcentaje / 100), 2)), 0) AS neto
      FROM ComprobanteVenta cv
      LEFT JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
      JOIN Cliente cl ON cl.id_cliente = cv.id_cliente
     GROUP BY cv.nro_comprobante
)
SELECT COUNT(*) AS comprobantes_desviados
  FROM ComprobanteVenta cv
  JOIN esperado e ON e.nro_comprobante = cv.nro_comprobante
 WHERE cv.subtotal  IS DISTINCT FROM e.bruto
    OR cv.descuento IS DISTINCT FROM (e.bruto - e.neto)
    OR cv.total     IS DISTINCT FROM e.neto;

-- DML: recalculo set-based de los 150.000 comprobantes
WITH esperado AS (
    SELECT cv.nro_comprobante,
           COALESCE(SUM(ROUND(dv.cantidad * dv.precio_unitario, 2)), 0) AS bruto,
           COALESCE(SUM(ROUND(dv.cantidad * dv.precio_unitario
                              * (1 - cl.descuento_porcentaje / 100), 2)), 0) AS neto
      FROM ComprobanteVenta cv
      LEFT JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
      JOIN Cliente cl ON cl.id_cliente = cv.id_cliente
     GROUP BY cv.nro_comprobante
)
UPDATE ComprobanteVenta cv
   SET subtotal  = e.bruto,
       descuento = e.bruto - e.neto,
       total     = e.neto
  FROM esperado e
 WHERE cv.nro_comprobante = e.nro_comprobante;

-- Control posterior: mismos agregados y desvios
SELECT COUNT(*)                  AS comprobantes,
       ROUND(SUM(subtotal), 2)   AS subtotal_global,
       ROUND(SUM(descuento), 2)  AS descuento_global,
       ROUND(SUM(total), 2)      AS total_global
FROM ComprobanteVenta;

WITH esperado AS (
    SELECT cv.nro_comprobante,
           COALESCE(SUM(ROUND(dv.cantidad * dv.precio_unitario, 2)), 0) AS bruto,
           COALESCE(SUM(ROUND(dv.cantidad * dv.precio_unitario
                              * (1 - cl.descuento_porcentaje / 100), 2)), 0) AS neto
      FROM ComprobanteVenta cv
      LEFT JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
      JOIN Cliente cl ON cl.id_cliente = cv.id_cliente
     GROUP BY cv.nro_comprobante
)
SELECT COUNT(*) AS comprobantes_desviados
  FROM ComprobanteVenta cv
  JOIN esperado e ON e.nro_comprobante = cv.nro_comprobante
 WHERE cv.subtotal  IS DISTINCT FROM e.bruto
    OR cv.descuento IS DISTINCT FROM (e.bruto - e.neto)
    OR cv.total     IS DISTINCT FROM e.neto;

ROLLBACK;


/* ============================================================
   U2 - Aumentar un 20 % el salario de los empleados con mas de
        5 anios de antiguedad.
   Funcion: fn_antiguedad_anios(fecha_ingreso) > 5
   ============================================================ */

BEGIN;

-- Control previo
SELECT COUNT(*)                 AS empleados_mas_5,
       ROUND(AVG(salario), 2)   AS salario_promedio,
       ROUND(SUM(salario), 2)   AS masa_salarial
FROM Empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

SELECT cuit, nombre, fecha_ingreso, salario
FROM Empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5
ORDER BY fecha_ingreso, cuit
LIMIT 5;

-- DML
UPDATE Empleado
   SET salario = ROUND(salario * 1.20, 2)
 WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

-- Control posterior
SELECT COUNT(*)                 AS empleados_mas_5,
       ROUND(AVG(salario), 2)   AS salario_promedio,
       ROUND(SUM(salario), 2)   AS masa_salarial
FROM Empleado
WHERE fn_antiguedad_anios(fecha_ingreso) > 5;

SELECT COUNT(*) AS salarios_invalidos
FROM Empleado
WHERE salario <= 0;

ROLLBACK;


/* ============================================================
   U3 - Incrementar un 13 % el precio de los vinos elaborados
        por una bodega determinada.
   Bodega: Bodega Ponce 01 (CUIT 34463830136)
   Regla: RN-13 (auditoria de precio)
   ============================================================ */

BEGIN;

-- Control previo
SELECT COUNT(*)                    AS vinos_bodega,
       ROUND(MIN(precio_venta), 2) AS precio_min,
       ROUND(MAX(precio_venta), 2) AS precio_max,
       ROUND(SUM(precio_venta), 2) AS precio_total
FROM Vino
WHERE cuit_bodega = '34463830136';

SELECT codigo_vino, nombre_comercial, precio_venta
FROM Vino
WHERE cuit_bodega = '34463830136'
ORDER BY codigo_vino
LIMIT 5;

SELECT COUNT(*) AS auditoria_antes FROM AuditoriaPrecio;

-- DML
UPDATE Vino
   SET precio_venta = ROUND(precio_venta * 1.13, 2)
 WHERE cuit_bodega = '34463830136';

-- Control posterior
SELECT COUNT(*)                    AS vinos_bodega,
       ROUND(MIN(precio_venta), 2) AS precio_min,
       ROUND(MAX(precio_venta), 2) AS precio_max,
       ROUND(SUM(precio_venta), 2) AS precio_total
FROM Vino
WHERE cuit_bodega = '34463830136';

SELECT codigo_vino, nombre_comercial, precio_venta
FROM Vino
WHERE cuit_bodega = '34463830136'
ORDER BY codigo_vino
LIMIT 5;

SELECT COUNT(*) AS auditoria_despues FROM AuditoriaPrecio;

SELECT COUNT(*) AS precios_invalidos
FROM Vino
WHERE precio_venta <= 0;

ROLLBACK;


/* ============================================================
   U4 - En las salas cuyo dia de cierre es Lunes cambiarlo a
        Miercoles y viceversa, en una sola sentencia.
   ============================================================ */

BEGIN;

-- Control previo
SELECT id_sala, calle, dia_cierre
FROM SalaDeVenta
WHERE dia_cierre IN ('Lunes', 'Miercoles')
ORDER BY id_sala;

-- DML: un solo UPDATE con CASE
UPDATE SalaDeVenta
   SET dia_cierre = CASE dia_cierre
                        WHEN 'Lunes'     THEN 'Miercoles'
                        WHEN 'Miercoles' THEN 'Lunes'
                        ELSE dia_cierre
                    END
 WHERE dia_cierre IN ('Lunes', 'Miercoles');

-- Control posterior
SELECT id_sala, calle, dia_cierre
FROM SalaDeVenta
WHERE id_sala IN (5, 6, 7, 11)
ORDER BY id_sala;

SELECT COUNT(*) AS salas_con_dia_invalido
FROM SalaDeVenta
WHERE dia_cierre NOT IN
      ('Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo', 'Ninguno');

ROLLBACK;


/* ============================================================
   U5 - Aplicar un 15 % de descuento de precio a los 10 vinos
        menos vendidos de toda la red.
   Menos vendidos: menor SUM(DetalleVenta.cantidad).
   Regla: RN-13 (auditoria de precio)
   ============================================================ */

BEGIN;

-- Control previo: ranking de los 10 menos vendidos
WITH ventas AS (
    SELECT v.codigo_vino,
           COALESCE(SUM(dv.cantidad), 0) AS botellas
      FROM Vino v
      LEFT JOIN DetalleVenta dv ON dv.codigo_vino = v.codigo_vino
     GROUP BY v.codigo_vino
), ranking AS (
    SELECT codigo_vino,
           botellas,
           ROW_NUMBER() OVER (ORDER BY botellas ASC, codigo_vino ASC) AS posicion
      FROM ventas
)
SELECT r.posicion, r.codigo_vino, v.nombre_comercial, r.botellas, v.precio_venta
  FROM ranking r
  JOIN Vino v ON v.codigo_vino = r.codigo_vino
 WHERE r.posicion <= 10
 ORDER BY r.posicion;

SELECT COUNT(*) AS auditoria_antes FROM AuditoriaPrecio;

-- DML
WITH ventas AS (
    SELECT v.codigo_vino,
           COALESCE(SUM(dv.cantidad), 0) AS botellas
      FROM Vino v
      LEFT JOIN DetalleVenta dv ON dv.codigo_vino = v.codigo_vino
     GROUP BY v.codigo_vino
), menos_vendidos AS (
    SELECT codigo_vino
      FROM ventas
     ORDER BY botellas ASC, codigo_vino ASC
     LIMIT 10
)
UPDATE Vino v
   SET precio_venta = ROUND(v.precio_venta * 0.85, 2)
  FROM menos_vendidos m
 WHERE v.codigo_vino = m.codigo_vino;

-- Control posterior: ranking y precios nuevos
WITH ventas AS (
    SELECT v.codigo_vino,
           COALESCE(SUM(dv.cantidad), 0) AS botellas
      FROM Vino v
      LEFT JOIN DetalleVenta dv ON dv.codigo_vino = v.codigo_vino
     GROUP BY v.codigo_vino
), ranking AS (
    SELECT codigo_vino,
           botellas,
           ROW_NUMBER() OVER (ORDER BY botellas ASC, codigo_vino ASC) AS posicion
      FROM ventas
)
SELECT r.posicion, r.codigo_vino, v.nombre_comercial, r.botellas, v.precio_venta
  FROM ranking r
  JOIN Vino v ON v.codigo_vino = r.codigo_vino
 WHERE r.posicion <= 10
 ORDER BY r.posicion;

SELECT COUNT(*) AS auditoria_despues FROM AuditoriaPrecio;

SELECT COUNT(*) AS precios_invalidos
FROM Vino
WHERE precio_venta <= 0;

ROLLBACK;


/* ============================================================
   U6 - A los exportadores con mas de 3 permisos de exportacion,
        subirles el descuento al 35 %.
   Regla: RN-06 (descuento por tipo de cliente) con excepcion
          comercial pedida por la consigna.
   ============================================================ */

BEGIN;

-- Control previo
WITH permisos AS (
    SELECT id_cliente, COUNT(*) AS cantidad
      FROM PermisoExportacion
     GROUP BY id_cliente
    HAVING COUNT(*) > 3
)
SELECT COUNT(*)                                            AS exportadores_mas_3,
       COUNT(*) FILTER (WHERE c.descuento_porcentaje = 35) AS ya_con_35,
       MIN(c.descuento_porcentaje)                         AS desc_min,
       MAX(c.descuento_porcentaje)                         AS desc_max
  FROM Cliente c
  JOIN Exportador e ON e.id_cliente = c.id_cliente
  JOIN permisos p   ON p.id_cliente = c.id_cliente;

WITH permisos AS (
    SELECT id_cliente, COUNT(*) AS cantidad
      FROM PermisoExportacion
     GROUP BY id_cliente
    HAVING COUNT(*) > 3
)
SELECT c.id_cliente, c.apellido, c.nombre, c.descuento_porcentaje,
       p.cantidad AS permisos
  FROM Cliente c
  JOIN Exportador e ON e.id_cliente = c.id_cliente
  JOIN permisos p   ON p.id_cliente = c.id_cliente
 ORDER BY p.cantidad DESC, c.id_cliente
 LIMIT 5;

-- DML
WITH permisos AS (
    SELECT id_cliente, COUNT(*) AS cantidad
      FROM PermisoExportacion
     GROUP BY id_cliente
    HAVING COUNT(*) > 3
)
UPDATE Cliente c
   SET descuento_porcentaje = 35
  FROM Exportador e
  JOIN permisos p ON p.id_cliente = e.id_cliente
 WHERE e.id_cliente = c.id_cliente;

-- Control posterior
WITH permisos AS (
    SELECT id_cliente, COUNT(*) AS cantidad
      FROM PermisoExportacion
     GROUP BY id_cliente
    HAVING COUNT(*) > 3
)
SELECT COUNT(*)                                            AS exportadores_mas_3,
       COUNT(*) FILTER (WHERE c.descuento_porcentaje = 35) AS con_35,
       MIN(c.descuento_porcentaje)                         AS desc_min,
       MAX(c.descuento_porcentaje)                         AS desc_max
  FROM Cliente c
  JOIN Exportador e ON e.id_cliente = c.id_cliente
  JOIN permisos p   ON p.id_cliente = c.id_cliente;

SELECT COUNT(*) AS descuentos_invalidos
FROM Cliente
WHERE descuento_porcentaje NOT BETWEEN 0 AND 100;

ROLLBACK;
