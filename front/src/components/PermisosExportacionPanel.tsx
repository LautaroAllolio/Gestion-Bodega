import { useEffect, useState, type FormEvent } from 'react'
import type { Cliente, PermisoExportacion } from '../api/types'
import { api } from '../api/endpoints'
import { EmptyState, ErrorBanner, Loading, SuccessBanner } from './Feedback'
import { formatDate, getErrorMessage } from '../lib/format'

interface PermisosExportacionPanelProps {
  cliente: Cliente
  onClose: () => void
  onChanged: () => void
}

export function PermisosExportacionPanel({
  cliente,
  onClose,
  onChanged,
}: PermisosExportacionPanelProps) {
  const [permisos, setPermisos] = useState<PermisoExportacion[]>([])
  const [codigo, setCodigo] = useState('')
  const [fechaEmision, setFechaEmision] = useState('')
  const [fechaVencimiento, setFechaVencimiento] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [savingDiscount, setSavingDiscount] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)

  useEffect(() => {
    let active = true
    setLoading(true)
    setError(null)
    api.listPermisosExportacion(cliente.id_cliente)
      .then((result) => {
        if (active) setPermisos(result)
      })
      .catch((err) => {
        if (active) setError(getErrorMessage(err))
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [cliente.id_cliente])

  async function recargarPermisos() {
    setError(null)
    const result = await api.listPermisosExportacion(cliente.id_cliente)
    setPermisos(result)
  }

  async function agregar(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSaving(true)
    setError(null)
    setNotice(null)
    try {
      const permiso = await api.createPermisoExportacion(cliente.id_cliente, {
        codigo_permiso: codigo.trim(),
        fecha_emision: fechaEmision,
        fecha_vencimiento: fechaVencimiento,
      })
      setPermisos((current) => [...current, permiso])
      setCodigo('')
      setFechaEmision('')
      setFechaVencimiento('')
      setNotice('Permiso agregado correctamente.')
      onChanged()
      await recargarPermisos()
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  async function eliminar(permiso: PermisoExportacion) {
    if (!window.confirm(`¿Eliminar el permiso ${permiso.codigo_permiso}?`)) return
    setDeletingId(permiso.id_permiso)
    setError(null)
    setNotice(null)
    try {
      await api.deletePermisoExportacion(cliente.id_cliente, permiso.id_permiso)
      setPermisos((current) =>
        current.filter((item) => item.id_permiso !== permiso.id_permiso),
      )
      setNotice('Permiso eliminado correctamente.')
      onChanged()
      await recargarPermisos()
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setDeletingId(null)
    }
  }

  async function corregirDescuento() {
    setSavingDiscount(true)
    setError(null)
    setNotice(null)
    try {
      await api.updateCliente(cliente.id_cliente, {
        descuento_porcentaje: descuentoAplicable,
      })
      setNotice(`Descuento actualizado al ${descuentoAplicable}%.`)
      onChanged()
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setSavingDiscount(false)
    }
  }

  const descuentoAplicable = permisos.length > 3 ? 35 : 30
  const descuentoActual = Number(cliente.descuento_porcentaje)

  return (
    <section
      id="permissions-panel"
      className="card permission-panel"
      aria-labelledby="permissions-title"
    >
      <div className="card-heading">
        <div>
          <p className="eyebrow">Exportador · ID {cliente.id_cliente}</p>
          <h2 id="permissions-title">Permisos de exportación</h2>
          <p className="muted">
            {loading
              ? 'Cargando permisos...'
              : error
                ? 'No se pudo consultar la cantidad de permisos.'
                : `${permisos.length} permiso${permisos.length === 1 ? '' : 's'} · descuento actual: ${descuentoActual}% · corresponde: ${descuentoAplicable}%`}
          </p>
        </div>
        <button type="button" className="button secondary small" onClick={onClose}>
          Cerrar
        </button>
      </div>

      <p className="permission-note">
        El 35% se aplica automáticamente al registrar el cuarto permiso. Si quedan tres o menos,
        vuelve al 30%.
      </p>
      {!loading && !error && descuentoActual !== descuentoAplicable && (
        <button
          type="button"
          className="button small secondary"
          onClick={() => void corregirDescuento()}
          disabled={savingDiscount || saving || deletingId !== null}
        >
          {savingDiscount ? 'Actualizando descuento...' : `Corregir al ${descuentoAplicable}%`}
        </button>
      )}
      <ErrorBanner message={error} />
      <SuccessBanner message={notice} />

      <form className="form-grid permission-form" onSubmit={(event) => void agregar(event)}>
        <label>
          Código del permiso
          <input
            value={codigo}
            onChange={(event) => setCodigo(event.target.value)}
            maxLength={50}
            disabled={saving || savingDiscount || deletingId !== null}
            required
          />
        </label>
        <label>
          Fecha de emisión
          <input
            type="date"
            value={fechaEmision}
            onChange={(event) => setFechaEmision(event.target.value)}
            disabled={saving || savingDiscount || deletingId !== null}
            required
          />
        </label>
        <label>
          Fecha de vencimiento
          <input
            type="date"
            value={fechaVencimiento}
            min={fechaEmision || undefined}
            onChange={(event) => setFechaVencimiento(event.target.value)}
            disabled={saving || savingDiscount || deletingId !== null}
            required
          />
        </label>
        <button
          type="submit"
          className="button align-end"
          disabled={saving || savingDiscount || deletingId !== null}
        >
          {saving ? 'Guardando...' : 'Agregar permiso'}
        </button>
      </form>

      {loading ? (
        <Loading label="Cargando permisos..." />
      ) : error && permisos.length === 0 ? null : permisos.length === 0 ? (
        <EmptyState>Este exportador todavía no tiene permisos registrados.</EmptyState>
      ) : (
        <div className="table-wrapper compact-table">
          <table>
            <thead>
              <tr>
                <th>Código</th>
                <th>Emisión</th>
                <th>Vencimiento</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {permisos.map((permiso) => (
                <tr key={permiso.id_permiso}>
                  <td className="mono">{permiso.codigo_permiso}</td>
                  <td>{formatDate(permiso.fecha_emision)}</td>
                  <td>{formatDate(permiso.fecha_vencimiento)}</td>
                  <td>
                    <button
                      type="button"
                      className="button small danger"
                      onClick={() => void eliminar(permiso)}
                      disabled={deletingId !== null || saving || savingDiscount}
                    >
                      {deletingId === permiso.id_permiso ? 'Eliminando...' : 'Eliminar'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
