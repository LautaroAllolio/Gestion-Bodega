export type TipoVino = 'Tinto' | 'Blanco' | 'Rosado' | 'Espumante'
export type TipoCliente = 'Socio' | 'Distribuidor' | 'Exportador'
export type EstadoDocumento = 'en_confeccion' | 'terminado' | 'procesado'

export interface Page<T> {
  total: number
  page: number
  limit: number
  items: T[]
}

export interface VinoListItem {
  codigo_vino: string
  nombre_comercial: string
  tipo: TipoVino
  anada: number
  presentacion_ml: number
  graduacion_alcoholica: number | string
  precio_venta: number | string
  cuit_bodega: string
  bodega: string
}

export interface CepaDeVino {
  id_cepa: number
  nombre: string
  tipo: string
  porcentaje_corte: number | string
}

export interface MaridajeDeVino {
  id_maridaje: number
  nombre: string
  temperatura_servicio: number | string
}

export interface VinoDetail extends VinoListItem {
  cepas: CepaDeVino[]
  maridajes: MaridajeDeVino[]
  stock_deposito: number
  stock_salas: number
  stock_total: number
}

export interface Cliente {
  id_cliente: number
  apellido: string
  nombre: string | null
  cuit: string
  tipo_cliente: TipoCliente
  tipo_documento: string
  nro_documento: string
  calle_cliente: string
  nro_calle_cliente: number
  id_localidad: number
  localidad: string | null
  fecha_alta: string
  descuento_porcentaje: number | string
  numero_socio: number | null
  zona_cobertura: string | null
  nro_habilitacion: string | null
  pais_destino_principal: string | null
}

export interface Localidad {
  id_localidad: number
  nombre: string
  provincia: string
}

export interface ClientePayload {
  apellido: string
  nombre?: string | null
  cuit: string
  tipo_cliente: TipoCliente
  tipo_documento: string
  nro_documento: string
  calle_cliente: string
  nro_calle_cliente: number
  id_localidad: number
  fecha_alta?: string
  descuento_porcentaje: number
  numero_socio?: number | null
  zona_cobertura?: string | null
  nro_habilitacion?: string | null
  pais_destino_principal?: string | null
}

export interface ClienteReplacePayload extends ClientePayload {
  nombre: string | null
  fecha_alta: string
  numero_socio: number | null
  zona_cobertura: string | null
  nro_habilitacion: string | null
  pais_destino_principal: string | null
}

export interface Bodega {
  cuit: string
  razon_social: string
}

export interface Cepa {
  id_cepa: number
  nombre: string
  tipo: string
}

export interface Maridaje {
  id_maridaje: number
  nombre: string
  temperatura_servicio: number | string
}

export interface Sala {
  id_sala: number
  calle: string
  numero_calle: number
  id_localidad: number
  localidad: string
}

export interface Deposito {
  id_deposito: number
  nombre: string
}

export interface RenglonVenta {
  codigo_vino: string
  nombre_comercial: string
  cantidad: number
  precio_unitario: number | string
  descuento_aplicado: number | string
  subtotal: number | string
}

export interface Comprobante {
  nro_comprobante: number
  fecha: string
  id_cliente: number
  cliente: string | null
  id_sala: number
  sala: string | null
  subtotal: number | string
  descuento: number | string
  total: number | string
  renglones: RenglonVenta[]
}

export interface RenglonTransferencia {
  codigo_vino: string
  nombre_comercial: string
  cantidad: number
}

export interface TransferenciaListItem {
  nro_transferencia: number
  id_sala_solicitante: number
  id_deposito: number
  fecha_confeccion: string
  estado: EstadoDocumento
}

export interface Transferencia {
  nro_transferencia: number
  id_sala_solicitante: number
  id_deposito: number
  fecha_confeccion: string
  estado: EstadoDocumento
  renglones: RenglonTransferencia[]
}

export interface TopVino {
  codigo_vino: string
  nombre_comercial: string
  unidades_vendidas: number
  total_vendido: number | string
}

export interface VentaSala {
  id_sala: number
  sala: string
  comprobantes: number
  total: number | string
}

export interface VinoSinStock {
  codigo_vino: string
  nombre_comercial: string
  tipo: TipoVino
  stock_sala: number
}

export interface VinoPayload {
  codigo_vino?: string
  nombre_comercial: string
  tipo: TipoVino
  anada: number
  presentacion_ml: number
  graduacion_alcoholica: number
  precio_venta: number
  cuit_bodega: string
  cepas: Array<{ id_cepa: number; porcentaje_corte: number }>
  maridajes: number[]
}

export interface ComprobantePayload {
  fecha?: string
  id_cliente: number
  id_sala: number
  renglones: Array<{ codigo_vino: string; cantidad: number }>
}

export interface TransferenciaPayload {
  id_sala_solicitante: number
  id_deposito: number
}

export interface RenglonTransferenciaPayload {
  codigo_vino: string
  cantidad: number
}
