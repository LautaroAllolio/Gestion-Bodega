import { useEffect, useState } from 'react'
import { api } from '../api/endpoints'
import type { Cliente, Comprobante, VinoListItem } from '../api/types'
import { EmptyState, ErrorBanner, Loading, SuccessBanner } from '../components/Feedback'
import { useCatalogos } from '../context/CatalogosContext'
import { formatMoney, getErrorMessage, nombreSala } from '../lib/format'
import { useDebouncedValue } from '../lib/useDebouncedValue'

interface ItemCarrito {
  vino: VinoListItem
  cantidad: number
}

export function NuevaVentaPage() {
  const { salas, loading: catalogosLoading, error: catalogosError } = useCatalogos()
  const [clientes, setClientes] = useState<Cliente[]>([])
  const [clientesTotal, setClientesTotal] = useState(0)
  const [clientesLoading, setClientesLoading] = useState(true)
  const [clientesError, setClientesError] = useState<string | null>(null)
  const [busquedaCliente, setBusquedaCliente] = useState('')
  const [idCliente, setIdCliente] = useState('')
  const [idSala, setIdSala] = useState('')

  const [busquedaVino, setBusquedaVino] = useState('')
  const [vinos, setVinos] = useState<VinoListItem[]>([])
  const [vinosLoading, setVinosLoading] = useState(true)
  const [vinosError, setVinosError] = useState<string | null>(null)
  const [carrito, setCarrito] = useState<ItemCarrito[]>([])

  const [cotizacion, setCotizacion] = useState<Comprobante | null>(null)
  const [cotizando, setCotizando] = useState(false)
  const [cotizacionError, setCotizacionError] = useState<string | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [venta, setVenta] = useState<Comprobante | null>(null)

  const debouncedCliente = useDebouncedValue(busquedaCliente, 350)
  const debouncedVino = useDebouncedValue(busquedaVino, 350)

  useEffect(() => {
    let active = true
    setClientesLoading(true)
    setClientesError(null)
    api
      .listClientes({ q: debouncedCliente || undefined, limit: 50 })
      .then((result) => {
        if (!active) return
        setClientes(result.items)
        setClientesTotal(result.total)
      })
      .catch((err) => {
        if (active) setClientesError(getErrorMessage(err))
      })
      .finally(() => {
        if (active) setClientesLoading(false)
      })
    return () => {
      active = false
    }
  }, [debouncedCliente])

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

  useEffect(() => {
    const renglones = carrito
      .filter((item) => item.cantidad > 0)
      .map((item) => ({ codigo_vino: item.vino.codigo_vino, cantidad: item.cantidad }))
    if (!idCliente || !idSala || renglones.length === 0) {
      setCotizacion(null)
      setCotizacionError(null)
      setCotizando(false)
      return
    }

    let active = true
    const timer = window.setTimeout(() => {
      setCotizando(true)
      setCotizacionError(null)
      api
        .cotizarComprobante({
          id_cliente: Number(idCliente),
          id_sala: Number(idSala),
          renglones,
        })
        .then((result) => {
          if (active) setCotizacion(result)
        })
        .catch((err) => {
          if (!active) return
          setCotizacion(null)
          setCotizacionError(getErrorMessage(err))
        })
        .finally(() => {
          if (active) setCotizando(false)
        })
    }, 350)

    return () => {
      active = false
      window.clearTimeout(timer)
    }
  }, [idCliente, idSala, carrito])

  function agregarVino(vino: VinoListItem) {
    setVenta(null)
    setCarrito((actual) => {
      const existente = actual.find((item) => item.vino.codigo_vino === vino.codigo_vino)
      if (existente) {
        return actual.map((item) =>
          item.vino.codigo_vino === vino.codigo_vino
            ? { ...item, cantidad: item.cantidad + 1 }
            : item,
        )
      }
      return [...actual, { vino, cantidad: 1 }]
    })
  }

  function cambiarCantidad(codigo: string, cantidad: number) {
    setVenta(null)
    setCarrito((actual) =>
      actual.map((item) =>
        item.vino.codigo_vino === codigo ? { ...item, cantidad } : item,
      ),
    )
  }

  function quitarVino(codigo: string) {
    setVenta(null)
    setCarrito((actual) => actual.filter((item) => item.vino.codigo_vino !== codigo))
  }

  async function confirmarVenta() {
    if (!idCliente || !idSala || carrito.length === 0) return
    setGuardando(true)
    setError(null)
    try {
      const result = await api.crearComprobante({
        id_cliente: Number(idCliente),
        id_sala: Number(idSala),
        renglones: carrito.map((item) => ({
          codigo_vino: item.vino.codigo_vino,
          cantidad: item.cantidad,
        })),
      })
      setVenta(result)
      setCarrito([])
      setCotizacion(null)
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setGuardando(false)
    }
  }

  const clienteSeleccionado = clientes.find((item) => String(item.id_cliente) === idCliente)
  const salaSeleccionada = salas.find((item) => String(item.id_sala) === idSala)

  return (
    <section className="page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">Ventas</p>
          <h1>Nueva venta</h1>
          <p>
            El subtotal, el descuento y el total se calculan en la base y se muestran desde la
            API.
          </p>
        </div>
      </div>

      <ErrorBanner message={catalogosError} />
      <ErrorBanner message={clientesError} />
      <ErrorBanner message={vinosError} />
      <ErrorBanner message={error} />
      <ErrorBanner message={cotizacionError} />
      <SuccessBanner
        message={
          venta
            ? `Venta ${venta.nro_comprobante} registrada por ${formatMoney(venta.total)}.`
            : null
        }
      />

      <div className="two-columns">
        <div className="stack">
          <section className="card">
            <h2>Cliente y sala</h2>
            <div className="form-grid compact">
              <label>
                Buscar cliente
                <input
                  value={busquedaCliente}
                  onChange={(event) => setBusquedaCliente(event.target.value)}
                  placeholder="Apellido, nombre o CUIT"
                />
              </label>
              <label>
                Cliente
                <select
                  value={idCliente}
                  onChange={(event) => setIdCliente(event.target.value)}
                  disabled={clientesLoading}
                >
                  <option value="">Seleccionar cliente</option>
                  {clientes.map((cliente) => (
                    <option key={cliente.id_cliente} value={cliente.id_cliente}>
                      {cliente.apellido} {cliente.nombre ?? ''} · {cliente.cuit}
                    </option>
                  ))}
                </select>
                <small className="muted">{clientesTotal} clientes encontrados</small>
              </label>
              <label>
                Sala de venta
                <select
                  value={idSala}
                  onChange={(event) => setIdSala(event.target.value)}
                  disabled={catalogosLoading}
                >
                  <option value="">Seleccionar sala</option>
                  {salas.map((sala) => (
                    <option key={sala.id_sala} value={sala.id_sala}>
                      {nombreSala(sala)}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          </section>

          <section className="card">
            <h2>Agregar vinos</h2>
            <label>
              Buscar vino
              <input
                value={busquedaVino}
                onChange={(event) => setBusquedaVino(event.target.value)}
                placeholder="Nombre o código"
              />
            </label>
            {vinosLoading ? (
              <Loading label="Buscando vinos..." />
            ) : vinos.length === 0 ? (
              <EmptyState>No se encontraron vinos.</EmptyState>
            ) : (
              <div className="table-wrapper">
                <table>
                  <thead>
                    <tr>
                      <th>Código</th>
                      <th>Vino</th>
                      <th>Tipo</th>
                      <th>Añada</th>
                      <th className="right">Precio</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {vinos.map((vino) => (
                      <tr key={vino.codigo_vino}>
                        <td className="mono">{vino.codigo_vino}</td>
                        <td>{vino.nombre_comercial}</td>
                        <td>{vino.tipo}</td>
                        <td>{vino.anada}</td>
                        <td className="right">{formatMoney(vino.precio_venta)}</td>
                        <td>
                          <button
                            type="button"
                            className="button small"
                            onClick={() => agregarVino(vino)}
                          >
                            Agregar
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>

        <aside className="stack">
          <section className="card">
            <div className="card-heading">
              <h2>Carrito</h2>
              {carrito.length > 0 && (
                <button
                  type="button"
                  className="button small secondary"
                  onClick={() => {
                    setCarrito([])
                    setVenta(null)
                  }}
                >
                  Vaciar
                </button>
              )}
            </div>
            {carrito.length === 0 ? (
              <EmptyState>Agregá al menos un vino para cotizar la venta.</EmptyState>
            ) : (
              <div className="stack">
                {carrito.map((item) => (
                  <div className="cart-row" key={item.vino.codigo_vino}>
                    <div>
                      <strong>{item.vino.nombre_comercial}</strong>
                      <span className="muted">
                        {item.vino.codigo_vino} · {formatMoney(item.vino.precio_venta)} por
                        unidad
                      </span>
                    </div>
                    <input
                      type="number"
                      min="1"
                      value={item.cantidad}
                      onChange={(event) =>
                        cambiarCantidad(
                          item.vino.codigo_vino,
                          Math.max(1, Number(event.target.value) || 1),
                        )
                      }
                      aria-label={`Cantidad de ${item.vino.nombre_comercial}`}
                    />
                    <button
                      type="button"
                      className="button small secondary"
                      onClick={() => quitarVino(item.vino.codigo_vino)}
                    >
                      Quitar
                    </button>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section className="card">
            <h2>Totales calculados por la API</h2>
            {!idCliente || !idSala || carrito.length === 0 ? (
              <p className="muted">Elegí cliente, sala y vinos para ver la cotización.</p>
            ) : cotizando ? (
              <Loading label="Calculando en el backend..." />
            ) : cotizacion ? (
              <dl className="totals">
                <div>
                  <dt>Cliente</dt>
                  <dd>
                    {clienteSeleccionado
                      ? `${clienteSeleccionado.apellido} ${clienteSeleccionado.nombre ?? ''}`
                      : '-'}
                  </dd>
                </div>
                <div>
                  <dt>Sala</dt>
                  <dd>{salaSeleccionada ? nombreSala(salaSeleccionada) : '-'}</dd>
                </div>
                <div>
                  <dt>Subtotal</dt>
                  <dd>{formatMoney(cotizacion.subtotal)}</dd>
                </div>
                <div>
                  <dt>Descuento</dt>
                  <dd>{formatMoney(cotizacion.descuento)}</dd>
                </div>
                <div className="total-row">
                  <dt>Total</dt>
                  <dd>{formatMoney(cotizacion.total)}</dd>
                </div>
              </dl>
            ) : null}

            <button
              type="button"
              className="button full-width"
              onClick={() => void confirmarVenta()}
              disabled={!idCliente || !idSala || carrito.length === 0 || guardando || !cotizacion}
            >
              {guardando ? 'Registrando venta...' : 'Confirmar venta'}
            </button>
          </section>

          {venta && (
            <section className="card">
              <h2>Comprobante {venta.nro_comprobante}</h2>
              <p className="muted">
                {venta.cliente} · {venta.sala} · {venta.fecha}
              </p>
              <ul className="plain-list">
                {venta.renglones.map((renglon) => (
                  <li key={renglon.codigo_vino}>
                    <span>
                      {renglon.nombre_comercial} × {renglon.cantidad}
                    </span>
                    <strong>{formatMoney(renglon.subtotal)}</strong>
                  </li>
                ))}
              </ul>
              <p className="total-line">Total: {formatMoney(venta.total)}</p>
            </section>
          )}
        </aside>
      </div>
    </section>
  )
}
