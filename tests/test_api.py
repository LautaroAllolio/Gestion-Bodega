import uuid

import pytest
from pydantic import ValidationError
from fastapi.testclient import TestClient

from api.db import fetch_one, transaction
from api.repository import _descuento_exportador
from api.schemas import PermisoExportacionCreate


def _vino_payload(seed: dict, codigo: str) -> dict:
    return {
        "codigo_vino": codigo,
        "nombre_comercial": f"Vino {codigo}",
        "tipo": "Tinto",
        "anada": 2024,
        "presentacion_ml": 750,
        "graduacion_alcoholica": 13.5,
        "precio_venta": 15000.0,
        "cuit_bodega": seed["cuit_bodega"],
        "cepas": [
            {"id_cepa": seed["cepa_1"], "porcentaje_corte": 60},
            {"id_cepa": seed["cepa_2"], "porcentaje_corte": 40},
        ],
        "maridajes": [seed["id_maridaje"]],
    }


def _cuit() -> str:
    return str(90000000000 + uuid.uuid4().int % 9999999999)


def test_salud(client: TestClient):
    response = client.get("/salud")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["database"]


def test_listado_y_busqueda_parametrizada(client: TestClient):
    response = client.get("/vinos", params={"q": "' OR 1=1 --"})
    assert response.status_code == 200
    assert response.json()["total"] == 0

    response = client.get("/vinos", params={"tipo": "Tinto", "limit": 5})
    assert response.status_code == 200
    assert len(response.json()["items"]) <= 5
    assert all(item["tipo"] == "Tinto" for item in response.json()["items"])


def test_crud_vino(client: TestClient, seed: dict):
    codigo = f"T{uuid.uuid4().hex[:12].upper()}"
    created = client.post("/vinos", json=_vino_payload(seed, codigo))
    assert created.status_code == 201
    assert created.json()["codigo_vino"] == codigo
    assert created.json()["stock_total"] == 0

    updated = client.patch(f"/vinos/{codigo}", json={"nombre_comercial": f"Vino {codigo} 2"})
    assert updated.status_code == 200
    assert updated.json()["nombre_comercial"] == f"Vino {codigo} 2"

    deleted = client.delete(f"/vinos/{codigo}")
    assert deleted.status_code == 204
    assert client.get(f"/vinos/{codigo}").status_code == 404


def test_put_vino_reemplaza_recurso_completo(client: TestClient, seed: dict):
    codigo = f"R{uuid.uuid4().hex[:12].upper()}"
    payload = _vino_payload(seed, codigo)
    assert client.post("/vinos", json=payload).status_code == 201

    replacement = {
        key: value for key, value in payload.items() if key != "codigo_vino"
    }
    replacement["nombre_comercial"] = f"Reemplazo {codigo}"
    response = client.put(f"/vinos/{codigo}", json=replacement)

    assert response.status_code == 200
    assert response.json()["nombre_comercial"] == f"Reemplazo {codigo}"
    assert client.patch(
        f"/vinos/{codigo}", json={"nombre_comercial": f"Parche {codigo}"}
    ).json()["nombre_comercial"] == f"Parche {codigo}"
    assert client.delete(f"/vinos/{codigo}").status_code == 204


def test_put_vino_requiere_representacion_completa(client: TestClient, seed: dict):
    codigo = f"U{uuid.uuid4().hex[:12].upper()}"
    assert client.post("/vinos", json=_vino_payload(seed, codigo)).status_code == 201

    response = client.put(f"/vinos/{codigo}", json={"nombre_comercial": "Incompleto"})

    assert response.status_code == 422
    assert client.get(f"/vinos/{codigo}").json()["nombre_comercial"] == f"Vino {codigo}"
    assert client.delete(f"/vinos/{codigo}").status_code == 204


