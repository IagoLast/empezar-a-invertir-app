# CI y TestFlight

El workflow **Verify V0** comprueba la API, los contratos, PostgreSQL y la app nativa con cada push a `main`. **Upload to TestFlight** se ejecuta manualmente desde Actions, exclusivamente sobre `main`. No se ejecuta en pull requests ni sube nada automáticamente.

La compilación sin firma funciona sin cuenta de Apple. Para TestFlight hacen falta Apple Developer Program, la ficha de la app en App Store Connect, el Bundle ID registrado y los materiales de firma. La API de Vercel y Supabase deben estar desplegados para que el build permita operar.

## Dónde poner las credenciales

En [Settings → Environments](https://github.com/IagoLast/empezar-a-invertir-app/settings/environments), crea el entorno `testflight`. Añade sus **secrets** y **variables**. No envíes las claves por chat ni las guardes en el repositorio. Puedes proteger ese entorno para que cada subida requiera tu revisión.

| Secret | Contenido |
|---|---|
| `ASC_API_KEY_P8_BASE64` | Archivo `.p8` de una Team API Key de App Store Connect, codificado en Base64 |
| `ASC_KEY_ID` | Key ID de esa clave |
| `ASC_ISSUER_ID` | Issuer ID del equipo de App Store Connect |
| `APPLE_CERTIFICATE_P12_BASE64` | Certificado Apple Distribution **con su clave privada**, exportado a `.p12` y codificado en Base64 |
| `APPLE_CERTIFICATE_PASSWORD` | Contraseña de exportación del `.p12` |
| `APPLE_PROFILE_BASE64` | Perfil de distribución App Store para esta app y este certificado, codificado en Base64 |

| Variable | Ejemplo / uso |
|---|---|
| `APPLE_TEAM_ID` | Identificador de 10 caracteres del equipo Apple Developer |
| `IOS_BUNDLE_ID` | `com.empezarainvertir.app` por defecto; debe coincidir con el perfil y App Store Connect |
| `API_BASE_URL` | URL HTTPS del backend Vercel, sin `/api` ni barra final |
| `SUPABASE_URL` | URL HTTPS del proyecto Supabase |
| `SUPABASE_ANON_KEY` | Clave pública publishable/anon; nunca `service_role` |
| `REVENUECAT_PUBLIC_KEY` | Clave pública iOS `appl_…` de RevenueCat |

Para copiar un archivo en Base64 desde macOS, sin imprimirlo en la terminal:

```bash
base64 -i AuthKey_ABC123.p8 | tr -d '\n' | pbcopy
```

Pega el portapapeles directamente en el secret correspondiente. Repite para el `.p12` y el `.mobileprovision`. Usa una clave de equipo de App Store Connect con permisos de subida; App Manager permite gestionar también el ciclo de TestFlight. La contraseña del Apple ID y los códigos de 2FA no son necesarios.

## Ejecutar

1. Abre [Actions → Upload to TestFlight](https://github.com/IagoLast/empezar-a-invertir-app/actions/workflows/testflight.yml).
2. Pulsa **Run workflow** sobre `main`.
3. El job comprueba configuración, importa el certificado en un llavero temporal, verifica el perfil, ejecuta los tests de iOS, archiva, exporta y sube la IPA con `altool` y la API Key.
4. Al terminar, borra el llavero, perfiles, `.p8`, IPA y configuración del runner.
5. Comprueba el procesamiento en App Store Connect → TestFlight y añade el build a tu grupo de testers internos. Una subida aceptada no significa que Apple haya terminado de procesarlo. La distribución externa puede requerir Beta App Review.

El número de build es `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`. Si reutilizas una ficha de App Store Connect con builds superiores, cambia la estrategia de numeración antes de subir. No hay distribución automática a testers ni envío a revisión del App Store.

## Estado de validación

La compilación sin firma se verifica con GitHub Actions. La firma, exportación y subida reales necesitan tus credenciales y no se consideran verificadas hasta que el workflow termine con éxito. No se ha subido un build a TestFlight durante la creación de esta V0.

Referencias: [firma en GitHub Actions](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [API Keys de App Store Connect](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api), [subida de builds con Apple](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).
