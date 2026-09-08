# HTTP contract

JSON, integer USD cents for wallet amounts, whole units and ISO 8601 UTC dates. External `market-preview` prices are decimal amounts in the returned currency. Endpoints require `Authorization: Bearer <Supabase access token>` from an Apple/Google identity, except public quote/search/preview/history routes and the independently authenticated webhook. Responses use `Cache-Control: no-store`.

| Method | Route | Input | Output |
|---|---|---|---|
| GET | `/api/state` | — | Portfolio |
| GET | `/api/search?q=NVDA` | Name or symbol, 1–80 characters | `{results: [{symbol, name, kind, exchange, source?}], partial?, notice?}` |
| GET | `/api/market-preview?symbol=NVDA` | Yahoo symbol | `{symbol, price, currency, changePercent, asOf, source, logoURL}`; read-only, decimal price in the specified currency |
| GET | `/api/quote?symbol=AAPL` | Provider stock/ETF symbol, including international listings | Quote |
| GET | `/api/history?symbol=TSCO.LON&range=1m` | `1w`, `1m`, `3m`, `1y`, `5y` | `{symbol, range, currency, source, interval, points: [{date, open, high, low, close}]}` |
| GET | `/api/fundamentals?symbol=AAPL` | AAPL or MSFT | `{available, symbol?, pe?, eps?, period?, source?, fetchedAt?}` |
| POST | `/api/trade` | `{requestId: UUID, symbol, side: buy\|sell, units: 1..100000, quoteId: UUID}` | Portfolio after commit |
| POST | `/api/lesson` | `{lessonId: lesson-1..lesson-4}` | Portfolio |
| DELETE | `/api/account` | — | `{deleted: true}` |
| POST | `/api/revenuecat` | RevenueCat v1 webhook and configured Authorization | `{received: true, appliedCents?, duplicate?, ignored?}` |

**Portfolio**: `userId`, `currency`, `cashCents`, `contributedCents`, `positions`, `quotes`, `orders`, `completedLessons`, `purchases`.

- Position: `{symbol, units, costCents}`; aggregate acquisition cost including buy fees.
- Order: `{id, requestId, symbol, side, units, priceCents, feeCents, createdAt}`; latest 50 returned.
- Purchase: `{transactionId, productId, credited, refunded}`.
- Quote: `{id, symbol, priceCents, currency, changePercent, asOf, fetchedAt, expiresAt, marketOpen, tradable, mode, delaySeconds, source, logoURL?, nativePrice?, nativeCurrency?, exchangeRate?, fxAsOf?, name?, kind?}`.

Missing quotes never produce invented valuations. `equity = cash + sum(units × quote.priceCents)`. `profit = equity - contributedCents` is an absolute result, not a time-weighted return. Stale data is identified.

Errors: `{error: CODE, message: Spanish user-facing message}`. Status codes: `400` invalid input, `401/403` authentication, `409` cash/units/quote/market/idempotency conflict, `422` unsupported asset type, `503` provider or server unavailable.

Pending orders retain their request ID and body. A timeout does not prove failure: resend the same body. The database returns success for an already executed order and rejects reuse with different content. A new quote requires a new review and request ID after resolving the previous attempt.

`quoteId` identifies a server-issued quote with explicit `expiresAt` (Yahoo: at most 20 minutes after retrieval and one hour after the market timestamp). Client prices and user IDs cannot replace the stored price or `auth.uid()`. Disabled instruments, expired data and closed markets cannot trade.

Search, external previews and history use bounded 15-minute per-instance caches. Requesting a trading quote validates the provider's EQUITY/ETF type and registers the instrument through a service-role-only RPC; user-supplied prices never register assets. Portfolio quotes retain the shared PostgreSQL cache. State includes the starter quotes and the user's current holdings, not every globally discovered symbol.

All execution amounts remain USD cents. International quotes preserve `nativePrice`, `nativeCurrency`, `exchangeRate` (USD per native currency unit) and `fxAsOf`. GBP pence, Israeli agorot and South African cents are converted to their major units first. Missing, mismatched, future or FX data at least four days old blocks new execution quotes. Quote expiry is also capped by FX expiry. Historical OHLC stays in the provider's original currency/unit and is never used to execute trades.

Apply `supabase/migrations/202609070001_global_markets.sql` before deploying the expanded quote API. Existing positions and wallets keep their USD accounting.


## Simulated orders (Finnhub migration)

`POST /api/orders` requires a social-login session and accepts `requestId`, `symbol`, `side` (`buy`/`sell`), integer `units`, server `quoteId`, optional `limitCents`, and optional `revision` when editing. Returns portfolio state, including `reservedCashCents` and `simulatedOrders`. Reuse the exact request ID and payload after a lost response. An edit uses the original ID and current revision; it does not postpone execution. The client never supplies an execution time, volume or final fill price.

`DELETE /api/orders` accepts `requestId` and `revision` and cancels a still-editable pending order. `ORDER_CHANGED` and `ORDER_FINISHED` return HTTP 409. Authentication is required for both methods; clients can only mutate their own orders.

A simulated order includes `id`, `symbol`, `side`, `units`, `priceCents`, optional `limitCents`, `status` (`pending`/`executed`/`cancelled`), `revision`, `createdAt`, `executeAt`, and nullable `averageDailyVolume`. Quotes also include nullable `averageDailyVolume` in units/day. Read `docs/FINNHUB-ORDERS.md` for simulation assumptions and provider coverage.

`GET /api/state` never executes orders. The server's scheduled worker handles completion independently. The legacy `POST /api/trade` remains available to existing builds and respects reservations.

## Multiple market providers

Finnhub remains the primary US quote provider. Alpha Vantage supplements international discovery, daily/weekly history, FX and end-of-day quote fallback. Each quote/series names its actual `source`. Alpha session dates use UTC midnight and `mode=eod`; `marketOpen=false` means no live session assertion for these quotes, not confirmed current closure. Legacy `tradable` remains false for daily prices; simulated orders validate the actual stored reference age/expiry.

`history.interval` describes actual candles (`1d`, `1wk`, or Finnhub's requested interval). Long Alpha ranges use weekly data; they do not claim daily/intraday resolution. Foreign candles use native major currency; USD-settled quotes expose native price and FX metadata. Query results can include `partial=true` and `notice` when only one provider is available. Alpha Vantage has a persistent server-side cache, a shared daily budget, and a burst limiter; see `docs/FINNHUB-ORDERS.md`.

## Simple investing and EODHD

`POST /api/orders` now returns the updated portfolio after immediate virtual execution. Request IDs remain idempotent. Search, quotes and history can report `source=EODHD`; the source is preserved through USD settlement. Symbols use the existing canonical listing format (for example `ITX.MC`, `TSCO.L`, `AAPL`), not EODHD-specific suffixes. No client provider selection is needed. See [market providers](../../docs/MARKET-PROVIDERS.md) for mapping, cache lifetimes, migration and legacy order compatibility.

`GET /api/company-logo?symbol=AAPL` is public and returns `{symbol, logoURL: string | null}`. The optional image URL belongs to a validated Finnhub HTTPS host; absence of a logo does not affect quote availability.
