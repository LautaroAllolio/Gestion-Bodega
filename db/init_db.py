import os
import subprocess
import sys
import time
from pathlib import Path

import psycopg
from psycopg import sql

BASE_DIR = Path(__file__).resolve().parent
MIGRATIONS_DIR = BASE_DIR / "migrations"
LOAD_SCRIPT = BASE_DIR / "seed" / "load.py"


def connect_with_retry(dsn: str) -> psycopg.Connection:
    last_error: Exception | None = None
    for _ in range(30):
        try:
            return psycopg.connect(dsn, autocommit=True)
        except psycopg.OperationalError as exc:
            last_error = exc
            time.sleep(2)
    raise SystemExit(f"No se pudo conectar a PostgreSQL: {last_error}")


def run_sql_file(conn: psycopg.Connection, path: Path) -> None:
    script = path.read_text(encoding="utf-8")
    conn.execute(script)
    print(f"Ejecutado {path.name}")


def main() -> int:
    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        raise SystemExit("Falta DATABASE_URL")

    scale = os.getenv("SEED_SCALE", "1.0")
    force_reload = os.getenv("FORCE_RELOAD", "0") == "1"

    with connect_with_retry(dsn) as conn:
        schema_exists = (
            conn.execute("SELECT to_regclass('public.vino') IS NOT NULL").fetchone()[0]
        )

        if not schema_exists:
            for path in sorted(MIGRATIONS_DIR.glob("*.sql")):
                if path.name == "007_roles.sql":
                    continue
                run_sql_file(conn, path)

        run_sql_file(conn, MIGRATIONS_DIR / "007_roles.sql")

        for role, variable in (
            ("bodega_propietario", "BODEGA_PROPIETARIO_PASSWORD"),
            ("bodega_api", "BODEGA_API_PASSWORD"),
            ("bodega_lectura", "BODEGA_LECTURA_PASSWORD"),
        ):
            password = os.getenv(variable)
            if password:
                conn.execute(
                    sql.SQL("ALTER ROLE {} WITH PASSWORD {}").format(
                        sql.Identifier(role), sql.Literal(password)
                    )
                )

        vinos = conn.execute("SELECT count(*) FROM Vino").fetchone()[0]

    if force_reload or vinos == 0:
        subprocess.run(
            [
                sys.executable,
                str(LOAD_SCRIPT),
                "--dsn",
                dsn,
                "--reset",
                "--scale",
                scale,
            ],
            check=True,
        )
    else:
        print(f"Base existente con {vinos} vinos; se omite la carga")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
