// Generate a fresh, isolated portfolio schema while reusing Supabase Auth.
// Pipe to psql only when provisioning a NEW sandbox; existing schemas fail safely.
import { readFileSync, readdirSync } from 'node:fs';
const migrations = new URL('../../supabase/migrations/', import.meta.url);
console.log('begin;\ncreate schema ea_sandbox;');
for (const file of readdirSync(migrations).filter(name => name.endsWith('.sql')).sort()) {
  const sql = readFileSync(new URL(file, migrations), 'utf8')
    .replace(/\bpublic\./g, 'ea_sandbox.')
    .replace(/schema public\b/g, 'schema ea_sandbox')
    .replace(/^begin;|^commit;/gmi, '');
  console.log(`-- ${file}\n${sql}`);
}
console.log('grant usage on schema ea_sandbox to anon, authenticated, service_role;\ncommit;');
