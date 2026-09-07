const jwt = require("jsonwebtoken");
const fs = require("fs");
const https = require("https");
const crypto = require("crypto");
const path = require("path");
const { URL } = require("url");

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

function apiCall(method, apiPath, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "api.appstoreconnect.apple.com",
      path: apiPath,
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

function uploadToUrl(uploadUrl, method, fileData, headers) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(uploadUrl);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: headers
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", chunk => data += chunk);
      res.on("end", () => resolve({ status: res.statusCode, data: data }));
    });
    req.on("error", reject);
    req.write(fileData);
    req.end();
  });
}

const VERSION_LOC_ID = "8fd53b92-3220-4917-b622-01b2012a54c6";

// Descripción con email correcto (.io)
const description = `TrainerStudio Coach es la herramienta definitiva para entrenadores personales y profesionales del fitness.

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

¿Dudas? info@trainerstudio.io`;

async function main() {
  // 1. Corregir email en descripción
  console.log("1. Actualizando descripción con email correcto (info@trainerstudio.io)...");
  const descResult = await apiCall("PATCH", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID, {
    data: {
      type: "appStoreVersionLocalizations",
      id: VERSION_LOC_ID,
      attributes: { description: description }
    }
  });
  console.log("   " + (descResult.status === 200 ? "✓" : "✗") + " Descripción actualizada");

  // 2. Obtener los screenshots reservados y completar upload
  console.log("\n2. Completando subida de screenshots...");

  const screenshotSetId = "06d35ddd-366d-4e46-9d6e-2b2522d7f963";
  const screenshots = await apiCall("GET", "/v1/appScreenshotSets/" + screenshotSetId + "/appScreenshots?limit=10");

  if (!screenshots.data.data || screenshots.data.data.length === 0) {
    console.log("   No hay screenshots pendientes");
    return;
  }

  const screenshotFiles = [
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (1).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (2).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (3).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (4).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (5).png"
  ];

  for (let i = 0; i < screenshots.data.data.length; i++) {
    const screenshot = screenshots.data.data[i];
    const state = screenshot.attributes.assetDeliveryState.state;
    const screenshotId = screenshot.id;

    console.log("\n   [" + (i+1) + "] ID: " + screenshotId);
    console.log("       Estado: " + state);

    if (state === "AWAITING_UPLOAD" && screenshot.attributes.uploadOperations) {
      const uploadOps = screenshot.attributes.uploadOperations;
      const filePath = screenshotFiles[i];

      if (fs.existsSync(filePath)) {
        const fileData = fs.readFileSync(filePath);

        for (const op of uploadOps) {
          console.log("       Subiendo a: " + op.url.substring(0, 50) + "...");

          const headers = {};
          if (op.requestHeaders) {
            op.requestHeaders.forEach(h => headers[h.name] = h.value);
          }
          headers["Content-Length"] = op.length || fileData.length;

          const uploadResult = await uploadToUrl(op.url, op.method, fileData.slice(op.offset || 0, (op.offset || 0) + (op.length || fileData.length)), headers);
          console.log("       Upload status: " + uploadResult.status);
        }

        // Commit el upload
        const checksum = crypto.createHash("md5").update(fileData).digest("base64");
        console.log("       Confirmando upload...");
        const commitResult = await apiCall("PATCH", "/v1/appScreenshots/" + screenshotId, {
          data: {
            type: "appScreenshots",
            id: screenshotId,
            attributes: {
              sourceFileChecksum: checksum,
              uploaded: true
            }
          }
        });
        console.log("       Commit status: " + commitResult.status);
      }
    } else if (state === "UPLOAD_COMPLETE" || state === "COMPLETE") {
      console.log("       ✓ Ya subido");
    }
  }

  console.log("\n=== VERIFICACIÓN FINAL ===");
  const finalCheck = await apiCall("GET", "/v1/appScreenshotSets/" + screenshotSetId + "/appScreenshots");
  console.log("Screenshots en el set: " + (finalCheck.data.data ? finalCheck.data.data.length : 0));
  if (finalCheck.data.data) {
    finalCheck.data.data.forEach((s, i) => {
      console.log("  " + (i+1) + ". " + s.attributes.assetDeliveryState.state);
    });
  }
}

main().catch(console.error);
