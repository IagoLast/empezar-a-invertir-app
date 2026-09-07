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

const APP_INFO_LOC_ID = "f00e9ca5-9819-4760-ab55-0bcff8f68149";
const VERSION_LOC_ID = "8fd53b92-3220-4917-b622-01b2012a54c6";

async function main() {
  console.log("Actualizando URLs a trainerstudio.com...\n");

  // 1. App Info Localization (Privacy URL)
  console.log("1. Privacy URL...");
  const r1 = await apiCall("PATCH", "/v1/appInfoLocalizations/" + APP_INFO_LOC_ID, {
    data: {
      type: "appInfoLocalizations",
      id: APP_INFO_LOC_ID,
      attributes: {
        privacyPolicyUrl: "https://trainerstudio.com/privacy"
      }
    }
  });
  console.log("   " + (r1.status === 200 ? "✓" : "✗") + " Privacy URL: https://trainerstudio.com/privacy");

  // 2. Version Localization (Support + Marketing URLs)
  console.log("2. Support y Marketing URLs...");
  const r2 = await apiCall("PATCH", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID, {
    data: {
      type: "appStoreVersionLocalizations",
      id: VERSION_LOC_ID,
      attributes: {
        supportUrl: "https://trainerstudio.com/support",
        marketingUrl: "https://trainerstudio.com"
      }
    }
  });
  console.log("   " + (r2.status === 200 ? "✓" : "✗") + " Support URL: https://trainerstudio.com/support");
  console.log("   " + (r2.status === 200 ? "✓" : "✗") + " Marketing URL: https://trainerstudio.com");

  console.log("\n✅ URLs actualizadas a trainerstudio.com");
}

main().catch(console.error);
