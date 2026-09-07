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
  const appInfoId = "f1e37638-149d-4c1b-b3de-992a6ff19c95";
  const versionId = "baa476d6-d3d0-4e6a-adf0-673dd7dfb998";

  console.log("=== APP INFO LOCALIZATIONS ===");
  const appInfoLocs = await apiCall("/v1/appInfos/" + appInfoId + "/appInfoLocalizations");
  console.log(JSON.stringify(appInfoLocs, null, 2));

  console.log("\n=== APP STORE VERSION LOCALIZATIONS ===");
  const versionLocs = await apiCall("/v1/appStoreVersions/" + versionId + "/appStoreVersionLocalizations");
  console.log(JSON.stringify(versionLocs, null, 2));

  console.log("\n=== AGE RATING DECLARATION ===");
  const ageRating = await apiCall("/v1/appInfos/" + appInfoId + "/ageRatingDeclaration");
  console.log(JSON.stringify(ageRating, null, 2));
}

main().catch(console.error);
