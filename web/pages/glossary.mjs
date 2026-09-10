// Glossary: a compact reference that captures "qué es X" searches and links
// every definition to the article that explains it in depth.
import { site } from '../site.mjs';
import { breadcrumbs } from '../components.mjs';

const terms = [
  { term: 'Acción', definition: 'Participación en la propiedad de una empresa. Si la empresa gana dinero, tu acción puede revalorizarse o repartir dividendos; si pierde valor, puedes perder parte de lo invertido.', slug: 'que-es-un-etf' },
  { term: 'Activo', definition: 'Todo lo que posees y puede generar valor o rentas: dinero, fondos, acciones, un inmueble o un negocio.', slug: 'diferencia-entre-activos-y-pasivos' },
  { term: 'Aportación periódica', definition: 'Invertir la misma cantidad de dinero a intervalos regulares, normalmente cada mes, sin intentar acertar el momento del mercado.', slug: 'dca-invertir-cada-mes' },
  { term: 'Base del ahorro', definition: 'Parte de la declaración donde tributan las ganancias de inversiones y dividendos, con tipos que van del 19 % al 28 % por tramos.', slug: 'fiscalidad-fondos-indexados-espana' },
  { term: 'Bono', definition: 'Préstamo que haces a un gobierno o a una empresa a cambio de intereses. Forma parte de la renta fija.', slug: 'renta-fija-vs-renta-variable' },
  { term: 'Bróker', definition: 'Intermediario que ejecuta órdenes de compra y venta de instrumentos financieros. No es lo mismo que un asesor financiero.', slug: 'donde-invertir-mi-dinero-opciones-novatos' },
  { term: 'Cartera', definition: 'Conjunto de inversiones que tienes. Su composición —cuánto en bolsa, cuánto en renta fija, en qué mercados— determina tu riesgo.', slug: 'cartera-indexada-tres-fondos' },
  { term: 'Comisión', definition: 'Coste que paga el inversor: de gestión, de depósito, de compraventa o de cambio de divisa. Se resta de tu rentabilidad todos los años.', slug: 'que-es-un-fondo-indexado' },
  { term: 'Cotización', definition: 'Precio al que se compra y se vende un activo en el mercado en un momento dado.', slug: 'que-es-un-etf' },
  { term: 'Cupón', definition: 'Interés periódico que paga un bono hasta su vencimiento. Puede ser fijo o variable.', slug: 'renta-fija-vs-renta-variable' },
  { term: 'Diversificación', definition: 'Repartir la inversión entre muchos activos, sectores y países para que el resultado no dependa de una sola apuesta.', slug: 'que-es-la-diversificacion' },
  { term: 'Dividendo', definition: 'Parte del beneficio que una empresa reparte entre sus accionistas, normalmente en efectivo. El día que se paga, el precio de la acción baja aproximadamente ese importe.', slug: 'que-son-los-dividendos' },
  { term: 'ETF', definition: 'Fondo cotizado que se compra y se vende en bolsa como una acción. Suele replicar un índice y tener comisiones bajas, pero no permite traspasos sin tributar en España.', slug: 'que-es-un-etf' },
  { term: 'Fondo de emergencia', definition: 'Dinero líquido reservado para imprevistos, equivalente a entre tres y seis meses de gastos. Se tiene antes de empezar a invertir.', slug: 'fondo-de-emergencia-cuanto-necesito' },
  { term: 'Fondo de inversión', definition: 'Vehículo que reúne el dinero de muchos inversores para comprar una cartera gestionada por una gestora.', slug: 'que-es-un-fondo-indexado' },
  { term: 'Fondo indexado', definition: 'Fondo de inversión que replica un índice en lugar de intentar batirlo. En España permite traspasar dinero entre fondos sin tributar.', slug: 'que-es-un-fondo-indexado' },
  { term: 'Horizonte temporal', definition: 'Tiempo que puedes dejar el dinero invertido sin necesitarlo. Cuanto más largo, más riesgo puedes asumir con sentido.', slug: 'como-empezar-a-invertir-desde-cero' },
  { term: 'Inflación', definition: 'Subida generalizada de los precios. Reduce el poder adquisitivo de tu dinero parado, por eso invertir es una forma de protegerlo.', slug: 'que-es-la-inflacion-como-afecta-ahorros' },
  { term: 'Interés compuesto', definition: 'Efecto de reinvertir los rendimientos: los intereses generan nuevos intereses y el crecimiento se acelera con el tiempo.', slug: 'que-es-el-interes-compuesto' },
  { term: 'Liquidez', definition: 'Facilidad para convertir un activo en dinero sin perder valor. El dinero en cuenta es líquido; un inmueble no lo es.', slug: 'fondo-de-emergencia-cuanto-necesito' },
  { term: 'Mercado alcista y bajista', definition: 'Tendencia sostenida de subida (alcista) o de bajada (bajista). Nadie puede predecir cuándo cambia una u otra.', slug: 'psicologia-del-inversor' },
  { term: 'Participación', definition: 'Cada unidad de un fondo de inversión. Su valor es el valor liquidativo del día.', slug: 'que-es-un-fondo-indexado' },
  { term: 'Pasivo', definition: 'Obligación o bien que te genera gastos: una deuda, un préstamo, un coche que solo cuesta dinero.', slug: 'diferencia-entre-activos-y-pasivos' },
  { term: 'Plusvalía', definition: 'Ganancia obtenida al vender un activo por encima de su precio de compra. Tributa en la base del ahorro.', slug: 'fiscalidad-fondos-indexados-espana' },
  { term: 'Rebalanceo', definition: 'Volver a tu reparto objetivo entre bloques de la cartera, normalmente una vez al año y usando las nuevas aportaciones.', slug: 'cartera-indexada-tres-fondos' },
  { term: 'Renta fija', definition: 'Inversiones de deuda, como bonos o letras del Tesoro, que pagan intereses. Menos volátiles que la bolsa, no exentas de riesgo.', slug: 'renta-fija-vs-renta-variable' },
  { term: 'Renta variable', definition: 'Acciones y fondos de acciones. Mayor potencial de rentabilidad a largo plazo y también mayores caídas.', slug: 'renta-fija-vs-renta-variable' },
  { term: 'Riesgo', definition: 'Posibilidad de perder parte del capital o de no alcanzar el objetivo. No se elimina: se gestiona diversificando y ajustando el horizonte.', slug: 'errores-comunes-invertir-principiantes' },
  { term: 'TER', definition: 'Total Expense Ratio: porcentaje anual que cobra un fondo o ETF por gestionarlo. Es el dato que más conviene comparar.', slug: 'que-es-un-etf' },
  { term: 'Traspaso', definition: 'Mover dinero de un fondo de inversión a otro sin tributar en ese momento. La ganancia se declara al reembolsar el dinero.', slug: 'fiscalidad-fondos-indexados-espana' },
  { term: 'Valor liquidativo', definition: 'Valor de cada participación de un fondo. Se calcula una vez al día, al cierre del mercado.', slug: 'que-es-un-fondo-indexado' },
  { term: 'Volatilidad', definition: 'Magnitud de las oscilaciones del precio de un activo. Alta volatilidad no siempre significa más riesgo si el horizonte es largo.', slug: 'psicologia-del-inversor' },
];

