import { endpoint, requireInput } from '../lib/http.js';
import { validSymbol } from '../lib/market.js';
import { historyRanges, marketHistory } from '../lib/history.js';

export const GET = endpoint('GET', async request => {
  const params = new URL(request.url).searchParams;
  const symbol = params.get('symbol'), range = params.get('range') || '1m';
  requireInput(validSymbol(symbol) && Object.hasOwn(historyRanges, range));
  return marketHistory(`${symbol}:${range}`);
});
