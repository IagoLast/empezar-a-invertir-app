import { readFileSync } from 'node:fs';
import { parseEnv } from 'node:util';
import { spawnSync } from 'node:child_process';

const [envFile, apiURL = 'http://localhost:3001'] = process.argv.slice(2);
if (!envFile) throw new Error('Usage: node scripts/configure-ios-local.mjs <backend-env-file> [api-url]');
const env = parseEnv(readFileSync(envFile, 'utf8'));
const url = env.SUPABASE_URL || env.NEXT_PUBLIC_SUPABASE_URL;
const key = env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_ANON_KEY;
if (!url?.startsWith('https://') || !key) throw new Error('Missing public Supabase configuration');
if (!key.startsWith('sb_publishable_')) {
  const payload = JSON.parse(Buffer.from(key.split('.')[1] || '', 'base64url').toString());
  if (payload.role !== 'anon') throw new Error('Only a publishable or anon key can enter the iOS app');
}
const api = new URL(apiURL);
if (api.protocol !== 'https:' && !(api.protocol === 'http:' && api.hostname === 'localhost')) {
  throw new Error('Use HTTPS, or localhost for the iOS Simulator');
}
const result = spawnSync('python3', ['-c', `
import json, plistlib, sys
from pathlib import Path
p = Path('apps/ios/Empezar/Resources/Config.plist')
source = p if p.exists() else Path('apps/ios/Config.example.plist')
config = plistlib.loads(source.read_bytes())
config.update(json.load(sys.stdin))
p.parent.mkdir(parents=True, exist_ok=True)
p.write_bytes(plistlib.dumps(config))
`], {
  input: JSON.stringify({ API_BASE_URL: apiURL.replace(/\/$/, ''), SUPABASE_URL: url.replace(/\/$/, ''), SUPABASE_ANON_KEY: key }),
  encoding: 'utf8',
});
if (result.status !== 0) throw new Error('Could not write local iOS configuration');
const response = await fetch(`${url}/auth/v1/settings`, { headers: { apikey: key } });
if (!response.ok) throw new Error(`Supabase Auth check failed: HTTP ${response.status}`);
const settings = await response.json();
console.log('Local iOS configuration saved. No server secrets copied.');
console.log(`Supabase reachable. Google: ${settings.external?.google ? 'enabled' : 'disabled'}; Apple: ${settings.external?.apple ? 'enabled' : 'disabled'}.`);
