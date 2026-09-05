# Conectar la V0

## 1. Supabase

1. Crea un proyecto de Supabase.
2. Ejecuta `supabase/migrations/202609050001_initial.sql` en el SQL Editor. Está pensada para un proyecto nuevo. No ejecutes los archivos `test-*.sql` en tu proyecto: crean identidades y datos únicamente para una base desechable de pruebas.
3. Activa login por correo. En Authentication → Email Templates → Magic Link, muestra `{{ .Token }}` para enviar un código en lugar de un enlace. Configura tu SMTP para una beta con usuarios reales.
4. No actives usuarios anónimos. La API requiere usuario verificado.
5. Conserva URL, clave publishable/anon y service-role/secret. La última **solo** va en Vercel.

RLS permite leer únicamente la cartera de cada usuario. El cliente no puede escribir saldos, posiciones, cotizaciones ni transacciones de pago. Los RPC de trading usan `auth.uid()`, bloquean la fila de la cartera y registran orden y movimiento dentro de la misma transacción.

## 2. Vercel

Importa este repositorio. Configura **Root Directory = `apps/api`**, framework **Other**, sin comando de build ni directorio de salida personalizado. Los handlers de `api/*.js` se despliegan como funciones Node.js. Las rutas son `/api/state`, `/api/quote`, etc.

Copia las variables de `apps/api/.env.example` a Environment Variables en Vercel:

| Variable | Uso |
|---|---|
| `SUPABASE_URL` | URL del proyecto |
| `SUPABASE_ANON_KEY` | Clave pública publishable/anon |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave secreta de servidor para RPC de datos/pagos y eliminación de cuenta |
| `TWELVE_DATA_API_KEY` | Clave privada del proveedor de mercado |
| `MARKET_DATA_MODE` | `realtime`, `delayed` o `eod`, según el feed contratado |
| `MARKET_DATA_DELAY_SECONDS` | `0` para realtime; retraso contratado en segundos para delayed |
| `ENABLE_FUNDAMENTALS` | `true` solo con acceso a `/statistics`; en otro caso los ratios se muestran como no disponibles |
| `REVENUECAT_WEBHOOK_AUTH` | Valor aleatorio largo que RevenueCat enviará exactamente en Authorization |
| `REVENUECAT_APP_ID` | ID de la app iOS en RevenueCat (`app_…`) |
| `REVENUECAT_ENVIRONMENT` | `SANDBOX` para desarrollo/TestFlight, `PRODUCTION` para compras de producción |

Usa proyectos separados de Vercel/Supabase para sandbox y producción. La app de RevenueCat debe tener un webhook para cada backend, filtrado por entorno. Los datos y saldos no se comparten entre esos dos backends.

Desarrollo local:

```bash
cd apps/api
cp .env.example .env
# Completa .env localmente.
node --env-file=.env dev.js
```

El servidor local escucha en `127.0.0.1:3000`. La app mantiene HTTPS obligatorio; para el simulador utiliza el despliegue HTTPS de Vercel o un túnel HTTPS propio. No se incluye una excepción ATS global.

## 3. iOS

Ejecuta `npm run ios:prepare`. Crea recursos a partir de `packages/contracts` y copia `Config.example.plist` cuando falta la configuración. Edita `apps/ios/Empezar/Resources/Config.plist` (ignorado por git):

- `API_BASE_URL`: URL de Vercel, sin barra final ni `/api`.
- `SUPABASE_URL` y `SUPABASE_ANON_KEY`: valores públicos del mismo proyecto.
- `REVENUECAT_PUBLIC_KEY`: clave SDK iOS `appl_…`.

No incluyas service-role, la clave Twelve Data, `.p8`, `.p12` ni el secreto del webhook en la app. Genera el proyecto con XcodeGen después de preparar recursos. En un dispositivo real, selecciona tu equipo de firma y un Bundle ID registrado.

## 4. App Store Connect y RevenueCat

Crea dos productos **Consumable**, con los identificadores exactos:

| Product ID | Saldo acreditado por el backend |
|---|---:|
| `ei.cash.10000` | 10.000 $ virtuales |
| `ei.cash.25000` | 25.000 $ virtuales |

Elige los precios reales en App Store Connect. El cliente muestra los precios localizados del producto; no hay precios hardcodeados. Importa los productos a RevenueCat y crea el offering **`virtual-cash`** con un package por producto. No necesitas un entitlement para llevar el saldo: este lo mantiene Postgres.

