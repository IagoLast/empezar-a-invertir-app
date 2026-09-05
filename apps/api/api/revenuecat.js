import { endpoint, body } from '../lib/http.js';
import { rpc } from '../lib/supabase.js';
import { validateEvent } from '../lib/revenuecat.js';
export const POST = endpoint('POST', async request => {
  const args = validateEvent(await body(request), request.headers.get('authorization'), process.env);
  if (!args) return { received: true, ignored: true };
  const result = await rpc('apply_purchase_event', args, null, true);
  return { received: true, ...result };
});
