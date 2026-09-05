# Contrato HTTP V0

JSON, importes en céntimos enteros de **USD**, unidades enteras, fechas ISO 8601 UTC. Todos los endpoints salvo el webhook requieren `Authorization: Bearer <Supabase access token>` de un usuario verificado. Las respuestas incluyen `Cache-Control: no-store`.

| Método | Ruta | Entrada | Salida |
|---|---|---|---|
| GET | `/api/state` | — | Portfolio |
| GET | `/api/quote?symbol=AAPL` | Símbolo del catálogo | Quote |
| GET | `/api/fundamentals?symbol=AAPL` | AAPL o MSFT | `{available, symbol?, pe?, eps?, period?, source?, fetchedAt?}` |
| POST | `/api/trade` | `{requestId: UUID, symbol, side: buy\|sell, units: 1..100000, quoteId: UUID}` | Portfolio tras la transacción |
| POST | `/api/lesson` | `{lessonId: lesson-1..lesson-4}` | Portfolio |
| DELETE | `/api/account` | — | `{deleted: true}` |
| POST | `/api/revenuecat` | Webhook v1 RevenueCat + Authorization configurado | `{received: true, appliedCents?, duplicate?, ignored?}` |

**Portfolio**: `userId`, `currency`, `cashCents`, `contributedCents`, `positions`, `quotes`, `orders`, `completedLessons`, `purchases`.

- Position: `{symbol, units, costCents}`; coste medio agregado, incluye comisiones de compra.
- Order: `{id, requestId, symbol, side, units, priceCents, feeCents, createdAt}`; se devuelven las 50 más recientes.
- Purchase: `{transactionId, productId, credited, refunded}`.
- Quote: `{id, symbol, priceCents, currency, changePercent, asOf, fetchedAt, expiresAt, marketOpen, tradable, mode, delaySeconds, source}`.

La cartera no inventa una valoración para posiciones sin precio. `equity = cash + sum(units × quote.priceCents)`. `profit = equity - contributedCents`; es resultado absoluto, no una rentabilidad ponderada por tiempo. Un dato antiguo se etiqueta como tal.

Errores: `{error: CODE, message: mensaje en español}`. `400` datos inválidos, `401/403` sesión, `409` saldo/unidades/precio/mercado/conflicto de idempotencia, `503` proveedor o servidor no disponible.

La app conserva `requestId` y el cuerpo de una orden pendiente. Un timeout no demuestra que haya fallado: se reenvía el mismo cuerpo. La DB devuelve éxito si ya estaba ejecutada y rechaza reutilizar la clave con otro contenido. Un nuevo precio requiere nueva revisión y nueva clave después de resolver el intento anterior.

`quoteId` identifica una cotización emitida por el servidor y válida durante 60 segundos. Ningún precio ni ID de usuario enviado por el cliente puede sustituir el precio guardado o `auth.uid()`. Las operaciones se bloquean si el instrumento está desactivado, el dato está caducado o el mercado está cerrado.
