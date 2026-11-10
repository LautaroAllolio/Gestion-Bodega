from typing import Any

from .db import fetch_all, fetch_one, transaction
from .errors import BusinessValidationError, NotFoundError

VINO_SELECT = """
SELECT v.codigo_vino, v.nombre_comercial, v.tipo, v.anada, v.presentacion_ml,
       v.graduacion_alcoholica, v.precio_venta, v.cuit_bodega,
       b.razon_social AS bodega
  FROM Vino v
  JOIN Bodega b ON b.cuit = v.cuit_bodega
"""

CLIENTE_SELECT = """
SELECT c.id_cliente, c.apellido, c.nombre, c.cuit, c.tipo_cliente,
       c.tipo_documento, c.nro_documento, c.calle_cliente, c.nro_calle_cliente,
       c.id_localidad, l.nombre AS localidad, c.fecha_alta,
       c.descuento_porcentaje, s.numero_socio, d.zona_cobertura,
       d.nro_habilitacion, e.pais_destino_principal
  FROM Cliente c
  JOIN Localidad l ON l.id_localidad = c.id_localidad
  LEFT JOIN SocioClub s ON s.id_cliente = c.id_cliente
  LEFT JOIN Distribuidor d ON d.id_cliente = c.id_cliente
  LEFT JOIN Exportador e ON e.id_cliente = c.id_cliente
"""

COMPROBANTE_SELECT = """
SELECT cv.nro_comprobante, cv.fecha, cv.id_cliente,
       (c.apellido || COALESCE(' ' || c.nombre, '')) AS cliente,
       cv.id_sala, (sv.calle || ' ' || sv.numero_calle) AS sala,
       cv.subtotal, cv.descuento, cv.total
  FROM ComprobanteVenta cv
  JOIN Cliente c ON c.id_cliente = cv.id_cliente
  JOIN SalaDeVenta sv ON sv.id_sala = cv.id_sala
"""

TRANSFERENCIA_SELECT = """
SELECT nro_transferencia, id_sala_solicitante, id_deposito,
       fecha_confeccion, estado::text AS estado
  FROM Transferencia
"""

INGRESO_SELECT = """
SELECT id_ingreso, fecha, estado::text AS estado, id_transporte,
       cuit_bodega, id_deposito
  FROM Ingreso
"""


def _exists(cur, table: str, column: str, value: Any) -> bool:
    cur.execute(f"SELECT 1 FROM {table} WHERE {column} = %s", (value,))
    return cur.fetchone() is not None


def get_vino(codigo_vino: str) -> dict[str, Any]:
    row = fetch_one(VINO_SELECT + " WHERE v.codigo_vino = %s", (codigo_vino,))
    if row is None:
        raise NotFoundError(f"No existe el vino {codigo_vino}")
    row["cepas"] = fetch_all(
        """
        SELECT vc.id_cepa, c.nombre, c.tipo, vc.porcentaje_corte
          FROM VinoCepa vc
          JOIN Cepa c ON c.id_cepa = vc.id_cepa
         WHERE vc.codigo_vino = %s
         ORDER BY c.nombre
        """,
        (codigo_vino,),
    )
    row["maridajes"] = fetch_all(
        """
        SELECT m.id_maridaje, m.nombre, m.temperatura_servicio
          FROM VinoMaridaje vm
          JOIN Maridaje m ON m.id_maridaje = vm.id_maridaje
         WHERE vm.codigo_vino = %s
         ORDER BY m.nombre
        """,
        (codigo_vino,),
    )
    stock = fetch_one(
        """
        SELECT stock_deposito, stock_salas, stock_total
          FROM vw_stock_total_vino
         WHERE codigo_vino = %s
        """,
        (codigo_vino,),
    )
    row.update(stock or {"stock_deposito": 0, "stock_salas": 0, "stock_total": 0})
    return row


