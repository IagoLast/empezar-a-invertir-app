import { endpoint, requireInput } from '../lib/http.js';
import { authenticated } from '../lib/supabase.js';
import { getQuote, symbols } from '../lib/market.js';
export const GET = endpoint('GET', async request => {
  await authenticated(request);
  const symbol = new URL(request.url).searchParams.get('symbol');
  requireInput(symbols.has(symbol));
  return getQuote(symbol);
});
