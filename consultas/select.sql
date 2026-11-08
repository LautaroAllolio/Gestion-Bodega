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


/* ============================================================
   S9 - Ficha de un vino: cepas con sus porcentajes, bodega
        elaboradora, maridajes y stock total (deposito + salas).
   Vino elegido: V0017 (Vazquez Tinto 0017), Bodega Acosta 03.
   Se usa la vista vw_stock_total_vino para el stock total.
   ============================================================ */

BEGIN;

WITH cepas AS (
    SELECT vc.codigo_vino,
           STRING_AGG(c.nombre || ' (' || vc.porcentaje_corte || '%)', ', '
                      ORDER BY vc.porcentaje_corte DESC) AS cepas
      FROM VinoCepa vc
      JOIN Cepa c ON c.id_cepa = vc.id_cepa
     GROUP BY vc.codigo_vino
),
maridajes AS (
    SELECT vm.codigo_vino,
           STRING_AGG(m.nombre, ', ' ORDER BY m.nombre) AS maridajes
      FROM VinoMaridaje vm
      JOIN Maridaje m ON m.id_maridaje = vm.id_maridaje
     GROUP BY vm.codigo_vino
)
SELECT v.codigo_vino,
       v.nombre_comercial,
       v.tipo,
       v.anada,
       v.presentacion_ml,
       v.graduacion_alcoholica,
       v.precio_venta,
       b.razon_social AS bodega,
       b.cuit AS cuit_bodega,
       c.cepas,
       m.maridajes,
       st.stock_deposito,
       st.stock_salas,
       st.stock_total
  FROM Vino v
  JOIN Bodega b ON b.cuit = v.cuit_bodega
  JOIN vw_stock_total_vino st ON st.codigo_vino = v.codigo_vino
  LEFT JOIN cepas c ON c.codigo_vino = v.codigo_vino
  LEFT JOIN maridajes m ON m.codigo_vino = v.codigo_vino
 WHERE v.codigo_vino = 'V0017';

ROLLBACK;


/* ============================================================
   S10 - Rendimiento en kg por hectarea de cada parcela y
         campania, e identificacion de las parcelas que rinden
         menos que el promedio de su finca.
   Se usa una CTE para agregar los lotes por parcela/campania y
   una subconsulta correlacionada para el promedio de la finca.
   ============================================================ */

BEGIN;

WITH rendimiento AS (
    SELECT l.id_finca,
           l.nro_parcela,
           l.campania,
           SUM(l.kilos) AS kilos_cosechados,
           p.superficie,
           SUM(l.kilos) / p.superficie AS kg_por_ha
      FROM LoteUva l
      JOIN Parcela p
        ON p.id_finca = l.id_finca
       AND p.nro_parcela = l.nro_parcela
     GROUP BY l.id_finca, l.nro_parcela, l.campania, p.superficie
),
comparado AS (
    SELECT r.id_finca,
           r.nro_parcela,
           r.campania,
           r.kilos_cosechados,
           r.superficie,
           r.kg_por_ha,
           (SELECT AVG(r2.kg_por_ha)
              FROM rendimiento r2
             WHERE r2.id_finca = r.id_finca
               AND r2.campania = r.campania) AS promedio_finca
      FROM rendimiento r
)
SELECT f.nombre AS finca,
       c.nro_parcela,
       c.campania,
       c.kilos_cosechados,
       c.superficie,
       ROUND(c.kg_por_ha, 2) AS kg_por_ha,
       ROUND(c.promedio_finca, 2) AS promedio_finca,
       CASE
           WHEN c.kg_por_ha < c.promedio_finca THEN 'SI'
           ELSE 'NO'
       END AS rinde_menos_que_promedio
  FROM comparado c
  JOIN Finca f ON f.id_finca = c.id_finca
 ORDER BY f.nombre, c.campania, c.nro_parcela;

ROLLBACK;


/* ============================================================
   S11 - Ranking de vinos dentro de cada sala por botellas
         vendidas y ventas acumuladas mensuales por sala.
   S11a usa RANK() OVER (PARTITION BY sala).
   S11b usa suma acumulada con ventana por sala y mes.
   ============================================================ */

BEGIN;

