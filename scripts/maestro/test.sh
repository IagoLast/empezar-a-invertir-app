#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${MAESTRO_BIN:=maestro}"
command -v "$MAESTRO_BIN" >/dev/null || { echo "Install Maestro CLI and Java 17+: https://docs.maestro.dev/getting-started/installing-maestro/macos" >&2; exit 1; }
command -v xcodegen >/dev/null
simulator_id="${SIMULATOR_ID:-$(xcrun simctl list devices booted -j | python3 -c 'import json,sys; d=[x["udid"] for v in json.load(sys.stdin)["devices"].values() for x in v if x["state"]=="Booted"]; print(d[0] if len(d)==1 else "")')}"
if [[ -z "$simulator_id" ]]; then
    echo "Boot an iOS simulator or set SIMULATOR_ID=<UDID>." >&2
    exit 1
fi
mkdir -p artifacts/maestro
if [[ "${SKIP_BUILD:-0}" != 1 ]]; then
    npm run ios:prepare
    xcodegen generate --spec apps/ios/project.yml
    xcodebuild -project apps/ios/Empezar.xcodeproj -scheme Empezar -configuration Debug \
        -destination "platform=iOS Simulator,id=$simulator_id" \
        -derivedDataPath apps/ios/build/maestro CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build \
        > artifacts/maestro/build.log 2>&1 || { tail -60 artifacts/maestro/build.log; exit 1; }
fi
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" apps/ios/build/maestro/Build/Products/Debug-iphonesimulator/Empezar.app
"$MAESTRO_BIN" --device "$simulator_id" test --format junit --output artifacts/maestro/results.xml \
    --test-output-dir artifacts/maestro "${@:-.maestro}"
