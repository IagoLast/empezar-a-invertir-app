import test from 'node:test';
import assert from 'node:assert/strict';
import { canonicalEodhdSymbol, eodhdSymbol, normalizeEodhdSearch, createEodhdClient, createEodhdMarket } from '../lib/eodhd.js';
import { createMarketQuote } from '../lib/providers.js';
import { createSearchService } from '../lib/search.js';
import { createHistoryService } from '../lib/history.js';
import { settlementQuote } from '../lib/market.js';
const now = Date.parse('2026-09-08T10:00:00Z');
const asset = {Code:'ITX',Exchange:'MC',Name:'Inditex',Type:'Common Stock',Currency:'EUR'};

test('EODHD listing identity round trips without conflating countries or US share classes', () => {
  for (const [code,exchange,symbol] of [['ITX','MC','ITX.MC'],['ITX','LSE','ITX.L'],['AAPL','US','AAPL'],['BRK-B','US','BRK.B'],['SAP','XETRA','SAP.DE']]) {
    assert.equal(canonicalEodhdSymbol(code,exchange),symbol);
    assert.equal(eodhdSymbol(symbol),`${code}.${exchange}`);
  }
  assert.equal(canonicalEodhdSymbol('ABC','UNKNOWN'),null);
  assert.throws(()=>eodhdSymbol('ABC.UNKNOWN'));
  assert.equal(eodhdSymbol('EURUSD=X'),'EURUSD.FOREX');
});
test('search excludes unknown exchanges, non-stock assets and missing currencies', () => {
  assert.deepEqual(normalizeEodhdSearch([asset,{...asset,Exchange:'UNKNOWN'},{...asset,Type:'Crypto'},{...asset,Currency:null}]).map(x=>x.symbol),['ITX.MC']);
});
test('EODHD client shares requests, expires its cache and never exposes the secret on failure', async () => {
  let calls=0, time=now;
  const request=createEodhdClient({key:()=> 'private-test-token',clock:()=>time,fetcher:async url=>{
    calls++; assert.equal(url.origin,'https://eodhd.com'); assert.equal(url.searchParams.get('api_token'),'private-test-token');
    return Response.json([asset]);
  }});
  await Promise.all([request('search/ITX'),request('search/ITX')]); assert.equal(calls,1);
  time+=60001; await request('search/ITX'); assert.equal(calls,2);
  const failed=createEodhdClient({key:()=> 'private-test-token',fetcher:async()=>{throw Error('https://eodhd.com/?api_token=private-test-token');}});
  await assert.rejects(failed('search/ITX'),error=>error.code==='MARKET_UNAVAILABLE'&&!String(error).includes('private-test-token'));
  const limited=createEodhdClient({key:()=> 'key',fetcher:async()=>new Response('',{status:429})});
  await assert.rejects(limited('search/ITX'),{code:'MARKET_RATE_LIMIT'});
});
test('daily fallback preserves session date, native currency and source through USD settlement', async () => {
  const market=createEodhdMarket({clock:()=>now,request:async path=> {
    if(path.startsWith('search/')) return [asset];
    if(path.startsWith('real-time/')) return {code:'WRONG',close:50,timestamp:now/1000,change_p:1};
    return [{date:'2026-09-07',close:50},{date:'2026-09-04',close:40}];
  }});
  const quote=await market.quote('ITX.MC');
  assert.equal(quote.mode,'eod'); assert.equal(quote.regularMarketTime.toISOString(),'2026-09-07T00:00:00.000Z');
  const settled=await settlementQuote(quote,'ITX.MC',async symbol=>({symbol,regularMarketPrice:1.1,regularMarketTime:new Date(now)}),now);
  assert.equal(settled.source,'EODHD'); assert.equal(settled.priceCents,5500);assert.equal(settled.nativeCurrency,'EUR');
  assert.equal(settled.marketOpen,false);assert.equal(settled.tradable,false);
});
test('invalid EODHD response falls through without accepting stale or mismatched data', async () => {
  const valid=symbol=>({symbol,currency:'EUR',quoteType:'EQUITY',marketState:'CLOSED',regularMarketPrice:50,regularMarketChangePercent:1,regularMarketTime:new Date(now)});
  const load=createMarketQuote({clock:()=>now,primary:async()=>null,additionalEnabled:()=>true,additional:async()=>valid('WRONG'),enabled:()=>true,secondary:async symbol=>valid(symbol)});
  assert.equal((await load('ITX.MC')).source,'Alpha Vantage');
});
test('search merges all providers, deduplicates listings and tolerates provider outages', async () => {
  const search=createSearchService({primary:async()=>({result:[{symbol:'ITX.MC',description:'Inditex',type:'Common Stock'}]}),
    additionalEnabled:()=>true,additional:async()=>normalizeEodhdSearch([asset,{...asset,Exchange:'LSE'}]),enabled:()=>true,secondary:async()=>{throw Error();}});
  const result=await search('ITX');
  assert.deepEqual(result.results.map(x=>x.symbol),['ITX.MC','ITX.L']);assert.equal(result.partial,true);
});
test('daily history reports daily resolution for a weekly viewing range and validates candles', async () => {
  const market=createEodhdMarket({clock:()=>now,request:async path=>path.startsWith('search/')?[asset]:[{date:'2026-09-07',open:50,high:52,low:49,close:51}]});
  const load=createHistoryService({additionalEnabled:()=>true,additional:market.history,enabled:()=>false,secondary:()=>assert.fail('Unnecessary fallback')});
  const result=await load('ITX.MC:1w');
  assert.equal(result.interval,'1d');assert.equal(result.source,'EODHD');assert.equal(result.points[0].close,51);
});

test('Alpha exchange aliases deduplicate against EODHD without merging other listings', async () => {
  const search=createSearchService({primary:async()=>({result:[]}),additionalEnabled:()=>true,
    additional:async()=>[{symbol:'TSCO.L',name:'Tesco',source:'EODHD'}],enabled:()=>true,
    secondary:async()=>[{symbol:'TSCO.LON',name:'Tesco',source:'Alpha Vantage'},{symbol:'TSCO',name:'Tractor Supply',source:'Alpha Vantage'}]});
  assert.deepEqual((await search('TSCO')).results.map(row=>row.symbol),['TSCO','TSCO.L']);
});
