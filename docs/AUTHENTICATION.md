# Authentication setup and verification

## Current audit — September 6, 2026

- Supabase responds to `/auth/v1/settings` using the app's public key.
- The app and backend point to `https://gnodplputnzejhipoxdw.supabase.co`.
- Apple is enabled, confirmed through public provider settings after the user configured it. Google remains disabled. Email is enabled, but this app only supports Apple/Google and the backend rejects email-only identities.
- Local backend `http://localhost:3001` is reachable and rejects unauthenticated portfolio access with HTTP 401, as intended.
- The app registers `empezar://` and handles Google callbacks at `empezar://auth-callback` with PKCE.
- Apple uses native AuthenticationServices, a hashed nonce for Apple and the original nonce for Supabase's identity-token exchange.
- Apple bundle ID `com.empezarainvertir.app` is registered as resource `WK3QFZ36NT` under TIMETIME SOFTWARE SOCIEDAD LIMITADA (`V4XXJ25N99`). Sign in with Apple (`APPLE_ID_AUTH`) was enabled as a primary App ID and verified through the Apple API.
- The XcodeGen specification includes Sign in with Apple and now sets `DEVELOPMENT_TEAM=V4XXJ25N99`.
- A signed development build for physical iPhone succeeded. The embedded provisioning profile and signed app entitlements both identify team `V4XXJ25N99`, application `V4XXJ25N99.com.empezarainvertir.app` and `com.apple.developer.applesignin=[Default]`. Code signature verification passed.
- Session storage uses Keychain; refresh tokens and sign-out are implemented.
- A live simulator UI test confirmed that the Apple sign-in button becomes enabled while Google remains disabled. Pull down to recheck provider configuration. This verifies availability, not a completed Apple identity-token exchange.

The user confirmed that Empezar belongs to the TIMETIME team and authorized use of its existing TrainerStudio Apple API credentials. They remain outside the repository. No Supabase management token is available; public/service-role keys cannot configure OAuth providers. The dashboard redirect allowlist and Google credentials remain unverified. Apple identifier capabilities and a signed development build have been verified. The user enabled Apple in the Supabase dashboard; a subsequent public settings check confirms it is active. The configured client ID cannot be inspected through that public endpoint. A real login has not completed.

## Manual Google setup

1. Open [Google Auth Platform](https://console.cloud.google.com/auth/overview) and select the intended Google Cloud project.
2. Configure app branding, audience and the basic `openid`, email and profile scopes. If the app is in testing, add the Google accounts that will test it as test users.
3. Create an OAuth client of type **Web application**. This app is native, but its Google flow uses Supabase's browser OAuth callback rather than the Google iOS SDK.
4. Add this exact **Authorized redirect URI**:

   ```text
   https://gnodplputnzejhipoxdw.supabase.co/auth/v1/callback
   ```

5. Open [Supabase Auth providers](https://supabase.com/dashboard/project/gnodplputnzejhipoxdw/auth/providers), select Google, paste the client ID and secret, enable it and save. Keep the secret in the dashboard; it does not belong in iOS or chat.
6. Under [Supabase URL configuration](https://supabase.com/dashboard/project/gnodplputnzejhipoxdw/auth/url-configuration), add this exact Redirect URL:

   ```text
   empezar://auth-callback
   ```

7. Pull down on the app's sign-in screen and try Google with a permitted test account.

The Google redirect goes to Supabase; the app redirect returns from Supabase to iOS. Do not swap them. Deployment to Vercel is not required for sign-in in the current simulator; keep the local backend running to load the portfolio afterward.

Reference: [Supabase Google configuration](https://supabase.com/docs/guides/auth/social-login/auth-google).

## Apple setup

1. **Completed:** `com.empezarainvertir.app` is registered in TIMETIME and Sign in with Apple is enabled.
2. **Configured:** XcodeGen uses team `V4XXJ25N99`. Keep this team and bundle ID when generating provisioning profiles or building on devices.
3. **Provider enabled:** the user completed the Supabase dashboard step and `/auth/v1/settings` confirms Apple is enabled. The accepted native Client ID must be `com.empezarainvertir.app`; the public settings endpoint does not expose this value.
4. This implementation uses native identity-token sign-in. A web Services ID and rotating OAuth client secret are not needed for the native-only flow. Those are additional requirements only if Apple web OAuth is introduced.
5. Build with signing and test on a physical iPhone signed into an Apple account. An unsigned simulator build does not verify provisioning or the complete Apple flow.

Reference: [Supabase Apple configuration](https://supabase.com/docs/guides/auth/social-login/auth-apple).

## Read-only recheck

From the repository root, after the local iOS plist exists:

```sh
node scripts/check-auth.mjs
```

The script prints endpoint/provider status and public callback URLs, never keys or tokens. Exit status is nonzero when a provider is disabled or the backend is unavailable/unexpected. It cannot validate secret correctness or the dashboard redirect allowlist.

## End-to-end acceptance

After each provider is configured:

- [ ] Complete sign-in and return to the app without an OAuth error.
- [ ] Load the virtual portfolio with the welcome balance granted exactly once.
- [ ] Complete a lesson, relaunch and confirm saved progress.
- [ ] Reopen after token expiry and verify session refresh.
- [ ] Sign out and confirm protected portfolio access is removed.
- [ ] Sign into the same account and recover the existing balance/progress.
- [ ] Verify account deletion only with a disposable test account after reviewing the confirmation.

Do not use email/password or fabricated sessions to work around disabled social providers.

## Access-screen regression coverage

`AuthAccessState` bounds the UI wait to eight seconds independently of transport cancellation. Late responses cannot overwrite a newer request; dismissal cancels the pending check, and failed refreshes retain previously available methods. Provider requests also use an ephemeral URLSession with eight-second request/resource limits.

`AuthAccessTests.swift` covers success, disabled providers, network failure/retry, hard deadlines, late responses, dismissal/reopening and preservation of known methods. `EmpezarAuthUITests/AuthScreenTests.swift` covers timeout plus pull-to-refresh recovery, offline dismissal/reopening, unavailable providers and closing during a pending request. These fixtures run only in Debug Simulator builds and never authenticate real accounts.

Both targets run through the Empezar scheme in CI. UI screenshots are retained as XCTest attachments in the `native-test-results` artifact. The current suite contains 19 unit tests and four authentication UI tests. Real Apple sign-in still requires the user's account and a complete identity-token exchange.

## Simulator authorization failure: missing entitlements

A live Apple authorization attempt returned `AKAuthenticationError -7026` / `ASAuthorizationError 1000`. The installed simulator app had been built with `CODE_SIGNING_ALLOWED=NO`, so it lacked the simulated Sign in with Apple entitlements. The signed device build and remote Apple configuration were valid, but did not validate the installed simulator artifact.

Use `npm run ios:run` for manual testing. It builds with simulator signing enabled, checks the signature and embedded simulator entitlements, installs and launches without fixtures. `scripts/verify-ios-simulator-signing.py` verifies the actual simulator executable's `__TEXT,__entitlements` section, which Xcode uses for simulator entitlements separately from code-signature entitlements. It requires the TIMETIME application identifier and `com.apple.developer.applesignin=Default`.

CI and Maestro simulator builds now retain signing. CI rejects a build missing these entitlements. Unit/UI fixture tests alone cannot prove that Apple's native authorization controller works.

After rebuilding with signing enabled, a live simulator test opened Apple's native authorization alert instead of returning the entitlement error. The simulator requested signing into an Apple Account in Settings. That personal account step remains for the user; no Apple password or token was entered by automation.
