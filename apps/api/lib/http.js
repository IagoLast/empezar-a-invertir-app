export class APIError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
export const json = (value, status = 200) => Response.json(value, { status, headers: { 'Cache-Control': 'no-store' } });
export function endpoint(method, fn) {
  return async request => {
    if (request.method !== method) return json({ error: 'METHOD_NOT_ALLOWED', message: 'Método no permitido.' }, 405);
    try { return json(await fn(request)); }
    catch (error) {
      if (error instanceof APIError) return json({ error: error.code, message: error.message }, error.status);
      // Do not log tokens, user data or purchase payloads.
      console.error('API failure', error.name);
      return json({ error: 'UNAVAILABLE', message: 'No hemos podido conectar. Inténtalo de nuevo.' }, 503);
    }
  };
}
export async function body(request) {
  const raw = await request.text();
  if (raw.length > 16384) throw new APIError(413, 'TOO_LARGE', 'Petición demasiado grande.');
  try {
    const value = JSON.parse(raw);
    if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error();
    return value;
  } catch { throw new APIError(400, 'INVALID_BODY', 'Datos no válidos.'); }
}
export function uuid(value) {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
export function requireInput(ok) {
  if (!ok) throw new APIError(400, 'INVALID_INPUT', 'Revisa los datos de la operación.');
}
