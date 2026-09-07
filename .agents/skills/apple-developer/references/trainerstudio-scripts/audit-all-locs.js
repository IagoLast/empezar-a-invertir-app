const jwt = require('jsonwebtoken');
const fs = require('fs');

const privateKey = fs.readFileSync(process.env.APPLE_PRIVATE_KEY_PATH);
const token = jwt.sign({}, privateKey, {
  algorithm: 'ES256',
  expiresIn: '20m',
  issuer: process.env.APPLE_ISSUER_ID,
  audience: 'appstoreconnect-v1',
  header: { alg: 'ES256', kid: process.env.APPLE_KEY_ID, typ: 'JWT' }
});

const SUBS = {
  '6762467774': 'Starter (5)',
  '6762467830': 'Small (15)',
  '6762467775': 'Professional (30)',
  '6762467798': 'Premium (50)',
  '6762467730': 'Unlimited (∞)'
};

async function api(path) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  return res.json();
}

(async () => {
  for (const [subId, label] of Object.entries(SUBS)) {
    console.log(`\n=== ${label} ===`);
    const locs = await api(`/v1/subscriptions/${subId}/subscriptionLocalizations?limit=200`);
    const all = locs.data;
    console.log(`  Total: ${all.length}`);
    const seen = {};
    for (const l of all) {
      seen[l.attributes.locale] = l.attributes;
      if (!l.attributes.name || !l.attributes.description) {
        console.log(`  EMPTY ${l.attributes.locale}: name="${l.attributes.name}" desc="${l.attributes.description}"`);
      }
      if (l.attributes.state !== 'PREPARE_FOR_SUBMISSION') {
        console.log(`  STATE ${l.attributes.locale}: ${l.attributes.state}`);
      }
      // name max 30 chars, desc max 45 chars
      if ((l.attributes.name || '').length > 30) {
        console.log(`  TOO LONG NAME ${l.attributes.locale}: ${l.attributes.name.length}`);
      }
      if ((l.attributes.description || '').length > 45) {
        console.log(`  TOO LONG DESC ${l.attributes.locale}: ${l.attributes.description.length}`);
      }
    }
    // Print all locales sorted, just the first one as sample
    const sortedLocales = Object.keys(seen).sort();
    console.log(`  Locales: ${sortedLocales.join(',')}`);
  }
})();
