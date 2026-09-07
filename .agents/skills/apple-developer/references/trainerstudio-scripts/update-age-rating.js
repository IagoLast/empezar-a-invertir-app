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

const AGE_RATING_ID = "f1e37638-149d-4c1b-b3de-992a6ff19c95";

async function main() {
  console.log("Actualizando Age Rating Declaration...\n");

  const result = await apiCall("PATCH", "/v1/ageRatingDeclarations/" + AGE_RATING_ID, {
    data: {
      type: "ageRatingDeclarations",
      id: AGE_RATING_ID,
      attributes: {
        // Strings con valores NONE/INFREQUENT_OR_MILD/FREQUENT_OR_INTENSE
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
        gunsOrOtherWeapons: "NONE",

        // Booleans
        gambling: false,
        unrestrictedWebAccess: false,
        parentalControls: false,
        healthOrWellnessTopics: true,
        messagingAndChat: false,
        ageAssurance: false,
        advertising: false,
        lootBox: false,
        userGeneratedContent: false
      }
    }
  });

  console.log("Status:", result.status);
  if (result.status !== 200) {
    console.log("Error:", JSON.stringify(result.data.errors || result.data, null, 2));
  } else {
    console.log("✓ Age Rating configurado correctamente");
    console.log("\nDetalles:");
    const attrs = result.data.data.attributes;
    console.log("  App Store Age Rating:", attrs.appStoreAgeRating || "Pendiente de cálculo");
  }
}

main().catch(console.error);
