# Market data and simple investing

The native app has four destinations: Inicio (financial summary), Invertir (search and a purchase), Operaciones (trade history and legacy pending actions), and Aprender (the existing book).

## Backend normalization

The client uses the same search, quote and history endpoints regardless of provider. Finnhub is the first quote source, EODHD the next, and Alpha Vantage the final fallback. History prefers EODHD, then Alpha Vantage, then Finnhub. Search merges enabled sources concurrently, ranks exact matches first and deduplicates by listing symbol. A provider failure does not discard other results.

EODHD maps exchange-qualified identifiers to the existing canonical catalog: `AAPL.US` → `AAPL`, `ITX.MC` → `ITX.MC`, `TSCO.LSE` → `TSCO.L`, `SAP.XETRA` → `SAP.DE`, `BRK-B.US` → `BRK.B`. Alpha Vantage aliases `.LON`, `.DEX` and `.FRK` also normalize to `.L`, `.DE` and `.F` before deduplication, and canonical requests translate back at the provider boundary. Existing provider-qualified wallet symbols remain accepted. Unmapped EODHD exchanges are excluded instead of guessed. Different listings of a company remain different assets. EODHD metadata must match the requested listing before its currency is used.

Quotes retain the actual provider, market timestamp and native currency. Wallet settlement remains USD with explicit FX conversion; pence and other minor currency units are scaled first. Delayed endpoints do not establish exchange opening status. Daily fallback uses the original session date with `mode=eod`, never the retrieval time. Daily history reports `interval=1d`, even for a one-week viewing range; OHLC bars are unadjusted and are not mixed with adjusted closes.

EODHD requests use an 8-second timeout, a bounded per-instance cache and concurrent request sharing. Search metadata caches for 15 minutes, historical requests for one hour, and delayed prices for one minute. The existing shared PostgreSQL quote cache still limits cross-instance price requests. EODHD discovery/history caches are per-instance, not a global daily quota; account limits still apply. Credentials and upstream error bodies are never returned to clients.

## Configuration

Set `EODHD_API_KEY` in the backend environment. It is optional: when absent the existing providers continue working. Use `apps/api/.env.local` locally (gitignored), then run `npm run dev:api`. Configure Supabase credentials there too, or explicitly load the existing backend environment. Never embed provider keys in the iOS plist.

Official EODHD references:

- [Search and instrument metadata](https://eodhd.com/financial-apis/search-api-for-stocks-etfs-mutual-funds)
- [Delayed prices](https://eodhd.com/financial-apis/live-ohlcv-stocks-api)
- [Daily and weekly OHLC history](https://eodhd.com/financial-apis/api-for-historical-data-and-volumes)

## Execution

Apply migrations in filename order, including `20260908120000_simple_investing.sql`. Explicit order submission now fills immediately in the same PostgreSQL transaction, updating the wallet, position, order history and ledger. Stored quotes from Finnhub, Alpha Vantage and EODHD are accepted only while unexpired and no more than seven days old. This is educational execution with virtual money, including outside market hours; EODHD supplies data, not brokerage execution.

Request IDs remain idempotent after a lost response. Wallet locks prevent overspending and overselling; the immediate worker only settles the submitting wallet. Existing delayed orders retain the scheduled worker and explicit cancellation/editing controls. Legacy limit orders remain supported by the backend for older clients, and the app offers market and limit orders with a short explanation. A chosen limit remains an explicitly simulated fill, not proof that the market reached it.

`GET /state` and pull-to-refresh remain read-only with respect to trades. The background cron still handles older queued orders independently of the app. Do not run `test-*.sql` against a live database.

## Verification

`npm test` covers provider mapping, merging, fallbacks, currency settlement, invalid data and credential redaction. CI applies all migrations to disposable PostgreSQL, runs the previous regression suites, then `supabase/test-simple-investing.sql` for immediate execution, idempotency, invalid prices, wallet accounting and account isolation. Native UI tests cover editing the review, immediate history/position updates, closed-session simulation and lost-response retry.

Verified on September 8, 2026: 72 backend tests; all disposable PostgreSQL regression suites; 30 native unit tests and six UI flows. The migration is applied to the app backend and the production API returns EODHD quotes/history for `ITX.MC`, with EUR-to-USD settlement. Published Inditex search has no duplicate Alpha exchange aliases. The final iOS build is installed locally with verified simulator signing; this is not a TestFlight release.

The Invest screen starts with an empty search prompt and only renders backend search results. It does not append bundled instruments or static suggestions, and portfolio refresh fetches prices only for held positions. Order entry exposes market/limit selection, contextual education and an explicit simulated-fill explanation.

## Logos and loading layout

`GET /api/company-logo?symbol=AAPL` returns `{symbol, logoURL}` independently of quotes. Finnhub profile identity must exactly match the requested listing; only its trusted HTTPS image hosts are accepted. Missing logos return `null`. Responses have shared CDN caching, and the client loads logos only for displayed assets. No provider key is embedded in image URLs. EODHD's separate PNG logo endpoint returned HTTP 403 with the configured account on September 8, so it is not used.

The search header remains outside the scrolling results and reserves the clear control's width. The detail price card keeps the same metadata slots during loading; the chart reserves its plot and footer sizes for loading, success and unavailable states. Placeholders are excluded from accessibility announcements where they represent unavailable values.