def list_vinos(
    q: str | None,
    tipo: str | None,
    bodega: str | None,
    cepa: str | None,
    anada: int | None,
    page: int,
    limit: int,
) -> dict[str, Any]:
    where: list[str] = []
    params: list[Any] = []
    if q:
        where.append("(v.nombre_comercial ILIKE %s OR v.codigo_vino ILIKE %s)")
        params.extend([f"%{q}%", f"%{q}%"])
    if tipo:
        where.append("v.tipo = %s")
        params.append(tipo)
    if bodega:
        where.append("b.razon_social ILIKE %s")
        params.append(f"%{bodega}%")
    if cepa:
        where.append(
            """
            EXISTS (
                SELECT 1
                  FROM VinoCepa vc
                  JOIN Cepa c ON c.id_cepa = vc.id_cepa
                 WHERE vc.codigo_vino = v.codigo_vino
                   AND c.nombre ILIKE %s
            )
            """
        )
        params.append(f"%{cepa}%")
    if anada is not None:
        where.append("v.anada = %s")
        params.append(anada)
    clause = f" WHERE {' AND '.join(where)}" if where else ""
    total_row = fetch_one(
        "SELECT count(*) AS total FROM Vino v JOIN Bodega b ON b.cuit = v.cuit_bodega"
        + clause,
        tuple(params),
    )
    offset = (page - 1) * limit
    items = fetch_all(
        VINO_SELECT + clause + " ORDER BY v.nombre_comercial, v.codigo_vino LIMIT %s OFFSET %s",
        tuple(params + [limit, offset]),
    )
    return {
        "total": total_row["total"] if total_row else 0,
        "page": page,
        "limit": limit,
        "items": items,
    }


def create_vino(payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    cepas = data.pop("cepas")
    maridajes = data.pop("maridajes", [])
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO Vino
                    (codigo_vino, nombre_comercial, tipo, anada, presentacion_ml,
                     graduacion_alcoholica, precio_venta, cuit_bodega)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    data["codigo_vino"],
                    data["nombre_comercial"],
                    data["tipo"],
                    data["anada"],
                    data["presentacion_ml"],
                    data["graduacion_alcoholica"],
                    data["precio_venta"],
                    data["cuit_bodega"],
                ),
            )
            for cepa in cepas:
                cur.execute(
                    """
                    INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
                    VALUES (%s, %s, %s)
                    """,
                    (data["codigo_vino"], cepa["id_cepa"], cepa["porcentaje_corte"]),
                )
            for id_maridaje in maridajes:
                cur.execute(
                    "INSERT INTO VinoMaridaje (codigo_vino, id_maridaje) VALUES (%s, %s)",
                    (data["codigo_vino"], id_maridaje),
                )
    return get_vino(data["codigo_vino"])


def update_vino(codigo_vino: str, payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    cepas = data.pop("cepas", None)
    maridajes = data.pop("maridajes", None)
    if not data and cepas is None and maridajes is None:
        return get_vino(codigo_vino)
    with transaction() as conn:
        with conn.cursor() as cur:
            if data:
                assignments = ", ".join(f"{column} = %s" for column in data)
                cur.execute(
                    f"UPDATE Vino SET {assignments} WHERE codigo_vino = %s",
                    (*data.values(), codigo_vino),
                )
                if cur.rowcount == 0:
                    raise NotFoundError(f"No existe el vino {codigo_vino}")
            elif not _exists(cur, "Vino", "codigo_vino", codigo_vino):
                raise NotFoundError(f"No existe el vino {codigo_vino}")
            if cepas is not None:
                cur.execute("DELETE FROM VinoCepa WHERE codigo_vino = %s", (codigo_vino,))
                for cepa in cepas:
                    cur.execute(
                        """
                        INSERT INTO VinoCepa (codigo_vino, id_cepa, porcentaje_corte)
                        VALUES (%s, %s, %s)
                        """,
                        (codigo_vino, cepa["id_cepa"], cepa["porcentaje_corte"]),
                    )
            if maridajes is not None:
                cur.execute(
                    "DELETE FROM VinoMaridaje WHERE codigo_vino = %s", (codigo_vino,)
                )
                for id_maridaje in maridajes:
                    cur.execute(
                        "INSERT INTO VinoMaridaje (codigo_vino, id_maridaje) VALUES (%s, %s)",
                        (codigo_vino, id_maridaje),
                    )
    return get_vino(codigo_vino)


def delete_vino(codigo_vino: str) -> None:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM Vino WHERE codigo_vino = %s RETURNING codigo_vino",
                (codigo_vino,),
            )
            if cur.fetchone() is None:
                raise NotFoundError(f"No existe el vino {codigo_vino}")


