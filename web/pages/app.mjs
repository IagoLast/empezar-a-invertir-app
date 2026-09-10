// App landing page: what the app does, how it works and what it is not.
import { appFaq, appFeatures, site } from '../site.mjs';
import { appBadge } from '../layout.mjs';
import {
  button, esc, faqList, icon, illustration, screen, sectionHead,
} from '../components.mjs';

export const appPage = {
  path: '/app/index.html',
  url: '/app/',
  title: 'La app para aprender a invertir practicando con dinero ficticio',
  description:
    'Conoce EAI, la app que combina el contenido del libro con un simulador: lee los 20 capítulos, busca acciones y ETF reales y practica con una cartera de 10.000 USD virtuales.',
  image: '/img/og/app.jpg',
  ogName: 'app',
  ogEyebrow: 'La app',
  ogTitle: 'Aprende a invertir practicando con dinero ficticio',
  updated: site.updated,
  changefreq: 'monthly',
  priority: '0.9',

  schema: [
    {
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      name: 'EAI',
      alternateName: 'Empezar a invertir',
      applicationCategory: 'FinanceApplication',
      operatingSystem: 'iOS 17 o posterior',
      description:
        'App educativa en español para aprender a invertir con los 20 capítulos de la guía y practicar con una cartera de dinero ficticio.',
      inLanguage: 'es',
      url: `${site.url}/app/`,
      publisher: { '@type': 'Organization', name: site.name, url: `${site.url}/` },
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR', description: 'Contenido y cartera virtual de prueba' },
    },
  ],

  webgpu: 'ribbon',

  body: () => `
    <section class="hero">
      <canvas class="hero__gpu" data-webgpu="ribbon" data-intensity="0.5" aria-hidden="true"></canvas>
      <div class="container hero__inner">
        <div class="hero__copy">
          <h1>Aprende invirtiendo, no arriesgando.</h1>
          <p class="lead">EAI reúne el contenido del libro y un simulador de inversión en la misma app: lee, busca activos reales y practica con ${site.app.startingCash} virtuales que no puedes perder.</p>
          <div class="actions">
            ${appBadge()}
            ${button({ href: '/articles/como-empezar-a-invertir-desde-cero.html', label: 'Empezar por la teoría', variant: 'button--secondary' })}
          </div>
          <div class="hero__proof">
            <span>${icon('book', { size: 18 })} ${site.book.chapters} capítulos dentro de la app</span>
            <span>${icon('wallet', { size: 18 })} Sin dinero real</span>
            <span>${icon('lock', { size: 18 })} Inicio de sesión con Apple</span>
          </div>
        </div>
        <div class="hero__art">
          ${illustration('practice', { variant: 'illustration--plain' })}
        </div>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container">
        ${sectionHead({
          center: true,
          eyebrow: 'Qué puedes hacer',
          title: 'Tres cosas, bien hechas',
          text: 'Sin gráficos de velas, sin apalancamiento y sin promesas. Solo lo que necesitas para entender cómo funciona invertir.',
        })}
        ${appFeatures
          .map(
            (feature, index) => `
        <div class="grid grid--split${index % 2 === 1 ? ' split--reverse' : ''}" style="margin-top:${index === 0 ? '0' : '56px'}">
          <div class="stack">
            ${sectionHead({ eyebrow: `0${index + 1}`, title: feature.title, text: feature.text })}
          </div>
          ${illustration(feature.illustration)}
        </div>`,
          )
          .join('')}
      </div>
    </section>

    <section class="section">
      <div class="container">
        ${sectionHead({
          center: true,
          eyebrow: 'Las pantallas',
          title: 'Así está pensada por dentro',
          text: 'Lectura integrada, buscador de activos y cartera simulada, con la misma jerarquía clara de la app y adaptada a la apariencia clara u oscura de tu iPhone.',
        })}
        <div class="device-row">
          ${screen('ui-portfolio', 'Pantalla de cartera con el saldo virtual y las posiciones de ejemplo')}
          ${screen('ui-markets', 'Pantalla de mercados con el buscador de acciones y ETF')}
          ${screen('ui-learn', 'Pantalla de aprendizaje con el progreso de lectura y los capítulos')}
        </div>
      </div>
    </section>

    <section class="section section--ink">
      <div class="container">
        ${sectionHead({
          center: true,
          eyebrow: 'Cómo funciona',
          title: 'De la curiosidad a la primera decisión simulada',
        })}
        <div class="steps">
          <div class="step">
            <span class="step__index">1</span>
            <h3>Lee y entiende</h3>
            <p>Recorre los capítulos a tu ritmo. Cada concepto financiero se explica dentro de la interfaz, sin dar nada por sabido.</p>
          </div>
          <div class="step">
            <span class="step__index">2</span>
            <h3>Explora activos reales</h3>
            <p>Busca acciones y ETF, mira su gráfico y sus datos. Los precios son de mercado; las operaciones, no.</p>
          </div>
          <div class="step">
            <span class="step__index">3</span>
            <h3>Practica sin riesgo</h3>
            <p>Compra y vende con saldo virtual y observa el resultado. Equivocarse aquí es gratis y enseña mucho.</p>
          </div>
        </div>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container container--narrow">
        ${sectionHead({ center: true, eyebrow: 'Preguntas frecuentes', title: 'Todo lo que suelen preguntarnos' })}
        ${faqList(appFaq)}
      </div>
    </section>

    <section class="section section--ink">
      <div class="container container--narrow center">
        <h2>Mientras llega al App Store</h2>
        <p class="lead" style="margin-top:16px">La guía cubre exactamente los mismos fundamentos que la app, con ejemplos y sin tecnicismos. Es la mejor forma de llegar preparado.</p>
        <div class="actions actions--center" style="margin-top:28px">
          ${button({ href: '/libro/', label: 'Conseguir la guía', iconName: 'arrowRight' })}
          ${button({ href: '/articles/', label: 'Leer el blog', variant: 'button--secondary' })}
        </div>
        <p class="disclaimer" style="margin-top:24px">${esc(site.app.requirements)}</p>
      </div>
    </section>
  `,
};
