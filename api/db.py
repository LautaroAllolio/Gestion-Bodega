from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from .config import get_settings

settings = get_settings()

pool = ConnectionPool(
    conninfo=settings.database_url,
    min_size=settings.pool_min_size,
    max_size=settings.pool_max_size,
    kwargs={"row_factory": dict_row},
    open=False,
)


def open_pool() -> None:
    pool.open()
    pool.wait()


def close_pool() -> None:
    pool.close()


@contextmanager
def connection() -> Iterator[psycopg.Connection]:
    with pool.connection() as conn:
        yield conn


@contextmanager
def transaction() -> Iterator[psycopg.Connection]:
    with pool.connection() as conn:
        with conn.transaction():
            yield conn


def fetch_all(sql: str, params: tuple[Any, ...] = ()) -> list[dict[str, Any]]:
    with connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()


def fetch_one(sql: str, params: tuple[Any, ...] = ()) -> dict[str, Any] | None:
    with connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchone()