def test_precio_negativo_rechazado(client: TestClient, seed: dict):
    codigo = f"P{uuid.uuid4().hex[:12].upper()}"
    assert client.post("/vinos", json=_vino_payload(seed, codigo)).status_code == 201

    response = client.patch(f"/vinos/{codigo}", json={"precio_venta": -1})
    assert response.status_code == 422
    assert response.json()["sqlstate"] == "23514"
    assert client.delete(f"/vinos/{codigo}").status_code == 204


def test_composicion_invalida_rechazada(client: TestClient, seed: dict):
    codigo = f"C{uuid.uuid4().hex[:12].upper()}"
    payload = _vino_payload(seed, codigo)
    payload["cepas"] = [
        {"id_cepa": seed["cepa_1"], "porcentaje_corte": 50},
        {"id_cepa": seed["cepa_2"], "porcentaje_corte": 40},
    ]
    response = client.post("/vinos", json=payload)
    assert response.status_code == 409
    assert response.json()["sqlstate"] == "P0001"
    assert "suman 90" in response.json()["detail"]


def test_crud_cliente(client: TestClient, seed: dict):
    payload = {
        "apellido": "Prueba",
        "nombre": "Distribuidor",
        "cuit": _cuit(),
        "tipo_cliente": "Distribuidor",
        "tipo_documento": "DNI",
        "nro_documento": uuid.uuid4().hex[:10],
        "calle_cliente": "San Martin",
        "nro_calle_cliente": 123,
        "id_localidad": seed["id_localidad"],
        "descuento_porcentaje": 20,
        "zona_cobertura": "Mendoza",
        "nro_habilitacion": "HAB-1",
    }
    created = client.post("/clientes", json=payload)
    assert created.status_code == 201
    id_cliente = created.json()["id_cliente"]

    updated = client.patch(
        f"/clientes/{id_cliente}", json={"zona_cobertura": "Cuyo"}
    )
    assert updated.status_code == 200
    assert updated.json()["zona_cobertura"] == "Cuyo"

    assert client.delete(f"/clientes/{id_cliente}").status_code == 204
    assert client.get(f"/clientes/{id_cliente}").status_code == 404


def test_descuento_exportador_35_requiere_mas_de_tres_permisos(
    client: TestClient, seed: dict
):
    payload = {
        "apellido": "Exportador de prueba",
        "nombre": None,
        "cuit": _cuit(),
        "tipo_cliente": "Exportador",
        "tipo_documento": "CUIT",
        "nro_documento": _cuit(),
        "calle_cliente": "San Martin",
        "nro_calle_cliente": 123,
        "id_localidad": seed["id_localidad"],
        "descuento_porcentaje": 30,
        "pais_destino_principal": "Chile",
    }
    created = client.post("/clientes", json=payload)
    assert created.status_code == 201
    id_cliente = created.json()["id_cliente"]
    try:
        rejected = client.patch(
            f"/clientes/{id_cliente}", json={"descuento_porcentaje": 35}
        )
        assert rejected.status_code == 422

        with transaction() as conn:
            with conn.cursor() as cur:
                for index in range(4):
                    cur.execute(
                        """
                        INSERT INTO PermisoExportacion
                            (id_cliente, codigo_permiso, fecha_emision, fecha_vencimiento)
                        VALUES (%s, %s, DATE '2025-01-01', DATE '2026-01-01')
                        """,
                        (id_cliente, f"TEST-{uuid.uuid4().hex}-{index}"),
                    )

        normalized = client.patch(
            f"/clientes/{id_cliente}", json={"apellido": "Exportador normalizado"}
        )
        assert normalized.status_code == 200
        assert normalized.json()["descuento_porcentaje"] == 35

        rejected_30 = client.patch(
            f"/clientes/{id_cliente}", json={"descuento_porcentaje": 30}
        )
        assert rejected_30.status_code == 422

        accepted = client.patch(
            f"/clientes/{id_cliente}", json={"descuento_porcentaje": 35}
        )
        assert accepted.status_code == 200

        replacement = {
            key: value
            for key, value in created.json().items()
            if key in {
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
                "numero_socio",
                "zona_cobertura",
                "nro_habilitacion",
                "pais_destino_principal",
            }
        }
        replacement["apellido"] = "Exportador actualizado"
        replacement["descuento_porcentaje"] = 35
        updated = client.put(f"/clientes/{id_cliente}", json=replacement)

        assert updated.status_code == 200
        assert fetch_one(
            "SELECT count(*) AS total FROM PermisoExportacion WHERE id_cliente = %s",
            (id_cliente,),
        )["total"] == 4
    finally:
        client.delete(f"/clientes/{id_cliente}")


