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
Path('docs/screenshots/README.md').write_text(f'''# Capturas nativas de iPhone

Capturadas en el simulador de iOS después de compilar y pasar los tests.
Código de la captura: `{revision}`.

Blanco y azul por defecto. El tema se cambia en **Perfil → Apariencia** y se conserva entre sesiones.
Las capturas usan una cuenta sin autenticar: las cotizaciones no disponibles aparecen como `—`, sin precios ni rentabilidades inventados.
Las pantallas de detalle y orden se abren mediante argumentos exclusivos de DEBUG para documentar también su estado sin cotización. No ejecutan compras.

| Pantalla | Claro (por defecto) | Oscuro |
|---|---|---|
| Cartera | ![Cartera clara](iphone-light-0.png) | ![Cartera oscura](iphone-dark-0.png) |
| Mercados | ![Mercados claros](iphone-light-1.png) | ![Mercados oscuros](iphone-dark-1.png) |
| Perfil y apariencia | ![Perfil claro](iphone-light-profile.png) | ![Perfil oscuro](iphone-dark-profile.png) |
| Detalle del activo | ![Activo claro](iphone-light-asset.png) | ![Activo oscuro](iphone-dark-asset.png) |
| Compra virtual | ![Compra clara](iphone-light-trade.png) | ![Compra oscura](iphone-dark-trade.png) |
| Aprender | ![Aprender claro](iphone-light-2.png) | ![Aprender oscuro](iphone-dark-2.png) |
''')
PY
