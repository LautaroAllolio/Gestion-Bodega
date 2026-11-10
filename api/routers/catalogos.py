from typing import Any

from fastapi import APIRouter

from .. import repository

router = APIRouter(prefix="/catalogos", tags=["catalogos"])


@router.get("/bodegas", response_model=list[dict[str, Any]])
def listar_bodegas():
    return repository.list_bodegas()


@router.get("/cepas", response_model=list[dict[str, Any]])
def listar_cepas():
    return repository.list_cepas()


@router.get("/maridajes", response_model=list[dict[str, Any]])
def listar_maridajes():
    return repository.list_maridajes()


@router.get("/salas", response_model=list[dict[str, Any]])
def listar_salas():
    return repository.list_salas()


@router.get("/depositos", response_model=list[dict[str, Any]])
def listar_depositos():
    return repository.list_depositos()


@router.get("/localidades", response_model=list[dict[str, Any]])
def listar_localidades():
    return repository.list_localidades()
