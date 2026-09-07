import { APIError } from './http.js';
import { finnhubSearch, finnhubQuote, logoURL } from './finnhub.js';

// Bounded per-instance cache for discovery; trading quotes keep their shared Postgres cache.
export function cachedLoader(load, { ttl = 15 * 60000, limit = 100, clock = Date.now } = {}) {
  const entries = new Map();
  return async key => {
    const existing = entries.get(key);
    if (existing && existing.until > clock()) return existing.promise;
    if (entries.size >= limit) entries.delete(entries.keys().next().value);
    const entry = { until: clock() + ttl, promise: Promise.resolve().then(() => load(key)) };
    entries.set(key, entry);
    try { return await entry.promise; }
    catch (error) { if (entries.get(key) === entry) entries.delete(key); throw error; }
  };
}
export function normalizeSearch(raw) {
  const seen = new Set();
  return (raw.result || []).filter(q => ['Common Stock', 'ETP', 'ADR', 'REIT'].includes(q.type)
    && typeof q.symbol === 'string' && /^[A-Z0-9][A-Z0-9-]{0,17}(?:\.[AB])?$/.test(q.symbol)
    && !seen.has(q.symbol) && seen.add(q.symbol)).map(q => ({
      symbol: q.symbol, name: q.description || q.symbol,
      kind: q.type === 'ETP' ? 'etf' : 'stock', exchange: 'US',
    }));
}
export const searchMarkets = cachedLoader(async query => {
  try { return { results: normalizeSearch(await finnhubSearch(query)) }; }
  catch (error) { if (error instanceof APIError) throw error; throw new APIError(503, 'SEARCH_UNAVAILABLE', 'No podemos buscar ahora. Vuelve a intentarlo.'); }
});
export const previewMarket = cachedLoader(async symbol => {
  try {
    const raw = await finnhubQuote(symbol);
    if (raw.symbol !== symbol || !Number.isFinite(raw.regularMarketPrice) || raw.regularMarketPrice <= 0
      || typeof raw.currency !== 'string' || !(raw.regularMarketTime instanceof Date)
      || !Number.isFinite(raw.regularMarketTime.getTime())) throw Error();
    return { symbol, price: raw.regularMarketPrice, currency: raw.currency,
      changePercent: Number.isFinite(raw.regularMarketChangePercent) ? raw.regularMarketChangePercent : null,
      asOf: raw.regularMarketTime.toISOString(), source: 'Finnhub', logoURL: logoURL(raw.logoUrl) };
  } catch (error) { if (error instanceof APIError) throw error; throw new APIError(503, 'MARKET_UNAVAILABLE', 'No podemos consultar este precio ahora.'); }
});
