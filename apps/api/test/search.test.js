import test from 'node:test';
import assert from 'node:assert/strict';
import { cachedLoader, normalizeSearch } from '../lib/search.js';
import { GET as search } from '../api/search.js';
import { GET as preview } from '../api/market-preview.js';

test('search returns distinct Yahoo stocks and ETFs with their names and exchanges', () => {
  const nvidia = { isYahooFinance: true, quoteType: 'EQUITY', symbol: 'NVDA', longname: 'NVIDIA Corporation', exchDisp: 'NASDAQ' };
  assert.deepEqual(normalizeSearch({ quotes: [nvidia, nvidia,
    { isYahooFinance: true, quoteType: 'ETF', symbol: 'SPY', shortname: 'SPDR', exchange: 'PCX' },
    { ...nvidia, symbol: '../bad' }, { ...nvidia, isYahooFinance: false }, { ...nvidia, symbol: 'BTC-USD', quoteType: 'CRYPTOCURRENCY' }] }),
    [{ symbol: 'NVDA', name: 'NVIDIA Corporation', kind: 'stock', exchange: 'NASDAQ' }, { symbol: 'SPY', name: 'SPDR', kind: 'etf', exchange: 'PCX' }]);
});
test('cache shares concurrent requests and reloads after expiry', async () => {
  let calls = 0, now = 0;
  const load = cachedLoader(async key => ({ key, count: ++calls }), { clock: () => now, ttl: 100 });
  const [a, b] = await Promise.all([load('nvda'), load('nvda')]); assert.equal(a, b); assert.equal(calls, 1);
  now = 101; assert.equal((await load('nvda')).count, 2);
});
test('failed searches can retry and the cache size is bounded', async () => {
  let calls = 0;
  const load = cachedLoader(async key => { calls++; if (calls === 1) throw Error('offline'); return key; }, { limit: 1 });
  await assert.rejects(load('a')); assert.equal(await load('a'), 'a');
  await load('b'); await load('a'); assert.equal(calls, 4);
});
test('public discovery rejects empty queries and unsafe symbols', async () => {
  for (const q of ['', 'a'.repeat(81)]) assert.equal((await search(new Request('https://app.example/api/search?q=' + q))).status, 400);
  assert.equal((await preview(new Request('https://app.example/api/market-preview?symbol=../../bad'))).status, 400);
});
