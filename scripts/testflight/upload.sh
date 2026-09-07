#!/usr/bin/env bash
set -euo pipefail
signing_dir="${TESTFLIGHT_SIGNING_DIR:-${RUNNER_TEMP:?Set RUNNER_TEMP or TESTFLIGHT_SIGNING_DIR}/empezar-signing}"
authentication_args=()
if [[ -n "${APPLE_PRIVATE_KEY_PATH:-}" ]]; then
  authentication_args+=(--p8-file-path "$APPLE_PRIVATE_KEY_PATH")
fi
# altool discovers ./private_keys/AuthKey_<KEY_ID>.p8 from this working directory.
cd "$signing_dir"
xcrun altool --upload-app --type ios --file "$signing_dir/export/Empezar.ipa" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
  ${authentication_args[@]+"${authentication_args[@]}"}
printf '%s\n' 'Upload accepted. Apple processing and TestFlight availability are separate steps.'
