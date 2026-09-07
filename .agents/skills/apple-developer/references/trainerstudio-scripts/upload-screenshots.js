const jwt = require("jsonwebtoken");
const fs = require("fs");
const https = require("https");
const crypto = require("crypto");
const path = require("path");

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

const VERSION_LOC_ID = "8fd53b92-3220-4917-b622-01b2012a54c6";

async function main() {
  console.log("=== SUBIENDO SCREENSHOTS ===\n");

  // 1. Verificar si ya existe un screenshot set para iPhone 6.7"
  console.log("1. Verificando screenshot sets existentes...");
  const setsResponse = await apiCall("GET", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID + "/appScreenshotSets");

  let screenshotSetId = null;

  if (setsResponse.data.data && setsResponse.data.data.length > 0) {
    // Buscar set para APP_IPHONE_67
    const existingSet = setsResponse.data.data.find(s => s.attributes.screenshotDisplayType === "APP_IPHONE_67");
    if (existingSet) {
      screenshotSetId = existingSet.id;
      console.log("   ✓ Set existente encontrado: " + screenshotSetId);
    }
  }

  // 2. Crear screenshot set si no existe
  if (!screenshotSetId) {
    console.log("2. Creando screenshot set para iPhone 6.7\"...");
    const createSetResponse = await apiCall("POST", "/v1/appScreenshotSets", {
      data: {
        type: "appScreenshotSets",
        attributes: {
          screenshotDisplayType: "APP_IPHONE_67"
        },
        relationships: {
          appStoreVersionLocalization: {
            data: {
              type: "appStoreVersionLocalizations",
              id: VERSION_LOC_ID
            }
          }
        }
      }
    });

    if (createSetResponse.status === 201) {
      screenshotSetId = createSetResponse.data.data.id;
      console.log("   ✓ Screenshot set creado: " + screenshotSetId);
    } else {
      console.log("   ✗ Error:", JSON.stringify(createSetResponse.data.errors || createSetResponse.data, null, 2));
      return;
    }
  }

  // 3. Listar screenshots que ya están en el set
  console.log("\n3. Verificando screenshots existentes...");
  const existingScreenshots = await apiCall("GET", "/v1/appScreenshotSets/" + screenshotSetId + "/appScreenshots");
  const existingCount = existingScreenshots.data.data ? existingScreenshots.data.data.length : 0;
  console.log("   Screenshots actuales: " + existingCount);

  // 4. Preparar lista de archivos a subir
  const screenshotFiles = [
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (1).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (2).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (3).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (4).png",
    "/Users/iagolast/Downloads/app.trainerstudio.io_(iPhone 14 Pro Max) (5).png"
  ];

  console.log("\n4. Reservando espacio para " + screenshotFiles.length + " screenshots...");

  for (let i = 0; i < screenshotFiles.length; i++) {
    const filePath = screenshotFiles[i];
    const fileName = path.basename(filePath);
    const fileData = fs.readFileSync(filePath);
    const fileSize = fileData.length;
    const checksum = crypto.createHash("md5").update(fileData).digest("base64");

    console.log("\n   [" + (i+1) + "/" + screenshotFiles.length + "] " + fileName);
    console.log("       Size: " + fileSize + " bytes, MD5: " + checksum);

    // Reservar screenshot
    const reserveResponse = await apiCall("POST", "/v1/appScreenshots", {
      data: {
        type: "appScreenshots",
        attributes: {
          fileName: fileName,
          fileSize: fileSize
        },
        relationships: {
          appScreenshotSet: {
            data: {
              type: "appScreenshotSets",
              id: screenshotSetId
            }
          }
        }
      }
    });

    if (reserveResponse.status === 201) {
      const screenshotId = reserveResponse.data.data.id;
      const uploadOps = reserveResponse.data.data.attributes.uploadOperations;
      console.log("       ✓ Reservado: " + screenshotId);
      console.log("       Upload operations: " + (uploadOps ? uploadOps.length : 0));

      if (uploadOps && uploadOps.length > 0) {
        // La API devuelve instrucciones de upload que necesitamos seguir
        console.log("       → Subida requiere operaciones adicionales (ver App Store Connect)");
      }
    } else {
      console.log("       ✗ Error:", JSON.stringify(reserveResponse.data.errors || reserveResponse.data, null, 2));
    }
  }

  console.log("\n=== RESUMEN ===");
  console.log("Los screenshots han sido reservados.");
  console.log("La subida de archivos binarios requiere seguir el protocolo de upload de Apple.");
  console.log("Recomendación: Usa 'Transporter' o App Store Connect web para completar la subida.");
}

main().catch(console.error);
