import { APIError } from './http.js';

export const eodhdEnabled = () => Boolean(process.env.EODHD_API_KEY);
const failure = (code = 'MARKET_UNAVAILABLE') => new APIError(code === 'MARKET_NOT_COVERED' ? 422 : 503, code,
  'No podemos obtener este dato de mercado ahora. Desliza hacia abajo para volver a intentarlo.');
// Canonical symbols preserve the listing, not just the company (ISIN can span exchanges).
const exchanges = { US: '', MC: 'MC', LSE: 'L', XETRA: 'DE', F: 'F', PA: 'PA', AS: 'AS', MI: 'MI',
  SW: 'SW', VI: 'VI', WAR: 'WA', TO: 'TO', V: 'V', AU: 'AX', HK: 'HK', SHG: 'SS', SHE: 'SZ',
  ST: 'ST', HE: 'HE', CO: 'CO', OL: 'OL', LS: 'LS', BR: 'BR', IR: 'IR' };
const safeSymbol = value => typeof value === 'string' && /^[A-Z0-9][A-Z0-9.-]{0,19}$/.test(value);
export function canonicalEodhdSymbol(code, exchange) {
  if (!safeSymbol(code) || !Object.hasOwn(exchanges, exchange)) return null;
  // EODHD represents US share classes with a hyphen; the existing catalog uses a dot.
  const symbol = exchange === 'US' ? code.replace(/-([AB])$/, '.$1') : `${code}.${exchanges[exchange]}`;
  return safeSymbol(symbol) ? symbol : null;
}
export function eodhdSymbol(symbol) {
  if (/^[A-Z]{3}USD=X$/.test(symbol)) return `${symbol.slice(0,6)}.FOREX`;
  if (!safeSymbol(symbol)) throw failure('MARKET_NOT_COVERED');
  if (!symbol.includes('.') || /\.[AB]$/.test(symbol)) return `${symbol.replace(/\.([AB])$/, '-$1')}.US`;
  const suffix = symbol.split('.').at(-1);
  const exchange = Object.keys(exchanges).find(key => exchanges[key] === suffix);
  if (!exchange) throw failure('MARKET_NOT_COVERED');
  return `${symbol.slice(0, -suffix.length)}${exchange}`;
}
export function createEodhdClient({ fetcher = fetch, key = () => process.env.EODHD_API_KEY, clock = Date.now } = {}) {
  const cache = new Map();
  return async (path, parameters = {}, ttl = 60000) => {
    if (!key()) throw failure();
    const cacheKey = path + '?' + new URLSearchParams(parameters);
    const old = cache.get(cacheKey);
    if (old?.until > clock()) return old.promise;
    const promise = (async () => {
      try {
        const url = new URL(`https://eodhd.com/api/${path}`);
        url.search = new URLSearchParams({ ...parameters, api_token: key(), fmt: 'json' });
        const response = await fetcher(url, { signal: AbortSignal.timeout(8000) });
        if ([401,403,404].includes(response.status)) throw failure('MARKET_NOT_COVERED');
        if (response.status === 429) throw failure('MARKET_RATE_LIMIT');
        if (!response.ok) throw failure();
        const data = await response.json();
        if (!data || data.error || data.message) throw failure();
        return data;
      } catch (error) {
        // Fetch/JSON errors can include the URL and its token; never propagate them.
        throw failure(error instanceof APIError ? error.code : undefined);
      }
    })();
    if (cache.size >= 300) cache.delete(cache.keys().next().value);
    const entry = { promise, until: clock() + ttl };
    cache.set(cacheKey, entry);
    try { return await promise; }
    catch (error) { if (cache.get(cacheKey) === entry) cache.delete(cacheKey); throw error; }
  };
}
export const eodhdRequest = createEodhdClient();
export function normalizeEodhdSearch(data) {
  if (!Array.isArray(data)) throw failure();
  return data.flatMap(row => {
    const symbol = canonicalEodhdSymbol(row.Code, row.Exchange);
    if (!symbol || !['Common Stock','ETF','Preferred Stock'].includes(row.Type)
      || !/^(?:[A-Z]{3}|GBp|ZAc)$/.test(row.Currency || '')) return [];
    return [{ symbol, name: row.Name || symbol, kind: row.Type === 'ETF' ? 'etf' : 'stock',
      exchange: row.Exchange === 'US' ? 'EE. UU.' : row.Exchange === 'MC' ? 'Madrid' : row.Exchange,
      currency: row.Currency, source: 'EODHD' }];
  });
}
export function createEodhdMarket({ request = eodhdRequest, clock = Date.now } = {}) {
  const search = async query => normalizeEodhdSearch(await request(`search/${encodeURIComponent(query)}`, { limit: '30' }, 15*60000));
  const assetInfo = async symbol => {
    const rows = await search(eodhdSymbol(symbol));
    const asset = rows.find(row => row.symbol === symbol);
    if (!asset) throw failure('MARKET_NOT_COVERED');
    return asset;
  };
  const daily = async (symbol, days, interval = '1d') => {
    const data = await request(`eod/${encodeURIComponent(eodhdSymbol(symbol))}`, {
      from: new Date(clock()-days*86400000).toISOString().slice(0,10),
      to: new Date(clock()).toISOString().slice(0,10), period: interval === '1wk' ? 'w' : 'd', order: 'd',
    }, 3600000);
    if (!Array.isArray(data) || !data.length) throw failure('MARKET_NOT_COVERED');
    return data;
  };
  return {
    search,
    async quote(symbol) {
      const code = eodhdSymbol(symbol), fx = symbol.endsWith('=X');
      const asset = fx ? null : await assetInfo(symbol);
      let quote;
      try {
        const row = await request(`real-time/${encodeURIComponent(code)}`);
        if (row.code !== code || !Number.isFinite(row.close) || row.close <= 0 || !Number.isFinite(row.timestamp)
          || row.timestamp*1000 < clock()-7*86400000 || row.timestamp*1000 > clock()+60000
          || (!fx && !Number.isFinite(row.change_p))) throw failure();
        quote = { regularMarketPrice: row.close, regularMarketTime: new Date(row.timestamp*1000), regularMarketChangePercent: row.change_p };
      } catch {
        const rows = await daily(symbol, 14);
        const [row, previous] = rows;
        if (!/^\d{4}-\d{2}-\d{2}$/.test(row.date) || !Number.isFinite(row.close) || row.close <= 0
          || (!fx && (!Number.isFinite(previous?.close) || previous.close <= 0))) throw failure();
        quote = { regularMarketPrice: row.close, regularMarketTime: new Date(`${row.date}T00:00:00Z`),
          regularMarketChangePercent: previous ? (row.close/previous.close-1)*100 : 0, mode: 'eod' };
      }
      // The delayed endpoint does not establish whether an exchange is currently open.
      return { ...quote, symbol, source: 'EODHD', currency: asset?.currency || 'USD', marketState: 'CLOSED',
        quoteType: asset?.kind === 'etf' ? 'ETF' : 'EQUITY', longName: asset?.name };
    },
    async history(symbol, { days, interval }) {
      const asset = await assetInfo(symbol);
      const rows = await daily(symbol, days, interval);
      const minor = { GBX:'GBP', GBp:'GBP', ILA:'ILS', ZAc:'ZAR' }, scale = minor[asset.currency] ? 0.01 : 1;
      return { meta: { symbol, currency: minor[asset.currency] || asset.currency, source:'EODHD', interval:interval === '1wk' ? '1wk' : '1d' },
        quotes: rows.map(row => ({ date: new Date(`${row.date}T00:00:00Z`),
          open:row.open*scale, high:row.high*scale, low:row.low*scale, close:row.close*scale })) };
    },
  };
}
const market = createEodhdMarket();
export const eodhdSearch = market.search;
export const eodhdQuote = market.quote;
export const eodhdHistory = market.history;
