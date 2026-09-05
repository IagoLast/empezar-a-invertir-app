#!/usr/bin/env bash
set -euo pipefail
signing_dir="$RUNNER_TEMP/empezar-signing"
profile_uuid=$(cat "$signing_dir/profile-uuid")
# Each workflow run and retry has a distinct numeric build version.
build_number="${GITHUB_RUN_NUMBER}.${GITHUB_RUN_ATTEMPT}"
xcodebuild -project apps/ios/Empezar.xcodeproj -scheme Empezar -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$signing_dir/Empezar.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$IOS_BUNDLE_ID" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
  PROVISIONING_PROFILE_SPECIFIER="$profile_uuid" CURRENT_PROJECT_VERSION="$build_number" \
  OTHER_CODE_SIGN_FLAGS="--keychain $signing_dir/signing.keychain-db" archive
xcodebuild -exportArchive -archivePath "$signing_dir/Empezar.xcarchive" \
  -exportOptionsPlist "$signing_dir/ExportOptions.plist" -exportPath "$signing_dir/export"
