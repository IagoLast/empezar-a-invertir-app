#!/usr/bin/env bash
set -euo pipefail
signing_dir="${TESTFLIGHT_SIGNING_DIR:-${RUNNER_TEMP:?Set RUNNER_TEMP or TESTFLIGHT_SIGNING_DIR}/empezar-signing}"
profile_uuid=$(cat "$signing_dir/profile-uuid")
# Each workflow run and retry has a distinct numeric build version.
build_number="${TESTFLIGHT_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:?Set a build number}.${GITHUB_RUN_ATTEMPT:?Set a build attempt}}"
signing_args=()
if [[ -f "$signing_dir/signing.keychain-db" ]]; then
  signing_args+=("OTHER_CODE_SIGN_FLAGS=--keychain $signing_dir/signing.keychain-db")
fi
xcodebuild -project apps/ios/Empezar.xcodeproj -scheme Empezar -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$signing_dir/Empezar.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="${APPLE_SIGNING_IDENTITY:-Apple Distribution}" \
  EMPEZAR_PROFILE_UUID="$profile_uuid" CURRENT_PROJECT_VERSION="$build_number" \
  ${signing_args[@]+"${signing_args[@]}"} archive
xcodebuild -exportArchive -archivePath "$signing_dir/Empezar.xcarchive" \
  -exportOptionsPlist "$signing_dir/ExportOptions.plist" -exportPath "$signing_dir/export"
python3 scripts/testflight/verify.py "$signing_dir/export/Empezar.ipa"
