import { endpoint, body, uuid, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
import { validSymbol } from '../lib/market.js';
export const POST = endpoint('POST', async request => {
  const { authorization } = await authenticated(request);
  const b = await body(request);
  requireInput(uuid(b.requestId) && ['buy', 'sell'].includes(b.side) && validSymbol(b.symbol)
    && Number.isSafeInteger(b.units) && b.units > 0 && b.units <= 100000 && uuid(b.quoteId));
  return rpc('place_trade', { p_request: b.requestId, p_symbol: b.symbol, p_side: b.side, p_units: b.units, p_quote: b.quoteId }, authorization);
});
