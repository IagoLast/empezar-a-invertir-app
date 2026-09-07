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

// All App Store supported locales for subscription localizations
const ALL_LOCALES = [
  'ar-SA','ca','zh-Hans','zh-Hant','hr','cs','da','nl-NL','en-AU','en-CA','en-GB','en-US',
  'fi','fr-FR','fr-CA','de-DE','el','he','hi','hu','id','it','ja','ko','ms','no','pl',
  'pt-BR','pt-PT','ro','ru','sk','es-MX','es-ES','sv','th','tr','uk','vi'
];

// Description template per locale: "{verb_phrase} N {clients}"
// Apple max 45 chars. Keep concise.
const DESC = {
  'ar-SA':    n => `حتى ${n} عميلاً نشطًا`,
  'ca':       n => `Fins a ${n} clients actius`,
  'zh-Hans':  n => `最多 ${n} 个活跃客户`,
  'zh-Hant':  n => `最多 ${n} 個活躍客戶`,
  'hr':       n => `Do ${n} aktivnih klijenata`,
  'cs':       n => `Až ${n} aktivních zákazníků`,
  'da':       n => `Op til ${n} aktive kunder`,
  'nl-NL':    n => `Tot ${n} actieve klanten`,
  'en-AU':    n => `Up to ${n} active customers`,
  'en-CA':    n => `Up to ${n} active customers`,
  'en-GB':    n => `Up to ${n} active customers`,
  'en-US':    n => `Up to ${n} active customers`,
  'fi':       n => `Enintään ${n} aktiivista asiakasta`,
  'fr-FR':    n => `Jusqu'à ${n} clients actifs`,
  'fr-CA':    n => `Jusqu'à ${n} clients actifs`,
  'de-DE':    n => `Bis zu ${n} aktive Kunden`,
  'el':       n => `Έως ${n} ενεργοί πελάτες`,
  'he':       n => `עד ${n} לקוחות פעילים`,
  'hi':       n => `अधिकतम ${n} सक्रिय ग्राहक`,
  'hu':       n => `Legfeljebb ${n} aktív ügyfél`,
  'id':       n => `Hingga ${n} pelanggan aktif`,
  'it':       n => `Fino a ${n} clienti attivi`,
  'ja':       n => `最大${n}人のアクティブ顧客`,
  'ko':       n => `활성 고객 최대 ${n}명`,
  'ms':       n => `Sehingga ${n} pelanggan aktif`,
  'no':       n => `Opptil ${n} aktive kunder`,
  'pl':       n => `Do ${n} aktywnych klientów`,
  'pt-BR':    n => `Até ${n} clientes ativos`,
  'pt-PT':    n => `Até ${n} clientes ativos`,
  'ro':       n => `Până la ${n} clienți activi`,
  'ru':       n => `До ${n} активных клиентов`,
  'sk':       n => `Až ${n} aktívnych zákazníkov`,
  'es-MX':    n => `Hasta ${n} clientes activos`,
  'es-ES':    n => `Hasta ${n} clientes activos`,
  'sv':       n => `Upp till ${n} aktiva kunder`,
  'th':       n => `ลูกค้าที่ใช้งานสูงสุด ${n} ราย`,
  'tr':       n => `${n} aktif müşteriye kadar`,
  'uk':       n => `До ${n} активних клієнтів`,
  'vi':       n => `Tối đa ${n} khách hàng hoạt động`
};

// Special description for unlimited (no count)
const DESC_UNLIMITED = {
  'ar-SA':   'عملاء غير محدودين',
  'ca':      'Clients il·limitats',
  'zh-Hans': '无限活跃客户',
  'zh-Hant': '無限活躍客戶',
  'hr':      'Neograničeni klijenti',
  'cs':      'Neomezený počet zákazníků',
  'da':      'Ubegrænsede kunder',
  'nl-NL':   'Onbeperkte klanten',
  'en-AU':   'Unlimited active customers',
  'en-CA':   'Unlimited active customers',
  'en-GB':   'Unlimited active customers',
  'en-US':   'Unlimited active customers',
  'fi':      'Rajaton asiakasmäärä',
  'fr-FR':   'Clients illimités',
  'fr-CA':   'Clients illimités',
  'de-DE':   'Unbegrenzte Kunden',
  'el':      'Απεριόριστοι πελάτες',
  'he':      'לקוחות ללא הגבלה',
  'hi':      'असीमित ग्राहक',
  'hu':      'Korlátlan ügyfél',
  'id':      'Pelanggan tanpa batas',
  'it':      'Clienti illimitati',
  'ja':      '無制限の顧客',
  'ko':      '무제한 고객',
  'ms':      'Pelanggan tanpa had',
  'no':      'Ubegrensede kunder',
  'pl':      'Nielimitowani klienci',
  'pt-BR':   'Clientes ilimitados',
  'pt-PT':   'Clientes ilimitados',
  'ro':      'Clienți nelimitați',
  'ru':      'Неограниченные клиенты',
  'sk':      'Neobmedzený počet zákazníkov',
  'es-MX':   'Clientes ilimitados',
  'es-ES':   'Clientes ilimitados',
  'sv':      'Obegränsade kunder',
  'th':      'ลูกค้าไม่จำกัด',
  'tr':      'Sınırsız müşteri',
  'uk':      'Необмежені клієнти',
  'vi':      'Khách hàng không giới hạn'
};

