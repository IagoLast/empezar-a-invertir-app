import { APIError } from './http.js';
import { alphaSearch, alphaEnabled } from './alpha-vantage.js';
import { providerQuote } from './providers.js';
import { finnhubSearch, logoURL } from './finnhub.js';

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
export function createSearchService({ primary = finnhubSearch, secondary = alphaSearch, enabled = alphaEnabled } = {}) {
  return cachedLoader(async query => {
    const useAlpha = enabled() && query.length >= 3;
    const [first, second] = await Promise.allSettled([primary(query), useAlpha ? secondary(query) : Promise.resolve([])]);
    if (first.status === 'rejected' && (!useAlpha || second.status === 'rejected')) throw first.reason instanceof APIError ? first.reason : new APIError(503, 'SEARCH_UNAVAILABLE', 'No podemos buscar ahora. Vuelve a intentarlo.');
    const results = first.status === 'fulfilled' ? normalizeSearch(first.value).map(row => ({...row, source:'Finnhub'})) : [];
    if (second.status === 'fulfilled') for (const row of second.value) if (!results.some(existing => existing.symbol === row.symbol)) results.push(row);
    return { results, partial: first.status === 'rejected' || (useAlpha && second.status === 'rejected'),
      notice: first.status === 'rejected' || (useAlpha && second.status === 'rejected') ? 'Una fuente no está disponible temporalmente. Mostramos los resultados de la otra.' : null };
  });
}
export const searchMarkets = createSearchService();
export const previewMarket = cachedLoader(async symbol => {
  try {
    const raw = await providerQuote(symbol);
    if (raw.symbol !== symbol || !Number.isFinite(raw.regularMarketPrice) || raw.regularMarketPrice <= 0
      || typeof raw.currency !== 'string' || !(raw.regularMarketTime instanceof Date)
      || !Number.isFinite(raw.regularMarketTime.getTime())) throw Error();
    return { symbol, price: raw.regularMarketPrice, currency: raw.currency,
      changePercent: Number.isFinite(raw.regularMarketChangePercent) ? raw.regularMarketChangePercent : null,
      asOf: raw.regularMarketTime.toISOString(), source: raw.source || 'Finnhub', logoURL: logoURL(raw.logoUrl) };
  } catch (error) { if (error instanceof APIError) throw error; throw new APIError(503, 'MARKET_UNAVAILABLE', 'No podemos consultar este precio ahora.'); }
});
