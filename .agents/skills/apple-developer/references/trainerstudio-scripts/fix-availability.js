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

const SUB_IDS = ['6762467774', '6762467830', '6762467775', '6762467798', '6762467730'];
const SUB_NAMES = {
  '6762467774': 'Starter (5)',
  '6762467830': 'Small (15)',
  '6762467775': 'Professional (30)',
  '6762467798': 'Premium (50)',
  '6762467730': 'Unlimited (∞)'
};

async function getTerritories(subId) {
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/subscriptionAvailabilities/${subId}/availableTerritories?limit=200`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const j = await res.json();
  return j.data.map(t => t.id);
}

async function recreateAvailability(subId, territoryIds) {
  const res = await fetch('https://api.appstoreconnect.apple.com/v1/subscriptionAvailabilities', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      data: {
        type: 'subscriptionAvailabilities',
        attributes: { availableInNewTerritories: false },
        relationships: {
          subscription: { data: { type: 'subscriptions', id: subId } },
          availableTerritories: {
            data: territoryIds.map(id => ({ type: 'territories', id }))
          }
        }
      }
    })
  });
  return { status: res.status, body: await res.text() };
}

async function getState(subId) {
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/subscriptions/${subId}`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const j = await res.json();
  return j.data.attributes.state;
}

(async () => {
  for (const subId of SUB_IDS) {
    const name = SUB_NAMES[subId];
    console.log(`\n=== ${name} (${subId}) ===`);
    const territories = await getTerritories(subId);
    console.log(`  territories: ${territories.length} (${territories.join(',')})`);
    const r = await recreateAvailability(subId, territories);
    if (r.status === 201) {
      console.log(`  recreated availability availableInNewTerritories=false OK`);
    } else {
      console.log(`  FAIL (${r.status}): ${r.body}`);
    }
  }

  console.log('\n=== Final state ===');
  for (const subId of SUB_IDS) {
    const state = await getState(subId);
    console.log(`  ${SUB_NAMES[subId].padEnd(20)} state=${state}`);
  }
})();