const PLANS = [
  {
    subId: '6762467774',
    brand: 'Starter',
    limit: 5,
    nameSuffix: '(5)',
    existing: [
      { id: '4d820322-e65a-41ec-9b7d-b82d8e36cbad', locale: 'en-US' },
      { id: '91af7f47-f835-43ea-a815-9638614691ac', locale: 'es-ES' }
    ]
  },
  {
    subId: '6762467830',
    brand: 'Small',
    limit: 15,
    nameSuffix: '(15)',
    existing: [
      { id: 'fe143c01-dbca-4aea-a0be-84b148dd9712', locale: 'en-US' },
      { id: '066be787-a183-4371-9113-1ccf8977b32c', locale: 'es-ES' }
    ]
  },
  {
    subId: '6762467775',
    brand: 'Professional',
    limit: 30,
    nameSuffix: '(30)',
    existing: [
      { id: 'e92202a8-c9f1-427d-ab3c-8e77f15bcaa7', locale: 'en-US' },
      { id: 'f283bca7-2dee-4184-8194-542ccd2a9488', locale: 'es-ES' }
    ]
  },
  {
    subId: '6762467798',
    brand: 'Premium',
    limit: 50,
    nameSuffix: '(50)',
    existing: [
      { id: '97f1ab6e-2f97-4aab-bf83-d85518c1a0c6', locale: 'en-US' },
      { id: '21442c01-f53e-44e7-a94d-1f6ec6d0fcc5', locale: 'es-ES' }
    ]
  },
  {
    subId: '6762467730',
    brand: 'Unlimited',
    limit: null, // unlimited
    nameSuffix: '(∞)',
    existing: [
      { id: '00fe941e-0111-4cbb-83da-6a1312241d28', locale: 'en-US' },
      { id: '03c06b1b-aa22-477d-816a-cf2600619b48', locale: 'es-ES' }
    ]
  }
];

function describeFor(plan, locale) {
  if (plan.limit === null) {
    return DESC_UNLIMITED[locale];
  }
  return DESC[locale](plan.limit);
}

async function patchLocalization(id, name, description) {
  const res = await fetch(`https://api.appstoreconnect.apple.com/v1/subscriptionLocalizations/${id}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: {
        type: 'subscriptionLocalizations',
        id,
        attributes: { name, description }
      }
    })
  });
  return { status: res.status, body: await res.text() };
}

async function createLocalization(subId, locale, name, description) {
  const res = await fetch('https://api.appstoreconnect.apple.com/v1/subscriptionLocalizations', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      data: {
        type: 'subscriptionLocalizations',
        attributes: { name, description, locale },
        relationships: {
          subscription: { data: { type: 'subscriptions', id: subId } }
        }
      }
    })
  });
  return { status: res.status, body: await res.text() };
}

(async () => {
  for (const plan of PLANS) {
    console.log(`\n=== ${plan.brand} ${plan.nameSuffix} (${plan.subId}) ===`);

    // Update existing en-US, es-ES
    for (const ex of plan.existing) {
      const desc = describeFor(plan, ex.locale);
      // Special case: keep es-ES "Profesional" rather than "Professional"
      let name = `${plan.brand} ${plan.nameSuffix}`;
      if (plan.brand === 'Professional' && ex.locale === 'es-ES') {
        name = `Profesional ${plan.nameSuffix}`;
      }
      const { status, body } = await patchLocalization(ex.id, name, desc);
      if (status === 200) {
        console.log(`  UPD ${ex.locale.padEnd(7)} -> "${name}" | "${desc}"`);
      } else {
        console.log(`  UPD FAIL ${ex.locale} (${status}): ${body}`);
      }
    }

    // Create remaining
    const existingLocales = new Set(plan.existing.map(e => e.locale));
    const toCreate = ALL_LOCALES.filter(l => !existingLocales.has(l));
    for (const locale of toCreate) {
      const desc = describeFor(plan, locale);
      const name = `${plan.brand} ${plan.nameSuffix}`;
      const { status, body } = await createLocalization(plan.subId, locale, name, desc);
      if (status === 201) {
        console.log(`  NEW ${locale.padEnd(7)} -> "${name}" | "${desc}"`);
      } else {
        console.log(`  NEW FAIL ${locale} (${status}): ${body}`);
      }
    }
  }
})();
