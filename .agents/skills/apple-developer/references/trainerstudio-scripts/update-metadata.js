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
const APP_ID = "6759298775";
const APP_INFO_ID = "f1e37638-149d-4c1b-b3de-992a6ff19c95";
const VERSION_ID = "baa476d6-d3d0-4e6a-adf0-673dd7dfb998";
const APP_INFO_LOC_ID = "f00e9ca5-9819-4760-ab55-0bcff8f68149";
const VERSION_LOC_ID = "8fd53b92-3220-4917-b622-01b2012a54c6";
const AGE_RATING_ID = "f1e37638-149d-4c1b-b3de-992a6ff19c95";

// METADATOS
const METADATA = {
  // App Info Localization
  subtitle: "Gestiona tus clientes y rutinas",
  privacyPolicyUrl: "https://trainerstudio.io/privacy",

  // Version Localization
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

TrainerStudio Coach te ayuda a escalar tu negocio de entrenamiento personal, mejorando la experiencia de tus clientes y optimizando tu tiempo.

¿Tienes dudas? Contacta con nuestro equipo de soporte en support@trainerstudio.io`,

  keywords: "entrenador personal,fitness,rutinas,clientes,gym,nutricion,ejercicios,planes,personal trainer,workout",

  supportUrl: "https://trainerstudio.io/support",
  marketingUrl: "https://trainerstudio.io",

  whatsNew: "Primera versión de TrainerStudio Coach. ¡Bienvenido!"
};

async function main() {
  console.log("=== ACTUALIZANDO METADATOS DE TRAINERSTUDIO COACH ===\n");

  // 1. Actualizar App Info Localization (subtítulo, privacy URL)
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

  // 2. Actualizar Version Localization (descripción, keywords, URLs, what's new)
  console.log("\n2. Actualizando Version Localization...");
  const versionLocResult = await apiCall("PATCH", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID, {
    data: {
      type: "appStoreVersionLocalizations",
      id: VERSION_LOC_ID,
      attributes: {
        description: METADATA.description,
        keywords: METADATA.keywords,
        supportUrl: METADATA.supportUrl,
        marketingUrl: METADATA.marketingUrl,
        whatsNew: METADATA.whatsNew
      }
    }
  });
  console.log("   Status:", versionLocResult.status);
  if (versionLocResult.status !== 200) {
    console.log("   Error:", JSON.stringify(versionLocResult.data.errors || versionLocResult.data, null, 2));
  } else {
    console.log("   ✓ Descripción, Keywords, URLs y What's New actualizados");
  }

  // 3. Actualizar Age Rating Declaration
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
        kidsAgeBand: null
      }
    }
  });
  console.log("   Status:", ageRatingResult.status);
  if (ageRatingResult.status !== 200) {
    console.log("   Error:", JSON.stringify(ageRatingResult.data.errors || ageRatingResult.data, null, 2));
  } else {
    console.log("   ✓ Clasificación de edad configurada (4+)");
  }

  // 4. Asignar categoría primaria (Health & Fitness)
  console.log("\n4. Asignando categoría primaria (Health & Fitness)...");
  const categoryResult = await apiCall("PATCH", "/v1/appInfos/" + APP_INFO_ID, {
    data: {
      type: "appInfos",
      id: APP_INFO_ID,
      relationships: {
        primaryCategory: {
          data: {
            type: "appCategories",
            id: "HEALTH_AND_FITNESS"
          }
        },
        secondaryCategory: {
          data: {
            type: "appCategories",
            id: "BUSINESS"
          }
        }
      }
    }
  });
  console.log("   Status:", categoryResult.status);
  if (categoryResult.status !== 200) {
    console.log("   Error:", JSON.stringify(categoryResult.data.errors || categoryResult.data, null, 2));
  } else {
    console.log("   ✓ Categorías asignadas: Health & Fitness (primaria), Business (secundaria)");
  }

  console.log("\n=== RESUMEN ===");
  console.log("✓ Subtítulo: " + METADATA.subtitle);
  console.log("✓ Privacy URL: " + METADATA.privacyPolicyUrl);
  console.log("✓ Support URL: " + METADATA.supportUrl);
  console.log("✓ Marketing URL: " + METADATA.marketingUrl);
  console.log("✓ Keywords: " + METADATA.keywords);
  console.log("✓ What's New: Configurado");
  console.log("✓ Descripción: " + METADATA.description.substring(0, 50) + "...");
}

main().catch(console.error);
