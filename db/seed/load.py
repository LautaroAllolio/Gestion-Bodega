#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import random
import sys
import time
from collections import defaultdict
from datetime import date, datetime, time as dtime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

try:
    from faker import Faker
except ImportError as exc:
    raise SystemExit("Falta Faker. Instalá db/seed/requirements.txt") from exc

BASE_DIR = Path(__file__).resolve().parent
SEED = 20261101
BASE_DATE = date(2026, 11, 1)
CENT = Decimal("0.01")
STRATEGIES = ("copy", "executemany", "individual")

TABLES: dict[str, tuple[str, ...]] = {
    "cepa": ("id_cepa", "nombre", "tipo"),
    "maridaje": ("id_maridaje", "nombre", "temperatura_servicio"),
    "departamento": ("id_departamento", "nombre", "provincia"),
    "localidad": ("id_localidad", "nombre", "provincia", "codigo_postal", "cuit_encargado"),
    "bodega": ("cuit", "razon_social", "calle_bodega", "num_calle_bodega"),
    "transportista": ("id_transporte", "razon_social", "cuit", "email", "telefono", "calle_transporte", "nro_calle_transporte"),
    "depositocentral": ("id_deposito", "nombre"),
    "saladeventa": ("id_sala", "calle", "dia_cierre", "id_localidad", "numero_calle"),
    "empleado": ("cuit", "nombre", "fecha_ingreso", "salario", "id_sala"),
    "transportistalocalidad": ("id_transporte", "id_localidad"),
    "finca": ("id_finca", "nombre", "superficie_total", "id_departamento"),
    "parcela": ("nro_parcela", "id_finca", "superficie", "anio_plantacion", "id_cepa"),
    "loteuva": ("id_lote", "nro_lote", "fecha_cosecha", "kilos", "cuit_bodega", "nro_parcela", "id_finca", "campania"),
    "analisiscalidad": ("id_analisis", "id_lote", "fecha", "grado_brix", "ph", "acidez_total"),
    "cliente": ("id_cliente", "apellido", "nombre", "cuit", "tipo_cliente", "tipo_documento", "nro_documento", "calle_cliente", "nro_calle_cliente", "id_localidad", "fecha_alta", "descuento_porcentaje"),
    "socioclub": ("id_cliente", "numero_socio"),
    "distribuidor": ("id_cliente", "zona_cobertura", "nro_habilitacion"),
    "exportador": ("id_cliente", "pais_destino_principal"),
    "permisoexportacion": ("id_permiso", "id_cliente", "codigo_permiso", "fecha_emision", "fecha_vencimiento"),
    "vino": ("codigo_vino", "nombre_comercial", "tipo", "anada", "presentacion_ml", "graduacion_alcoholica", "precio_venta", "cuit_bodega"),
    "vinocepa": ("codigo_vino", "id_cepa", "porcentaje_corte"),
    "vinomaridaje": ("codigo_vino", "id_maridaje"),
    "stockdeposito": ("id_deposito", "codigo_vino", "cantidad"),
    "ingreso": ("id_ingreso", "fecha", "estado", "id_transporte", "cuit_bodega", "id_deposito"),
    "detalleingreso": ("id_ingreso", "codigo_vino", "cantidad_botellas"),
    "transferencia": ("nro_transferencia", "id_sala_solicitante", "id_deposito", "fecha_confeccion", "estado"),
    "detalletransferencia": ("nro_transferencia", "codigo_vino", "cantidad"),
    "stocksala": ("id_sala", "codigo_vino", "cantidad"),
    "comprobanteventa": ("nro_comprobante", "fecha", "id_cliente", "id_sala", "subtotal", "descuento", "total"),
    "detalleventa": ("nro_comprobante", "codigo_vino", "cantidad", "precio_unitario", "descuento_aplicado", "subtotal"),
    "auditoriaprecio": ("id_auditoria", "codigo_vino", "precio_anterior", "precio_nuevo", "fecha_hora", "usuario"),
}

LOAD_ORDER = [
    "cepa", "maridaje", "departamento", "bodega", "transportista", "depositocentral", "localidad",
    "saladeventa", "empleado",
    "transportistalocalidad", "finca", "parcela", "loteuva", "analisiscalidad",
    "cliente", "socioclub", "distribuidor", "exportador", "permisoexportacion",
    "vino", "vinocepa", "vinomaridaje", "stockdeposito",
    "ingreso", "detalleingreso", "transferencia", "detalletransferencia", "stocksala",
    "comprobanteventa", "detalleventa", "auditoriaprecio",
]

PK = {
    "cepa": ("id_cepa",),
    "maridaje": ("id_maridaje",),
    "departamento": ("id_departamento",),
    "localidad": ("id_localidad",),
    "bodega": ("cuit",),
    "transportista": ("id_transporte",),
    "depositocentral": ("id_deposito",),
    "saladeventa": ("id_sala",),
    "empleado": ("cuit",),
    "transportistalocalidad": ("id_transporte", "id_localidad"),
    "finca": ("id_finca",),
    "parcela": ("nro_parcela", "id_finca"),
    "loteuva": ("id_lote",),
    "analisiscalidad": ("id_analisis",),
    "cliente": ("id_cliente",),
    "socioclub": ("id_cliente",),
    "distribuidor": ("id_cliente",),
    "exportador": ("id_cliente",),
    "permisoexportacion": ("id_permiso",),
    "vino": ("codigo_vino",),
    "vinocepa": ("codigo_vino", "id_cepa"),
    "vinomaridaje": ("codigo_vino", "id_maridaje"),
    "stockdeposito": ("id_deposito", "codigo_vino"),
    "ingreso": ("id_ingreso",),
    "detalleingreso": ("id_ingreso", "codigo_vino"),
    "transferencia": ("nro_transferencia",),
    "detalletransferencia": ("nro_transferencia", "codigo_vino"),
    "stocksala": ("id_sala", "codigo_vino"),
    "comprobanteventa": ("nro_comprobante",),
    "detalleventa": ("nro_comprobante", "codigo_vino"),
    "auditoriaprecio": ("id_auditoria",),
}