El SDK se configura **después** del login, usando el UUID de Supabase en minúsculas como `appUserID`. No se permite comprar con un ID anónimo de RevenueCat. La app espera el webhook antes de mostrar el nuevo saldo; nunca acredita basándose en `CustomerInfo`.

Configura RevenueCat → Integrations → Webhooks:

- URL: `https://TU_BACKEND/api/revenuecat`.
- Authorization: valor exacto de `REVENUECAT_WEBHOOK_AUTH`.
- App y entorno: los mismos del backend.
- Eventos: `NON_RENEWING_PURCHASE` y `CANCELLATION`; la V0 maneja refunds de compra única con `cancel_reason=CUSTOMER_SUPPORT`.
- Conecta App Store Server Notifications con RevenueCat para recibir refunds de compras únicas.

Los eventos duplicados y las transacciones duplicadas no vuelven a acreditar saldo. Los fallos de DB devuelven error para que RevenueCat reintente; no se responde éxito antes del commit. Si se agotan los reintentos, reenvía el evento desde RevenueCat y comprueba `purchase_receipts` y `ledger`. La V0 no incorpora aún un worker periódico de reconciliación.

Los consumibles comprados no caducan. El saldo se recupera iniciando sesión en la misma cuenta; un botón Restore Purchases no recrearía consumibles ya gastados. Un refund puede dejar saldo virtual negativo si ya se invirtió el crédito: se bloquean nuevas compras, pero se permite vender para recuperar liquidez. Eliminar la cuenta elimina también ese saldo, con confirmación explícita en la app.

## Datos reales y licencia

Se ha elegido **Twelve Data** por su endpoint `/quote`, cobertura de acciones y ETF, timestamps y estado de mercado, y datos fundamentales opcionales. La clave demo pública permite comprobar Apple; no da acceso a todo el catálogo. La aplicación necesita tu propia clave.

Se usa `close` como último precio y `last_quote_at` como timestamp preferente; `timestamp` puede representar la apertura de la vela. La API redondea precios a céntimos y conserva ambos momentos: hora del dato y hora de recepción. La caché compartida limita refrescos a uno por símbolo cada 30 segundos, incluso entre lambdas. Cada cotización caduca a los 60 segundos. Si falla el proveedor, se conserva el dato antiguo y su vencimiento: nunca se convierte en un precio nuevo.

Con mercado abierto se rechazan datos más antiguos que el retraso contratado más 120 segundos. Fuera de mercado y en modo EOD se consulta el último precio, pero no se ejecutan órdenes. No hay cola para la próxima apertura. El feed básico US es parcial (aproximadamente 5 % del volumen según el proveedor); no representa un bid/ask consolidado.

La visualización a usuarios externos necesita los derechos correspondientes de display/redistribución. Las condiciones y add-ons dependen del plan y mercado; verifica con Twelve Data el contrato de tu app antes de publicarla. La caché reduce solicitudes por usuario, pero una sesión activa continua de cuatro símbolos puede superar las cuotas del plan de prueba. Configura el plan, alertas de consumo y límites de Vercel para tu volumen.

Fuentes verificadas durante la implementación:

- [Quote: campos y timestamps](https://twelvedata.com/docs/llms/market-data/quote.md).
- [Statistics: PER, BPA y período reportado](https://twelvedata.com/docs/llms/fundamentals/statistics.md).
- [Feed US y derechos de redistribución](https://support.twelvedata.com/en/articles/9935903-us-equities-market-data).
- [Planes empresariales](https://twelvedata.com/pricing-business).
- [Supabase: funciones y permisos](https://supabase.com/docs/guides/database/functions), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
- [RevenueCat: consumibles](https://www.revenuecat.com/docs/platform-resources/non-subscriptions), [webhooks e idempotencia](https://www.revenuecat.com/docs/integrations/webhooks).
- [Apple: IAP y saldo que no caduca](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase).

## Para una beta externa

Probar en sandbox: comprar los dos packs, cancelar en StoreKit, reabrir la app con una compra pendiente, duplicar el webhook, reembolsar antes y después de gastar saldo, comprobar otra cuenta y borrar la cuenta. Validar la cotización en apertura/cierre de sesión con el plan real. Completar una política de privacidad propia, App Privacy en App Store Connect y los datos de contacto. Las pruebas automatizadas no sustituyen la validación de estas integraciones con credenciales reales.
