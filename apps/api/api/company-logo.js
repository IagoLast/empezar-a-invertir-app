import { endpoint, requireInput } from '../lib/http.js';
import { validSymbol } from '../lib/market.js';
import { companyLogo } from '../lib/logos.js';
const handler = endpoint('GET', async request => {
  const symbol = new URL(request.url).searchParams.get('symbol');
  requireInput(validSymbol(symbol));
  return companyLogo(symbol);
});
export async function GET(request) {
  const response = await handler(request);
  if (response.ok) response.headers.set('Cache-Control', 'public, max-age=3600, s-maxage=86400');
  return response;
}
