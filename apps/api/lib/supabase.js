import { APIError } from './http.js';
export function config(key) {
  const value = process.env[key];
  if (!value || value.includes('REPLACE') || value.includes('YOUR_')) throw new Error('Missing configuration');
  return value;
}
export async function authenticated(request) {
  const authorization = request.headers.get('authorization') || '';
  if (!/^Bearer \S+$/i.test(authorization)) throw new APIError(401, 'UNAUTHORIZED', 'Inicia sesión para continuar.');
  const response = await fetch(`${config('SUPABASE_URL')}/auth/v1/user`, {
    headers: { apikey: config('SUPABASE_ANON_KEY'), Authorization: authorization }, signal: AbortSignal.timeout(8000)
  });
  if (response.status === 401 || response.status === 403) throw new APIError(401, 'UNAUTHORIZED', 'Vuelve a iniciar sesión.');
  if (!response.ok) throw new Error('Auth unavailable');
  const user = await response.json();
  if (!user.id || !user.email_confirmed_at || user.is_anonymous) throw new APIError(403, 'VERIFICATION_REQUIRED', 'Verifica tu correo para continuar.');
  return { user, authorization };
}
const messages = {
  INSUFFICIENT_CASH: [409, 'No tienes suficiente saldo virtual.'],
  INSUFFICIENT_UNITS: [409, 'No tienes suficientes unidades.'],
  STALE_QUOTE: [409, 'El precio ha caducado. Actualízalo y vuelve a confirmar.'],
  MARKET_CLOSED: [409, 'Mercado cerrado. Puedes operar cuando vuelva a abrir.'],
  QUOTE_UNAVAILABLE: [503, 'No hay una cotización reciente disponible.'],
  IDEMPOTENCY_CONFLICT: [409, 'Esta operación ya existe con otros datos.'],
  INVALID_INPUT: [400, 'Datos no válidos.'],
  UNAUTHORIZED: [401, 'Vuelve a iniciar sesión.']
};
export async function rpc(name, args, authorization, admin = false) {
  const key = config(admin ? 'SUPABASE_SERVICE_ROLE_KEY' : 'SUPABASE_ANON_KEY');
  const response = await fetch(`${config('SUPABASE_URL')}/rest/v1/rpc/${name}`, {
    method: 'POST', headers: { apikey: key, Authorization: authorization || `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(args), signal: AbortSignal.timeout(10000)
  });
  const data = await response.json();
  if (!response.ok) {
    const match = messages[data.message];
    if (match) throw new APIError(match[0], data.message, match[1]);
    throw new Error('Database unavailable');
  }
  return data;
}
