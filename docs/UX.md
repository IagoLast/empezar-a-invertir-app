# UX and copy guidelines

Reviewed September 6, 2026. Empezar teaches investing through explanations and simulated trades.

## Language

Use English for code identifiers, comments, filenames, test descriptions and developer documentation. Keep user-facing app copy and educational resources in Spanish. Internal state uses English identifiers, not display labels.

## Interaction

- Explain actions and their purpose; do not expose caching, servers or configuration instructions in the product.
- Use native pull-to-refresh on data screens. Refreshing must not submit trades, initiate purchases or retry unresolved orders.
- Keep purchase restoration and pending-order resolution explicit.
- Show price dates and sources discreetly with contextual explanations.
- Distinguish real subscription/top-up charges from virtual balances and fees.
- Place information icons beside their concept: 13-point icon, 5-point gap, entire label tappable with a minimum 44-point height. Support VoiceOver and multiline text.
- Use logos with category-icon fallbacks. Never invent prices or charts.

## Reviewed screens

- [x] Onboarding: learning and first steps without early top-up promotion.
- [x] Portfolio/activity: identify guest welcome cash, label investment value accurately and attach balance help to its concept.
- [x] Markets: understandable search and empty/error states; practice catalog.
- [x] Catalog detail: identity, per-share/unit price, investment explanation, earnings and risks.
- [x] Search detail: logo, asset type, educational context and read-only scope.
- [x] Lessons/valuation: explained vocabulary, coherent exercises and EPS/P/E/safety-margin help.
- [x] Trade: contextual commission help, virtual-money confirmation and a return action when markets are closed.
- [x] Authentication/profile/wallet: useful messages without service configuration instructions.
- [x] Subscription: current free access and accurate billing/renewal disclosures.
- [x] Errors: understandable messages instead of SDK diagnostics.

## Verification history

12 native and 32 backend tests pass. Shared educational resources match their contracts. Three UI journeys passed on iPhone 17 Pro: Apple detail, lesson, and NVDA search with help-sheet opening/closing. Detail and contextual-help screenshots were inspected.

These checks do not validate real OAuth or purchases. See README for external configuration still required.

The pull-to-refresh change passes a simulator UI test that confirms the refresh button is absent, performs the gesture and verifies the disabled-provider sign-in state. The native suite now includes 13 tests.

Authentication now has an eight-second UI deadline, a recoverable connection state, pull-to-refresh retry and an explicit exploration exit. Disabled providers are hidden. The native Apple button uses the app's Spanish localization. Six state tests and four durable UI tests cover these flows; timeout and recovery screenshots were visually inspected.
