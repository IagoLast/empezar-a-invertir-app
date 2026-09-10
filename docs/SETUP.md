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
| `ENABLE_FUNDAMENTALS` | `true` enables Finnhub P/E and EPS with a 24-hour cache; `false` disables them |
| `REVENUECAT_WEBHOOK_AUTH` | Long random value RevenueCat sends exactly in Authorization |
| `REVENUECAT_APP_ID` | RevenueCat iOS app ID; currently `app899c976007` |
| `REVENUECAT_ENVIRONMENT` | `SANDBOX` for development/TestFlight or `PRODUCTION` |

Keep sandbox and production balances separate. The configured Test Store uses a separate Vercel project and the isolated `ea_sandbox` schema, sharing only Supabase Auth identities. See [PAYMENTS.md](PAYMENTS.md) for the active setup and its limitations. Configure one app/store/environment-filtered RevenueCat webhook per backend.

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
- Three introduction screens precede authentication. Cash purchases are optional in the home banner; the legacy `FREE_PREVIEW_ENABLED` flag is ignored.
- `PRIVACY_POLICY_URL`: HTTPS URL of the published privacy policy.

Never embed service-role keys, `.p8`, `.p12` or webhook secrets. Generate the project with XcodeGen after preparing resources. Physical devices require a signing team and registered bundle ID. The target includes Sign in with Apple and the `empezar://` URL scheme; the provisioning profile and Apple identifier must enable the same capability.

## 4. App Store Connect and RevenueCat

See [PAYMENTS.md](PAYMENTS.md) for catalog IDs, the three EUR cash packs, ready-to-use Test Store and remaining Apple work.

Create consumable products with these exact identifiers:

| Product ID | Server-granted virtual cash |
|---|---:|
| `ei.cash.1000` | USD 1,000 (EUR 1.00) |
| `ei.cash.10000` | USD 10,000 (EUR 5.00) |
| `ei.cash.1000000` | USD 1,000,000 (EUR 20.00) |
| `ei.cash.25000` | USD 25,000 (historical receipts only; not offered in the app) |

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

Finnhub, EODHD and Alpha Vantage are normalized by the backend. Configure their server-only keys and apply every migration in `supabase/migrations` in filename order. See [market providers and execution](MARKET-PROVIDERS.md) for the current setup, caching and immediate virtual orders.

## External beta checks

Test all three packs, StoreKit cancellation, reopening with pending purchases, duplicate webhooks, refunds before/after spending, account switching and deletion. Check opening/closing session behavior. Complete the privacy policy, App Privacy declarations and contact details. Automated tests do not replace real-credential integration checks.

## Run iOS against the local backend

```bash
# From the repository root: copy only the URL and public key into the ignored plist.
node scripts/configure-ios-local.mjs apps/api/.env.production.local http://localhost:3001
# In another terminal, from apps/api:
PORT=3001 node --env-file=.env.production.local dev.js
```

This uses the Supabase project in the specified file (production in this example), not a local database. Rebuild and reinstall after configuration. Launch without `-maestro-scenario` to use the real backend. A physical device needs a reachable backend URL.

The script reports whether Google/Apple authentication is enabled. Copying public keys does not configure OAuth providers; each needs its own credentials. Both were disabled at the September 6 check.
