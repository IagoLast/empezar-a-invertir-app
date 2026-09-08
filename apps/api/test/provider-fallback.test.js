import test from 'node:test';
import assert from 'node:assert/strict';
import { createMarketQuote } from '../lib/providers.js';
import { createHistoryService } from '../lib/history.js';
import { APIError } from '../lib/http.js';
const now = Date.parse('2026-09-08T10:00:00Z');
const quote = symbol => ({ symbol, currency:'EUR', quoteType:'EQUITY', marketState:'CLOSED',
  regularMarketPrice:50, regularMarketChangePercent:1, regularMarketTime:new Date(now) });

test('international quotes try Finnhub and stop when it supplies valid data', async () => {
  const load = createMarketQuote({clock:()=>now,enabled:()=>true,
    primary:async symbol=>quote(symbol),secondary:()=>assert.fail('Unnecessary quota use')});
  assert.equal((await load('ITX.MC')).source,'Finnhub');
});
test('international provider failures fall through using the exact requested listing', async () => {
  for (const invalid of [null, {...quote('ITX.MC'),regularMarketPrice:0}, quote('OTHER.MC'),
    {...quote('ITX.MC'),currency:null}, {...quote('ITX.MC'),regularMarketTime:new Date(0)}]) {
    const load = createMarketQuote({clock:()=>now,enabled:()=>true,primary:async()=>invalid,
      secondary:async symbol=>{assert.equal(symbol,'ITX.MC');return quote(symbol);}});
    assert.equal((await load('ITX.MC')).source,'Alpha Vantage');
  }
});
test('all providers must fail before returning an aggregate error', async () => {
  let attempts=0;
  const fail=async()=>{attempts++;throw new APIError(422,'MARKET_NOT_COVERED','Provider-specific plan error');};
  const load=createMarketQuote({primary:fail,secondary:fail,enabled:()=>true});
  await assert.rejects(load('TSCO.LON'),error=>error.code==='MARKET_NOT_COVERED'&&!error.message.includes('Provider-specific'));
  assert.equal(attempts,2);
});
test('invalid fallback quotes are never accepted', async () => {
  const load=createMarketQuote({clock:()=>now,enabled:()=>true,primary:async()=>{throw Error();},secondary:async()=>quote('OTHER')});
  await assert.rejects(load('ITX.MC'),{code:'MARKET_UNAVAILABLE'});
});
test('empty and malformed histories trigger another provider before returning', async () => {
  const valid={meta:{symbol:'ITX.MC',currency:'EUR',source:'Finnhub'},quotes:[{date:new Date(now),open:50,high:52,low:49,close:51}]};
  for(const bad of [null,{...valid,quotes:[]},{...valid,meta:{symbol:'OTHER',currency:'EUR'}}]) {
    const load=createHistoryService({enabled:()=>true,primary:async()=>bad,secondary:async()=>valid});
    assert.equal((await load('ITX.MC:1m')).source,'Finnhub');
  }
});
