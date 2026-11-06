/* ------------------------------------------------------------ */
/* 005_triggers.sql - TPI Bases de Datos, Bodegas del Atuel      */
/* Triggers de integridad - Etapa 2                              */
/* Ejecutar despues de 004_procedimientos.sql (PostgreSQL 14+)   */
/*     psql -v ON_ERROR_STOP=1 -f 005_triggers.sql               */
/* ------------------------------------------------------------ */
/* Todas las reglas rechazan con RAISE EXCEPTION (SQLSTATE       */
/* P0001), que la API traduce a 409 Conflict con el mensaje.     */
/*                                                               */
/* Carga masiva (etapa 3): para el historial se pueden           */
/* deshabilitar con  ALTER TABLE <t> DISABLE TRIGGER USER;       */
/* y volver a habilitar con ENABLE TRIGGER USER, validando luego */
/* con consultas de control.                                     */
/* ------------------------------------------------------------ */


/* ============================================================ */
/* 1. VENTAS: completar renglon, validar stock, descontar stock  */
/*    y calcular totales (RN-06, RN-08, RN-09)                   */
/* ============================================================ */

-- RN-06 / RN-08: el renglon no se carga a mano. Precio unitario = precio
-- vigente del vino, descuento = el del cliente, subtotal calculado.
-- BEFORE INSERT en DetalleVenta (se ejecuta antes que la validacion de stock).
CREATE OR REPLACE FUNCTION trg_renglon_completar() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_id_cliente integer;
    v_precio     numeric;
BEGIN
    -- FOR UPDATE serializa la carga de renglones del mismo comprobante: si dos
    -- transacciones agregan renglones a la vez, la segunda espera y recalcula
    -- los totales viendo el renglon de la primera.
    SELECT c.id_cliente INTO v_id_cliente
      FROM ComprobanteVenta c
     WHERE c.nro_comprobante = NEW.nro_comprobante
       FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el comprobante % (RN-08)', NEW.nro_comprobante;
    END IF;

    SELECT v.precio_venta INTO v_precio
      FROM Vino v
     WHERE v.codigo_vino = NEW.codigo_vino;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el vino % (RN-08)', NEW.codigo_vino;
    END IF;

    NEW.precio_unitario    := v_precio;
    NEW.descuento_aplicado := fn_descuento_cliente(v_id_cliente);
    NEW.subtotal           := ROUND(NEW.cantidad * NEW.precio_unitario
                                    * (1 - NEW.descuento_aplicado / 100), 2);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_renglon_1_completar
BEFORE INSERT ON DetalleVenta
FOR EACH ROW EXECUTE FUNCTION trg_renglon_completar();


-- RN-09: no se puede vender mas de lo que hay en stock de la sala.
-- BEFORE INSERT en DetalleVenta. Bloquea la fila de stock (FOR UPDATE) para
-- que dos ventas simultaneas de la ultima botella no pasen las dos.
CREATE OR REPLACE FUNCTION trg_validar_stock_venta() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_sala  integer;
    v_stock integer;
BEGIN
    SELECT c.id_sala INTO v_sala
      FROM ComprobanteVenta c
     WHERE c.nro_comprobante = NEW.nro_comprobante;

    SELECT ss.cantidad INTO v_stock
      FROM StockSala ss
     WHERE ss.id_sala = v_sala
       AND ss.codigo_vino = NEW.codigo_vino
       FOR UPDATE;

    IF NOT FOUND THEN
        v_stock := 0;
    END IF;

    IF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION
            'Stock insuficiente del vino % en la sala %: disponible %, pedido % (RN-09)',
            NEW.codigo_vino, v_sala, v_stock, NEW.cantidad;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_renglon_2_valida_stock
BEFORE INSERT ON DetalleVenta
FOR EACH ROW EXECUTE FUNCTION trg_validar_stock_venta();


-- RN-08 / RN-09: descuenta el stock de la sala y recalcula los importes del
-- comprobante (subtotal sin descuento, descuento en monto y total).
-- AFTER INSERT en DetalleVenta.
CREATE OR REPLACE FUNCTION trg_renglon_stock_y_totales() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_sala   integer;
    v_bruto  numeric;
    v_total  numeric;
