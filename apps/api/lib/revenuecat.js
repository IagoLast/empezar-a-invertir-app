import { timingSafeEqual } from 'node:crypto';
import { APIError, uuid, requireInput } from './http.js';
export const products = { 'ei.cash.10000': 1000000, 'ei.cash.25000': 2500000 };
export function validateEvent(payload, authorization, env) {
  const secret = env.REVENUECAT_WEBHOOK_AUTH;
  if (!secret || !env.REVENUECAT_APP_ID || !['SANDBOX', 'PRODUCTION'].includes(env.REVENUECAT_ENVIRONMENT)) throw new Error('Missing webhook configuration');
  const a = Buffer.from(authorization || ''), b = Buffer.from(secret);
  if (a.length !== b.length || !timingSafeEqual(a, b)) throw new APIError(401, 'UNAUTHORIZED', 'Unauthorized');
  const event = payload.event;
  requireInput(event && typeof event === 'object');
  if (event.type === 'TEST') return null;
  if (event.app_id !== env.REVENUECAT_APP_ID || event.environment !== env.REVENUECAT_ENVIRONMENT || event.store !== 'APP_STORE') return null;
  const kind = event.type === 'NON_RENEWING_PURCHASE' ? 'purchase' : event.type === 'CANCELLATION' && event.cancel_reason === 'CUSTOMER_SUPPORT' ? 'refund' : null;
  if (!kind || !Object.hasOwn(products, event.product_id)) return null;
  requireInput(uuid(event.app_user_id) && typeof event.id === 'string' && event.id.length > 0 && event.id.length <= 200
    && typeof event.transaction_id === 'string' && event.transaction_id.length > 0 && event.transaction_id.length <= 200);
  return { p_event: event.id, p_user: event.app_user_id, p_transaction: event.transaction_id, p_product: event.product_id,
    p_environment: event.environment, p_app: event.app_id, p_kind: kind };
}
