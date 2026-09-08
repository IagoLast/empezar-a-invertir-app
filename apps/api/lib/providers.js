import { finnhubQuote } from './finnhub.js';
import { alphaQuote, alphaEnabled } from './alpha-vantage.js';
import { firstValidProvider } from './provider-fallback.js';

export function createMarketQuote({ primary = finnhubQuote, secondary = alphaQuote, enabled = alphaEnabled, clock = Date.now } = {}) {
  return async symbol => {
    const attempts = [async () => ({ ...await primary(symbol), source: 'Finnhub' })];
    if (enabled()) attempts.push(async () => ({ ...await secondary(symbol), source: 'Alpha Vantage' }));
    return firstValidProvider(attempts, quote => {
      const stamp = quote?.regularMarketTime instanceof Date ? quote.regularMarketTime.getTime() : NaN;
      if (quote.symbol !== symbol || !Number.isFinite(quote.regularMarketPrice) || quote.regularMarketPrice <= 0
        || !Number.isFinite(stamp) || stamp < clock()-7*86400000 || stamp > clock()+60000) throw Error('Invalid quote');
      if (!symbol.endsWith('=X') && (!/^(?:[A-Z]{3}|GBp|ZAc)$/.test(quote.currency || '')
        || !['EQUITY', 'ETF'].includes(quote.quoteType) || !Number.isFinite(quote.regularMarketChangePercent)
        || !['REGULAR', 'CLOSED', 'PRE', 'PREPRE', 'POST', 'POSTPOST'].includes(quote.marketState))) throw Error('Invalid quote metadata');
      return quote;
    }, 'No hemos podido obtener una cotización de las fuentes disponibles para este activo. Desliza hacia abajo para volver a intentarlo.');
  };
}
export const providerQuote = createMarketQuote();
