#!/usr/bin/env python3
"""Reject simulator builds that cannot exercise native Apple authentication."""
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

if len(sys.argv) != 2:
    sys.exit('Usage: python3 scripts/verify-ios-simulator-signing.py <simulator-app>')
app = Path(sys.argv[1])
info = plistlib.loads((app / 'Info.plist').read_bytes())
executable = app / info['CFBundleExecutable']
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
# Xcode stores simulator entitlements in the executable, separately from the signature.
architectures = subprocess.check_output(['xcrun', 'lipo', '-archs', str(executable)], text=True).split()
architecture = 'arm64' if 'arm64' in architectures else 'x86_64'
output = subprocess.check_output(
    ['xcrun', 'otool', '-arch', architecture, '-X', '-s', '__TEXT', '__entitlements', str(executable)], text=True
)
words = []
for line in output.splitlines():
    fields = line.split()
    if fields and re.fullmatch(r'[0-9a-fA-F]{16}', fields[0]):
        words.extend(word for word in fields[1:] if re.fullmatch(r'(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{2})', word))
raw = b''.join(int(word, 16).to_bytes(len(word) // 2, 'little') for word in words).rstrip(b'\0')
if not raw:
    sys.exit('Missing simulator entitlements. Rebuild with CODE_SIGNING_ALLOWED=YES; do not install unsigned test builds for real login.')
end = raw.find(b'</plist>')
if end < 0:
    sys.exit('Malformed simulator entitlements.')
entitlements = plistlib.loads(raw[:end + len(b'</plist>')])
expected = 'V4XXJ25N99.' + info['CFBundleIdentifier']
if entitlements.get('application-identifier') != expected:
    sys.exit('The simulator build does not identify the expected TIMETIME app.')
if 'Default' not in entitlements.get('com.apple.developer.applesignin', []):
    sys.exit('The simulator build is missing Sign in with Apple.')
print(json.dumps({'applicationIdentifier': expected, 'appleSignIn': 'Default', 'signature': 'verified'}))
