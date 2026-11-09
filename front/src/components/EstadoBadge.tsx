import type { EstadoDocumento } from '../api/types'
import { etiquetaEstado } from '../lib/format'

export function EstadoBadge({ estado }: { estado: EstadoDocumento }) {
  return <span className={`badge estado-${estado}`}>{etiquetaEstado(estado)}</span>
}
