const jwt = require('jsonwebtoken');
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const privateKey = fs.readFileSync(process.env.APPLE_PRIVATE_KEY_PATH);
const token = jwt.sign({}, privateKey, {
  algorithm: 'ES256',
  expiresIn: '20m',
  issuer: process.env.APPLE_ISSUER_ID,
  audience: 'appstoreconnect-v1',
  header: { alg: 'ES256', kid: process.env.APPLE_KEY_ID, typ: 'JWT' }
});

const IMG_DIR = '/Users/iagolast/Workspace/trainerstudio/design/dist/subscription-plans-review';

const SUBS = [
  { id: '6762467774', label: 'Starter (5)',       file: 'starter-5.png' },
  { id: '6762467830', label: 'Small (15)',        file: 'small-15.png' },
  { id: '6762467775', label: 'Professional (30)', file: 'profesional-30.png' },
  { id: '6762467798', label: 'Premium (50)',      file: 'premium-50.png' },
  { id: '6762467730', label: 'Unlimited (∞)',     file: 'unlimited.png' },
];

const BASE = 'https://api.appstoreconnect.apple.com';

async function api(p, opts = {}) {
  const res = await fetch(`${BASE}${p}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${p}: ${text}`);
  return text ? JSON.parse(text) : null;
}

async function uploadOne(sub) {
  const filePath = path.join(IMG_DIR, sub.file);
  const data = fs.readFileSync(filePath);
  const fileSize = data.length;
  const md5 = crypto.createHash('md5').update(data).digest('hex');

  console.log(`\n=== ${sub.label} ===`);

  // Delete existing review screenshot (1260x2736 is invalid)
  const existing = await fetch(`${BASE}/v1/subscriptions/${sub.id}/appStoreReviewScreenshot`, {
    headers: { Authorization: `Bearer ${token}` },
  }).then((r) => r.json());

  if (existing.data?.id) {
    console.log(`  deleting existing screenshot ${existing.data.id} (${existing.data.attributes.imageAsset?.width}x${existing.data.attributes.imageAsset?.height})`);
    await api(`/v1/subscriptionAppStoreReviewScreenshots/${existing.data.id}`, { method: 'DELETE' });
  }

  // Step 1: reserve
  console.log(`  reserving (${fileSize} bytes, md5=${md5})…`);
  const created = await api('/v1/subscriptionAppStoreReviewScreenshots', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'subscriptionAppStoreReviewScreenshots',
        attributes: { fileName: sub.file, fileSize },
        relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } },
      },
    }),
  });

  const screenshotId = created.data.id;
  const ops = created.data.attributes.uploadOperations;
  console.log(`  screenshot id=${screenshotId}, ${ops.length} upload op(s)`);

  // Step 2: upload chunks
  for (const op of ops) {
    const chunk = data.subarray(op.offset, op.offset + op.length);
    const headers = {};
    for (const h of op.requestHeaders || []) headers[h.name] = h.value;
    const res = await fetch(op.url, { method: op.method, headers, body: chunk });
    if (!res.ok) {
      const t = await res.text();
      throw new Error(`upload chunk ${op.offset}+${op.length}: ${res.status} ${t}`);
    }
    console.log(`  uploaded chunk ${op.offset}+${op.length}`);
  }

  // Step 3: commit
  console.log(`  committing…`);
  await api(`/v1/subscriptionAppStoreReviewScreenshots/${screenshotId}`, {
    method: 'PATCH',
    body: JSON.stringify({
      data: {
        type: 'subscriptionAppStoreReviewScreenshots',
        id: screenshotId,
        attributes: { uploaded: true, sourceFileChecksum: md5 },
      },
    }),
  });

  // Verify
  const verify = await api(`/v1/subscriptionAppStoreReviewScreenshots/${screenshotId}`);
  const a = verify.data.attributes;
  console.log(`  ✓ ${a.imageAsset?.width}x${a.imageAsset?.height} state=${a.assetDeliveryState?.state} errors=${JSON.stringify(a.assetDeliveryState?.errors)}`);
}

(async () => {
  for (const sub of SUBS) {
    try {
      await uploadOne(sub);
    } catch (err) {
      console.error(`  ✗ ${sub.label}: ${err.message}`);
    }
  }
  console.log('\nDone. Re-checking subscription states…\n');
  for (const sub of SUBS) {
    const r = await fetch(`${BASE}/v1/subscriptions/${sub.id}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const j = await r.json();
    console.log(`  ${sub.label.padEnd(20)} state=${j.data.attributes.state}`);
  }
})();
