import { endpoint, requireInput } from '../lib/http.js';
import { authenticated, rpc } from '../lib/supabase.js';
import { provider } from '../lib/market.js';
export const GET = endpoint('GET', async request => {
  await authenticated(request);
  const symbol = new URL(request.url).searchParams.get('symbol');
  requireInput(['AAPL', 'MSFT'].includes(symbol));
  if (process.env.ENABLE_FUNDAMENTALS !== 'true') return { available: false };
  const cached = await rpc('fundamentals_cache', { p_symbol: symbol }, null, true);
  if (!cached.refresh) return cached.data || { available: false };
  try {
    const result = await provider('statistics', symbol);
    const s = result.statistics;
    const pe = s?.valuations_metrics?.trailing_pe ?? s?.valuation_metrics?.price_to_earnings;
    const eps = s?.financials?.income_statement?.diluted_eps_ttm;
    const number = v => v !== null && v !== undefined && Number.isFinite(Number(v)) ? Number(v) : null;
    const data = { available: true, symbol, pe: number(pe), eps: number(eps), source: 'Twelve Data', fetchedAt: new Date().toISOString() };
    await rpc('save_fundamentals', { p_symbol: symbol, p_data: data }, null, true);
    return data;
  } catch { return cached.data || { available: false }; }
});
