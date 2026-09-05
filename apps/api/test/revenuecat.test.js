import test from 'node:test';
import assert from 'node:assert/strict';
import { validateEvent } from '../lib/revenuecat.js';
const env = { REVENUECAT_WEBHOOK_AUTH: 'Bearer test-only', REVENUECAT_APP_ID: 'app_test', REVENUECAT_ENVIRONMENT: 'SANDBOX' };
const event = () => ({ event: { id: 'evt-1', type: 'NON_RENEWING_PURCHASE', app_id: 'app_test', environment: 'SANDBOX', store: 'APP_STORE', app_user_id: '11111111-1111-4111-8111-111111111111', transaction_id: 'tx-1', product_id: 'ei.cash.10000' } });
test('valid consumable maps to server-controlled product, never payload credit', () => {
  const e = event(); e.event.credits = 999999999;
  const result = validateEvent(e, env.REVENUECAT_WEBHOOK_AUTH, env);
  assert.equal(result.p_kind, 'purchase'); assert.equal(result.p_product, 'ei.cash.10000'); assert.equal(result.credits, undefined);
});
test('rejects unauthenticated, truncated and empty webhook authorization', () => {
  for (const auth of [null, '', 'Bearer wrong', 'Bearer test-only ']) assert.throws(() => validateEvent(event(), auth, env), { status: 401 });
});
test('isolates app, environment and store', () => {
  for (const patch of [{ app_id: 'other' }, { environment: 'PRODUCTION' }, { store: 'PLAY_STORE' }]) {
    const e = event(); Object.assign(e.event, patch); assert.equal(validateEvent(e, env.REVENUECAT_WEBHOOK_AUTH, env), null);
  }
});
test('ignores unknown products and events without granting currency', () => {
  for (const patch of [{ product_id: 'ei.cash.999999' }, { type: 'RENEWAL' }, { type: 'TRANSFER' }]) {
    const e = event(); Object.assign(e.event, patch); assert.equal(validateEvent(e, env.REVENUECAT_WEBHOOK_AUTH, env), null);
  }
});
test('supports store refund events', () => {
  const e = event(); Object.assign(e.event, { type: 'CANCELLATION', cancel_reason: 'CUSTOMER_SUPPORT' });
  assert.equal(validateEvent(e, env.REVENUECAT_WEBHOOK_AUTH, env).p_kind, 'refund');
});
test('requires durable app user identity and transaction id', () => {
  for (const patch of [{ app_user_id: '$RCAnonymousID:test' }, { transaction_id: '' }]) {
    const e = event(); Object.assign(e.event, patch); assert.throws(() => validateEvent(e, env.REVENUECAT_WEBHOOK_AUTH, env), { status: 400 });
  }
});