def get_cliente(id_cliente: int) -> dict[str, Any]:
    row = fetch_one(CLIENTE_SELECT + " WHERE c.id_cliente = %s", (id_cliente,))
    if row is None:
        raise NotFoundError(f"No existe el cliente {id_cliente}")
    return row


def list_clientes(
    q: str | None,
    tipo_cliente: str | None,
    page: int,
    limit: int,
) -> dict[str, Any]:
    where: list[str] = []
    params: list[Any] = []
    if q:
        where.append(
            "(c.apellido ILIKE %s OR c.nombre ILIKE %s OR c.cuit ILIKE %s)"
        )
        params.extend([f"%{q}%", f"%{q}%", f"%{q}%"])
    if tipo_cliente:
        where.append("c.tipo_cliente = %s")
        params.append(tipo_cliente)
    clause = f" WHERE {' AND '.join(where)}" if where else ""
    total_row = fetch_one("SELECT count(*) AS total FROM Cliente c" + clause, tuple(params))
    offset = (page - 1) * limit
    items = fetch_all(
        CLIENTE_SELECT
        + clause
        + " ORDER BY c.apellido, c.nombre, c.id_cliente LIMIT %s OFFSET %s",
        tuple(params + [limit, offset]),
    )
    return {
        "total": total_row["total"] if total_row else 0,
        "page": page,
        "limit": limit,
        "items": items,
    }


def _insert_subtype(cur, id_cliente: int, tipo_cliente: str, data: dict[str, Any]) -> None:
    if tipo_cliente == "Socio":
        cur.execute(
            "INSERT INTO SocioClub (id_cliente, numero_socio) VALUES (%s, %s)",
            (id_cliente, data.get("numero_socio")),
        )
    elif tipo_cliente == "Distribuidor":
        zona = data.get("zona_cobertura")
        habilitacion = data.get("nro_habilitacion")
        if not zona or not habilitacion:
            raise BusinessValidationError(
                "Distribuidor requiere zona_cobertura y nro_habilitacion"
            )
        cur.execute(
            """
            INSERT INTO Distribuidor (id_cliente, zona_cobertura, nro_habilitacion)
            VALUES (%s, %s, %s)
            """,
            (id_cliente, zona, habilitacion),
        )
    elif tipo_cliente == "Exportador":
        pais = data.get("pais_destino_principal")
        if not pais:
            raise BusinessValidationError("Exportador requiere pais_destino_principal")
        cur.execute(
            """
            INSERT INTO Exportador (id_cliente, pais_destino_principal)
            VALUES (%s, %s)
            """,
            (id_cliente, pais),
        )


def _descuento_exportador(total_permisos: int) -> int:
    return 35 if total_permisos > 3 else 30


def _validate_cliente_discount(
    cur, id_cliente: int | None, tipo_cliente: str, descuento: Any
) -> None:
    descuentos_base = {"Socio": 10, "Distribuidor": 20}
    if tipo_cliente in descuentos_base:
        if descuento != descuentos_base[tipo_cliente]:
            raise BusinessValidationError(
                f"{tipo_cliente} debe tener {descuentos_base[tipo_cliente]}% de descuento"
            )
        return

    if tipo_cliente == "Exportador" and id_cliente is None and descuento == 30:
        return
    if tipo_cliente == "Exportador" and id_cliente is not None:
        cur.execute(
            "SELECT count(*) AS total FROM PermisoExportacion WHERE id_cliente = %s",
            (id_cliente,),
        )
        total_permisos = cur.fetchone()["total"]
        descuento_esperado = _descuento_exportador(total_permisos)
        if descuento == descuento_esperado:
            return
        raise BusinessValidationError(
            f"Con {total_permisos} permisos de exportación corresponde un descuento de "
            f"{descuento_esperado}%"
        )
    if tipo_cliente == "Exportador":
        raise BusinessValidationError(
            "Exportador debe tener 30% o, con más de tres permisos, 35% de descuento"
        )
    raise BusinessValidationError("Tipo de cliente inválido para el descuento")


