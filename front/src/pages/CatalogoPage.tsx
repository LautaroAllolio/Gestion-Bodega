import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/endpoints'
import type { Page, VinoDetail, VinoListItem, TipoVino } from '../api/types'
import { EmptyState, ErrorBanner, Loading } from '../components/Feedback'
import { Pagination } from '../components/Pagination'
import { useCatalogos } from '../context/CatalogosContext'
import { formatDecimal, formatMoney, getErrorMessage } from '../lib/format'
import { useDebouncedValue } from '../lib/useDebouncedValue'

const tipos: TipoVino[] = ['Tinto', 'Blanco', 'Rosado', 'Espumante']

export function CatalogoPage() {
  const { bodegas, cepas, loading: catalogosLoading, error: catalogosError } = useCatalogos()
  const [q, setQ] = useState('')
  const [tipo, setTipo] = useState('')
  const [bodega, setBodega] = useState('')
  const [cepa, setCepa] = useState('')
  const [anada, setAnada] = useState('')
  const [page, setPage] = useState(1)
  const [data, setData] = useState<Page<VinoListItem> | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [detalle, setDetalle] = useState<VinoDetail | null>(null)
  const [detalleLoading, setDetalleLoading] = useState(false)
  const [detalleError, setDetalleError] = useState<string | null>(null)
  const detalleRef = useRef<HTMLElement>(null)

  const debouncedQ = useDebouncedValue(q, 300)
  const debouncedAnada = useDebouncedValue(anada, 400)
  const limit = 10

  useEffect(() => {
    if (!detalle) return
    detalleRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    detalleRef.current?.focus({ preventScroll: true })
  }, [detalle])

  useEffect(() => {
    let active = true
    setLoading(true)
    setError(null)
    api
      .listVinos({
        q: debouncedQ || undefined,
        tipo: tipo || undefined,
        bodega: bodega || undefined,
        cepa: cepa || undefined,
        anada: debouncedAnada || undefined,
        page,
        limit,
      })
      .then((result) => {
        if (active) setData(result)
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
  }, [debouncedQ, tipo, bodega, cepa, debouncedAnada, page])

  async function verDetalle(codigo: string) {
    setDetalleLoading(true)
    setDetalleError(null)
    try {
      setDetalle(await api.getVino(codigo))
    } catch (err) {
      setDetalleError(getErrorMessage(err))
      setDetalle(null)
    } finally {
      setDetalleLoading(false)
    }
  }

  function cambiarFiltro(accion: () => void) {
    accion()
    setPage(1)
  }

  return (
    <section className="page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">Catálogo</p>
          <h1>Vinos disponibles</h1>
          <p>Listado paginado con filtros por tipo, cepa, bodega y añada.</p>
        </div>
        <Link className="button" to="/vinos/nuevo">
          Nuevo vino
        </Link>
      </div>

      <ErrorBanner message={catalogosError} />

      <form className="filters" onSubmit={(event) => event.preventDefault()}>
        <label>
          Buscar
          <input
            value={q}
            onChange={(event) => cambiarFiltro(() => setQ(event.target.value))}
            placeholder="Nombre o código"
          />
        </label>
        <label>
          Tipo
          <select value={tipo} onChange={(event) => cambiarFiltro(() => setTipo(event.target.value))}>
            <option value="">Todos</option>
            {tipos.map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
        </label>
        <label>
          Cepa
          <select value={cepa} onChange={(event) => cambiarFiltro(() => setCepa(event.target.value))}>
            <option value="">Todas</option>
            {cepas.map((item) => (
              <option key={item.id_cepa} value={item.nombre}>
                {item.nombre}
              </option>
            ))}
          </select>
        </label>
        <label>
          Bodega
          <select
            value={bodega}
            onChange={(event) => cambiarFiltro(() => setBodega(event.target.value))}
          >
            <option value="">Todas</option>
            {bodegas.map((item) => (
              <option key={item.cuit} value={item.razon_social}>
                {item.razon_social}
              </option>
            ))}
          </select>
        </label>
        <label>
          Añada
          <input
            type="number"
            min="1900"
            max="2100"
            value={anada}
            onChange={(event) => cambiarFiltro(() => setAnada(event.target.value))}
            placeholder="Ej. 2024"
          />
        </label>
      </form>

      <ErrorBanner message={error} />

      {loading || catalogosLoading ? (
        <Loading label="Cargando catálogo..." />
      ) : !data || data.items.length === 0 ? (
        <EmptyState>No hay vinos que coincidan con los filtros.</EmptyState>
      ) : (
        <>
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Código</th>
                  <th>Nombre</th>
                  <th>Tipo</th>
                  <th>Añada</th>
                  <th>Bodega</th>
                  <th>Precio</th>
                  <th>Acciones</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((vino) => (
                  <tr key={vino.codigo_vino}>
                    <td className="mono">{vino.codigo_vino}</td>
                    <td>{vino.nombre_comercial}</td>
                    <td>{vino.tipo}</td>
                    <td>{vino.anada}</td>
                    <td>{vino.bodega}</td>
                    <td className="right">{formatMoney(vino.precio_venta)}</td>
                    <td>
                      <div className="table-actions">
                        <button
                          type="button"
                          className="button small secondary"
                          onClick={() => void verDetalle(vino.codigo_vino)}
                        >
                          Detalle
                        </button>
                        <Link
                          className="button small secondary"
                          to={`/vinos/${encodeURIComponent(vino.codigo_vino)}/editar`}
                        >
                          Editar
                        </Link>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pagination page={data.page} limit={data.limit} total={data.total} onChange={setPage} />
        </>
      )}

      <ErrorBanner message={detalleError} />

      {detalleLoading && <Loading label="Cargando detalle..." />}

      {detalle && !detalleLoading && (
        <article ref={detalleRef} className="card detail-card" tabIndex={-1}>
          <div className="card-heading">
            <div>
              <p className="eyebrow">Detalle</p>
              <h2>{detalle.nombre_comercial}</h2>
              <p className="muted">
                {detalle.codigo_vino} · {detalle.tipo} · {detalle.anada} ·{' '}
                {detalle.presentacion_ml} ml · {formatDecimal(detalle.graduacion_alcoholica)}°
              </p>
            </div>
            <button type="button" className="button secondary" onClick={() => setDetalle(null)}>
              Cerrar
            </button>
          </div>
          <div className="detail-grid">
            <div>
              <h3>Composición de cepas</h3>
              <ul className="plain-list">
                {detalle.cepas.map((item) => (
                  <li key={item.id_cepa}>
                    <span>{item.nombre}</span>
                    <strong>{formatDecimal(item.porcentaje_corte)} %</strong>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3>Maridajes</h3>
              {detalle.maridajes.length === 0 ? (
                <p className="muted">Sin maridajes registrados.</p>
              ) : (
                <ul className="plain-list">
                  {detalle.maridajes.map((item) => (
                    <li key={item.id_maridaje}>
                      <span>{item.nombre}</span>
                      <strong>{formatDecimal(item.temperatura_servicio)} °C</strong>
                    </li>
                  ))}
                </ul>
              )}
            </div>
            <div>
              <h3>Stock</h3>
              <ul className="plain-list">
                <li>
                  <span>Depósito</span>
                  <strong>{formatDecimal(detalle.stock_deposito)}</strong>
                </li>
                <li>
                  <span>Salas</span>
                  <strong>{formatDecimal(detalle.stock_salas)}</strong>
                </li>
                <li>
                  <span>Total</span>
                  <strong>{formatDecimal(detalle.stock_total)}</strong>
                </li>
              </ul>
            </div>
          </div>
        </article>
      )}
    </section>
  )
}