def test_crud_permisos_exportador_actualiza_descuento(
    client: TestClient, seed: dict
):
    payload = {
        "apellido": "Exportador con permisos",
        "nombre": None,
        "cuit": _cuit(),
        "tipo_cliente": "Exportador",
        "tipo_documento": "CUIT",
        "nro_documento": _cuit(),
        "calle_cliente": "San Martin",
        "nro_calle_cliente": 123,
        "id_localidad": seed["id_localidad"],
        "descuento_porcentaje": 30,
        "pais_destino_principal": "Chile",
    }
    created = client.post("/clientes", json=payload)
    assert created.status_code == 201
    id_cliente = created.json()["id_cliente"]

    try:
        assert client.get(f"/clientes/{id_cliente}/permisos").json() == []
        permisos = []
        for index in range(4):
            response = client.post(
                f"/clientes/{id_cliente}/permisos",
                json={
                    "codigo_permiso": f"TEST-{uuid.uuid4().hex}-{index}",
                    "fecha_emision": "2026-01-01",
                    "fecha_vencimiento": "2027-01-01",
                },
            )
            assert response.status_code == 201
            permisos.append(response.json())

        assert len(client.get(f"/clientes/{id_cliente}/permisos").json()) == 4
        assert client.get(f"/clientes/{id_cliente}").json()["descuento_porcentaje"] == 35

        deleted = client.delete(
            f"/clientes/{id_cliente}/permisos/{permisos[0]['id_permiso']}"
        )

        assert deleted.status_code == 204
        assert len(client.get(f"/clientes/{id_cliente}/permisos").json()) == 3
        assert client.get(f"/clientes/{id_cliente}").json()["descuento_porcentaje"] == 30
        assert client.patch(
            f"/clientes/{id_cliente}", json={"descuento_porcentaje": 35}
        ).status_code == 422
    finally:
        client.delete(f"/clientes/{id_cliente}")


def test_permisos_solo_se_pueden_asignar_a_exportadores(
    client: TestClient, seed: dict
):
    payload = {
        "apellido": "Socio sin permisos",
        "nombre": None,
        "cuit": _cuit(),
        "tipo_cliente": "Socio",
        "tipo_documento": "DNI",
        "nro_documento": uuid.uuid4().hex[:10],
        "calle_cliente": "San Martin",
        "nro_calle_cliente": 123,
        "id_localidad": seed["id_localidad"],
        "descuento_porcentaje": 10,
        "numero_socio": 900000 + uuid.uuid4().int % 99999,
    }
    created = client.post("/clientes", json=payload)
    assert created.status_code == 201
    id_cliente = created.json()["id_cliente"]
    try:
        response = client.post(
            f"/clientes/{id_cliente}/permisos",
            json={
                "codigo_permiso": "NO-EXPORTADOR",
                "fecha_emision": "2026-01-01",
                "fecha_vencimiento": "2027-01-01",
            },
        )

        assert response.status_code == 422
    finally:
        client.delete(f"/clientes/{id_cliente}")


def test_permiso_rechaza_vencimiento_anterior_a_emision(
    client: TestClient, seed: dict
):
    response = client.post(
        f"/clientes/{seed['id_cliente']}/permisos",
        json={
            "codigo_permiso": "FECHAS-INVALIDAS",
            "fecha_emision": "2027-01-01",
            "fecha_vencimiento": "2026-01-01",
        },
    )

    assert response.status_code == 422


