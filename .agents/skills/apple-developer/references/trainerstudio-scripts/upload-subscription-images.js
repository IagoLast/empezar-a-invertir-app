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

const IMG_DIR = '/Users/iagolast/Workspace/trainerstudio/design/dist/subscription-plans';

const SUBS = [
  { id: '6762467774', label: 'Starter (5)',       file: 'starter-5.png' },
  { id: '6762467830', label: 'Small (15)',        file: 'small-15.png' },
  { id: '6762467775', label: 'Professional (30)', file: 'profesional-30.png' },
  { id: '6762467798', label: 'Premium (50)',      file: 'premium-50.png' },
  { id: '6762467730', label: 'Unlimited (∞)',     file: 'unlimited.png' },
];

const BASE = 'https://api.appstoreconnect.apple.com';

async function api(path, opts = {}) {
  const res = await fetch(`${BASE}${path}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status} ${path}: ${text}`);
  return text ? JSON.parse(text) : null;
}

async function uploadOne(sub) {
  const filePath = path.join(IMG_DIR, sub.file);
  const data = fs.readFileSync(filePath);
  const fileSize = data.length;
  const md5 = crypto.createHash('md5').update(data).digest('hex');

  console.log(`\n=== ${sub.label} ===`);

  // Check existing images and delete them so we replace cleanly
  const existing = await api(`/v1/subscriptions/${sub.id}/images`);
  for (const img of existing.data || []) {
    console.log(`  deleting existing image ${img.id}`);
    await api(`/v1/subscriptionImages/${img.id}`, { method: 'DELETE' });
  }

  // Step 1: reserve image
  console.log(`  reserving image (${fileSize} bytes, md5=${md5})…`);
  const created = await api('/v1/subscriptionImages', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'subscriptionImages',
        attributes: { fileName: sub.file, fileSize },
        relationships: { subscription: { data: { type: 'subscriptions', id: sub.id } } },
      },
    }),
  });

  const imageId = created.data.id;
  const ops = created.data.attributes.uploadOperations;
  console.log(`  image id=${imageId}, ${ops.length} upload op(s)`);

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
  await api(`/v1/subscriptionImages/${imageId}`, {
    method: 'PATCH',
    body: JSON.stringify({
      data: {
        type: 'subscriptionImages',
        id: imageId,
        attributes: { uploaded: true, sourceFileChecksum: md5 },
      },
    }),
  });

  console.log(`  ✓ done`);
}

(async () => {
  for (const sub of SUBS) {
    try {
      await uploadOne(sub);
    } catch (err) {
      console.error(`  ✗ ${sub.label}: ${err.message}`);
    }
  }
  console.log('\nAll done. Re-run audit-subscriptions.js to verify.');
})();
