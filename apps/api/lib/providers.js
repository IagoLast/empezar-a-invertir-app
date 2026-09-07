import { finnhubQuote } from './finnhub.js';
import { alphaQuote, alphaEnabled } from './alpha-vantage.js';
import { APIError } from './http.js';
export function createMarketQuote({ primary = finnhubQuote, secondary = alphaQuote, enabled = alphaEnabled, clock = Date.now } = {}) {
  return async symbol => {
    // Keep Alpha's exchange suffixes intact: TSCO.LON is not a US symbol or a Yahoo alias.
    if ((symbol.includes('.') && !/\.[AB]$/.test(symbol)) || symbol.endsWith('=X')) {
      if (enabled()) return secondary(symbol);
      throw new APIError(422, 'MARKET_NOT_COVERED', 'Este mercado no está incluido en las fuentes disponibles.');
    }
    try {
      const quote = await primary(symbol);
      if (!Number.isFinite(quote?.regularMarketPrice) || quote.regularMarketPrice <= 0
        || !(quote.regularMarketTime instanceof Date) || !Number.isFinite(quote.regularMarketTime.getTime())
        || quote.regularMarketTime.getTime() < clock()-7*86400000 || quote.regularMarketTime.getTime() > clock()+60000) throw Error('Invalid primary quote');
      return { ...quote, source: 'Finnhub' };
    } catch (error) {
      if (!enabled()) throw error;
      return secondary(symbol);
    }
  };
}
export const providerQuote = createMarketQuote();
