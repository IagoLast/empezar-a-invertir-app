const jwt = require("jsonwebtoken");
const fs = require("fs");

// Cargar .env manualmente
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
  header: {
    alg: "ES256",
    kid: process.env.APPLE_KEY_ID,
    typ: "JWT"
  }
});

// Hacer llamada a la API
const https = require("https");
const options = {
  hostname: "api.appstoreconnect.apple.com",
  path: "/v1/apps",
  method: "GET",
  headers: {
    "Authorization": "Bearer " + token
  }
};

const req = https.request(options, (res) => {
  let data = "";
  res.on("data", chunk => data += chunk);
  res.on("end", () => {
    const json = JSON.parse(data);
    if (json.data) {
      json.data.forEach(app => {
        console.log("App: " + app.attributes.name);
        console.log("  Bundle ID: " + app.attributes.bundleId);
        console.log("  ID: " + app.id);
        console.log("");
      });
    } else {
      console.log(JSON.stringify(json, null, 2));
    }
  });
});

req.on("error", e => console.error(e));
req.end();
