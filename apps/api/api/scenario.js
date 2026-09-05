import { endpoint, body, uuid, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
export const POST = endpoint('POST', async request => {
  const { authorization } = await authenticated(request);
  const b = await body(request);
  requireInput(uuid(b.requestId) && Number.isInteger(b.step) && b.step >= 0 && b.step < 4);
  return rpc('advance_scenario', { p_request: b.requestId, p_step: b.step }, authorization);
});