BEGIN
    SELECT c.id_sala INTO v_sala
      FROM ComprobanteVenta c
     WHERE c.nro_comprobante = NEW.nro_comprobante;

    UPDATE StockSala
       SET cantidad = cantidad - NEW.cantidad
     WHERE id_sala = v_sala
       AND codigo_vino = NEW.codigo_vino;

    SELECT COALESCE(SUM(ROUND(d.cantidad * d.precio_unitario, 2)), 0)
      INTO v_bruto
      FROM DetalleVenta d
     WHERE d.nro_comprobante = NEW.nro_comprobante;

    v_total := fn_total_comprobante(NEW.nro_comprobante);

    UPDATE ComprobanteVenta
       SET subtotal  = v_bruto,
           descuento = v_bruto - v_total,
           total     = v_total
     WHERE nro_comprobante = NEW.nro_comprobante;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_renglon_3_stock_y_totales
AFTER INSERT ON DetalleVenta
FOR EACH ROW EXECUTE FUNCTION trg_renglon_stock_y_totales();


/* ============================================================ */
/* 2. ESTADOS de ingreso y transferencia (RN-10, RN-11)          */
/* ============================================================ */

-- RN-10 / RN-11: solo se permite en_confeccion -> terminado -> procesado,
-- sin saltos ni retrocesos. BEFORE UPDATE OF estado en Ingreso y Transferencia.
CREATE OR REPLACE FUNCTION trg_validar_estado() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_regla text := CASE TG_TABLE_NAME WHEN 'ingreso' THEN 'RN-10' ELSE 'RN-11' END;
BEGIN
    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;

    IF (OLD.estado = 'en_confeccion' AND NEW.estado = 'terminado')
       OR (OLD.estado = 'terminado' AND NEW.estado = 'procesado') THEN
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'Cambio de estado no permitido en %: % -> % (%)',
        TG_TABLE_NAME, OLD.estado, NEW.estado, v_regla;
END;
$$;

CREATE OR REPLACE TRIGGER trg_ingreso_estado
BEFORE UPDATE OF estado ON Ingreso
FOR EACH ROW EXECUTE FUNCTION trg_validar_estado();

CREATE OR REPLACE TRIGGER trg_transferencia_estado
BEFORE UPDATE OF estado ON Transferencia
FOR EACH ROW EXECUTE FUNCTION trg_validar_estado();


-- RN-11: la fecha de confeccion de una transferencia es la actual y no se
-- puede modificar. BEFORE INSERT OR UPDATE OF fecha_confeccion en Transferencia.
CREATE OR REPLACE FUNCTION trg_fecha_confeccion() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.fecha_confeccion := CURRENT_DATE;
    ELSIF NEW.fecha_confeccion IS DISTINCT FROM OLD.fecha_confeccion THEN
        RAISE EXCEPTION
            'La fecha de confeccion de la transferencia % no se puede modificar (RN-11)',
            OLD.nro_transferencia;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_transferencia_fecha
BEFORE INSERT OR UPDATE OF fecha_confeccion ON Transferencia
FOR EACH ROW EXECUTE FUNCTION trg_fecha_confeccion();


/* ============================================================ */
/* 3. BLOQUEO DE RENGLONES (RN-12)                               */
/* ============================================================ */

-- RN-12: un ingreso que no esta en confeccion no admite agregar, modificar ni
-- quitar renglones. BEFORE INSERT/UPDATE/DELETE en DetalleIngreso.
-- Si la cabecera ya no existe (borrado en cascada del ingreso) se permite.
-- FOR SHARE: evita que el ingreso cambie de estado mientras se carga un renglon.
CREATE OR REPLACE FUNCTION trg_bloquear_renglones_ingreso() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_estado estado_documento;
    v_id     integer;
BEGIN
    FOREACH v_id IN ARRAY CASE TG_OP
                              WHEN 'INSERT' THEN ARRAY[NEW.id_ingreso]
                              WHEN 'DELETE' THEN ARRAY[OLD.id_ingreso]
                              ELSE ARRAY[OLD.id_ingreso, NEW.id_ingreso]
                          END
    LOOP
        SELECT i.estado INTO v_estado
          FROM Ingreso i
         WHERE i.id_ingreso = v_id
           FOR SHARE;

        IF FOUND AND v_estado <> 'en_confeccion' THEN
            RAISE EXCEPTION
                'El ingreso % esta en estado % y no admite cambios en sus renglones (RN-12)',
                v_id, v_estado;
        END IF;
    END LOOP;

    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE OR REPLACE TRIGGER trg_detalle_ingreso_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON DetalleIngreso
FOR EACH ROW EXECUTE FUNCTION trg_bloquear_renglones_ingreso();


