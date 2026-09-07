---
name: apple-developer
description: Manage Empezar in App Store Connect, including iOS signing, TestFlight, store metadata and App Store CI/CD preparation.
---

# Apple Developer — Empezar

Adapted from `/Users/iagolast/Workspace/trainerstudio/.agents/skills/apple-developer`.
This project is a native SwiftUI iOS app, not a Capacitor app.

## Project context

- XcodeGen configuration: `apps/ios/project.yml`; scheme: `Empezar`.
- Bundle ID: `com.empezarainvertir.app`; registered resource ID: `WK3QFZ36NT`.
- App Store Connect app: EAI (`6809398284`). The iPhone display name is EAI; the Xcode project and scheme remain Empezar.
- Apple Developer team: TIMETIME SOFTWARE SOCIEDAD LIMITADA (`V4XXJ25N99`), confirmed by the user. Empezar shares this team with TrainerStudio; do not use Edge accounts.
- Sign in with Apple is enabled as a primary App ID (`APPLE_ID_AUTH`, `PRIMARY_APP_CONSENT`). Read back the current capability before changing it.
- The user authorized the TrainerStudio team API key for Empezar. Its external key file remains in the original skill directory; do not copy or commit it. Supply credentials explicitly to the local helper.
- Existing upload workflow: `.github/workflows/testflight.yml`.
- Signing, archive and upload helpers: `scripts/testflight/` at the repository root.
- Read `docs/TESTFLIGHT.md` for configuration, secret names and validation status before preparing a release. Reuse this workflow.

## App Store Connect API

Run from this skill directory. Install dependencies with `npm ci`.
Supply `APPLE_ISSUER_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY_PATH` through the environment. The private key path must point to an external `.p8` file; do not copy, print or commit credentials.

```bash
scripts/apple-api.sh "/v1/apps?filter[bundleId]=com.empezarainvertir.app"
scripts/apple-api.sh "/v1/builds?filter[app]=APP_ID"
```

Resolve the app ID from the bundle ID before writes. Follow pagination links for complete audits. After a write, query the affected resource and report its resulting state.
Local `APPLE_KEY_ID` / `APPLE_ISSUER_ID` correspond to CI `ASC_KEY_ID` / `ASC_ISSUER_ID`; CI receives the key contents as `ASC_API_KEY_P8_BASE64`, not a local path.

## Imported workflows

The original JavaScript helpers are preserved in `references/trainerstudio-scripts/` for metadata, screenshots, subscriptions and audits. They contain TrainerStudio app IDs, product IDs, paths and store text. These are source references, not runnable Empezar workflows: inspect and adapt the relevant helper into `scripts/` before using it. Never reuse the original app/resource IDs or metadata for Empezar.

## TestFlight and CI/CD

When asked to configure distribution, inspect the existing workflow and current Apple documentation, determine the correct team and app, and prepare signing and CI configuration using the repository helpers. Verify bundle ID, entitlements and provisioning agree, including Sign in with Apple.
Distinguish local build validation, signed archive/export, accepted upload and completed TestFlight processing. Report only stages actually verified. Installing this skill does not configure Apple credentials, upload a build or authorize a store release.
