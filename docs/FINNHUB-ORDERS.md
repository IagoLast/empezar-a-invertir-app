# Market data and simulated orders

The API combines Finnhub and Alpha Vantage. Finnhub remains the primary source for US quotes and company metrics. Alpha Vantage supplies daily/weekly history, international search and end-of-day quote fallback. `FINNHUB_API_KEY` is a server-only Vercel secret; never put it in iOS configuration. Yahoo dependencies and fallback requests have been removed. Old Yahoo quote caches are not returned as Finnhub prices.

## Verified coverage

The supplied subscription returned US equity/ETF quotes, company profiles, search results, market status and average trading volumes. AAPL, VTI and BND were verified. `stock/candle` and the Madrid symbol `ITX.MC` returned HTTP 403. The app reports unavailable historical data rather than fabricating a chart. Finnhub discovery filters to supported US symbol forms, including A/B share classes. Alpha Vantage adds exact provider symbols such as `TSCO.LON`; suffixes are never guessed or rewritten. The adapter preserves quote timestamps, identifies closed markets, and uses the original source date in the UI.

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

## Alpha Vantage integration

Set server-only `ALPHA_VANTAGE_API_KEY` and apply `20260907174106_alpha_vantage_cache.sql` and `20260907174558_provider_instruments.sql` before deploying the combined API. Default `ALPHA_VANTAGE_DAILY_LIMIT=25`; increase it only after the provider approves a higher quota. No automatic educational entitlement is assumed.

The shared PostgreSQL cache stores successful raw responses (daily/weekly candles: 24 hours, symbol metadata/search: 7 days, FX: 1 hour). A service-role-only reservation function serializes a global daily request budget and spaces requests at least 1.25 seconds apart across serverless instances. Duplicate requests reuse a lease; cached responses still work when the quota is exhausted. The counter resets at UTC midnight; provider-side limits are also handled. Provider error responses are sanitized and briefly cached; credentials are never stored in cache keys or returned in errors. Do not use the same key elsewhere without accounting for those requests.

US quotes prefer Finnhub. A failed/invalid Finnhub response can fall back to Alpha's daily series; foreign Alpha symbols route directly to Alpha. Quote IDs and original dates remain intact in the shared quote cache on provider failures. Alpha data has `mode=eod`, `tradable=false` for the legacy real-time gate, and a session date at UTC midnight. It does not claim to know whether the exchange is currently open. New educational orders can use a recent valid daily reference, as with closed-market quotes. No intraday data is invented.

Foreign assets require exact search metadata (type/currency), actual daily candles and a fresh `CURRENCY_EXCHANGE_RATE` quote for USD settlement. Minor units such as GBX are converted once to GBP. Missing FX blocks the quote. History remains in native major currency. Daily trading volume is averaged over up to 10 valid observations; missing values stay unknown.

Short history ranges use compact daily data (up to 100 sessions). One/five-year ranges use weekly data and return `interval=1wk`; the iOS chart labels the resolution. A chart uses one provider's complete series and never splices price levels between providers. Search combines and deduplicates both sources for queries of at least three characters; shorter queries use Finnhub. If one source fails, available results remain visible with a partial-results notice.

Initial live verification: AAPL daily candles succeeded; Tesco search returned `TSCO.LON` in GBX; Inditex search returned no matches. Global coverage is selective, not every exchange or ticker. The key reported the free 25/day and 1/second limits. Endpoint availability and educational/display licensing remain independent of API-key validity.
