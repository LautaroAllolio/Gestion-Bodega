import { useEffect, useState } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { api } from '../api/endpoints'
import type { TopVino, VentaSala, VinoSinStock } from '../api/types'
import { EmptyState, ErrorBanner, Loading } from '../components/Feedback'
import { useCatalogos } from '../context/CatalogosContext'
import { formatMoney, formatNumber, getErrorMessage, nombreSala } from '../lib/format'

const colores = ['#7f1d1d', '#b45309', '#166534', '#1d4ed8', '#6d28d9', '#0f766e']

export function TableroPage() {
  const { salas, loading: catalogosLoading, error: catalogosError } = useCatalogos()
  const [topVinos, setTopVinos] = useState<TopVino[]>([])
  const [ventasSala, setVentasSala] = useState<VentaSala[]>([])
  const [reportesLoading, setReportesLoading] = useState(true)
  const [reportesError, setReportesError] = useState<string | null>(null)

  const [idSala, setIdSala] = useState('')
  const [sinStock, setSinStock] = useState<VinoSinStock[]>([])
  const [sinStockLoading, setSinStockLoading] = useState(false)
  const [sinStockError, setSinStockError] = useState<string | null>(null)

  useEffect(() => {
    let active = true
    setReportesLoading(true)
    setReportesError(null)
    Promise.all([api.getTopVinos(), api.getVentasSalaTrimestre()])
      .then(([top, ventas]) => {
        if (!active) return
        setTopVinos(top)
        setVentasSala(ventas)
      })
      .catch((err) => {
        if (active) setReportesError(getErrorMessage(err))
      })
      .finally(() => {
        if (active) setReportesLoading(false)
      })
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    if (!idSala) {
      setSinStock([])
      setSinStockError(null)
      return
    }
    let active = true
    setSinStockLoading(true)
    setSinStockError(null)
    api
      .getVinosSinStockSala(Number(idSala))
      .then((result) => {
        if (active) setSinStock(result)
      })
      .catch((err) => {
        if (active) {
          setSinStock([])
          setSinStockError(getErrorMessage(err))
        }
      })
      .finally(() => {
        if (active) setSinStockLoading(false)
      })
    return () => {
      active = false
    }
  }, [idSala])

  const datosTop = topVinos.map((item) => ({
    ...item,
    nombre: item.nombre_comercial.length > 18 ? `${item.nombre_comercial.slice(0, 18)}…` : item.nombre_comercial,
    total: Number(item.total_vendido),
  }))
  const datosSalas = ventasSala.map((item) => ({
    ...item,
    nombre: item.sala.length > 22 ? `${item.sala.slice(0, 22)}…` : item.sala,
    total: Number(item.total),
  }))

  return (
    <section className="page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">Tablero</p>
          <h1>Indicadores de ventas y stock</h1>
          <p>
            Datos agregados por la base: top de vinos vendidos, ventas por sala del último
            trimestre y vinos sin stock en una sala.
          </p>
        </div>
      </div>

      <ErrorBanner message={catalogosError} />
      <ErrorBanner message={reportesError} />

      {reportesLoading ? (
        <Loading label="Cargando reportes..." />
      ) : (
        <div className="dashboard-grid">
          <section className="card chart-card">
            <div className="card-heading">
              <div>
                <p className="eyebrow">S4</p>
                <h2>Top vinos vendidos</h2>
              </div>
              <span className="muted">{topVinos.length} vinos</span>
            </div>
            {datosTop.length === 0 ? (
              <EmptyState>No hay ventas registradas para calcular el ranking.</EmptyState>
            ) : (
              <>
                <div className="chart">
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={datosTop} margin={{ top: 8, right: 8, left: 0, bottom: 48 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#e5e0d8" />
                      <XAxis dataKey="nombre" angle={-30} textAnchor="end" interval={0} tick={{ fontSize: 11 }} />
                      <YAxis tick={{ fontSize: 11 }} />
                      <Tooltip />
                      <Bar dataKey="total" name="Total vendido" radius={[4, 4, 0, 0]}>
                        {datosTop.map((item, index) => (
                          <Cell key={item.codigo_vino} fill={colores[index % colores.length]} />
                        ))}
                      </Bar>
                    </BarChart>
                  </ResponsiveContainer>
                </div>
                <div className="table-wrapper compact-table">
                  <table>
                    <thead>
                      <tr>
                        <th>Vino</th>
                        <th className="right">Unidades</th>
                        <th className="right">Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {topVinos.map((item) => (
                        <tr key={item.codigo_vino}>
                          <td>{item.nombre_comercial}</td>
                          <td className="right">{formatNumber(item.unidades_vendidas)}</td>
                          <td className="right">{formatMoney(item.total_vendido)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </section>

          <section className="card chart-card">
            <div className="card-heading">
              <div>
                <p className="eyebrow">S13</p>
                <h2>Ventas por sala · último trimestre</h2>
              </div>
              <span className="muted">{ventasSala.length} salas</span>
            </div>
            {datosSalas.length === 0 ? (
              <EmptyState>No hay comprobantes en los últimos tres meses.</EmptyState>
            ) : (
              <>
                <div className="chart">
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={datosSalas} margin={{ top: 8, right: 8, left: 0, bottom: 52 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#e5e0d8" />
                      <XAxis dataKey="nombre" angle={-30} textAnchor="end" interval={0} tick={{ fontSize: 11 }} />
                      <YAxis tick={{ fontSize: 11 }} />
                      <Tooltip />
                      <Bar dataKey="total" name="Total vendido" radius={[4, 4, 0, 0]}>
                        {datosSalas.map((item, index) => (
                          <Cell key={item.id_sala} fill={colores[index % colores.length]} />
                        ))}
                      </Bar>
                    </BarChart>
                  </ResponsiveContainer>
                </div>
                <div className="table-wrapper compact-table">
                  <table>
                    <thead>
                      <tr>
                        <th>Sala</th>
                        <th className="right">Comprobantes</th>
                        <th className="right">Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {ventasSala.map((item) => (
                        <tr key={item.id_sala}>
                          <td>{item.sala}</td>
                          <td className="right">{formatNumber(item.comprobantes)}</td>
                          <td className="right">{formatMoney(item.total)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </section>
        </div>
      )}

      <section className="card">
        <div className="card-heading">
          <div>
            <p className="eyebrow">S14</p>
            <h2>Vinos sin stock en sala</h2>
          </div>
          <label className="inline-select">
            Sala
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

        <ErrorBanner message={sinStockError} />

        {!idSala ? (
          <EmptyState>Elegí una sala para consultar los vinos que no tienen stock.</EmptyState>
        ) : sinStockLoading ? (
          <Loading label="Consultando stock..." />
        ) : sinStock.length === 0 ? (
          <EmptyState>Todos los vinos tienen stock en la sala seleccionada.</EmptyState>
        ) : (
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th>Código</th>
                  <th>Vino</th>
                  <th>Tipo</th>
                  <th className="right">Stock en sala</th>
                </tr>
              </thead>
              <tbody>
                {sinStock.map((item) => (
                  <tr key={item.codigo_vino}>
                    <td className="mono">{item.codigo_vino}</td>
                    <td>{item.nombre_comercial}</td>
                    <td>{item.tipo}</td>
                    <td className="right">{formatNumber(item.stock_sala)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </section>
  )
}
