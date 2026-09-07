import { randomUUID } from 'node:crypto';
import { APIError } from './http.js';
import { rpc } from './supabase.js';
import { logoURL } from './finnhub.js';
import { providerQuote } from './providers.js';
const supportedSource = source => ['Finnhub', 'Alpha Vantage'].includes(source);
export const QUOTE_CACHE_MS = 15 * 60 * 1000;
const MAX_TRADE_AGE_MS = 60 * 60 * 1000;
export const symbols = new Set(['AAPL', 'MSFT', 'VTI', 'BND']);
export const validSymbol = symbol => typeof symbol === 'string' && /^[A-Z0-9][A-Z0-9.-]{0,19}$/.test(symbol);
const MAX_FX_AGE_MS = 4 * 86400000;

// Wallets settle in USD. Preserve the exchange's native price alongside the execution price.
export async function settlementQuote(raw, symbol, loadQuote = providerQuote, now = Date.now()) {
  if (!raw || raw.symbol !== symbol || !['EQUITY', 'ETF'].includes(raw.quoteType)) {
    throw new APIError(422, 'ASSET_UNSUPPORTED', 'Solo se puede operar con acciones y ETF que tengan una cotización disponible.');
  }
  if (typeof raw.regularMarketPrice !== 'number' || !Number.isFinite(raw.regularMarketPrice) || raw.regularMarketPrice <= 0) throw Error('Invalid native price');
  let currency = raw.currency, scale = 1;
  const minorUnits = { GBp: 'GBP', GBX: 'GBP', ILA: 'ILS', ZAc: 'ZAR' };
  if (minorUnits[currency]) { currency = minorUnits[currency]; scale = 0.01; }
  if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) throw Error('Invalid currency');
  let rate = 1, fxAsOf;
  if (currency !== 'USD') {
    const fxSymbol = `${currency}USD=X`;
    const fx = await loadQuote(fxSymbol);
    const stamp = fx?.regularMarketTime instanceof Date ? fx.regularMarketTime.getTime() : NaN;
    if (fx?.symbol !== fxSymbol || !Number.isFinite(fx.regularMarketPrice) || fx.regularMarketPrice <= 0
      || !Number.isFinite(stamp) || stamp > now + 60000 || stamp <= now - MAX_FX_AGE_MS) throw Error('Invalid FX quote');
    rate = fx.regularMarketPrice;
    fxAsOf = new Date(stamp).toISOString();
  }
  const nativePrice = raw.regularMarketPrice * scale;
  const converted = nativePrice * rate;
  if (!Number.isFinite(converted) || converted <= 0 || converted >= 10000000) throw Error('Invalid settlement price');
  const quote = normalizeQuote({ ...raw, currency: 'USD', regularMarketPrice: Number(converted.toFixed(8)) }, symbol, now);
  if (fxAsOf) quote.expiresAt = new Date(Math.min(Date.parse(quote.expiresAt), Date.parse(fxAsOf) + MAX_FX_AGE_MS)).toISOString();
  return { ...quote, nativePrice, nativeCurrency: currency, exchangeRate: rate, fxAsOf,
    name: raw.longName || raw.shortName || symbol, kind: raw.quoteType === 'ETF' ? 'etf' : 'stock' };
}
export function priceCents(raw) {
  if (typeof raw !== 'string' || !/^\d{1,7}(\.\d{1,8})?$/.test(raw)) throw new Error('Invalid provider price');
  // Decimal parsing, not floating point multiplication; round to the nearest cent.
  const [whole, fraction = ''] = raw.split('.');
  const cents = Number(whole) * 100 + Number(fraction.padEnd(2, '0').slice(0, 2)) + (Number(fraction[2] || 0) >= 5 ? 1 : 0);
  if (!Number.isSafeInteger(cents) || cents <= 0) throw new Error('Invalid provider price');
  return cents;
}
export function normalizeQuote(raw, symbol, now = Date.now()) {
  if (!raw || raw.symbol !== symbol || raw.currency !== 'USD' || !['REGULAR', 'CLOSED', 'PRE', 'PREPRE', 'POST', 'POSTPOST'].includes(raw.marketState)) throw new Error('Invalid provider quote');
  const stamp = raw.regularMarketTime instanceof Date ? raw.regularMarketTime.getTime() : NaN;
  if (!Number.isFinite(stamp) || stamp > now + 60000 || stamp < now - 7 * 86400000) throw new Error('Invalid quote timestamp');
  if (typeof raw.regularMarketPrice !== 'number' || !Number.isFinite(raw.regularMarketPrice)) throw new Error('Invalid provider price');
  const change = raw.regularMarketChangePercent;
  if (typeof change !== 'number' || !Number.isFinite(change)) throw new Error('Invalid provider change');
  const marketOpen = raw.marketState === 'REGULAR';
  // Educational execution can use delayed data, but never data older than one hour.
  const tradable = marketOpen && now - stamp < MAX_TRADE_AGE_MS;
  const expiry = marketOpen ? Math.min(now + QUOTE_CACHE_MS + 5 * 60000, stamp + MAX_TRADE_AGE_MS) : now + QUOTE_CACHE_MS;
  return { id: randomUUID(), symbol, priceCents: priceCents(String(raw.regularMarketPrice)), currency: 'USD', changePercent: change,
    asOf: new Date(stamp).toISOString(), fetchedAt: new Date(now).toISOString(), expiresAt: new Date(expiry).toISOString(),
    marketOpen, tradable, mode: raw.mode === 'eod' ? 'eod' : 'cached', delaySeconds: Math.max(0, Math.floor((now - stamp) / 1000)),
    source: raw.source === 'Alpha Vantage' ? 'Alpha Vantage' : 'Finnhub', averageDailyVolume: raw.averageDailyVolume ?? null, logoURL: logoURL(raw.logoUrl) };
}
export function normalizeFundamentals(raw, symbol, now = Date.now()) {
  if (!raw || raw.symbol !== symbol || raw.currency !== 'USD') throw new Error('Invalid fundamentals');
  const number = value => typeof value === 'number' && Number.isFinite(value) ? value : null;
  const pe = number(raw.trailingPE), eps = number(raw.epsTrailingTwelveMonths);
  return { available: pe !== null || eps !== null, symbol, pe, eps, period: 'TTM', source: 'Finnhub', fetchedAt: new Date(now).toISOString() };
}
export function createQuoteService({ database = rpc, loadQuote = providerQuote, clock = Date.now } = {}) {
  return async function getQuote(symbol) {
    const cached = await database('quote_cache', { p_symbol: symbol }, null, true);
    if (cached.quote && supportedSource(cached.quote.source) && Date.parse(cached.quote.fetchedAt) > clock() - QUOTE_CACHE_MS && Date.parse(cached.quote.expiresAt) > clock()) return cached.quote;
    if (!cached.refresh) {
      if (supportedSource(cached.quote?.source)) return { ...cached.quote, tradable: false }; // Expiry still enforced by Postgres, no new execution lifetime.
      throw new APIError(503, 'QUOTE_LOADING', 'Estamos actualizando el precio. Inténtalo en unos segundos.');
    }
    try {
      const quote = await settlementQuote(await loadQuote(symbol), symbol, loadQuote, clock());
      await database('save_quote', { p_quote: quote }, null, true);
      return quote;
    } catch (error) {
      // Retain original timestamps; never turn stale data into a fresh executable quote.
      if (supportedSource(cached.quote?.source)) return { ...cached.quote, tradable: false };
      if (error instanceof APIError) throw error;
      throw new APIError(503, 'MARKET_UNAVAILABLE', 'No hay una cotización disponible. No se puede operar sin un precio real.');
    }
  }
}

export const getQuote = createQuoteService();
