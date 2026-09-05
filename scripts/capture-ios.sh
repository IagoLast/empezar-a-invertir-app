#!/usr/bin/env bash
set -euo pipefail
device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for devices in d["devices"].values() for x in devices if x["name"].startswith("iPhone")))')
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl status_bar "$device_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui "$device_id" appearance light
xcrun simctl install "$device_id" apps/ios/build/Build/Products/Debug-iphonesimulator/Empezar.app
mkdir -p docs/screenshots
for preview_tab in 0 1 2; do
  xcrun simctl launch --terminate-running-process "$device_id" com.empezarainvertir.app -has-onboarded-v0 YES -preview-tab "$preview_tab"
  sleep 3
  xcrun simctl io "$device_id" screenshot "docs/screenshots/iphone-$preview_tab.png"
done
python3 - <<'PY'
import pathlib
pathlib.Path('docs/screenshots/README.md').write_text('''# Capturas nativas de iPhone

Capturadas por GitHub Actions en el simulador de iOS. Se regeneran después de una compilación y tests correctos. La configuración del CI no contiene credenciales: los precios aparecen como no disponibles, nunca como cotizaciones inventadas.

## Cartera
![Cartera](iphone-0.png)

## Explorar
![Explorar](iphone-1.png)

## Aprender
![Aprender](iphone-2.png)
''')
PY
