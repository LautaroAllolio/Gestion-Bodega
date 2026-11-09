from fastapi import APIRouter, Query, Response, status

from .. import repository
from ..schemas import TipoVino, VinoCreate, VinoDetailOut, VinoPage, VinoUpdate

router = APIRouter(prefix="/vinos", tags=["vinos"])


@router.get("", response_model=VinoPage)
def listar_vinos(
    q: str | None = Query(default=None, max_length=200),
    tipo: TipoVino | None = Query(default=None),
    bodega: str | None = Query(default=None, max_length=100),
    cepa: str | None = Query(default=None, max_length=50),
    anada: int | None = Query(default=None, ge=1900, le=2100),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
):
    return repository.list_vinos(q, tipo, bodega, cepa, anada, page, limit)


@router.post("", response_model=VinoDetailOut, status_code=status.HTTP_201_CREATED)
def crear_vino(payload: VinoCreate):
    return repository.create_vino(payload.model_dump())


@router.get("/{codigo_vino}", response_model=VinoDetailOut)
def obtener_vino(codigo_vino: str):
    return repository.get_vino(codigo_vino)


@router.patch("/{codigo_vino}", response_model=VinoDetailOut)
def actualizar_vino(codigo_vino: str, payload: VinoUpdate):
    return repository.update_vino(codigo_vino, payload.model_dump(exclude_unset=True))


@router.delete("/{codigo_vino}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_vino(codigo_vino: str):
    repository.delete_vino(codigo_vino)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
