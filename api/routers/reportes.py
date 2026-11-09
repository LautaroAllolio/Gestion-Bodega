from typing import Any

from fastapi import APIRouter

from .. import reports

router = APIRouter(prefix="/reportes", tags=["reportes"])


@router.get("/s1-stock-total", response_model=list[dict[str, Any]])
def s1_stock_total():
    return reports.stock_total_por_vino()


@router.get("/s2-ventas-mensuales-sala", response_model=list[dict[str, Any]])
def s2_ventas_mensuales_sala():
    return reports.ventas_mensuales_por_sala()


@router.get("/s3-documentos-pendientes", response_model=list[dict[str, Any]])
def s3_documentos_pendientes():
    return reports.documentos_pendientes()


@router.get("/s4-top-vinos", response_model=list[dict[str, Any]])
def s4_top_vinos():
    return reports.top_vinos_vendidos()


@router.get("/s5-top-clientes", response_model=list[dict[str, Any]])
def s5_top_clientes():
    return reports.top_clientes_facturacion()


@router.get("/s6-ventas-localidad", response_model=list[dict[str, Any]])
def s6_ventas_localidad():
    return reports.ventas_por_localidad()


@router.get("/s7-ventas-tipo", response_model=list[dict[str, Any]])
def s7_ventas_tipo():
    return reports.ventas_por_tipo_vino()


@router.get("/s8-clientes-sin-compras", response_model=list[dict[str, Any]])
def s8_clientes_sin_compras():
    return reports.clientes_sin_compras()


@router.get("/s9-vinos-sin-stock", response_model=list[dict[str, Any]])
def s9_vinos_sin_stock():
    return reports.vinos_sin_stock()


@router.get("/s10-top-salas", response_model=list[dict[str, Any]])
def s10_top_salas():
    return reports.top_salas_ventas()


@router.get("/s11-descuentos-clientes", response_model=list[dict[str, Any]])
def s11_descuentos_clientes():
    return reports.descuentos_por_cliente()


@router.get("/s12-evolucion-mensual", response_model=list[dict[str, Any]])
def s12_evolucion_mensual():
    return reports.evolucion_mensual_ventas()
