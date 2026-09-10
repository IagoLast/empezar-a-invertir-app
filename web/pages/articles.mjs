// Blog index and article pages, generated from web/articles.mjs.
import { categories } from '../articles.mjs';
import { site } from '../site.mjs';
import {
  articleCard, breadcrumbs, button, esc, faqList, icon, illustration, longDate, sectionHead,
} from '../components.mjs';

const slugify = text =>
  text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

// Adds stable anchors to every <h2> and returns the table of contents.
function withHeadingIds(html) {
  const headings = [];
  const withIds = html.replace(/<h2>([\s\S]*?)<\/h2>/g, (_, inner) => {
    const text = inner.replace(/<[^>]+>/g, '').trim();
    const id = slugify(text);
    headings.push({ id, text });
    return `<h2 id="${id}">${inner}</h2>`;
  });
  return { html: withIds, headings };
}

// Article bodies were written for the previous site structure. Normalise the
// few relative links they contain so every URL is canonical site wide.
const normalizeLinks = html =>
  html
    .replaceAll('class="btn btn--primary"', 'class="button"')
    .replaceAll('href="../index.html"', 'href="/libro/"')
    .replaceAll('href="index.html"', 'href="/articles/"')
    .replace(/href="([a-z0-9-]+)\.html"/g, 'href="/articles/$1.html"');

export const articlesIndexPage = {
  path: '/articles/index.html',
  url: '/articles/',
  title: 'Blog de inversión para principiantes — Empezar a invertir',
  description:
    'Artículos y guías sobre inversión para principiantes: cómo empezar desde cero, qué es un ETF o un fondo indexado, cómo funciona el interés compuesto y qué errores evitar.',
  image: '/img/og/articles.jpg',
  ogName: 'articles',
  ogEyebrow: 'Blog',
  ogTitle: 'Guías de inversión para principiantes',
  updated: site.updated,
  changefreq: 'weekly',
  priority: '0.8',

  schema: ({ articles }) => [
    {
      '@context': 'https://schema.org',
      '@type': 'CollectionPage',
      name: 'Blog de inversión para principiantes',
      url: `${site.url}/articles/`,
      description: 'Artículos y guías sobre inversión para principiantes.',
      inLanguage: 'es',
      isPartOf: { '@type': 'WebSite', name: site.name, url: `${site.url}/` },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      itemListElement: articles.map((article, index) => ({
        '@type': 'ListItem',
        position: index + 1,
        url: `${site.url}/articles/${article.slug}.html`,
        name: article.title,
      })),
    },
  ],

  body: ({ articles }) => `
    <section class="section section--tight">
      <div class="container">
        <div class="section__head">
          <h1>Aprende a invertir, concepto a concepto</h1>
          <p class="lead">${articles.length} guías en español sobre los fundamentos de la inversión. Sin recomendaciones de compra, sin promesas de rentabilidad y sin jerga innecesaria.</p>
        </div>
        <div class="actions">
          ${button({ href: '/articles/como-empezar-a-invertir-desde-cero.html', label: 'Empezar por aquí', iconName: 'arrowRight' })}
          ${button({ href: '/calculadora-interes-compuesto/', label: 'Calcular interés compuesto', variant: 'button--secondary' })}
        </div>
      </div>
    </section>

    ${categories
      .map(category => {
        const items = articles.filter(article => article.category === category.name);
        if (!items.length) return '';
        return `<section class="section section--surface" id="${slugify(category.name)}">
      <div class="container">
        ${sectionHead({ eyebrow: `${items.length} artículos`, title: category.name, text: category.description })}
        <div class="grid grid--3">${items.map(article => articleCard(article)).join('')}</div>
      </div>
    </section>`;
      })
      .join('')}

    <section class="section">
      <div class="container grid grid--split">
        <div class="stack stack--lg">
          ${sectionHead({
            eyebrow: 'La app',
            title: 'Practica lo que acabas de leer',
            text: 'Los artículos explican la teoría. La app te deja aplicarla con una cartera de dinero ficticio y precios reales de mercado.',
          })}
          <div class="actions">${button({ href: '/app/', label: 'Descubrir la app', iconName: 'arrowRight' })}</div>
        </div>
        ${illustration('learn')}
      </div>
    </section>
  `,
};

