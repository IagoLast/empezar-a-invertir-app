import { endpoint, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
import { normalizeFundamentals } from '../lib/market.js';
import { yahooQuote } from '../lib/yahoo.js';
export const GET = endpoint('GET', async request => {
  await authenticated(request);
  const symbol = new URL(request.url).searchParams.get('symbol');
  requireInput(['AAPL', 'MSFT'].includes(symbol));
  if (process.env.ENABLE_FUNDAMENTALS === 'false') return { available: false };
  const cached = await rpc('fundamentals_cache', { p_symbol: symbol }, null, true);
  if (!cached.refresh) return cached.data || { available: false };
  try {
    const data = normalizeFundamentals(await yahooQuote(symbol), symbol);
    await rpc('save_fundamentals', { p_symbol: symbol, p_data: data }, null, true);
    return data;
  } catch { return cached.data || { available: false }; }
});
