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

const SUBS = [
  { id: '6762467774', name: 'Starter (5)',     reviewNote: 'Monthly auto-renewing subscription. Starter plan: grants the coach access to up to 5 active customers in the TrainerStudio Coach app. Available in selected territories only.' },
  { id: '6762467830', name: 'Small (15)',      reviewNote: 'Monthly auto-renewing subscription. Small plan: grants the coach access to up to 15 active customers in the TrainerStudio Coach app. Available in selected territories only.' },
  { id: '6762467775', name: 'Professional (30)', reviewNote: 'Monthly auto-renewing subscription. Professional plan: grants the coach access to up to 30 active customers in the TrainerStudio Coach app. Available in selected territories only.' },
  { id: '6762467798', name: 'Premium (50)',    reviewNote: 'Monthly auto-renewing subscription. Premium plan: grants the coach access to up to 50 active customers in the TrainerStudio Coach app. Available in selected territories only.' },
  { id: '6762467730', name: 'Unlimited (∞)',   reviewNote: 'Monthly auto-renewing subscription. Unlimited plan: grants the coach unlimited active customers (up to 1000) in the TrainerStudio Coach app. Available in selected territories only.' }
];

async function patchAvailability(subId) {
  // subscriptionAvailabilities id matches the subscription id
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/subscriptionAvailabilities/${subId}`, {
    method: 'PATCH',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      data: {
        type: 'subscriptionAvailabilities',
        id: subId,
        attributes: { availableInNewTerritories: false }
      }
    })
  });
  return { status: res.status, body: await res.text() };
}

async function patchSubscription(subId, reviewNote) {
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/subscriptions/${subId}`, {
    method: 'PATCH',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      data: {
        type: 'subscriptions',
        id: subId,
        attributes: { reviewNote }
      }
    })
  });
  return { status: res.status, body: await res.text() };
}

(async () => {
  for (const s of SUBS) {
    console.log(`\n=== ${s.name} (${s.id}) ===`);

    const a = await patchAvailability(s.id);
    if (a.status === 200) console.log('  availability: availableInNewTerritories=false OK');
    else console.log(`  availability FAIL (${a.status}): ${a.body}`);

    const r = await patchSubscription(s.id, s.reviewNote);
    if (r.status === 200) console.log(`  reviewNote OK`);
    else console.log(`  reviewNote FAIL (${r.status}): ${r.body}`);
  }

  console.log('\n=== Final state check ===');
  for (const s of SUBS) {
    const res = await fetch(`https://api.appstoreconnect.apple.com/v1/subscriptions/${s.id}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const j = await res.json();
    console.log(`  ${s.name.padEnd(20)} state=${j.data.attributes.state}`);
  }
})();
