const jwt = require('jsonwebtoken');
const fs = require('fs');

const privateKey = fs.readFileSync(process.env.APPLE_PRIVATE_KEY_PATH);

function newToken() {
  return jwt.sign({}, privateKey, {
    algorithm: 'ES256',
    expiresIn: '20m',
    issuer: process.env.APPLE_ISSUER_ID,
    audience: 'appstoreconnect-v1',
    header: { alg: 'ES256', kid: process.env.APPLE_KEY_ID, typ: 'JWT' },
  });
}

let token = newToken();
let tokenAt = Date.now();

function getToken() {
  if (Date.now() - tokenAt > 15 * 60 * 1000) {
    token = newToken();
    tokenAt = Date.now();
  }
  return token;
}

const APP_ID = '6759298775';

const SUBS = {
  '6762467774': 'Starter',
  '6762467830': 'Small',
  '6762467775': 'Professional',
  '6762467798': 'Premium',
  '6762467730': 'Unlimited',
};

const PAID_20 = [
  'ARG','BOL','BRA','CHL','COL','CRI','DOM','ECU','ESP','GTM',
  'HND','ITA','MEX','NIC','PAN','PER','PRY','SLV','URY','USA',
];

const DEVELOPED = [
  'DEU','FRA','NLD','BEL','AUT','IRL','LUX',
  'SWE','NOR','DNK','FIN','ISL',
  'GBR','CHE','LIE',
  'CAN','AUS','NZL',
  'JPN','KOR','SGP','HKG','TWN','ISR',
];

const KEEP_AS_IS = new Set([...PAID_20, ...DEVELOPED]);

const BASE = 'https://api.appstoreconnect.apple.com';

async function api(p, opts = {}) {
  const res = await fetch(BASE + p, {
    ...opts,
    headers: {
      Authorization: 'Bearer ' + getToken(),
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  if (!res.ok) {
    const err = new Error(res.status + ' ' + p + ': ' + text);
    err.status = res.status;
    err.body = text;
    throw err;
  }
  return text ? JSON.parse(text) : null;
}

async function getEspPricePoint(subId) {
  const j = await api(`/v1/subscriptions/${subId}/prices?filter[territory]=ESP&include=subscriptionPricePoint`);
  const ppId = j.data[0].relationships.subscriptionPricePoint.data.id;
  const pp = (j.included || []).find((x) => x.id === ppId);
  return { ppId, customerPrice: pp?.attributes?.customerPrice };
}

async function getEqualizations(ppId) {
  const map = {};
  let cursor = `/v1/subscriptionPricePoints/${ppId}/equalizations?include=territory&limit=200`;
  while (cursor) {
    const j = await api(cursor);
    const tMap = {};
    for (const inc of (j.included || []).filter((x) => x.type === 'territories')) {
      tMap[inc.id] = inc.attributes;
    }
    for (const p of j.data || []) {
      const tId = p.relationships?.territory?.data?.id;
      if (tId) {
        map[tId] = {
          ppId: p.id,
          price: p.attributes.customerPrice,
          currency: tMap[tId]?.currency,
        };
      }
    }
    cursor = j.links?.next ? j.links.next.replace(BASE, '') : null;
  }
  return map;
}

async function getCurrentPrice(subId, territoryId) {
  const j = await api(`/v1/subscriptions/${subId}/prices?filter[territory]=${territoryId}&include=subscriptionPricePoint`);
  const p = j.data[0];
  if (!p) return null;
  const ppId = p.relationships.subscriptionPricePoint.data.id;
  const pp = (j.included || []).find((x) => x.id === ppId);
  return { priceId: p.id, ppId, customerPrice: pp?.attributes?.customerPrice };
}

async function setPrice(subId, territoryId, ppId) {
  return api('/v1/subscriptionPrices', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'subscriptionPrices',
        attributes: { startDate: null, preserveCurrentPrice: false },
        relationships: {
          subscription: { data: { type: 'subscriptions', id: subId } },
          subscriptionPricePoint: { data: { type: 'subscriptionPricePoints', id: ppId } },
          territory: { data: { type: 'territories', id: territoryId } },
        },
      },
    }),
  });
}

async function setSubscriptionAvailability(subId, territoryIds) {
  return api('/v1/subscriptionAvailabilities', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'subscriptionAvailabilities',
        attributes: { availableInNewTerritories: true },
        relationships: {
          subscription: { data: { type: 'subscriptions', id: subId } },
          availableTerritories: {
            data: territoryIds.map((id) => ({ type: 'territories', id })),
          },
        },
      },
    }),
  });
}

async function getAppTerritoryAvailabilities() {
  const all = [];
  let cursor = `/v2/appAvailabilities/${APP_ID}/territoryAvailabilities?limit=200`;
  while (cursor) {
    const j = await api(cursor);
    for (const t of j.data || []) all.push(t);
    cursor = j.links?.next ? j.links.next.replace(BASE, '') : null;
  }
  return all;
}

