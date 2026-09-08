import { canonicalAlphaSymbol } from './market-symbols.js';
import { eodhdSearch, eodhdEnabled } from './eodhd.js';
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
const exchangeNames = { MC: 'Madrid', L: 'Londres', DE: 'Xetra', F: 'Fráncfort', PA: 'París', AS: 'Ámsterdam',
  MI: 'Milán', SW: 'Suiza', VI: 'Viena', WA: 'Varsovia', T: 'Tokio', HK: 'Hong Kong', KS: 'Corea del Sur', KQ: 'Corea del Sur',
  TO: 'Toronto', V: 'TSX Venture', AX: 'Australia', SS: 'Shanghái', SZ: 'Shenzhen', NS: 'India', BO: 'Bombay',
  ST: 'Estocolmo', HE: 'Helsinki', CO: 'Copenhague', OL: 'Oslo', LS: 'Lisboa', BR: 'Bruselas' };
const searchAliases = { inditex: 'Industria de Diseno Textil' };
export function normalizeSearch(raw) {
  const seen = new Set();
  return (raw.result || []).filter(q => ['Common Stock', 'ETP', 'ADR', 'REIT'].includes(q.type)
    && typeof q.symbol === 'string' && /^[A-Z0-9][A-Z0-9.-]{0,19}$/.test(q.symbol)
    && !seen.has(q.symbol) && seen.add(q.symbol)).map(q => {
      const suffix = q.symbol.includes('.') && !/\.[AB]$/.test(q.symbol) ? q.symbol.split('.').at(-1) : null;
      return { symbol: q.symbol, name: q.description || q.symbol, kind: q.type === 'ETP' ? 'etf' : 'stock',
        exchange: suffix ? exchangeNames[suffix] || `Mercado internacional (${suffix})` : 'EE. UU.',
        quoteAvailability: suffix ? 'check_on_open' : 'unknown' };
    });
}
export function rankSearchResults(results, query) {
  const normalize = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  const term = normalize(query.trim());
  const score = row => normalize(row.symbol) === term ? 0
    : normalize(row.symbol).split('.')[0] === term ? 1
    : normalize(row.name || row.symbol) === term ? 2
    : normalize(row.name || row.symbol).startsWith(term) ? 3 : 4;
  return [...results].sort((a,b) => score(a)-score(b));
}
export function createSearchService({ primary = finnhubSearch, secondary = alphaSearch, enabled = alphaEnabled,
  additional = eodhdSearch, additionalEnabled = eodhdEnabled } = {}) {
  return cachedLoader(async query => {
    const term = searchAliases[query.toLowerCase()] || query;
    const attempts = [async () => normalizeSearch(await primary(term)).map(row => ({ ...row, source: 'Finnhub' }))];
    if (additionalEnabled()) attempts.push(() => additional(term));
    if (enabled() && query.length >= 3) attempts.push(() => secondary(term));
    const responses = await Promise.allSettled(attempts.map(load => Promise.resolve().then(load)));
    if (responses.every(row => row.status === 'rejected')) throw new APIError(503, 'SEARCH_UNAVAILABLE', 'No podemos buscar ahora. Vuelve a intentarlo.');
    const results = new Map();
    for (const response of responses) if (response.status === 'fulfilled') {
      for (const row of response.value) {
        const symbol = row.source === 'Alpha Vantage' ? canonicalAlphaSymbol(row.symbol) : row.symbol;
        if (!results.has(symbol)) results.set(symbol, { ...row, symbol });
      }
    }
    const partial = responses.some(row => row.status === 'rejected');
    return { results: rankSearchResults([...results.values()], query), partial,
      notice: partial ? 'Algunos resultados no están disponibles ahora.' : null };
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
