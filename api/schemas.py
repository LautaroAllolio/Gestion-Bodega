from datetime import date
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

TipoVino = Literal["Tinto", "Blanco", "Rosado", "Espumante"]
TipoCliente = Literal["Socio", "Distribuidor", "Exportador"]
EstadoDocumento = Literal["en_confeccion", "terminado", "procesado"]


def _validate_descuento_tipo(
    tipo_cliente: str,
    descuento: Decimal,
    *,
    permite_excepcion_exportador: bool = False,
) -> None:
    descuentos_base = {"Socio": Decimal("10"), "Distribuidor": Decimal("20")}
    if tipo_cliente in descuentos_base:
        esperado = descuentos_base[tipo_cliente]
        if descuento != esperado:
            raise ValueError(f"{tipo_cliente} debe tener {esperado}% de descuento")
        return

    descuentos_exportador = {Decimal("30")}
    if permite_excepcion_exportador:
        descuentos_exportador.add(Decimal("35"))
    if tipo_cliente == "Exportador" and descuento in descuentos_exportador:
        return
    if tipo_cliente == "Exportador":
        raise ValueError("Exportador debe tener 30%; el 35% requiere más de tres permisos")
    raise ValueError("Tipo de cliente inválido para el descuento")


class CepaInput(BaseModel):
    id_cepa: int
    porcentaje_corte: Decimal


class VinoCreate(BaseModel):
    codigo_vino: str = Field(min_length=1, max_length=50)
    nombre_comercial: str = Field(min_length=1, max_length=50)
    tipo: TipoVino
    anada: int
    presentacion_ml: int
    graduacion_alcoholica: Decimal
    precio_venta: Decimal
    cuit_bodega: str = Field(pattern=r"^\d{11}$")
    cepas: list[CepaInput] = Field(min_length=1)
    maridajes: list[int] = Field(default_factory=list)


class VinoUpdate(BaseModel):
    nombre_comercial: str | None = Field(default=None, min_length=1, max_length=50)
    tipo: TipoVino | None = None
    anada: int | None = None
    presentacion_ml: int | None = None
    graduacion_alcoholica: Decimal | None = None
    precio_venta: Decimal | None = None
    cuit_bodega: str | None = Field(default=None, pattern=r"^\d{11}$")
    cepas: list[CepaInput] | None = None
    maridajes: list[int] | None = None


class VinoReplace(BaseModel):
    nombre_comercial: str = Field(min_length=1, max_length=50)
    tipo: TipoVino
    anada: int
    presentacion_ml: int
    graduacion_alcoholica: Decimal
    precio_venta: Decimal
    cuit_bodega: str = Field(pattern=r"^\d{11}$")
    cepas: list[CepaInput] = Field(min_length=1)
    maridajes: list[int]


class ClienteCreate(BaseModel):
    apellido: str = Field(min_length=1, max_length=50)
    nombre: str | None = Field(default=None, max_length=50)
    cuit: str = Field(pattern=r"^\d{11}$")
    tipo_cliente: TipoCliente
    tipo_documento: str = Field(min_length=1, max_length=50)
    nro_documento: str = Field(min_length=1, max_length=50)
    calle_cliente: str = Field(min_length=1, max_length=50)
    nro_calle_cliente: int
    id_localidad: int
    fecha_alta: date | None = None
    descuento_porcentaje: Decimal
    numero_socio: int | None = None
    zona_cobertura: str | None = Field(default=None, max_length=50)
    nro_habilitacion: str | None = Field(default=None, max_length=50)
    pais_destino_principal: str | None = Field(default=None, max_length=50)

    @model_validator(mode="after")
    def validate_subtype(self) -> "ClienteCreate":
        _validate_descuento_tipo(self.tipo_cliente, self.descuento_porcentaje)
        if self.tipo_cliente == "Socio" and self.numero_socio is None:
            raise ValueError("Socio requiere numero_socio")
        if self.tipo_cliente == "Distribuidor":
            if not self.zona_cobertura or not self.nro_habilitacion:
                raise ValueError("Distribuidor requiere zona_cobertura y nro_habilitacion")
        if self.tipo_cliente == "Exportador" and not self.pais_destino_principal:
            raise ValueError("Exportador requiere pais_destino_principal")
        return self


