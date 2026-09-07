import { APIError } from './http.js';
import { yahooSearch, yahooQuote, logoURL } from './yahoo.js';

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
  return (raw.quotes || []).filter(q => q.isYahooFinance && ['EQUITY', 'ETF'].includes(q.quoteType)
    && typeof q.symbol === 'string' && /^[A-Z0-9][A-Z0-9.^=-]{0,19}$/.test(q.symbol)
    && !seen.has(q.symbol) && seen.add(q.symbol)).map(q => ({
      symbol: q.symbol, name: q.longname || q.shortname || q.symbol,
      kind: q.quoteType === 'ETF' ? 'etf' : 'stock', exchange: q.exchDisp || q.exchange || '',
    }));
}
export const searchMarkets = cachedLoader(async query => {
  try { return { results: normalizeSearch(await yahooSearch(query)) }; }
  catch { throw new APIError(503, 'SEARCH_UNAVAILABLE', 'No podemos buscar ahora. Vuelve a intentarlo.'); }
});
export const previewMarket = cachedLoader(async symbol => {
  try {
    const raw = await yahooQuote(symbol);
    if (raw.symbol !== symbol || !Number.isFinite(raw.regularMarketPrice) || raw.regularMarketPrice <= 0
      || typeof raw.currency !== 'string' || !(raw.regularMarketTime instanceof Date)
      || !Number.isFinite(raw.regularMarketTime.getTime())) throw Error();
    return { symbol, price: raw.regularMarketPrice, currency: raw.currency,
      changePercent: Number.isFinite(raw.regularMarketChangePercent) ? raw.regularMarketChangePercent : null,
      asOf: raw.regularMarketTime.toISOString(), source: 'Yahoo Finance', logoURL: logoURL(raw.logoUrl) };
  } catch { throw new APIError(503, 'MARKET_UNAVAILABLE', 'No podemos consultar este precio ahora.'); }
});
