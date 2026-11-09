import psycopg
from fastapi import Request
from fastapi.responses import JSONResponse
from psycopg_pool import PoolTimeout

class NotFoundError(Exception):
    pass


class BusinessValidationError(Exception):
    pass


SQLSTATE_MAP: dict[str, tuple[int, str]] = {
    "23505": (409, "Conflicto de unicidad"),
    "23503": (409, "Violación de clave foránea"),
    "23514": (422, "Violación de una regla de validación"),
    "23502": (422, "Falta un campo obligatorio"),
    "P0001": (409, "Regla de negocio violada"),
    "22P02": (400, "Formato inválido para el tipo de dato"),
    "40001": (503, "Conflicto de serialización; reintente la operación"),
    "40P01": (503, "Deadlock detectado; reintente la operación"),
    "42501": (403, "Permiso insuficiente"),
}


async def psycopg_exception_handler(request: Request, exc: psycopg.Error) -> JSONResponse:
    code = getattr(exc, "sqlstate", None) or ""
    status, default_message = SQLSTATE_MAP.get(code, (500, "Error de base de datos"))
    message = str(exc).strip() or default_message
    return JSONResponse(
        status_code=status,
        content={"detail": message, "sqlstate": code},
    )


async def pool_timeout_handler(request: Request, exc: PoolTimeout) -> JSONResponse:
    return JSONResponse(
        status_code=503,
        content={"detail": "No hay conexiones disponibles en el pool", "sqlstate": None},
    )


async def not_found_handler(request: Request, exc: NotFoundError) -> JSONResponse:
    return JSONResponse(status_code=404, content={"detail": str(exc)})


async def business_validation_handler(
    request: Request, exc: BusinessValidationError
) -> JSONResponse:
    return JSONResponse(status_code=422, content={"detail": str(exc)})
