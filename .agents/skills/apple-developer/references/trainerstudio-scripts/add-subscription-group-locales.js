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

const GROUP_ID = '22037679';
const CUSTOM_APP_NAME = 'TrainerStudio';

// Locales already present
const EXISTING = new Set(['en-US', 'es-ES']);

// All App Store supported locales for subscription group localizations
// `name` is the localized translation of "Plans" (the subscription group display name)
const LOCALES = [
  { locale: 'ar-SA', name: 'الخطط' },
  { locale: 'ca', name: 'Plans' },
  { locale: 'zh-Hans', name: '套餐' },
  { locale: 'zh-Hant', name: '方案' },
  { locale: 'hr', name: 'Planovi' },
  { locale: 'cs', name: 'Plány' },
  { locale: 'da', name: 'Abonnementer' },
  { locale: 'nl-NL', name: 'Abonnementen' },
  { locale: 'en-AU', name: 'Plans' },
  { locale: 'en-CA', name: 'Plans' },
  { locale: 'en-GB', name: 'Plans' },
  { locale: 'en-US', name: 'Plans' },
  { locale: 'fi', name: 'Tilaukset' },
  { locale: 'fr-FR', name: 'Forfaits' },
  { locale: 'fr-CA', name: 'Forfaits' },
  { locale: 'de-DE', name: 'Tarife' },
  { locale: 'el', name: 'Πλάνα' },
  { locale: 'he', name: 'תוכניות' },
  { locale: 'hi', name: 'योजनाएँ' },
  { locale: 'hu', name: 'Csomagok' },
  { locale: 'id', name: 'Paket' },
  { locale: 'it', name: 'Piani' },
  { locale: 'ja', name: 'プラン' },
  { locale: 'ko', name: '요금제' },
  { locale: 'ms', name: 'Pelan' },
  { locale: 'no', name: 'Abonnementer' },
  { locale: 'pl', name: 'Plany' },
  { locale: 'pt-BR', name: 'Planos' },
  { locale: 'pt-PT', name: 'Planos' },
  { locale: 'ro', name: 'Planuri' },
  { locale: 'ru', name: 'Тарифы' },
  { locale: 'sk', name: 'Plány' },
  { locale: 'es-MX', name: 'Planes' },
  { locale: 'es-ES', name: 'Planes' },
  { locale: 'sv', name: 'Abonnemang' },
  { locale: 'th', name: 'แผน' },
  { locale: 'tr', name: 'Planlar' },
  { locale: 'uk', name: 'Тарифи' },
  { locale: 'vi', name: 'Gói' }
];

async function createLocalization({ locale, name }) {
  const res = await fetch('https://api.appstoreconnect.apple.com/v1/subscriptionGroupLocalizations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: {
        type: 'subscriptionGroupLocalizations',
        attributes: { name, customAppName: CUSTOM_APP_NAME, locale },
        relationships: {
          subscriptionGroup: {
            data: { type: 'subscriptionGroups', id: GROUP_ID }
          }
        }
      }
    })
  });
  const body = await res.text();
  return { status: res.status, body };
}

(async () => {
  const toCreate = LOCALES.filter(l => !EXISTING.has(l.locale));
  console.log(`Adding ${toCreate.length} locales...`);
  for (const item of toCreate) {
    const { status, body } = await createLocalization(item);
    if (status === 201) {
      console.log(`  OK ${item.locale} -> "${item.name}"`);
    } else {
      console.log(`  FAIL ${item.locale} (${status}): ${body}`);
    }
  }
})();
