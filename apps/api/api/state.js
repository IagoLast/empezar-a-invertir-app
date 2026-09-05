import { endpoint } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
export const GET = endpoint('GET', async request => {
  const { authorization } = await authenticated(request);
  return rpc('get_state', {}, authorization);
});
