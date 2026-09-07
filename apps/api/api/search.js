import { endpoint, requireInput } from '../lib/http.js';
import { searchMarkets } from '../lib/search.js';
export const GET = endpoint('GET', async request => {
  const query = (new URL(request.url).searchParams.get('q') || '').trim();
  requireInput(query.length >= 1 && query.length <= 80 && !/[\x00-\x1f]/.test(query));
  return searchMarkets(query.toLocaleLowerCase('en-US'));
});
