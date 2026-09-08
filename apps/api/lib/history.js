import { firstValidProvider } from './provider-fallback.js';
import { cachedLoader } from './search.js';
import { finnhubHistory } from './finnhub.js';
import { alphaHistory, alphaEnabled } from './alpha-vantage.js';

export const historyRanges = {
  '1w': { days: 7, interval: '1h' },
  '1m': { days: 31, interval: '1d' },
  '3m': { days: 93, interval: '1d' },
  '1y': { days: 366, interval: '1d' },
  '5y': { days: 1827, interval: '1wk' },
};

export function normalizeHistory(raw, symbol, range) {
  if (raw?.meta?.symbol !== symbol || !/^[A-Z]{3}$/.test(raw.meta.currency || '') || !Array.isArray(raw.quotes)) throw Error('Invalid history');
  const seen = new Set();
  const points = raw.quotes.flatMap(row => {
    const date = row.date instanceof Date ? row.date.getTime() : NaN;
    if (!Number.isFinite(date) || seen.has(date)
      || ![row.open, row.high, row.low, row.close].every(n => Number.isFinite(n) && n > 0)
      || row.low > Math.min(row.open, row.close) || row.high < Math.max(row.open, row.close)) return [];
    seen.add(date);
    return [{ date: new Date(date).toISOString(), open: row.open, high: row.high, low: row.low, close: row.close }];
  }).sort((a, b) => a.date.localeCompare(b.date));
  return { symbol, range, currency: raw.meta.currency, source: raw.meta.source || 'Finnhub', interval: raw.meta.interval || historyRanges[range].interval, points };
}

export function createHistoryService({ primary = alphaHistory, secondary = finnhubHistory, enabled = alphaEnabled } = {}) {
  return cachedLoader(async key => {
    const [symbol, range] = key.split(':');
    const attempts = [];
    if (enabled()) attempts.push(() => primary(symbol, historyRanges[range]));
    attempts.push(() => secondary(symbol, historyRanges[range]));
    return firstValidProvider(attempts, raw => {
      const result = normalizeHistory(raw, symbol, range);
      if (!result.points.length) throw Error('Empty history');
      return result;
    }, 'No hemos podido obtener el histórico de las fuentes disponibles para este activo. Desliza hacia abajo para volver a intentarlo.');
  });
}
export const marketHistory = createHistoryService();
