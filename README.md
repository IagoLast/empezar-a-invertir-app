# Empezar

A native iPhone app for learning about stocks, ETFs, bonds and valuation through simulated investing. New portfolios start with USD 10,000 in virtual cash. Market prices come from Yahoo Finance with a shared 15-minute cache. The interface and educational content are in Spanish; code, comments, filenames and developer documentation are in English.

Built with SwiftUI for iOS 17+, with a white-and-blue default appearance, optional dark mode and three tabs. No technical analysis. [Simulator screenshots](docs/screenshots/README.md).

## Delivery checklist

Status checked on September 6, 2026. Free preview access is enabled. Real charges are not active or verified.

### Implemented

- [x] Native paywall, monthly subscription integration and virtual-cash purchases.
- [x] RevenueCat catalog: `plus` entitlement, monthly plan, USD 10,000 and USD 25,000 virtual-cash packs.
- [x] Local iOS configuration connected to the existing Supabase project and `http://localhost:3001` backend.
- [x] 19 native unit tests, four authentication UI tests and 32 backend tests. These do not validate real sign-in or purchases.
- [x] Initial database migration applied; RLS and server-only cache writes verified.
- [x] Yahoo Finance integration with shared caching and optional logos; prices available to guests.
- [x] Contextual explanations, educational asset details and pull-to-refresh for data screens.

### Authentication and backend

- [ ] Configure and enable Google OAuth in Supabase.
- [x] Register the Apple bundle ID in TIMETIME and enable Sign in with Apple.
- [x] Build and verify a signed iPhone development app with matching TIMETIME provisioning and Apple sign-in entitlements.
- [x] Enable Apple in Supabase (reported by the user and confirmed through public provider settings).
- [ ] Register callback URLs; test sign-in, sign-out and session recovery.
- [ ] Deploy the backend to Vercel and configure its HTTPS URL in iOS.
- [ ] Review data redistribution terms before commercial release.

### Payments

- [ ] Connect App Store Connect and In-App Purchase credentials to RevenueCat.
- [ ] Create and configure the monthly subscription and two consumables in Apple.
- [ ] Confirm proposed Spanish prices: EUR 4.99/month, EUR 1.99 and EUR 3.99 top-ups. They are not published.
- [ ] Configure a proposed seven-day trial for eligible users and choose sales territories.
- [ ] Connect the RevenueCat webhook with authentication and separate sandbox/production environments.
- [ ] Test purchases, restoration, expiration, account switching, top-ups, duplicate events and refunds in sandbox.
- [ ] Add server-side subscription authorization before paid release; the current access gate is in iOS.
- [ ] Explicitly disable `FREE_PREVIEW_ENABLED` when ready. Free preview access is not an Apple subscription trial.

### Release

- [ ] Publish the privacy policy and set `PRIVACY_POLICY_URL` for iOS and TestFlight.
- [ ] Complete signing, App Store metadata, privacy declarations and screenshots.
- [ ] Upload to TestFlight and verify the full flow on a physical iPhone.

Authentication audit and exact manual steps: [AUTHENTICATION.md](docs/AUTHENTICATION.md).

Configuration: [setup](docs/SETUP.md), [payments](docs/PAYMENTS.md), [TestFlight](docs/TESTFLIGHT.md).

## Repository layout

| Directory | Responsibility |
|---|---|
| `apps/ios` | SwiftUI app, Apple/Google authentication, Keychain and RevenueCat |
| `apps/api` | Vercel Node.js functions, authentication, quotes and webhook |
| `apps/web` | Generated static site published at empezar-a-invertir.com |
| `web` | Authoring sources for the site: pages, article bodies and Open Graph cards |
| `packages/contracts` | Shared catalog, Spanish lesson content and HTTP contract |
| `supabase` | PostgreSQL migration, RLS and transactional wallet tests |
| `scripts` | iOS resource preparation, release automation and the web builder |
| `.github/workflows` | API, PostgreSQL and iOS CI; TestFlight upload on every push to `main` |

## Run in Xcode

