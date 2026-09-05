#!/usr/bin/env bash
set -euo pipefail
signing_dir="$RUNNER_TEMP/empezar-signing"
if [ -f "$signing_dir/signing.keychain-db" ]; then security delete-keychain "$signing_dir/signing.keychain-db" || true; fi
python3 - <<'PY'
import os,pathlib,shutil
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'empezar-signing'
if (root/'profile-uuid').exists():
 uuid=(root/'profile-uuid').read_text().strip()
 for d in ['Library/MobileDevice/Provisioning Profiles','Library/Developer/Xcode/UserData/Provisioning Profiles']:
  (pathlib.Path.home()/d/(uuid+'.mobileprovision')).unlink(missing_ok=True)
shutil.rmtree(root,ignore_errors=True)
pathlib.Path('apps/ios/Empezar/Resources/Config.plist').unlink(missing_ok=True)
PY
