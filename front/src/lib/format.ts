import { ApiError } from '../api/client'
import type { EstadoDocumento, Sala } from '../api/types'

const moneyFormatter = new Intl.NumberFormat('es-AR', {
  style: 'currency',
  currency: 'ARS',
  maximumFractionDigits: 2,
})

const numberFormatter = new Intl.NumberFormat('es-AR')

export function formatMoney(value: number | string | null | undefined): string {
  return moneyFormatter.format(Number(value ?? 0))
}

export function formatNumber(value: number | string | null | undefined): string {
  return numberFormatter.format(Number(value ?? 0))
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '-'
  const date = new Date(`${value}T00:00:00`)
  return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString('es-AR')
}

export function formatDecimal(value: number | string | null | undefined): string {
  const number = Number(value ?? 0)
  return Number.isInteger(number) ? String(number) : number.toFixed(2)
}

export function nombreSala(sala: Pick<Sala, 'calle' | 'numero_calle' | 'localidad'>): string {
  return `${sala.calle} ${sala.numero_calle}, ${sala.localidad}`
}

export function nombreSalaPorId(salas: Sala[], id: number): string {
  const sala = salas.find((item) => item.id_sala === id)
  return sala ? nombreSala(sala) : `Sala ${id}`
}

export function nombreDepositoPorId(
  depositos: Array<{ id_deposito: number; nombre: string }>,
  id: number,
): string {
  return depositos.find((item) => item.id_deposito === id)?.nombre ?? `Depósito ${id}`
}

export function etiquetaEstado(estado: EstadoDocumento): string {
  const labels: Record<EstadoDocumento, string> = {
    en_confeccion: 'En confección',
    terminado: 'Terminado',
    procesado: 'Procesado',
  }
  return labels[estado]
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    return error.sqlstate ? `${error.message} (${error.sqlstate})` : error.message
  }
  if (error instanceof Error) return error.message
  return 'Ocurrió un error inesperado'
}
