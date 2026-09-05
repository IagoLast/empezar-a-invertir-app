# Empezar a invertir

**Dinero virtual. Lo que aprendes, es real.**

V0 nativa para iPhone: aprende acciones, ETF, bonos y valoración comprando y vendiendo con 10.000 $ virtuales iniciales y precios reales de **Twelve Data**. Diseño en español, SwiftUI, blanco y azul por defecto, modo oscuro opcional en Perfil → Apariencia, tres pestañas y confirmación de cada orden. Sin análisis técnico.

[Ver capturas reales del simulador de iPhone](docs/screenshots/README.md). El CI genera capturas claras y oscuras de cartera, mercados, perfil, ficha, compra y aprendizaje después de compilar y pasar los tests, sin credenciales ni precios inventados. En las PR se adjuntan como artefacto; en `main` se actualizan en el repositorio.

## Monorepo

| Directorio | Responsabilidad |
|---|---|
| `apps/ios` | App SwiftUI para iOS 17+, autenticación por código, Keychain y RevenueCat |
| `apps/api` | Funciones Vercel / Node.js, autenticación, cotizaciones y webhook |
| `packages/contracts` | Catálogo y lecciones compartidos; contrato HTTP |
| `supabase` | Migración Postgres, RLS y pruebas del motor transaccional |
| `scripts` | Preparación de recursos iOS y automatización de TestFlight |
| `.github/workflows` | CI de API, Postgres e iOS; subida manual a TestFlight |

## Probar la interfaz en Xcode

Requisitos: macOS con Xcode, Node 22+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/IagoLast/empezar-a-invertir-app.git
cd empezar-a-invertir-app
brew install xcodegen
npm run ios:prepare
cd apps/ios
xcodegen generate
open Empezar.xcodeproj
```

Selecciona un simulador iPhone y ejecuta **Empezar**. Sin configuración puedes explorar las pantallas y lecciones; las cotizaciones y compras permanecen deshabilitadas. La app no genera precios falsos como sustituto de la API. Para conectar los servicios, sigue [SETUP.md](docs/SETUP.md).

## Interfaz

- Cartera centrada en valor total, invertido, efectivo y resultado por posición; movimientos en una vista separada.
- Búsqueda por nombre o símbolo dentro del catálogo disponible y filtros de acciones, ETF y ETF de bonos.
- Ficha con precio, posición, coste medio y acciones de compra/venta; selector de unidades con máximo disponible y revisión explícita.
- Apariencia persistente en **Perfil → Apariencia**: Claro (predeterminado), Oscuro o Sistema.
- Controles Liquid Glass con SDK/iOS 26; materiales nativos en iOS 17–18 y superficies opacas con Reducir transparencia. Las tarjetas de datos conservan contraste.
- Dirección visual inspirada en [Revolut X](https://www.revolut.com/revolut-x/) y [Coinbase](https://www.coinbase.com/advanced-trade): jerarquía financiera, acciones claras y navegación directa, adaptadas a una identidad blanca y azul.

## Lo que incluye

- Cartera, posiciones, distribución, efectivo y movimientos. Las aportaciones y recargas no cuentan como beneficio.
- Compra y venta de unidades enteras de AAPL, MSFT, VTI y BND. Solo USD en esta V0.
- Cotizaciones reales, fuente, hora, modalidad del feed y estado de mercado. El servidor bloquea precios caducados y mercado cerrado.
- Revisión de orden, comisión simulada explícita de 1 $, confirmación y reintento con la misma clave de idempotencia.
- Cuatro lecciones y laboratorio de valoración con supuestos editables; datos fundamentales opcionales mediante el endpoint statistics del proveedor.
- Login por OTP de correo, sesión en Keychain y eliminación de cuenta.
- Recargas consumibles RevenueCat de 10.000 y 25.000 dólares virtuales. El precio real se toma de App Store; el saldo solo lo acredita el webhook del servidor.
- Dedupe por evento y transacción de Apple, separación sandbox/producción, reembolsos y orden inverso refund/purchase.

## Verificación

```bash
npm test
```

20 pruebas de la API, validación de contratos, pruebas de cartera y RLS sobre PostgreSQL, compilación SwiftUI y tests nativos en GitHub Actions. [Ver CI](https://github.com/IagoLast/empezar-a-invertir-app/actions/workflows/ci.yml).

[TestFlight: workflow, credenciales y ejecución](docs/TESTFLIGHT.md). La subida firmada necesita configurar los secrets de Apple; aún no se ha subido un build.

## Límites explícitos de la V0

Las órdenes se simulan al último precio del feed, con una comisión fija. No hay bid/ask, profundidad, fracciones, órdenes limitadas, ejecución fuera de sesión, cambio de divisas, dividendos, splits ni intereses. El P&L es variación de precio neta de las comisiones implementadas; no rentabilidad total con distribuciones. Estas limitaciones también aparecen en la app.

**BND es un ETF de bonos**, no un bono individual. Los bonos individuales se explican en las lecciones; requieren ampliar datos y motor de cálculo para negociarlos. Las compras IAP son opcionales, no hay rankings ni mecanismos que obliguen a recargar.

Antes de una beta externa: contratar derechos de display/redistribución para el feed de Twelve Data, desplegar servicios, configurar App Store Connect/RevenueCat, probar compras sandbox de extremo a extremo y completar política de privacidad y metadatos de la app. El feed US por defecto de Twelve Data es parcial, no un precio consolidado NBBO. [Detalles y fuentes](docs/SETUP.md#datos-reales-y-licencia).
