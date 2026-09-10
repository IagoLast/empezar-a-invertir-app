import { endpoint, requireInput } from '../lib/http.js';
import { exchangeRates } from '../lib/currencies.js';
import { previewMarket } from '../lib/search.js';
export const GET = endpoint('GET', async request => {
  if (new URL(request.url).searchParams.get('resource') === 'currencies') return exchangeRates();
  const symbol = new URL(request.url).searchParams.get('symbol') || '';
  requireInput(/^[A-Z0-9][A-Z0-9.^=-]{0,19}$/.test(symbol));
  return previewMarket(symbol);
});
