import { useEffect, useState } from 'react'
import type {
  Cliente,
  ClientePayload,
  ClienteReplacePayload,
  Localidad,
  Page,
  TipoCliente,
} from '../api/types'
import { api } from '../api/endpoints'
import { ClienteForm, type ClienteFormValues } from '../components/ClienteForm'
import { EmptyState, ErrorBanner, Loading, SuccessBanner } from '../components/Feedback'
import { Pagination } from '../components/Pagination'
import { formatDate, formatDecimal, getErrorMessage } from '../lib/format'
import { useDebouncedValue } from '../lib/useDebouncedValue'

const tipos: TipoCliente[] = ['Socio', 'Distribuidor', 'Exportador']

function tipoClienteSeleccionado(value: string): TipoCliente | '' {
  return tipos.find((tipo) => tipo === value) ?? ''
}

export function ClientesPage() {
  const [clientes, setClientes] = useState<Page<Cliente> | null>(null)
  const [localidades, setLocalidades] = useState<Localidad[]>([])
  const [localidadesLoading, setLocalidadesLoading] = useState(true)
  const [localidadesError, setLocalidadesError] = useState<string | null>(null)
  const [q, setQ] = useState('')
  const [tipo, setTipo] = useState<TipoCliente | ''>('')
  const [page, setPage] = useState(1)
  const [refreshKey, setRefreshKey] = useState(0)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [deletingId, setDeletingId] = useState<number | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [editing, setEditing] = useState<Cliente | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const debouncedQ = useDebouncedValue(q, 300)

  useEffect(() => {
    let active = true
    api.listLocalidades()
      .then((result) => {
        if (active) setLocalidades(result)
      })
      .catch((err) => {
        if (active) setLocalidadesError(getErrorMessage(err))
      })
      .finally(() => {
        if (active) setLocalidadesLoading(false)
      })
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    let active = true
    setLoading(true)
    setError(null)
    api.listClientes({
      q: debouncedQ || undefined,
      tipo_cliente: tipo || undefined,
      page,
      limit: 10,
    })
      .then((result) => {
        if (active) setClientes(result)
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
  }, [debouncedQ, tipo, page, refreshKey])

  function abrirAlta() {
    setEditing(null)
    setShowForm(true)
    setError(null)
    setNotice(null)
  }

  function abrirEdicion(cliente: Cliente) {
    setEditing(cliente)
    setShowForm(true)
    setError(null)
    setNotice(null)
  }

  async function guardar(values: ClienteFormValues) {
    setSaving(true)
    setError(null)
    setNotice(null)
    const common = {
      apellido: values.apellido.trim(),
      nombre: values.nombre.trim() || null,
      cuit: values.cuit.trim(),
      tipo_cliente: values.tipo_cliente,
      tipo_documento: values.tipo_documento.trim(),
      nro_documento: values.nro_documento.trim(),
      calle_cliente: values.calle_cliente.trim(),
      nro_calle_cliente: Number(values.nro_calle_cliente),
      id_localidad: Number(values.id_localidad),
      fecha_alta: values.fecha_alta,
      descuento_porcentaje: Number(values.descuento_porcentaje),
    }
    const subtype = {
      numero_socio: values.tipo_cliente === 'Socio' && values.numero_socio
        ? Number(values.numero_socio)
        : null,
      zona_cobertura: values.tipo_cliente === 'Distribuidor' ? values.zona_cobertura.trim() : null,
      nro_habilitacion: values.tipo_cliente === 'Distribuidor' ? values.nro_habilitacion.trim() : null,
      pais_destino_principal:
        values.tipo_cliente === 'Exportador' ? values.pais_destino_principal.trim() : null,
    }

    try {
      if (editing) {
        const payload: ClienteReplacePayload = { ...common, ...subtype }
        await api.replaceCliente(editing.id_cliente, payload)
        setNotice('Cliente actualizado correctamente.')
      } else {
        const payload: ClientePayload = { ...common, ...subtype }
        await api.createCliente(payload)
        setNotice('Cliente creado correctamente.')
        setPage(1)
      }
      setShowForm(false)
      setEditing(null)
      setRefreshKey((current) => current + 1)
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  async function eliminar(cliente: Cliente) {
    if (!window.confirm(`¿Eliminar al cliente ${cliente.apellido} (${cliente.id_cliente})?`)) return
    setDeletingId(cliente.id_cliente)
    setError(null)
    setNotice(null)
    try {
      await api.deleteCliente(cliente.id_cliente)
      setNotice('Cliente eliminado correctamente.')
      if (clientes?.items.length === 1 && page > 1) setPage((current) => current - 1)
      setRefreshKey((current) => current + 1)
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setDeletingId(null)
    }
  }

  return (
    <section className="page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">Administración</p>
          <h1>Clientes</h1>
          <p>Buscá, creá y actualizá clientes. La baja respeta las restricciones del historial.</p>
        </div>
        {!showForm && (
          <button
            type="button"
            className="button"
            onClick={abrirAlta}
            disabled={localidadesLoading || localidadesError !== null}
          >
            {localidadesLoading ? 'Cargando localidades...' : 'Nuevo cliente'}
          </button>
        )}
      </div>

      <ErrorBanner message={error} />
      <ErrorBanner message={localidadesError} />
      <SuccessBanner message={notice} />

      {showForm && (
        <ClienteForm
          cliente={editing}
          localidades={localidades}
          saving={saving}
          onCancel={() => {
            setShowForm(false)
            setEditing(null)
          }}
          onSubmit={(values) => void guardar(values)}
        />
      )}

      <form className="filters" onSubmit={(event) => event.preventDefault()}>
        <label>
          Buscar
          <input
            type="search"
            value={q}
            onChange={(event) => {
              setQ(event.target.value)
              setPage(1)
            }}
            placeholder="Nombre, apellido o CUIT"
          />
        </label>
        <label>
          Tipo de cliente
          <select
            value={tipo}
            onChange={(event) => {
              setTipo(tipoClienteSeleccionado(event.target.value))
              setPage(1)
            }}
          >
            <option value="">Todos</option>
            {tipos.map((item) => (
              <option key={item} value={item}>{item}</option>
            ))}
          </select>
        </label>
      </form>

      {loading ? (
        <Loading label="Cargando clientes..." />
      ) : !clientes || clientes.items.length === 0 ? (
        <EmptyState>No hay clientes que coincidan con los filtros.</EmptyState>
      ) : (
        <>
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Cliente</th>
                  <th>CUIT</th>
                  <th>Tipo</th>
                  <th>Localidad</th>
                  <th>Alta</th>
                  <th>Descuento</th>
                  <th>Acciones</th>
                </tr>
              </thead>
              <tbody>
                {clientes.items.map((cliente) => (
                  <tr key={cliente.id_cliente}>
                    <td>
                      <strong>{cliente.apellido}</strong>
                      {cliente.nombre && <span className="client-name"> {cliente.nombre}</span>}
                      <small className="client-id">ID {cliente.id_cliente}</small>
                    </td>
                    <td className="mono">{cliente.cuit}</td>
                    <td>{cliente.tipo_cliente}</td>
                    <td>{cliente.localidad ?? `Localidad ${cliente.id_localidad}`}</td>
                    <td>{formatDate(cliente.fecha_alta)}</td>
                    <td>{formatDecimal(cliente.descuento_porcentaje)}%</td>
                    <td>
                      <div className="table-actions">
                        <button
                          type="button"
                          className="button small secondary"
                          onClick={() => abrirEdicion(cliente)}
                          disabled={localidadesLoading || localidadesError !== null}
                        >
                          Editar
                        </button>
                        <button
                          type="button"
                          className="button small danger"
                          onClick={() => void eliminar(cliente)}
                          disabled={deletingId !== null}
                        >
                          {deletingId === cliente.id_cliente ? 'Eliminando...' : 'Eliminar'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination
            page={clientes.page}
            limit={clientes.limit}
            total={clientes.total}
            onChange={setPage}
          />
        </>
      )}
    </section>
  )
}
