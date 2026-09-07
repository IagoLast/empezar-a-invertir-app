import { execFileSync } from 'node:child_process';

// Read local public configuration without printing credentials.
const config = JSON.parse(execFileSync('python3', ['-c',
  "import json,plistlib; print(json.dumps(plistlib.load(open('apps/ios/Empezar/Resources/Config.plist','rb'))))",
], { encoding: 'utf8' }));
const authURL = new URL('/auth/v1/settings', config.SUPABASE_URL);
const response = await fetch(authURL, {
  headers: { apikey: config.SUPABASE_ANON_KEY }, signal: AbortSignal.timeout(15000),
});
if (!response.ok) throw new Error(`Auth settings request failed: HTTP ${response.status}`);
const settings = await response.json();
console.log(`Supabase: ${authURL.origin}`);
console.log(`Google: ${settings.external?.google ? 'enabled' : 'disabled'}`);
console.log(`Apple: ${settings.external?.apple ? 'enabled' : 'disabled'}`);
console.log('Expected app callback: empezar://auth-callback');
console.log(`Google redirect URI: ${authURL.origin}/auth/v1/callback`);
try {
  const state = await fetch(new URL('/api/state', config.API_BASE_URL), { signal: AbortSignal.timeout(10000) });
  console.log(`Backend guest portfolio: HTTP ${state.status} (expected 401)`);
  if (state.status !== 401) process.exitCode = 1;
} catch {
  console.log('Backend unavailable. Start the local server or configure a reachable HTTPS URL.');
  process.exitCode = 1;
}
console.log('Provider flags do not verify OAuth credentials, redirect allowlists, signing or a completed login.');
if (!settings.external?.google || !settings.external?.apple) process.exitCode = 1;
