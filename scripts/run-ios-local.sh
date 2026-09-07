#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
simulator_id="${SIMULATOR_ID:-$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; devices=[x["udid"] for group in json.load(sys.stdin)["devices"].values() for x in group if x["state"]=="Booted" and x["name"].startswith("iPhone")]; print(devices[0] if len(devices)==1 else "")')}"
if [[ -z "$simulator_id" ]]; then
  echo 'Boot one iPhone simulator or set SIMULATOR_ID.' >&2
  exit 1
fi
build_directory="${IOS_BUILD_DIRECTORY:-apps/ios/build/local}"
mkdir -p artifacts/ios-local
npm run ios:prepare
xcodegen generate --spec apps/ios/project.yml
xcodebuild build -project apps/ios/Empezar.xcodeproj -scheme Empezar \
  -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$build_directory" \
  -clonedSourcePackagesDirPath "${IOS_PACKAGES_DIRECTORY:-$build_directory/SourcePackages}" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- > artifacts/ios-local/build.log 2>&1 || {
    tail -60 artifacts/ios-local/build.log
    exit 1
  }
app="$build_directory/Build/Products/Debug-iphonesimulator/Empezar.app"
python3 scripts/verify-ios-simulator-signing.py "$app"
xcrun simctl install "$simulator_id" "$app"
xcrun simctl launch --terminate-running-process "$simulator_id" com.empezarainvertir.app \
  -has-onboarded-v0 YES -preview-tab 0 -preview-profile NO -preview-screen main
