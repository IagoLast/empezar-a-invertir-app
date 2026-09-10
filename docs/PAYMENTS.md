# Virtual cash purchases

## Catalog

Purchased units are fictitious USD in the investment simulator. PostgreSQL stores integer cents; they cannot be withdrawn or redeemed. Prices below are real EUR purchase prices, not exchange rates.

| Product | Virtual USD | EUR | Apple product | RevenueCat Apple product | RevenueCat Test Store product |
|---|---:|---:|---|---|---|
| `ei.cash.1000` | 1,000 | 1.00 | `6810572636` | `prodcea07aa262` | `prod5ccdc9551b` |
| `ei.cash.10000` | 10,000 | 5.00 | `6810572773` | `prod65d887744c` | `prod5d8348a0f3` |
| `ei.cash.1000000` | 1,000,000 | 20.00 | `6810572524` | `proda542555ba7` | `prod31d8ca6427` |

RevenueCat project `proja88b27a4`, current offering `virtual-cash` (`ofrngc857889146`). Each package contains matching App Store and Test Store consumables. The app displays the store's localized price. Historical `ei.cash.25000` receipts remain valid for reconciliation and refunds, but that pack is not offered in the app. Legacy subscriptions do not grant cash.

## Test now, without charges

The installed local Debug build uses RevenueCat Test Store. Open **Añadir saldo ficticio**, choose a pack, then choose one of RevenueCat's native test actions:

- **Test valid purchase** records a sandbox purchase. RevenueCat delivers a webhook, the server credits the wallet, and the app reads the confirmed balance.
- **Test failed purchase** simulates a payment failure without crediting cash.
- **Cancel** cancels without crediting cash.

These are RevenueCat's test dialogs, not Apple's payment sheet. Test Store transactions cost no money. Inspect them in RevenueCat with sandbox data visible.

```bash
python3 scripts/payments/configure-ios.py sandbox
npm run ios:run
```

The script updates only the ignored local Config.plist. Debug selects `REVENUECAT_TEST_KEY` and `REVENUECAT_TEST_API_BASE_URL` when `REVENUECAT_TEST_MODE=true`. Release ignores these switches and uses the normal Apple SDK key and API URL. Minimum RevenueCat iOS SDK: 5.43.0; the verified local build resolved 5.88.0.

## Sandbox infrastructure

- Backend: `https://empezar-payments-sandbox.vercel.app` (separate Vercel project `empezar-payments-sandbox`).
- RevenueCat Test Store app: `appabb5f0f730`.
- Webhook: `whintgrce41961619`, URL `/api/revenuecat`, app-filtered to Test Store and environment-filtered to sandbox; events `non_renewing_purchase` and `cancellation`. A random authorization secret is stored in Vercel and RevenueCat, never in the app.
- Data: `ea_sandbox` schema in the existing Supabase project. It has separate wallets, receipts, ledger, trades and progress. Authentication identities are shared, so existing Apple sign-in works. This is data isolation within one Supabase project, not a separate Supabase instance.
- API variables: `SUPABASE_DB_SCHEMA=ea_sandbox`, `REVENUECAT_APP_ID=appabb5f0f730`, `REVENUECAT_STORE=TEST_STORE`, `REVENUECAT_ENVIRONMENT=SANDBOX`.
- Account deletion is blocked in this sandbox because deleting the shared Auth identity would also delete the normal account. Pending purchases, trades and local orders use separate device storage keys.

All migrations through `20260910100000_cash_packs.sql` were applied to **ea_sandbox only**. Existing public wallets and receipt records were preserved. A fresh sandbox can be provisioned by piping `node scripts/payments/sandbox-schema.mjs` into an authorized PostgreSQL connection with `ON_ERROR_STOP=1`; it fails if the schema exists. Expose `ea_sandbox` alongside existing PostgREST schemas and retain the generated RLS/function grants. Apply future migrations to both schemas deliberately; do not rerun initial provisioning against an existing sandbox.

The sandbox deployment contains `apps/api/api`, `apps/api/lib` and `apps/api/package.json`. Keep its Vercel project link separate from `apps/api/.vercel`, which targets the normal API. Deploy updates to the sandbox project after tests pass. Its Vercel production target is the stable sandbox service URL, not production purchase data.

