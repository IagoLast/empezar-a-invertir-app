# Empezar a invertir

V0 en desarrollo. Simulador educativo con precios reales y dinero virtual.

Monorepo: `apps/ios` (SwiftUI), `apps/api` (Vercel / Node.js), `packages/contracts` (catálogo y contenido compartido), `supabase` (Postgres).

Datos de mercado: Twelve Data. La API key permanece en Vercel. El servidor valida las cotizaciones, conserva sus timestamps y bloquea ejecuciones fuera de mercado o con precios caducados. No hay precios sintéticos en la aplicación.

El trabajo se guarda por incrementos en `main`. La configuración y la guía de arranque se completan junto con la app.
