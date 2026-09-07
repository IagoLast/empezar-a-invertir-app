import { endpoint, requireInput } from '../lib/http.js';
import { getQuote, validSymbol } from '../lib/market.js';
export const GET = endpoint('GET', async request => {
  const symbol = new URL(request.url).searchParams.get('symbol');
  requireInput(validSymbol(symbol));
  return getQuote(symbol);
});
