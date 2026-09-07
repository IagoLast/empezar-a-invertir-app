import { APIError } from './http.js';

const cache = new Map();
const pending = new Map();
export function createFinnhubClient({ fetcher = fetch, key = () => process.env.FINNHUB_API_KEY } = {}) {
  return async function request(path, parameters = {}) {
    if (!key()) throw new APIError(503, 'MARKET_UNAVAILABLE', 'El servicio de precios no está configurado.');
    const url = new URL(`https://finnhub.io/api/v1/${path}`);
    url.search = new URLSearchParams(parameters).toString();
    let response;
    try { response = await fetcher(url, { headers: { 'X-Finnhub-Token': key() }, signal: AbortSignal.timeout(8000) }); }
    catch { throw new APIError(503, 'MARKET_UNAVAILABLE', 'No podemos conectar con el servicio de precios.'); }
    if (response.status === 403) throw new APIError(422, 'MARKET_NOT_COVERED', 'Este dato no está disponible con la cobertura actual de mercado.');
    if (response.status === 429) throw new APIError(503, 'MARKET_RATE_LIMIT', 'El servicio de precios está ocupado. Inténtalo en un minuto.');
    if (!response.ok) throw new APIError(503, 'MARKET_UNAVAILABLE', 'El servicio de precios no responde.');
    const data = await response.json();
    if (!data || data.error) throw new APIError(503, 'MARKET_UNAVAILABLE', 'No hemos podido obtener este dato de mercado.');
    return data;
  };
}
export const finnhubRequest = createFinnhubClient();
async function cached(key, ttl, load) {
  const old = cache.get(key);
  if (old?.until > Date.now()) return old.value;
  if (pending.has(key)) return pending.get(key);
  const task = load().then(value => {
    if (cache.size >= 300) cache.delete(cache.keys().next().value);
    cache.set(key, { value, until: Date.now() + ttl }); return value;
  }).finally(() => pending.delete(key));
  pending.set(key, task); return task;
}
export function logoURL(value) {
  try { const url = new URL(value); return url.protocol === 'https:' && ['static.finnhub.io', 'static2.finnhub.io'].includes(url.hostname) ? url.href : null; }
  catch { return null; }
}
export const finnhubSearch = query => cached(`search:${query}`, 15 * 60000, () => finnhubRequest('search', { q: query }));
export const finnhubMetrics = symbol => cached(`metric:${symbol}`, 86400000, () => finnhubRequest('stock/metric', { symbol, metric: 'all' }));
export async function finnhubQuote(symbol) {
  return cached(`quote:${symbol}`, 60000, async () => {
    const [quote, profile, search, status, financials] = await Promise.all([
      finnhubRequest('quote', { symbol }),
      cached(`profile:${symbol}`, 86400000, () => finnhubRequest('stock/profile2', { symbol })).catch(() => ({})),
      finnhubSearch(symbol),
      cached('status:US', 60000, () => finnhubRequest('stock/market-status', { exchange: 'US' })),
      finnhubMetrics(symbol).catch(() => ({})),
    ]);
    const asset = search.result?.find(row => row.symbol === symbol);
    if (!asset || !['Common Stock', 'ETP', 'ADR', 'REIT'].includes(asset.type)) throw new APIError(422, 'ASSET_UNSUPPORTED', 'Solo puedes practicar con acciones y ETF disponibles.');
    // This subscription supplies US quotes. Never infer FX rates or rename foreign symbols.
    if ((symbol.includes('.') && !/\.[AB]$/.test(symbol)) || (profile.currency && profile.currency !== 'USD')) throw new APIError(422, 'MARKET_NOT_COVERED', 'Este mercado no está incluido. Busca una acción o ETF de Estados Unidos.');
    const average = financials.metric?.['10DayAverageTradingVolume'] ?? financials.metric?.['3MonthAverageTradingVolume'];
    return { symbol, currency: 'USD', regularMarketPrice: quote.c, regularMarketChangePercent: quote.dp,
      regularMarketTime: new Date(quote.t * 1000), marketState: status.isOpen === true ? 'REGULAR' : 'CLOSED',
      quoteType: asset.type === 'ETP' ? 'ETF' : 'EQUITY', longName: profile.name || asset.description,
      logoUrl: logoURL(profile.logo), averageDailyVolume: Number.isFinite(average) && average > 0 ? Math.round(average * 1e6) : null };
  });
}
export async function finnhubHistory(symbol, { days, interval }) {
  const to = Math.floor(Date.now() / 1000);
  const result = await finnhubRequest('stock/candle', { symbol, resolution: { '1h': '60', '1d': 'D', '1wk': 'W' }[interval], from: to - days * 86400, to });
  if (result.s !== 'ok' || !Array.isArray(result.t)) throw new APIError(422, 'HISTORY_UNAVAILABLE', 'No hay histórico disponible para este activo.');
  return { meta: { symbol, currency: 'USD' }, quotes: result.t.map((t, i) => ({ date: new Date(t * 1000), open: result.o?.[i], high: result.h?.[i], low: result.l?.[i], close: result.c?.[i] })) };
}
