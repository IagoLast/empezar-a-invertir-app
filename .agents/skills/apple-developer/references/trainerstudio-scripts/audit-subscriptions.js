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
  console.log('=== APP-LEVEL CHECKS ===');
  const app = await api('/v1/apps/6759298775?include=appInfos,appStoreVersions,inAppPurchases');
  console.log(`  App name: ${app.data.attributes.name}`);
  console.log(`  Bundle: ${app.data.attributes.bundleId}`);
  console.log(`  contentRightsDeclaration: ${app.data.attributes.contentRightsDeclaration}`);
  console.log(`  primaryLocale: ${app.data.attributes.primaryLocale}`);

  for (const inc of app.included || []) {
    if (inc.type === 'appInfos') {
      console.log(`  appInfo state: ${inc.attributes.state} | appStoreState: ${inc.attributes.appStoreState}`);
    }
    if (inc.type === 'appStoreVersions') {
      console.log(`  appStoreVersion ${inc.attributes.versionString}: ${inc.attributes.appStoreState} (platform=${inc.attributes.platform})`);
    }
  }

  for (const [subId, label] of Object.entries(SUBS)) {
    console.log(`\n=== ${label} (${subId}) ===`);
    const sub = await api(`/v1/subscriptions/${subId}?include=subscriptionLocalizations,appStoreReviewScreenshot,prices,images,promotedPurchase,group,subscriptionAvailability,offerCodes,introductoryOffers`);

    console.log(`  state: ${sub.data.attributes.state}`);
    console.log(`  groupLevel: ${sub.data.attributes.groupLevel}`);
    console.log(`  familySharable: ${sub.data.attributes.familySharable}`);
    console.log(`  reviewNote (len): ${sub.data.attributes.reviewNote?.length || 0}`);

    const locs = (sub.included || []).filter(x => x.type === 'subscriptionLocalizations');
    const badLocs = locs.filter(l => !l.attributes.name || !l.attributes.description || l.attributes.state !== 'PREPARE_FOR_SUBMISSION');
    console.log(`  locs: ${locs.length} total, ${badLocs.length} bad`);
    badLocs.forEach(l => console.log(`    BAD ${l.attributes.locale}: state=${l.attributes.state} name=${!!l.attributes.name} desc=${!!l.attributes.description}`));

    const screenshot = (sub.included || []).find(x => x.type === 'subscriptionAppStoreReviewScreenshots');
    if (screenshot) {
      console.log(`  screenshot: state=${screenshot.attributes.assetDeliveryState?.state} size=${screenshot.attributes.imageAsset?.width}x${screenshot.attributes.imageAsset?.height}`);
      console.log(`    errors: ${JSON.stringify(screenshot.attributes.assetDeliveryState?.errors)}`);
      console.log(`    warnings: ${JSON.stringify(screenshot.attributes.assetDeliveryState?.warnings)}`);
    } else {
      console.log(`  screenshot: MISSING`);
    }

    const images = (sub.included || []).filter(x => x.type === 'subscriptionImages');
    console.log(`  promotional images: ${images.length}`);

    const prices = sub.data.relationships.prices.meta.paging.total;
    const territories = sub.data.relationships.subscriptionAvailability;
    console.log(`  prices: ${prices}`);
    console.log(`  availability: ${territories?.data?.id || 'NONE'}`);
  }
})();
