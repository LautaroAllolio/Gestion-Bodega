import { useEffect, useState, type FormEvent } from 'react'
import type { Cliente, Localidad, TipoCliente } from '../api/types'

export interface ClienteFormValues {
  apellido: string
  nombre: string
  cuit: string
  tipo_cliente: TipoCliente
  tipo_documento: string
  nro_documento: string
  calle_cliente: string
  nro_calle_cliente: string
  id_localidad: string
  fecha_alta: string
  descuento_porcentaje: string
  numero_socio: string
  zona_cobertura: string
  nro_habilitacion: string
  pais_destino_principal: string
}

interface ClienteFormProps {
  cliente: Cliente | null
  localidades: Localidad[]
  saving: boolean
  onCancel: () => void
  onSubmit: (values: ClienteFormValues) => void
}

const tipoClientes: TipoCliente[] = ['Socio', 'Distribuidor', 'Exportador']

function esTipoCliente(value: string): value is TipoCliente {
  return tipoClientes.some((tipo) => tipo === value)
}

function fechaLocalActual(): string {
  const ahora = new Date()
  ahora.setMinutes(ahora.getMinutes() - ahora.getTimezoneOffset())
  return ahora.toISOString().slice(0, 10)
}

function valoresIniciales(cliente: Cliente | null): ClienteFormValues {
  if (!cliente) {
    return {
      apellido: '',
      nombre: '',
      cuit: '',
      tipo_cliente: 'Socio',
      tipo_documento: 'DNI',
      nro_documento: '',
      calle_cliente: '',
      nro_calle_cliente: '',
      id_localidad: '',
      fecha_alta: fechaLocalActual(),
      descuento_porcentaje: '',
      numero_socio: '',
      zona_cobertura: '',
      nro_habilitacion: '',
      pais_destino_principal: '',
    }
  }
  return {
    apellido: cliente.apellido,
    nombre: cliente.nombre ?? '',
    cuit: cliente.cuit,
    tipo_cliente: cliente.tipo_cliente,
    tipo_documento: cliente.tipo_documento,
    nro_documento: cliente.nro_documento,
    calle_cliente: cliente.calle_cliente,
    nro_calle_cliente: String(cliente.nro_calle_cliente),
    id_localidad: String(cliente.id_localidad),
    fecha_alta: cliente.fecha_alta,
    descuento_porcentaje: String(cliente.descuento_porcentaje),
    numero_socio: cliente.numero_socio === null ? '' : String(cliente.numero_socio),
    zona_cobertura: cliente.zona_cobertura ?? '',
    nro_habilitacion: cliente.nro_habilitacion ?? '',
    pais_destino_principal: cliente.pais_destino_principal ?? '',
  }
}

export function ClienteForm({
  cliente,
  localidades,
  saving,
  onCancel,
  onSubmit,
}: ClienteFormProps) {
  const [values, setValues] = useState(() => valoresIniciales(cliente))

  useEffect(() => {
    setValues(valoresIniciales(cliente))
  }, [cliente])

  function update<K extends keyof ClienteFormValues>(key: K, value: ClienteFormValues[K]) {
    setValues((current) => ({ ...current, [key]: value }))
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    onSubmit(values)
  }

  return (
    <form className="card client-form" onSubmit={submit}>
      <div className="card-heading">
        <div>
          <p className="eyebrow">{cliente ? 'Edición' : 'Alta'}</p>
          <h2>{cliente ? `Cliente ${cliente.id_cliente}` : 'Nuevo cliente'}</h2>
        </div>
      </div>

      <div className="form-grid">
        <label>
          Apellido / razón social
          <input
            value={values.apellido}
            onChange={(event) => update('apellido', event.target.value)}
            maxLength={50}
            required
          />
        </label>
        <label>
          Nombre
          <input
            value={values.nombre}
            onChange={(event) => update('nombre', event.target.value)}
            maxLength={50}
          />
        </label>
        <label>
          CUIT
          <input
            value={values.cuit}
            onChange={(event) => update('cuit', event.target.value)}
            inputMode="numeric"
            pattern="[0-9]{11}"
            title="Ingresá 11 dígitos, sin guiones"
            maxLength={11}
            required
          />
        </label>
        <label>
          Tipo de cliente
          <select
            value={values.tipo_cliente}
            onChange={(event) => {
              if (esTipoCliente(event.target.value)) update('tipo_cliente', event.target.value)
            }}
          >
            {tipoClientes.map((tipo) => (
              <option key={tipo} value={tipo}>
                {tipo}
              </option>
            ))}
          </select>
        </label>
        <label>
          Tipo de documento
          <input
            value={values.tipo_documento}
            onChange={(event) => update('tipo_documento', event.target.value)}
            maxLength={50}
            required
          />
        </label>
        <label>
          Número de documento
          <input
            value={values.nro_documento}
            onChange={(event) => update('nro_documento', event.target.value)}
            maxLength={50}
            required
          />
        </label>
        <label>
          Calle
          <input
            value={values.calle_cliente}
            onChange={(event) => update('calle_cliente', event.target.value)}
            maxLength={50}
            required
          />
        </label>
        <label>
          Número
          <input
            type="number"
            min="0"
            value={values.nro_calle_cliente}
            onChange={(event) => update('nro_calle_cliente', event.target.value)}
            required
          />
        </label>
        <label>
          Localidad
          <select
            value={values.id_localidad}
            onChange={(event) => update('id_localidad', event.target.value)}
            required
          >
            <option value="">Seleccionar localidad</option>
            {localidades.map((localidad) => (
              <option key={localidad.id_localidad} value={localidad.id_localidad}>
                {localidad.nombre}, {localidad.provincia}
              </option>
            ))}
          </select>
        </label>
        <label>
          Fecha de alta
          <input
            type="date"
            value={values.fecha_alta}
            onChange={(event) => update('fecha_alta', event.target.value)}
            required
          />
        </label>
        <label>
          Descuento (%)
          <input
            type="number"
            min="0"
            max="100"
            step="0.01"
            value={values.descuento_porcentaje}
            onChange={(event) => update('descuento_porcentaje', event.target.value)}
            required
          />
        </label>
      </div>

      <fieldset className="subtype-fields">
        <legend>Datos del subtipo: {values.tipo_cliente}</legend>
        {values.tipo_cliente === 'Socio' && (
          <label>
            Número de socio
            <input
              type="number"
              min="1"
              value={values.numero_socio}
              onChange={(event) => update('numero_socio', event.target.value)}
              required
            />
          </label>
        )}
        {values.tipo_cliente === 'Distribuidor' && (
          <div className="form-grid">
            <label>
              Zona de cobertura
              <input
                value={values.zona_cobertura}
                onChange={(event) => update('zona_cobertura', event.target.value)}
                maxLength={50}
                required
              />
            </label>
            <label>
              Número de habilitación
              <input
                value={values.nro_habilitacion}
                onChange={(event) => update('nro_habilitacion', event.target.value)}
                maxLength={50}
                required
              />
            </label>
          </div>
        )}
        {values.tipo_cliente === 'Exportador' && (
          <label>
            País de destino principal
            <input
              value={values.pais_destino_principal}
              onChange={(event) => update('pais_destino_principal', event.target.value)}
              maxLength={50}
              required
            />
          </label>
        )}
      </fieldset>

      <div className="form-actions">
        <button className="button" type="submit" disabled={saving}>
          {saving ? 'Guardando...' : cliente ? 'Guardar cambios' : 'Crear cliente'}
        </button>
        <button className="button secondary" type="button" onClick={onCancel} disabled={saving}>
          Cancelar
        </button>
      </div>
    </form>
  )
}
