/* ------------------------------------------------------------ */
/* 003_funciones.sql - TPI Bases de Datos, Bodegas del Atuel     */
/* Funciones de cálculo y consulta - Etapa 2                     */
/* Ejecutar después de 002_contraints.sql (PostgreSQL 14+)       */
/* ------------------------------------------------------------ */

-- RN-08: total del comprobante = suma de sus renglones con descuento.
-- Parámetros: p_nro_comprobante integer.
-- Retorna: numeric(12,2); 0 si no tiene renglones. Volatilidad: STABLE.
CREATE OR REPLACE FUNCTION fn_total_comprobante(p_nro_comprobante integer)
RETURNS numeric(12,2)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT COALESCE(SUM(dv.subtotal), 0)::numeric(12,2)
          FROM DetalleVenta dv
         WHERE dv.nro_comprobante = p_nro_comprobante
    );
END;
$$;

COMMENT ON FUNCTION fn_total_comprobante(integer)
    IS 'RN-08: total de un comprobante a partir de sus renglones. STABLE.';


-- RN-09: stock de un vino en una sala.
-- Parámetros: p_id_sala integer, p_codigo_vino varchar(50).
-- Retorna: integer; 0 si no existe la fila. Volatilidad: STABLE.
CREATE OR REPLACE FUNCTION fn_stock_sala(
    p_id_sala integer,
    p_codigo_vino varchar(50)
)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN COALESCE(
        (
            SELECT ss.cantidad
              FROM StockSala ss
             WHERE ss.id_sala = p_id_sala
               AND ss.codigo_vino = p_codigo_vino
        ),
        0
    );
END;
$$;

COMMENT ON FUNCTION fn_stock_sala(integer, character varying)
    IS 'RN-09: stock de un vino en una sala; 0 si no existe. STABLE.';


-- RN-06: descuento según el tipo de cliente.
-- Parámetros: p_id_cliente integer.
-- Retorna: numeric(5,2): 10, 20 o 30. Volatilidad: STABLE.
CREATE OR REPLACE FUNCTION fn_descuento_cliente(p_id_cliente integer)
RETURNS numeric(5,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_tipo varchar(50);
BEGIN
    SELECT c.tipo_cliente
      INTO v_tipo
      FROM Cliente c
     WHERE c.id_cliente = p_id_cliente;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el cliente % (RN-06)', p_id_cliente;
    END IF;

    RETURN CASE v_tipo
               WHEN 'Socio' THEN 10.00
               WHEN 'Distribuidor' THEN 20.00
               WHEN 'Exportador' THEN 30.00
           END;
END;
$$;

COMMENT ON FUNCTION fn_descuento_cliente(integer)
    IS 'RN-06: descuento según tipo de cliente. STABLE.';


-- U2/D3: años cumplidos desde una fecha de ingreso.
-- Parámetros: p_fecha_ingreso date.
-- Retorna: integer. Volatilidad: STABLE (usa CURRENT_DATE).
CREATE OR REPLACE FUNCTION fn_antiguedad_anios(p_fecha_ingreso date)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN EXTRACT(YEAR FROM age(CURRENT_DATE, p_fecha_ingreso))::integer;
END;
$$;

COMMENT ON FUNCTION fn_antiguedad_anios(date)
    IS 'Años cumplidos desde una fecha de ingreso hasta CURRENT_DATE. STABLE.';
