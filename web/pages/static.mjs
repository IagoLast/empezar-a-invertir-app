// Static pages: about, privacy, legal notice and the 404 page.
import { site } from '../site.mjs';
import { breadcrumbs, button, esc, icon, illustration, sectionHead } from '../components.mjs';

const page = ({ path, url, title, description, ogName, ogEyebrow, ogTitle, noindex, body, schema, priority = '0.4', changefreq = 'yearly' }) => ({
  path,
  url,
  title,
  description,
  image: `/img/og/${ogName}.jpg`,
  ogName,
  ogEyebrow,
  ogTitle,
  noindex,
  body,
  schema,
  updated: site.updated,
  priority,
  changefreq,
});

export const sobrePage = page({
  path: '/sobre/index.html',
  url: '/sobre/',
  title: 'Sobre el proyecto — Empezar a invertir',
  description:
    'Quién está detrás de Empezar a invertir, cómo elaboramos el contenido, qué fuentes usamos y cómo puedes contactar con nosotros.',
  ogName: 'sobre',
  ogEyebrow: 'Proyecto',
  ogTitle: 'Sobre Empezar a invertir',
  schema: [
    {
      '@context': 'https://schema.org',
      '@type': 'AboutPage',
      name: 'Sobre el proyecto',
      url: `${site.url}/sobre/`,
      inLanguage: 'es',
      publisher: { '@type': 'Organization', name: site.name, url: `${site.url}/` },
    },
  ],
  body: () => `
    <section class="section section--tight">
      <div class="container container--narrow stack stack--lg">
        ${breadcrumbs([{ href: '/', label: 'Inicio' }, { href: '/sobre/', label: 'Sobre el proyecto' }])}
        <h1>Un proyecto para explicar la inversión sin ruido</h1>
        <div class="prose">
          <p>Empezar a invertir nació como un libro escrito para resolver una frustración concreta: la mayoría del contenido sobre inversión está pensado para quien ya sabe, o directamente para vender algo. Faltaba una explicación ordenada, honesta y en español para quien empieza de cero.</p>

          <h2>Cómo se elabora el contenido</h2>
          <ul>
            <li><strong>Primero los conceptos, después los productos.</strong> Ningún artículo o capítulo asume conocimientos previos.</li>
            <li><strong>Sin promesas de rentabilidad.</strong> Explicamos el riesgo, los costes y la incertidumbre antes que las ganancias.</li>
            <li><strong>Revisión periódica.</strong> Los artículos indican su fecha de actualización y se revisan cuando cambian la fiscalidad o las plataformas relevantes.</li>
            <li><strong>Ejemplos con números sencillos.</strong> Preferimos una cuenta a mano que un gráfico espectacular.</li>
          </ul>

          <h2>Qué no somos</h2>
          <p>No somos un bróker, no gestionamos dinero de terceros y no damos asesoramiento financiero personalizado. No publicamos recomendaciones de compra ni vendemos señales. Todo el material es educativo.</p>

          <h2>La app</h2>
          <p>La app EAI traslada el mismo contenido al móvil y añade un simulador: puedes leer los capítulos, buscar acciones y ETF reales y practicar con una cartera de ${site.app.startingCash} de dinero ficticio. El saldo virtual no es dinero real y no se puede retirar ni canjear.</p>

          <h2>Independencia y afiliación</h2>
          <p>Algunos enlaces a la tienda del libro son de afiliado: si compras desde ellos, el precio es el mismo para ti y recibimos una pequeña comisión que ayuda a mantener el proyecto. Ninguna marca condiciona el contenido editorial.</p>

          <h2>Esta web</h2>
          <p>El sitio es estático: HTML, CSS y un poco de JavaScript, sin frameworks ni rastreadores más allá de la analítica agregada. La portada y la página de la app incluyen un fondo animado renderizado con WebGPU (con la librería <a href="https://vgpu.sh" rel="noopener">vgpu</a>) que se carga después de que la página termine de cargar, solo si tu navegador lo soporta y no has pedido reducir el movimiento. No envía nada a ningún servidor: se calcula en tu dispositivo.</p>

          <h2>Contacto</h2>
          <p>¿Has encontrado un error, quieres proponer un tema o detectar una errata? Escríbenos a <a href="mailto:${site.contact}">${site.contact}</a> y lo revisamos.</p>
        </div>
        <div class="actions">
          ${button({ href: '/articles/', label: 'Leer los artículos', iconName: 'arrowRight' })}
          ${button({ href: '/app/', label: 'Ver la app', variant: 'button--secondary' })}
        </div>
      </div>
    </section>
  `,
});