def _sync_subtype(cur, id_cliente: int, tipo_cliente: str, data: dict[str, Any]) -> None:
    cur.execute(
        """
        SELECT c.tipo_cliente, s.numero_socio, d.zona_cobertura, d.nro_habilitacion,
               e.pais_destino_principal
          FROM Cliente c
          LEFT JOIN SocioClub s ON s.id_cliente = c.id_cliente
          LEFT JOIN Distribuidor d ON d.id_cliente = c.id_cliente
          LEFT JOIN Exportador e ON e.id_cliente = c.id_cliente
         WHERE c.id_cliente = %s
        """,
        (id_cliente,),
    )
    current = cur.fetchone()
    if current is None:
        raise NotFoundError(f"No existe el cliente {id_cliente}")
    values = dict(current)
    values.update({key: value for key, value in data.items() if value is not None})

    if current["tipo_cliente"] == tipo_cliente:
        subtype_updates = {
            "Socio": ("SocioClub", "numero_socio"),
            "Distribuidor": ("Distribuidor", "zona_cobertura, nro_habilitacion"),
            "Exportador": ("Exportador", "pais_destino_principal"),
        }
        table, columns = subtype_updates[tipo_cliente]
        fields = [column.strip() for column in columns.split(",")]
        assignments = ", ".join(f"{column} = %s" for column in fields)
        cur.execute(
            f"UPDATE {table} SET {assignments} WHERE id_cliente = %s",
            (*(values[field] for field in fields), id_cliente),
        )
        if cur.rowcount == 0:
            _insert_subtype(cur, id_cliente, tipo_cliente, values)
        return

    cur.execute("DELETE FROM SocioClub WHERE id_cliente = %s", (id_cliente,))
    cur.execute("DELETE FROM Distribuidor WHERE id_cliente = %s", (id_cliente,))
    cur.execute("DELETE FROM Exportador WHERE id_cliente = %s", (id_cliente,))
    _insert_subtype(cur, id_cliente, tipo_cliente, values)


