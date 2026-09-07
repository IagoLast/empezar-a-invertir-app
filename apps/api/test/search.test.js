import test from 'node:test';
import assert from 'node:assert/strict';
import { cachedLoader, normalizeSearch } from '../lib/search.js';
import { GET as search } from '../api/search.js';
import { GET as preview } from '../api/market-preview.js';

test('search shows distinct US stocks and ETFs and excludes unsupported foreign symbols', () => {
  const stock = { type: 'Common Stock', symbol: 'NVDA', description: 'NVIDIA Corporation' };
  assert.deepEqual(normalizeSearch({ result: [stock, stock,
    { type: 'ETP', symbol: 'SPY', description: 'SPDR' },
    { ...stock, symbol: '../bad' }, { ...stock, symbol: 'ITX.MC' }, { ...stock, type: 'Crypto', symbol: 'BTC' }] }),
    [{ symbol: 'NVDA', name: 'NVIDIA Corporation', kind: 'stock', exchange: 'US' }, { symbol: 'SPY', name: 'SPDR', kind: 'etf', exchange: 'US' }]);
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
