#!/usr/bin/env bash
set -euo pipefail
device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for devices in d["devices"].values() for x in devices if x["name"].startswith("iPhone")))')
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl status_bar "$device_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$device_id" apps/ios/build/Build/Products/Debug-iphonesimulator/Empezar.app
mkdir -p docs/screenshots
for appearance in light dark; do
  xcrun simctl ui "$device_id" appearance "$appearance"
  for preview_tab in 0 1 2; do
    xcrun simctl launch --terminate-running-process "$device_id" com.empezarainvertir.app -has-onboarded-v0 YES -preview-tab "$preview_tab" -app-appearance "$appearance" -preview-profile NO -preview-screen main
    sleep 3
    xcrun simctl io "$device_id" screenshot "docs/screenshots/iphone-$appearance-$preview_tab.png"
  done
  xcrun simctl launch --terminate-running-process "$device_id" com.empezarainvertir.app -has-onboarded-v0 YES -preview-tab 0 -app-appearance "$appearance" -preview-profile YES -preview-screen main
  sleep 3
  xcrun simctl io "$device_id" screenshot "docs/screenshots/iphone-$appearance-profile.png"
  for preview_screen in asset trade; do
    xcrun simctl launch --terminate-running-process "$device_id" com.empezarainvertir.app -has-onboarded-v0 YES -preview-tab 0 -app-appearance "$appearance" -preview-profile NO -preview-screen "$preview_screen"
    sleep 3
    xcrun simctl io "$device_id" screenshot "docs/screenshots/iphone-$appearance-$preview_screen.png"
  done
done
# Preserve existing screenshot URLs with the new default light appearance.
for preview_tab in 0 1 2; do
  cp "docs/screenshots/iphone-light-$preview_tab.png" "docs/screenshots/iphone-$preview_tab.png"
done
python3 - <<'PY'
from pathlib import Path
import subprocess
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
Path('docs/screenshots/README.md').write_text(f'''# Native iPhone screenshots

Captured in the iOS simulator after building and testing.
Source revision: `{revision}`.

White and blue are the defaults. Appearance can be changed in the profile and persists across sessions.
Screenshots use a guest account. Unavailable quotes appear as `—`, without fabricated prices or returns.
Detail and trade screens use DEBUG-only launch arguments to document missing-price states. Capturing them does not execute purchases.

| Screen | Light (default) | Dark |
|---|---|---|
| Portfolio | ![Light portfolio](iphone-light-0.png) | ![Dark portfolio](iphone-dark-0.png) |
| Markets | ![Light markets](iphone-light-1.png) | ![Dark markets](iphone-dark-1.png) |
| Profile and appearance | ![Light profile](iphone-light-profile.png) | ![Dark profile](iphone-dark-profile.png) |
| Asset detail | ![Light asset](iphone-light-asset.png) | ![Dark asset](iphone-dark-asset.png) |
| Virtual trade | ![Light trade](iphone-light-trade.png) | ![Dark trade](iphone-dark-trade.png) |
| Learn | ![Light lessons](iphone-light-2.png) | ![Dark lessons](iphone-dark-2.png) |
''')
PY