SERIALS = {
    "localidad": ("id_localidad",),
    "maridaje": ("id_maridaje",),
    "depositocentral": ("id_deposito",),
    "saladeventa": ("id_sala",),
    "finca": ("id_finca",),
    "loteuva": ("id_lote",),
    "analisiscalidad": ("id_analisis",),
    "cliente": ("id_cliente",),
    "permisoexportacion": ("id_permiso",),
    "ingreso": ("id_ingreso",),
    "transferencia": ("nro_transferencia",),
    "transportista": ("id_transporte",),
    "comprobanteventa": ("nro_comprobante",),
    "auditoriaprecio": ("id_auditoria",),
}

REFS = [
    ("saladeventa", "id_localidad", "localidad", "id_localidad"),
    ("empleado", "id_sala", "saladeventa", "id_sala"),
    ("transportistalocalidad", "id_transporte", "transportista", "id_transporte"),
    ("transportistalocalidad", "id_localidad", "localidad", "id_localidad"),
    ("finca", "id_departamento", "departamento", "id_departamento"),
    ("parcela", "id_finca", "finca", "id_finca"),
    ("parcela", "id_cepa", "cepa", "id_cepa"),
    ("loteuva", "cuit_bodega", "bodega", "cuit"),
    ("analisiscalidad", "id_lote", "loteuva", "id_lote"),
    ("cliente", "id_localidad", "localidad", "id_localidad"),
    ("socioclub", "id_cliente", "cliente", "id_cliente"),
    ("distribuidor", "id_cliente", "cliente", "id_cliente"),
    ("exportador", "id_cliente", "cliente", "id_cliente"),
    ("permisoexportacion", "id_cliente", "exportador", "id_cliente"),
    ("vino", "cuit_bodega", "bodega", "cuit"),
    ("vinocepa", "codigo_vino", "vino", "codigo_vino"),
    ("vinocepa", "id_cepa", "cepa", "id_cepa"),
    ("vinomaridaje", "codigo_vino", "vino", "codigo_vino"),
    ("vinomaridaje", "id_maridaje", "maridaje", "id_maridaje"),
    ("stockdeposito", "id_deposito", "depositocentral", "id_deposito"),
    ("stockdeposito", "codigo_vino", "vino", "codigo_vino"),
    ("ingreso", "id_transporte", "transportista", "id_transporte"),
    ("ingreso", "cuit_bodega", "bodega", "cuit"),
    ("ingreso", "id_deposito", "depositocentral", "id_deposito"),
    ("detalleingreso", "id_ingreso", "ingreso", "id_ingreso"),
    ("detalleingreso", "codigo_vino", "vino", "codigo_vino"),
    ("transferencia", "id_sala_solicitante", "saladeventa", "id_sala"),
    ("transferencia", "id_deposito", "depositocentral", "id_deposito"),
    ("detalletransferencia", "nro_transferencia", "transferencia", "nro_transferencia"),
    ("detalletransferencia", "codigo_vino", "vino", "codigo_vino"),
    ("stocksala", "id_sala", "saladeventa", "id_sala"),
    ("stocksala", "codigo_vino", "vino", "codigo_vino"),
    ("comprobanteventa", "id_cliente", "cliente", "id_cliente"),
    ("comprobanteventa", "id_sala", "saladeventa", "id_sala"),
    ("detalleventa", "nro_comprobante", "comprobanteventa", "nro_comprobante"),
    ("detalleventa", "codigo_vino", "vino", "codigo_vino"),
    ("auditoriaprecio", "codigo_vino", "vino", "codigo_vino"),
]

TRIGGER_TABLES = ("detalleventa", "transferencia", "detalleingreso", "detalletransferencia", "vino", "vinocepa")

ESTADOS = ("en_confeccion", "terminado", "procesado")
DIAS_CIERRE = ("Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo", "Ninguno")
TIPOS_CLIENTE = ("Socio", "Distribuidor", "Exportador")
PAISES = ("Brasil", "Estados Unidos", "Reino Unido", "China", "Chile", "Paraguay", "Uruguay", "Canadá", "Francia", "Italia", "Japón", "México")


def money(value) -> Decimal:
    return Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP)


def scaled(value: int, scale: float, minimum: int = 1) -> int:
    return max(minimum, int(round(value * scale)))


def rng_for(seed: int, section: str) -> random.Random:
    return random.Random(f"{seed}:{section}")


def random_date(rng: random.Random, start: date, end: date) -> date:
    return start + timedelta(days=rng.randint(0, (end - start).days))


def gen_cuit(rng: random.Random, used: set[str]) -> str:
    prefix = rng.choice(("20", "23", "24", "27", "30", "33", "34"))
    while True:
        body = prefix + f"{rng.randint(10_000_000, 99_999_999):08d}"
        weights = (5, 4, 3, 2, 7, 6, 5, 4, 3, 2)
        total = sum(int(digit) * weight for digit, weight in zip(body, weights))
        check = 11 - total % 11
        if check == 11:
            check = 0
        elif check == 10:
            check = 9
        cuit = body + str(check)
        if cuit not in used:
            used.add(cuit)
            return cuit


