#!/usr/bin/env python3
"""Verify the exported distribution artifact before uploading it to Apple."""

import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import zipfile


ipa = Path(sys.argv[1]).resolve()
bundle_id = os.environ.get("IOS_BUNDLE_ID", "com.empezarainvertir.app")
team_id = os.environ.get("APPLE_TEAM_ID", "V4XXJ25N99")
with tempfile.TemporaryDirectory(prefix="eai-verify-") as temporary:
    with zipfile.ZipFile(ipa) as archive:
        archive.extractall(temporary)
    apps = list((Path(temporary) / "Payload").glob("*.app"))
    if len(apps) != 1:
        raise SystemExit("Expected exactly one application in the IPA")
    app = apps[0]
    info = plistlib.loads((app / "Info.plist").read_bytes())
    config = plistlib.loads((app / "Config.plist").read_bytes())
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    entitlements = plistlib.loads(subprocess.check_output(
        ["codesign", "-d", "--entitlements", ":-", str(app)], stderr=subprocess.DEVNULL
    ))
    checks = {
        "bundle identifier": info["CFBundleIdentifier"] == bundle_id,
        "display name": info["CFBundleDisplayName"] == "EAI",
        "iPhone device family": info["UIDeviceFamily"] == [1],
        "application entitlement": entitlements["application-identifier"] == f"{team_id}.{bundle_id}",
        "Apple sign-in entitlement": entitlements.get("com.apple.developer.applesignin") == ["Default"],
        "distribution debugging disabled": not entitlements.get("get-task-allow"),
        "HTTPS backend": config["API_BASE_URL"].startswith("https://"),
        "HTTPS authentication": config["SUPABASE_URL"].startswith("https://"),
    }
    if os.environ.get("API_BASE_URL"):
        checks["expected backend"] = config["API_BASE_URL"] == os.environ["API_BASE_URL"]
    failures = [name for name, passed in checks.items() if not passed]
    if failures:
        raise SystemExit("IPA verification failed: " + ", ".join(failures))
    report = {
        "name": info["CFBundleDisplayName"],
        "version": info["CFBundleShortVersionString"],
        "build": info["CFBundleVersion"],
        "bundleId": bundle_id,
        "api": config["API_BASE_URL"],
        "deviceFamily": info["UIDeviceFamily"],
        "sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
        "checks": checks,
    }
    (ipa.parent / "verification.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
