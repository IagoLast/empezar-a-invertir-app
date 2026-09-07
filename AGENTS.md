# Empezar

Native SwiftUI iOS app in `apps/ios`. Generate the Xcode project from `apps/ios/project.yml` with XcodeGen.

## Language and interaction conventions

Use English for code identifiers, comments, filenames, test descriptions, scripts and developer documentation. Keep user-facing app copy and educational content in Spanish. Do not use translated display strings as internal state identifiers.

Use pull-to-refresh for reloading screen data instead of refresh buttons. Preserve explicit actions for purchases, purchase restoration and pending-order resolution; refreshing a screen must not submit a trade or initiate a purchase.

## Local simulator builds

Use `npm run ios:run` to relaunch for manual testing. Real Apple authorization requires simulator signing and embedded entitlements. Never install a `CODE_SIGNING_ALLOWED=NO` test artifact for manual sign-in. Verify the installed candidate with `scripts/verify-ios-simulator-signing.py`.

## Project skills

For App Store Connect, iOS signing, TestFlight, metadata and Apple CI/CD, read and use [apple-developer](.agents/skills/apple-developer/SKILL.md). Existing release scripts are in `scripts/testflight/`; configuration is documented in `docs/TESTFLIGHT.md`.
