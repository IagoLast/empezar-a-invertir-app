import { APIError } from './http.js';
import { cachedLoader } from './search.js';
import { finnhubHistory } from './finnhub.js';

export const historyRanges = {
  '1w': { days: 7, interval: '1h' },
  '1m': { days: 31, interval: '1d' },
  '3m': { days: 93, interval: '1d' },
  '1y': { days: 366, interval: '1d' },
  '5y': { days: 1827, interval: '1wk' },
};

export function normalizeHistory(raw, symbol, range) {
  if (raw?.meta?.symbol !== symbol || typeof raw.meta.currency !== 'string' || !Array.isArray(raw.quotes)) throw Error('Invalid history');
  const seen = new Set();
  const points = raw.quotes.flatMap(row => {
    const date = row.date instanceof Date ? row.date.getTime() : NaN;
    if (!Number.isFinite(date) || seen.has(date)
      || ![row.open, row.high, row.low, row.close].every(n => Number.isFinite(n) && n > 0)
      || row.low > Math.min(row.open, row.close) || row.high < Math.max(row.open, row.close)) return [];
    seen.add(date);
    return [{ date: new Date(date).toISOString(), open: row.open, high: row.high, low: row.low, close: row.close }];
  }).sort((a, b) => a.date.localeCompare(b.date));
  return { symbol, range, currency: raw.meta.currency, source: 'Finnhub', points };
}

export const marketHistory = cachedLoader(async key => {
  const [symbol, range] = key.split(':');
  try { return normalizeHistory(await finnhubHistory(symbol, historyRanges[range]), symbol, range); }
  catch (error) { if (error instanceof APIError) throw error; throw new APIError(503, 'HISTORY_UNAVAILABLE', 'No hemos podido cargar el histórico. Desliza hacia abajo para volver a intentarlo.'); }
});
