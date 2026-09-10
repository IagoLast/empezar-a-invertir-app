# Art brief — site illustrations

Inventory of every drawing the site ships, what each one is meant to say, where it appears, and how a new delivery is processed. Every scene slot is covered by delivered art; only the three app screens inside the phone frames are still vector placeholders.

## How to deliver

1. Drop the file in `web/art/`, named after the **site name** of the drawing (`learning`, `practice`, `concepts`, `diversification`, `compound`, `app`, `book`, `emergency`, `inflation`, `markets`, `risk`, `steps`).
2. Run `npm run web:art`. It writes `apps/web/img/illustrations/<name>.png`, deletes the vector placeholder for that name and prints the resulting size.
3. Run `npm run web:build && npm test`.

The converter (`scripts/build-web-art.sh`, ImageMagick) does the housekeeping so the delivery stays simple:

- **Trims** the empty margin, so every drawing fills its slot the same way.
- **Derives the alpha channel from the luminance**, which turns the white paper transparent while keeping the anti-aliased edge of the strokes. This is why deliveries must be **ink on a plain white background**.
- Caps the long side at 1100 px and quantises to a 32-colour palette with transparency (an untouched RGBA PNG of the same drawing is ~650 KB; the processed file is 26–69 KB).
- Dark mode is handled in CSS (the raster art is inverted and its hue rotated back, so the blue accents survive). Nothing has to be delivered twice.

### What the file must be

| Property | Value |
|---|---|
| Format | PNG or JPG. Flat, no transparency needed: the white background is converted. |
| Background | Plain white (`#FFFFFF`), no gradient, no paper texture, no drop shadow, no frame. |
| Ink | Black line work plus the blue accent `#165DDE` (`#2B6CE0` is close enough). Avoid other hues: they invert less predictably. |
| Size | Deliver at 1600 px on the long side or more. The processed file is capped at 1100 px. |
| Text | None. No letters, numbers or currency words baked into the artwork. The current deliveries label the book spines ("INVERSIÓN", "FINANZAS"…), which reads as illustration rather than copy; keep that exception if it helps the scene. |
| Composition | Subject centred, roughly equal margins, one horizontal ground line when the scene stands on the floor. Corners stay quiet: cards crop them with a 24 px radius. |
| Empty space | Leave it really empty: the converter uses the white to cut the shape out. |

### Sizes in use

The art is placed in boxes capped at 190 px (home cards), 170 px (article promos), 380–420 px (feature and hero blocks) and always centred, so a drawing is rarely wider than 700 px on screen. Wider art with a strong horizontal composition (the `compound` chart, `diversification` pots) works better in the wide slots than a square.

## Status

| Site name | Delivered file | Where it appears |
|---|---|---|
| `onboarding` | `onboarding.png` | Home hero |
| `learning` | `learning.png` | `/libro/`, `/app/` feature |
| `learn` | `learn.png` | Blog index and the app-choosing article |
| `practice` | `pratice.png` | `/`, `/app/` hero, 3 articles |
| `concepts` | `money_grows.png` | 3 articles and article promos |
| `diversification` | `diversificar.png` | 4 articles |
| `compound` | `compound.png` | Calculator and 4 articles |
| `risk` | `volatilidad.png` | 3 articles |
| `inflation` | `inflacion.png` | 1 article |
| `emergency` | `emergency.png` | 2 articles |
| `book` | `book.png` | `/`, 2 articles |
| `markets` | `explorar.png` | `/app/`, 1 article |
| `steps` | `steps.png` (the iOS bundle drawing, identical file) | 1 article |
| `complicado` | `complicado.png` | 404 page |
| `ui-portfolio`, `ui-markets`, `ui-learn` | ⏳ Placeholder | phone frames on `/` and `/app/` |

## Scene coverage

All scene slots are taken. `onboarding`, `learn` and `complicado` came from the app's onboarding set rather than from a dedicated website delivery; they fit their slots today, and a purpose-drawn replacement for any of them only needs to keep the same site name.

## The three app screens

`ui-portfolio`, `ui-markets` and `ui-learn` stand in for real screenshots inside the phone frames. They are UI drawings, not doodles: same rounded cards, pale blue chips and tab bar as the app, no invented market data beyond the harmless examples already there.

**Preferred replacement:** a real capture of the app. The captures in `docs/screenshots/` cannot be used yet because every one shows the simulator's "Un momento — No se pudo completar" error dialog. Once the backend is reachable from the simulator, a clean capture at 1206×2622 replaces the drawings with raster images and nothing else has to change.

## Style reference

The app's onboarding doodles: black line art on white, round caps and joins, a friendly character with a solid black hair shape, plants and coins as recurring motifs, and small "movement" ticks near heads. Editorial doodle, not corporate flat illustration: hand-drawn feel, simple geometry, generous white space, no shadows, no 3D, no photorealism. The five delivered drawings set the current tone; keep new work consistent with them.

## Not required from the art team

| Asset | Origin |
|---|---|
| `apps/web/img/logo/mark-ink-128.png`, `mark-white-128.png` | The white "e" glyph extracted from the iOS `AppIcon.png` and recoloured. |
| `apps/web/favicon.ico`, `favicon.svg`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png` | Rendered from the same app icon. |
| `apps/web/img/og/*.svg` and `*.jpg` | 35 Open Graph cards generated per page from the headline plus the brand mark. |
| `apps/web/img/cover-800.jpg` | Downscaled from the book cover. |
| `apps/web/img/twitter.png`, `leanpub.webp`, `amazon-logo.svg` | Carried over from the previous version of the site. |
| `docs/screenshots/*.png` | iOS simulator captures for the repository documentation. |
