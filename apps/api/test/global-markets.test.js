import test from 'node:test';
import assert from 'node:assert/strict';
import { settlementQuote, createQuoteService, validSymbol } from '../lib/market.js';
import { normalizeHistory } from '../lib/history.js';
import { GET as history } from '../api/history.js';

const now = Date.parse('2026-09-07T10:00:00Z');
const asset = (patch = {}) => ({ symbol: 'ITX.MC', quoteType: 'EQUITY', currency: 'EUR', longName: 'Inditex',
  regularMarketPrice: 50, regularMarketTime: new Date(now - 600000), regularMarketChangePercent: 1, marketState: 'REGULAR', ...patch });
const fx = (patch = {}) => ({ symbol: 'EURUSD=X', regularMarketPrice: 1.1, regularMarketTime: new Date(now - 60000), ...patch });

test('international symbols and single-letter stocks are accepted; unsafe strings are not', () => {
  for (const symbol of ['ITX.MC', 'BRK-B', 'F', '7203.T', 'ASML.AS']) assert.equal(validSymbol(symbol), true);
  for (const symbol of [null, '', '../bad', 'A B', 'EURUSD=X', 'aapl']) assert.equal(validSymbol(symbol), false);
});
test('Inditex settles in USD while preserving native price, currency and conversion evidence', async () => {
  const quote = await settlementQuote(asset(), 'ITX.MC', async symbol => { assert.equal(symbol, 'EURUSD=X'); return fx(); }, now);
  assert.equal(quote.priceCents, 5500);
  assert.equal(quote.currency, 'USD'); assert.equal(quote.nativeCurrency, 'EUR'); assert.equal(quote.nativePrice, 50);
  assert.equal(quote.exchangeRate, 1.1); assert.equal(quote.name, 'Inditex'); assert.equal(quote.kind, 'stock'); assert.equal(quote.tradable, true);
});
test('pence are scaled before conversion and USD assets need no FX request', async () => {
  const quote = await settlementQuote(asset({ currency: 'GBp', regularMarketPrice: 1000 }), 'ITX.MC', async () => fx({ symbol: 'GBPUSD=X', regularMarketPrice: 1.25 }), now);
  assert.equal(quote.priceCents, 1250); assert.equal(quote.nativePrice, 10); assert.equal(quote.nativeCurrency, 'GBP');
  const usd = await settlementQuote(asset({ currency: 'USD', regularMarketPrice: 1.005 }), 'ITX.MC', () => assert.fail('No FX for USD'), now);
  assert.equal(usd.priceCents, 101);
});
test('missing, stale, future and mismatched FX never produce executable quotes', async () => {
  for (const patch of [{ symbol: 'USDEUR=X' }, { regularMarketPrice: 0 }, { regularMarketPrice: NaN },
    { regularMarketTime: new Date(now - 4 * 86400000) }, { regularMarketTime: new Date(now + 120000) }]) {
    await assert.rejects(settlementQuote(asset(), 'ITX.MC', async () => fx(patch), now));
  }
  await assert.rejects(settlementQuote(asset({ quoteType: 'INDEX' }), 'ITX.MC', async () => fx(), now), { code: 'ASSET_UNSUPPORTED' });
  await assert.rejects(settlementQuote(asset({ regularMarketPrice: '50' }), 'ITX.MC', async () => fx(), now));
});
test('uncatalogued assets load, convert and persist via the normal quote flow', async () => {
  let saved;
  const get = createQuoteService({ clock: () => now,
    database: async (name, args) => name === 'quote_cache' ? { refresh: true } : (saved = args.p_quote),
    loadQuote: async symbol => symbol === 'ITX.MC' ? asset() : fx() });
  assert.deepEqual(await get('ITX.MC'), saved); assert.equal(saved.priceCents, 5500);
});
test('history preserves provider OHLC and skips incomplete points without inventing data', () => {
  const point = { date: new Date(now), open: 10, high: 12, low: 9, close: 11 };
  const result = normalizeHistory({ meta: { symbol: 'ITX.MC', currency: 'EUR' }, quotes: [point, point, { ...point, date: new Date(now - 1000), close: null }] }, 'ITX.MC', '1m');
  assert.equal(result.currency, 'EUR'); assert.equal(result.points.length, 1); assert.equal(result.points[0].high, 12);
  assert.throws(() => normalizeHistory({ meta: { symbol: 'AAPL' }, quotes: [] }, 'ITX.MC', '1m'));
});
test('history rejects invalid ranges and symbols before contacting the provider', async () => {
  for (const query of ['symbol=ITX.MC&range=bad', 'symbol=ITX.MC&range=__proto__', 'symbol=../bad']) {
    assert.equal((await history(new Request(`https://example.test/api/history?${query}`))).status, 400);
  }
});
