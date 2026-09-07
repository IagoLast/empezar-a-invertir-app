# Empezar payments

## Verified configuration — September 6, 2026

The RevenueCat catalog was created and read back through its MCP. `PaywallView.swift` renders native SwiftUI from offerings; it does not require a hosted RevenueCat paywall template.

| Resource | Identifier |
|---|---|
| RevenueCat project | `proja88b27a4` |
| iOS app | `app899c976007` |
| Bundle ID | `com.empezarainvertir.app` |
| Entitlement | `plus` (`entl48961e943e`) |
| Current subscription offering | `plus` (`ofrngea7e3ba552`) |
| Monthly package | `$rc_monthly` |
| Top-up offering | `virtual-cash` (`ofrngc857889146`) |

| Product | Type | Proposed Spanish price | Benefit |
|---|---|---|---|
| `ei.plus.monthly` | Monthly auto-renewing subscription | EUR 4.99/month; seven-day trial if eligible | Empezar Plus access |
| `ei.cash.10000` | Consumable | EUR 1.99 | USD 10,000 virtual cash |
| `ei.cash.25000` | Consumable | EUR 3.99 | USD 25,000 virtual cash |

**Prices and trial duration are proposals, not published Apple offers.** App Store Connect and In-App Purchase credentials are missing in RevenueCat. Apple product creation, duration and configuration are not verified. The public `appl_…` SDK key is in local/example configuration; it is not a secret. The original Test Store app was preserved. Backend consumables only accept App Store events.

## App behavior

- `FREE_PREVIEW_ENABLED=true` allows free access without subscription or automatic billing. This is the local/example configuration and TestFlight workflow default.
- The profile opens the paywall, restores purchases and links to Apple subscription management.
- Setting the flag to `false` gates iOS access after onboarding. Authentication, paywall and account management remain available. This does not add authorization to API endpoints or Supabase RPCs; add server-side subscription enforcement before paid release.
- Subscriptions use `plus`; top-ups do not unlock it. Subscriptions do not replenish cash monthly. Welcome cash is granted once when creating the portfolio.
- RevenueCat uses the authenticated Supabase UUID. Subscription state updates on launch, foreground entry, purchase, restoration and CustomerInfo changes.
- StoreKit supplies prices. A free trial is shown only when the product offers one and RevenueCat confirms eligibility.
- Only the webhook confirms and credits top-ups. Consumable balances are recovered by signing into the same account, not through Restore Purchases.
- Account deletion does not cancel the Apple subscription; the confirmation explains this.

## Remaining integration work

1. Connect App Store Connect and In-App Purchase keys under RevenueCat app settings. Keep private keys out of the app and repository.
2. Create/verify the three Apple products, subscription group, monthly duration, prices, localizations, sales territories and trial offer. Territories have not been chosen.
3. Publish a privacy policy and set HTTPS `PRIVACY_POLICY_URL` in iOS and TestFlight. The paywall already links to Apple's standard EULA.
4. Configure services following [SETUP.md](SETUP.md). Local iOS uses the existing Supabase project and localhost:3001 backend. Apple/Google providers were disabled at the last check.
5. Configure `REVENUECAT_APP_ID=app899c976007` and `/api/revenuecat` with matching authorization and environment. No RevenueCat webhook integration existed at the last check. Separate sandbox and production.
6. Test eligible/ineligible subscriptions, cancellation, pending purchases, restoration, expiration, account switching, both packs, duplicate webhooks, refunds and reconnecting with a pending top-up.
7. Add server authorization, verify the full flow and explicitly disable free preview in a new build when ready. No release has been published or submitted for review.

## Validation

12 native tests and 32 backend tests pass, including shared catalog checks. RevenueCat 5.88.0 and the native paywall build for the simulator. The signed-out paywall was visually reviewed on iPhone 17 Pro; the temporary gated build was replaced with the free-preview build. These checks do not validate real purchases or Apple trial grants.

References: [CustomerInfo](https://www.revenuecat.com/docs/customers/customer-info), [offers and eligibility](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers), [consumables](https://www.revenuecat.com/docs/platform-resources/non-subscriptions).