def test_schema_permiso_acepta_fechas_validas():
    permiso = PermisoExportacionCreate.model_validate(
        {
            "codigo_permiso": "PERM-1",
            "fecha_emision": "2026-01-01",
            "fecha_vencimiento": "2027-01-01",
        }
    )

    assert permiso.codigo_permiso == "PERM-1"


def test_schema_permiso_rechaza_fechas_invalidas():
    with pytest.raises(ValidationError):
        PermisoExportacionCreate.model_validate(
            {
                "codigo_permiso": "PERM-1",
                "fecha_emision": "2027-01-01",
                "fecha_vencimiento": "2026-01-01",
            }
        )


def test_schema_permiso_rechaza_codigo_vacio():
    with pytest.raises(ValidationError):
        PermisoExportacionCreate.model_validate(
            {
                "codigo_permiso": "   ",
                "fecha_emision": "2026-01-01",
                "fecha_vencimiento": "2027-01-01",
            }
        )


@pytest.mark.parametrize(("total_permisos", "descuento"), [(0, 30), (3, 30), (4, 35)])
def test_descuento_exportador_segun_cantidad_de_permisos(
    total_permisos: int, descuento: int
):
    assert _descuento_exportador(total_permisos) == descuento


def test_no_se_puede_cambiar_tipo_si_exportador_tiene_permisos(
    client: TestClient, seed: dict
):
    payload = {
        "apellido": "Exportador protegido",
        "nombre": None,
        "cuit": _cuit(),
        "tipo_cliente": "Exportador",
        "tipo_documento": "CUIT",
        "nro_documento": _cuit(),
        "calle_cliente": "San Martin",
        "nro_calle_cliente": 123,
        "id_localidad": seed["id_localidad"],
        "descuento_porcentaje": 30,
        "pais_destino_principal": "Chile",
    }
    created = client.post("/clientes", json=payload)
    assert created.status_code == 201
    id_cliente = created.json()["id_cliente"]
    try:
        permission = client.post(
            f"/clientes/{id_cliente}/permisos",
            json={
                "codigo_permiso": f"TEST-{uuid.uuid4().hex}",
                "fecha_emision": "2026-01-01",
                "fecha_vencimiento": "2027-01-01",
            },
        )
        assert permission.status_code == 201

        response = client.patch(
            f"/clientes/{id_cliente}",
            json={
                "tipo_cliente": "Socio",
                "descuento_porcentaje": 10,
                "numero_socio": 900000 + uuid.uuid4().int % 99999,
            },
        )

        assert response.status_code == 422
        assert client.get(f"/clientes/{id_cliente}").json()["tipo_cliente"] == "Exportador"
        assert len(client.get(f"/clientes/{id_cliente}/permisos").json()) == 1
    finally:
        client.delete(f"/clientes/{id_cliente}")


def test_crear_cliente_rechaza_descuento_que_no_corresponde_al_tipo(
    client: TestClient, seed: dict
):
    response = client.post(
        "/clientes",
        json={
            "apellido": "Socio",
            "nombre": "Descuento inválido",
            "cuit": _cuit(),
            "tipo_cliente": "Socio",
            "tipo_documento": "DNI",
            "nro_documento": "12345678",
            "calle_cliente": "San Martin",
            "nro_calle_cliente": 123,
            "id_localidad": seed["id_localidad"],
            "descuento_porcentaje": 80,
            "numero_socio": 900000 + uuid.uuid4().int % 99999,
        },
    )

    if response.status_code == 201:
        client.delete(f"/clientes/{response.json()['id_cliente']}")
    assert response.status_code == 422


def test_actualizar_cliente_rechaza_descuento_fuera_de_reglas(
    client: TestClient, seed: dict
):
    response = client.patch(
        f"/clientes/{seed['id_cliente']}",
        json={"descuento_porcentaje": 80},
    )

    assert response.status_code == 422


