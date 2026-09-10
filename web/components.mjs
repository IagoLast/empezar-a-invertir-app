// Small, dependency free HTML helpers shared by every page.
import { existsSync, readFileSync } from 'node:fs';

export const esc = value =>
  String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const iconPaths = {
  check: 'M20 6 9 17l-5-5',
  arrowRight: 'M5 12h14M13 6l6 6-6 6',
  arrowUpRight: 'M7 17 17 7M8 7h9v9',
  chevronDown: 'm6 9 6 6 6-6',
  book: 'M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z',
  chart: 'M3 3v18h18M7 15l4-4 3 3 5-6',
  search: 'M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM21 21l-4.35-4.35',
  phone: 'M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zM11 18h2',
  shield: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
  sparkles: 'M12 3v4M12 17v4M3 12h4M17 12h4M6.5 6.5 9 9M15 15l2.5 2.5M17.5 6.5 15 9M9 15l-2.5 2.5',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
  mail: 'M3 5h18v14H3zM3 6l9 7 9-7',
  target: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2z',
  wallet: 'M3 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM16 12h2',
  clock: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
  users: 'M17 20v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9.5 10a4 4 0 1 0 0-8 4 4 0 0 0 0 8M22 20v-2a4 4 0 0 0-3-3.87M16 2.13a4 4 0 0 1 0 7.75',
};

export function icon(name, { size = 24, className = '' } = {}) {
  const path = iconPaths[name];
  if (!path) throw new Error(`Unknown icon: ${name}`);
  return `<svg class="${className}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="${path}"/></svg>`;
}

export function appleLogo({ size = 22 } = {}) {
  return `<svg width="${size}" height="${size}" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true" focusable="false"><path d="M11.182.008C11.148-.03 9.923.023 8.857 1.18c-1.066 1.156-.902 2.482-.878 2.516.024.034 1.52.087 2.475-1.258.955-1.345.762-2.391.728-2.43Zm3.314 11.733c-.048-.096-2.325-1.234-2.113-3.422.212-2.189 1.675-2.789 1.698-2.854.023-.065-.597-.79-1.254-1.157a3.692 3.692 0 0 0-1.563-.434c-.108-.003-.483-.095-1.254.116-.508.139-1.653.589-1.968.607-.316.018-1.256-.522-2.267-.665-.647-.125-1.333.131-1.824.328-.49.196-1.422.754-2.074 2.237-.652 1.482-.311 3.83-.067 4.56.244.729.625 1.924 1.273 2.796.576.984 1.34 1.667 1.659 1.899.319.232 1.219.386 1.843.067.502-.308 1.408-.485 1.766-.472.357.013 1.061.154 1.782.539.571.197 1.111.115 1.652-.105.541-.221 1.324-1.059 2.238-2.758.347-.79.505-1.217.473-1.282Z"/></svg>`;
}

let illustrationCount = 0;

const artworkDir = new URL('../apps/web/img/illustrations/', import.meta.url);

// Art arrives in two flavours: the vector placeholders still in the repository
// and the raster drawings delivered by the art team, which win when both exist.
function artwork(name) {
  for (const extension of ['.png', '.webp', '.svg']) {
    const file = new URL(`${name}${extension}`, artworkDir);
    if (existsSync(file)) return { extension, file };
  }
  throw new Error(`Missing illustration "${name}" in apps/web/img/illustrations`);
}

// Size of a PNG, read from the IHDR chunk: raster art gets explicit dimensions
// so the page never shifts while the image loads.
function pngSize(file) {
  const header = readFileSync(file).subarray(0, 24);
  return [header.readUInt32BE(16), header.readUInt32BE(20)];
}

const artworkAlt = {
  learning: 'Una persona estudia inversión con un portátil, apuntes y una gráfica ascendente',
  practice: 'Una persona practica con una cartera virtual en el móvil, rodeada de monedas',
  concepts: 'Una planta crece sobre una pila de monedas',
  diversification: 'Tres macetas con plantas distintas sobre una línea de suelo',
  compound: 'Una curva creciente con monedas cada vez más grandes',
  app: 'Un móvil con la app, rodeado de elementos de aprendizaje y práctica',
  book: 'Un libro abierto del que brota una planta',
  emergency: 'Un paraguas protege una hucha con forma de cerdito',
  inflation: 'Una cesta de la compra con una etiqueta de precio que sube',
  markets: 'Una lupa examina un gráfico de velas',
  risk: 'Una persona mantiene el equilibrio sobre una gráfica con altibajos',
  steps: 'Una escalera ascendente con una bandera en la cima y una persona subiendo',
};

