# Web sources

Authoring sources for [empezar-a-invertir.com](https://www.empezar-a-invertir.com). The published site lives in `apps/web` and is generated from here, so nothing in this directory is served.

## Layout

| Path | Purpose |
|---|---|
| `site.mjs` | Site configuration, navigation, product links and reusable copy (features, FAQs, book index). |
| `articles.mjs` | Metadata for every article: slug, titles, description, category, dates, illustration, CTA, related links and optional FAQ. |
| `articles/<slug>.html` | Article body as a plain HTML fragment. No `<head>`, no navigation: the generator adds them. |
| `components.mjs` | HTML helpers (icons, buttons, cards, callouts, FAQ accordions, illustration inlining). |
| `layout.mjs` | Document shell: head metadata, Open Graph tags, navigation and footer. |
| `pages/*.mjs` | One module per page (home, app, book, blog index, glossary, calculator, static and legal pages). |
| `gpu/` | Shader sources for the optional WebGPU background, written with [vgpu](https://vgpu.sh). |
| `art/` | Drawings delivered by the art team, as received. Converted into `apps/web/img/illustrations` by `npm run web:art`. |
| `art-brief.md` | What every illustration represents, where it is used and what a delivery must look like. |
| `build.mjs` | `buildSite()` returns every generated file as `Map<path, contents>`; used by both the builder and the checker. |

## Commands

```bash
npm run web:build     # regenerate apps/web (committed output)
npm run web:assets    # regenerate icons, Open Graph cards and the book cover
npm run web:art       # convert the drawings in web/art into transparent assets
npm run web:serve     # preview apps/web at http://localhost:4173
npm test              # runs scripts/check-web.mjs with the rest of the checks
```

`web:assets` needs ImageMagick (`magick`) and `rsvg-convert`; the generated files are committed, so CI only needs Node.

Changing the shaders needs the toolchain in `web/gpu`, which is installed on demand and kept out of the root install so CI never downloads Dawn:

```bash
npm --prefix web/gpu install   # vgpu + esbuild, once
npm run web:gpu                # writes apps/web/js/webgpu.js and webgpu-effect.js
```

## WebGPU background

The home and app heroes render a small WGSL effect with vgpu behind their copy. It is strictly additive:

- Pages opt in with `webgpu: 'aurora' | 'ribbon'` and a `<canvas class="hero__gpu" data-webgpu="...">`. The layout adds `/js/webgpu.js` only to those pages.
- `web/gpu/loader.js` (about 2.4 KB, 1.4 KB gzipped) is the only GPU script every visitor downloads. It bails out when `navigator.gpu` is missing, when the visitor prefers reduced motion, or when the connection reports `saveData`.
- The effect bundle is imported only after the canvas approaches the viewport, the `load` event has fired and the browser is idle, so it never competes with the critical path. It is about 44 KB gzipped, self hosted and self contained.
- The effect renders premultiplied alpha into a transparent canvas, caps the frame rate at 30 fps, clamps the device pixel ratio to 1.5 and pauses when the tab is hidden or the canvas leaves the viewport. `prefers-reduced-motion` and `prefers-color-scheme` changes are honoured without a reload.
- If anything fails, the canvas never fades in and the static design stays exactly as it is.

`scripts/check-web.mjs` enforces the contract: both files must exist, the bundle must carry the hash of the current `web/gpu/effect.js`, it must stay inside the size budget and it must load nothing from the network.

## How it fits together

1. `scripts/build-web.mjs` calls `buildSite()` and writes each file into `apps/web`. It also deletes generated pages that no longer exist in the sources.
2. Every page gets a generated Open Graph card: the build writes `apps/web/img/og/<name>.svg` from the page headline, and `web:assets` rasterises it to `<name>.jpg` with the brand mark stamped on top.
3. `scripts/check-web.mjs` rebuilds the site in memory and fails if the committed HTML differs, if an internal link is broken, if a page is missing metadata, if JSON-LD does not parse, or if a share image has not been generated.

## Conventions

- Spanish for everything a user reads; English for code, filenames and comments.
- Articles are plain HTML fragments so they can be written without touching the generator. Add the metadata entry in `articles.mjs` and the body file in `articles/`, then run `npm run web:build && npm run web:assets`.
- Illustrations live in `apps/web/img/illustrations` in two flavours: the remaining vector placeholders, which use `currentColor` and `var(--accent)` and are inlined by the generator, and the raster drawings delivered by the art team, which are served as `<img>` with explicit dimensions with transparent, borderless containers and inverted in dark mode by CSS. `illustration("name")` picks whichever exists, preferring raster, so replacing a placeholder is only a matter of dropping the file in `web/art/` and running `npm run web:art`.
- The app store badge switches from "muy pronto" to a download link as soon as `site.app.storeUrl` is set in `site.mjs`.

## Pending

- `docs/screenshots` still shows the iOS simulator error dialog in every capture, so the marketing pages use the illustrated app screens (`ui-portfolio`, `ui-markets`, `ui-learn`) instead. Replace them with real captures once the backend is reachable from the simulator.
