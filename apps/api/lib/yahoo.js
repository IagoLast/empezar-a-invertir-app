import YahooFinance from 'yahoo-finance2';

const yahoo = new YahooFinance({ suppressNotices: ['yahooSurvey'] });
const fields = ['symbol', 'currency', 'regularMarketPrice', 'regularMarketTime',
  'regularMarketChangePercent', 'marketState', 'exchangeDataDelayedBy', 'logoUrl',
  'trailingPE', 'epsTrailingTwelveMonths', 'quoteType', 'shortName', 'longName'];
const pending = new Map();

export async function yahooQuote(symbol) {
  if (pending.has(symbol)) return pending.get(symbol);
  const request = yahoo.quote(symbol, { fields }, { fetchOptions: { signal: AbortSignal.timeout(8000) } });
  pending.set(symbol, request);
  try { return await request; }
  finally { pending.delete(symbol); }
}

export function logoURL(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === 's.yimg.com' ? url.href : null;
  } catch { return null; }
}

export async function yahooSearch(query) {
  return yahoo.search(query, { quotesCount: 50, newsCount: 0, enableFuzzyQuery: true },
    { fetchOptions: { signal: AbortSignal.timeout(8000) } });
}

export async function yahooHistory(symbol, { days, interval }) {
  return yahoo.chart(symbol, { period1: new Date(Date.now() - days * 86400000), interval },
    { fetchOptions: { signal: AbortSignal.timeout(8000) } });
}
