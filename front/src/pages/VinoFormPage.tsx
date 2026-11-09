import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api/endpoints'
import type { TipoVino, VinoPayload } from '../api/types'
import { ErrorBanner, Loading } from '../components/Feedback'
import { useCatalogos } from '../context/CatalogosContext'
import { formatDecimal, getErrorMessage } from '../lib/format'

interface CepaForm {
  id_cepa: number
  porcentaje_corte: string
}

interface FormState {
  codigo_vino: string
  nombre_comercial: string
  tipo: TipoVino
  anada: string
  presentacion_ml: string
  graduacion_alcoholica: string
  precio_venta: string
  cuit_bodega: string
  cepas: CepaForm[]
  maridajes: number[]
}

const tipos: TipoVino[] = ['Tinto', 'Blanco', 'Rosado', 'Espumante']

const estadoInicial: FormState = {
  codigo_vino: '',
  nombre_comercial: '',
  tipo: 'Tinto',
  anada: String(new Date().getFullYear()),
  presentacion_ml: '750',
  graduacion_alcoholica: '13.5',
  precio_venta: '',
  cuit_bodega: '',
  cepas: [{ id_cepa: 0, porcentaje_corte: '100' }],
  maridajes: [],
}

export function VinoFormPage() {
  const { codigo } = useParams()
  const navigate = useNavigate()
  const editando = Boolean(codigo)
  const { bodegas, cepas, maridajes, loading: catalogosLoading, error: catalogosError } =
    useCatalogos()
  const [form, setForm] = useState<FormState>(estadoInicial)
  const [loading, setLoading] = useState(editando)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!codigo) return
    let active = true
    setLoading(true)
    setError(null)
    api
      .getVino(codigo)
      .then((vino) => {
        if (!active) return
        setForm({
          codigo_vino: vino.codigo_vino,
          nombre_comercial: vino.nombre_comercial,
          tipo: vino.tipo,
          anada: String(vino.anada),
          presentacion_ml: String(vino.presentacion_ml),
          graduacion_alcoholica: String(vino.graduacion_alcoholica),
          precio_venta: String(vino.precio_venta),
          cuit_bodega: vino.cuit_bodega,
          cepas: vino.cepas.map((item) => ({
            id_cepa: item.id_cepa,
            porcentaje_corte: String(item.porcentaje_corte),
          })),
          maridajes: vino.maridajes.map((item) => item.id_maridaje),
        })
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
  }, [codigo])

  const sumaCepas = form.cepas.reduce((total, item) => total + Number(item.porcentaje_corte || 0), 0)

  function actualizar<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((actual) => ({ ...actual, [key]: value }))
  }

  function actualizarCepa(index: number, patch: Partial<CepaForm>) {
    setForm((actual) => ({
      ...actual,
      cepas: actual.cepas.map((item, i) => (i === index ? { ...item, ...patch } : item)),
    }))
  }

  function agregarCepa() {
    setForm((actual) => ({
      ...actual,
      cepas: [...actual.cepas, { id_cepa: 0, porcentaje_corte: '0' }],
    }))
  }

  function quitarCepa(index: number) {
    setForm((actual) => ({
      ...actual,
      cepas: actual.cepas.filter((_, i) => i !== index),
    }))
  }

  function alternarMaridaje(id: number) {
    setForm((actual) => ({
      ...actual,
      maridajes: actual.maridajes.includes(id)
        ? actual.maridajes.filter((item) => item !== id)
        : [...actual.maridajes, id],
    }))
  }

  async function guardar(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setError(null)
    const payload: VinoPayload = {
      codigo_vino: form.codigo_vino,
      nombre_comercial: form.nombre_comercial.trim(),
      tipo: form.tipo,
      anada: Number(form.anada),
      presentacion_ml: Number(form.presentacion_ml),
      graduacion_alcoholica: Number(form.graduacion_alcoholica),
      precio_venta: Number(form.precio_venta),
      cuit_bodega: form.cuit_bodega,
      cepas: form.cepas.map((item) => ({
        id_cepa: Number(item.id_cepa),
        porcentaje_corte: Number(item.porcentaje_corte),
      })),
      maridajes: form.maridajes,
    }
    try {
      if (editando && codigo) {
        const { codigo_vino: _codigo, ...resto } = payload
        await api.updateVino(codigo, resto)
      } else {
        await api.createVino(payload)
      }
      navigate('/vinos')
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  if (loading || catalogosLoading) {
    return (
      <section className="page">
        <Loading label="Cargando formulario..." />
      </section>
    )
  }

  return (
    <section className="page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">{editando ? 'Edición' : 'Alta'}</p>
          <h1>{editando ? `Editar ${form.codigo_vino}` : 'Nuevo vino'}</h1>
          <p>La composición de cepas se valida en la base; el error se muestra tal cual.</p>
        </div>
        <Link className="button secondary" to="/vinos">
          Volver al catálogo
        </Link>
      </div>

      <ErrorBanner message={catalogosError} />
      <ErrorBanner message={error} />

      <form className="card form-grid" onSubmit={(event) => void guardar(event)}>
        <label>
          Código
          <input
            value={form.codigo_vino}
            onChange={(event) => actualizar('codigo_vino', event.target.value)}
            required
            maxLength={50}
            disabled={editando}
          />
        </label>
        <label>
          Nombre comercial
          <input
            value={form.nombre_comercial}
            onChange={(event) => actualizar('nombre_comercial', event.target.value)}
            required
            maxLength={50}
          />
        </label>
        <label>
          Tipo
          <select
            value={form.tipo}
            onChange={(event) => actualizar('tipo', event.target.value as TipoVino)}
          >
            {tipos.map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
        </label>
        <label>
          Añada
          <input
            type="number"
            value={form.anada}
            onChange={(event) => actualizar('anada', event.target.value)}
            required
          />
        </label>
        <label>
          Presentación (ml)
          <input
            type="number"
            value={form.presentacion_ml}
            onChange={(event) => actualizar('presentacion_ml', event.target.value)}
            required
          />
        </label>
        <label>
          Graduación alcohólica
          <input
            type="number"
            step="0.01"
            value={form.graduacion_alcoholica}
            onChange={(event) => actualizar('graduacion_alcoholica', event.target.value)}
            required
          />
        </label>
        <label>
          Precio de venta
          <input
            type="number"
            step="0.01"
            value={form.precio_venta}
            onChange={(event) => actualizar('precio_venta', event.target.value)}
            required
          />
        </label>
        <label>
          Bodega
          <select
            value={form.cuit_bodega}
            onChange={(event) => actualizar('cuit_bodega', event.target.value)}
            required
          >
            <option value="">Seleccionar bodega</option>
            {bodegas.map((item) => (
              <option key={item.cuit} value={item.cuit}>
                {item.razon_social}
              </option>
            ))}
          </select>
        </label>

        <fieldset className="full-width">
          <legend>Composición de cepas</legend>
          <p className={sumaCepas === 100 ? 'muted' : 'warning-text'}>
            Suma actual: {formatDecimal(sumaCepas)} %. La API rechaza composiciones que no sumen
            100.
          </p>
          <div className="stack">
            {form.cepas.map((item, index) => (
              <div className="inline-row" key={`${index}-${item.id_cepa}`}>
                <label className="grow">
                  Cepa
                  <select
                    value={item.id_cepa || ''}
                    onChange={(event) =>
                      actualizarCepa(index, { id_cepa: Number(event.target.value) })
                    }
                    required
                  >
                    <option value="">Seleccionar cepa</option>
                    {cepas.map((cepa) => (
                      <option key={cepa.id_cepa} value={cepa.id_cepa}>
                        {cepa.nombre} ({cepa.tipo})
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Porcentaje
                  <input
                    type="number"
                    step="0.01"
                    value={item.porcentaje_corte}
                    onChange={(event) =>
                      actualizarCepa(index, { porcentaje_corte: event.target.value })
                    }
                    required
                  />
                </label>
                <button
                  type="button"
                  className="button secondary"
                  onClick={() => quitarCepa(index)}
                  disabled={form.cepas.length === 1}
                >
                  Quitar
                </button>
              </div>
            ))}
          </div>
          <button type="button" className="button secondary" onClick={agregarCepa}>
            Agregar cepa
          </button>
        </fieldset>

        <fieldset className="full-width">
          <legend>Maridajes</legend>
          <div className="checkbox-grid">
            {maridajes.map((item) => (
              <label className="checkbox" key={item.id_maridaje}>
                <input
                  type="checkbox"
                  checked={form.maridajes.includes(item.id_maridaje)}
                  onChange={() => alternarMaridaje(item.id_maridaje)}
                />
                {item.nombre}
              </label>
            ))}
          </div>
        </fieldset>

        <div className="form-actions full-width">
          <button className="button" type="submit" disabled={saving}>
            {saving ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear vino'}
          </button>
          <Link className="button secondary" to="/vinos">
            Cancelar
          </Link>
        </div>
      </form>
    </section>
  )
}
