from fastapi import APIRouter, Query, status

from .. import repository
from ..schemas import (
    ComprobanteCreate,
    ComprobanteOut,
    EstadoDocumento,
    IngresoCreate,
    IngresoOut,
    RenglonIngresoInput,
    RenglonTransferenciaInput,
    TransferenciaCreate,
    TransferenciaOut,
    TransferenciaPage,
)

router = APIRouter(tags=["documentos"])


@router.post(
    "/comprobantes",
    response_model=ComprobanteOut,
    status_code=status.HTTP_201_CREATED,
)
def crear_comprobante(payload: ComprobanteCreate):
    return repository.create_comprobante(payload.model_dump())


@router.post("/comprobantes/cotizar", response_model=ComprobanteOut)
def cotizar_comprobante(payload: ComprobanteCreate):
    return repository.quote_comprobante(payload.model_dump())


@router.get("/comprobantes/{nro_comprobante}", response_model=ComprobanteOut)
def obtener_comprobante(nro_comprobante: int):
    return repository.get_comprobante(nro_comprobante)


@router.get("/transferencias", response_model=TransferenciaPage)
def listar_transferencias(
    estado: EstadoDocumento | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
):
    return repository.list_transferencias(estado, page, limit)


@router.post(
    "/transferencias",
    response_model=TransferenciaOut,
    status_code=status.HTTP_201_CREATED,
)
def crear_transferencia(payload: TransferenciaCreate):
    return repository.create_transferencia(payload.model_dump())


@router.get("/transferencias/{nro_transferencia}", response_model=TransferenciaOut)
def obtener_transferencia(nro_transferencia: int):
    return repository.get_transferencia(nro_transferencia)


@router.post(
    "/transferencias/{nro_transferencia}/renglones",
    response_model=TransferenciaOut,
    status_code=status.HTTP_201_CREATED,
)
def agregar_renglon_transferencia(
    nro_transferencia: int, payload: RenglonTransferenciaInput
):
    return repository.add_renglon_transferencia(
        nro_transferencia, payload.model_dump()
    )


@router.post(
    "/transferencias/{nro_transferencia}/terminar",
    response_model=TransferenciaOut,
)
def terminar_transferencia(nro_transferencia: int):
    return repository.terminar_transferencia(nro_transferencia)


@router.post(
    "/transferencias/{nro_transferencia}/procesar",
    response_model=TransferenciaOut,
)
def procesar_transferencia(nro_transferencia: int):
    return repository.procesar_transferencia(nro_transferencia)


@router.post(
    "/ingresos",
    response_model=IngresoOut,
    status_code=status.HTTP_201_CREATED,
)
def crear_ingreso(payload: IngresoCreate):
    return repository.create_ingreso(payload.model_dump())


@router.get("/ingresos/{id_ingreso}", response_model=IngresoOut)
def obtener_ingreso(id_ingreso: int):
    return repository.get_ingreso(id_ingreso)


@router.post(
    "/ingresos/{id_ingreso}/renglones",
    response_model=IngresoOut,
    status_code=status.HTTP_201_CREATED,
)
def agregar_renglon_ingreso(id_ingreso: int, payload: RenglonIngresoInput):
    return repository.add_renglon_ingreso(id_ingreso, payload.model_dump())


@router.post("/ingresos/{id_ingreso}/terminar", response_model=IngresoOut)
def terminar_ingreso(id_ingreso: int):
    return repository.terminar_ingreso(id_ingreso)


@router.post("/ingresos/{id_ingreso}/procesar", response_model=IngresoOut)
def procesar_ingreso(id_ingreso: int):
    return repository.procesar_ingreso(id_ingreso)
