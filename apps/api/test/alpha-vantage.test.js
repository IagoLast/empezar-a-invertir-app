import test from 'node:test';
import assert from 'node:assert/strict';
import { createAlphaClient, createAlphaMarket, normalizeAlphaSearch } from '../lib/alpha-vantage.js';
import { createMarketQuote } from '../lib/providers.js';
import { createSearchService } from '../lib/search.js';
import { createHistoryService } from '../lib/history.js';
import { settlementQuote } from '../lib/market.js';
const match = (symbol='AAPL', currency='USD') => ({'1. symbol':symbol,'2. name':'Example','3. type':'Equity','4. region':'Example market','8. currency':currency});
const series = symbol => ({'Meta Data':{'2. Symbol':symbol},'Time Series (Daily)':{
  '2026-09-04':{'1. open':'100','2. high':'110','3. low':'95','4. close':'105','5. volume':'1000'},
  '2026-09-03':{'1. open':'95','2. high':'105','3. low':'90','4. close':'100','5. volume':'2000'},
}});
const now=Date.parse('2026-09-07T18:00:00Z');
test('Alpha caches success and does not put credentials in persistent cache keys',async()=>{
  let calls=0,saved;
  const request=createAlphaClient({key:()=> 'test-secret',database:async(name,args)=>{
    assert.ok(!JSON.stringify(args).includes('test-secret'));
    if(name==='save_alpha_response'){saved=args.p_data;return;}
    return saved?{data:saved}:{ticket:'lease'};
  },fetcher:async url=>{calls++;assert.equal(url.searchParams.get('apikey'),'test-secret');return Response.json({bestMatches:[]});}});
  await request({function:'SYMBOL_SEARCH',keywords:'AAPL'});await request({function:'SYMBOL_SEARCH',keywords:'AAPL'});
  assert.equal(calls,1);
});
test('Alpha quota stops the network request and cached responses remain usable',async()=>{
  const request=createAlphaClient({key:()=> 'key',database:async()=>({limited:true}),fetcher:()=>assert.fail('Must not spend quota')});
  await assert.rejects(request({function:'TIME_SERIES_DAILY',symbol:'AAPL'}),{code:'MARKET_RATE_LIMIT'});
});
test('Alpha treats HTTP 200 quota and premium notices as errors and sanitizes network errors',async()=>{
  for(const [data,code] of [[{Information:'25 requests per day rate limit'},'MARKET_RATE_LIMIT'],[{Information:'premium endpoint'},'MARKET_NOT_COVERED'],[{'Error Message':'Invalid API call'},'MARKET_NOT_COVERED']]){
    const request=createAlphaClient({key:()=> 'secret',database:async name=>name==='reserve_alpha_request'?{ticket:'lease'}:null,fetcher:async()=>Response.json(data)});
    await assert.rejects(request({function:'TEST'}),{code});
  }
  const request=createAlphaClient({key:()=> 'secret',database:async()=>({ticket:'lease'}),fetcher:async()=>{throw Error('https://example?apikey=secret');}});
  await assert.rejects(request({function:'TEST'}),error=>error.code==='MARKET_UNAVAILABLE'&&!error.message.includes('secret'));
});
test('Alpha obeys shared burst waits before sending a request',async()=>{
  let reserves=0,waited=0;
  const request=createAlphaClient({key:()=> 'key',database:async name=>name==='reserve_alpha_request'?(++reserves===1?{waitMs:1200}:{ticket:'lease'}):null,wait:async ms=>{waited+=ms;},fetcher:async()=>Response.json({bestMatches:[]})});
  await request({function:'SYMBOL_SEARCH',keywords:'AAPL'});assert.equal(waited,1200);
});
test('international search preserves exact provider symbols and rejects unsupported assets',()=>{
  assert.equal(normalizeAlphaSearch({bestMatches:[match('TSCO.LON','GBX')]})[0].symbol,'TSCO.LON');
  assert.deepEqual(normalizeAlphaSearch({bestMatches:[{...match(),'3. type':'Cryptocurrency'}]}),[]);
});
test('daily fallback preserves session date, source, volume and non-live status',async()=>{
  const market=createAlphaMarket({clock:()=>now,request:async p=>p.function==='SYMBOL_SEARCH'?{bestMatches:[match()]}:series('AAPL')});
  const raw=await market.quote('AAPL');const quote=await settlementQuote(raw,'AAPL',market.quote,now);
  assert.equal(quote.source,'Alpha Vantage');assert.equal(quote.mode,'eod');assert.equal(quote.tradable,false);
  assert.equal(quote.asOf,'2026-09-04T00:00:00.000Z');assert.equal(quote.averageDailyVolume,1500);assert.equal(quote.priceCents,10500);
});
test('foreign daily prices convert minor units once and require an actual FX quote',async()=>{
  const market=createAlphaMarket({clock:()=>now,request:async p=>p.function==='SYMBOL_SEARCH'?{bestMatches:[match('TSCO.LON','GBX')]}:p.function==='CURRENCY_EXCHANGE_RATE'?{'Realtime Currency Exchange Rate':{'1. From_Currency Code':'GBP','3. To_Currency Code':'USD','5. Exchange Rate':'1.25','6. Last Refreshed':'2026-09-07 12:00:00','7. Time Zone':'UTC'}}:series('TSCO.LON')});
  const quote=await settlementQuote(await market.quote('TSCO.LON'),'TSCO.LON',market.quote,now);
  assert.equal(quote.nativeCurrency,'GBP');assert.equal(quote.nativePrice,1.05);assert.equal(quote.priceCents,131);
  const history=await market.history('TSCO.LON',{days:31});assert.equal(history.meta.currency,'GBP');assert.equal(history.quotes[0].close,1.05);
});
test('long history uses weekly data and labels the actual resolution',async()=>{
  let used;
  const market=createAlphaMarket({clock:()=>now,request:async p=>{used=p.function;if(p.function==='SYMBOL_SEARCH')return {bestMatches:[match()]};const d=series('AAPL');return {'Meta Data':d['Meta Data'],'Weekly Time Series':d['Time Series (Daily)']};}});
  const result=await market.history('AAPL',{days:366});assert.equal(used,'TIME_SERIES_WEEKLY');assert.equal(result.meta.interval,'1wk');
});
test('Finnhub remains first choice and only failure invokes the fallback',async()=>{
  let fallback=0;const first={symbol:'AAPL',currency:'USD',quoteType:'EQUITY',marketState:'CLOSED',regularMarketChangePercent:1,regularMarketPrice:100,regularMarketTime:new Date(now)};
  const good=createMarketQuote({clock:()=>now,primary:async()=>first,secondary:async()=>{fallback++;},enabled:()=>true});
  assert.equal((await good('AAPL')).source,'Finnhub');assert.equal(fallback,0);
  const bad=createMarketQuote({clock:()=>now,primary:async()=>({...first,regularMarketPrice:0}),secondary:async()=>({...first,source:'Alpha Vantage'}),enabled:()=>true});
  assert.equal((await bad('AAPL')).source,'Alpha Vantage');
});
test('search merges providers without duplicate tickers and survives one source failing',async()=>{
  const search=createSearchService({primary:async()=>({result:[{symbol:'AAPL',type:'Common Stock'}]}),secondary:async()=>[{symbol:'AAPL'},{symbol:'TSCO.LON'}],enabled:()=>true});
  assert.deepEqual((await search('apple')).results.map(r=>r.symbol),['AAPL','TSCO.LON']);
  const limited=createSearchService({primary:async()=>({result:[{symbol:'AAPL',type:'Common Stock'}]}),secondary:async()=>{throw Error();},enabled:()=>true});
  const result=await limited('apple');assert.equal(result.results.length,1);assert.equal(result.partial,true);
});
test('history preserves provider attribution and falls back without merging candle series',async()=>{
  const raw={meta:{symbol:'AAPL',currency:'USD',source:'Alpha Vantage',interval:'1d'},quotes:[{date:new Date(now),open:1,high:2,low:1,close:2}]};
  const history=createHistoryService({enabled:()=>true,primary:async()=>raw,secondary:async()=>assert.fail()});
  assert.equal((await history('AAPL:1m')).source,'Alpha Vantage');
  const fallback=createHistoryService({enabled:()=>true,primary:async()=>{throw Error();},secondary:async()=>({...raw,meta:{...raw.meta,source:'Finnhub'}})});
  assert.equal((await fallback('AAPL:1m')).source,'Finnhub');
});
