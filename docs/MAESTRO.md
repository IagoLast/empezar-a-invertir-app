# iOS user flows with Maestro

Requires macOS, Xcode with an iOS 17+ simulator, XcodeGen, Node, [Maestro CLI](https://docs.maestro.dev/getting-started/installing-maestro/macos) and Java 17 or 21. The suite was originally validated with Maestro 2.10.0.

Use a dedicated simulator. Obtain its UDID with `xcrun simctl list devices`.

```sh
npm run test:ios:e2e
# Select a simulator when several are booted.
SIMULATOR_ID=<UDID> npm run test:ios:e2e
# Reuse the build and run one flow.
SKIP_BUILD=1 npm run test:ios:e2e -- .maestro/flows/02-trade-rejected.yaml
# Override the CLI path.
MAESTRO_BIN=/path/to/maestro npm run test:ios:e2e
```

The script prepares resources, generates Xcode, builds Debug, installs the app and runs flows without backend credentials. Logs, failure screenshots and JUnit go to `artifacts/maestro/`. Flows use `clearState`, erasing local app state but not the simulator Keychain.

## Coverage

| Flow | Expected behavior |
|---|---|
| Buy and sell | Correct position, USD 9,998 final balance and both activity entries |
| HTTP 409 rejection | Visible error, unchanged cash and no pending order |
| Lesson completion | Progress persists after pulling to refresh the portfolio |
| Onboarding/guest | Pages, free entry, keyboard submission, empty search, filters and protected access |
| Closed market | Cannot review or confirm trades |
| Expired quote | Trading stays blocked; pull-to-refresh preserves validation |
| Quantities | Zero/insufficient cash blocked; maximum includes fees |
| Lost confirmation | Explicit retry recovers one purchase and one fee |
| Portfolio error | Pull-to-refresh recovers the portfolio |
| Lesson save error | No premature completion; retry works |
| Sign-out | Clears portfolio/activity and protects purchases |

Native tests also cover fees, expired/malformed quotes, trading permissions and incomplete valuations.

## Simulated backend

Launch argument `maestro-scenario` selects `happy`, `guest`, `trade-rejected`, `trade-response-lost`, `market-closed`, `quote-expired`, `state-retry` or `lesson-retry`. `MaestroBackend.swift` only compiles under `DEBUG && targetEnvironment(simulator)`.

It supplies an in-memory session (except for guests), bypasses Keychain and disables RevenueCat. An ephemeral URLSession/URLProtocol intercepts HTTP/JSON at `https://maestro.invalid`. Views, AppStore, serialization, validation and error handling remain real. Undefined routes/scenarios fail rather than falling through to the live backend.

State lasts for the process lifetime; relaunch resets fixtures. Normal quotes have current timestamps and a 2099 expiry. Repeated request IDs do not duplicate orders. Add YAML under `.maestro/flows/`; shared steps stay outside that folder. Prefer accessibility IDs and visible outcomes, without fixed sleeps. Names/comments use English; assertions match Spanish UI copy.

Real OAuth, payments and backend persistence/business logic need separate integration tests.

## CI and local status

`.github/workflows/maestro.yml` runs on PRs, pushes to main and manual dispatch with macos-26, Java 21, Maestro 2.10.0 and an available iPhone from the latest runtime. It builds Debug with local simulator signing and without secrets. The **iOS user flows** check fails on build/flow errors and cancels stale runs. The **maestro-ios-results** artifact retains logs, JUnit and failure screenshots for 14 days. Configure branch protection separately.

The original eleven flows were checked on iPhone 17 Pro, iOS 26.5. Copy and refresh changes update those flows; consult the latest `artifacts/maestro/results.xml` rather than treating historical runs as current validation. CI execution requires pushing the changes.

A local CLI may be reused without changing global PATH:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
MAESTRO_BIN=artifacts/maestro-cli/maestro/bin/maestro \
SIMULATOR_ID=<UDID> npm run test:ios:e2e
```