## App Store and TestFlight status

Apple app `6809398284`, bundle `com.empezarainvertir.app`, RevenueCat app `app899c976007`.

On September 10, 2026, all three Apple consumables were created with Spanish localization and review notes. Price schedules were set and read back with Spain as the base territory: EUR 1.00, 5.00 and 20.00. The authorized App Store Connect API key was connected to RevenueCat and validated successfully.

All three Apple products now report **READY_TO_SUBMIT**. Availability covers all 175 territories returned by Apple, including new territories automatically. Native wallet review screenshots uploaded successfully and report **COMPLETE**. RevenueCat still needs an **In-App Purchase key** (`subscription_key_configured=false`). No App Store review submission or new TestFlight upload was performed.

Test Store is usable now. Apple Sandbox/TestFlight purchases require finishing the above Apple setup and adding a separate `APP_STORE` sandbox webhook/backend configuration. The Test Store webhook intentionally rejects App Store events. Do not switch the installed Test Store build to Apple and assume purchases will credit.

For a later App Store build:

1. Complete the In-App Purchase key and App Store Server Notifications in Apple/RevenueCat.
2. Apply pending cash migrations to the intended normal backend; its public schema was not changed by this setup.
3. Set up an Apple webhook with matching app, store, environment and authorization. Keep Apple sandbox wallets separate from production wallets.
4. Select the normal local configuration with `python3 scripts/payments/configure-ios.py app-store`, rebuild, and verify the entire Apple purchase flow. Release builds always select the normal configuration.

## Integrity and verification

Purchases are optional and never gate app access. New wallets start empty. Only the backend can grant cash, using a server-controlled catalog. CustomerInfo never credits the balance. Pull-to-refresh reads state/offerings and never submits a purchase or trade. Restoration does not recreate consumables; signing into the same account recovers its existing balance. Duplicate events/transactions are idempotent. Refunds remove the original grant and can produce a negative balance after spending.

Verified on September 10, 2026:

- Signed simulator build and embedded Apple sign-in entitlements verified; installed through `npm run ios:run`.
- All three amounts and EUR prices visible in the native wallet.
- An actual Test Store purchase of `ei.cash.1000` completed through SDK → RevenueCat → deployed webhook → sandbox receipt → app balance of 1,000 virtual USD.
- Replayed transaction against the deployed webhook returned zero additional credit; balance unchanged.
- 79 API tests passed, including store/environment filtering, sandbox schema routing and shared-account deletion protection.
- Full disposable PostgreSQL regression suite passed, including exact grants for every pack, duplicate delivery, refunds and late purchase events. Fresh sandbox schema generation also passed.
- Shared catalog and educational content checks passed.

The 5 EUR and 20 EUR packs were verified in catalog/UI and database tests, not claimed as completed native end-to-end purchases. Cancellation/failure controls are available for manual testing; Apple Sandbox/TestFlight transactions remain unverified.

References: [RevenueCat Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store), [Apple Sandbox and TestFlight](https://www.revenuecat.com/docs/test-and-launch/sandbox/apple-app-store), [webhooks](https://www.revenuecat.com/docs/integrations/webhooks), [Supabase custom schemas](https://supabase.com/docs/guides/api/using-custom-schemas).

## Paid app listing

The app itself is priced at **EUR 7.99** with Spain as its base territory. Apple generated 178 automatic territory price entries. App availability was configured for all 175 territories returned by the territory API, with new territories enabled. Price schedules and availability were read back after writes. The Spanish description, subtitle, keywords and promotional text are saved, with Education as primary category and Finance as secondary. Optional consumables are explicitly separate from the app purchase. Metadata sources are in `metadata/app-store/es-ES/`.

The age questionnaire reflects the educational simulator and infrequent profanity in the book. Remaining listing prerequisites include a published privacy-policy URL, support URL, privacy disclosures, review contact, current release screenshots and a matching release build. The official Apple OpenAPI specification has no In-App Purchase key-generation endpoint; the existing general API key cannot generate that key. No browser is used.
