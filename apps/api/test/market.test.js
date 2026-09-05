import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeQuote, priceCents } from '../lib/market.js';
const now = Date.parse('2026-09-04T15:30:00Z');
const fixture = () => ({ symbol: 'AAPL', currency: 'USD', close: '319.97000', timestamp: now / 1000 - 7200, last_quote_at: now / 1000 - 30, percent_change: '-2.51058', is_market_open: true });
test('parses monetary decimals without float multiplication errors', () => {
  assert.equal(priceCents('1.00500'), 101); assert.equal(priceCents('319.97000'), 31997); assert.equal(priceCents('0.105'), 11);
});
test('rejects zero, negative, NaN, exponent and non-string prices', () => {
  for (const price of ['0', '-2', 'NaN', '1e5', 100, null, '999999999']) assert.throws(() => priceCents(price));
});
test('uses last quote timestamp, not opening candle timestamp', () => {
  const q = normalizeQuote(fixture(), 'AAPL', now);
  assert.equal(q.asOf, new Date(now - 30000).toISOString()); assert.equal(q.tradable, true); assert.equal(q.priceCents, 31997);
});
test('closed market quotes are visible but not tradable', () => {
  const q = normalizeQuote({ ...fixture(), is_market_open: false }, 'AAPL', now);
  assert.equal(q.marketOpen, false); assert.equal(q.tradable, false);
});
test('stale open-market data is never executable', () => {
  const q = normalizeQuote({ ...fixture(), last_quote_at: now / 1000 - 3600 }, 'AAPL', now);
  assert.equal(q.tradable, false);
});
test('licensed delayed data carries explicit delay and freshness checks', () => {
  const q = normalizeQuote({ ...fixture(), last_quote_at: now / 1000 - 920 }, 'AAPL', now, 'delayed', 900);
  assert.equal(q.tradable, true); assert.equal(q.delaySeconds, 900);
  assert.throws(() => normalizeQuote(fixture(), 'AAPL', now, 'delayed', 0));
});
test('rejects incorrect symbols, currencies, timestamps and provider errors', () => {
  for (const patch of [{ symbol: 'MSFT' }, { currency: 'EUR' }, { last_quote_at: now / 1000 + 600 }, { last_quote_at: 1 }, { is_market_open: 'true' }, { status: 'error' }]) {
    assert.throws(() => normalizeQuote({ ...fixture(), ...patch }, 'AAPL', now));
  }
});
test('end of day mode never executes live orders', () => assert.equal(normalizeQuote(fixture(), 'AAPL', now, 'eod').tradable, false));
