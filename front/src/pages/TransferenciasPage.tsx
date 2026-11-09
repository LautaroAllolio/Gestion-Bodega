import { useEffect, useState } from 'react'
import { api } from '../api/endpoints'
import type {
  EstadoDocumento,
  Page,
  Transferencia,
  TransferenciaListItem,
  VinoListItem,
} from '../api/types'
import { EstadoBadge } from '../components/EstadoBadge'
import { EmptyState, ErrorBanner, Loading, SuccessBanner } from '../components/Feedback'
import { Pagination } from '../components/Pagination'
import { useCatalogos } from '../context/CatalogosContext'
import {
  formatDate,
  getErrorMessage,
  nombreDepositoPorId,
  nombreSalaPorId,
} from '../lib/format'
import { useDebouncedValue } from '../lib/useDebouncedValue'

const estados: Array<{ value: EstadoDocumento | ''; label: string }> = [
  { value: '', label: 'Todos' },
  { value: 'en_confeccion', label: 'En confección' },
  { value: 'terminado', label: 'Terminado' },
  { value: 'procesado', label: 'Procesado' },
]

export function TransferenciasPage() {
  const { salas, depositos, loading: catalogosLoading, error: catalogosError } = useCatalogos()
  const [estadoFiltro, setEstadoFiltro] = useState<EstadoDocumento | ''>('')
  const [page, setPage] = useState(1)
  const [lista, setLista] = useState<Page<TransferenciaListItem> | null>(null)
  const [listaLoading, setListaLoading] = useState(true)
  const [listaError, setListaError] = useState<string | null>(null)
  const [refreshKey, setRefreshKey] = useState(0)

  const [idSala, setIdSala] = useState('')
  const [idDeposito, setIdDeposito] = useState('')
  const [creando, setCreando] = useState(false)
  const [crearError, setCrearError] = useState<string | null>(null)
  const [mensaje, setMensaje] = useState<string | null>(null)

  const [seleccionada, setSeleccionada] = useState<Transferencia | null>(null)
  const [detalleLoading, setDetalleLoading] = useState(false)
  const [detalleError, setDetalleError] = useState<string | null>(null)
  const [accionError, setAccionError] = useState<string | null>(null)

  const [busquedaVino, setBusquedaVino] = useState('')
  const [vinos, setVinos] = useState<VinoListItem[]>([])
  const [vinosLoading, setVinosLoading] = useState(true)
  const [vinosError, setVinosError] = useState<string | null>(null)
  const [codigoVino, setCodigoVino] = useState('')
  const [cantidad, setCantidad] = useState('1')
  const [agregando, setAgregando] = useState(false)
  const [agregarError, setAgregarError] = useState<string | null>(null)

  const debouncedVino = useDebouncedValue(busquedaVino, 350)

  useEffect(() => {
    let active = true
    setListaLoading(true)
    setListaError(null)
    api
      .listTransferencias({ estado: estadoFiltro || undefined, page, limit: 10 })
      .then((result) => {
        if (active) setLista(result)
      })
      .catch((err) => {
        if (active) setListaError(getErrorMessage(err))
      })
      .finally(() => {
        if (active) setListaLoading(false)
      })
    return () => {
      active = false
    }
  }, [estadoFiltro, page, refreshKey])

  useEffect(() => {
    let active = true
    setVinosLoading(true)
    setVinosError(null)
    api
      .listVinos({ q: debouncedVino || undefined, limit: 50 })
      .then((result) => {
        if (active) setVinos(result.items)
      })
      .catch((err) => {
        if (active) setVinosError(getErrorMessage(err))
      })
      .finally(() => {
        if (active) setVinosLoading(false)
      })
    return () => {
      active = false
    }
  }, [debouncedVino])

  function refrescar() {
    setRefreshKey((actual) => actual + 1)
  }

  async function verDetalle(nro: number) {
    setDetalleLoading(true)
    setDetalleError(null)
    setAccionError(null)
    try {
      setSeleccionada(await api.getTransferencia(nro))
    } catch (err) {
      setDetalleError(getErrorMessage(err))
      setSeleccionada(null)
    } finally {
      setDetalleLoading(false)
    }
  }

  async function crearTransferencia() {
    if (!idSala || !idDeposito) return
    setCreando(true)
    setCrearError(null)
    setMensaje(null)
    try {
      const creada = await api.crearTransferencia({
        id_sala_solicitante: Number(idSala),
        id_deposito: Number(idDeposito),
      })
      setSeleccionada(creada)
      setMensaje(`Transferencia ${creada.nro_transferencia} creada en estado en confección.`)
      refrescar()
    } catch (err) {
      setCrearError(getErrorMessage(err))
    } finally {
      setCreando(false)
    }
  }

  async function agregarRenglon() {
    if (!seleccionada || !codigoVino) return
    setAgregando(true)
    setAgregarError(null)
    try {
      const actualizada = await api.agregarRenglonTransferencia(
        seleccionada.nro_transferencia,
        { codigo_vino: codigoVino, cantidad: Number(cantidad) },
      )
      setSeleccionada(actualizada)
      setCantidad('1')
      refrescar()
    } catch (err) {
      setAgregarError(getErrorMessage(err))
    } finally {
      setAgregando(false)
    }
  }

  async function cambiarEstado(accion: 'terminar' | 'procesar') {
    if (!seleccionada) return
    setAccionError(null)
    setMensaje(null)
    try {
      const actualizada =
        accion === 'terminar'
          ? await api.terminarTransferencia(seleccionada.nro_transferencia)
          : await api.procesarTransferencia(seleccionada.nro_transferencia)
      setSeleccionada(actualizada)
      setMensaje(
        `Transferencia ${actualizada.nro_transferencia} actualizada a ${actualizada.estado}.`,
      )
      refrescar()
    } catch (err) {
      setAccionError(getErrorMessage(err))
    }
  }

  const enConfeccion = seleccionada?.estado === 'en_confeccion'
  const terminada = seleccionada?.estado === 'terminado'

  return (
    <section className="page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">Documentos</p>
          <h1>Transferencias</h1>
          <p>Creá una transferencia, cargá renglones y avanzá el estado según la regla de la base.</p>
        </div>
      </div>

      <ErrorBanner message={catalogosError} />
      <ErrorBanner message={crearError} />
      <ErrorBanner message={listaError} />
      <ErrorBanner message={detalleError} />
      <ErrorBanner message={accionError} />
      <ErrorBanner message={vinosError} />
      <ErrorBanner message={agregarError} />
      <SuccessBanner message={mensaje} />

      <section className="card">
        <h2>Nueva transferencia</h2>
        <div className="form-grid compact">
          <label>
            Sala solicitante
            <select
              value={idSala}
              onChange={(event) => setIdSala(event.target.value)}
              disabled={catalogosLoading}
            >
              <option value="">Seleccionar sala</option>
              {salas.map((sala) => (
                <option key={sala.id_sala} value={sala.id_sala}>
                  {sala.calle} {sala.numero_calle}, {sala.localidad}
                </option>
              ))}
            </select>
          </label>
          <label>
            Depósito
            <select
              value={idDeposito}
              onChange={(event) => setIdDeposito(event.target.value)}
              disabled={catalogosLoading}
            >
              <option value="">Seleccionar depósito</option>
              {depositos.map((deposito) => (
                <option key={deposito.id_deposito} value={deposito.id_deposito}>
                  {deposito.nombre}
                </option>
              ))}
            </select>
          </label>
          <div className="form-actions align-end">
            <button
              type="button"
              className="button"
              onClick={() => void crearTransferencia()}
              disabled={!idSala || !idDeposito || creando}
            >
              {creando ? 'Creando...' : 'Crear transferencia'}
            </button>
          </div>
        </div>
      </section>

      <div className="two-columns">
        <section className="card">
          <div className="card-heading">
            <h2>Listado</h2>
            <select
              value={estadoFiltro}
              onChange={(event) => {
                setEstadoFiltro(event.target.value as EstadoDocumento | '')
                setPage(1)
              }}
            >
              {estados.map((estado) => (
                <option key={estado.value} value={estado.value}>
                  {estado.label}
                </option>
              ))}
            </select>
          </div>
          {listaLoading ? (
            <Loading label="Cargando transferencias..." />
          ) : !lista || lista.items.length === 0 ? (
            <EmptyState>No hay transferencias para el filtro seleccionado.</EmptyState>
          ) : (
            <>
              <div className="table-wrapper">
                <table>
                  <thead>
                    <tr>
                      <th>Nro.</th>
                      <th>Fecha</th>
                      <th>Sala</th>
                      <th>Depósito</th>
                      <th>Estado</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {lista.items.map((item) => (
                      <tr key={item.nro_transferencia}>
                        <td className="mono">{item.nro_transferencia}</td>
                        <td>{formatDate(item.fecha_confeccion)}</td>
                        <td>{nombreSalaPorId(salas, item.id_sala_solicitante)}</td>
                        <td>{nombreDepositoPorId(depositos, item.id_deposito)}</td>
                        <td>
                          <EstadoBadge estado={item.estado} />
                        </td>
                        <td>
                          <button
                            type="button"
                            className="button small secondary"
                            onClick={() => void verDetalle(item.nro_transferencia)}
                          >
                            Abrir
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Pagination page={lista.page} limit={lista.limit} total={lista.total} onChange={setPage} />
            </>
          )}
        </section>

        <aside className="stack">
          {detalleLoading ? (
            <Loading label="Cargando transferencia..." />
          ) : !seleccionada ? (
            <section className="card">
              <EmptyState>Abrí una transferencia para cargar renglones y avanzar el estado.</EmptyState>
            </section>
          ) : (
            <section className="card">
              <div className="card-heading">
                <div>
                  <p className="eyebrow">Transferencia</p>
                  <h2>{seleccionada.nro_transferencia}</h2>
                </div>
                <EstadoBadge estado={seleccionada.estado} />
              </div>
              <p className="muted">
                {nombreSalaPorId(salas, seleccionada.id_sala_solicitante)} ·{' '}
                {nombreDepositoPorId(depositos, seleccionada.id_deposito)} ·{' '}
                {formatDate(seleccionada.fecha_confeccion)}
              </p>

              <h3>Renglones</h3>
              {seleccionada.renglones.length === 0 ? (
                <EmptyState>Todavía no hay renglones cargados.</EmptyState>
              ) : (
                <ul className="plain-list">
                  {seleccionada.renglones.map((renglon) => (
                    <li key={renglon.codigo_vino}>
                      <span>
                        {renglon.nombre_comercial} ({renglon.codigo_vino})
                      </span>
                      <strong>{renglon.cantidad}</strong>
                    </li>
                  ))}
                </ul>
              )}

              <div className="stack">
                <label>
                  Buscar vino para agregar
                  <input
                    value={busquedaVino}
                    onChange={(event) => setBusquedaVino(event.target.value)}
                    placeholder="Nombre o código"
                    disabled={!enConfeccion}
                  />
                </label>
                {vinosLoading ? (
                  <Loading label="Buscando vinos..." />
                ) : (
                  <div className="inline-row">
                    <label className="grow">
                      Vino
                      <select
                        value={codigoVino}
                        onChange={(event) => setCodigoVino(event.target.value)}
                        disabled={!enConfeccion}
                      >
                        <option value="">Seleccionar vino</option>
                        {vinos.map((vino) => (
                          <option key={vino.codigo_vino} value={vino.codigo_vino}>
                            {vino.nombre_comercial} ({vino.codigo_vino})
                          </option>
                        ))}
                      </select>
                    </label>
                    <label>
                      Cantidad
                      <input
                        type="number"
                        min="1"
                        value={cantidad}
                        onChange={(event) => setCantidad(event.target.value)}
                        disabled={!enConfeccion}
                      />
                    </label>
                    <button
                      type="button"
                      className="button"
                      onClick={() => void agregarRenglon()}
                      disabled={!enConfeccion || !codigoVino || agregando}
                    >
                      {agregando ? 'Agregando...' : 'Agregar renglón'}
                    </button>
                  </div>
                )}
              </div>

              <div className="form-actions">
                <button
                  type="button"
                  className="button"
                  onClick={() => void cambiarEstado('terminar')}
                  disabled={!enConfeccion}
                >
                  Terminar
                </button>
                <button
                  type="button"
                  className="button"
                  onClick={() => void cambiarEstado('procesar')}
                  disabled={!terminada}
                >
                  Procesar
                </button>
              </div>
            </section>
          )}
        </aside>
      </div>
    </section>
  )
}
