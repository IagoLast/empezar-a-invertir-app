import { APIError } from './http.js';

// Validate inside each attempt so malformed or empty successes also trigger fallback.
export async function firstValidProvider(attempts, validate, unavailableMessage) {
  const failures = [];
  for (const attempt of attempts) {
    try { return await validate(await attempt()); }
    catch (error) { failures.push(error); }
  }
  const uncovered = failures.length > 0 && failures.every(error =>
    ['MARKET_NOT_COVERED', 'ASSET_UNSUPPORTED', 'HISTORY_UNAVAILABLE'].includes(error?.code));
  throw new APIError(uncovered ? 422 : 503, uncovered ? 'MARKET_NOT_COVERED' : 'MARKET_UNAVAILABLE', unavailableMessage);
}
