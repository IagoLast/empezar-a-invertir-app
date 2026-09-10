// Compound interest calculator: the site's main interactive tool and a strong
// long tail search entry point.
import { calculatorFaq, site } from '../site.mjs';
import {
  button, callout, faqList, icon, illustration, sectionHead,
} from '../components.mjs';

// Static, crawlable example table (100 EUR/month at 6% for 10, 20 and 30 years).
const exampleRows = [
  { years: 10, contributed: 12000, final: 16470 },
  { years: 20, contributed: 24000, final: 46204 },
  { years: 30, contributed: 36000, final: 100452 },
];

const eur = value => `${value.toLocaleString('es-ES')} €`;

export const calculatorPage = {
  path: '/calculadora-interes-compuesto/index.html',
  url: '/calculadora-interes-compuesto/',
  title: 'Calculadora de interés compuesto — Simula tu inversión mensual',
  description:
    'Calcula cuánto crecería tu dinero con aportaciones periódicas y interés compuesto. Introduce capital inicial, aportación mensual, rentabilidad y años para ver el resultado.',
  image: '/img/og/calculadora.jpg',
  ogName: 'calculadora',
  ogEyebrow: 'Herramienta',
  ogTitle: 'Calculadora de interés compuesto',
  updated: site.updated,
  changefreq: 'monthly',
  priority: '0.8',

  schema: [
    {
      '@context': 'https://schema.org',
      '@type': 'WebApplication',
      name: 'Calculadora de interés compuesto',
      url: `${site.url}/calculadora-interes-compuesto/`,
      applicationCategory: 'FinanceApplication',
      operatingSystem: 'Cualquier navegador',
      inLanguage: 'es',
      description:
        'Calculadora gratuita de interés compuesto con aportaciones periódicas: capital inicial, aportación mensual, rentabilidad anual y años.',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR' },
      publisher: { '@type': 'Organization', name: site.name, url: `${site.url}/` },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: calculatorFaq.map(item => ({
        '@type': 'Question',
        name: item.question,
        acceptedAnswer: { '@type': 'Answer', text: item.answer },
      })),
    },
  ],

  body: () => `
    <section class="section section--tight">
      <div class="container">
        <div class="section__head">
          <h1>Calculadora de interés compuesto</h1>
          <p class="lead">Introduce tus números y observa cómo el tiempo y las aportaciones periódicas cambian el resultado. Sin registro y sin dejar tus datos en ningún sitio: todo se calcula en tu navegador.</p>
        </div>

        <div class="calculator" style="margin-top:40px">
          <form class="card" id="calculadora" novalidate>
            <h2 style="font-size:1.25rem">Tus datos</h2>
            <div class="field">
              <label for="inicial">Capital inicial (€)</label>
              <input id="inicial" name="inicial" type="number" min="0" step="100" value="1000" inputmode="decimal">
            </div>
            <div class="field">
              <label for="mensual">Aportación mensual (€)</label>
              <input id="mensual" name="mensual" type="number" min="0" step="10" value="150" inputmode="decimal">
            </div>
            <div class="field">
              <label for="rentabilidad">Rentabilidad anual estimada (%)</label>
              <input id="rentabilidad" name="rentabilidad" type="number" min="0" max="20" step="0.1" value="6" inputmode="decimal">
              <small>Un escenario habitual para una cartera global diversificada está entre el 4 % y el 7 % anual, aunque ningún año se parece a la media.</small>
            </div>
            <div class="field">
              <label for="anios">Años invertidos</label>
              <input id="anios" name="anios" type="number" min="1" max="50" step="1" value="25" inputmode="numeric">
            </div>
          </form>

          <div class="card" aria-live="polite">
            <h2 style="font-size:1.25rem">Resultado</h2>
            <div class="result">
              <span class="result__label">Valor final estimado</span>
              <span class="result__value" id="resultado-final">—</span>
            </div>
            <div class="grid grid--2" style="margin-top:12px">
              <div class="result">
                <span class="result__label">Has aportado</span>
                <span class="result__value" id="resultado-aportado" style="font-size:1.5rem">—</span>
              </div>
              <div class="result">
                <span class="result__label">Intereses generados</span>
                <span class="result__value" id="resultado-intereses" style="font-size:1.5rem">—</span>
              </div>
            </div>
            <div class="bar-chart" id="grafico" aria-hidden="true"></div>
            <p class="muted" style="font-size:.8125rem">Cada barra es un año. El crecimiento no es lineal: las últimas barras crecen mucho más porque los intereses también generan intereses.</p>
          </div>
        </div>

        <div class="card card--flat" style="margin-top:32px">
          <h2 style="font-size:1.25rem">Detalle por años</h2>
          <div style="overflow-x:auto">
            <table class="data-table" style="min-width:520px">
              <thead>
                <tr><th>Año</th><th>Has aportado</th><th>Intereses</th><th>Valor final</th></tr>
              </thead>
              <tbody id="tabla-detalle">
                ${exampleRows
                  .map(
                    row => `<tr><td>${row.years}</td><td>${eur(row.contributed)}</td><td>${eur(row.final - row.contributed)}</td><td>${eur(row.final)}</td></tr>`,
                  )
                  .join('')}
              </tbody>
            </table>
          </div>
          <p class="muted" style="font-size:.8125rem">Ejemplo estático con 100 € al mes al 6 % anual. La tabla se recalcula con tus datos en cuanto cambias un valor.</p>
        </div>

        <noscript>
          <p class="disclaimer" style="margin-top:24px">Activa JavaScript para calcular con tus propios datos. La tabla de ejemplo funciona sin JavaScript.</p>
        </noscript>
      </div>
    </section>

    <section class="section section--surface">
      <div class="container grid grid--split">
        <div class="stack stack--lg">
          ${sectionHead({
            eyebrow: 'Cómo leerlo',
            title: 'El tiempo pesa más que la cantidad',
            text: 'La fórmula del interés compuesto premia dos cosas: aportar de forma constante y no interrumpir el proceso.',
          })}
          <ul class="prose" style="font-size:1.0625rem">
            <li><strong>Aportación periódica:</strong> sumar cada mes tiene más efecto que esperar a tener una cantidad grande.</li>
            <li><strong>Horizonte:</strong> pasar de 10 a 30 años no triplica el resultado, lo multiplica.</li>
            <li><strong>Costes:</strong> una comisión del 1 % anual puede llevarse una parte enorme del resultado a 30 años.</li>
            <li><strong>Inflación:</strong> resta la inflación media a la rentabilidad para ver el poder adquisitivo real.</li>
          </ul>
          ${callout('Importante', 'Esta calculadora hace aritmética con una rentabilidad constante. La realidad incluye años malos, impuestos y comisiones. Úsala para entender el mecanismo, no como una promesa.')}
        </div>
        ${illustration('compound')}
      </div>
    </section>

    <section class="section">
      <div class="container container--narrow">
        ${sectionHead({ center: true, eyebrow: 'Preguntas frecuentes', title: 'Dudas sobre el interés compuesto' })}
        ${faqList(calculatorFaq)}
      </div>
    </section>

    <section class="section section--ink">
      <div class="container container--narrow center">
        <h2>Pon a prueba tu plan sin arriesgar nada</h2>
        <p class="lead" style="margin-top:16px">La app parte de ${site.app.startingCash} virtuales para que veas cómo se comporta una cartera mes a mes antes de invertir tu dinero.</p>
        <div class="actions actions--center" style="margin-top:28px">
          ${button({ href: '/app/', label: 'Descubrir la app', iconName: 'arrowRight' })}
          ${button({ href: '/articles/que-es-el-interes-compuesto.html', label: 'Leer la guía completa', variant: 'button--secondary' })}
        </div>
      </div>
    </section>

    <script>
      (function () {
        var form = document.getElementById('calculadora');
        if (!form) return;
        var fields = ['inicial', 'mensual', 'rentabilidad', 'anios'].map(function (id) {
          return document.getElementById(id);
        });
        var final = document.getElementById('resultado-final');
        var aportado = document.getElementById('resultado-aportado');
        var intereses = document.getElementById('resultado-intereses');
        var grafico = document.getElementById('grafico');
        var tabla = document.getElementById('tabla-detalle');
        var money = new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
        var milestones = [1, 5, 10, 15, 20, 25, 30, 40, 50];

        function calcular() {
          var inicial = Math.max(0, Number(document.getElementById('inicial').value) || 0);
          var mensual = Math.max(0, Number(document.getElementById('mensual').value) || 0);
          var tasa = Math.max(0, Number(document.getElementById('rentabilidad').value) || 0) / 100;
          var anios = Math.min(60, Math.max(1, Math.round(Number(document.getElementById('anios').value) || 1)));
          var meses = anios * 12;
          var mensualTasa = Math.pow(1 + tasa, 1 / 12) - 1;
          var valor = inicial;
          var aportadoTotal = inicial;
          var serie = [];
          for (var mes = 1; mes <= meses; mes++) {
            valor = valor * (1 + mensualTasa) + mensual;
            aportadoTotal += mensual;
            if (mes % 12 === 0) serie.push(valor);
          }
          final.textContent = money.format(valor);
          aportado.textContent = money.format(aportadoTotal);
          intereses.textContent = money.format(valor - aportadoTotal);

          var max = Math.max.apply(null, serie.concat([1]));
          grafico.innerHTML = serie
            .map(function (value) {
              return '<span style="height:' + Math.max(2, (value / max) * 100).toFixed(1) + '%"></span>';
            })
            .join('');

          var filas = '';
          var valorFila = inicial;
          var aportadoFila = inicial;
          for (var anio = 1; anio <= anios; anio++) {
            aportadoFila += mensual * 12;
            for (var m = 0; m < 12; m++) valorFila = valorFila * (1 + mensualTasa) + mensual;
            if (milestones.indexOf(anio) !== -1 || anio === anios) {
              filas +=
                '<tr><td>' + anio + '</td><td>' + money.format(aportadoFila) + '</td><td>' +
                money.format(valorFila - aportadoFila) + '</td><td>' + money.format(valorFila) + '</td></tr>';
            }
          }
          tabla.innerHTML = filas;
        }

        fields.forEach(function (field) {
          field.addEventListener('input', calcular);
        });
        calcular();
      })();
    </script>
  `,
};
