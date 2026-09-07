import { endpoint, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
import { normalizeFundamentals } from '../lib/market.js';
import { finnhubMetrics } from '../lib/finnhub.js';
export const GET = endpoint('GET', async request => {
  await authenticated(request);
  const symbol = new URL(request.url).searchParams.get('symbol');
  requireInput(['AAPL', 'MSFT'].includes(symbol));
  if (process.env.ENABLE_FUNDAMENTALS === 'false') return { available: false };
  const cached = await rpc('fundamentals_cache', { p_symbol: symbol }, null, true);
  if (!cached.refresh && cached.data?.source === 'Finnhub') return cached.data;
  try {
    const data = normalizeFundamentals({ symbol, currency: 'USD', trailingPE: (await finnhubMetrics(symbol)).metric?.peTTM, epsTrailingTwelveMonths: (await finnhubMetrics(symbol)).metric?.epsTTM }, symbol);
    await rpc('save_fundamentals', { p_symbol: symbol, p_data: data }, null, true);
    return data;
  } catch { return cached.data?.source === 'Finnhub' ? cached.data : { available: false }; }
});
