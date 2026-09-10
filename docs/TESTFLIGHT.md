# CI and TestFlight

**Verify V0** checks the API, contracts, PostgreSQL and native app on pushes to `main`. **Upload to TestFlight** runs on every push to `main`, with no path filter, and can also be started manually on `main`. Pull requests do not upload builds. Tests must pass before each upload.

Uploads run one at a time, without canceling an active upload. The concurrency queue holds up to 100 pending runs so successive pushes do not replace each other; pushes beyond that GitHub limit are canceled.

Unsigned builds work without an Apple account. TestFlight requires Apple Developer Program membership, an App Store Connect app, a registered bundle ID and signing materials. Deploy the backend and Supabase configuration before testing trades in a distributed build.

## Credentials

Create the `testflight` environment in [Settings → Environments](https://github.com/IagoLast/empezar-a-invertir-app/settings/environments). Add secrets and variables there, never in chat or the repository. Optional environment protection can require review before uploads.

| Secret | Contents |
|---|---|
| `ASC_API_KEY_P8_BASE64` | Base64-encoded `.p8` App Store Connect Team API Key |
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | App Store Connect team issuer ID |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded Apple Distribution `.p12`, including its private key |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` export password |
| `APPLE_PROFILE_BASE64` | Base64-encoded App Store distribution profile matching the app and certificate |

| Variable | Purpose |
|---|---|
| `APPLE_TEAM_ID` | Ten-character Apple Developer team ID |
| `IOS_BUNDLE_ID` | Defaults to `com.empezarainvertir.app`; must match profile and App Store Connect |
| `API_BASE_URL` | HTTPS backend URL without `/api` or trailing slash |
| `SUPABASE_URL` | HTTPS project URL |
| `SUPABASE_ANON_KEY` | Public publishable/anon key, never service-role |
| `REVENUECAT_PUBLIC_KEY` | Public iOS `appl_…` SDK key |
| `FREE_PREVIEW_ENABLED` | Legacy configuration; ignored by the current authentication/onboarding/cash-purchase flow |
| `PRIVACY_POLICY_URL` | Published privacy policy HTTPS URL |

Copy Base64 directly to the macOS clipboard without printing it:

```bash
base64 -i AuthKey_ABC123.p8 | tr -d '\n' | pbcopy
```

Paste into the corresponding secret; repeat for `.p12` and `.mobileprovision`. Use a team API key with upload permission; App Manager also supports managing TestFlight. Apple ID passwords and two-factor codes are not required.

## Upload

1. Push to `main` to start an upload automatically.
2. To start another build manually, open [Actions → Upload to TestFlight](https://github.com/IagoLast/empezar-a-invertir-app/actions/workflows/testflight.yml) and select **Run workflow** on `main`.
3. The job validates configuration, imports the certificate into a temporary keychain, checks the profile, tests iOS, archives, exports and uploads using `altool` and the API key.
4. Cleanup removes the keychain, profiles, `.p8`, IPA and runner configuration.
5. `distribute.mjs` waits for the exact uploaded build to become VALID, verifies the target group belongs to this app, assigns the build to EAI Internal and reads back IN_BETA_TESTING. External distribution may require Beta App Review.

Build numbers use `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`, giving each run and retry a new build number while preserving the marketing version in `apps/ios/project.yml`. Adjust this before uploading to an app with higher existing build numbers. Internal tester distribution is automatic after Apple processing. There is no App Store review submission.

## Validation status

### September 7, 2026 release preparation

- Production API: `https://empezar-a-invertir-api.vercel.app`, deployment `dpl_BZbNizhtyKf8wibpBibBTJKrBJYS` is READY. Public quotes, search and market previews returned HTTP 200; unauthenticated portfolio access returned HTTP 401. Quote retrieval also verified the deployed Supabase cache RPCs. The error-log query returned no entries.
- The 32 API tests and shared catalog/book checks passed before deployment.
- Distribution profile `UMQ8B3XL2V` (`Empezar App Store 2026`) is ACTIVE and matches the app, TIMETIME team, existing distribution certificate and Sign in with Apple entitlement. It expires on October 28, 2026.
- Version `0.1.0`, build `1` archived and exported successfully. The IPA is at `artifacts/testflight/export/Empezar.ipa`; `export/verification.json` records its SHA-256. The exported app passed strict code-signature verification, includes the Apple sign-in entitlement, disables debugging and points to the production API. Device family `[1]` is explicitly set on the application target; `scripts/testflight/verify.py` checks the exported artifact before upload.
- Local release configuration uses the production API and free preview. Apple authentication is enabled in Supabase; Google remains disabled. A complete personal Apple login still requires device testing.
- App Store Connect app `6809398284` is named EAI and matches `com.empezarainvertir.app`. The exported iPhone display name is also EAI; internal project/scheme identifiers remain Empezar.
- Internal group `205b61f6-1d98-4fc4-89d9-5a6c798d3243` (`EAI Internal`) contains the user's existing App Store Connect account. Membership was read back through the API.
- Apple accepted the upload without errors at 09:39 UTC. Delivery/build ID: `b307d080-0630-47d3-85b8-739d4cab91bd`. Processing completed as `VALID`; internal state is `IN_BETA_TESTING`. The build is assigned to `EAI Internal`, and the user's tester state is `INVITED`. Spanish testing notes are published. These states were read back through the API. The build expires December 6, 2026.

### Local archive and upload

The same archive/upload scripts support a local signing directory through `TESTFLIGHT_SIGNING_DIR` (absolute path). It must contain `profile-uuid`, `ExportOptions.plist` and the exported build after archiving; install the matching profile in Xcode's provisioning directory first. Local signing uses the existing keychain unless a temporary `signing.keychain-db` is present.

Set `TESTFLIGHT_BUILD_NUMBER`, `APPLE_TEAM_ID`, `IOS_BUNDLE_ID` and optionally `APPLE_SIGNING_IDENTITY` to select the exact certificate. The profile is applied only to the app target using `EMPEZAR_PROFILE_UUID`, so Swift package resource bundles do not inherit it.

For upload, set `ASC_KEY_ID`, `ASC_ISSUER_ID` and `APPLE_PRIVATE_KEY_PATH` to the existing external key file. The upload helper passes that path directly to `altool`; it does not copy the private key. CI retains its temporary-key workflow.

Keep release artifacts and local configuration under the ignored `artifacts/testflight/` directory. An archive or exported IPA does not mean Apple has accepted or processed an upload.

Local development signing, distribution archive/export, upload acceptance, processing and internal tester availability have been verified under TIMETIME (`V4XXJ25N99`). The first release used local signing. Review [PAYMENTS.md](PAYMENTS.md) before enabling paid access.

### Automatic upload setup — September 7, 2026

- The workflow now triggers on every push to `main`, retaining manual dispatch and using the maximum concurrency queue.
- GitHub's `testflight` environment is configured with a deployment branch policy allowing only `main`, without required reviewers. App configuration variables, the distribution profile and App Store Connect API credentials are configured.
- All six required GitHub environment secrets are configured. The Apple Distribution identity was exported from the local keychain by matching its certificate to the provisioning profile, protected with a randomly generated password, and stored as `APPLE_CERTIFICATE_P12_BASE64` and `APPLE_CERTIFICATE_PASSWORD`. The PKCS#12 integrity check passed and confirmed both certificate and private-key bags. The temporary export was deleted, and the secret names were read back from GitHub.
- Workflow YAML, event filters, concurrency configuration and shell syntax were checked locally. The workflow is included in the publication of the pending project changes; a GitHub archive/upload has not yet been verified.

References: [GitHub signing](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [App Store Connect API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api), [Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
