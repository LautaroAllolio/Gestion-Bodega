import { request, withQuery } from './client'
import type {
  Bodega,
  Cepa,
  Cliente,
  Comprobante,
  ComprobantePayload,
  Deposito,
  EstadoDocumento,
  Maridaje,
  Page,
  RenglonTransferenciaPayload,
  Sala,
  TopVino,
  Transferencia,
  TransferenciaListItem,
  TransferenciaPayload,
  VentaSala,
  VinoDetail,
  VinoListItem,
  VinoPayload,
  VinoSinStock,
} from './types'

export interface VinosQuery {
  q?: string
  tipo?: string
  bodega?: string
  cepa?: string
  anada?: number | string
  page?: number
  limit?: number
}

export interface ClientesQuery {
  q?: string
  tipo_cliente?: string
  page?: number
  limit?: number
}

export const api = {
  listVinos(query: VinosQuery = {}) {
    return request<Page<VinoListItem>>(withQuery('/vinos', query))
  },
  getVino(codigo: string) {
    return request<VinoDetail>(`/vinos/${encodeURIComponent(codigo)}`)
  },
  createVino(payload: VinoPayload) {
    return request<VinoDetail>('/vinos', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
  },
  updateVino(codigo: string, payload: Partial<VinoPayload>) {
    return request<VinoDetail>(`/vinos/${encodeURIComponent(codigo)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    })
  },
  listClientes(query: ClientesQuery = {}) {
    return request<Page<Cliente>>(withQuery('/clientes', query))
  },
  listBodegas() {
    return request<Bodega[]>('/catalogos/bodegas')
  },
  listCepas() {
    return request<Cepa[]>('/catalogos/cepas')
  },
  listMaridajes() {
    return request<Maridaje[]>('/catalogos/maridajes')
  },
  listSalas() {
    return request<Sala[]>('/catalogos/salas')
  },
  listDepositos() {
    return request<Deposito[]>('/catalogos/depositos')
  },
  cotizarComprobante(payload: ComprobantePayload) {
    return request<Comprobante>('/comprobantes/cotizar', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
  },
  crearComprobante(payload: ComprobantePayload) {
    return request<Comprobante>('/comprobantes', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
  },
  listTransferencias(query: { estado?: EstadoDocumento | ''; page?: number; limit?: number } = {}) {
    return request<Page<TransferenciaListItem>>(withQuery('/transferencias', query))
  },
  getTransferencia(nro: number) {
    return request<Transferencia>(`/transferencias/${nro}`)
  },
  crearTransferencia(payload: TransferenciaPayload) {
    return request<Transferencia>('/transferencias', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
  },
  agregarRenglonTransferencia(nro: number, payload: RenglonTransferenciaPayload) {
    return request<Transferencia>(`/transferencias/${nro}/renglones`, {
      method: 'POST',
      body: JSON.stringify(payload),
    })
  },
  terminarTransferencia(nro: number) {
    return request<Transferencia>(`/transferencias/${nro}/terminar`, { method: 'POST' })
  },
  procesarTransferencia(nro: number) {
    return request<Transferencia>(`/transferencias/${nro}/procesar`, { method: 'POST' })
  },
  getTopVinos() {
    return request<TopVino[]>('/reportes/s4-top-vinos')
  },
  getVentasSalaTrimestre() {
    return request<VentaSala[]>('/reportes/s13-ventas-sala-trimestre')
  },
  getVinosSinStockSala(idSala: number) {
    return request<VinoSinStock[]>(
      withQuery('/reportes/s14-vinos-sin-stock-sala', { id_sala: idSala }),
    )
  },
}