WITH ventas_vino AS (
    SELECT cv.id_sala,
           dv.codigo_vino,
           SUM(dv.cantidad) AS botellas_vendidas
      FROM ComprobanteVenta cv
      JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
     GROUP BY cv.id_sala, dv.codigo_vino
)
SELECT s.id_sala,
       s.calle,
       vv.codigo_vino,
       v.nombre_comercial,
       vv.botellas_vendidas,
       RANK() OVER (
           PARTITION BY vv.id_sala
           ORDER BY vv.botellas_vendidas DESC
       ) AS ranking_en_sala
  FROM ventas_vino vv
  JOIN SalaDeVenta s ON s.id_sala = vv.id_sala
  JOIN Vino v ON v.codigo_vino = vv.codigo_vino
 ORDER BY s.id_sala, ranking_en_sala, vv.codigo_vino;

ROLLBACK;


BEGIN;

WITH ventas_mensuales AS (
    SELECT cv.id_sala,
           date_trunc('month', cv.fecha)::date AS mes,
           SUM(cv.total) AS ventas_mes
      FROM ComprobanteVenta cv
     GROUP BY cv.id_sala, date_trunc('month', cv.fecha)::date
)
SELECT s.id_sala,
       s.calle,
       vm.mes,
       vm.ventas_mes,
       SUM(vm.ventas_mes) OVER (
           PARTITION BY vm.id_sala
           ORDER BY vm.mes
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS ventas_acumuladas
  FROM ventas_mensuales vm
  JOIN SalaDeVenta s ON s.id_sala = vm.id_sala
 ORDER BY s.id_sala, vm.mes;

ROLLBACK;


/* ============================================================
   S12 - Clientes que compraron todos los vinos de una bodega
         determinada (division con NOT EXISTS) y clientes que
         nunca compraron ningun vino tinto (anti-join).
   Bodega elegida: Bodega Juarez 10, CUIT 34122036849 (17 vinos).
   ============================================================ */

BEGIN;

-- Control: cobertura maxima de la bodega elegida
SELECT c.id_cliente,
       c.apellido,
       c.nombre,
       COUNT(DISTINCT dv.codigo_vino) AS vinos_comprados
  FROM Cliente c
  JOIN ComprobanteVenta cv ON cv.id_cliente = c.id_cliente
  JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
  JOIN Vino v ON v.codigo_vino = dv.codigo_vino
 WHERE v.cuit_bodega = '34122036849'
 GROUP BY c.id_cliente, c.apellido, c.nombre
 ORDER BY vinos_comprados DESC, c.id_cliente
 LIMIT 5;

-- Division relacional: no existe un vino de la bodega que el
-- cliente no haya comprado. El anti-join LEFT JOIN ... IS NULL
-- obtiene los pares (cliente, vino) faltantes y NOT EXISTS deja
-- solo a los clientes que no tienen ninguno.
WITH vinos_bodega AS (
    SELECT codigo_vino
      FROM Vino
     WHERE cuit_bodega = '34122036849'
),
compras_bodega AS (
    SELECT DISTINCT cv.id_cliente,
                    dv.codigo_vino
      FROM ComprobanteVenta cv
      JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
      JOIN vinos_bodega vb ON vb.codigo_vino = dv.codigo_vino
),
faltantes AS (
    SELECT c.id_cliente
      FROM Cliente c
      CROSS JOIN vinos_bodega vb
      LEFT JOIN compras_bodega cb
             ON cb.id_cliente = c.id_cliente
            AND cb.codigo_vino = vb.codigo_vino
     WHERE cb.codigo_vino IS NULL
)
SELECT c.id_cliente,
       c.apellido,
       c.nombre
  FROM Cliente c
 WHERE NOT EXISTS (
           SELECT 1
             FROM faltantes f
            WHERE f.id_cliente = c.id_cliente
       )
 ORDER BY c.id_cliente;

ROLLBACK;


BEGIN;

SELECT c.id_cliente,
       c.apellido,
       c.nombre,
       c.tipo_cliente
  FROM Cliente c
  LEFT JOIN (
      SELECT DISTINCT cv.id_cliente
        FROM ComprobanteVenta cv
        JOIN DetalleVenta dv ON dv.nro_comprobante = cv.nro_comprobante
        JOIN Vino v ON v.codigo_vino = dv.codigo_vino
       WHERE v.tipo = 'Tinto'
  ) r ON r.id_cliente = c.id_cliente
 WHERE r.id_cliente IS NULL
 ORDER BY c.id_cliente;

ROLLBACK;
