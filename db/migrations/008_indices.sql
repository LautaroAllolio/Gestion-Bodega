/* ------------------------------------------------------------ */
/* 008_indices.sql - Índices justificados por planes medidos    */
/* PostgreSQL 14+                                               */
/* ------------------------------------------------------------ */

/* S3: igualdad por sala y rango por fecha; id_cliente permite
 * resolver el join sin volver a la tabla cuando hay visibilidad. */
CREATE INDEX IF NOT EXISTS idx_comprobante_sala_fecha
    ON ComprobanteVenta (id_sala, fecha)
    INCLUDE (id_cliente);

/* S8: rango trimestral, con sala e importe disponibles desde el índice. */
CREATE INDEX IF NOT EXISTS idx_comprobante_fecha_cover
    ON ComprobanteVenta (fecha)
    INCLUDE (id_sala, total);

/* Índice de la FK usada al consultar compras por cliente y al comprobar
 * referencias cuando se actualiza o elimina un Cliente. */
CREATE INDEX IF NOT EXISTS idx_comprobante_cliente
    ON ComprobanteVenta (id_cliente);

/* S4: buscar los renglones por vino y obtener la transferencia asociada. */
CREATE INDEX IF NOT EXISTS idx_detalletransferencia_vino_transferencia
    ON DetalleTransferencia (codigo_vino, nro_transferencia)
    INCLUDE (cantidad);

/* S5: solo se indexan las transferencias pendientes; la sala es la clave
 * de agrupación y nro_transferencia cubre el COUNT sin leer la tabla. */
CREATE INDEX IF NOT EXISTS idx_transferencia_pendiente_sala
    ON Transferencia (id_sala_solicitante)
    INCLUDE (nro_transferencia)
    WHERE estado <> 'procesado';
