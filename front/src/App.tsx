import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { Layout } from './components/Layout'
import { CatalogosProvider } from './context/CatalogosContext'
import { CatalogoPage } from './pages/CatalogoPage'
import { NuevaVentaPage } from './pages/NuevaVentaPage'
import { TableroPage } from './pages/TableroPage'
import { TransferenciasPage } from './pages/TransferenciasPage'
import { VinoFormPage } from './pages/VinoFormPage'

export function App() {
  return (
    <BrowserRouter>
      <CatalogosProvider>
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<Navigate to="/vinos" replace />} />
            <Route path="/vinos" element={<CatalogoPage />} />
            <Route path="/vinos/nuevo" element={<VinoFormPage />} />
            <Route path="/vinos/:codigo/editar" element={<VinoFormPage />} />
            <Route path="/ventas/nueva" element={<NuevaVentaPage />} />
            <Route path="/transferencias" element={<TransferenciasPage />} />
            <Route path="/tablero" element={<TableroPage />} />
            <Route
              path="*"
              element={
                <section className="page">
                  <h1>Página no encontrada</h1>
                  <p>La ruta solicitada no existe.</p>
                </section>
              }
            />
          </Route>
        </Routes>
      </CatalogosProvider>
    </BrowserRouter>
  )
}