def read_catalogs(seed: int) -> tuple[dict[str, list[tuple]], list[str]]:
    data: dict[str, list[tuple]] = {table: [] for table in TABLES}

    with (BASE_DIR / "cepas.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            data["cepa"].append((int(row["id_cepa"]), row["nombre"], row["tipo"]))

    with (BASE_DIR / "maridajes.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            data["maridaje"].append((int(row["id_maridaje"]), row["nombre"], Decimal(row["temperatura_servicio"])))

    with (BASE_DIR / "departamentos.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            data["departamento"].append((int(row["id_departamento"]), row["nombre"], row["provincia"]))

    with (BASE_DIR / "localidades.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            data["localidad"].append((int(row["id_localidad"]), row["nombre"], row["provincia"], row["codigo_postal"], None))

    with (BASE_DIR / "tipos_vino.csv").open(encoding="utf-8", newline="") as handle:
        tipos = [row["tipo"] for row in csv.DictReader(handle)]

    return data, tipos


def generate(seed: int, base_date: date, scale: float) -> tuple[dict[str, list[tuple]], list[tuple[str, int]], list[str]]:
    data, tipos_vino = read_catalogs(seed)
    fake = Faker("es_AR")
    Faker.seed(seed)

    cepas = data["cepa"]
    maridajes = data["maridaje"]
    departamentos = data["departamento"]
    localidades = data["localidad"]
    cepas_tintas = [row[0] for row in cepas if row[2] == "Tinta"]
    cepas_blancas = [row[0] for row in cepas if row[2] == "Blanca"]
    cepas_plantadas = cepas_tintas + cepas_blancas[:2]

    n_bodegas = scaled(20, scale)
    n_transportistas = scaled(18, scale)
    n_salas = max(len(localidades), scaled(20, scale))
    n_fincas = scaled(30, scale)
    n_parcelas = max(n_fincas, scaled(900, scale))
    n_empleados = max(n_salas * 3, scaled(120, scale))
    n_lotes_objetivo = scaled(4000, scale)
    n_clientes = max(4, scaled(20000, scale))
    n_vinos = max(4, scaled(600, scale))
    n_ingresos = scaled(2000, scale)
    n_transferencias = scaled(3000, scale)
    n_stock_sala = scaled(3000, scale)
    n_comprobantes = max(10, scaled(150000, scale))

    rng_cuit = rng_for(seed, "cuit")
    used_cuits: set[str] = set()

    rng_bodega = rng_for(seed, "bodega")
    for i in range(1, n_bodegas + 1):
        data["bodega"].append((
            gen_cuit(rng_cuit, used_cuits),
            f"Bodega {fake.last_name()} {i:02d}"[:50],
            fake.street_name()[:50],
            str(rng_bodega.randint(1, 5000)),
        ))

    rng_transportista = rng_for(seed, "transportista")
    for i in range(1, n_transportistas + 1):
        data["transportista"].append((
            i,
            f"Transporte {fake.company()}"[:50],
            gen_cuit(rng_cuit, used_cuits),
            fake.email()[:50],
            fake.phone_number()[:50],
            fake.street_name()[:50],
            str(rng_transportista.randint(1, 5000)),
        ))

    data["depositocentral"].append((1, "Depósito Central"))

    rng_sala = rng_for(seed, "sala")
    for i in range(1, n_salas + 1):
        data["saladeventa"].append((
            i,
            fake.street_name()[:50],
            rng_sala.choice(DIAS_CIERRE),
            localidades[(i - 1) % len(localidades)][0],
            rng_sala.randint(1, 5000),
        ))

    rng_empleado = rng_for(seed, "empleado")
    for i in range(1, n_empleados + 1):
        ingreso = random_date(rng_empleado, base_date - timedelta(days=7300), base_date - timedelta(days=30))
        data["empleado"].append((
            gen_cuit(rng_cuit, used_cuits),
            fake.name()[:50],
            ingreso,
            money(rng_empleado.randint(500_000, 3_500_000)),
            ((i - 1) % n_salas) + 1,
        ))

    sala_localidad = {row[0]: row[3] for row in data["saladeventa"]}
    empleados_por_localidad: dict[int, list[str]] = defaultdict(list)
    for cuit, _nombre, _fecha, _salario, id_sala in data["empleado"]:
        empleados_por_localidad[sala_localidad[id_sala]].append(cuit)
    rng_encargado = rng_for(seed, "encargado")
    encargados: list[tuple[str, int]] = []
    for id_localidad, _nombre, _prov, _cp, _cuit in localidades:
        candidatos = empleados_por_localidad.get(id_localidad, [])
        if candidatos:
            encargados.append((rng_encargado.choice(candidatos), id_localidad))

    rng_tl = rng_for(seed, "transportista_localidad")
    pares_tl: set[tuple[int, int]] = set()
    transporte_ids = [row[0] for row in data["transportista"]]
    localidad_ids = [row[0] for row in localidades]
    objetivo_tl = scaled(45, scale, minimum=len(transporte_ids))
    for id_transporte in transporte_ids:
        for id_localidad in rng_tl.sample(localidad_ids, rng_tl.randint(1, min(5, len(localidad_ids)))):
            pares_tl.add((id_transporte, id_localidad))
    while len(pares_tl) < objetivo_tl:
        pares_tl.add((rng_tl.choice(transporte_ids), rng_tl.choice(localidad_ids)))
    for par in sorted(pares_tl):
        data["transportistalocalidad"].append(par)

    rng_finca = rng_for(seed, "finca")
    base_parcelas = n_parcelas // n_fincas
    resto_parcelas = n_parcelas % n_fincas
    parcelas_por_finca: list[list[tuple]] = []
    for id_finca in range(1, n_fincas + 1):
        cantidad = base_parcelas + (1 if id_finca <= resto_parcelas else 0)
        filas = []
        for nro_parcela in range(1, cantidad + 1):
            filas.append((
                nro_parcela,
                id_finca,
                money(Decimal(rng_finca.randint(200, 4000)) / 100),
                rng_finca.randint(1970, 2024),
                rng_finca.choice(cepas_plantadas),
            ))
        parcelas_por_finca.append(filas)
        superficie = sum(fila[2] for fila in filas) + money(Decimal(rng_finca.randint(1000, 5000)) / 100)
        data["finca"].append((
            id_finca,
            f"Finca {fake.last_name()} {id_finca:02d}"[:50],
            superficie,
            rng_finca.choice(departamentos)[0],
        ))
        data["parcela"].extend(filas)

    parcelas_info = {(fila[1], fila[0]): fila for fila in data["parcela"]}
    campanias = list(range(base_date.year - 4, base_date.year + 1))
    combos = [(id_finca, nro_parcela, campania) for (id_finca, nro_parcela) in parcelas_info for campania in campanias]
    rng_lote = rng_for(seed, "lote")
    rng_lote.shuffle(combos)
    n_lotes = min(n_lotes_objetivo, len(combos))
    bodega_cuits = [row[0] for row in data["bodega"]]
    rng_analisis = rng_for(seed, "analisis")
    id_analisis = 1
    for id_lote, (id_finca, nro_parcela, campania) in enumerate(combos[:n_lotes], start=1):
        superficie = parcelas_info[(id_finca, nro_parcela)][2]
        kilos = money(superficie * Decimal(rng_lote.randint(6000, 15000)) / 100)
        cosecha = random_date(rng_lote, date(campania, 2, 1), date(campania, 4, 30))
        data["loteuva"].append((
            id_lote,
            id_lote,
            cosecha,
            kilos,
            rng_lote.choice(bodega_cuits),
            nro_parcela,
            id_finca,
            campania,
        ))
        for _ in range(rng_analisis.randint(1, 3)):
            data["analisiscalidad"].append((
                id_analisis,
                id_lote,
                cosecha + timedelta(days=rng_analisis.randint(1, 30)),
                money(Decimal(rng_analisis.randint(2000, 2600)) / 100),
                money(Decimal(rng_analisis.randint(280, 400)) / 100),
                money(Decimal(rng_analisis.randint(400, 900)) / 100),
            ))
            id_analisis += 1

    rng_cliente = rng_for(seed, "cliente")
    clientes_info: dict[int, dict[str, object]] = {}
    id_permiso = 1
    for id_cliente in range(1, n_clientes + 1):
        if id_cliente == 1:
            tipo = "Socio"
        elif id_cliente == 2:
            tipo = "Distribuidor"
        elif id_cliente == 3:
            tipo = "Exportador"
        else:
            tipo = rng_cliente.choices(TIPOS_CLIENTE, weights=(70, 20, 10))[0]
        if tipo == "Socio":
            apellido = fake.last_name()[:50]
            nombre = fake.first_name()[:50]
            tipo_documento = "DNI"
            nro_documento = f"{rng_cliente.randint(10_000_000, 99_999_999)}"
            descuento = Decimal("10.00")
        else:
            apellido = fake.company()[:50]
            nombre = None
            tipo_documento = "CUIT"
            cuit_cliente = gen_cuit(rng_cuit, used_cuits)
            nro_documento = cuit_cliente
            descuento = Decimal("20.00") if tipo == "Distribuidor" else Decimal("30.00")
        cuit_cliente = gen_cuit(rng_cuit, used_cuits) if tipo == "Socio" else nro_documento
        fecha_alta = random_date(rng_cliente, base_date - timedelta(days=2920), base_date - timedelta(days=30))
        data["cliente"].append((
            id_cliente,
            apellido,
            nombre,
            cuit_cliente,
            tipo,
            tipo_documento,
            nro_documento,
            fake.street_name()[:50],
            rng_cliente.randint(1, 5000),
            rng_cliente.choice(localidad_ids),
            fecha_alta,
            descuento,
        ))
        clientes_info[id_cliente] = {"tipo": tipo, "descuento": descuento}
        if tipo == "Socio":
            data["socioclub"].append((id_cliente, 100000 + id_cliente))
        elif tipo == "Distribuidor":
            data["distribuidor"].append((
                id_cliente,
                f"{rng_cliente.choice(departamentos)[1]} y zona"[:50],
                f"HAB-{id_cliente:05d}",
            ))
        else:
            data["exportador"].append((id_cliente, rng_cliente.choice(PAISES)))
            cantidad_permisos = rng_cliente.choices((0, 1, 2, 3, 4, 5), weights=(10, 25, 25, 20, 12, 8))[0]
            if id_cliente == 3:
                cantidad_permisos = max(1, cantidad_permisos)
            for _ in range(cantidad_permisos):
                emision = random_date(rng_cliente, base_date - timedelta(days=1825), base_date)
                vencimiento = emision + timedelta(days=rng_cliente.randint(180, 1500))
                data["permisoexportacion"].append((
                    id_permiso,
                    id_cliente,
                    f"EXP-{id_cliente:05d}-{id_permiso:04d}",
                    emision,
                    vencimiento,
                ))
                id_permiso += 1

    rng_vino = rng_for(seed, "vino")
    vinos_info: dict[str, dict[str, object]] = {}
    for i in range(1, n_vinos + 1):
        tipo = tipos_vino[(i - 1) % len(tipos_vino)]
        codigo = f"V{i:04d}"
        anada = rng_vino.randint(2019, 2025)
        presentacion = rng_vino.choice((187, 375, 750, 1500, 3000))
        if tipo == "Tinto":
            graduacion = Decimal(rng_vino.randint(1250, 1550)) / 100
            precio = Decimal(rng_vino.randint(8000, 30000) + (anada - 2019) * 500)
            pool = cepas_tintas
            maridajes_tipo = (1, 2, 3, 4)
        elif tipo == "Blanco":
            graduacion = Decimal(rng_vino.randint(1100, 1350)) / 100
            precio = Decimal(rng_vino.randint(6000, 22000) + (anada - 2019) * 500)
            pool = cepas_blancas
            maridajes_tipo = (5, 6, 7, 8)
        elif tipo == "Rosado":
            graduacion = Decimal(rng_vino.randint(1100, 1300)) / 100
            precio = Decimal(rng_vino.randint(5500, 18000) + (anada - 2019) * 500)
            pool = cepas_tintas
            maridajes_tipo = (1, 2, 5, 6)
        else:
            graduacion = Decimal(rng_vino.randint(1050, 1300)) / 100
            precio = Decimal(rng_vino.randint(9000, 26000) + (anada - 2019) * 500)
            pool = cepas_blancas
            maridajes_tipo = (5, 6, 7, 8)
        data["vino"].append((
            codigo,
            f"{fake.last_name()[:30]} {tipo} {i:04d}",
            tipo,
            anada,
            presentacion,
            graduacion,
            money(precio),
            rng_vino.choice(bodega_cuits),
        ))
        vinos_info[codigo] = {"precio": money(precio), "tipo": tipo}

        cantidad_cepas = rng_vino.choices((1, 2, 3), weights=(60, 30, 10))[0]
        cepas_elegidas = rng_vino.sample(pool, min(cantidad_cepas, len(pool)))
        if len(cepas_elegidas) == 1:
            porcentajes = [Decimal("100.00")]
        elif len(cepas_elegidas) == 2:
            primero = rng_vino.randint(30, 70)
            porcentajes = [Decimal(primero), Decimal(100 - primero)]
        else:
            primero = rng_vino.randint(20, 70)
            segundo = rng_vino.randint(5, 95 - primero)
            porcentajes = [Decimal(primero), Decimal(segundo), Decimal(100 - primero - segundo)]
        for id_cepa, porcentaje in zip(cepas_elegidas, porcentajes):
            data["vinocepa"].append((codigo, id_cepa, porcentaje))

        for id_maridaje in rng_vino.sample(maridajes_tipo, rng_vino.randint(1, 2)):
            data["vinomaridaje"].append((codigo, id_maridaje))

        data["stockdeposito"].append((1, codigo, rng_vino.randint(50, 5000)))

    rng_ingreso = rng_for(seed, "ingreso")
    vino_codigos = list(vinos_info)
    for id_ingreso in range(1, n_ingresos + 1):
        fecha = random_date(rng_ingreso, base_date - timedelta(days=1825), base_date)
        estado = rng_ingreso.choices(ESTADOS, weights=(7, 8, 85))[0]
        data["ingreso"].append((
            id_ingreso,
            fecha,
            estado,
            rng_ingreso.choice(transporte_ids),
            rng_ingreso.choice(bodega_cuits),
            1,
        ))
        cantidad = min(rng_ingreso.choices((2, 3, 4, 5), weights=(10, 40, 35, 15))[0], len(vino_codigos))
        for codigo in rng_ingreso.sample(vino_codigos, cantidad):
            data["detalleingreso"].append((id_ingreso, codigo, rng_ingreso.randint(6, 600)))

    rng_transferencia = rng_for(seed, "transferencia")
    sala_ids = [row[0] for row in data["saladeventa"]]
    for nro_transferencia in range(1, n_transferencias + 1):
        fecha = random_date(rng_transferencia, base_date - timedelta(days=730), base_date)
        estado = rng_transferencia.choices(ESTADOS, weights=(10, 10, 80))[0]
        data["transferencia"].append((
            nro_transferencia,
            rng_transferencia.choice(sala_ids),
            1,
            fecha,
            estado,
        ))
        cantidad = min(rng_transferencia.choices((2, 3, 4), weights=(20, 50, 30))[0], len(vino_codigos))
        for codigo in rng_transferencia.sample(vino_codigos, cantidad):
            data["detalletransferencia"].append((nro_transferencia, codigo, rng_transferencia.randint(3, 300)))

    rng_stock = rng_for(seed, "stock_sala")
    pares_stock = [(id_sala, codigo) for id_sala in sala_ids for codigo in vino_codigos]
    rng_stock.shuffle(pares_stock)
    for id_sala, codigo in pares_stock[: min(n_stock_sala, len(pares_stock))]:
        data["stocksala"].append((id_sala, codigo, rng_stock.randint(1, 800)))

    rng_venta = rng_for(seed, "venta")
    compradores = [row[0] for row in data["cliente"] if row[0] % 10 != 0] or [row[0] for row in data["cliente"]]
    cabeceras: list[tuple[int, date, int, int]] = []
    for nro_comprobante in range(1, n_comprobantes + 1):
        tramo = rng_venta.choices((0, 1, 2, 3, 4), weights=(2, 13, 25, 25, 35))[0]
        if tramo == 0:
            fecha = random_date(rng_venta, base_date - timedelta(days=6), base_date)
        elif tramo == 1:
            fecha = random_date(rng_venta, base_date - timedelta(days=89), base_date - timedelta(days=7))
        elif tramo == 2:
            fecha = random_date(rng_venta, base_date - timedelta(days=730), base_date - timedelta(days=90))
        elif tramo == 3:
            fecha = random_date(rng_venta, base_date - timedelta(days=1825), base_date - timedelta(days=731))
        else:
            fecha = random_date(rng_venta, base_date - timedelta(days=2555), base_date - timedelta(days=1826))
        cabeceras.append((nro_comprobante, fecha, rng_venta.choice(compradores), rng_venta.choice(sala_ids)))

    totales: dict[int, list[Decimal]] = {nro: [Decimal("0.00"), Decimal("0.00")] for nro, _f, _c, _s in cabeceras}
    for nro_comprobante, _fecha, id_cliente, _id_sala in cabeceras:
        rng_comp = random.Random(f"{seed}:venta:{nro_comprobante}")
        cantidad = min(rng_comp.choices((2, 3, 4, 5), weights=(10, 50, 30, 10))[0], len(vino_codigos))
        descuento = clientes_info[id_cliente]["descuento"]
        for codigo in rng_comp.sample(vino_codigos, cantidad):
            precio = vinos_info[codigo]["precio"]
            botellas = rng_comp.randint(1, 12)
            subtotal = money(Decimal(botellas) * precio * (Decimal(100) - descuento) / Decimal(100))
            data["detalleventa"].append((nro_comprobante, codigo, botellas, precio, descuento, subtotal))
            totales[nro_comprobante][0] += Decimal(botellas) * precio
            totales[nro_comprobante][1] += subtotal

    for nro_comprobante, fecha, id_cliente, id_sala in cabeceras:
        bruto, neto = totales[nro_comprobante]
        bruto = money(bruto)
        neto = money(neto)
        data["comprobanteventa"].append((nro_comprobante, fecha, id_cliente, id_sala, bruto, money(bruto - neto), neto))

    primer_codigo = vino_codigos[0]
    precio_anterior = vinos_info[primer_codigo]["precio"]
    data["auditoriaprecio"].append((
        1,
        primer_codigo,
        precio_anterior,
        money(precio_anterior * Decimal("1.10")),
        datetime.combine(base_date - timedelta(days=17), dtime(10, 30)),
        "seed",
    ))

    return data, encargados, tipos_vino


def validate(data: dict[str, list[tuple]], encargados: list[tuple[str, int]]) -> list[str]:
    errors: list[str] = []
    index = {table: {col: pos for pos, col in enumerate(cols)} for table, cols in TABLES.items()}

    for table, rows in data.items():
        if not rows:
            errors.append(f"{table}: sin filas")

    for table, cols in PK.items():
        keys = [tuple(row[index[table][col]] for col in cols) for row in data[table]]
        if len(keys) != len(set(keys)):
            errors.append(f"{table}: PK duplicada {cols}")

    for table, col, ref_table, ref_col in REFS:
        ref = {row[index[ref_table][ref_col]] for row in data[ref_table]}
        missing = sum(1 for row in data[table] if row[index[table][col]] is not None and row[index[table][col]] not in ref)
        if missing:
            errors.append(f"{table}.{col}: {missing} referencias inexistentes")

    parcelas = {(row[index["parcela"]["nro_parcela"]], row[index["parcela"]["id_finca"]]) for row in data["parcela"]}
    for row in data["loteuva"]:
        if (row[index["loteuva"]["nro_parcela"]], row[index["loteuva"]["id_finca"]]) not in parcelas:
            errors.append("loteuva: parcela inexistente")
            break

    empleados = {row[index["empleado"]["cuit"]] for row in data["empleado"]}
    for cuit, id_localidad in encargados:
        if cuit not in empleados:
            errors.append(f"localidad {id_localidad}: encargado inexistente")
            break

    sumas: dict[str, Decimal] = defaultdict(Decimal)
    for codigo, _id_cepa, porcentaje in data["vinocepa"]:
        sumas[codigo] += porcentaje
    for codigo, _nombre, _tipo, _anada, _pres, _grad, _precio, _cuit in data["vino"]:
        if sumas[codigo] != Decimal("100.00"):
            errors.append(f"{codigo}: composición suma {sumas[codigo]}")
            break
        if not any(row[0] == codigo for row in data["vinomaridaje"]):
            errors.append(f"{codigo}: sin maridaje")
            break

    for row in data["stockdeposito"] + data["stocksala"]:
        if row[-1] < 0:
            errors.append("stock negativo")
            break

    for row in data["detalleventa"]:
        botellas, precio, descuento, subtotal = row[2], row[3], row[4], row[5]
        if money(Decimal(botellas) * precio * (Decimal(100) - descuento) / Decimal(100)) != subtotal:
            errors.append("detalleventa: subtotal inconsistente")
            break
        if botellas <= 0 or precio <= 0:
            errors.append("detalleventa: cantidad o precio inválido")
            break

    for row in data["cliente"]:
        tipo = row[index["cliente"]["tipo_cliente"]]
        descuento = row[index["cliente"]["descuento_porcentaje"]]
        esperado = {"Socio": Decimal("10.00"), "Distribuidor": Decimal("20.00"), "Exportador": Decimal("30.00")}[tipo]
        if descuento != esperado:
            errors.append("cliente: descuento inconsistente")
            break

    vinos_unicos = {(row[1], row[3], row[4]) for row in data["vino"]}
    if len(vinos_unicos) != len(data["vino"]):
        errors.append("vino: (nombre, añada, presentación) duplicado")

    lotes_unicos = {(row[6], row[5], row[7]) for row in data["loteuva"]}
    if len(lotes_unicos) != len(data["loteuva"]):
        errors.append("loteuva: cosecha duplicada por parcela y campaña")

    totales: dict[int, list[Decimal]] = defaultdict(lambda: [Decimal("0.00"), Decimal("0.00")])
    for row in data["detalleventa"]:
        totales[row[0]][0] += Decimal(row[2]) * row[3]
        totales[row[0]][1] += row[5]
    nros_con_detalle = {row[0] for row in data["detalleventa"]}
    for row in data["comprobanteventa"]:
        if row[0] not in nros_con_detalle:
            errors.append(f"comprobante {row[0]}: sin renglones")
            break
        bruto, descuento, total = row[4], row[5], row[6]
        esperado_bruto = money(totales[row[0]][0])
        esperado_total = money(totales[row[0]][1])
        if bruto != esperado_bruto or total != esperado_total or descuento != money(esperado_bruto - esperado_total):
            errors.append(f"comprobante {row[0]}: totales inconsistentes")
            break

    return errors


def connect(args):
    try:
        import psycopg
    except ImportError as exc:
        raise SystemExit("Falta psycopg. Instalá db/seed/requirements.txt") from exc

    dsn = args.dsn or os.getenv("DATABASE_URL")
    if dsn:
        return psycopg.connect(dsn)
    return psycopg.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=os.getenv("PGPORT", "5432"),
        dbname=os.getenv("PGDATABASE", "bodega_seed"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD"),
    )


def copy_rows(cursor, table: str, rows: list[tuple]) -> None:
    if not rows:
        return
    from psycopg import sql

    columns = TABLES[table]
    statement = sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier(table),
        sql.SQL(", ").join(sql.Identifier(column) for column in columns),
    )
    with cursor.copy(statement) as copy:
        for row in rows:
            copy.write_row(row)


def insert_statement(table: str):
    from psycopg import sql

    columns = TABLES[table]
    return sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
        sql.Identifier(table),
        sql.SQL(", ").join(sql.Identifier(column) for column in columns),
        sql.SQL(", ").join(sql.Placeholder() for _ in columns),
    )


def insert_rows(cursor, table: str, rows: list[tuple], strategy: str) -> None:
    if not rows:
        return
    if strategy == "copy":
        copy_rows(cursor, table, rows)
        return
    statement = insert_statement(table)
    if strategy == "executemany":
        cursor.executemany(statement, rows)
        return
    if strategy == "individual":
        for row in rows:
            cursor.execute(statement, row)
        return
    raise ValueError(f"Estrategia desconocida: {strategy}")


def table_is_empty(cursor) -> bool:
    cursor.execute("SELECT (SELECT count(*) FROM cepa) + (SELECT count(*) FROM vino) + (SELECT count(*) FROM comprobanteventa)")
    return cursor.fetchone()[0] == 0


def truncate_all(cursor, restart_identity: bool = True) -> None:
    identity = " RESTART IDENTITY" if restart_identity else ""
    cursor.execute("TRUNCATE TABLE " + ", ".join(TABLES) + identity + " CASCADE")


def set_disabled_triggers(cursor, disabled: bool) -> None:
    action = "DISABLE" if disabled else "ENABLE"
    for table in TRIGGER_TABLES:
        cursor.execute(f"ALTER TABLE {table} {action} TRIGGER USER")


def update_encargados(cursor, encargados: list[tuple[str, int]]) -> None:
    cursor.executemany("UPDATE localidad SET cuit_encargado = %s WHERE id_localidad = %s", encargados)


def set_sequences(cursor) -> None:
    for table, (column,) in SERIALS.items():
        cursor.execute(
            "SELECT setval(pg_get_serial_sequence(%s, %s), "
            f"COALESCE((SELECT MAX({column}) FROM {table}), 1), true)",
            (table, column),
        )


def run_controls(cursor) -> dict[str, int]:
    controls: dict[str, int] = {}
    cursor.execute(
        "SELECT count(*) FROM pg_trigger t"
        " JOIN pg_class c ON c.oid = t.tgrelid"
        " JOIN pg_namespace n ON n.oid = c.relnamespace"
        " WHERE NOT t.tgisinternal AND t.tgenabled = 'D'"
        "   AND n.nspname = current_schema()"
    )
    controls["triggers_usuario_deshabilitados"] = cursor.fetchone()[0]

    cursor.execute(
        "SELECT count(*) FROM ("
        " SELECT v.codigo_vino FROM vino v"
        " LEFT JOIN vinocepa vc ON vc.codigo_vino = v.codigo_vino"
        " GROUP BY v.codigo_vino"
        " HAVING COALESCE(SUM(vc.porcentaje_corte), 0) <> 100"
        ") x"
    )
    controls["vinos_corte_distinto_100"] = cursor.fetchone()[0]

    cursor.execute(
        "SELECT count(*) FROM comprobanteventa c"
        " LEFT JOIN ("
        "   SELECT nro_comprobante,"
        "          ROUND(SUM(cantidad * precio_unitario), 2) AS bruto,"
        "          ROUND(SUM(subtotal), 2) AS neto"
        "   FROM detalleventa GROUP BY nro_comprobante"
        " ) d ON d.nro_comprobante = c.nro_comprobante"
        " WHERE c.subtotal IS DISTINCT FROM COALESCE(d.bruto, 0)"
        "    OR c.total IS DISTINCT FROM COALESCE(d.neto, 0)"
        "    OR c.descuento IS DISTINCT FROM COALESCE(d.bruto, 0) - COALESCE(d.neto, 0)"
    )
    controls["comprobantes_totales_inconsistentes"] = cursor.fetchone()[0]

    cursor.execute(
        "SELECT count(*) FROM comprobanteventa c"
        " WHERE NOT EXISTS (SELECT 1 FROM detalleventa d WHERE d.nro_comprobante = c.nro_comprobante)"
    )
    controls["comprobantes_sin_detalle"] = cursor.fetchone()[0]

    cursor.execute("SELECT count(*) FROM stockdeposito WHERE cantidad < 0")
    controls["stock_deposito_negativo"] = cursor.fetchone()[0]
    cursor.execute("SELECT count(*) FROM stocksala WHERE cantidad < 0")
    controls["stock_sala_negativo"] = cursor.fetchone()[0]

    orphan_checks = {
        "detalleventa_sin_comprobante": ("detalleventa d", "comprobanteventa c", "c.nro_comprobante = d.nro_comprobante", "c.nro_comprobante"),
        "detalleventa_sin_vino": ("detalleventa d", "vino v", "v.codigo_vino = d.codigo_vino", "v.codigo_vino"),
        "detalleingreso_sin_ingreso": ("detalleingreso d", "ingreso i", "i.id_ingreso = d.id_ingreso", "i.id_ingreso"),
        "detalletransferencia_sin_transferencia": ("detalletransferencia d", "transferencia t", "t.nro_transferencia = d.nro_transferencia", "t.nro_transferencia"),
        "loteuva_sin_parcela": ("loteuva l", "parcela p", "p.id_finca = l.id_finca AND p.nro_parcela = l.nro_parcela", "p.nro_parcela"),
        "cliente_sin_localidad": ("cliente c", "localidad l", "l.id_localidad = c.id_localidad", "l.id_localidad"),
        "empleado_sin_sala": ("empleado e", "saladeventa s", "s.id_sala = e.id_sala", "s.id_sala"),
        "vino_sin_bodega": ("vino v", "bodega b", "b.cuit = v.cuit_bodega", "b.cuit"),
        "permiso_sin_exportador": ("permisoexportacion p", "exportador e", "e.id_cliente = p.id_cliente", "e.id_cliente"),
    }
    for name, (left, right, condition, key) in orphan_checks.items():
        cursor.execute(f"SELECT count(*) FROM {left} LEFT JOIN {right} ON {condition} WHERE {key} IS NULL")
        controls[name] = cursor.fetchone()[0]

    return controls


def load_dataset(
    database,
    data: dict[str, list[tuple]],
    encargados: list[tuple[str, int]],
    args,
    *,
    strategy: str | None = None,
    benchmark: bool = False,
) -> tuple[dict[str, int], dict[str, float], dict[str, int]]:
    strategy = strategy or args.strategy
    counts: dict[str, int] = {}
    timings: dict[str, float] = {}
    controls: dict[str, int] = {}
    with database.transaction(force_rollback=benchmark):
        with database.cursor() as cursor:
            cursor.execute("SET LOCAL synchronous_commit = off")
            set_disabled_triggers(cursor, True)
            if benchmark or args.reset:
                truncate_all(cursor, restart_identity=not benchmark)
            elif not table_is_empty(cursor):
                raise SystemExit("La base ya tiene datos. Usá --reset para truncar antes de cargar.")

            for table in LOAD_ORDER:
                start = time.perf_counter()
                insert_rows(cursor, table, data[table], strategy)
                timings[table] = round(time.perf_counter() - start, 3)
                counts[table] = len(data[table])

            update_encargados(cursor, encargados)
            if not benchmark:
                set_sequences(cursor)
                cursor.execute("ANALYZE")
            set_disabled_triggers(cursor, False)
            controls = run_controls(cursor)

    return counts, timings, controls


def benchmark(database, data: dict[str, list[tuple]], encargados: list[tuple[str, int]], args) -> dict[str, dict]:
    results: dict[str, dict] = {}
    for strategy in STRATEGIES:
        print(f"Benchmark: {strategy} ...", flush=True)
        started = time.perf_counter()
        try:
            counts, timings, controls = load_dataset(
                database, data, encargados, args, strategy=strategy, benchmark=True
            )
        except Exception as exc:
            results[strategy] = {"error": str(exc)}
            print(f"  ERROR: {exc}", file=sys.stderr)
            continue
        wall_seconds = round(time.perf_counter() - started, 3)
        total_rows = sum(counts.values())
        insert_seconds = round(sum(timings.values()), 3)
        results[strategy] = {
            "rows": counts,
            "timings": timings,
            "controls": controls,
            "total_rows": total_rows,
            "insert_seconds": insert_seconds,
            "wall_seconds": wall_seconds,
            "rows_per_second": round(total_rows / insert_seconds, 1) if insert_seconds else None,
        }
        print(f"  {total_rows} filas, inserción {insert_seconds:.3f}s, total {wall_seconds:.3f}s", flush=True)

    baseline = results.get("individual", {}).get("insert_seconds")
    if baseline:
        for result in results.values():
            if "insert_seconds" in result:
                result["speedup_vs_individual"] = round(baseline / result["insert_seconds"], 2)
    return results


def print_benchmark(results: dict[str, dict]) -> None:
    print("\nComparación de estrategias:")
    print(f"  {'estrategia':12s} {'filas':>9s} {'inserción':>11s} {'total':>9s} {'filas/s':>12s} {'vs individual':>14s}")
    for strategy in STRATEGIES:
        result = results[strategy]
        if "error" in result:
            print(f"  {strategy:12s} ERROR: {result['error']}")
            continue
        speedup = result.get("speedup_vs_individual")
        speedup_text = f"{speedup:.2f}x" if speedup is not None else "-"
        rows_per_second = result.get("rows_per_second")
        rps_text = f"{rows_per_second:.1f}" if rows_per_second is not None else "-"
        print(
            f"  {strategy:12s} {result['total_rows']:>9d}"
            f" {result['insert_seconds']:>10.3f}s {result['wall_seconds']:>8.3f}s"
            f" {rps_text:>12s} {speedup_text:>14s}"
        )
        if any(result["controls"].values()):
            failed = {name: value for name, value in result["controls"].items() if value}
            print(f"    controles con diferencias: {failed}")
        else:
            print("    controles: OK")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Carga masiva reproducible de Bodegas del Atuel")
    parser.add_argument("--dsn", help="Cadena de conexión; si falta se usan DATABASE_URL o PG*")
    parser.add_argument("--reset", action="store_true", help="Trunca todas las tablas antes de cargar")
    parser.add_argument("--scale", type=float, default=1.0, help="Factor de escala de los volúmenes (default 1.0)")
    parser.add_argument("--strategy", choices=STRATEGIES, default="copy", help="Estrategia de inserción (default copy)")
    parser.add_argument("--seed", type=int, default=SEED, help=f"Semilla (default {SEED})")
    parser.add_argument("--base-date", type=date.fromisoformat, default=BASE_DATE, help=f"Fecha base ISO (default {BASE_DATE})")
    parser.add_argument("--dry-run", action="store_true", help="Genera y valida sin conectarse a PostgreSQL")
    parser.add_argument("--report", type=Path, help="Escribe un reporte JSON con conteos, tiempos y controles")
    parser.add_argument("--benchmark", action="store_true", help="Compara copy, executemany e individual con rollback")
    parser.add_argument("--benchmark-scale", type=float, default=1.0, help="Escala del benchmark (default 1.0)")
    parser.add_argument("--benchmark-report", type=Path, help="Escribe el reporte JSON del benchmark")
    args = parser.parse_args(argv)
    if args.scale <= 0:
        parser.error("--scale debe ser mayor que 0")
    if args.benchmark_scale <= 0:
        parser.error("--benchmark-scale debe ser mayor que 0")
    if args.benchmark and args.dry_run:
        parser.error("--benchmark y --dry-run no se pueden combinar")
    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    scale = args.benchmark_scale if args.benchmark else args.scale
    started = time.perf_counter()
    data, encargados, _tipos = generate(args.seed, args.base_date, scale)
    generated_at = time.perf_counter()
    errors = validate(data, encargados)
    counts = {table: len(rows) for table, rows in data.items()}
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"Generación OK en {generated_at - started:.2f}s ({sum(counts.values())} filas, escala {scale})")
    if args.dry_run:
        for table in LOAD_ORDER:
            print(f"  {table:24s} {counts[table]:>9d}")
        print("Dry-run sin errores")
        return 0

    database = connect(args)
    try:
        if args.benchmark:
            results = benchmark(database, data, encargados, args)
        else:
            counts, timings, controls = load_dataset(database, data, encargados, args)
    finally:
        database.close()

    if args.benchmark:
        print_benchmark(results)
        report = {
            "seed": args.seed,
            "base_date": args.base_date.isoformat(),
            "scale": scale,
            "strategies": results,
            "validation_errors": errors,
        }
        if args.benchmark_report:
            args.benchmark_report.parent.mkdir(parents=True, exist_ok=True)
            args.benchmark_report.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"Reporte de benchmark escrito en {args.benchmark_report}")
        valid = all("error" not in result and not any(result["controls"].values()) for result in results.values())
        return 0 if valid else 1

    load_time = time.perf_counter() - generated_at

    print(f"Carga OK en {load_time:.2f}s")
    for table in LOAD_ORDER:
        print(f"  {table:24s} {counts[table]:>9d}  {timings[table]:>7.3f}s")
    print("Controles:")
    for name, value in controls.items():
        print(f"  {name:40s} {value}")

    report = {
        "seed": args.seed,
        "base_date": args.base_date.isoformat(),
        "scale": args.scale,
        "strategy": args.strategy,
        "counts": counts,
        "timings": timings,
        "controls": controls,
        "validation_errors": errors,
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Reporte escrito en {args.report}")

    return 0 if not any(controls.values()) else 2


if __name__ == "__main__":
    raise SystemExit(main())