export function articlePage(article, { articles }) {
  const { html: body, headings } = withHeadingIds(normalizeLinks(article.body));
  const related = article.related
    .map(slug => articles.find(candidate => candidate.slug === slug))
    .filter(Boolean)
    .slice(0, 3);
  const url = `/articles/${article.slug}.html`;

  return {
    path: `/articles/${article.slug}.html`,
    url,
    title: `${article.seoTitle}${` | ${site.name}`.length + article.seoTitle.length <= 65 ? ` | ${site.name}` : ''}`,
    ogTitle: article.title,
    description: article.description,
    image: `/img/og/${article.slug}.jpg`,
    ogName: article.slug,
    ogEyebrow: article.category,
    ogType: 'article',
    updated: article.updated,
    changefreq: 'monthly',
    priority: '0.7',

    schema: [
      {
        '@context': 'https://schema.org',
        '@type': 'Article',
        headline: article.title,
        description: article.description,
        inLanguage: 'es',
        articleSection: article.category,
        datePublished: article.published,
        dateModified: article.updated,
        timeRequired: `PT${article.minutes}M`,
        wordCount: undefined,
        mainEntityOfPage: { '@type': 'WebPage', '@id': `${site.url}${url}` },
        image: `${site.url}/img/og/${article.slug}.jpg`,
        author: { '@type': 'Organization', name: site.name, url: `${site.url}/` },
        publisher: {
          '@type': 'Organization',
          name: site.name,
          logo: { '@type': 'ImageObject', url: `${site.url}/img/logo/icon-512.png` },
        },
      },
      {
        '@context': 'https://schema.org',
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Inicio', item: `${site.url}/` },
          { '@type': 'ListItem', position: 2, name: 'Artículos', item: `${site.url}/articles/` },
          { '@type': 'ListItem', position: 3, name: article.title, item: `${site.url}${url}` },
        ],
      },
      ...(article.faq?.length
        ? [
            {
              '@context': 'https://schema.org',
              '@type': 'FAQPage',
              mainEntity: article.faq.map(item => ({
                '@type': 'Question',
                name: item.question,
                acceptedAnswer: { '@type': 'Answer', text: item.answer },
              })),
            },
          ]
        : []),
    ],

    body: () => `
    <article>
      <header class="article-header">
        <div class="container container--article stack">
          ${breadcrumbs([
            { href: '/', label: 'Inicio' },
            { href: '/articles/', label: 'Artículos' },
            { href: url, label: article.title },
          ])}
          <h1>${esc(article.title)}</h1>
          <p class="lead">${esc(article.description)}</p>
          <div class="article-meta">
            <a class="article-meta__category" href="/articles/#${slugify(article.category)}">${esc(article.category)}</a>
            <span>${icon('clock', { size: 16 })} ${article.minutes} min</span>
            <span>Publicado el ${longDate(article.published)}</span>
            ${article.updated !== article.published ? `<span>Actualizado el ${longDate(article.updated)}</span>` : ''}
          </div>
        </div>
      </header>

      <div class="container container--article stack stack--lg">
        ${
          headings.length
            ? `<nav class="toc-card" aria-label="Contenido del artículo">
          <h2 class="toc-card__title">En este artículo</h2>
          <ul class="toc-list">${headings
            .map(heading => `<li><a href="#${heading.id}">${esc(heading.text)}</a></li>`)
            .join('')}</ul>
        </nav>`
            : ''
        }

        <div class="prose">${body}</div>

        ${
          article.faq?.length
            ? `<section class="article-section">
          <h2>Preguntas frecuentes</h2>
          ${faqList(article.faq)}
        </section>`
            : ''
        }

        <aside class="app-promo">
          ${illustration(article.illustration, { variant: 'illustration--plain', className: 'app-promo__art' })}
          <div class="app-promo__text">
            <h2>Practica lo que acabas de leer</h2>
            <p class="muted">La app reúne los ${site.book.chapters} capítulos y una cartera virtual de ${site.app.startingCash} para probar cada concepto sin arriesgar dinero.</p>
            <a class="text-link" href="/app/">Ver la app →</a>
          </div>
        </aside>

        <section class="inline-book-banner">
          <div class="inline-book-banner__text">
            <p class="inline-book-banner__title">${esc(article.cta.title)}</p>
            <p class="inline-book-banner__desc">${esc(article.cta.body)}</p>
          </div>
          <a class="button" href="/libro/">Ver la guía</a>
        </section>
      </div>

      ${
        related.length
          ? `<section class="section section--tight">
        <div class="container container--article">
          <h2 class="article-section__title">Sigue leyendo</h2>
          <ul class="read-next">
            ${related
              .map(
                item => `<li>
              <a href="/articles/${item.slug}.html">
                <span class="read-next__meta">${esc(item.category)} · ${icon('clock', { size: 13 })} ${item.minutes} min</span>
                <span class="read-next__title">${esc(item.title)}</span>
                <span class="read-next__desc">${esc(item.description)}</span>
              </a>
            </li>`,
              )
              .join('')}
          </ul>
        </div>
      </section>`
          : ''
      }
    </article>
  `,
  };
}