export const privacidadPage = page({
  path: '/privacidad/index.html',
  url: '/privacidad/',
  title: 'Política de privacidad — Empezar a invertir',
  description:
    'Qué datos recoge la web y la app Empezar a invertir, con qué finalidad, cuánto tiempo se conservan y cómo ejercer tus derechos según el RGPD.',
  ogName: 'privacidad',
  ogEyebrow: 'Legal',
  ogTitle: 'Política de privacidad',
  body: () => `
    <section class="section section--tight">
      <div class="container container--narrow stack stack--lg">
        ${breadcrumbs([{ href: '/', label: 'Inicio' }, { href: '/privacidad/', label: 'Privacidad' }])}
        <h1>Política de privacidad</h1>
        <p class="muted">Última actualización: ${site.updated}.</p>
        <div class="prose">
          <p>Esta política explica qué datos personales tratamos cuando visitas <strong>empezar-a-invertir.com</strong> o usas la app <strong>EAI</strong>, con qué finalidad y qué derechos tienes. Responsable del tratamiento: el equipo editorial de Empezar a invertir, contactable en <a href="mailto:${site.contact}">${site.contact}</a>.</p>

          <h2>Datos que tratamos en la web</h2>
          <ul>
            <li><strong>Datos de navegación anónimos.</strong> Usamos Google Tag Manager y Google Analytics para medir visitas y páginas vistas de forma agregada. La analítica se activa con consentimiento y se puede rechazar sin perder acceso al contenido.</li>
            <li><strong>Dirección IP y user agent.</strong> Los trata el proveedor de alojamiento para servir la web y protegerla frente a abusos.</li>
            <li><strong>Correo electrónico.</strong> Solo si nos escribes voluntariamente a la dirección de contacto, para responderte.</li>
          </ul>
          <p>La web no tiene formularios de registro, no vende productos digitales directamente y no elabora perfiles publicitarios personalizados.</p>

          <h2>Datos que trata la app</h2>
          <ul>
            <li><strong>Identificador de cuenta.</strong> El acceso se realiza con Iniciar sesión con Apple. Solo recibimos el identificador de usuario y, si lo autorizas, un correo de relay de Apple. No recibimos tu contraseña.</li>
            <li><strong>Progreso de lectura y actividad simulada.</strong> Los capítulos leídos, los marcadores, el saldo virtual y las operaciones simuladas se guardan para que puedas continuar donde lo dejaste.</li>
            <li><strong>Compras dentro de la app.</strong> Las gestiona Apple y las valida RevenueCat mediante un identificador anónimo de suscripción. No almacenamos datos de tu tarjeta.</li>
            <li><strong>Datos de mercado.</strong> Las cotizaciones se solicitan a proveedores externos mediante nuestro backend; no se envían datos personales en esas consultas.</li>
          </ul>

          <h2>Cuánto tiempo los conservamos</h2>
          <p>Los datos de cuenta y progreso se conservan mientras la cuenta esté activa. Si solicitas su eliminación, los borramos en un plazo máximo de 30 días, salvo los registros que debamos conservar por obligación legal o contable.</p>

          <h2>Con quién compartimos datos</h2>
          <p>Con los proveedores necesarios para prestar el servicio: Apple (inicio de sesión y pagos), Supabase (infraestructura y base de datos), RevenueCat (gestión de compras), proveedores de datos de mercado y Google (analítica de la web). No vendemos datos personales a terceros.</p>

          <h2>Tus derechos</h2>
          <p>Puedes solicitar acceso, rectificación, supresión, oposición, limitación y portabilidad de tus datos escribiendo a <a href="mailto:${site.contact}">${site.contact}</a>. También puedes reclamar ante la Agencia Española de Protección de Datos.</p>

          <h2>Menores</h2>
          <p>El servicio está dirigido a personas mayores de 18 años. No recogemos conscientemente datos de menores.</p>

          <h2>Cambios en esta política</h2>
          <p>Si modificamos esta política publicaremos la nueva versión en esta misma página actualizando la fecha del encabezado.</p>
        </div>
      </div>
    </section>
  `,
});

