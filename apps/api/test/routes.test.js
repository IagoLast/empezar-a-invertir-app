import test from 'node:test';
import assert from 'node:assert/strict';
import { GET as state } from '../api/state.js';
import { POST as trade } from '../api/trade.js';
import { POST as webhook } from '../api/revenuecat.js';
const user = '11111111-1111-4111-8111-111111111111';
const requestId = '22222222-2222-4222-8222-222222222222';
const quoteId = '33333333-3333-4333-8333-333333333333';
const env = () => { process.env.SUPABASE_URL = 'https://project.example'; process.env.SUPABASE_ANON_KEY = 'test-anon'; };
const req = value => new Request('https://app.example/api/trade', { method: 'POST', headers: { authorization: 'Bearer test-token' }, body: JSON.stringify(value) });
test('unauthenticated portfolio access fails before database request', async () => {
  const result = await state(new Request('https://app.example/api/state')); assert.equal(result.status, 401);
});
test('HTTP methods are enforced', async () => { assert.equal((await state(new Request('https://app.example/api/state', { method: 'POST' }))).status, 405); });
test('invalid quantities and client prices never reach RPC', async t => {
  env(); let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => { calls++; return Response.json({ id: user, email_confirmed_at: '2026-01-01' }); });
  for (const units of [0, -1, 1.2, '1', 100001]) assert.equal((await trade(req({ requestId, quoteId, symbol: 'AAPL', side: 'buy', units }))).status, 400);
  assert.equal(calls, 5);
});
test('trade only passes identity from JWT and uses quote ID, not client price', async t => {
  env(); let rpcBody;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    if (url.endsWith('/auth/v1/user')) return Response.json({ id: user, email_confirmed_at: '2026-01-01' });
    rpcBody = JSON.parse(options.body); assert.equal(options.headers.Authorization, 'Bearer test-token'); return Response.json({ cashCents: 500000 });
  });
  const result = await trade(req({ requestId, quoteId, symbol: 'AAPL', side: 'buy', units: 2, userId: 'attacker', priceCents: 1 }));
  assert.equal(result.status, 200); assert.deepEqual(rpcBody, { p_request: requestId, p_symbol: 'AAPL', p_side: 'buy', p_units: 2, p_quote: quoteId });
});
test('database rejects stale quote with recoverable conflict', async t => {
  env(); t.mock.method(globalThis, 'fetch', async url => url.endsWith('/auth/v1/user') ? Response.json({ id: user, email_confirmed_at: '2026-01-01' }) : Response.json({ message: 'STALE_QUOTE' }, { status: 400 }));
  const result = await trade(req({ requestId, quoteId, symbol: 'AAPL', side: 'buy', units: 2 }));
  assert.equal(result.status, 409); assert.equal((await result.json()).error, 'STALE_QUOTE');
});
test('malformed webhook body is rejected', async () => {
  assert.equal((await webhook(new Request('https://app.example/api/revenuecat', { method: 'POST', body: '{' }))).status, 400);
});
