const jwt = require("jsonwebtoken");
const fs = require("fs");
const https = require("https");

// Cargar .env
const envContent = fs.readFileSync(".env", "utf8");
envContent.split("\n").forEach(line => {
  const [key, ...valueParts] = line.split("=");
  const value = valueParts.join("=");
  if (key && value) process.env[key.trim()] = value.trim();
});

const privateKey = fs.readFileSync(process.env.APPLE_PRIVATE_KEY_PATH);
const token = jwt.sign({}, privateKey, {
  algorithm: "ES256",
  expiresIn: "20m",
  issuer: process.env.APPLE_ISSUER_ID,
  audience: "appstoreconnect-v1",
  header: { alg: "ES256", kid: process.env.APPLE_KEY_ID, typ: "JWT" }
});

function apiCall(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "api.appstoreconnect.apple.com",
      path: path,
      method: method,
      headers: {
        "Authorization": "Bearer " + token,
        "Content-Type": "application/json"
      }
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", chunk => data += chunk);
      res.on("end", () => {
        try {
          resolve({ status: res.statusCode, data: data ? JSON.parse(data) : {} });
        } catch(e) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// IDs
const APP_INFO_LOC_ID = "f00e9ca5-9819-4760-ab55-0bcff8f68149";
const VERSION_LOC_ID = "8fd53b92-3220-4917-b622-01b2012a54c6";
const AGE_RATING_ID = "f1e37638-149d-4c1b-b3de-992a6ff19c95";

// METADATOS CORREGIDOS
const METADATA = {
  // Subtítulo (max 30 chars)
  subtitle: "Gestiona clientes y rutinas", // 27 chars
  privacyPolicyUrl: "https://trainerstudio.io/privacy",

  // Keywords (max 100 chars) - optimizados
  keywords: "entrenador personal,fitness,rutinas,gym,nutricion,ejercicios,trainer,workout", // 79 chars

  description: `TrainerStudio Coach es la herramienta definitiva para entrenadores personales y profesionales del fitness.

GESTIONA TUS CLIENTES
• Organiza todos tus clientes en un solo lugar
• Accede al historial completo de cada cliente
• Comunícate directamente desde la app

CREA RUTINAS PERSONALIZADAS
• Biblioteca con cientos de ejercicios
• Crea rutinas adaptadas a cada cliente
• Asigna planes de entrenamiento semanales

SEGUIMIENTO EN TIEMPO REAL
• Monitoriza el progreso de tus clientes
• Recibe notificaciones de entrenamientos completados
• Analiza estadísticas y métricas de rendimiento

PLANES DE NUTRICIÓN
• Crea planes alimenticios personalizados
• Calcula macros y calorías automáticamente
• Envía recordatorios de comidas

AHORRA TIEMPO
• Automatiza tareas repetitivas
• Plantillas reutilizables para rutinas
• Sincronización en todos tus dispositivos

TrainerStudio Coach te ayuda a escalar tu negocio de entrenamiento personal.

¿Dudas? support@trainerstudio.io`,

  supportUrl: "https://trainerstudio.io/support",
  marketingUrl: "https://trainerstudio.io"
};

async function main() {
  console.log("=== ACTUALIZANDO METADATOS (CORREGIDO) ===\n");

  // 1. Actualizar App Info Localization
  console.log("1. Actualizando App Info Localization...");
  const appInfoLocResult = await apiCall("PATCH", "/v1/appInfoLocalizations/" + APP_INFO_LOC_ID, {
    data: {
      type: "appInfoLocalizations",
      id: APP_INFO_LOC_ID,
      attributes: {
        subtitle: METADATA.subtitle,
        privacyPolicyUrl: METADATA.privacyPolicyUrl
      }
    }
  });
  console.log("   Status:", appInfoLocResult.status);
  if (appInfoLocResult.status !== 200) {
    console.log("   Error:", JSON.stringify(appInfoLocResult.data.errors || appInfoLocResult.data, null, 2));
  } else {
    console.log("   ✓ Subtítulo y Privacy URL actualizados");
  }

  // 2. Actualizar Version Localization (sin whatsNew - es primera versión)
  console.log("\n2. Actualizando Version Localization...");
  const versionLocResult = await apiCall("PATCH", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID, {
    data: {
      type: "appStoreVersionLocalizations",
      id: VERSION_LOC_ID,
      attributes: {
        description: METADATA.description,
        keywords: METADATA.keywords,
        supportUrl: METADATA.supportUrl,
        marketingUrl: METADATA.marketingUrl
      }
    }
  });
  console.log("   Status:", versionLocResult.status);
  if (versionLocResult.status !== 200) {
    console.log("   Error:", JSON.stringify(versionLocResult.data.errors || versionLocResult.data, null, 2));
  } else {
    console.log("   ✓ Descripción, Keywords y URLs actualizados");
  }

  // 3. Actualizar Age Rating Declaration (todos los campos requeridos)
  console.log("\n3. Actualizando Age Rating...");
  const ageRatingResult = await apiCall("PATCH", "/v1/ageRatingDeclarations/" + AGE_RATING_ID, {
    data: {
      type: "ageRatingDeclarations",
      id: AGE_RATING_ID,
      attributes: {
        alcoholTobaccoOrDrugUseOrReferences: "NONE",
        contests: "NONE",
        gamblingSimulated: "NONE",
        medicalOrTreatmentInformation: "NONE",
        profanityOrCrudeHumor: "NONE",
        sexualContentGraphicAndNudity: "NONE",
        sexualContentOrNudity: "NONE",
        horrorOrFearThemes: "NONE",
        matureOrSuggestiveThemes: "NONE",
        violenceCartoonOrFantasy: "NONE",
        violenceRealisticProlongedGraphicOrSadistic: "NONE",
        violenceRealistic: "NONE",
        gambling: false,
        unrestrictedWebAccess: false,
        // Campos que faltaban
        parentalControls: false,
        healthOrWellnessTopics: true, // La app trata temas de fitness/salud
        messagingAndChat: false,
        ageAssurance: false,
        advertising: false,
        gunsOrOtherWeapons: false,
        lootBox: false,
        userGeneratedContent: false
      }
    }
  });
  console.log("   Status:", ageRatingResult.status);
  if (ageRatingResult.status !== 200) {
    console.log("   Error:", JSON.stringify(ageRatingResult.data.errors || ageRatingResult.data, null, 2));
  } else {
    console.log("   ✓ Clasificación de edad configurada");
  }

  console.log("\n=== VERIFICACIÓN FINAL ===");

  // Verificar App Info Localization
  const checkAppInfo = await apiCall("GET", "/v1/appInfoLocalizations/" + APP_INFO_LOC_ID);
  console.log("\nApp Info Localization:");
  console.log("  Subtitle:", checkAppInfo.data.data.attributes.subtitle);
  console.log("  Privacy URL:", checkAppInfo.data.data.attributes.privacyPolicyUrl);

  // Verificar Version Localization
  const checkVersion = await apiCall("GET", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID);
  console.log("\nVersion Localization:");
  console.log("  Description:", checkVersion.data.data.attributes.description ? "✓ Configurada (" + checkVersion.data.data.attributes.description.length + " chars)" : "✗ Vacía");
  console.log("  Keywords:", checkVersion.data.data.attributes.keywords);
  console.log("  Support URL:", checkVersion.data.data.attributes.supportUrl);
  console.log("  Marketing URL:", checkVersion.data.data.attributes.marketingUrl);
}

main().catch(console.error);
