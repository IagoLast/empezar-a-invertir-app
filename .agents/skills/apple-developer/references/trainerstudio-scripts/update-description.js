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

const VERSION_LOC_ID = "8fd53b92-3220-4917-b622-01b2012a54c6";

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

¿Dudas? support@trainerstudio.com`;

async function main() {
  console.log("Actualizando descripción con email correcto...");

  const r = await apiCall("PATCH", "/v1/appStoreVersionLocalizations/" + VERSION_LOC_ID, {
    data: {
      type: "appStoreVersionLocalizations",
      id: VERSION_LOC_ID,
      attributes: {
        description: description
      }
    }
  });

  console.log(r.status === 200 ? "✓ Descripción actualizada (email: support@trainerstudio.com)" : "✗ Error: " + JSON.stringify(r.data));
}

main().catch(console.error);