def test_put_cliente_reemplaza_recurso_y_subtipo(client: TestClient, seed: dict):
    payload = {
        "apellido": "Prueba",
        "nombre": "Distribuidor",
        "cuit": _cuit(),
        "tipo_cliente": "Distribuidor",
        "tipo_documento": "DNI",
        "nro_documento": uuid.uuid4().hex[:10],
        "calle_cliente": "San Martin",
        "nro_calle_cliente": 123,
        "id_localidad": seed["id_localidad"],
        "descuento_porcentaje": 20,
        "zona_cobertura": "Mendoza",
        "nro_habilitacion": "HAB-PUT",
    }
    created = client.post("/clientes", json=payload)
    assert created.status_code == 201
    id_cliente = created.json()["id_cliente"]
    replacement = {
        **payload,
        "apellido": "Socio",
        "descuento_porcentaje": 10,
        "fecha_alta": created.json()["fecha_alta"],
        "tipo_cliente": "Socio",
        "numero_socio": 900000 + uuid.uuid4().int % 99999,
        "zona_cobertura": None,
        "nro_habilitacion": None,
        "pais_destino_principal": None,
    }

    response = client.put(f"/clientes/{id_cliente}", json=replacement)

    assert response.status_code == 200
    assert response.json()["tipo_cliente"] == "Socio"
    assert response.json()["numero_socio"] == replacement["numero_socio"]
    assert response.json()["zona_cobertura"] is None
    assert client.patch(
        f"/clientes/{id_cliente}", json={"apellido": "Parche"}
    ).json()["apellido"] == "Parche"
    assert client.delete(f"/clientes/{id_cliente}").status_code == 204


def test_put_cliente_requiere_representacion_completa(client: TestClient, seed: dict):
    response = client.put(
        f"/clientes/{seed['id_cliente']}", json={"apellido": "Incompleto"}
    )

    assert response.status_code == 422


def test_put_cliente_rechaza_datos_de_subtipo_fuera_de_limite(
    client: TestClient, seed: dict
):
    response = client.put(
        f"/clientes/{seed['id_cliente']}",
        json={
            "apellido": "Exportador",
            "nombre": None,
            "cuit": _cuit(),
            "tipo_cliente": "Exportador",
            "tipo_documento": "DNI",
            "nro_documento": "12345678",
            "calle_cliente": "San Martin",
            "nro_calle_cliente": 123,
            "id_localidad": seed["id_localidad"],
            "fecha_alta": "2025-01-01",
            "descuento_porcentaje": 30,
            "pais_destino_principal": "X" * 51,
        },
    )

    assert response.status_code == 422


def test_comprobante_valido(client: TestClient, seed: dict):
    stock = seed["stock_sala"]
    payload = {
        "id_cliente": seed["id_cliente"],
        "id_sala": stock["id_sala"],
        "renglones": [{"codigo_vino": stock["codigo_vino"], "cantidad": 1}],
    }
    response = client.post("/comprobantes", json=payload)
    assert response.status_code == 201
    body = response.json()
    assert float(body["total"]) > 0
    assert len(body["renglones"]) == 1
    assert float(body["renglones"][0]["precio_unitario"]) > 0


def test_venta_sin_stock(client: TestClient, seed: dict):
    stock = seed["stock_sala"]
    payload = {
        "id_cliente": seed["id_cliente"],
        "id_sala": stock["id_sala"],
        "renglones": [
            {"codigo_vino": stock["codigo_vino"], "cantidad": stock["cantidad"] + 1000}
        ],
    }
    response = client.post("/comprobantes", json=payload)
    assert response.status_code == 409
    assert response.json()["sqlstate"] == "P0001"
    assert "Stock insuficiente" in response.json()["detail"]


