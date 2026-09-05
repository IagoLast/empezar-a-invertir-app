import { randomUUID } from 'node:crypto';
import { APIError } from './http.js';
import { config, rpc } from './supabase.js';
export const symbols = new Set(['AAPL', 'MSFT', 'VTI', 'BND']);
export function priceCents(raw) {
  if (typeof raw !== 'string' || !/^\d{1,7}(\.\d{1,8})?$/.test(raw)) throw new Error('Invalid provider price');
  // Decimal parsing, not floating point multiplication; round to the nearest cent.
  const [whole, fraction = ''] = raw.split('.');
  const cents = Number(whole) * 100 + Number(fraction.padEnd(2, '0').slice(0, 2)) + (Number(fraction[2] || 0) >= 5 ? 1 : 0);
  if (!Number.isSafeInteger(cents) || cents <= 0) throw new Error('Invalid provider price');
  return cents;
}
export function normalizeQuote(raw, symbol, now = Date.now(), mode = 'realtime', delaySeconds = 0) {
  if (raw.status === 'error' || raw.symbol !== symbol || raw.currency !== 'USD' || typeof raw.is_market_open !== 'boolean') throw new Error('Invalid provider quote');
  const stamp = raw.last_quote_at ?? raw.timestamp;
  if (!Number.isInteger(stamp) || stamp * 1000 > now + 60000 || stamp * 1000 < now - 7 * 86400000) throw new Error('Invalid quote timestamp');
  if (!['realtime', 'delayed', 'eod'].includes(mode) || !Number.isInteger(delaySeconds) || delaySeconds < 0 || (mode === 'delayed' && delaySeconds === 0)) throw new Error('Invalid feed configuration');
  const age = now - stamp * 1000;
  // Never execute against yesterday's quote during an open market, or at a close after hours.
  const tradable = raw.is_market_open && mode !== 'eod' && age <= delaySeconds * 1000 + 120000;
  const change = Number(raw.percent_change);
  if (!Number.isFinite(change)) throw new Error('Invalid provider change');
  return { id: randomUUID(), symbol, priceCents: priceCents(raw.close), currency: 'USD', changePercent: change,
    asOf: new Date(stamp * 1000).toISOString(), fetchedAt: new Date(now).toISOString(), expiresAt: new Date(now + 60000).toISOString(),
    marketOpen: raw.is_market_open, tradable, mode, delaySeconds, source: 'Twelve Data' };
}
export async function provider(endpoint, symbol) {
  const url = new URL(`https://api.twelvedata.com/${endpoint}`);
  url.searchParams.set('symbol', symbol);
  url.searchParams.set('apikey', config('TWELVE_DATA_API_KEY'));
  const response = await fetch(url, { signal: AbortSignal.timeout(7000) });
  if (!response.ok) throw new APIError(503, 'MARKET_UNAVAILABLE', 'El proveedor no está disponible. Vuelve a intentarlo.');
  const result = await response.json();
  if (result.status === 'error') throw new APIError(503, 'MARKET_UNAVAILABLE', 'No podemos actualizar este dato ahora.');
  return result;
}
export async function getQuote(symbol) {
  const cached = await rpc('quote_cache', { p_symbol: symbol }, null, true);
  if (cached.quote && Date.parse(cached.quote.fetchedAt) > Date.now() - 30000) return cached.quote;
  if (!cached.refresh) {
    if (cached.quote) return cached.quote; // Expiry still enforced by Postgres, no new execution lifetime.
    throw new APIError(503, 'QUOTE_LOADING', 'Estamos actualizando el precio. Inténtalo en unos segundos.');
  }
  try {
    const quote = normalizeQuote(await provider('quote', symbol), symbol, Date.now(), config('MARKET_DATA_MODE'), Number(process.env.MARKET_DATA_DELAY_SECONDS || 0));
    await rpc('save_quote', { p_quote: quote }, null, true);
    return quote;
  } catch {
    // Retain original timestamps; never turn stale data into a fresh executable quote.
    if (cached.quote) return cached.quote;
    throw new APIError(503, 'MARKET_UNAVAILABLE', 'No hay una cotización disponible. No se puede operar sin un precio real.');
  }
}
