import { endpoint, requireInput } from '../lib/http.js';
import { previewMarket } from '../lib/search.js';
export const GET = endpoint('GET', async request => {
  const symbol = new URL(request.url).searchParams.get('symbol') || '';
  requireInput(/^[A-Z0-9][A-Z0-9.^=-]{0,19}$/.test(symbol));
  return previewMarket(symbol);
});
