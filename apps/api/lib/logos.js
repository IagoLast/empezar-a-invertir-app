import { finnhubRequest, logoURL } from './finnhub.js';
import { cachedLoader } from './search.js';
import { canonicalAlphaSymbol } from './market-symbols.js';

export function createLogoService({ request = finnhubRequest } = {}) {
  return cachedLoader(async symbol => {
    const listing = canonicalAlphaSymbol(symbol);
    try {
      const profile = await request('stock/profile2', { symbol: listing });
      return { symbol, logoURL: profile?.ticker === listing ? logoURL(profile.logo) : null };
    } catch {
      // Branding is optional and never prevents search or trading.
      return { symbol, logoURL: null };
    }
  }, { ttl: 60 * 60000, limit: 500 });
}
export const companyLogo = createLogoService();
