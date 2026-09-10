# Web

Generated static site for the book, the blog and the app landing page. Serve this directory from any static host at the domain root: all internal URLs are root relative (`/articles/`, `/img/`, `/style.css`).

**Do not edit the HTML here.** Every `.html`, `.xml` and `site.webmanifest` file is produced by `npm run web:build` from the sources in `web/`. Edit those instead, then run `npm run web:build` (and `npm run web:assets` when a new page needs a share image).

`js/` holds the optional WebGPU background: `webgpu.js` is the progressive-enhancement loader and `webgpu-effect.js` is the vgpu shader bundle. Both are produced by `npm run web:gpu` from `web/gpu/` and are loaded only by the pages that opt in.

`img/illustrations/` mixes vector placeholders and the raster drawings delivered by the art team; the generator inlines the former and serves the latter as `<img>`. See [web/art-brief.md](../web/art-brief.md).

The visual system mirrors the iOS app: light `#F5F6F8` canvas, white `24px` cards, `#165DDE` blue accents, system typography and automatic dark mode. Illustrations are hand authored SVG line art inlined into the pages. Spanish copy is user facing; filenames and developer documentation remain in English.

SEO assets include per-page canonical URLs, Open Graph cards (`img/og/*.jpg`), Article, FAQ, Breadcrumb, Book, SoftwareApplication and Organization JSON-LD, `sitemap.xml`, `feed.xml`, `robots.txt` and a web manifest. `npm test` runs `scripts/check-web.mjs`, which verifies that this directory matches the sources and keeps the contract.

Preview locally with `npm run web:serve`.
