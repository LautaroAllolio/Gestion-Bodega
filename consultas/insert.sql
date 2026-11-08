/* ============================================================
   consultas/insert.sql
   TPI Bases de Datos - Bodegas del Atuel
   Etapa 5 - Insercion de datos (I1 a I6)

   Cada consigna se resuelve dentro de BEGIN ... ROLLBACK para no
   alterar el dataset. Los controles previos y posteriores permiten
   ver el estado de las filas y el tag "INSERT 0 n" de psql informa
   cuantas filas se insertaron.

   Valores concretos tomados de db/dump_completo.sql.gz:
     - Localidad General Alvear: id_localidad = 2
     - Transportista con menos ingresos en el ultimo trimestre:
       id_transporte = 12 (2 envios al 2026-11-08)
     - Vinos tintos con graduacion >= 14: 77
     - Cliente Socio: id_cliente = 1 (descuento 10 %)
     - Sala de venta: id_sala = 1
     - Vinos con stock en sala 1: V0209, V0317, V0558
     - Vino 750 ml para ingreso: V0017 (Bodega Acosta 03)
     - Transportista para ingreso: id_transporte = 1
     - Deposito central: id_deposito = 1
   ============================================================ */


/* ============================================================
   I1 - Insertar en la relacion transportista-localidad una nueva
        cobertura que vincule la localidad de General Alvear con el
        transportista que menos envios (ingresos trasladados) haya
        realizado en el ultimo trimestre.
   Regla: el transportista elegido no debe tener ya una cobertura
          para General Alvear.
   ============================================================ */

BEGIN;

-- Control previo: ranking de envios del ultimo trimestre
SELECT t.id_transporte,
       t.razon_social,
       COUNT(i.id_ingreso) AS envios_ultimo_trimestre,
       EXISTS (
           SELECT 1
             FROM TransportistaLocalidad tl
            WHERE tl.id_transporte = t.id_transporte
              AND tl.id_localidad = 2
       ) AS ya_cubre_general_alvear
  FROM Transportista t
  LEFT JOIN Ingreso i
         ON i.id_transporte = t.id_transporte
        AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
        AND i.fecha <= CURRENT_DATE
 GROUP BY t.id_transporte, t.razon_social
 ORDER BY envios_ultimo_trimestre ASC, t.id_transporte ASC;

-- Control previo: coberturas actuales de General Alvear
SELECT tl.id_transporte, t.razon_social, l.nombre AS localidad
  FROM TransportistaLocalidad tl
  JOIN Transportista t ON t.id_transporte = tl.id_transporte
  JOIN Localidad l ON l.id_localidad = tl.id_localidad
 WHERE tl.id_localidad = 2
 ORDER BY tl.id_transporte;

-- DML: elegir el transportista con menos envios y agregar la cobertura
WITH ranking AS (
    SELECT t.id_transporte,
           COUNT(i.id_ingreso) AS envios
      FROM Transportista t
      LEFT JOIN Ingreso i
             ON i.id_transporte = t.id_transporte
            AND i.fecha >= CURRENT_DATE - INTERVAL '3 months'
            AND i.fecha <= CURRENT_DATE
     GROUP BY t.id_transporte
), elegido AS (
    SELECT r.id_transporte
      FROM ranking r
     WHERE NOT EXISTS (
           SELECT 1
             FROM TransportistaLocalidad tl
            WHERE tl.id_transporte = r.id_transporte
              AND tl.id_localidad = 2
     )
     ORDER BY r.envios ASC, r.id_transporte ASC
     LIMIT 1
)
INSERT INTO TransportistaLocalidad (id_transporte, id_localidad)
SELECT id_transporte, 2
  FROM elegido;

-- Control posterior: coberturas de General Alvear
SELECT tl.id_transporte, t.razon_social, l.nombre AS localidad
  FROM TransportistaLocalidad tl
  JOIN Transportista t ON t.id_transporte = tl.id_transporte
  JOIN Localidad l ON l.id_localidad = tl.id_localidad
 WHERE tl.id_localidad = 2
 ORDER BY tl.id_transporte;

ROLLBACK;


/* ============================================================
   I2 - Si existe algun vino tinto con graduacion de 14 grados o
        mas, crear el maridaje "cordero al disco" y asociarlo a
        todos los vinos que cumplan esa condicion.
   ============================================================ */

BEGIN;

-- Control previo: cantidad de tintos que cumplen la condicion
SELECT COUNT(*) AS tintos_ge_14
  FROM Vino
 WHERE tipo = 'Tinto'
   AND graduacion_alcoholica >= 14;

SELECT id_maridaje, nombre, temperatura_servicio
  FROM Maridaje
 WHERE nombre = 'cordero al disco';

