// Document shell: head metadata, navigation and footer.
import { site } from './site.mjs';
import { appleLogo, esc, icon, jsonLd } from './components.mjs';

const logoLockup = ({ size = 32 } = {}) => `<picture>
      <source srcset="/img/logo/mark-white-128.png" media="(prefers-color-scheme: dark)">
      <img src="/img/logo/mark-ink-128.png" alt="" width="${size}" height="${Math.round((size * 556) / 679)}" decoding="async">
    </picture>`;

export function appBadge({ small = false } = {}) {
  const classes = ['appstore-badge', small ? 'appstore-badge--small' : ''].filter(Boolean).join(' ');
  if (site.app.storeUrl) {
    return `<a class="${classes}" href="${site.app.storeUrl}" target="_blank" rel="noopener">${appleLogo({ size: small ? 20 : 26 })}<span><small>Descárgala en</small>App Store</span></a>`;
  }
  return `<span class="${classes}">${appleLogo({ size: small ? 20 : 26 })}<span><small>Muy pronto en</small>App Store</span></span>`;
}

function nav(currentPath) {
  const links = site.nav
    .map(
      item =>
        `<a href="${item.path}"${currentPath.startsWith(item.path) ? ' aria-current="page"' : ''}>${item.label}</a>`,
    )
    .join('');
  return `<a class="skip-link" href="#contenido">Saltar al contenido</a>
  <header class="nav">
    <div class="container nav__inner">
      <a class="nav__brand" href="/">
        ${logoLockup()}
        <span class="nav__brand-text">Empezar a invertir<small>Guía + app de inversión</small></span>
      </a>
      <nav class="nav__links" aria-label="Navegación principal">${links}</nav>
      <a class="button button--small nav__cta" href="/app/">Probar la app</a>
      <details class="nav__menu">
        <summary>Menú ${icon('chevronDown', { size: 16 })}</summary>
        <div class="nav__menu-panel">
          ${site.nav.map(item => `<a href="${item.path}">${item.label}</a>`).join('')}
          <a href="/sobre/">Sobre el proyecto</a>
        </div>
      </details>
    </div>
  </header>`;
}

function footer() {
  const columns = [
    {
      title: 'Producto',
      links: [
        { href: '/app/', label: 'La app' },
        { href: '/libro/', label: 'El libro' },
        { href: '/calculadora-interes-compuesto/', label: 'Calculadora de interés compuesto' },
      ],
    },
    {
      title: 'Aprender',
      links: [
        { href: '/articles/', label: 'Todos los artículos' },
        { href: '/glosario/', label: 'Glosario de inversión' },
        { href: '/articles/como-empezar-a-invertir-desde-cero.html', label: 'Empezar desde cero' },
        { href: '/articles/que-es-un-etf.html', label: 'Qué es un ETF' },
        { href: '/articles/que-es-el-interes-compuesto.html', label: 'Interés compuesto' },
        { href: '/articles/que-es-la-diversificacion.html', label: 'Diversificación' },
      ],
    },
    {
      title: 'Proyecto',
      links: [
        { href: '/sobre/', label: 'Sobre el proyecto' },
        { href: `mailto:${site.contact}`, label: 'Contacto' },
        { href: '/privacidad/', label: 'Privacidad' },
        { href: '/aviso-legal/', label: 'Aviso legal' },
        { href: '/feed.xml', label: 'RSS' },
      ],
    },
  ];

  return `<footer class="footer">
    <div class="container">
      <div class="footer__grid">
        <div>
          <div class="footer__brand">${logoLockup({ size: 34 })}<span>Empezar a invertir</span></div>
          <p class="muted" style="margin-top:16px;max-width:34ch">${esc(site.tagline)}. Material educativo en español, sin promesas de rentabilidad.</p>
        </div>
        ${columns
          .map(
            column => `<div>
          <h3>${column.title}</h3>
          <ul>${column.links.map(link => `<li><a href="${link.href}">${link.label}</a></li>`).join('')}</ul>
        </div>`,
          )
          .join('')}
      </div>
      <div class="footer__note">
        <span>© ${site.updated.slice(0, 4)} Empezar a invertir</span>
        <span>Hecho en España · Contenido educativo, no asesoramiento financiero</span>
      </div>
    </div>
  </footer>`;
}

function gtm() {
  if (!site.gtm) return '';
  return `<script>(function (w, d, s, l, i) {
      w[l] = w[l] || []; w[l].push({ 'gtm.start': new Date().getTime(), event: 'gtm.js' });
      var f = d.getElementsByTagName(s)[0], j = d.createElement(s), dl = l != 'dataLayer' ? '&l=' + l : '';
      j.async = true; j.src = 'https://www.googletagmanager.com/gtm.js?id=' + i + dl;
      f.parentNode.insertBefore(j, f);
    })(window, document, 'script', 'dataLayer', '${site.gtm}');</script>`;
}

function gtmNoScript() {
  if (!site.gtm) return '';
  return `<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=${site.gtm}" height="0" width="0" style="display:none;visibility:hidden" title="Google Tag Manager"></iframe></noscript>`;
}

export function renderDocument(page, { content, currentPath }) {
  const canonical = `${site.url}${page.url}`;
  const image = page.image ? `${site.url}${page.image}` : `${site.url}/img/og/site.jpg`;
  const robots = page.noindex ? 'noindex, follow' : 'index, follow, max-image-preview:large';
  const schemas = [page.schema ?? []].flat().filter(Boolean);
  const smartBanner = site.app.storeUrl
    ? `<meta name="apple-itunes-app" content="app-id=${site.app.storeUrl.split('id').pop()}">`
    : '';

  return `<!DOCTYPE html>
<html lang="${site.lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(page.title)}</title>
  <meta name="description" content="${esc(page.description)}">
  <meta name="robots" content="${robots}">
  <meta name="author" content="${site.name}">
  <meta name="theme-color" content="${site.themeColor}" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="${site.themeColorDark}" media="(prefers-color-scheme: dark)">
  <link rel="canonical" href="${canonical}">
  ${smartBanner}

  <meta property="og:type" content="${page.ogType ?? 'website'}">
  <meta property="og:site_name" content="${site.name}">
  <meta property="og:locale" content="${site.locale}">
  <meta property="og:url" content="${canonical}">
  <meta property="og:title" content="${esc(page.ogTitle ?? page.title)}">
  <meta property="og:description" content="${esc(page.description)}">
  <meta property="og:image" content="${image}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="${esc(page.ogTitle ?? page.title)}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${esc(page.ogTitle ?? page.title)}">
  <meta name="twitter:description" content="${esc(page.description)}">
  <meta name="twitter:image" content="${image}">

  <link rel="icon" href="/favicon.ico" sizes="32x32">
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/img/logo/apple-touch-icon.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="alternate" type="application/rss+xml" title="${site.name}" href="/feed.xml">
  <link rel="stylesheet" href="/style.css">
  ${schemas.map(jsonLd).join('\n  ')}
  ${gtm()}
</head>
<body>
  ${gtmNoScript()}
  ${nav(currentPath)}
  <main id="contenido">
${content}
  </main>
  ${footer()}
  ${page.webgpu ? '<script type="module" src="/js/webgpu.js"></script>' : ''}
</body>
</html>
`;
}

export { logoLockup };