const sorted = [...terms].sort((a, b) => a.term.localeCompare(b.term, 'es'));

export const glossaryPage = {
  path: '/glosario/index.html',
  url: '/glosario/',
  title: 'Glosario de inversión para principiantes — Empezar a invertir',
  description:
    'Glosario con los términos de inversión que más te vas a encontrar: ETF, fondo indexado, interés compuesto, renta fija, TER, traspaso y muchos más, explicados en una frase.',
  image: '/img/og/glosario.jpg',
  ogName: 'glosario',
  ogEyebrow: 'Glosario',
  ogTitle: 'Glosario de inversión para principiantes',
  updated: site.updated,
  changefreq: 'monthly',
  priority: '0.6',

  schema: [
    {
      '@context': 'https://schema.org',
      '@type': 'DefinedTermSet',
      name: 'Glosario de inversión',
      url: `${site.url}/glosario/`,
      inLanguage: 'es',
      hasDefinedTerm: sorted.map(item => ({
        '@type': 'DefinedTerm',
        name: item.term,
        description: item.definition,
        inDefinedTermSet: `${site.url}/glosario/`,
      })),
    },
    {
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Inicio', item: `${site.url}/` },
        { '@type': 'ListItem', position: 2, name: 'Glosario', item: `${site.url}/glosario/` },
      ],
    },
  ],

  body: () => `
    <section class="section section--tight">
      <div class="container stack stack--lg">
        ${breadcrumbs([{ href: '/', label: 'Inicio' }, { href: '/glosario/', label: 'Glosario' }])}
        <div class="section__head">
          <h1>Los términos de inversión, en una frase</h1>
          <p class="lead">${sorted.length} palabras que aparecen en cualquier conversación sobre invertir, explicadas sin rodeos. Cada definición enlaza con la guía donde se desarrolla.</p>
        </div>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container">
        <ol class="term-list">
          ${sorted
            .map(
              (item, index) => `<li>
            <a class="term-row" href="/articles/${item.slug}.html">
              <span class="term-row__index">${String(index + 1).padStart(2, '0')}</span>
              <span class="term-row__term">${item.term}</span>
              <span class="term-row__definition">${item.definition}</span>
            </a>
          </li>`,
            )
            .join('')}
        </ol>
      </div>
    </section>
  `,
};
