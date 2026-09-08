import test from 'node:test';
import assert from 'node:assert/strict';
import { createLogoService } from '../lib/logos.js';
import { GET } from '../api/company-logo.js';

test('logos require exact listing identity and a trusted image host', async () => {
  for (const [profile,expected] of [
    [{ticker:'AAPL',logo:'https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/AAPL.png'},true],
    [{ticker:'OTHER',logo:'https://static2.finnhub.io/AAPL.png'},false],
    [{ticker:'AAPL',logo:'https://untrusted.example/AAPL.png'},false],
    [{ticker:'AAPL',logo:'http://static2.finnhub.io/AAPL.png'},false],
  ]) {
    const load = createLogoService({request:async()=>profile});
    assert.equal(Boolean((await load('AAPL')).logoURL),expected);
  }
});
test('logo lookups share cached results and provider failures leave a neutral fallback', async () => {
  let calls=0;
  const load=createLogoService({request:async()=>{calls++;throw Error('provider secret');}});
  const result=await Promise.all([load('ITX.MC'),load('ITX.MC')]);
  assert.equal(calls,1);assert.deepEqual(result[0],{symbol:'ITX.MC',logoURL:null});
});
test('logo endpoint rejects malformed symbols before requesting a provider', async () => {
  const response=await GET(new Request('https://example/api/company-logo?symbol=../AAPL'));
  assert.equal(response.status,400);assert.equal(response.headers.get('cache-control'),'no-store');
});