def create_cliente(payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    with transaction() as conn:
        with conn.cursor() as cur:
            _validate_cliente_discount(
                cur, None, data["tipo_cliente"], data["descuento_porcentaje"]
            )
            cur.execute(
                """
                INSERT INTO Cliente
                    (apellido, nombre, cuit, tipo_cliente, tipo_documento,
                     nro_documento, calle_cliente, nro_calle_cliente, id_localidad,
                     fecha_alta, descuento_porcentaje)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,
                        COALESCE(%s, CURRENT_DATE), %s)
                RETURNING id_cliente
                """,
                (
                    data["apellido"],
                    data.get("nombre"),
                    data["cuit"],
                    data["tipo_cliente"],
                    data["tipo_documento"],
                    data["nro_documento"],
                    data["calle_cliente"],
                    data["nro_calle_cliente"],
                    data["id_localidad"],
                    data.get("fecha_alta"),
                    data["descuento_porcentaje"],
                ),
            )
            id_cliente = cur.fetchone()["id_cliente"]
            _insert_subtype(cur, id_cliente, data["tipo_cliente"], data)
    return get_cliente(id_cliente)


def update_cliente(id_cliente: int, payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    base_columns = {
        "apellido",
        "nombre",
        "cuit",
        "tipo_cliente",
        "tipo_documento",
        "nro_documento",
        "calle_cliente",
        "nro_calle_cliente",
        "id_localidad",
        "fecha_alta",
        "descuento_porcentaje",
    }
    subtype_columns = {
        "numero_socio",
        "zona_cobertura",
        "nro_habilitacion",
        "pais_destino_principal",
    }
    base = {key: value for key, value in data.items() if key in base_columns}
    needs_subtype = "tipo_cliente" in data or any(
        key in data for key in subtype_columns
    )
    if not base and not needs_subtype:
        return get_cliente(id_cliente)
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT tipo_cliente, descuento_porcentaje
                  FROM Cliente
                 WHERE id_cliente = %s
                 FOR UPDATE
                """,
                (id_cliente,),
            )
            current = cur.fetchone()
            if current is None:
                raise NotFoundError(f"No existe el cliente {id_cliente}")
            if (
                current["tipo_cliente"] == "Exportador"
                and data.get("tipo_cliente", "Exportador") != "Exportador"
            ):
                cur.execute(
                    "SELECT count(*) AS total FROM PermisoExportacion WHERE id_cliente = %s",
                    (id_cliente,),
                )
                if cur.fetchone()["total"] > 0:
                    raise BusinessValidationError(
                        "Elimine los permisos de exportación antes de cambiar el tipo de cliente"
                    )
            tipo_cliente_objetivo = data.get(
                "tipo_cliente", current["tipo_cliente"]
            )
            if (
                tipo_cliente_objetivo == "Exportador"
                and "descuento_porcentaje" not in data
            ):
                cur.execute(
                    "SELECT count(*) AS total FROM PermisoExportacion WHERE id_cliente = %s",
                    (id_cliente,),
                )
                total_permisos = cur.fetchone()["total"]
                descuento_esperado = _descuento_exportador(total_permisos)
                data["descuento_porcentaje"] = descuento_esperado
                if current["descuento_porcentaje"] != descuento_esperado:
                    base["descuento_porcentaje"] = descuento_esperado
            _validate_cliente_discount(
                cur,
                id_cliente,
                tipo_cliente_objetivo,
                data.get("descuento_porcentaje", current["descuento_porcentaje"]),
            )
            if base:
                assignments = ", ".join(f"{column} = %s" for column in base)
                cur.execute(
                    f"UPDATE Cliente SET {assignments} WHERE id_cliente = %s",
                    (*base.values(), id_cliente),
                )
                if cur.rowcount == 0:
                    raise NotFoundError(f"No existe el cliente {id_cliente}")
            elif not _exists(cur, "Cliente", "id_cliente", id_cliente):
                raise NotFoundError(f"No existe el cliente {id_cliente}")
            if needs_subtype:
                tipo_cliente = data.get("tipo_cliente")
                if tipo_cliente is None:
                    cur.execute(
                        "SELECT tipo_cliente FROM Cliente WHERE id_cliente = %s",
                        (id_cliente,),
                    )
                    row = cur.fetchone()
                    if row is None:
                        raise NotFoundError(f"No existe el cliente {id_cliente}")
                    tipo_cliente = row["tipo_cliente"]
                _sync_subtype(cur, id_cliente, tipo_cliente, data)
    return get_cliente(id_cliente)


def _lock_exportador(cur, id_cliente: int) -> None:
    cur.execute(
        "SELECT tipo_cliente FROM Cliente WHERE id_cliente = %s FOR UPDATE",
        (id_cliente,),
    )
    cliente = cur.fetchone()
    if cliente is None:
        raise NotFoundError(f"No existe el cliente {id_cliente}")
    if cliente["tipo_cliente"] != "Exportador":
        raise BusinessValidationError(
            "Los permisos solo corresponden a clientes Exportadores"
        )


def list_permisos_exportacion(id_cliente: int) -> list[dict[str, Any]]:
    with transaction() as conn:
        with conn.cursor() as cur:
            _lock_exportador(cur, id_cliente)
            cur.execute(
                """
                SELECT id_permiso, codigo_permiso, fecha_emision, fecha_vencimiento
                  FROM PermisoExportacion
                 WHERE id_cliente = %s
                 ORDER BY fecha_emision, id_permiso
                """,
                (id_cliente,),
            )
            return cur.fetchall()


def create_permiso_exportacion(
    id_cliente: int, payload: dict[str, Any]
) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            _lock_exportador(cur, id_cliente)
            cur.execute(
                """
                INSERT INTO PermisoExportacion
                    (id_cliente, codigo_permiso, fecha_emision, fecha_vencimiento)
                VALUES (%s, %s, %s, %s)
                RETURNING id_permiso, codigo_permiso, fecha_emision, fecha_vencimiento
                """,
                (
                    id_cliente,
                    payload["codigo_permiso"],
                    payload["fecha_emision"],
                    payload["fecha_vencimiento"],
                ),
            )
            permiso = cur.fetchone()
            cur.execute(
                "SELECT count(*) AS total FROM PermisoExportacion WHERE id_cliente = %s",
                (id_cliente,),
            )
            descuento = _descuento_exportador(cur.fetchone()["total"])
            cur.execute(
                """
                UPDATE Cliente
                   SET descuento_porcentaje = %s
                 WHERE id_cliente = %s AND descuento_porcentaje <> %s
                """,
                (descuento, id_cliente, descuento),
            )
            return permiso


def delete_permiso_exportacion(id_cliente: int, id_permiso: int) -> None:
    with transaction() as conn:
        with conn.cursor() as cur:
            _lock_exportador(cur, id_cliente)
            cur.execute(
                """
                DELETE FROM PermisoExportacion
                 WHERE id_cliente = %s AND id_permiso = %s
                RETURNING id_permiso
                """,
                (id_cliente, id_permiso),
            )
            if cur.fetchone() is None:
                raise NotFoundError(
                    f"No existe el permiso {id_permiso} para el cliente {id_cliente}"
                )
            cur.execute(
                "SELECT count(*) AS total FROM PermisoExportacion WHERE id_cliente = %s",
                (id_cliente,),
            )
            descuento = _descuento_exportador(cur.fetchone()["total"])
            cur.execute(
                """
                UPDATE Cliente
                   SET descuento_porcentaje = %s
                 WHERE id_cliente = %s AND descuento_porcentaje <> %s
                """,
                (descuento, id_cliente, descuento),
            )


def delete_cliente(id_cliente: int) -> None:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM Cliente WHERE id_cliente = %s RETURNING id_cliente",
                (id_cliente,),
            )
            if cur.fetchone() is None:
                raise NotFoundError(f"No existe el cliente {id_cliente}")


def get_comprobante(nro_comprobante: int) -> dict[str, Any]:
    row = fetch_one(
        COMPROBANTE_SELECT + " WHERE cv.nro_comprobante = %s", (nro_comprobante,)
    )
    if row is None:
        raise NotFoundError(f"No existe el comprobante {nro_comprobante}")
    row["renglones"] = fetch_all(
        """
        SELECT dv.codigo_vino, v.nombre_comercial, dv.cantidad,
               dv.precio_unitario, dv.descuento_aplicado, dv.subtotal
          FROM DetalleVenta dv
          JOIN Vino v ON v.codigo_vino = dv.codigo_vino
         WHERE dv.nro_comprobante = %s
         ORDER BY dv.codigo_vino
        """,
        (nro_comprobante,),
    )
    return row


def create_comprobante(payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ComprobanteVenta
                    (fecha, id_cliente, id_sala, subtotal, descuento, total)
                VALUES (COALESCE(%s, CURRENT_DATE), %s, %s, 0, 0, 0)
                RETURNING nro_comprobante
                """,
                (data.get("fecha"), data["id_cliente"], data["id_sala"]),
            )
            nro = cur.fetchone()["nro_comprobante"]
            for renglon in data["renglones"]:
                cur.execute(
                    """
                    INSERT INTO DetalleVenta
                        (nro_comprobante, codigo_vino, cantidad,
                         precio_unitario, descuento_aplicado, subtotal)
                    VALUES (%s, %s, %s, 0, 0, 0)
                    """,
                    (nro, renglon["codigo_vino"], renglon["cantidad"]),
                )
    return get_comprobante(nro)


class _QuoteRollback(Exception):
    def __init__(self, result: dict[str, Any]) -> None:
        self.result = result


def quote_comprobante(payload: dict[str, Any]) -> dict[str, Any]:
    data = dict(payload)
    try:
        with transaction() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO ComprobanteVenta
                        (fecha, id_cliente, id_sala, subtotal, descuento, total)
                    VALUES (COALESCE(%s, CURRENT_DATE), %s, %s, 0, 0, 0)
                    RETURNING nro_comprobante
                    """,
                    (data.get("fecha"), data["id_cliente"], data["id_sala"]),
                )
                nro = cur.fetchone()["nro_comprobante"]
                for renglon in data["renglones"]:
                    cur.execute(
                        """
                        INSERT INTO DetalleVenta
                            (nro_comprobante, codigo_vino, cantidad,
                             precio_unitario, descuento_aplicado, subtotal)
                        VALUES (%s, %s, %s, 0, 0, 0)
                        """,
                        (nro, renglon["codigo_vino"], renglon["cantidad"]),
                    )
                cur.execute(
                    COMPROBANTE_SELECT + " WHERE cv.nro_comprobante = %s", (nro,)
                )
                row = cur.fetchone()
                cur.execute(
                    """
                    SELECT dv.codigo_vino, v.nombre_comercial, dv.cantidad,
                           dv.precio_unitario, dv.descuento_aplicado, dv.subtotal
                      FROM DetalleVenta dv
                      JOIN Vino v ON v.codigo_vino = dv.codigo_vino
                     WHERE dv.nro_comprobante = %s
                     ORDER BY dv.codigo_vino
                    """,
                    (nro,),
                )
                row["renglones"] = cur.fetchall()
                raise _QuoteRollback(row)
    except _QuoteRollback as exc:
        return exc.result


def list_transferencias(
    estado: str | None,
    page: int,
    limit: int,
) -> dict[str, Any]:
    where: list[str] = []
    params: list[Any] = []
    if estado:
        where.append("estado = %s")
        params.append(estado)
    clause = f" WHERE {' AND '.join(where)}" if where else ""
    total_row = fetch_one(
        "SELECT count(*) AS total FROM Transferencia" + clause, tuple(params)
    )
    offset = (page - 1) * limit
    items = fetch_all(
        """
        SELECT nro_transferencia, id_sala_solicitante, id_deposito,
               fecha_confeccion, estado::text AS estado
          FROM Transferencia
        """
        + clause
        + " ORDER BY nro_transferencia DESC LIMIT %s OFFSET %s",
        tuple(params + [limit, offset]),
    )
    return {
        "total": total_row["total"] if total_row else 0,
        "page": page,
        "limit": limit,
        "items": items,
    }


def get_transferencia(nro_transferencia: int) -> dict[str, Any]:
    row = fetch_one(
        TRANSFERENCIA_SELECT + " WHERE nro_transferencia = %s", (nro_transferencia,)
    )
    if row is None:
        raise NotFoundError(f"No existe la transferencia {nro_transferencia}")
    row["renglones"] = fetch_all(
        """
        SELECT dt.codigo_vino, v.nombre_comercial, dt.cantidad
          FROM DetalleTransferencia dt
          JOIN Vino v ON v.codigo_vino = dt.codigo_vino
         WHERE dt.nro_transferencia = %s
         ORDER BY dt.codigo_vino
        """,
        (nro_transferencia,),
    )
    return row


def create_transferencia(payload: dict[str, Any]) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO Transferencia
                    (id_sala_solicitante, id_deposito, estado)
                VALUES (%s, %s, 'en_confeccion')
                RETURNING nro_transferencia
                """,
                (payload["id_sala_solicitante"], payload["id_deposito"]),
            )
            nro = cur.fetchone()["nro_transferencia"]
    return get_transferencia(nro)


