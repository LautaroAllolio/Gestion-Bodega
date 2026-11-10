from fastapi import APIRouter, Query, Response, status

from .. import repository
from ..schemas import (
    ClienteCreate,
    ClienteOut,
    ClientePage,
    ClienteReplace,
    ClienteUpdate,
    TipoCliente,
)

router = APIRouter(prefix="/clientes", tags=["clientes"])


@router.get("", response_model=ClientePage)
def listar_clientes(
    q: str | None = Query(default=None, max_length=200),
    tipo_cliente: TipoCliente | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
):
    return repository.list_clientes(q, tipo_cliente, page, limit)


@router.post("", response_model=ClienteOut, status_code=status.HTTP_201_CREATED)
def crear_cliente(payload: ClienteCreate):
    return repository.create_cliente(payload.model_dump())


@router.get("/{id_cliente}", response_model=ClienteOut)
def obtener_cliente(id_cliente: int):
    return repository.get_cliente(id_cliente)


@router.patch("/{id_cliente}", response_model=ClienteOut)
def actualizar_cliente(id_cliente: int, payload: ClienteUpdate):
    return repository.update_cliente(
        id_cliente, payload.model_dump(exclude_unset=True)
    )


@router.put("/{id_cliente}", response_model=ClienteOut)
def reemplazar_cliente(id_cliente: int, payload: ClienteReplace):
    return repository.update_cliente(id_cliente, payload.model_dump())


@router.delete("/{id_cliente}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_cliente(id_cliente: int):
    repository.delete_cliente(id_cliente)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