-- DML: crear el maridaje solo si hay candidatos y asociarlo
WITH candidatos AS (
    SELECT codigo_vino
      FROM Vino
     WHERE tipo = 'Tinto'
       AND graduacion_alcoholica >= 14
), maridaje_existente AS (
    SELECT id_maridaje
      FROM Maridaje
     WHERE nombre = 'cordero al disco'
), maridaje_nuevo AS (
    INSERT INTO Maridaje (nombre, temperatura_servicio)
    SELECT 'cordero al disco', 18.0
     WHERE EXISTS (SELECT 1 FROM candidatos)
       AND NOT EXISTS (SELECT 1 FROM maridaje_existente)
    RETURNING id_maridaje
), maridaje_id AS (
    SELECT id_maridaje FROM maridaje_nuevo
    UNION ALL
    SELECT id_maridaje FROM maridaje_existente
)
INSERT INTO VinoMaridaje (codigo_vino, id_maridaje)
SELECT c.codigo_vino, m.id_maridaje
  FROM candidatos c
 CROSS JOIN maridaje_id m
ON CONFLICT (codigo_vino, id_maridaje) DO NOTHING;

-- Control posterior: maridaje creado y cantidad de vinos asociados
SELECT m.id_maridaje,
       m.nombre,
       m.temperatura_servicio,
       COUNT(vm.codigo_vino) AS vinos_asociados
  FROM Maridaje m
  LEFT JOIN VinoMaridaje vm ON vm.id_maridaje = m.id_maridaje
 WHERE m.nombre = 'cordero al disco'
 GROUP BY m.id_maridaje, m.nombre, m.temperatura_servicio;

-- Control posterior: asociaciones que no cumplen la condicion
SELECT COUNT(*) AS asociaciones_invalidas
  FROM VinoMaridaje vm
  JOIN Vino v ON v.codigo_vino = vm.codigo_vino
  JOIN Maridaje m ON m.id_maridaje = vm.id_maridaje
 WHERE m.nombre = 'cordero al disco'
   AND NOT (v.tipo = 'Tinto' AND v.graduacion_alcoholica >= 14);

ROLLBACK;


/* ============================================================
   I3 - Crear un nuevo comprobante con tres renglones para un
        cliente dado, en la sala con ID 1, dentro de una
        transaccion y usando las funciones de calculo.
   Cliente: id_cliente = 1 (Socio, descuento 10 %)
   Vinos: V0209, V0317 y V0558 (con stock en sala 1)
   Reglas: RN-06 (descuento), RN-08 (totales) y RN-09 (stock)
   ============================================================ */

BEGIN;

-- Control previo: cliente y stock de los vinos elegidos
SELECT id_cliente, apellido, nombre, tipo_cliente, descuento_porcentaje
  FROM Cliente
 WHERE id_cliente = 1;

SELECT id_sala, codigo_vino, cantidad
  FROM StockSala
 WHERE id_sala = 1
   AND codigo_vino IN ('V0209', 'V0317', 'V0558')
 ORDER BY codigo_vino;

-- Guardar el nro de comprobante generado para los controles
DROP TABLE IF EXISTS tmp_i3;
CREATE TEMP TABLE tmp_i3 (nro_comprobante integer) ON COMMIT DROP;

WITH cabecera AS (
    INSERT INTO ComprobanteVenta (fecha, id_cliente, id_sala, subtotal, descuento, total)
    VALUES (CURRENT_DATE, 1, 1, 0, 0, 0)
    RETURNING nro_comprobante
)
INSERT INTO tmp_i3 (nro_comprobante)
SELECT nro_comprobante FROM cabecera;

-- Los triggers completan precio, descuento, subtotal, stock y totales
INSERT INTO DetalleVenta (nro_comprobante, codigo_vino, cantidad,
                          precio_unitario, descuento_aplicado, subtotal)
SELECT t.nro_comprobante, v.codigo_vino, v.cantidad, 0, 0, 0
  FROM tmp_i3 t
 CROSS JOIN (VALUES ('V0209', 1),
                    ('V0317', 1),
                    ('V0558', 1)) AS v(codigo_vino, cantidad);

-- Control posterior: cabecera y total calculado con la funcion
SELECT c.nro_comprobante,
       c.fecha,
       c.id_cliente,
       c.id_sala,
       c.subtotal,
       c.descuento,
       c.total,
       fn_total_comprobante(c.nro_comprobante) AS total_calculado,
       CASE
           WHEN c.total = fn_total_comprobante(c.nro_comprobante) THEN 'OK'
           ELSE 'ERROR'
       END AS control
  FROM ComprobanteVenta c
  JOIN tmp_i3 t ON t.nro_comprobante = c.nro_comprobante;

-- Control posterior: renglones cargados por los triggers
SELECT d.nro_comprobante,
       d.codigo_vino,
       v.nombre_comercial,
       d.cantidad,
       d.precio_unitario,
       d.descuento_aplicado,
       d.subtotal
  FROM DetalleVenta d
  JOIN Vino v ON v.codigo_vino = d.codigo_vino
  JOIN tmp_i3 t ON t.nro_comprobante = d.nro_comprobante
 ORDER BY d.codigo_vino;

