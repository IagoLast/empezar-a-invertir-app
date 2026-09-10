// Book landing page: index, formats and who it is for.
import { bookChapters, bookFaq, site } from '../site.mjs';
import { button, checkList, esc, faqList, icon, illustration, sectionHead } from '../components.mjs';

export const libroPage = {
  path: '/libro/index.html',
  url: '/libro/',
  title: 'Guía para empezar a invertir — El libro completo, sin tecnicismos',
  description:
    'La guía que explica la inversión desde cero: 20 capítulos sobre dinero, riesgo, interés compuesto, fondos y acciones. Disponible en PDF, EPUB, MOBI, Kindle y tapa blanda.',
  image: '/img/og/libro.jpg',
  ogName: 'libro',
  ogEyebrow: 'El libro',
  ogTitle: 'La guía completa para empezar a invertir',
  updated: site.updated,
  ogType: 'book',
  changefreq: 'monthly',
  priority: '0.9',

  schema: [
    {
      '@context': 'https://schema.org',
      '@type': 'Book',
      name: site.book.title,
      url: `${site.url}/libro/`,
      image: `${site.url}/img/cover-800.jpg`,
      description:
        'Guía en español para empezar a invertir desde cero: conceptos fundamentales, riesgo, costes, interés compuesto y comparativa de productos de inversión.',
      inLanguage: 'es',
      bookFormat: 'https://schema.org/EBook',
      numberOfPages: undefined,
      genre: ['Finanzas', 'Inversiones', 'Educación financiera'],
      audience: { '@type': 'Audience', audienceType: 'Principiantes en inversión' },
      author: { '@type': 'Organization', name: site.name },
      publisher: { '@type': 'Organization', name: site.name },
      offers: [
        {
          '@type': 'Offer',
          price: '5.00',
          priceCurrency: 'USD',
          availability: 'https://schema.org/InStock',
          url: site.book.leanpub,
        },
        { '@type': 'Offer', availability: 'https://schema.org/InStock', url: site.book.amazon },
      ],
    },
  ],

  body: () => `
    <section class="hero">
      <div class="container hero__inner">
        <div class="hero__copy">
          <h1>Todo lo que necesitas entender antes de invertir.</h1>
          <p class="lead">Un recorrido ordenado por el dinero, el riesgo, el interés compuesto y los productos de inversión. Escrito para quien empieza de cero y no quiere que le vendan humo.</p>
          <div class="actions">
            ${button({ href: site.book.leanpub, label: 'Comprar en Leanpub', iconName: 'arrowUpRight', attributes: 'target="_blank" rel="noopener"' })}
            ${button({ href: site.book.amazon, label: 'Comprar en Amazon', variant: 'button--secondary', attributes: 'target="_blank" rel="noopener"' })}
          </div>
          <div class="hero__proof">
            <span>${icon('book', { size: 18 })} ${site.book.chapters} capítulos</span>
            <span>${icon('clock', { size: 18 })} ${site.book.minutes} min</span>
            <span>${icon('sparkles', { size: 18 })} PDF, EPUB, MOBI, Kindle y papel</span>
          </div>
          <p class="disclaimer">Enlaces de afiliado: si compras desde aquí, el precio es el mismo para ti y una pequeña parte ayuda a mantener el proyecto.</p>
        </div>
        <div class="hero__art">
          <img class="book-cover" src="/img/cover-800.jpg" alt="Portada del libro Guía para empezar a invertir" width="800" height="1277" decoding="async">
        </div>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container">
        ${sectionHead({
          eyebrow: 'Índice',
          title: 'Un recorrido claro, en el orden correcto',
          text: 'Primero entiendes el contexto, después el vocabulario y finalmente los productos donde puedes invertir. Cada capítulo se lee en menos de 15 minutos.',
        })}
        <div class="accordion index">
          ${bookChapters
            .map((section, index) => {
              const start = bookChapters
                .slice(0, index)
                .reduce((total, previous) => total + previous.chapters.length, 0);
              const minutes = section.chapters.reduce((total, chapter) => total + chapter.minutes, 0);
              const count = section.chapters.length;
              return `<details${index === 0 ? ' open' : ''}>
            <summary>
              <span class="index__section">${esc(section.section)}</span>
              <span class="index__meta">${count} ${count === 1 ? 'capítulo' : 'capítulos'} · ${minutes} min</span>
            </summary>
            <div class="accordion__content">
              <ol class="chapter-list">
                ${section.chapters
                  .map(
                    (chapter, position) => `<li>
                  <span class="chapter-list__index">${String(start + position + 1).padStart(2, '0')}</span>
                  <span class="chapter-list__title">${esc(chapter.title)}</span>
                  <span class="chapter-list__minutes">${chapter.minutes} min</span>
                </li>`,
                  )
                  .join('')}
              </ol>
            </div>
          </details>`;
            })
            .join('')}
        </div>
      </div>
    </section>

    <section class="section">
      <div class="container grid grid--split">
        <div class="stack stack--lg">
          ${sectionHead({
            eyebrow: 'Enfoque',
            title: 'Criterio, no atajos',
            text: 'El objetivo no es que sepas elegir el producto de moda, sino que entiendas qué estás haciendo y por qué.',
          })}
          ${checkList([
            '<strong>Empieza desde cero</strong>: no necesitas saber qué es un bono ni haber visto un gráfico.',
            '<strong>Sin promesas de rentabilidad</strong>: explicamos el riesgo y los costes antes que las ganancias.',
            '<strong>Aterriza en lo práctico</strong>: termina comparando acciones, renta fija y fondos de inversión.',
            '<strong>Con la app como complemento</strong>: puedes practicar cada concepto en el simulador.',
          ])}
          <div class="actions">${button({ href: '/app/', label: 'Ver la app', variant: 'button--secondary' })}</div>
        </div>
        ${illustration('learning')}
      </div>
    </section>

    <section class="section section--ink">
      <div class="container">
        ${sectionHead({
          center: true,
          eyebrow: 'Formatos',
          title: 'Compra donde te resulte más cómodo',
          text: 'El contenido es el mismo. Elige el formato que mejor encaje con cómo lees.',
        })}
        <div class="grid grid--2" style="max-width:820px;margin-inline:auto">
          <div class="card card--ink">
            <div class="card__icon">${icon('book', { size: 22 })}</div>
            <h3>Leanpub · PDF, EPUB y MOBI</h3>
            <p>Descarga inmediata y lectura en cualquier dispositivo. Recibe también las actualizaciones del libro.</p>
            ${button({ href: site.book.leanpub, label: 'Comprar en Leanpub', attributes: 'target="_blank" rel="noopener"' })}
          </div>
          <div class="card card--ink">
            <div class="card__icon">${icon('wallet', { size: 22 })}</div>
            <h3>Amazon · Kindle y tapa blanda</h3>
            <p>Si prefieres el ecosistema Kindle o quieres el libro en papel para tenerlo a mano y subrayarlo.</p>
            ${button({ href: site.book.amazon, label: 'Comprar en Amazon', variant: 'button--secondary', attributes: 'target="_blank" rel="noopener"' })}
          </div>
        </div>
        <p class="disclaimer center" style="margin-top:32px">Versión actualizada en septiembre de 2026. Las plataformas y productos mencionados cambian con el tiempo: contrasta siempre la información antes de invertir.</p>
      </div>
    </section>

    <section class="section">
      <div class="container container--narrow">
        ${sectionHead({ center: true, eyebrow: 'Preguntas frecuentes', title: 'Antes de comprar' })}
        ${faqList(bookFaq)}
      </div>
    </section>

    <section class="section section--surface">
      <div class="container container--narrow center">
        <h2>Sigue aprendiendo gratis</h2>
        <p class="lead" style="margin-top:16px">Si todavía no quieres comprar nada, en el blog tienes guías completas sobre los mismos conceptos y una calculadora de interés compuesto para hacer tus propias cuentas.</p>
        <div class="actions actions--center" style="margin-top:28px">
          ${button({ href: '/articles/', label: 'Leer los artículos', iconName: 'arrowRight' })}
          ${button({ href: '/calculadora-interes-compuesto/', label: 'Abrir la calculadora', variant: 'button--secondary' })}
        </div>
      </div>
    </section>
  `,
};