// Inlines an SVG from the artwork with unique ids, so the same drawing can
// appear several times on a page without duplicate identifiers.
export function inlineSvg(name) {
  const suffix = illustrationCount++;
  return readFileSync(artwork(name).file, 'utf8')
    .replace(/^<\?xml[^>]*\?>\s*/, '')
    .replace(/\sid="([^"]+)"/g, ` id="$1-${suffix}"`)
    .replace(/aria-labelledby="([^"]+)"/g, `aria-labelledby="$1-${suffix}"`)
    .trim();
}

function artworkMarkup(name) {
  const { extension, file } = artwork(name);
  if (extension === '.svg') return inlineSvg(name);

  const [width, height] = pngSize(file);
  return `<img src="/img/illustrations/${name}${extension}" alt="${esc(artworkAlt[name] ?? '')}" width="${width}" height="${height}" loading="lazy" decoding="async">`;
}

export function illustration(name, { caption, variant = '', className = '' } = {}) {
  const classes = ['illustration', variant, className].filter(Boolean).join(' ');
  const figcaption = caption ? `<figcaption>${caption}</figcaption>` : '';
  return `<figure class="${classes}">${artworkMarkup(name)}${figcaption}</figure>`;
}

export function screen(name, alt) {
  return `<div class="device device--small" role="img" aria-label="${esc(alt)}">${inlineSvg(name)}</div>`;
}

export function button({ href, label, variant = '', iconName, block = false, attributes = '' }) {
  const classes = ['button', variant, block ? 'button--block' : ''].filter(Boolean).join(' ');
  const glyph = iconName ? icon(iconName, { size: 18, className: 'button__arrow' }) : '';
  return `<a class="${classes}" href="${href}"${attributes ? ` ${attributes}` : ''}><span>${label}</span>${glyph}</a>`;
}

export function checkList(items) {
  return `<ul class="checklist">${items
    .map(item => `<li>${icon('check', { size: 20 })}<span>${item}</span></li>`)
    .join('')}</ul>`;
}

export function callout(eyebrow, text) {
  const label = eyebrow ? `<span class="eyebrow">${eyebrow}</span>` : '';
  return `<aside class="callout">${label}<p>${text}</p></aside>`;
}

export function faqList(items) {
  return `<div class="accordion">${items
    .map(
      item => `<details>
        <summary>${item.question}</summary>
        <div class="accordion__content"><p>${item.answer}</p></div>
      </details>`,
    )
    .join('')}</div>`;
}

export function sectionHead({ eyebrow, title, text, center = false, id }) {
  const headingId = id ? ` id="${id}"` : '';
  return `<div class="section__head${center ? ' section__head--center' : ''}">
    ${eyebrow ? `<span class="eyebrow">${eyebrow}</span>` : ''}
    <h2${headingId}>${title}</h2>
    ${text ? `<p class="lead">${text}</p>` : ''}
  </div>`;
}

export function device(src, alt, { small = false, width, height } = {}) {
  const size = width && height ? ` width="${width}" height="${height}"` : '';
  return `<div class="device${small ? ' device--small' : ''}"><img src="${src}" alt="${alt}" loading="lazy" decoding="async"${size}></div>`;
}

export function articleCard(article, { headingLevel = 3 } = {}) {
  return `<a class="article-card" href="/articles/${article.slug}.html">
    <span class="article-card__category">${esc(article.category)}</span>
    <h${headingLevel} class="article-card__title">${esc(article.title)}</h${headingLevel}>
    <p class="article-card__desc">${esc(article.description)}</p>
    <span class="article-card__meta">${icon('clock', { size: 15 })} ${article.minutes} min</span>
  </a>`;
}

export function breadcrumbs(items) {
  const list = items
    .map((item, index) =>
      index === items.length - 1
        ? `<li aria-current="page">${esc(item.label)}</li>`
        : `<li><a href="${item.href}">${esc(item.label)}</a></li>`,
    )
    .join('');
  return `<nav class="breadcrumbs" aria-label="Migas de pan"><ol>${list}</ol></nav>`;
}

export function jsonLd(payload) {
  return `<script type="application/ld+json">${JSON.stringify(payload, null, 2)}</script>`;
}

// Formats an ISO date as Spanish copy, e.g. "10 de septiembre de 2026".
const months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

export function longDate(iso) {
  const [year, month, day] = iso.split('-').map(Number);
  return `${day} de ${months[month - 1]} de ${year}`;
}
