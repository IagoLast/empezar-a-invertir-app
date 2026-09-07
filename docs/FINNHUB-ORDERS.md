# Finnhub and simulated orders

The API uses Finnhub for quotes, search, company metrics and candle requests. `FINNHUB_API_KEY` is a server-only Vercel secret; never put it in iOS configuration. Yahoo dependencies and fallback requests have been removed. Old Yahoo quote caches are not returned as Finnhub prices.

## Verified coverage

The supplied subscription returned US equity/ETF quotes, company profiles, search results, market status and average trading volumes. AAPL, VTI and BND were verified. `stock/candle` and the Madrid symbol `ITX.MC` returned HTTP 403. The app reports unavailable historical data rather than fabricating a chart. Discovery filters to supported US symbol forms, including A/B share classes. The adapter preserves quote timestamps, identifies closed markets, and uses the original source date in the UI.

Finnhub reports average trading volumes in millions of units; the adapter converts these to units/day. Missing volume stays null and uses the middle waiting-time band. This is volume, not measured volatility.

## Execution model

All new orders are explicitly educational simulations using virtual money. The confirmed reference price is locked; a chosen limit simulates that limit being reached (buy: lower of reference and limit; sell: higher). The UI explains that real limit orders may never execute. Closed markets do not prevent this simulation, but unavailable or expired quote references do.

The server chooses a random delay once: 8–15 seconds for at least 10 million average daily units, 15–30 seconds for at least 1 million, 30–60 seconds for lower positive volume, and 20–40 seconds when volume is unknown. A PostgreSQL Cron worker checks due orders every 10 seconds. Normal completion takes at most about 70 seconds, subject to database availability and backlog. A server outage delays execution; it does not discard accepted orders.

Pending buys reserve cash plus the $1 fee. Pending sells reserve units. A shared wallet lock serializes submission, edits, cancellation, legacy trades and execution. Request IDs make submission/retries idempotent; optimistic revisions prevent stale edits. Edits preserve the original execution time. Editing or cancelling after execution starts returns a conflict and the client reloads state. Cancelled orders release their reservation.

`GET /state` is read-only with respect to orders. Foreground polling and pull-to-refresh never submit or execute an order. The database worker continues when the phone is closed or offline. Existing app versions retain their instant-trade endpoint, with reservation checks to protect new orders.

## Deployment sequence

1. Set the server-only `FINNHUB_API_KEY` in the API's Vercel production environment.
2. Run `supabase/migrations/20260907163045_simulated_orders.sql` against the EAI database.
3. Run `supabase/schedule-simulated-orders.sql` and verify the active Cron job and successful job runs.
4. Deploy `apps/api` and verify quotes, search, coverage errors and authentication enforcement.
5. Publish the iOS build through the existing TestFlight workflow.

Rollback the API/app first if needed. Do not drop `simulated_orders` or stop its worker while accepted orders remain pending.

## Validation

`npm test` covers Finnhub response/error handling, quote caching, search, monetary normalization and authenticated order routes. PostgreSQL regression scripts cover reservations, editing, idempotency, cancellation, execution, legacy trades and overspending/overselling. Native UI tests cover editing the review, editing a pending order, automatic completion and cancellation. The database test schema is disposable; production verification must not create trades in a real user's account.

## September 7, 2026 deployment

The migration and 10-second Cron schedule are applied to project `gnodplputnzejhipoxdw`. Cron runs report `succeeded`; authenticated clients cannot execute the worker. The API production deployment is `empezar-a-invertir-ceesiv4ty-iago-lastras-projects.vercel.app`. Production checks returned AAPL quote/volume and search results from Finnhub, HTTP 422 for unavailable history, and HTTP 401 for unauthenticated order submission/cancellation. The post-deploy error log query returned no entries. The iOS release is published separately through TestFlight.
