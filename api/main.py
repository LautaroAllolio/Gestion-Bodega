from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from psycopg_pool import PoolTimeout

from . import db
from .config import get_settings
from .errors import (
    BusinessValidationError,
    NotFoundError,
    business_validation_handler,
    not_found_handler,
    pool_timeout_handler,
    psycopg_exception_handler,
)
from .routers import clientes, documentos, reportes, vinos
from .schemas import SaludOut

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.open_pool()
    yield
    db.close_pool()


app = FastAPI(
    title="Bodegas del Atuel API",
    version="1.0.0",
    description="API REST para la gestion de bodegas, ventas, stock y reportes.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_exception_handler(psycopg.Error, psycopg_exception_handler)
app.add_exception_handler(PoolTimeout, pool_timeout_handler)
app.add_exception_handler(NotFoundError, not_found_handler)
app.add_exception_handler(BusinessValidationError, business_validation_handler)

app.include_router(vinos.router)
app.include_router(clientes.router)
app.include_router(documentos.router)
app.include_router(reportes.router)


@app.get("/salud", response_model=SaludOut, tags=["salud"])
def salud():
    row = db.fetch_one("SELECT current_database() AS db")
    return {"status": "ok", "database": row["db"] if row else "desconocida"}


@app.get("/", include_in_schema=False)
def raiz():
    return {"api": "Bodegas del Atuel", "docs": "/docs"}