def test_venta_multi_renglon_fallida_revierte_cabecera_detalles_y_stock(
    client: TestClient, seed: dict
):
    stock = seed["stock_sala"]
    cantidad_antes = fetch_one(
        "SELECT cantidad FROM StockSala WHERE id_sala = %s AND codigo_vino = %s",
        (stock["id_sala"], stock["codigo_vino"]),
    )["cantidad"]
    comprobantes_antes = fetch_one(
        "SELECT count(*) AS total FROM ComprobanteVenta"
    )["total"]
    detalles_antes = fetch_one("SELECT count(*) AS total FROM DetalleVenta")["total"]
    payload = {
        "id_cliente": seed["id_cliente"],
        "id_sala": stock["id_sala"],
        "renglones": [
            {"codigo_vino": stock["codigo_vino"], "cantidad": 1},
            {
                "codigo_vino": stock["codigo_vino"],
                "cantidad": stock["cantidad"] + 1000,
            },
        ],
    }

    response = client.post("/comprobantes", json=payload)

    assert response.status_code == 409
    assert response.json()["sqlstate"] == "P0001"
    assert "Stock insuficiente" in response.json()["detail"]
    assert fetch_one(
        "SELECT cantidad FROM StockSala WHERE id_sala = %s AND codigo_vino = %s",
        (stock["id_sala"], stock["codigo_vino"]),
    )["cantidad"] == cantidad_antes
    assert fetch_one("SELECT count(*) AS total FROM ComprobanteVenta")["total"] == comprobantes_antes
    assert fetch_one("SELECT count(*) AS total FROM DetalleVenta")["total"] == detalles_antes


def test_ingreso_estado_invalido(client: TestClient, seed: dict):
    codigo = seed["stock_deposito"]["codigo_vino"]
    created = client.post(
        "/ingresos",
        json={
            "id_transporte": seed["id_transporte"],
            "cuit_bodega": seed["cuit_bodega"],
            "id_deposito": seed["id_deposito"],
        },
    )
    assert created.status_code == 201
    id_ingreso = created.json()["id_ingreso"]

    assert (
        client.post(
            f"/ingresos/{id_ingreso}/renglones",
            json={"codigo_vino": codigo, "cantidad_botellas": 2},
        ).status_code
        == 201
    )
    assert client.post(f"/ingresos/{id_ingreso}/terminar").status_code == 200
    procesado = client.post(f"/ingresos/{id_ingreso}/procesar")
    assert procesado.status_code == 200
    assert procesado.json()["estado"] == "procesado"

    rechazado = client.post(
        f"/ingresos/{id_ingreso}/renglones",
        json={"codigo_vino": codigo, "cantidad_botellas": 1},
    )
    assert rechazado.status_code == 409
    assert rechazado.json()["sqlstate"] == "P0001"
    assert "no admite cambios" in rechazado.json()["detail"]


def test_transferencia_flujo(client: TestClient, seed: dict):
    stock = seed["stock_deposito"]
    created = client.post(
        "/transferencias",
        json={
            "id_sala_solicitante": seed["id_sala"],
            "id_deposito": stock["id_deposito"],
        },
    )
    assert created.status_code == 201
    nro = created.json()["nro_transferencia"]
    assert created.json()["estado"] == "en_confeccion"

    assert (
        client.post(
            f"/transferencias/{nro}/renglones",
            json={"codigo_vino": stock["codigo_vino"], "cantidad": 1},
        ).status_code
        == 201
    )
    assert client.post(f"/transferencias/{nro}/terminar").status_code == 200
    procesada = client.post(f"/transferencias/{nro}/procesar")
    assert procesada.status_code == 200
    assert procesada.json()["estado"] == "procesado"

    repetida = client.post(f"/transferencias/{nro}/procesar")
    assert repetida.status_code == 409
    assert repetida.json()["sqlstate"] == "P0001"


def test_catalogos(client: TestClient):
    for endpoint in [
        "/catalogos/bodegas",
        "/catalogos/cepas",
        "/catalogos/maridajes",
        "/catalogos/salas",
        "/catalogos/depositos",
        "/catalogos/localidades",
    ]:
        response = client.get(endpoint)
        assert response.status_code == 200, endpoint
        assert isinstance(response.json(), list), endpoint
        assert response.json(), endpoint


