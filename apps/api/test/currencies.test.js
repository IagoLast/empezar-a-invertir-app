import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseExchangeRates, createExchangeRates } from '../lib/currencies.js';

const now = Date.parse('2026-09-10T12:00:00Z');
const xml = "<Cube time='2026-09-09'><Cube currency='USD' rate='1.2'/><Cube currency='GBP' rate='0.8'/></Cube>";
test('ECB rates preserve the EUR base and USD conversion direction', () => {
  const result = parseExchangeRates(xml, now);
  assert.equal(result.rates.EUR, 1);
  assert.equal(result.rates.EUR / result.rates.USD, 1 / 1.2);
});
test('reject stale, future, missing and duplicate rates', () => {
  for (const bad of [xml.replace('2026-09-09', '2026-08-01'), xml.replace('2026-09-09', '2026-10-01'), xml.replace('USD', 'CAD'), xml.replace('GBP', 'USD'), xml.replace('1.2', '0')]) {
    assert.throws(() => parseExchangeRates(bad, now));
  }
});
test('coalesce concurrent requests and cache successful rates', async () => {
  let calls = 0;
  const get = createExchangeRates({ clock: () => now, fetcher: async () => { calls++; return new Response(xml); } });
  const [first, second] = await Promise.all([get(), get()]);
  assert.deepEqual(first, second);
  await get();
  assert.equal(calls, 1);
});
test('failed requests can retry without inventing rates', async () => {
  let calls = 0;
  const get = createExchangeRates({ clock: () => now, fetcher: async () => new Response(++calls === 1 ? '' : xml, { status: calls === 1 ? 503 : 200 }) });
  await assert.rejects(get());
  assert.equal((await get()).rates.USD, 1.2);
});
