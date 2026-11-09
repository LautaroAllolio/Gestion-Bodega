export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? '/api'

export class ApiError extends Error {
  readonly status: number
  readonly sqlstate: string | null

  constructor(message: string, status: number, sqlstate: string | null = null) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.sqlstate = sqlstate
  }
}

type QueryValue = string | number | boolean | null | undefined

export function withQuery<T extends object>(path: string, params: T = {} as T): string {
  const search = new URLSearchParams()
  for (const [key, value] of Object.entries(params) as Array<[string, QueryValue]>) {
    if (value !== undefined && value !== null && value !== '') {
      search.set(key, String(value))
    }
  }
  const query = search.toString()
  return query ? `${path}?${query}` : path
}

export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)
  if (init.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json')
  }

  let response: Response
  try {
    response = await fetch(`${API_BASE_URL}${path}`, { ...init, headers })
  } catch {
    throw new ApiError('No se pudo conectar con la API', 0)
  }

  if (response.status === 204) {
    return undefined as T
  }

  const text = await response.text()
  let body: unknown = null
  if (text) {
    try {
      body = JSON.parse(text)
    } catch {
      body = text
    }
  }

  if (!response.ok) {
    const payload = body as { detail?: unknown; sqlstate?: unknown } | null
    const detail =
      payload && typeof payload === 'object' && 'detail' in payload
        ? String(payload.detail)
        : typeof body === 'string' && body
          ? body
          : `Error HTTP ${response.status}`
    const sqlstate =
      payload && typeof payload === 'object' && 'sqlstate' in payload
        ? String(payload.sqlstate)
        : null
    throw new ApiError(detail, response.status, sqlstate)
  }

  return body as T
}