def add_renglon_transferencia(
    nro_transferencia: int, payload: dict[str, Any]
) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            if not _exists(
                cur, "Transferencia", "nro_transferencia", nro_transferencia
            ):
                raise NotFoundError(f"No existe la transferencia {nro_transferencia}")
            cur.execute(
                """
                INSERT INTO DetalleTransferencia
                    (nro_transferencia, codigo_vino, cantidad)
                VALUES (%s, %s, %s)
                """,
                (
                    nro_transferencia,
                    payload["codigo_vino"],
                    payload["cantidad"],
                ),
            )
    return get_transferencia(nro_transferencia)


def terminar_transferencia(nro_transferencia: int) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE Transferencia SET estado = 'terminado'
                 WHERE nro_transferencia = %s
                """,
                (nro_transferencia,),
            )
            if cur.rowcount == 0:
                raise NotFoundError(f"No existe la transferencia {nro_transferencia}")
    return get_transferencia(nro_transferencia)


def procesar_transferencia(nro_transferencia: int) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            if not _exists(
                cur, "Transferencia", "nro_transferencia", nro_transferencia
            ):
                raise NotFoundError(f"No existe la transferencia {nro_transferencia}")
            cur.execute("CALL sp_procesar_transferencia(%s)", (nro_transferencia,))
    return get_transferencia(nro_transferencia)


def get_ingreso(id_ingreso: int) -> dict[str, Any]:
    row = fetch_one(INGRESO_SELECT + " WHERE id_ingreso = %s", (id_ingreso,))
    if row is None:
        raise NotFoundError(f"No existe el ingreso {id_ingreso}")
    row["renglones"] = fetch_all(
        """
        SELECT di.codigo_vino, v.nombre_comercial, di.cantidad_botellas
          FROM DetalleIngreso di
          JOIN Vino v ON v.codigo_vino = di.codigo_vino
         WHERE di.id_ingreso = %s
         ORDER BY di.codigo_vino
        """,
        (id_ingreso,),
    )
    return row


def create_ingreso(payload: dict[str, Any]) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO Ingreso
                    (fecha, estado, id_transporte, cuit_bodega, id_deposito)
                VALUES (COALESCE(%s, CURRENT_DATE), 'en_confeccion', %s, %s, %s)
                RETURNING id_ingreso
                """,
                (
                    payload.get("fecha"),
                    payload["id_transporte"],
                    payload["cuit_bodega"],
                    payload["id_deposito"],
                ),
            )
            id_ingreso = cur.fetchone()["id_ingreso"]
    return get_ingreso(id_ingreso)


