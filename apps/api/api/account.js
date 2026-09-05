import { endpoint } from '../lib/http.js';
import { authenticated, config } from '../lib/supabase.js';
export const DELETE = endpoint('DELETE', async request => {
  const { user } = await authenticated(request);
  const key = config('SUPABASE_SERVICE_ROLE_KEY');
  const result = await fetch(`${config('SUPABASE_URL')}/auth/v1/admin/users/${user.id}`, {
    method: 'DELETE', headers: { apikey: key, Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(10000)
  });
  if (!result.ok) throw new Error('Deletion unavailable');
  return { deleted: true };
});
