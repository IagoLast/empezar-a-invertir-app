import { alphaSymbol } from './market-symbols.js';
import { setTimeout as sleep } from 'node:timers/promises';
import { APIError } from './http.js';
import { rpc } from './supabase.js';

const messages = {
  MARKET_RATE_LIMIT: 'Se ha alcanzado el límite temporal de Alpha Vantage. Los datos de Finnhub siguen disponibles.',
  MARKET_NOT_COVERED: 'Alpha Vantage no ofrece este dato con el plan actual.',
  MARKET_UNAVAILABLE: 'No hemos podido obtener este dato de Alpha Vantage.',
};
const failure = code => new APIError(code === 'MARKET_NOT_COVERED' ? 422 : 503, code, messages[code]);
export const alphaEnabled = () => Boolean(process.env.ALPHA_VANTAGE_API_KEY);
export function createAlphaClient({ database = rpc, fetcher = fetch, key = () => process.env.ALPHA_VANTAGE_API_KEY,
  wait = sleep, limit = () => Number(process.env.ALPHA_VANTAGE_DAILY_LIMIT || 25) } = {}) {
  return async (parameters, ttl = 86400) => {
    if (!key()) throw failure('MARKET_UNAVAILABLE');
    // Parameters contain no credentials. Identical requests share a persistent lease and result.
    const cacheKey = new URLSearchParams(Object.entries(parameters).sort()).toString();
    let reservation;
    for (let attempt = 0; attempt < 12; attempt++) {
      reservation = await database('reserve_alpha_request', { p_key: cacheKey, p_limit: limit() }, null, true);
      if (reservation.data !== undefined) {
        if (reservation.data.failure) throw failure(reservation.data.failure);
        return reservation.data;
      }
      if (reservation.limited) throw failure('MARKET_RATE_LIMIT');
      if (reservation.ticket) break;
      await wait(Math.min(1250, Math.max(100, reservation.waitMs || 500)));
    }
    if (!reservation.ticket) throw failure('MARKET_RATE_LIMIT');
    const save = (data, seconds) => database('save_alpha_response', { p_key: cacheKey, p_ticket: reservation.ticket, p_data: data, p_ttl: seconds }, null, true);
    let data;
    try {
      const url = new URL('https://www.alphavantage.co/query');
      url.search = new URLSearchParams({ ...parameters, apikey: key() });
      const response = await fetcher(url, { signal: AbortSignal.timeout(8000) });
      if (response.status === 429) throw failure('MARKET_RATE_LIMIT');
      if (!response.ok) throw failure('MARKET_UNAVAILABLE');
      data = await response.json();
      // Alpha Vantage reports quotas, premium gates and bad symbols inside HTTP 200 bodies.
      const notice = data?.Information || data?.Note;
      if (notice) throw failure(/rate limit|requests per|call frequency|call volume/i.test(notice) ? 'MARKET_RATE_LIMIT' : 'MARKET_NOT_COVERED');
      if (!data || data['Error Message']) throw failure('MARKET_NOT_COVERED');
    } catch (error) {
      const code = error instanceof APIError ? error.code : 'MARKET_UNAVAILABLE';
      await save({ failure: code }, code === 'MARKET_NOT_COVERED' ? 86400 : 60);
      throw failure(code); // Never propagate a fetch error containing the credential-bearing URL.
    }
    await save(data, ttl);
    return data;
  };
}
export const alphaRequest = createAlphaClient();
const safeSymbol = value => typeof value === 'string' && /^[A-Z0-9][A-Z0-9.-]{0,19}$/.test(value);
export function normalizeAlphaSearch(data) {
  if (!Array.isArray(data.bestMatches)) throw failure('MARKET_UNAVAILABLE');
  return data.bestMatches.filter(row => safeSymbol(row['1. symbol']) && ['Equity', 'ETF'].includes(row['3. type'])
    && /^[A-Z]{3}$/.test(row['8. currency'] || '')).map(row => ({
      symbol: row['1. symbol'], name: row['2. name'], kind: row['3. type'] === 'ETF' ? 'etf' : 'stock',
      exchange: row['4. region'], currency: row['8. currency'], source: 'Alpha Vantage',
    }));
}
export const alphaSearch = async query => normalizeAlphaSearch(await alphaRequest({ function: 'SYMBOL_SEARCH', keywords: query.toUpperCase() }, 604800));
async function assetInfo(symbol, request) {
  symbol = alphaSymbol(symbol);
  const results = normalizeAlphaSearch(await request({ function: 'SYMBOL_SEARCH', keywords: symbol }, 604800));
  const asset = results.find(row => row.symbol === symbol);
  if (!asset) throw failure('MARKET_NOT_COVERED');
  return asset;
}
function rows(data, symbol, weekly = false) {
  if (data['Meta Data']?.['2. Symbol'] !== symbol) throw failure('MARKET_NOT_COVERED');
  const series = data[weekly ? 'Weekly Time Series' : 'Time Series (Daily)'];
  if (!series || typeof series !== 'object') throw failure('MARKET_NOT_COVERED');
  const result = Object.entries(series).map(([date, row]) => ({
    date: new Date(`${date}T00:00:00Z`), open: Number(row['1. open']), high: Number(row['2. high']),
    low: Number(row['3. low']), close: Number(row['4. close']), volume: Number(row['5. volume']),
  })).filter(row => Number.isFinite(row.date.getTime()) && [row.open,row.high,row.low,row.close].every(n => Number.isFinite(n) && n > 0)
    && row.low <= Math.min(row.open,row.close) && row.high >= Math.max(row.open,row.close))
    .sort((a,b) => b.date - a.date);
  if (!result.length) throw failure('MARKET_NOT_COVERED');
  return result;
}
// Daily dates are session dates, represented at UTC midnight, never as live timestamps.
export function createAlphaMarket({ request = alphaRequest, clock = Date.now } = {}) {
  const daily = async symbol => {
    symbol = alphaSymbol(symbol);
    return rows(await request({ function: 'TIME_SERIES_DAILY', symbol }, 86400), symbol);
  };
  return {
    async quote(symbol) {
      if (/^[A-Z]{3}USD=X$/.test(symbol)) {
        const currency = symbol.slice(0,3);
        const data = await request({ function: 'CURRENCY_EXCHANGE_RATE', from_currency: currency, to_currency: 'USD' }, 3600);
        const fx = data['Realtime Currency Exchange Rate'];
        if (fx?.['1. From_Currency Code'] !== currency || fx?.['3. To_Currency Code'] !== 'USD' || fx?.['7. Time Zone'] !== 'UTC') throw failure('MARKET_UNAVAILABLE');
        return { symbol, regularMarketPrice: Number(fx['5. Exchange Rate']), regularMarketTime: new Date(fx['6. Last Refreshed'].replace(' ', 'T')+'Z') };
      }
      const asset = await assetInfo(symbol, request);
      const points = await daily(symbol);
      if (points.length < 2) throw failure('MARKET_NOT_COVERED');
      const [latest, previous] = points;
      const volumes = points.slice(0,10).map(row => row.volume).filter(n => Number.isFinite(n) && n >= 0);
      return { symbol, source: 'Alpha Vantage', mode: 'eod', currency: asset.currency,
        quoteType: asset.kind === 'etf' ? 'ETF' : 'EQUITY', longName: asset.name,
        regularMarketPrice: latest.close, regularMarketTime: latest.date, marketState: 'CLOSED',
        regularMarketChangePercent: (latest.close / previous.close - 1) * 100,
        averageDailyVolume: volumes.length ? Math.round(volumes.reduce((a,b) => a+b,0)/volumes.length) : null };
    },
    async history(symbol, { days }) {
      const asset = await assetInfo(symbol, request);
      // Compact daily data covers 100 trading sessions. Long ranges use the free weekly endpoint.
      const weekly = days > 100;
      const points = weekly ? rows(await request({ function: 'TIME_SERIES_WEEKLY', symbol: alphaSymbol(symbol) },86400),alphaSymbol(symbol),true) : await daily(symbol);
      const minor = { GBX: 'GBP', GBp: 'GBP', ILA: 'ILS', ZAc: 'ZAR' };
      const scale = minor[asset.currency] ? 0.01 : 1;
      return { meta: { symbol, currency: minor[asset.currency] || asset.currency, source: 'Alpha Vantage', interval: weekly ? '1wk' : '1d' },
        quotes: points.filter(row => row.date.getTime() >= clock()-days*86400000 && row.date.getTime() <= clock())
          .map(row => ({...row,open:row.open*scale,high:row.high*scale,low:row.low*scale,close:row.close*scale})) };
    },
  };
}
const market = createAlphaMarket();
export const alphaQuote = market.quote;
export const alphaHistory = market.history;
