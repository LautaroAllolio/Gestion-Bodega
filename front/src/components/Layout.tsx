import { NavLink, Outlet } from 'react-router-dom'

const links = [
  { to: '/vinos', label: 'Catálogo' },
  { to: '/vinos/nuevo', label: 'Nuevo vino' },
  { to: '/ventas/nueva', label: 'Nueva venta' },
  { to: '/transferencias', label: 'Transferencias' },
  { to: '/tablero', label: 'Tablero' },
]

export function Layout() {
  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="brand">
          <span className="brand-mark">BA</span>
          <div>
            <strong>Bodegas del Atuel</strong>
            <small>Gestión de vinos, ventas y stock</small>
          </div>
        </div>
        <nav className="main-nav" aria-label="Navegación principal">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === '/vinos'}
              className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')}
            >
              {link.label}
            </NavLink>
          ))}
        </nav>
      </header>
      <main className="app-main">
        <Outlet />
      </main>
      <footer className="app-footer">
        Base de Datos · UTN FRSR 2026 · El front consume únicamente la API
      </footer>
    </div>
  )
}