-- Control posterior: stock descontado
SELECT id_sala, codigo_vino, cantidad
  FROM StockSala
 WHERE id_sala = 1
   AND codigo_vino IN ('V0209', 'V0317', 'V0558')
 ORDER BY codigo_vino;

ROLLBACK;


/* ============================================================
   I4 - Insertar una nueva bodega.
   CUIT: 30999999991 (11 digitos, no existe en el dataset)
   ============================================================ */

BEGIN;

-- Control previo
SELECT COUNT(*) AS bodegas_con_cuit
  FROM Bodega
 WHERE cuit = '30999999991';

-- DML
INSERT INTO Bodega (cuit, razon_social, calle_bodega, num_calle_bodega)
VALUES ('30999999991', 'Bodega Nueva 21', 'Calle Ficticia', '123')
RETURNING cuit, razon_social, calle_bodega, num_calle_bodega;

-- Control posterior
SELECT cuit, razon_social, calle_bodega, num_calle_bodega
  FROM Bodega
 WHERE cuit = '30999999991';

ROLLBACK;


/* ============================================================
   I5 - Insertar una nueva sala de venta.
   Localidad: San Rafael (id_localidad = 1)
   Dia de cierre: Viernes (valor permitido por el CHECK)
   ============================================================ */

BEGIN;

-- Control previo
SELECT COUNT(*) AS salas_actuales, MAX(id_sala) AS max_id_sala
  FROM SalaDeVenta;

SELECT id_localidad, nombre, provincia
  FROM Localidad
 WHERE id_localidad = 1;

-- DML
INSERT INTO SalaDeVenta (calle, dia_cierre, id_localidad, numero_calle)
VALUES ('Calle Nueva', 'Viernes', 1, 123)
RETURNING id_sala, calle, dia_cierre, id_localidad, numero_calle;

-- Control posterior
SELECT id_sala, calle, dia_cierre, id_localidad, numero_calle
  FROM SalaDeVenta
 WHERE id_sala = (SELECT MAX(id_sala) FROM SalaDeVenta);

ROLLBACK;


/* ============================================================
   I6 - Crear un ingreso en confeccion de 120 botellas de un vino
        determinado, elaborado por una bodega dada y trasladado por
        un transportista dado.
   Vino: V0017 (Vazquez Tinto 0017, 750 ml)
   Bodega: 33655765404 (Bodega Acosta 03)
   Transportista: id_transporte = 1
   Deposito: id_deposito = 1
   Regla: RN-12 (solo se cargan renglones en estado en_confeccion)
   ============================================================ */

BEGIN;

-- Control previo: vino, bodega, transportista y deposito
SELECT v.codigo_vino,
       v.nombre_comercial,
       v.tipo,
       v.presentacion_ml,
       v.graduacion_alcoholica,
       v.cuit_bodega,
       b.razon_social AS bodega
  FROM Vino v
  JOIN Bodega b ON b.cuit = v.cuit_bodega
 WHERE v.codigo_vino = 'V0017';

SELECT id_transporte, razon_social
  FROM Transportista
 WHERE id_transporte = 1;

SELECT id_deposito, nombre
  FROM DepositoCentral
 WHERE id_deposito = 1;

SELECT COUNT(*) AS ingresos_actuales, MAX(id_ingreso) AS max_id_ingreso
  FROM Ingreso;

-- Guardar el id de ingreso generado para los controles
DROP TABLE IF EXISTS tmp_i6;
CREATE TEMP TABLE tmp_i6 (id_ingreso integer) ON COMMIT DROP;

WITH cabecera AS (
    INSERT INTO Ingreso (fecha, estado, id_transporte, cuit_bodega, id_deposito)
    VALUES (CURRENT_DATE, 'en_confeccion', 1, '33655765404', 1)
    RETURNING id_ingreso
)
INSERT INTO tmp_i6 (id_ingreso)
SELECT id_ingreso FROM cabecera;

-- Renglon del ingreso: 120 botellas del vino elegido
INSERT INTO DetalleIngreso (id_ingreso, codigo_vino, cantidad_botellas)
SELECT t.id_ingreso, 'V0017', 120
  FROM tmp_i6 t;

-- Control posterior: cabecera y renglon
SELECT i.id_ingreso,
       i.fecha,
       i.estado,
       i.id_transporte,
       i.cuit_bodega,
       i.id_deposito,
       d.codigo_vino,
       d.cantidad_botellas
  FROM Ingreso i
  JOIN DetalleIngreso d ON d.id_ingreso = i.id_ingreso
  JOIN tmp_i6 t ON t.id_ingreso = i.id_ingreso;

ROLLBACK;
