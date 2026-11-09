import type { ReactNode } from 'react'

export function ErrorBanner({ message }: { message: string | null }) {
  if (!message) return null
  return (
    <div className="error-banner" role="alert">
      <strong>Error de la API</strong>
      <span>{message}</span>
    </div>
  )
}

export function SuccessBanner({ message }: { message: string | null }) {
  if (!message) return null
  return (
    <div className="success-banner" role="status">
      {message}
    </div>
  )
}

export function Loading({ label = 'Cargando...' }: { label?: string }) {
  return (
    <div className="loading" role="status">
      <span className="spinner" aria-hidden="true" />
      {label}
    </div>
  )
}

export function EmptyState({ children }: { children: ReactNode }) {
  return <div className="empty-state">{children}</div>
}
