import { APIError } from './http.js';

const feedURL = 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml';
const maxAge = 7 * 86400000;
export function parseExchangeRates(xml, now = Date.now()) {
  const date = xml.match(/<Cube\b[^>]*\btime=['"](\d{4}-\d{2}-\d{2})['"]/i)?.[1];
  const timestamp = Date.parse(`${date}T00:00:00Z`);
  if (!date || !Number.isFinite(timestamp) || timestamp > now + 86400000 || now - timestamp > maxAge) throw new Error('Invalid exchange-rate date');
  const rates = { EUR: 1 };
  for (const match of xml.matchAll(/<Cube\b[^>]*\bcurrency=['"]([A-Z]{3})['"][^>]*\brate=['"]([0-9.]+)['"][^>]*\/?\s*>/g)) {
    const rate = Number(match[2]);
    if (!Number.isFinite(rate) || rate <= 0 || Object.hasOwn(rates, match[1])) throw new Error('Invalid exchange rate');
    rates[match[1]] = rate;
  }
  if (!rates.USD || Object.keys(rates).length < 3) throw new Error('Incomplete exchange rates');
  return { base: 'EUR', date, source: 'Banco Central Europeo', rates };
}
export function createExchangeRates({ fetcher = fetch, clock = Date.now } = {}) {
  let cached, expires = 0, pending;
  return async () => {
    if (cached && clock() < expires && clock() - Date.parse(cached.date) <= maxAge) return cached;
    if (pending) return pending;
    pending = (async () => {
      try {
        const response = await fetcher(feedURL, { signal: AbortSignal.timeout(8000) });
        if (!response.ok) throw new Error('Exchange rates unavailable');
        const result = parseExchangeRates(await response.text(), clock());
        cached = result; expires = clock() + 3600000;
        return result;
      } catch {
        throw new APIError(503, 'FX_UNAVAILABLE', 'No hemos podido actualizar el cambio de moneda. Desliza hacia abajo para volver a intentarlo.');
      } finally { pending = undefined; }
    })();
    return pending;
  };
}
export const exchangeRates = createExchangeRates();