def test_filtros_vinos_por_cepa_y_anada(client: TestClient):
    first = client.get("/vinos", params={"limit": 1}).json()["items"][0]
    detail = client.get(f"/vinos/{first['codigo_vino']}").json()
    cepa = detail["cepas"][0]["nombre"]
    anada = detail["anada"]

    response = client.get(
        "/vinos", params={"cepa": cepa, "anada": anada, "limit": 100}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["total"] >= 1
    assert any(item["codigo_vino"] == first["codigo_vino"] for item in body["items"])


def test_cotizacion_no_persiste(client: TestClient, seed: dict):
    stock = seed["stock_sala"]
    payload = {
        "id_cliente": seed["id_cliente"],
        "id_sala": stock["id_sala"],
        "renglones": [{"codigo_vino": stock["codigo_vino"], "cantidad": 1}],
    }
    stock_antes = client.get(f"/vinos/{stock['codigo_vino']}").json()["stock_total"]

    response = client.post("/comprobantes/cotizar", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert float(body["total"]) > 0
    assert float(body["renglones"][0]["precio_unitario"]) > 0
    assert client.get(f"/comprobantes/{body['nro_comprobante']}").status_code == 404

    stock_despues = client.get(f"/vinos/{stock['codigo_vino']}").json()["stock_total"]
    assert stock_despues == stock_antes


def test_cotizacion_sin_stock(client: TestClient, seed: dict):
    stock = seed["stock_sala"]
    response = client.post(
        "/comprobantes/cotizar",
        json={
            "id_cliente": seed["id_cliente"],
            "id_sala": stock["id_sala"],
            "renglones": [
                {
                    "codigo_vino": stock["codigo_vino"],
                    "cantidad": stock["cantidad"] + 1000,
                }
            ],
        },
    )
    assert response.status_code == 409
    assert response.json()["sqlstate"] == "P0001"
    assert "Stock insuficiente" in response.json()["detail"]


def test_transferencias_listado(client: TestClient, seed: dict):
    stock = seed["stock_deposito"]
    created = client.post(
        "/transferencias",
        json={
            "id_sala_solicitante": seed["id_sala"],
            "id_deposito": stock["id_deposito"],
        },
    )
    assert created.status_code == 201
    nro = created.json()["nro_transferencia"]

    response = client.get(
        "/transferencias", params={"estado": "en_confeccion", "limit": 100}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["total"] >= 1
    assert any(item["nro_transferencia"] == nro for item in body["items"])
    assert "renglones" not in body["items"][0]


def test_reportes_s13_s14(client: TestClient, seed: dict):
    response = client.get("/reportes/s13-ventas-sala-trimestre")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

    response = client.get(
        "/reportes/s14-vinos-sin-stock-sala", params={"id_sala": seed["id_sala"]}
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)

    response = client.get(
        "/reportes/s14-vinos-sin-stock-sala", params={"id_sala": 999999999}
    )
    assert response.status_code == 404


def test_reportes_s1_s12(client: TestClient):
    endpoints = [
        "/reportes/s1-stock-total",
        "/reportes/s2-ventas-mensuales-sala",
        "/reportes/s3-documentos-pendientes",
        "/reportes/s4-top-vinos",
        "/reportes/s5-top-clientes",
        "/reportes/s6-ventas-localidad",
        "/reportes/s7-ventas-tipo",
        "/reportes/s8-clientes-sin-compras",
        "/reportes/s9-vinos-sin-stock",
        "/reportes/s10-top-salas",
        "/reportes/s11-descuentos-clientes",
        "/reportes/s12-evolucion-mensual",
    ]
    for endpoint in endpoints:
        response = client.get(endpoint)
        assert response.status_code == 200, endpoint
        assert isinstance(response.json(), list), endpoint
