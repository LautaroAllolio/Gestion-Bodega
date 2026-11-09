interface PaginationProps {
  page: number
  limit: number
  total: number
  onChange: (page: number) => void
}

export function Pagination({ page, limit, total, onChange }: PaginationProps) {
  const totalPages = Math.max(1, Math.ceil(total / limit))
  if (totalPages <= 1) {
    return <p className="pagination-summary">{total} registros</p>
  }
  return (
    <div className="pagination">
      <button
        type="button"
        className="button secondary"
        onClick={() => onChange(page - 1)}
        disabled={page <= 1}
      >
        Anterior
      </button>
      <span>
        Página {page} de {totalPages} · {total} registros
      </span>
      <button
        type="button"
        className="button secondary"
        onClick={() => onChange(page + 1)}
        disabled={page >= totalPages}
      >
        Siguiente
      </button>
    </div>
  )
}
