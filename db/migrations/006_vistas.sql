/* ------------------------------------------------------------ */
/* 006_vistas.sql - TPI Bases de Datos, Bodegas del Atuel       */
/* Vistas de reporte - Etapa 2                                  */
/* Ejecutar después de 005_triggers.sql (PostgreSQL 14+)        */
/* ------------------------------------------------------------ */

/* ============================================================ */
/* 1. STOCK TOTAL POR VINO                                      */
/* ============================================================ */

/* Una fila por vino con el stock del depósito central, la suma
 * de todas las salas y el total de ambos.
 */
CREATE OR REPLACE VIEW vw_stock_total_vino AS
SELECT v.codigo_vino,
       v.nombre_comercial,
       COALESCE(d.stock_deposito, 0) AS stock_deposito,
       COALESCE(s.stock_salas, 0)    AS stock_salas,
       COALESCE(d.stock_deposito, 0) + COALESCE(s.stock_salas, 0) AS stock_total
FROM Vino v
LEFT JOIN (
    SELECT codigo_vino,
           SUM(cantidad) AS stock_deposito
    FROM StockDeposito
    GROUP BY codigo_vino
) d ON d.codigo_vino = v.codigo_vino
LEFT JOIN (
    SELECT codigo_vino,
           SUM(cantidad) AS stock_salas
    FROM StockSala
    GROUP BY codigo_vino
) s ON s.codigo_vino = v.codigo_vino;

COMMENT ON VIEW vw_stock_total_vino
    IS 'Stock total por vino: depósito central más todas las salas.';


/* ============================================================ */
/* 2. VENTAS MENSUALES POR SALA                                 */
/* ============================================================ */

/* Agrupa los comprobantes por sala y mes calendario, mostrando
 * cantidad de comprobantes e importes de la cabecera.
 */
CREATE OR REPLACE VIEW vw_ventas_mensuales_sala AS
SELECT cv.id_sala,
       sv.calle,
       sv.numero_calle,
       l.nombre AS localidad,
       date_trunc('month', cv.fecha)::date AS mes,
       COUNT(*)            AS cantidad_comprobantes,
       SUM(cv.subtotal)    AS subtotal,
       SUM(cv.descuento)   AS descuento,
       SUM(cv.total)       AS total
FROM ComprobanteVenta cv
JOIN SalaDeVenta sv ON sv.id_sala = cv.id_sala
JOIN Localidad l   ON l.id_localidad = sv.id_localidad
GROUP BY cv.id_sala,
         sv.calle,
         sv.numero_calle,
         l.nombre,
         date_trunc('month', cv.fecha)::date
ORDER BY mes DESC, cv.id_sala;

COMMENT ON VIEW vw_ventas_mensuales_sala
    IS 'Ventas mensuales por sala: comprobantes, subtotal, descuento y total.';


/* ============================================================ */
/* 3. DOCUMENTOS PENDIENTES                                     */
/* ============================================================ */

/* Ingresos y transferencias que todavía no están procesados.
 * Muestra los días transcurridos desde la fecha del documento.
 */
CREATE OR REPLACE VIEW vw_documentos_pendientes AS
SELECT 'Ingreso'::text AS tipo_documento,
       i.id_ingreso  AS nro_documento,
       i.fecha,
       i.estado::text AS estado,
       CURRENT_DATE - i.fecha AS dias_pendiente
FROM Ingreso i
WHERE i.estado <> 'procesado'
UNION ALL
SELECT 'Transferencia'::text,
       t.nro_transferencia,
       t.fecha_confeccion,
       t.estado::text,
       CURRENT_DATE - t.fecha_confeccion
FROM Transferencia t
WHERE t.estado <> 'procesado'
ORDER BY dias_pendiente DESC, tipo_documento, nro_documento;

COMMENT ON VIEW vw_documentos_pendientes
    IS 'Ingresos y transferencias pendientes de procesar, con días transcurridos.';
