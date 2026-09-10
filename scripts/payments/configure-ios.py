#!/usr/bin/env python3
"""Switch the local Debug build between Test Store and App Store purchases."""
import argparse
import plistlib
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['sandbox', 'app-store'])
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
path = root / 'apps/ios/Empezar/Resources/Config.plist'
config = plistlib.loads(path.read_bytes())
config['REVENUECAT_TEST_MODE'] = 'true' if args.mode == 'sandbox' else 'false'
config['REVENUECAT_TEST_KEY'] = 'test_sZGlnhglxKWytyVbCscbaGxYSri'
config['REVENUECAT_TEST_API_BASE_URL'] = 'https://empezar-payments-sandbox.vercel.app'
path.write_bytes(plistlib.dumps(config))
print(f'Configured {args.mode}. Run npm run ios:run to rebuild and relaunch.')