export const avisoLegalPage = page({
  path: '/aviso-legal/index.html',
  url: '/aviso-legal/',
  title: 'Aviso legal y condiciones de uso — Empezar a invertir',
  description:
    'Condiciones de uso del sitio y de la app Empezar a invertir, límites del contenido educativo, propiedad intelectual y exención de responsabilidad financiera.',
  ogName: 'aviso-legal',
  ogEyebrow: 'Legal',
  ogTitle: 'Aviso legal y condiciones de uso',
  body: () => `
    <section class="section section--tight">
      <div class="container container--narrow stack stack--lg">
        ${breadcrumbs([{ href: '/', label: 'Inicio' }, { href: '/aviso-legal/', label: 'Aviso legal' }])}
        <h1>Aviso legal y condiciones de uso</h1>
        <p class="muted">Última actualización: ${site.updated}.</p>
        <div class="prose">
          <h2>Objeto</h2>
          <p>Este sitio web y la app EAI ofrecen contenido educativo sobre finanzas personales e inversión. El acceso implica la aceptación de estas condiciones. Titular: el equipo editorial de Empezar a invertir, contacto <a href="mailto:${site.contact}">${site.contact}</a>.</p>

          <h2>No es asesoramiento financiero</h2>
          <p>Nada de lo publicado aquí constituye asesoramiento financiero, fiscal o legal personalizado, ni una recomendación de compra o venta de instrumentos financieros. El contenido tiene carácter divulgativo y puede no ajustarse a tu situación concreta, a tu horizonte temporal o a tu tolerancia al riesgo. Antes de invertir, consulta con un profesional registrado si lo necesitas.</p>

          <h2>Sobre la app y el dinero virtual</h2>
          <ul>
            <li>EAI no es un bróker ni una entidad registrada para prestar servicios de inversión.</li>
            <li>Las operaciones que realiza el usuario son <strong>simulaciones educativas</strong> y no se ejecutan en ningún mercado real.</li>
            <li>El saldo virtual no es dinero real: no se puede retirar, transferir, canjear ni convertir en efectivo.</li>
            <li>Las cotizaciones mostradas pueden estar retrasadas o ser incompletas y no deben usarse para tomar decisiones de inversión reales.</li>
            <li>El acceso a la app requiere Iniciar sesión con Apple.</li>
          </ul>

          <h2>Riesgo de invertir</h2>
          <p>Invertir conlleva riesgo de pérdida del capital. La rentabilidad pasada no garantiza resultados futuros. Los ejemplos numéricos de este sitio son ilustrativos y suponen condiciones constantes que no se dan en la realidad.</p>

          <h2>Propiedad intelectual</h2>
          <p>Los textos, ilustraciones, marca y código de este sitio pertenecen a sus autores. Puedes citar fragmentos indicando la fuente con un enlace a la página original. No está permitida la reproducción íntegra ni el uso comercial sin autorización escrita.</p>

          <h2>Enlaces de afiliado</h2>
          <p>Algunos enlaces a la tienda del libro son de afiliado. Si compras a través de ellos, el precio no varía para ti y podemos recibir una comisión. Esto no condiciona el contenido editorial.</p>

          <h2>Exención de responsabilidad</h2>
          <p>Hacemos lo posible por mantener la información actualizada y correcta, pero no garantizamos que esté libre de errores ni que refleje cambios normativos recientes. No nos hacemos responsables de decisiones tomadas a partir de este contenido ni de daños derivados de su uso.</p>

          <h2>Ley aplicable</h2>
          <p>Estas condiciones se rigen por la legislación española. Cualquier controversia se someterá a los juzgados y tribunales que correspondan según la normativa de consumo aplicable.</p>
        </div>
      </div>
    </section>
  `,
});

export const notFoundPage = page({
  path: '/404.html',
  url: '/404.html',
  title: 'Página no encontrada — Empezar a invertir',
  description: 'La página que buscas no existe o ha cambiado de dirección. Te dejamos los enlaces más útiles para seguir aprendiendo a invertir.',
  ogName: 'site',
  ogTitle: 'Página no encontrada',
  noindex: true,
  body: () => `
    <section class="section">
      <div class="container grid grid--split">
        <div class="stack stack--lg">
          <h1>Esta página no existe</h1>
          <p class="lead">Puede que el enlace esté mal escrito o que hayamos movido el contenido. Desde aquí puedes seguir por donde ibas.</p>
          <div class="actions">
            ${button({ href: '/articles/', label: 'Ver todos los artículos', iconName: 'arrowRight' })}
            ${button({ href: '/', label: 'Volver al inicio', variant: 'button--secondary' })}
          </div>
          <ul class="checklist">
            <li>${icon('book', { size: 20 })}<span><a class="text-link" href="/libro/">La guía completa para empezar a invertir</a></span></li>
            <li>${icon('phone', { size: 20 })}<span><a class="text-link" href="/app/">La app para practicar sin riesgo</a></span></li>
            <li>${icon('chart', { size: 20 })}<span><a class="text-link" href="/calculadora-interes-compuesto/">Calculadora de interés compuesto</a></span></li>
          </ul>
        </div>
        ${illustration('complicado')}
      </div>
    </section>
  `,
});

export { sectionHead, esc };
