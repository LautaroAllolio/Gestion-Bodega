from typing import Any

from .db import fetch_all, fetch_one
from .errors import NotFoundError


def stock_total_por_vino() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT codigo_vino, nombre_comercial, stock_deposito, stock_salas,
               stock_total
          FROM vw_stock_total_vino
         ORDER BY nombre_comercial, codigo_vino
        """
    )


def ventas_mensuales_por_sala() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT id_sala, calle, numero_calle, localidad, mes,
               cantidad_comprobantes, subtotal, descuento, total
          FROM vw_ventas_mensuales_sala
         ORDER BY mes DESC, id_sala
        """
    )


def documentos_pendientes() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT tipo_documento, nro_documento, fecha, estado, dias_pendiente
          FROM vw_documentos_pendientes
         ORDER BY dias_pendiente DESC, tipo_documento, nro_documento
        """
    )


def top_vinos_vendidos() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT dv.codigo_vino, v.nombre_comercial,
               SUM(dv.cantidad)::integer AS unidades_vendidas,
               SUM(dv.subtotal) AS total_vendido
          FROM DetalleVenta dv
          JOIN Vino v ON v.codigo_vino = dv.codigo_vino
         GROUP BY dv.codigo_vino, v.nombre_comercial
         ORDER BY unidades_vendidas DESC, dv.codigo_vino
         LIMIT 10
        """
    )


def top_clientes_facturacion() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT c.id_cliente, c.apellido, c.nombre, c.tipo_cliente,
               COUNT(cv.nro_comprobante)::integer AS comprobantes,
               SUM(cv.total) AS total_facturado
          FROM Cliente c
          JOIN ComprobanteVenta cv ON cv.id_cliente = c.id_cliente
         GROUP BY c.id_cliente, c.apellido, c.nombre, c.tipo_cliente
         ORDER BY total_facturado DESC, c.id_cliente
         LIMIT 10
        """
    )


def ventas_por_localidad() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT l.id_localidad, l.nombre AS localidad, l.provincia,
               COUNT(cv.nro_comprobante)::integer AS comprobantes,
               SUM(cv.total) AS total_vendido
          FROM ComprobanteVenta cv
          JOIN SalaDeVenta s ON s.id_sala = cv.id_sala
          JOIN Localidad l ON l.id_localidad = s.id_localidad
         GROUP BY l.id_localidad, l.nombre, l.provincia
         ORDER BY total_vendido DESC, l.nombre
        """
    )


def ventas_por_tipo_vino() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT v.tipo, SUM(dv.cantidad)::integer AS unidades_vendidas,
               SUM(dv.subtotal) AS total_vendido
          FROM DetalleVenta dv
          JOIN Vino v ON v.codigo_vino = dv.codigo_vino
         GROUP BY v.tipo
         ORDER BY unidades_vendidas DESC, v.tipo
        """
    )


def clientes_sin_compras() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT c.id_cliente, c.apellido, c.nombre, c.tipo_cliente, c.cuit
          FROM Cliente c
          LEFT JOIN ComprobanteVenta cv ON cv.id_cliente = c.id_cliente
         WHERE cv.nro_comprobante IS NULL
         ORDER BY c.apellido, c.nombre, c.id_cliente
        """
    )


def vinos_sin_stock() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT v.codigo_vino, v.nombre_comercial, v.tipo,
               COALESCE(s.stock_total, 0) AS stock_total
          FROM Vino v
          LEFT JOIN vw_stock_total_vino s ON s.codigo_vino = v.codigo_vino
         WHERE COALESCE(s.stock_total, 0) = 0
         ORDER BY v.nombre_comercial, v.codigo_vino
        """
    )


def top_salas_ventas() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT s.id_sala, s.calle, s.numero_calle,
               COUNT(cv.nro_comprobante)::integer AS comprobantes,
               SUM(cv.total) AS total_vendido
          FROM SalaDeVenta s
          JOIN ComprobanteVenta cv ON cv.id_sala = s.id_sala
         GROUP BY s.id_sala, s.calle, s.numero_calle
         ORDER BY total_vendido DESC, s.id_sala
         LIMIT 10
        """
    )


def descuentos_por_cliente() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT c.id_cliente, c.apellido, c.nombre, c.descuento_porcentaje,
               COUNT(cv.nro_comprobante)::integer AS comprobantes,
               SUM(cv.descuento) AS total_descuento
          FROM Cliente c
          JOIN ComprobanteVenta cv ON cv.id_cliente = c.id_cliente
         GROUP BY c.id_cliente, c.apellido, c.nombre, c.descuento_porcentaje
         ORDER BY total_descuento DESC, c.id_cliente
         LIMIT 10
        """
    )


def evolucion_mensual_ventas() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT date_trunc('month', cv.fecha)::date AS mes,
               COUNT(*)::integer AS comprobantes,
               SUM(cv.subtotal) AS subtotal,
               SUM(cv.descuento) AS descuento,
               SUM(cv.total) AS total
          FROM ComprobanteVenta cv
         GROUP BY date_trunc('month', cv.fecha)::date
         ORDER BY mes
        """
    )


def ventas_sala_ultimo_trimestre() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT s.id_sala,
               (s.calle || ' ' || s.numero_calle) AS sala,
               COUNT(cv.nro_comprobante)::integer AS comprobantes,
               COALESCE(SUM(cv.total), 0) AS total
          FROM SalaDeVenta s
          JOIN ComprobanteVenta cv ON cv.id_sala = s.id_sala
         WHERE cv.fecha >= CURRENT_DATE - INTERVAL '3 months'
         GROUP BY s.id_sala, s.calle, s.numero_calle
         ORDER BY total DESC, s.id_sala
        """
    )


def vinos_sin_stock_sala(id_sala: int) -> list[dict[str, Any]]:
    if fetch_one(
        "SELECT 1 FROM SalaDeVenta WHERE id_sala = %s", (id_sala,)
    ) is None:
        raise NotFoundError(f"No existe la sala {id_sala}")
    return fetch_all(
        """
        SELECT v.codigo_vino, v.nombre_comercial, v.tipo,
               COALESCE(ss.cantidad, 0) AS stock_sala
          FROM Vino v
          LEFT JOIN StockSala ss
            ON ss.codigo_vino = v.codigo_vino
           AND ss.id_sala = %s
         WHERE COALESCE(ss.cantidad, 0) = 0
         ORDER BY v.nombre_comercial, v.codigo_vino
        """,
        (id_sala,),
    )
