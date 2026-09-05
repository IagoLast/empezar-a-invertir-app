#!/usr/bin/env bash
set -euo pipefail
signing_dir="$RUNNER_TEMP/empezar-signing"
# altool discovers ./private_keys/AuthKey_<KEY_ID>.p8 from this working directory.
cd "$signing_dir"
xcrun altool --upload-app --type ios --file "$signing_dir/export/Empezar.ipa" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
printf '%s\n' 'Upload accepted. Apple processing and TestFlight availability are separate steps.'
