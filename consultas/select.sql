/* ============================================================
   consultas/select.sql
   TPI Bases de Datos - Bodegas del Atuel
   Etapa 5 - Consultas SELECT (S1 a S8)

   Cada consulta se ejecuta dentro de BEGIN ... ROLLBACK para
   demostrar que se prueba en transaccion sin alterar el dataset.

   Parametros concretos elegidos del dataset:
     - S3: sala 1, ultima semana (CURRENT_DATE - 7 days).
     - S4: vino V0155 (Alvarez Rosado 0155), ultimos 15 dias.
     - S5: transferencias pendientes = estado <> 'procesado'.
     - S6: sala 1, deposito central id_deposito = 1.
     - S7: ultimo mes (CURRENT_DATE - 1 month).
     - S8: ultimo trimestre (CURRENT_DATE - 3 months).
   ============================================================ */


/* ============================================================
   S1 - Ranking de los 10 vinos con mayor cantidad de botellas
        vendidas en toda la red de salas.
   ============================================================ */

BEGIN;

SELECT ROW_NUMBER() OVER (
           ORDER BY SUM(dv.cantidad) DESC, v.codigo_vino ASC
       ) AS posicion,
       v.codigo_vino,
       v.nombre_comercial,
       v.tipo,
       SUM(dv.cantidad) AS botellas_vendidas
  FROM DetalleVenta dv
  JOIN Vino v ON v.codigo_vino = dv.codigo_vino
 GROUP BY v.codigo_vino, v.nombre_comercial, v.tipo
 ORDER BY botellas_vendidas DESC, v.codigo_vino ASC
 LIMIT 10;

ROLLBACK;


/* ============================================================
   S2 - Listar codigos y nombres de los vinos que se vendieron
        en todas las salas (division relacional).
   Implementacion por cardinalidad: la cantidad de salas distintas
   en las que se vendio el vino debe igualar la cantidad total de
   salas. Es equivalente a la division con doble NOT EXISTS.
   ============================================================ */

BEGIN;

SELECT v.codigo_vino,
       v.nombre_comercial
  FROM Vino v
  JOIN DetalleVenta dv
    ON dv.codigo_vino = v.codigo_vino
  JOIN ComprobanteVenta cv
    ON cv.nro_comprobante = dv.nro_comprobante
 GROUP BY v.codigo_vino, v.nombre_comercial
HAVING COUNT(DISTINCT cv.id_sala) = (SELECT COUNT(*) FROM SalaDeVenta)
 ORDER BY v.codigo_vino;

ROLLBACK;


/* ============================================================
   S3 - Cantidad de clientes de cada tipo que compraron en una
        sala determinada en la ultima semana.
   Sala elegida: id_sala = 1.
   ============================================================ */

BEGIN;

SELECT c.tipo_cliente,
       COUNT(DISTINCT c.id_cliente) AS cantidad_clientes
  FROM ComprobanteVenta cv
  JOIN Cliente c ON c.id_cliente = cv.id_cliente
 WHERE cv.id_sala = 1
   AND cv.fecha >= CURRENT_DATE - INTERVAL '7 days'
   AND cv.fecha <= CURRENT_DATE
 GROUP BY c.tipo_cliente
 ORDER BY c.tipo_cliente;

ROLLBACK;


/* ============================================================
   S4 - Top 5 de las salas que solicitaron mayor cantidad de un
        vino determinado mediante transferencias en los ultimos
        15 dias.
   Vino elegido: V0155 (Alvarez Rosado 0155).
   ============================================================ */

BEGIN;

WITH cantidades AS (
    SELECT t.id_sala_solicitante AS id_sala,
           SUM(dt.cantidad) AS botellas_solicitadas
      FROM Transferencia t
      JOIN DetalleTransferencia dt
        ON dt.nro_transferencia = t.nro_transferencia
     WHERE dt.codigo_vino = 'V0155'
       AND t.fecha_confeccion >= CURRENT_DATE - INTERVAL '15 days'
       AND t.fecha_confeccion <= CURRENT_DATE
     GROUP BY t.id_sala_solicitante
)
SELECT s.id_sala,
       s.calle,
       c.botellas_solicitadas
  FROM cantidades c
  JOIN SalaDeVenta s ON s.id_sala = c.id_sala
 ORDER BY c.botellas_solicitadas DESC, s.id_sala ASC
 LIMIT 5;