-- RN-12: idem para transferencias. BEFORE INSERT/UPDATE/DELETE en DetalleTransferencia.
CREATE OR REPLACE FUNCTION trg_bloquear_renglones_transferencia() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_estado estado_documento;
    v_nro    integer;
BEGIN
    FOREACH v_nro IN ARRAY CASE TG_OP
                               WHEN 'INSERT' THEN ARRAY[NEW.nro_transferencia]
                               WHEN 'DELETE' THEN ARRAY[OLD.nro_transferencia]
                               ELSE ARRAY[OLD.nro_transferencia, NEW.nro_transferencia]
                           END
    LOOP
        SELECT t.estado INTO v_estado
          FROM Transferencia t
         WHERE t.nro_transferencia = v_nro
           FOR SHARE;

        IF FOUND AND v_estado <> 'en_confeccion' THEN
            RAISE EXCEPTION
                'La transferencia % esta en estado % y no admite cambios en sus renglones (RN-12)',
                v_nro, v_estado;
        END IF;
    END LOOP;

    RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE OR REPLACE TRIGGER trg_detalle_transferencia_bloqueo
BEFORE INSERT OR UPDATE OR DELETE ON DetalleTransferencia
FOR EACH ROW EXECUTE FUNCTION trg_bloquear_renglones_transferencia();


/* ============================================================ */
/* 4. AUDITORIA DE PRECIOS (RN-13)                               */
/* ============================================================ */

-- RN-13: todo cambio de precio de un vino queda auditado (fecha, usuario,
-- precio anterior y nuevo). AFTER UPDATE OF precio_venta en Vino; la fecha
-- sale del DEFAULT de AuditoriaPrecio.fecha_hora.
CREATE OR REPLACE FUNCTION trg_auditar_precio() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO AuditoriaPrecio (codigo_vino, precio_anterior, precio_nuevo, usuario)
    VALUES (NEW.codigo_vino, OLD.precio_venta, NEW.precio_venta, CURRENT_USER);
    RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_vino_auditoria_precio
AFTER UPDATE OF precio_venta ON Vino
FOR EACH ROW
WHEN (OLD.precio_venta IS DISTINCT FROM NEW.precio_venta)
EXECUTE FUNCTION trg_auditar_precio();


/* ============================================================ */
/* 5. COMPOSICION DEL VINO (RN-05)                               */
/* ============================================================ */

-- RN-05: los porcentajes de corte de un vino suman exactamente 100.
-- CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED: se verifica al cerrar la
-- transaccion, asi se pueden cargar las cepas de a una dentro de la misma
-- transaccion. Se dispara al tocar VinoCepa y al crear un Vino (un vino sin
-- composicion tampoco es valido: tiene una o mas cepas).
-- Si el vino ya no existe (borrado en cascada) no se controla.
CREATE OR REPLACE FUNCTION trg_validar_suma_cortes() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_codigos varchar[];
    v_cod     varchar;
    v_suma    numeric;
BEGIN
    IF TG_TABLE_NAME = 'vino' OR TG_OP = 'INSERT' THEN
        v_codigos := ARRAY[NEW.codigo_vino];
    ELSIF TG_OP = 'DELETE' THEN
        v_codigos := ARRAY[OLD.codigo_vino];
    ELSE
        v_codigos := ARRAY[OLD.codigo_vino, NEW.codigo_vino];
    END IF;

    FOREACH v_cod IN ARRAY v_codigos
    LOOP
        IF EXISTS (SELECT 1 FROM Vino WHERE codigo_vino = v_cod) THEN
            SELECT COALESCE(SUM(vc.porcentaje_corte), 0) INTO v_suma
              FROM VinoCepa vc
             WHERE vc.codigo_vino = v_cod;

            IF v_suma <> 100 THEN
                RAISE EXCEPTION
                    'Los porcentajes de corte del vino % suman %, deben sumar 100 (RN-05)',
                    v_cod, v_suma;
            END IF;
        END IF;
    END LOOP;

    RETURN NULL;
END;
$$;

-- (CREATE OR REPLACE no existe para constraint triggers: se hace DROP + CREATE)
DROP TRIGGER IF EXISTS trg_vinocepa_suma_100 ON VinoCepa;
CREATE CONSTRAINT TRIGGER trg_vinocepa_suma_100
AFTER INSERT OR UPDATE OR DELETE ON VinoCepa
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_validar_suma_cortes();

DROP TRIGGER IF EXISTS trg_vino_suma_100 ON Vino;
CREATE CONSTRAINT TRIGGER trg_vino_suma_100
AFTER INSERT ON Vino
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION trg_validar_suma_cortes();
