#!/usr/bin/env bash
set -euo pipefail
# Never enable shell tracing: signing credentials must not enter Actions logs.
python3 - <<'PY'
import os,base64,pathlib,plistlib,secrets,re
required=['APPLE_TEAM_ID','IOS_BUNDLE_ID','API_BASE_URL','SUPABASE_URL','SUPABASE_ANON_KEY','REVENUECAT_PUBLIC_KEY','APPLE_CERTIFICATE_P12_BASE64','APPLE_CERTIFICATE_PASSWORD','APPLE_PROFILE_BASE64','ASC_API_KEY_P8_BASE64','ASC_KEY_ID','ASC_ISSUER_ID']
missing=[k for k in required if not os.environ.get(k)]
if missing: raise SystemExit('Configure the testflight environment: '+', '.join(missing))
if not re.fullmatch(r'[A-Z0-9]+',os.environ['ASC_KEY_ID']): raise SystemExit('Invalid ASC_KEY_ID')
for k in ['API_BASE_URL','SUPABASE_URL']:
 if not os.environ[k].startswith('https://') or 'YOUR_' in os.environ[k]: raise SystemExit('Invalid '+k)
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'empezar-signing'
root.mkdir(mode=0o700,exist_ok=True)
private=root/'private_keys'; private.mkdir(mode=0o700,exist_ok=True)
for key,file in [('APPLE_CERTIFICATE_P12_BASE64',root/'certificate.p12'),('APPLE_PROFILE_BASE64',root/'profile.mobileprovision'),('ASC_API_KEY_P8_BASE64',private/('AuthKey_'+os.environ['ASC_KEY_ID']+'.p8'))]:
 file.write_bytes(base64.b64decode(os.environ[key],validate=True)); file.chmod(0o600)
(root/'keychain-password').write_text(secrets.token_urlsafe(32)); (root/'keychain-password').chmod(0o600)
config={k:os.environ[k] for k in ['API_BASE_URL','SUPABASE_URL','SUPABASE_ANON_KEY','REVENUECAT_PUBLIC_KEY']}
with open('apps/ios/Empezar/Resources/Config.plist','wb') as f: plistlib.dump(config,f)
PY
signing_dir="$RUNNER_TEMP/empezar-signing"
signing_keychain="$signing_dir/signing.keychain-db"
keychain_pass=$(cat "$signing_dir/keychain-password")
security create-keychain -p "$keychain_pass" "$signing_keychain"
security set-keychain-settings -lut 21600 "$signing_keychain"
security unlock-keychain -p "$keychain_pass" "$signing_keychain"
security import "$signing_dir/certificate.p12" -P "$APPLE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$signing_keychain" >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$keychain_pass" "$signing_keychain" >/dev/null
security list-keychains -d user -s "$signing_keychain"
security cms -D -i "$signing_dir/profile.mobileprovision" > "$signing_dir/profile.plist"
python3 - <<'PY'
import os,pathlib,plistlib,shutil,datetime
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'empezar-signing'
p=plistlib.loads((root/'profile.plist').read_bytes())
if p['TeamIdentifier'][0]!=os.environ['APPLE_TEAM_ID']: raise SystemExit('Profile team mismatch')
if p['Entitlements']['application-identifier']!=p['ApplicationIdentifierPrefix'][0]+'.'+os.environ['IOS_BUNDLE_ID']: raise SystemExit('Profile bundle ID mismatch')
if p['ExpirationDate']<datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None): raise SystemExit('Provisioning profile expired')
if p.get('ProvisionedDevices') or p.get('ProvisionsAllDevices') or p['Entitlements'].get('get-task-allow'): raise SystemExit('An App Store distribution profile is required')
for directory in [pathlib.Path.home()/'Library/MobileDevice/Provisioning Profiles',pathlib.Path.home()/'Library/Developer/Xcode/UserData/Provisioning Profiles']:
 directory.mkdir(parents=True,exist_ok=True); shutil.copyfile(root/'profile.mobileprovision',directory/(p['UUID']+'.mobileprovision'))
(root/'profile-uuid').write_text(p['UUID'])
export={'method':'app-store-connect','teamID':os.environ['APPLE_TEAM_ID'],'signingStyle':'manual','signingCertificate':'Apple Distribution','provisioningProfiles':{os.environ['IOS_BUNDLE_ID']:p['UUID']},'uploadSymbols':True,'manageAppVersionAndBuildNumber':False}
(root/'ExportOptions.plist').write_bytes(plistlib.dumps(export))
PY