def add_renglon_ingreso(id_ingreso: int, payload: dict[str, Any]) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            if not _exists(cur, "Ingreso", "id_ingreso", id_ingreso):
                raise NotFoundError(f"No existe el ingreso {id_ingreso}")
            cur.execute(
                """
                INSERT INTO DetalleIngreso
                    (id_ingreso, codigo_vino, cantidad_botellas)
                VALUES (%s, %s, %s)
                """,
                (id_ingreso, payload["codigo_vino"], payload["cantidad_botellas"]),
            )
    return get_ingreso(id_ingreso)


def terminar_ingreso(id_ingreso: int) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "UPDATE Ingreso SET estado = 'terminado' WHERE id_ingreso = %s",
                (id_ingreso,),
            )
            if cur.rowcount == 0:
                raise NotFoundError(f"No existe el ingreso {id_ingreso}")
    return get_ingreso(id_ingreso)


def procesar_ingreso(id_ingreso: int) -> dict[str, Any]:
    with transaction() as conn:
        with conn.cursor() as cur:
            if not _exists(cur, "Ingreso", "id_ingreso", id_ingreso):
                raise NotFoundError(f"No existe el ingreso {id_ingreso}")
            cur.execute("CALL sp_procesar_ingreso(%s)", (id_ingreso,))
    return get_ingreso(id_ingreso)


def list_bodegas() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT cuit, razon_social
          FROM Bodega
         ORDER BY razon_social, cuit
        """
    )


def list_cepas() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT id_cepa, nombre, tipo
          FROM Cepa
         ORDER BY nombre, id_cepa
        """
    )


def list_maridajes() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT id_maridaje, nombre, temperatura_servicio
          FROM Maridaje
         ORDER BY nombre, id_maridaje
        """
    )


def list_salas() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT s.id_sala, s.calle, s.numero_calle, s.id_localidad,
               l.nombre AS localidad
          FROM SalaDeVenta s
          JOIN Localidad l ON l.id_localidad = s.id_localidad
         ORDER BY l.nombre, s.calle, s.numero_calle, s.id_sala
        """
    )


def list_depositos() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT id_deposito, nombre
          FROM DepositoCentral
         ORDER BY nombre, id_deposito
        """
    )


def list_localidades() -> list[dict[str, Any]]:
    return fetch_all(
        """
        SELECT id_localidad, nombre, provincia
          FROM Localidad
         ORDER BY provincia, nombre, id_localidad
        """
    )
