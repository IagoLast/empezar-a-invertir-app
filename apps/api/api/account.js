import { endpoint, APIError } from '../lib/http.js';
import { authenticated, config } from '../lib/supabase.js';
export const DELETE = endpoint('DELETE', async request => {
  const { user } = await authenticated(request);
  if (process.env.SUPABASE_DB_SCHEMA === 'ea_sandbox') throw new APIError(403, 'SANDBOX_ACCOUNT_DELETION_DISABLED', 'La cuenta es compartida con tu cartera habitual. No se puede eliminar desde el entorno de pruebas.');
  const key = config('SUPABASE_SERVICE_ROLE_KEY');
  const result = await fetch(`${config('SUPABASE_URL')}/auth/v1/admin/users/${user.id}`, {
    method: 'DELETE', headers: { apikey: key, Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(10000)
  });
  if (!result.ok) throw new Error('Deletion unavailable');
  return { deleted: true };
});
