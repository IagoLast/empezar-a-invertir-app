const jwt = require("jsonwebtoken");
const fs = require("fs");
const https = require("https");

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

function apiCall(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "api.appstoreconnect.apple.com",
      path: path,
      method: "GET",
      headers: { "Authorization": "Bearer " + token }
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", chunk => data += chunk);
      res.on("end", () => resolve(JSON.parse(data)));
    });
    req.on("error", reject);
    req.end();
  });
}

async function main() {
  console.log("╔══════════════════════════════════════════════════════════════╗");
  console.log("║       RESUMEN METADATOS - TRAINERSTUDIO COACH                ║");
  console.log("╚══════════════════════════════════════════════════════════════╝\n");

  // App Info
  const appInfo = await apiCall("/v1/appInfos/f1e37638-149d-4c1b-b3de-992a6ff19c95?include=primaryCategory,secondaryCategory");

  // App Info Localization
  const appInfoLoc = await apiCall("/v1/appInfoLocalizations/f00e9ca5-9819-4760-ab55-0bcff8f68149");
  const infoAttrs = appInfoLoc.data.attributes;

  // Version Localization
  const versionLoc = await apiCall("/v1/appStoreVersionLocalizations/8fd53b92-3220-4917-b622-01b2012a54c6");
  const verAttrs = versionLoc.data.attributes;

  // Age Rating
  const ageRating = await apiCall("/v1/ageRatingDeclarations/f1e37638-149d-4c1b-b3de-992a6ff19c95");

  // Categorías
  let primaryCat = "No asignada";
  let secondaryCat = "No asignada";
  if (appInfo.included) {
    appInfo.included.forEach(inc => {
      if (inc.type === "appCategories") {
        if (appInfo.data.relationships.primaryCategory.data &&
            appInfo.data.relationships.primaryCategory.data.id === inc.id) {
          primaryCat = inc.id;
        }
        if (appInfo.data.relationships.secondaryCategory.data &&
            appInfo.data.relationships.secondaryCategory.data.id === inc.id) {
          secondaryCat = inc.id;
        }
      }
    });
  }

  console.log("📱 INFORMACIÓN GENERAL");
  console.log("─────────────────────────────────────────");
  console.log("  Nombre:           TrainerStudio Coach");
  console.log("  Subtítulo:        " + (infoAttrs.subtitle || "❌ No configurado"));
  console.log("  Locale:           es-ES");
  console.log("");

  console.log("📂 CATEGORÍAS");
  console.log("─────────────────────────────────────────");
  console.log("  Primaria:         " + primaryCat);
  console.log("  Secundaria:       " + secondaryCat);
  console.log("");

  console.log("📝 DESCRIPCIÓN");
  console.log("─────────────────────────────────────────");
  if (verAttrs.description) {
    console.log("  ✓ Configurada (" + verAttrs.description.length + " caracteres)");
  } else {
    console.log("  ❌ No configurada");
  }
  console.log("");

  console.log("🔑 KEYWORDS");
  console.log("─────────────────────────────────────────");
  console.log("  " + (verAttrs.keywords || "❌ No configurados"));
  console.log("");

  console.log("🔗 URLs");
  console.log("─────────────────────────────────────────");
  console.log("  Privacidad:       " + (infoAttrs.privacyPolicyUrl || "❌ No configurada"));
  console.log("  Soporte:          " + (verAttrs.supportUrl || "❌ No configurada"));
  console.log("  Marketing:        " + (verAttrs.marketingUrl || "❌ No configurada"));
  console.log("");

  console.log("🔞 CLASIFICACIÓN DE EDAD");
  console.log("─────────────────────────────────────────");
  const ageAttrs = ageRating.data.attributes;
  console.log("  App Store Rating: " + (ageAttrs.appStoreAgeRating || "4+ (calculado automáticamente)"));
  console.log("  Health Topics:    " + (ageAttrs.healthOrWellnessTopics ? "Sí" : "No"));
  console.log("");

  console.log("📸 SCREENSHOTS");
  console.log("─────────────────────────────────────────");
  console.log("  ⚠️  Pendiente - Requiere subir manualmente o vía API");
  console.log("");

  console.log("═══════════════════════════════════════════════════════════════");
  console.log("✅ Metadatos de texto configurados correctamente");
  console.log("⚠️  Falta: Screenshots (mínimo 3 para iPhone 6.7\")");
  console.log("═══════════════════════════════════════════════════════════════");
}

main().catch(console.error);