ROLLBACK;


/* ============================================================
   S5 - Listado de las salas con menor cantidad de transferencias
        pendientes (no procesadas).
   Se incluyen las salas sin transferencias pendientes con 0.
   ============================================================ */

BEGIN;

WITH pendientes AS (
    SELECT s.id_sala,
           s.calle,
           COUNT(t.nro_transferencia) AS transferencias_pendientes
      FROM SalaDeVenta s
      LEFT JOIN Transferencia t
             ON t.id_sala_solicitante = s.id_sala
            AND t.estado <> 'procesado'
     GROUP BY s.id_sala, s.calle
)
SELECT id_sala,
       calle,
       transferencias_pendientes
  FROM pendientes
 WHERE transferencias_pendientes = (
           SELECT MIN(transferencias_pendientes) FROM pendientes
       )
 ORDER BY id_sala;

ROLLBACK;


/* ============================================================
   S6 - Para una sala determinada, los vinos sin stock en la sala
        pero con stock en el deposito central.
   Sala elegida: id_sala = 1. Deposito central: id_deposito = 1.
   ============================================================ */

BEGIN;

SELECT v.codigo_vino,
       v.nombre_comercial,
       COALESCE(ss.cantidad, 0) AS stock_sala,
       sd.cantidad AS stock_deposito
  FROM Vino v
  JOIN StockDeposito sd
    ON sd.codigo_vino = v.codigo_vino
   AND sd.id_deposito = 1
   AND sd.cantidad > 0
  LEFT JOIN StockSala ss
    ON ss.codigo_vino = v.codigo_vino
   AND ss.id_sala = 1
 WHERE COALESCE(ss.cantidad, 0) = 0
 ORDER BY v.codigo_vino;

ROLLBACK;


/* ============================================================
   S7 - Empresa de transporte con mayor actividad en el ultimo
        mes. Se mide por cantidad de ingresos trasladados y se
        informa tambien el total de botellas.
   ============================================================ */

BEGIN;

WITH actividad AS (
    SELECT i.id_transporte,
           COUNT(DISTINCT i.id_ingreso) AS ingresos,
           COUNT(DISTINCT i.cuit_bodega) AS bodegas,
           COALESCE(SUM(di.cantidad_botellas), 0) AS botellas
      FROM Ingreso i
      LEFT JOIN DetalleIngreso di
             ON di.id_ingreso = i.id_ingreso
     WHERE i.fecha >= CURRENT_DATE - INTERVAL '1 month'
       AND i.fecha <= CURRENT_DATE
     GROUP BY i.id_transporte
)
SELECT t.id_transporte,
       t.razon_social,
       a.ingresos,
       a.bodegas,
       a.botellas
  FROM actividad a
  JOIN Transportista t ON t.id_transporte = a.id_transporte
 ORDER BY a.ingresos DESC, a.botellas DESC, t.id_transporte ASC
 LIMIT 1;

ROLLBACK;


/* ============================================================
   S8 - Monto total de ventas por sala en el ultimo trimestre,
        en orden descendente.
   ============================================================ */

BEGIN;

SELECT s.id_sala,
       s.calle,
       l.nombre AS localidad,
       SUM(cv.total) AS monto_total
  FROM ComprobanteVenta cv
  JOIN SalaDeVenta s ON s.id_sala = cv.id_sala
  JOIN Localidad l ON l.id_localidad = s.id_localidad
 WHERE cv.fecha >= CURRENT_DATE - INTERVAL '3 months'
   AND cv.fecha <= CURRENT_DATE
 GROUP BY s.id_sala, s.calle, l.nombre
 ORDER BY monto_total DESC, s.id_sala ASC;

ROLLBACK;
