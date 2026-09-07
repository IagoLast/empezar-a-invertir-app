# Service setup

## 1. Supabase

1. Create a Supabase project.
2. Apply `supabase/migrations/202609050001_initial.sql` and then `supabase/migrations/202609070001_global_markets.sql` in the SQL Editor. The initial migration targets a new database; existing installations need only the global-markets migration before deploying the expanded API. Never run `test-*.sql` against this project: those files create identities and data for disposable test databases only.
3. Under Authentication → Providers, enable Google and configure its Google Cloud client ID/secret. Register `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback` as an authorized Google redirect URI.
4. Enable Apple. Register `com.empezarainvertir.app` as the native App ID, add the bundle ID to Supabase's accepted client IDs and enable Sign in with Apple in Apple Developer.
5. Add `empezar://auth-callback` under Authentication → URL Configuration → Redirect URLs. Google uses OAuth with PKCE; Apple uses native AuthenticationServices with a nonce.
6. Disable email and anonymous authentication. The API accepts Apple and Google identities only.
7. Keep the project URL, public publishable/anon key and server service-role/secret key. The server key belongs only in backend configuration.

RLS limits reads to each user's portfolio. Clients cannot write balances, positions, quotes or payment transactions. Trading RPCs use `auth.uid()`, lock the wallet row and record the order and ledger movement in one transaction.

## 2. Vercel

Import the repository with **Root Directory = `apps/api`**, framework **Other**, no build command and no custom output directory. `api/*.js` handlers become Node.js functions at `/api/state`, `/api/quote`, etc.

Copy values from `apps/api/.env.example` into Vercel environment variables:

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | Public publishable/anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | Secret server key for data/payment RPCs and account deletion |
| `ENABLE_FUNDAMENTALS` | `true` enables Yahoo P/E and EPS with a 24-hour cache; `false` disables them |
| `REVENUECAT_WEBHOOK_AUTH` | Long random value RevenueCat sends exactly in Authorization |
| `REVENUECAT_APP_ID` | RevenueCat iOS app ID; currently `app899c976007` |
| `REVENUECAT_ENVIRONMENT` | `SANDBOX` for development/TestFlight or `PRODUCTION` |

Use separate Vercel/Supabase projects for sandbox and production. Configure one environment-filtered RevenueCat webhook per backend. Their data and balances must not be shared.

```bash
cd apps/api
cp .env.example .env
# Fill in .env locally.
node --env-file=.env dev.js
```

The local server defaults to port 3000; `PORT` overrides it. iOS permits local networking without a global ATS exception. Use HTTPS for external hosts. See the local simulator configuration below.

## 3. iOS

Run `npm run ios:prepare` to generate resources from `packages/contracts` and copy the example configuration if missing. Edit the ignored `apps/ios/Empezar/Resources/Config.plist`:

- `API_BASE_URL`: backend base URL, without a trailing slash or `/api`.
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`: public values for the same project.
- `REVENUECAT_PUBLIC_KEY`: public iOS SDK key starting with `appl_`.
- `FREE_PREVIEW_ENABLED`: `true` keeps current free access.
- `PRIVACY_POLICY_URL`: HTTPS URL of the published privacy policy.

Never embed service-role keys, `.p8`, `.p12` or webhook secrets. Generate the project with XcodeGen after preparing resources. Physical devices require a signing team and registered bundle ID. The target includes Sign in with Apple and the `empezar://` URL scheme; the provisioning profile and Apple identifier must enable the same capability.

## 4. App Store Connect and RevenueCat

See [PAYMENTS.md](PAYMENTS.md) for catalog IDs, monthly subscription, proposed prices and remaining Apple/backend work. Free preview is not an Apple subscription trial.

Create consumable products with these exact identifiers:

| Product ID | Server-granted virtual cash |
|---|---:|
| `ei.cash.10000` | USD 10,000 |
| `ei.cash.25000` | USD 25,000 |

Set real prices in App Store Connect. The client displays localized StoreKit prices. Import products into RevenueCat and create the `virtual-cash` offering with one package per product. PostgreSQL maintains cash balances; they do not need a RevenueCat entitlement.

Configure the SDK after sign-in using the lowercase Supabase UUID as `appUserID`. Anonymous RevenueCat purchases are not allowed. The client waits for the webhook and never grants cash based on CustomerInfo.

Configure RevenueCat → Integrations → Webhooks:

- URL: `https://YOUR_BACKEND/api/revenuecat`.
- Authorization: exact `REVENUECAT_WEBHOOK_AUTH` value.
- App and environment: match the backend.
- Events: `NON_RENEWING_PURCHASE` and `CANCELLATION`; consumable refunds use `cancel_reason=CUSTOMER_SUPPORT`.
- Connect App Store Server Notifications to RevenueCat to receive consumable refunds.

Duplicate events and transactions do not grant cash twice. Database failures return errors so RevenueCat retries; success is returned only after commit. If retries are exhausted, resend the event and inspect `purchase_receipts` and `ledger`. There is no periodic reconciliation worker yet.

Purchased cash does not expire. Signing into the same account restores its balance; Restore Purchases does not recreate spent consumables. A refund can make cash negative after it was invested. New buys are blocked, but sells can recover liquidity. Account deletion removes the balance after explicit confirmation.

## Market data

The backend uses the unofficial `yahoo-finance2` library without an API key. Quotes expose `source=Yahoo Finance`, `mode=cached` and optional `logoURL`. Logos must use HTTPS on `s.yimg.com`; missing images fall back to category icons.

PostgreSQL shares quotes across users and instances for 15 minutes. The refresh lease limits concurrent requests and retries. `asOf` retains the market timestamp separately from `fetchedAt`. Provider failures return the previous quote without renewing timestamps or validity.

Trades accept data no older than one hour during the regular session. Quotes expire at most 20 minutes after retrieval and never later than one hour after their market timestamp. Closed-market prices remain visible, but cannot execute trades. The interface shows the date/source and contextual explanations without exposing caching implementation details.

AAPL/MSFT trailing-twelve-month P/E and EPS use a 24-hour cache. Missing values remain `null`, not zero. Set `ENABLE_FUNDAMENTALS=false` to disable retrieval.

On September 6, real queries for all four catalog symbols, shared-cache write/read with stable IDs, AAPL fundamentals and AAPL/MSFT logos were verified. Yahoo returned no VTI/BND logos. The existing initial migration was applied to the previously empty Supabase project, enabling RLS and server-only quote writes.

Commercial use and redistribution terms still require review before release. References: [library](https://github.com/gadicc/yahoo-finance2), [Yahoo terms](https://legal.yahoo.com/xw/en/yahoo/terms/otos/index.html).

## External beta checks

Test both packs, StoreKit cancellation, reopening with pending purchases, duplicate webhooks, refunds before/after spending, account switching and deletion. Check opening/closing session behavior. Complete the privacy policy, App Privacy declarations and contact details. Automated tests do not replace real-credential integration checks.

## Run iOS against the local backend

```bash
# From the repository root: copy only the URL and public key into the ignored plist.
node scripts/configure-ios-local.mjs apps/api/.env.production.local http://localhost:3001
# In another terminal, from apps/api:
PORT=3001 node --env-file=.env.production.local dev.js
```

This uses the Supabase project in the specified file (production in this example), not a local database. Rebuild and reinstall after configuration. Launch without `-maestro-scenario` to use the real backend. A physical device needs a reachable backend URL.

The script reports whether Google/Apple authentication is enabled. Copying public keys does not configure OAuth providers; each needs its own credentials. Both were disabled at the September 6 check.
