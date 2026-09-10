// Home page: the hub that introduces both products.
import { site, homeFaq } from '../site.mjs';
import { appBadge } from '../layout.mjs';
import {
  articleCard, button, checkList, esc, faqList, icon, illustration, screen, sectionHead,
} from '../components.mjs';

const topics = [
  { slug: 'diferencia-entre-activos-y-pasivos', iconName: 'wallet', label: 'Activos y pasivos' },
  { slug: 'que-es-la-inflacion-como-afecta-ahorros', iconName: 'chart', label: 'Inflación' },
  { slug: 'que-es-el-interes-compuesto', iconName: 'sparkles', label: 'Interés compuesto' },
  { slug: 'que-es-la-diversificacion', iconName: 'target', label: 'Diversificación' },
  { slug: 'que-es-un-etf', iconName: 'search', label: 'ETFs y fondos' },
  { slug: 'renta-fija-vs-renta-variable', iconName: 'shield', label: 'Renta fija y variable' },
];

export const homePage = {
  path: '/index.html',
  url: '/',
  title: 'Empezar a invertir — Aprende con una guía clara y practica sin riesgo',
  description: site.description,
  image: '/img/og/home.jpg',
  ogName: 'home',
  ogEyebrow: null,
  ogTitle: 'Aprende a invertir sin arriesgar tu dinero',
  updated: site.updated,
  changefreq: 'weekly',
  priority: '1.0',

  schema: [
    {
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      name: site.name,
      url: `${site.url}/`,
      inLanguage: 'es',
      description: site.description,
    },
    {
      '@context': 'https://schema.org',
      '@type': 'Organization',
      name: site.name,
      url: `${site.url}/`,
      logo: `${site.url}/img/logo/icon-512.png`,
      email: site.contact,
    },
  ],

  webgpu: 'aurora',

  body: ({ articles, articleBySlug }) => {
    const recent = [...articles]
      .sort((a, b) => b.updated.localeCompare(a.updated) || b.published.localeCompare(a.published))
      .slice(0, 3);

    return `
    <section class="hero">
      <canvas class="hero__gpu" data-webgpu="aurora" data-intensity="0.45" aria-hidden="true"></canvas>
      <div class="container hero__inner">
        <div class="hero__copy">
          <h1 class="display">Aprende a invertir sin arriesgar tu dinero.</h1>
          <p class="lead">Una guía clara para entender lo esencial y una app para practicarlo con una cartera de dinero ficticio. Sin jerga, sin promesas y sin dar el primer paso a ciegas.</p>
          <div class="actions">
            ${button({ href: '/app/', label: 'Descubrir la app', iconName: 'arrowRight' })}
            ${button({ href: '/libro/', label: 'Ver la guía', variant: 'button--secondary' })}
          </div>
          <div class="hero__proof">
            <span>${icon('book', { size: 18 })} ${site.book.chapters} capítulos completos</span>
            <span>${icon('clock', { size: 18 })} ${Math.floor(site.book.minutes / 60)} h ${site.book.minutes % 60} min</span>
            <span>${icon('wallet', { size: 18 })} Cartera virtual de ${site.app.startingCash}</span>
          </div>
        </div>
        <div class="hero__art">
          ${illustration('onboarding', { variant: 'illustration--plain' })}
        </div>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container">
        ${sectionHead({
          eyebrow: 'Dos formas de aprender',
          title: 'Un libro para entenderlo, una app para practicarlo',
          text: 'Los dos productos cubren lo mismo desde ángulos distintos: el libro te da los cimientos con calma y la app convierte esos conceptos en decisiones simuladas.',
        })}
        <div class="grid grid--2">
          <article class="card">
            ${illustration('book', { variant: 'illustration--plain', className: 'card__art' })}
            <h3>La guía completa</h3>
            <p class="muted">20 capítulos que empiezan en qué es el dinero y terminan comparando acciones, renta fija y fondos. Disponible en PDF, EPUB, MOBI, Kindle y tapa blanda.</p>
            <a class="text-link" href="/libro/">Ver el índice y los formatos →</a>
          </article>
          <article class="card">
            ${illustration('practice', { variant: 'illustration--plain', className: 'card__art' })}
            <h3>La app para practicar</h3>
            <p class="muted">Lee el mismo contenido desde el móvil, busca acciones y ETF reales y gestiona una cartera de ${site.app.startingCash} virtuales para ver cómo se comportan tus decisiones.</p>
            <a class="text-link" href="/app/">Ver qué puedes hacer →</a>
          </article>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container">
        ${sectionHead({
          center: true,
          eyebrow: 'La app',
          title: 'Aprender, explorar y practicar en el mismo sitio',
          text: 'La app no te pide dinero real ni te promete rentabilidades: te deja equivocarte en un entorno simulado y entender por qué.',
        })}
        <div class="grid grid--3">
          <article class="card card--fill">
            <div class="card__icon">${icon('book', { size: 22 })}</div>
            <h3>Aprende paso a paso</h3>
            <p class="muted">Los 20 capítulos de la guía en formato lectura, con progreso guardado, marcadores y explicaciones de cada concepto dentro de la propia interfaz.</p>
          </article>
          <article class="card card--fill">
            <div class="card__icon">${icon('search', { size: 22 })}</div>
            <h3>Explora el mercado</h3>
            <p class="muted">Busca acciones y ETF de todo el mundo, consulta su ficha, su gráfico y los datos clave antes de decidir. Sin análisis técnico ni ruido.</p>
          </article>
          <article class="card card--fill">
            <div class="card__icon">${icon('wallet', { size: 22 })}</div>
            <h3>Practica con dinero ficticio</h3>
            <p class="muted">Empieza con ${site.app.startingCash} virtuales, lanza órdenes simuladas y observa cómo evoluciona tu cartera con precios reales de mercado.</p>
          </article>
        </div>
        <div class="device-row" style="margin-top:48px">
          ${screen('ui-portfolio', 'Pantalla de cartera con el saldo virtual y las posiciones de ejemplo')}
          ${screen('ui-markets', 'Pantalla de mercados con el buscador de acciones y ETF')}
          ${screen('ui-learn', 'Pantalla de aprendizaje con el progreso de lectura y los capítulos')}
        </div>
        <div class="actions actions--center" style="margin-top:40px">
          ${appBadge()}
          ${button({ href: '/app/', label: 'Cómo funciona', variant: 'button--secondary' })}
        </div>
      </div>
    </section>

    <section class="section section--ink">
      <div class="container book-grid">
        <img class="book-cover" src="/img/cover-800.jpg" alt="Portada del libro Guía para empezar a invertir" width="800" height="1277" loading="lazy" decoding="async">
        <div class="stack stack--lg">
          ${sectionHead({
            eyebrow: 'El libro',
            title: 'La guía que empezó todo esto',
            text: 'Empezar a invertir nació como un libro para explicar la inversión sin humo. Hoy sigue siendo la base de todo el contenido de la app.',
          })}
          ${checkList([
            '<strong>20 capítulos</strong> y 127 minutos de lectura, de cero a productos concretos.',
            '<strong>Sin jerga</strong>: cada término se explica la primera vez que aparece.',
            '<strong>Con criterio</strong>: riesgo, costes e interés compuesto antes de mover dinero.',
          ])}
          <div class="actions">
            ${button({ href: site.book.leanpub, label: 'Comprar en Leanpub', attributes: 'target="_blank" rel="noopener"' })}
            ${button({ href: '/libro/', label: 'Ver el índice', variant: 'button--secondary' })}
          </div>
          <p class="disclaimer">Algunos enlaces de compra son de afiliado. El precio no cambia para ti y nos ayuda a mantener el proyecto.</p>
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container">
        ${sectionHead({
          eyebrow: 'Por dónde empezar',
          title: 'Los conceptos que de verdad importan',
          text: 'Si prefieres empezar por el blog, estos son los artículos que cubren la base. Todos se leen en menos de 15 minutos.',
        })}
        <div class="grid grid--3">
          ${topics
            .map(topic => {
              const article = articleBySlug.get(topic.slug);
              return `<a class="card card--flat" href="/articles/${topic.slug}.html">
                <div class="card__icon">${icon(topic.iconName, { size: 22 })}</div>
                <h3>${esc(topic.label)}</h3>
                <p class="muted">${esc(article.description)}</p>
              </a>`;
            })
            .join('')}
        </div>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container">
        ${sectionHead({
          eyebrow: 'Blog',
          title: 'Artículos recientes',
          text: 'Guías prácticas sobre fondos, inflación, riesgo y errores frecuentes. Contenido en español, actualizado y sin recomendaciones de compra.',
        })}
        <div class="grid grid--3">${recent.map(article => articleCard(article)).join('')}</div>
        <div class="actions" style="margin-top:32px">${button({ href: '/articles/', label: `Ver los ${articles.length} artículos`, variant: 'button--secondary', iconName: 'arrowRight' })}</div>
      </div>
    </section>

    <section class="section">
      <div class="container container--narrow">
        ${sectionHead({ center: true, eyebrow: 'Preguntas frecuentes', title: 'Dudas habituales antes de empezar' })}
        ${faqList(homeFaq)}
      </div>
    </section>

    <section class="section section--ink">
      <div class="container container--narrow center">
        <h2>Deja de posponer una decisión importante</h2>
        <p class="lead" style="margin-top:16px">Empieza por entender, sigue practicando y decide después. Sin prisa y sin arriesgar dinero que no puedas permitirte perder.</p>
        <div class="actions actions--center" style="margin-top:28px">
          ${button({ href: '/app/', label: 'Descubrir la app', iconName: 'arrowRight' })}
          ${button({ href: '/libro/', label: 'Conseguir la guía', variant: 'button--secondary' })}
        </div>
      </div>
    </section>
    `;
  },
};
