import test from 'node:test';
import assert from 'node:assert/strict';
import { rpc } from '../lib/supabase.js';
import { DELETE } from '../api/account.js';
function environment(t, key, value) {
  const previous = process.env[key];
  process.env[key] = value;
  t.after(() => { if (previous === undefined) delete process.env[key]; else process.env[key] = previous; });
}

test('sandbox RPC uses the separate schema while keeping the authenticated identity', async t => {
  environment(t, 'SUPABASE_DB_SCHEMA', 'ea_sandbox');
  environment(t, 'SUPABASE_URL', 'https://db.example');
  environment(t, 'SUPABASE_ANON_KEY', 'public-key');
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    assert.equal(url, 'https://db.example/rest/v1/rpc/get_state');
    assert.equal(options.headers['Content-Profile'], 'ea_sandbox');
    assert.equal(options.headers.Authorization, 'Bearer user-session');
    return Response.json({ cashCents: 0 });
  });
  assert.deepEqual(await rpc('get_state', {}, 'Bearer user-session'), { cashCents: 0 });
});
test('sandbox account deletion never deletes the shared authentication account', async t => {
  environment(t, 'SUPABASE_DB_SCHEMA', 'ea_sandbox');
  environment(t, 'SUPABASE_URL', 'https://db.example');
  environment(t, 'SUPABASE_ANON_KEY', 'public-key');
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async url => {
    calls++;
    assert.equal(url, 'https://db.example/auth/v1/user');
    return Response.json({ id: '11111111-1111-4111-8111-111111111111', app_metadata: { providers: ['apple'] } });
  });
  const result = await DELETE(new Request('https://app.example/api/account', { method: 'DELETE', headers: { Authorization: 'Bearer user-session' } }));
  assert.equal(result.status, 403);
  assert.equal((await result.json()).error, 'SANDBOX_ACCOUNT_DELETION_DISABLED');
  assert.equal(calls, 1);
});
