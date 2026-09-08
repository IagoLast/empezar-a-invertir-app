import test from 'node:test';
import assert from 'node:assert/strict';
import { cachedLoader, normalizeSearch, rankSearchResults, createSearchService } from '../lib/search.js';
import { GET as search } from '../api/search.js';
import { GET as preview } from '../api/market-preview.js';

test('search keeps international listings and distinguishes their exchanges', () => {
  const stock = { type: 'Common Stock', symbol: 'NVDA', description: 'NVIDIA Corporation' };
  const result = normalizeSearch({ result: [stock, stock, { type:'ETP',symbol:'SPY',description:'SPDR' },
    {...stock,symbol:'ITX.MC'}, {...stock,symbol:'TSCO.L'}, {...stock,symbol:'../bad'}, {...stock,type:'Crypto',symbol:'BTC'}] });
  assert.deepEqual(result.map(row=>row.symbol),['NVDA','SPY','ITX.MC','TSCO.L']);
  assert.equal(result[2].exchange,'Madrid');assert.equal(result[3].exchange,'Londres');
  assert.equal(result[2].quoteAvailability,'check_on_open');
});
test('brand search resolves the verified legal name and exact symbols rank first',async()=>{
  let requested;
  const search=createSearchService({enabled:()=>false,primary:async q=>{requested=q;return {result:[{symbol:'ITX.MC',description:'Industria de Diseno Textil',type:'Common Stock'}]};}});
  assert.equal((await search('inditex')).results[0].symbol,'ITX.MC');assert.equal(requested,'Industria de Diseno Textil');
  const result=rankSearchResults([{symbol:'ADTX',name:'Aditxt'},{symbol:'ITX.MC',name:'Industria de Diseno Textil'}],'ITX');
  assert.equal(result[0].symbol,'ITX.MC');
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
