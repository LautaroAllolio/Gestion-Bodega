import os
from typing import Any

import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql://bodega_api@127.0.0.1:55432/bodega_api_test",
)
TEST_ADMIN_URL = os.getenv(
    "TEST_ADMIN_URL",
    "postgresql://postgres@127.0.0.1:55432/postgres",
)
TEST_DB_NAME = os.getenv("TEST_DB_NAME") or conninfo_to_dict(TEST_DATABASE_URL).get(
    "dbname", "bodega_api_test"
)
TEST_TEMPLATE_DB = os.getenv("TEST_TEMPLATE_DB", "bodega_seed")

os.environ["DATABASE_URL"] = TEST_DATABASE_URL

from api.main import app


def _create_test_database() -> None:
    with psycopg.connect(TEST_ADMIN_URL, autocommit=True) as conn:
        conn.execute(
            """
            SELECT pg_terminate_backend(pid)
              FROM pg_stat_activity
             WHERE datname = %s AND pid <> pg_backend_pid()
            """,
            (TEST_DB_NAME,),
        )
        conn.execute(
            sql.SQL("DROP DATABASE IF EXISTS {}").format(sql.Identifier(TEST_DB_NAME))
        )
        conn.execute(
            sql.SQL("CREATE DATABASE {} TEMPLATE {}").format(
                sql.Identifier(TEST_DB_NAME),
                sql.Identifier(TEST_TEMPLATE_DB),
            )
        )


@pytest.fixture(scope="session", autouse=True)
def database() -> None:
    if os.getenv("CREATE_TEST_DB", "1") == "1":
        _create_test_database()


@pytest.fixture(scope="session")
def client(database) -> TestClient:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(scope="session")
def seed(database) -> dict[str, Any]:
    with psycopg.connect(TEST_DATABASE_URL, row_factory=dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT cuit FROM Bodega ORDER BY cuit LIMIT 1")
            bodega = cur.fetchone()["cuit"]

            cur.execute("SELECT id_cepa FROM Cepa ORDER BY id_cepa LIMIT 2")
            cepas = [row["id_cepa"] for row in cur.fetchall()]

            cur.execute("SELECT id_maridaje FROM Maridaje ORDER BY id_maridaje LIMIT 1")
            maridaje = cur.fetchone()["id_maridaje"]

            cur.execute("SELECT id_localidad FROM Localidad ORDER BY id_localidad LIMIT 1")
            localidad = cur.fetchone()["id_localidad"]

            cur.execute("SELECT id_cliente FROM Cliente ORDER BY id_cliente LIMIT 1")
            cliente = cur.fetchone()["id_cliente"]

            cur.execute("SELECT id_sala FROM SalaDeVenta ORDER BY id_sala LIMIT 1")
            sala = cur.fetchone()["id_sala"]

            cur.execute("SELECT id_deposito FROM DepositoCentral ORDER BY id_deposito LIMIT 1")
            deposito = cur.fetchone()["id_deposito"]

            cur.execute("SELECT id_transporte FROM Transportista ORDER BY id_transporte LIMIT 1")
            transporte = cur.fetchone()["id_transporte"]

            cur.execute(
                """
                SELECT ss.id_sala, ss.codigo_vino, ss.cantidad
                  FROM StockSala ss
                 WHERE ss.cantidad >= 10
                 ORDER BY ss.id_sala, ss.codigo_vino
                 LIMIT 1
                """
            )
            stock_sala = cur.fetchone()

            cur.execute(
                """
                SELECT sd.id_deposito, sd.codigo_vino, sd.cantidad
                  FROM StockDeposito sd
                 WHERE sd.cantidad >= 10
                 ORDER BY sd.id_deposito, sd.codigo_vino
                 LIMIT 1
                """
            )
            stock_deposito = cur.fetchone()

    return {
        "cuit_bodega": bodega,
        "cepa_1": cepas[0],
        "cepa_2": cepas[1],
        "id_maridaje": maridaje,
        "id_localidad": localidad,
        "id_cliente": cliente,
        "id_sala": sala,
        "id_deposito": deposito,
        "id_transporte": transporte,
        "stock_sala": stock_sala,
        "stock_deposito": stock_deposito,
    }