Requires macOS, Xcode, Node 22+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/IagoLast/empezar-a-invertir-app.git
cd empezar-a-invertir-app
brew install xcodegen
npm run ios:prepare
cd apps/ios
xcodegen generate
open Empezar.xcodeproj
```

Select an iPhone simulator and run **Empezar**, or use `npm run ios:run` from the repository root to build, verify Apple sign-in entitlements and relaunch the local simulator app. Without service configuration, lessons and screens remain explorable but market data and purchases are unavailable. The app does not fabricate prices. Follow [SETUP.md](docs/SETUP.md) to connect services or run the local backend.

## User experience

- Portfolio value, cash, investments and individual results; activity in a separate view. Contributions and top-ups are not profits.
- Search stocks and ETFs by company name or symbol. Trading remains limited to AAPL, MSFT, VTI and BND.
- Asset details explain the investment, price, risks and relevant concepts. Logos fall back to category icons.
- Information icons sit beside their labels, with a shared tappable area and explanatory bottom sheets with examples.
- Pull down to refresh portfolios, markets, asset details, trade quotes, wallet and subscription options. Restoring purchases and resolving pending orders remain explicit actions.
- Appearance is stored across sessions: light, dark or system. Liquid Glass on iOS 26, native materials on iOS 17–18, opaque surfaces when Reduce Transparency is enabled.
- Visual references: [Revolut X](https://www.revolut.com/revolut-x/) and [Coinbase](https://www.coinbase.com/advanced-trade), adapted to the app's own identity.

See [UX.md](docs/UX.md) for copy and interaction guidelines.

## Features and boundaries

Orders use whole units, USD prices and a USD 1 simulated fee. Each order is reviewed before confirmation. The server rejects expired quotes and closed-market trades. Pending orders retain their idempotency keys for safe retries.

The app includes four lessons and a valuation exercise with editable assumptions. Optional Yahoo Finance fundamentals provide trailing-twelve-month P/E and EPS. Apple/Google sessions are stored in Keychain; account deletion is supported.

RevenueCat consumables grant USD 10,000 or USD 25,000 virtual cash. StoreKit supplies localized real prices. Only the server webhook grants cash; event and Apple transaction deduplication, refunds and refund-before-purchase ordering are supported. Sandbox and production are isolated.

The simulator has no bid/ask spread, order book, fractional shares, limit orders, after-hours execution, currency conversion, dividends, stock splits or interest. Profit is price movement net of implemented fees, not total return including distributions. BND is a bond ETF, not an individual bond. Top-ups are optional; there are no rankings or mechanics requiring them.

Before external release, complete service deployment, distribution-rights review, Apple/RevenueCat setup, sandbox integration tests, privacy policy and store metadata. Cached prices are educational data, not a real-time execution feed.

## Web site

The marketing site and blog live in `web/` as sources and are generated into `apps/web/`, which is what gets served. It mirrors the app's appearance (light and dark), uses hand authored line-art illustrations and ships with per-page Open Graph cards, structured data, `sitemap.xml` and an RSS feed.

```bash
npm run web:build     # regenerate apps/web
npm run web:assets    # icons, share cards and cover (needs magick and rsvg-convert)
npm run web:gpu       # rebuild the WebGPU shader bundle (needs npm --prefix web/gpu install)
npm run web:art       # convert the drawings delivered in web/art
npm run web:serve     # preview at http://localhost:4173
```

The home and app heroes render a small vgpu shader behind their copy. It is loaded after the page finishes loading, only when the browser supports WebGPU and the visitor allows motion, so it stays out of the critical path; without support the pages keep their static design.

`npm test` includes `scripts/check-web.mjs`, which fails if the committed pages drift from the sources, if an internal link or share image is missing or if a page breaks the metadata contract. See [web/README.md](web/README.md).

## Verification

```bash
npm test
```

Runs the API test suite plus the shared-resource checks: HTTP contracts, all 20 manuscript chapters and the generated web site. [CI](https://github.com/IagoLast/empezar-a-invertir-app/actions/workflows/ci.yml) also validates PostgreSQL wallet/RLS behavior, builds SwiftUI and runs native tests. Screenshot artifacts are produced on PRs and committed on `main` after verification.

`npm run test:ios:e2e` builds the simulator app and runs 11 Maestro flows against a simulated backend. See [MAESTRO.md](docs/MAESTRO.md). Real OAuth, payments and signed uploads require separate integration verification.

Market data and order execution: [Finnhub and simulated orders](docs/FINNHUB-ORDERS.md).
