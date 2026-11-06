/* ------------------------------------------------------------ */
/* 004_procedimientos.sql - TPI Bases de Datos, Bodegas del Atuel */
/* Procedimientos transaccionales - Etapa 2                      */
/* Ejecutar después de 003_funciones.sql (PostgreSQL 14+)        */
/* ------------------------------------------------------------ */

-- RN-10: solo un ingreso terminado impacta el depósito y pasa a procesado.
-- Parámetros: p_id_ingreso integer.
-- No hace COMMIT ni ROLLBACK: la atomicidad la controla el llamador.
CREATE OR REPLACE PROCEDURE sp_procesar_ingreso(p_id_ingreso integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_id_deposito integer;
BEGIN
    SELECT i.estado, i.id_deposito
      INTO v_estado, v_id_deposito
      FROM Ingreso i
     WHERE i.id_ingreso = p_id_ingreso
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el ingreso % (RN-10)', p_id_ingreso;
    END IF;

    IF v_estado IS DISTINCT FROM 'terminado' THEN
        RAISE EXCEPTION
            'El ingreso % debe estar terminado para procesarse; estado actual: % (RN-10)',
            p_id_ingreso, v_estado;
    END IF;

    PERFORM 1
      FROM DetalleIngreso d
     WHERE d.id_ingreso = p_id_ingreso
     ORDER BY d.codigo_vino
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El ingreso % no tiene renglones (RN-10)', p_id_ingreso;
    END IF;

    PERFORM 1
      FROM StockDeposito s
      JOIN DetalleIngreso d ON d.codigo_vino = s.codigo_vino
     WHERE d.id_ingreso = p_id_ingreso
       AND s.id_deposito = v_id_deposito
     ORDER BY s.codigo_vino
     FOR UPDATE OF s;

    INSERT INTO StockDeposito (id_deposito, codigo_vino, cantidad)
    SELECT v_id_deposito, d.codigo_vino, d.cantidad_botellas
      FROM DetalleIngreso d
     WHERE d.id_ingreso = p_id_ingreso
     ORDER BY d.codigo_vino
    ON CONFLICT (id_deposito, codigo_vino)
    DO UPDATE SET cantidad = StockDeposito.cantidad + EXCLUDED.cantidad;

    UPDATE Ingreso
       SET estado = 'procesado'
     WHERE id_ingreso = p_id_ingreso;
END;
$$;

COMMENT ON PROCEDURE sp_procesar_ingreso(integer)
    IS 'RN-10: procesa un ingreso terminado, suma stock al depósito y lo pasa a procesado.';


-- RN-11: solo una transferencia terminada impacta stock y pasa a procesado.
-- Parámetros: p_nro_transferencia integer.
-- No hace COMMIT ni ROLLBACK: la atomicidad la controla el llamador.
CREATE OR REPLACE PROCEDURE sp_procesar_transferencia(p_nro_transferencia integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_documento;
    v_id_deposito integer;
    v_id_sala integer;
    v_codigo_vino varchar(50);
    v_cantidad_pedida integer;
    v_cantidad_disponible integer;
BEGIN
    SELECT t.estado, t.id_deposito, t.id_sala_solicitante
      INTO v_estado, v_id_deposito, v_id_sala
      FROM Transferencia t
     WHERE t.nro_transferencia = p_nro_transferencia
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la transferencia % (RN-11)', p_nro_transferencia;
    END IF;

    IF v_estado IS DISTINCT FROM 'terminado' THEN
        RAISE EXCEPTION
            'La transferencia % debe estar terminada para procesarse; estado actual: % (RN-11)',
            p_nro_transferencia, v_estado;
    END IF;

    PERFORM 1
      FROM DetalleTransferencia d
     WHERE d.nro_transferencia = p_nro_transferencia
     ORDER BY d.codigo_vino
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La transferencia % no tiene renglones (RN-11)', p_nro_transferencia;
    END IF;

    PERFORM 1
      FROM StockDeposito s
      JOIN DetalleTransferencia d ON d.codigo_vino = s.codigo_vino
     WHERE d.nro_transferencia = p_nro_transferencia
       AND s.id_deposito = v_id_deposito
     ORDER BY s.codigo_vino
     FOR UPDATE OF s;

    SELECT d.codigo_vino, d.cantidad, COALESCE(s.cantidad, 0)
      INTO v_codigo_vino, v_cantidad_pedida, v_cantidad_disponible
      FROM DetalleTransferencia d
      LEFT JOIN StockDeposito s
        ON s.id_deposito = v_id_deposito
       AND s.codigo_vino = d.codigo_vino
     WHERE d.nro_transferencia = p_nro_transferencia
       AND (s.codigo_vino IS NULL OR s.cantidad < d.cantidad)
     ORDER BY d.codigo_vino
     LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION
            'Stock insuficiente del vino % en el depósito % para la transferencia %: pedido %, disponible % (RN-11)',
            v_codigo_vino, v_id_deposito, p_nro_transferencia,
            v_cantidad_pedida, v_cantidad_disponible;
    END IF;

    UPDATE StockDeposito s
       SET cantidad = s.cantidad - d.cantidad
      FROM DetalleTransferencia d
     WHERE d.nro_transferencia = p_nro_transferencia
       AND s.id_deposito = v_id_deposito
       AND s.codigo_vino = d.codigo_vino;

    PERFORM 1
      FROM StockSala ss
      JOIN DetalleTransferencia d ON d.codigo_vino = ss.codigo_vino
     WHERE d.nro_transferencia = p_nro_transferencia
       AND ss.id_sala = v_id_sala
     ORDER BY ss.codigo_vino
     FOR UPDATE OF ss;

    INSERT INTO StockSala (id_sala, codigo_vino, cantidad)
    SELECT v_id_sala, d.codigo_vino, d.cantidad
      FROM DetalleTransferencia d
     WHERE d.nro_transferencia = p_nro_transferencia
     ORDER BY d.codigo_vino
    ON CONFLICT (id_sala, codigo_vino)
    DO UPDATE SET cantidad = StockSala.cantidad + EXCLUDED.cantidad;

    UPDATE Transferencia
       SET estado = 'procesado'
     WHERE nro_transferencia = p_nro_transferencia;
END;
$$;

COMMENT ON PROCEDURE sp_procesar_transferencia(integer)
    IS 'RN-11: procesa una transferencia terminada, descuenta del depósito, suma a la sala y la pasa a procesado.';
