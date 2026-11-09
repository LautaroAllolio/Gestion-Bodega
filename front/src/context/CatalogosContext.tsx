import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { api } from '../api/endpoints'
import type { Bodega, Cepa, Deposito, Maridaje, Sala } from '../api/types'
import { getErrorMessage } from '../lib/format'

interface Catalogos {
  bodegas: Bodega[]
  cepas: Cepa[]
  maridajes: Maridaje[]
  salas: Sala[]
  depositos: Deposito[]
  loading: boolean
  error: string | null
  recargar: () => Promise<void>
}

const CatalogosContext = createContext<Catalogos | null>(null)

export function CatalogosProvider({ children }: { children: ReactNode }) {
  const [bodegas, setBodegas] = useState<Bodega[]>([])
  const [cepas, setCepas] = useState<Cepa[]>([])
  const [maridajes, setMaridajes] = useState<Maridaje[]>([])
  const [salas, setSalas] = useState<Sala[]>([])
  const [depositos, setDepositos] = useState<Deposito[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function recargar() {
    setLoading(true)
    setError(null)
    try {
      const [bodegasData, cepasData, maridajesData, salasData, depositosData] =
        await Promise.all([
          api.listBodegas(),
          api.listCepas(),
          api.listMaridajes(),
          api.listSalas(),
          api.listDepositos(),
        ])
      setBodegas(bodegasData)
      setCepas(cepasData)
      setMaridajes(maridajesData)
      setSalas(salasData)
      setDepositos(depositosData)
    } catch (err) {
      setError(getErrorMessage(err))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void recargar()
  }, [])

  return (
    <CatalogosContext.Provider
      value={{ bodegas, cepas, maridajes, salas, depositos, loading, error, recargar }}
    >
      {children}
    </CatalogosContext.Provider>
  )
}

export function useCatalogos(): Catalogos {
  const context = useContext(CatalogosContext)
  if (!context) {
    throw new Error('useCatalogos debe usarse dentro de CatalogosProvider')
  }
  return context
}
