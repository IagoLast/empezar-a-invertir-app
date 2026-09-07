import test from 'node:test';
import assert from 'node:assert/strict';
import { createFinnhubClient } from '../lib/finnhub.js';
test('Finnhub sends credentials only in a header and preserves provider timestamps', async () => {
 const load = createFinnhubClient({ key: () => 'test-private-key', fetcher: async (url, options) => {
  assert.equal(url.origin, 'https://finnhub.io'); assert.equal(url.searchParams.get('symbol'), 'AAPL');
  assert.ok(!url.href.includes('test-private-key')); assert.equal(options.headers['X-Finnhub-Token'], 'test-private-key');
  return Response.json({ c: 123.45, t: 1234567890 });
 }});
 assert.deepEqual(await load('quote',{symbol:'AAPL'}),{c:123.45,t:1234567890});
});
test('Finnhub coverage and throttling failures are actionable without invented data', async () => {
 for (const [status, code] of [[403,'MARKET_NOT_COVERED'],[429,'MARKET_RATE_LIMIT'],[500,'MARKET_UNAVAILABLE']]) {
  const load=createFinnhubClient({key:()=> 'secret',fetcher:async()=>Response.json({error:'secret should never be exposed'},{status})});
  await assert.rejects(load('quote'), e => e.code===code && !e.message.includes('secret'));
 }
});
test('missing Finnhub credentials make no network request', async () => {
 const load=createFinnhubClient({key:()=>'',fetcher:()=>assert.fail('Must not request')});
 await assert.rejects(load('quote'),{code:'MARKET_UNAVAILABLE'});
});