class ClienteReplace(BaseModel):
    apellido: str = Field(min_length=1, max_length=50)
    nombre: str | None = Field(max_length=50)
    cuit: str = Field(pattern=r"^\d{11}$")
    tipo_cliente: TipoCliente
    tipo_documento: str = Field(min_length=1, max_length=50)
    nro_documento: str = Field(min_length=1, max_length=50)
    calle_cliente: str = Field(min_length=1, max_length=50)
    nro_calle_cliente: int
    id_localidad: int
    fecha_alta: date
    descuento_porcentaje: Decimal
    numero_socio: int | None = None
    zona_cobertura: str | None = Field(default=None, max_length=50)
    nro_habilitacion: str | None = Field(default=None, max_length=50)
    pais_destino_principal: str | None = Field(default=None, max_length=50)

    @model_validator(mode="after")
    def validate_subtype(self) -> "ClienteReplace":
        _validate_descuento_tipo(
            self.tipo_cliente,
            self.descuento_porcentaje,
            permite_excepcion_exportador=True,
        )
        if self.tipo_cliente == "Socio" and self.numero_socio is None:
            raise ValueError("Socio requiere numero_socio")
        if self.tipo_cliente == "Distribuidor":
            if not self.zona_cobertura or not self.nro_habilitacion:
                raise ValueError("Distribuidor requiere zona_cobertura y nro_habilitacion")
        if self.tipo_cliente == "Exportador" and not self.pais_destino_principal:
            raise ValueError("Exportador requiere pais_destino_principal")
        return self


class ClienteUpdate(BaseModel):
    apellido: str | None = Field(default=None, min_length=1, max_length=50)
    nombre: str | None = Field(default=None, max_length=50)
    cuit: str | None = Field(default=None, pattern=r"^\d{11}$")
    tipo_cliente: TipoCliente | None = None
    tipo_documento: str | None = Field(default=None, min_length=1, max_length=50)
    nro_documento: str | None = Field(default=None, min_length=1, max_length=50)
    calle_cliente: str | None = Field(default=None, min_length=1, max_length=50)
    nro_calle_cliente: int | None = None
    id_localidad: int | None = None
    fecha_alta: date | None = None
    descuento_porcentaje: Decimal | None = None
    numero_socio: int | None = None
    zona_cobertura: str | None = Field(default=None, max_length=50)
    nro_habilitacion: str | None = Field(default=None, max_length=50)
    pais_destino_principal: str | None = Field(default=None, max_length=50)

    @field_validator("descuento_porcentaje")
    @classmethod
    def validate_discount_values(cls, value: Decimal | None) -> Decimal | None:
        if value is not None and value not in {
            Decimal("10"),
            Decimal("20"),
            Decimal("30"),
            Decimal("35"),
        }:
            raise ValueError("El descuento debe ser 10%, 20%, 30% o 35%")
        return value

    @model_validator(mode="after")
    def validate_discount_type(self) -> "ClienteUpdate":
        if self.tipo_cliente is not None and self.descuento_porcentaje is not None:
            _validate_descuento_tipo(
                self.tipo_cliente,
                self.descuento_porcentaje,
                permite_excepcion_exportador=True,
            )
        return self


class RenglonVentaInput(BaseModel):
    codigo_vino: str = Field(min_length=1, max_length=50)
    cantidad: int = Field(gt=0)


class ComprobanteCreate(BaseModel):
    fecha: date | None = None
    id_cliente: int
    id_sala: int
    renglones: list[RenglonVentaInput] = Field(min_length=1)


class TransferenciaCreate(BaseModel):
    id_sala_solicitante: int
    id_deposito: int


class RenglonTransferenciaInput(BaseModel):
    codigo_vino: str = Field(min_length=1, max_length=50)
    cantidad: int = Field(gt=0)