async function setAppAvailability(territoryIds) {
  // POST a fresh appAvailability with all wanted territories available
  return api('/v2/appAvailabilities', {
    method: 'POST',
    body: JSON.stringify({
      data: {
        type: 'appAvailabilities',
        attributes: { availableInNewTerritories: true },
        relationships: {
          app: { data: { type: 'apps', id: APP_ID } },
          availableTerritories: {
            data: territoryIds.map((id) => ({ type: 'territories', id })),
          },
        },
      },
    }),
  });
}

async function main() {
  console.log('=== Phase 1: Apply ESP-tier prices to ~130 emerging territories ===\n');

  // Get list of all 175 territories Apple supports (use Starter equalizations for this)
  const espStarter = await getEspPricePoint('6762467774');
  console.log(`Spain Starter price point: €${espStarter.customerPrice} (${espStarter.ppId.slice(0, 16)}…)`);
  const espStarterMap = await getEqualizations(espStarter.ppId);
  const ALL_TERRITORIES = ['ESP', ...Object.keys(espStarterMap).filter((t) => t !== 'ESP')];
  const targetTerritories = Object.keys(espStarterMap).filter((t) => !KEEP_AS_IS.has(t));
  console.log(`Total territories: ${ALL_TERRITORIES.length}`);
  console.log(`Keep as-is: ${KEEP_AS_IS.size}`);
  console.log(`Target for ESP-tier price update: ${targetTerritories.length}`);

  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalFailed = 0;

  for (const [subId, label] of Object.entries(SUBS)) {
    console.log(`\n--- ${label} (${subId}) ---`);
    const { ppId, customerPrice } = await getEspPricePoint(subId);
    console.log(`  Spain price: €${customerPrice}`);
    const equalizations = await getEqualizations(ppId);

    let updated = 0;
    let skipped = 0;
    let failed = 0;
    for (const tId of targetTerritories) {
      const targetPp = equalizations[tId];
      if (!targetPp) {
        console.log(`  ${tId}: SKIP (no equalization)`);
        skipped += 1;
        continue;
      }
      try {
        const current = await getCurrentPrice(subId, tId);
        if (current && current.ppId === targetPp.ppId) {
          skipped += 1;
          continue;
        }
        await setPrice(subId, tId, targetPp.ppId);
        updated += 1;
        if (updated % 25 === 0) console.log(`  …${updated} updated so far`);
      } catch (err) {
        failed += 1;
        console.log(`  ${tId}: FAIL ${err.message.slice(0, 200)}`);
      }
    }
    console.log(`  → updated=${updated} skipped=${skipped} failed=${failed}`);
    totalUpdated += updated;
    totalSkipped += skipped;
    totalFailed += failed;
  }

  console.log(`\nPhase 1 totals: updated=${totalUpdated} skipped=${totalSkipped} failed=${totalFailed}`);

  console.log('\n=== Phase 2: Expand subscription availability to all 175 territories ===\n');
  for (const [subId, label] of Object.entries(SUBS)) {
    try {
      await setSubscriptionAvailability(subId, ALL_TERRITORIES);
      console.log(`  ✓ ${label}: ${ALL_TERRITORIES.length} territories`);
    } catch (err) {
      console.log(`  ✗ ${label}: ${err.message.slice(0, 250)}`);
    }
  }

  console.log('\n=== Phase 3: Open app availability to all 175 territories ===\n');
  try {
    await setAppAvailability(ALL_TERRITORIES);
    console.log(`  ✓ App availability set to ${ALL_TERRITORIES.length} territories via POST`);
  } catch (err) {
    console.log(`  POST failed (${err.message.slice(0, 150)}), falling back to PATCH per-territory…`);
    const records = await getAppTerritoryAvailabilities();
    let yes = 0;
    let no = 0;
    for (const t of records) {
      if (t.attributes?.available) continue;
      try {
        await api(`/v1/territoryAvailabilities/${t.id}`, {
          method: 'PATCH',
          body: JSON.stringify({
            data: {
              type: 'territoryAvailabilities',
              id: t.id,
              attributes: { available: true },
            },
          }),
        });
        yes += 1;
      } catch (e) {
        no += 1;
        console.log(`  ✗ ${t.id.slice(0, 30)}: ${e.message.slice(0, 100)}`);
      }
    }
    console.log(`  → opened=${yes} failed=${no}`);
  }

  console.log('\n=== Final verification ===\n');
  for (const [subId, label] of Object.entries(SUBS)) {
    const r = await api(`/v1/subscriptions/${subId}`);
    let availCount = 0;
    let cursor = `/v1/subscriptions/${subId}/subscriptionAvailability/availableTerritories?limit=200`;
    while (cursor) {
      const j = await api(cursor);
      availCount += (j.data || []).length;
      cursor = j.links?.next ? j.links.next.replace(BASE, '') : null;
    }
    console.log(`  ${label.padEnd(15)} state=${r.data.attributes.state.padEnd(20)} territories=${availCount}`);
  }

  const apps = await getAppTerritoryAvailabilities();
  const yes = apps.filter((t) => t.attributes?.available).length;
  console.log(`\nApp available in ${yes}/${apps.length} territories`);
}

main().catch((err) => {
  console.error('\nFATAL:', err.message);
  process.exit(1);
});
