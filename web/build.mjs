// Static site generator. buildSite() returns every file that must exist under
// apps/web, keyed by absolute site path, so scripts/check-web.mjs can verify the
// committed output without writing anything.
import { readFileSync } from 'node:fs';
import { articles, articleBySlug, categories } from './articles.mjs';
import { renderDocument } from './layout.mjs';
import { site } from './site.mjs';
import { articlePage, articlesIndexPage } from './pages/articles.mjs';
import { appPage } from './pages/app.mjs';
import { calculatorPage } from './pages/calculator.mjs';
import { homePage } from './pages/home.mjs';
import { libroPage } from './pages/libro.mjs';
import { glossaryPage } from './pages/glossary.mjs';
import { avisoLegalPage, notFoundPage, privacidadPage, sobrePage } from './pages/static.mjs';

const xml = value =>
  String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const bodyPath = slug => new URL(`./articles/${slug}.html`, import.meta.url);

export function loadBodies() {
  for (const article of articles) {
    article.body = readFileSync(bodyPath(article.slug), 'utf8');
  }
  return articles;
}

// --- Open Graph cards ------------------------------------------------------
// Social platforms ignore SVG, so the build emits an SVG source per page and
// scripts/build-web-assets.sh rasterises it into /img/og/<name>.png.
function ogCard({ ogEyebrow, ogTitle, title }) {
  const headline = (ogTitle ?? title).replace(/\s*\|\s*Empezar a invertir$/, '');
  const words = headline.split(/\s+/);
  const lines = [];
  let current = '';
  for (const word of words) {
    if ((current + ' ' + word).trim().length > 30 && current) {
      lines.push(current.trim());
      current = word;
    } else {
      current = `${current} ${word}`.trim();
    }
  }
  if (current) lines.push(current.trim());
  const visible = lines.slice(0, 3);
  const fontSize = headline.length > 78 ? 52 : 62;
  const startY = ogEyebrow ? 300 : 286;
  const step = fontSize + 12;

  const titleLines = visible
    .map((line, index) => `<text x="88" y="${startY + index * step}" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="${fontSize}" font-weight="700" fill="#FFFFFF" letter-spacing="-1.4">${xml(line)}</text>`)
    .join('\n    ');
  const eyebrow = ogEyebrow
    ? `<circle cx="94" cy="196" r="7" fill="#4C8DFF"/>
    <text x="116" y="205" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="26" font-weight="600" fill="#9CC0FF" letter-spacing="3.2">${xml(ogEyebrow.toUpperCase())}</text>`
    : '';

  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#15213B"/>
      <stop offset="1" stop-color="#080D18"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.86" cy="0.16" r="0.7">
      <stop offset="0" stop-color="#165DDE" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#165DDE" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#bg)"/>
  <rect width="1200" height="630" fill="url(#glow)"/>
  <g fill="none" stroke="#4C8DFF" stroke-opacity="0.5" stroke-width="3" stroke-linecap="round">
    <circle cx="1035" cy="392" r="120"/>
    <circle cx="1035" cy="392" r="72"/>
    <path d="M965 500 L1010 452 L1052 476 L1100 418 L1140 392"/>
  </g>
  ${eyebrow}
  ${titleLines}
  <g transform="translate(88 545)">
    <circle cx="8" cy="8" r="8" fill="#4C8DFF"/>
    <text x="30" y="19" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-size="24" font-weight="500" fill="#93A3BE" letter-spacing="0.6">empezar-a-invertir.com</text>
  </g>
</svg>
`;
}

// --- Feeds and indexes -----------------------------------------------------
function sitemap(pages) {
  const entries = pages
    .filter(page => !page.noindex && page.url !== '/404.html')
    .sort((a, b) => Number(b.priority) - Number(a.priority) || a.url.localeCompare(b.url))
    .map(
      page => `  <url>
    <loc>${site.url}${page.url}</loc>
    <lastmod>${page.updated}</lastmod>
    <changefreq>${page.changefreq}</changefreq>
    <priority>${page.priority}</priority>
  </url>`,
    )
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${entries}
</urlset>
`;
}

function feed() {
  const items = [...articles]
    .sort((a, b) => b.published.localeCompare(a.published))
    .map(
      article => `    <item>
      <title>${xml(article.title)}</title>
      <link>${site.url}/articles/${article.slug}.html</link>
      <guid isPermaLink="true">${site.url}/articles/${article.slug}.html</guid>
      <pubDate>${new Date(`${article.published}T08:00:00Z`).toUTCString()}</pubDate>
      <category>${xml(article.category)}</category>
      <description>${xml(article.description)}</description>
    </item>`,
    )
    .join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>${xml(site.name)}</title>
    <link>${site.url}/</link>
    <description>${xml(site.description)}</description>
    <language>${site.lang}</language>
    <atom:link href="${site.url}/feed.xml" rel="self" type="application/rss+xml"/>
${items}
  </channel>
</rss>
`;
}

function robots() {
  return `User-agent: *
Allow: /

Sitemap: ${site.url}/sitemap.xml
`;
}

function manifest() {
  return `${JSON.stringify(
    {
      name: site.name,
      short_name: site.shortName,
      description: site.description,
      start_url: '/',
      display: 'standalone',
      background_color: '#F5F6F8',
      theme_color: '#1757E0',
      lang: site.lang,
      icons: [
        { src: '/img/logo/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/img/logo/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/img/logo/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    },
    null,
    2,
  )}\n`;
}

// --- Entry point -----------------------------------------------------------
export function buildSite() {
  loadBodies();
  const context = { site, articles, articleBySlug, categories };

  const pages = [
    homePage,
    appPage,
    libroPage,
    calculatorPage,
    articlesIndexPage,
    glossaryPage,
    sobrePage,
    privacidadPage,
    avisoLegalPage,
    notFoundPage,
    ...articles.map(article => articlePage(article, { articles })),
  ];

  const files = new Map();
  for (const page of pages) {
    const schema = typeof page.schema === 'function' ? page.schema(context) : page.schema;
    const content = page.body(context);
    files.set(page.path, renderDocument({ ...page, schema }, { content, currentPath: page.path }));
    files.set(`/img/og/${page.ogName}.svg`, ogCard(page));
  }

  files.set('/sitemap.xml', sitemap(pages));
  files.set('/robots.txt', robots());
  files.set('/feed.xml', feed());
  files.set('/site.webmanifest', manifest());

  return { files, pages, articles };
}
