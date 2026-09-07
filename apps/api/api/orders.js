import { endpoint, body, uuid, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
import { validSymbol } from '../lib/market.js';
export const POST = endpoint('POST', async request => {
  const { authorization } = await authenticated(request);
  const b = await body(request);
  requireInput(uuid(b.requestId) && ['buy', 'sell'].includes(b.side) && validSymbol(b.symbol)
    && Number.isSafeInteger(b.units) && b.units > 0 && b.units <= 100000 && uuid(b.quoteId)
    && (b.limitCents == null || (Number.isSafeInteger(b.limitCents) && b.limitCents > 0 && b.limitCents <= 1000000000))
    && (b.revision == null || (Number.isSafeInteger(b.revision) && b.revision > 0)));
  return rpc('submit_simulated_order', { p_request: b.requestId, p_symbol: b.symbol, p_side: b.side,
    p_units: b.units, p_quote: b.quoteId, p_limit: b.limitCents ?? null, p_revision: b.revision ?? null }, authorization);
});
export const DELETE = endpoint('DELETE', async request => {
  const { authorization } = await authenticated(request);
  const b = await body(request);
  requireInput(uuid(b.requestId) && Number.isSafeInteger(b.revision) && b.revision > 0);
  return rpc('cancel_simulated_order', { p_request: b.requestId, p_revision: b.revision }, authorization);
});