class IngresoCreate(BaseModel):
    fecha: date | None = None
    id_transporte: int
    cuit_bodega: str = Field(pattern=r"^\d{11}$")
    id_deposito: int


class RenglonIngresoInput(BaseModel):
    codigo_vino: str = Field(min_length=1, max_length=50)
    cantidad_botellas: int = Field(gt=0)


class CepaOut(BaseModel):
    id_cepa: int
    nombre: str
    tipo: str
    porcentaje_corte: Decimal


class MaridajeOut(BaseModel):
    id_maridaje: int
    nombre: str
    temperatura_servicio: Decimal


class VinoListOut(BaseModel):
    codigo_vino: str
    nombre_comercial: str
    tipo: str
    anada: int
    presentacion_ml: int
    graduacion_alcoholica: Decimal
    precio_venta: Decimal
    cuit_bodega: str
    bodega: str


class VinoDetailOut(VinoListOut):
    cepas: list[CepaOut]
    maridajes: list[MaridajeOut]
    stock_deposito: int
    stock_salas: int
    stock_total: int


class VinoPage(BaseModel):
    total: int
    page: int
    limit: int
    items: list[VinoListOut]


class ClienteOut(BaseModel):
    id_cliente: int
    apellido: str
    nombre: str | None
    cuit: str
    tipo_cliente: str
    tipo_documento: str
    nro_documento: str
    calle_cliente: str
    nro_calle_cliente: int
    id_localidad: int
    localidad: str | None
    fecha_alta: date
    descuento_porcentaje: Decimal
    numero_socio: int | None
    zona_cobertura: str | None
    nro_habilitacion: str | None
    pais_destino_principal: str | None


class ClientePage(BaseModel):
    total: int
    page: int
    limit: int
    items: list[ClienteOut]


class PermisoExportacionCreate(BaseModel):
    codigo_permiso: str = Field(min_length=1, max_length=50)
    fecha_emision: date
    fecha_vencimiento: date

    @field_validator("codigo_permiso")
    @classmethod
    def validate_codigo_permiso(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("El código del permiso no puede estar vacío")
        return value.strip()

    @model_validator(mode="after")
    def validate_dates(self) -> "PermisoExportacionCreate":
        if self.fecha_vencimiento <= self.fecha_emision:
            raise ValueError("La fecha de vencimiento debe ser posterior a la de emisión")
        return self


class PermisoExportacionOut(BaseModel):
    id_permiso: int
    codigo_permiso: str
    fecha_emision: date
    fecha_vencimiento: date


class RenglonVentaOut(BaseModel):
    codigo_vino: str
    nombre_comercial: str
    cantidad: int
    precio_unitario: Decimal
    descuento_aplicado: Decimal
    subtotal: Decimal


class ComprobanteOut(BaseModel):
    nro_comprobante: int
    fecha: date
    id_cliente: int
    cliente: str | None
    id_sala: int
    sala: str | None
    subtotal: Decimal
    descuento: Decimal
    total: Decimal
    renglones: list[RenglonVentaOut]


class RenglonTransferenciaOut(BaseModel):
    codigo_vino: str
    nombre_comercial: str
    cantidad: int


class TransferenciaOut(BaseModel):
    nro_transferencia: int
    id_sala_solicitante: int
    id_deposito: int
    fecha_confeccion: date
    estado: EstadoDocumento
    renglones: list[RenglonTransferenciaOut]


class TransferenciaListItem(BaseModel):
    nro_transferencia: int
    id_sala_solicitante: int
    id_deposito: int
    fecha_confeccion: date
    estado: EstadoDocumento


class TransferenciaPage(BaseModel):
    total: int
    page: int
    limit: int
    items: list[TransferenciaListItem]


class RenglonIngresoOut(BaseModel):
    codigo_vino: str
    nombre_comercial: str
    cantidad_botellas: int


class IngresoOut(BaseModel):
    id_ingreso: int
    fecha: date
    estado: EstadoDocumento
    id_transporte: int
    cuit_bodega: str
    id_deposito: int
    renglones: list[RenglonIngresoOut]


class SaludOut(BaseModel):
    status: str
    database: str
