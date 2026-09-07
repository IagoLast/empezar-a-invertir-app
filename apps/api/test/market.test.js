import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeQuote, normalizeFundamentals, priceCents, createQuoteService, QUOTE_CACHE_MS } from '../lib/market.js';
const now = Date.parse('2026-09-04T15:30:00Z');
const fixture = () => ({ quoteType: 'EQUITY', symbol: 'AAPL', currency: 'USD', regularMarketPrice: 319.97, regularMarketTime: new Date(now - 20 * 60000), regularMarketChangePercent: -2.51, marketState: 'REGULAR', logoUrl: 'https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/AAPL.png' });
test('monetary amounts round to cents without float multiplication', () => {
  assert.equal(priceCents('1.00500'), 101); assert.equal(priceCents('319.97000'), 31997);
  for (const value of ['0', '-2', 'NaN', '1e5', 100, null, '999999999']) assert.throws(() => priceCents(value));
});
test('educational trades accept delayed prices and expose actual timestamps', () => {
  const q = normalizeQuote(fixture(), 'AAPL', now);
  assert.equal(q.tradable, true); assert.equal(q.mode, 'cached'); assert.equal(q.priceCents, 31997);
  assert.equal(q.asOf, new Date(now - 20 * 60000).toISOString());
  assert.equal(Date.parse(q.expiresAt), now + 20 * 60000);
  assert.equal(q.source, 'Finnhub'); assert.equal(q.logoURL, fixture().logoUrl);
});
test('weekend closing prices remain visible and cannot execute trades', () => {
  const q = normalizeQuote({ ...fixture(), marketState: 'CLOSED' }, 'AAPL', now + 2 * 86400000);
  assert.equal(q.marketOpen, false); assert.equal(q.tradable, false);
});
test('one-hour-old prices and pre/post-market quotes cannot execute trades', () => {
  assert.equal(normalizeQuote({ ...fixture(), regularMarketTime: new Date(now - 3600000) }, 'AAPL', now).tradable, false);
  for (const marketState of ['PRE', 'PREPRE', 'POST', 'POSTPOST']) assert.equal(normalizeQuote({ ...fixture(), marketState }, 'AAPL', now).tradable, false);
});
test('execution validity never extends a quote beyond one hour from its source timestamp', () => {
  const q = normalizeQuote({ ...fixture(), regularMarketTime: new Date(now - 55 * 60000) }, 'AAPL', now);
  assert.equal(Date.parse(q.expiresAt), now + 5 * 60000);
});
test('rejects mismatched, malformed, future and excessively old market data', () => {
  for (const patch of [{symbol:'MSFT'}, {currency:'EUR'}, {marketState:'UNKNOWN'}, {regularMarketTime:null}, {regularMarketTime:new Date(now+120000)}, {regularMarketTime:new Date(0)}, {regularMarketPrice:NaN}, {regularMarketPrice:-1}, {regularMarketChangePercent:null}]) assert.throws(() => normalizeQuote({...fixture(),...patch},'AAPL',now));
});
test('logos are optional and restricted to the Finnhub HTTPS image host', () => {
  for (const logoUrl of [undefined, 'http://s.yimg.com/logo.png', 'https://evil.example/logo.png']) assert.equal(normalizeQuote({...fixture(),logoUrl},'AAPL',now).logoURL,null);
});
test('fundamentals preserve missing values rather than inventing zero', () => {
  assert.deepEqual(normalizeFundamentals({...fixture(),trailingPE:32,epsTrailingTwelveMonths:8},'AAPL',now), {available:true,symbol:'AAPL',pe:32,eps:8,period:'TTM',source:'Finnhub',fetchedAt:new Date(now).toISOString()});
  assert.equal(normalizeFundamentals(fixture(),'AAPL',now).available,false);
  assert.equal(normalizeFundamentals({...fixture(),trailingPE:0},'AAPL',now).pe,0);
});
test('shared cache prevents Finnhub requests for fifteen minutes', async () => {
  const quote = normalizeQuote(fixture(),'AAPL',now);
  let calls=0;
  const get=createQuoteService({clock:()=>now+QUOTE_CACHE_MS-1, database:async()=>({quote,refresh:true}),loadQuote:async()=>{calls++;throw Error();}});
  assert.deepEqual(await get('AAPL'),quote);assert.equal(calls,0);
});
test('expired cache refreshes and persists a new quote', async () => {
  const quote=normalizeQuote(fixture(),'AAPL',now);let saved;
  const get=createQuoteService({clock:()=>now+QUOTE_CACHE_MS, database:async(name,args)=>name==='quote_cache'?{quote,refresh:true}:(saved=args.p_quote),loadQuote:async()=>fixture()});
  const result=await get('AAPL');assert.equal(saved,result);assert.notEqual(result.id,quote.id);
});
test('provider failure preserves stale timestamps and does not save a fake fresh quote', async () => {
  const quote=normalizeQuote(fixture(),'AAPL',now);let writes=0;
  const get=createQuoteService({clock:()=>now+3600000,database:async(name)=>name==='quote_cache'?{quote,refresh:true}:writes++,loadQuote:async()=>{throw Error('offline');}});
  assert.deepEqual(await get('AAPL'),{...quote,tradable:false});assert.equal(writes,0);
});
test('refresh lease prevents duplicate provider calls and cold-cache failure is explicit', async () => {
  const get=createQuoteService({database:async()=>({quote:null,refresh:false}),loadQuote:async()=>{assert.fail('must not call Finnhub');}});
  await assert.rejects(get('AAPL'),{code:'QUOTE_LOADING'});
  const unavailable=createQuoteService({database:async()=>({refresh:true}),loadQuote:async()=>{throw Error('offline');}});
  await assert.rejects(unavailable('AAPL'),{code:'MARKET_UNAVAILABLE'});
});
