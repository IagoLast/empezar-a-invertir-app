// Site level configuration and reusable copy.
// Everything user facing is written in Spanish; code stays in English.

export const site = {
  name: 'Empezar a invertir',
  shortName: 'Empezar',
  url: 'https://www.empezar-a-invertir.com',
  lang: 'es',
  locale: 'es_ES',
  themeColor: '#F5F6F8',
  themeColorDark: '#0C1017',
  gtm: 'GTM-MQBDL6HW',
  updated: '2026-09-10',
  tagline: 'Aprende a invertir y practícalo sin arriesgar dinero',
  description:
    'Aprende a invertir desde cero con una guía clara y una app para practicar con una cartera de dinero ficticio. Sin jerga, sin promesas y sin arriesgar un euro.',
  nav: [
    { path: '/app/', label: 'La app' },
    { path: '/libro/', label: 'El libro' },
    { path: '/articles/', label: 'Artículos' },
    { path: '/glosario/', label: 'Glosario' },
    { path: '/calculadora-interes-compuesto/', label: 'Calculadora' },
  ],
  book: {
    title: 'Guía para empezar a invertir',
    chapters: 20,
    minutes: 127,
    leanpub: 'https://leanpub.com/guia-empezar-invertir',
    amazon:
      'https://www.amazon.es/dp/B0F6JRM84H?maas=maas_adg_C6F4C3B555BEA3BC23C57D03DE163D10_afap_abs&ref_=aa_maas&tag=maas&ascsubtag=landing_web',
  },
  app: {
    name: 'EAI',
    // Set to the App Store URL once the app is published; the badge switches
    // from "coming soon" to a download link automatically.
    storeUrl: null,
    requirements: 'iPhone con iOS 17 o posterior · Inicio de sesión con Apple',
    startingCash: '10.000 USD',
  },
  contact: 'hola@empezar-a-invertir.com',
};

// Reading order of the bundled book, used by the book page and the app page.
export const bookChapters = [
  { section: 'Introducción', chapters: [{ title: 'Introducción', minutes: 13 }] },
  {
    section: 'Conceptos financieros básicos',
    chapters: [
      { title: 'Dinero', minutes: 8 },
      { title: 'Juego de suma cero', minutes: 5 },
      { title: 'Activos y pasivos', minutes: 6 },
      { title: 'Liquidez', minutes: 5 },
      { title: 'Inflación', minutes: 8 },
      { title: 'Volatilidad', minutes: 4 },
      { title: 'Riesgo', minutes: 7 },
      { title: 'El interés compuesto', minutes: 2 },
      { title: 'Diversificación', minutes: 2 },
      { title: 'Relación entre rentabilidad y riesgo', minutes: 3 },
      { title: 'Los costes de invertir', minutes: 2 },
      { title: 'Tipos de interés', minutes: 5 },
    ],
  },
  {
    section: '¿Dónde invertir?',
    chapters: [
      { title: 'El origen de la bolsa', minutes: 11 },
      { title: 'Acciones', minutes: 15 },
      { title: 'Renta fija', minutes: 10 },
      { title: 'Fondos de inversión', minutes: 10 },
      { title: 'Otras formas de invertir', minutes: 5 },
    ],
  },
  { section: 'Conclusión', chapters: [{ title: 'Conclusión', minutes: 4 }] },
];

export const appFeatures = [
  {
    illustration: 'learning',
    title: 'Aprende paso a paso',
    text: 'Los 20 capítulos de la guía en formato lectura, con marcadores, progreso guardado y explicaciones de cada concepto dentro de la propia interfaz.',
  },
  {
    illustration: 'markets',
    title: 'Explora el mercado',
    text: 'Busca acciones y ETF de todo el mundo, consulta su ficha, su gráfico y los datos clave antes de decidir. Sin análisis técnico ni ruido.',
  },
  {
    illustration: 'practice',
    title: 'Practica con dinero ficticio',
    text: 'Empieza con 10.000 USD virtuales, lanza órdenes de compra y venta simuladas y observa cómo evoluciona tu cartera con precios reales de mercado.',
  },
];

export const homeFaq = [
  {
    question: '¿Necesito dinero real para practicar con la app?',
    answer:
      'No. La app arranca con una cartera virtual de 10.000 USD que no es dinero real y no se puede retirar ni canjear. Puedes comprar y vender acciones y ETF simulados para entender cómo se comporta una cartera antes de invertir tu dinero.',
  },
  {
    question: '¿Esto es asesoramiento financiero?',
    answer:
      'No. El libro y la app son material educativo. Explican conceptos, muestran ejemplos y te ayudan a practicar, pero no recomiendan productos ni sustituyen el consejo de un profesional que conozca tu situación.',
  },
  {
    question: '¿Puedo empezar a invertir con poco dinero?',
    answer:
      'Sí. Muchos fondos indexados y roboadvisors permiten empezar con aportaciones de 50 o 100 euros al mes. Antes de invertir conviene tener un fondo de emergencia y las deudas caras bajo control.',
  },
  {
    question: '¿En qué se diferencia el libro de la app?',
    answer:
      'El libro es la guía completa: 20 capítulos que explican el dinero, el riesgo, el interés compuesto o los fondos de inversión con calma. La app convierte ese contenido en práctica diaria con lectura integrada y una cartera simulada.',
  },
  {
    question: '¿Cuándo estará disponible la app?',
    answer:
      'Está en fase final de preparación para el App Store. Mientras tanto puedes leer los artículos del blog y conseguir la guía, que cubre exactamente los mismos fundamentos.',
  },
];

export const appFaq = [
  {
    question: '¿La app sirve para aprender si nunca he invertido?',
    answer:
      'Sí, está pensada para eso. Empieza por los conceptos —dinero, inflación, riesgo, interés compuesto— y avanza hasta productos concretos como acciones, renta fija y fondos. Cada término se explica dentro de la app, sin dar nada por sabido.',
  },
  {
    question: '¿Puedo perder dinero usando la app?',
    answer:
      'No puedes perder dinero real porque las operaciones son simuladas y el saldo es ficticio. Lo que sí vas a notar son las emociones de una cartera que sube y baja, que es justo lo que conviene entrenar antes de invertir.',
  },
  {
    question: '¿Necesito cuenta para usarla?',
    answer: 'Sí. El acceso se hace con Iniciar sesión con Apple, que evita crear y recordar otra contraseña.',
  },
  {
    question: '¿Puedo leer el contenido sin comprar saldo virtual?',
    answer:
      'Sí. La compra de la app da acceso al contenido educativo y a la cartera virtual inicial. Las recargas de saldo simulado son opcionales, no son suscripciones y no se renuevan solas.',
  },
  {
    question: '¿En qué idioma está la app?',
    answer: 'Toda la interfaz y el contenido educativo están en español.',
  },
];

export const bookFaq = [
  {
    question: '¿Para quién es este libro?',
    answer:
      'Para quien nunca ha invertido y quiere entender lo esencial antes de mover dinero, y para quien ya ha empezado pero se ha dado cuenta de que le faltan los cimientos.',
  },
  {
    question: '¿Necesito conocimientos previos?',
    answer:
      'Ninguno. El libro empieza explicando qué es el dinero y termina comparando productos de inversión, sin dar nada por supuesto.',
  },
  {
    question: '¿En qué formato está disponible?',
    answer:
      'En Leanpub tienes PDF, EPUB y MOBI para cualquier dispositivo. En Amazon está disponible en Kindle y en tapa blanda.',
  },
  {
    question: '¿El libro promete rentabilidades?',
    answer:
      'No. No encontrarás fórmulas mágicas ni promesas de rentabilidad. El objetivo es que entiendas el riesgo, los costes y el interés compuesto para decidir con criterio propio.',
  },
];

export const calculatorFaq = [
  {
    question: '¿Qué es el interés compuesto?',
    answer:
      'Es el efecto de reinvertir los rendimientos que genera tu dinero: los intereses producen nuevos intereses. Con el tiempo, el crecimiento deja de ser lineal y se acelera.',
  },
  {
    question: '¿Esta calculadora garantiza la rentabilidad que muestra?',
    answer:
      'No. Es una simulación aritmética con una rentabilidad anual constante. En la realidad los mercados suben y bajan cada año, y la rentabilidad pasada no asegura la futura.',
  },
  {
    question: '¿Qué rentabilidad anual tiene sentido usar?',
    answer:
      'Depende del activo y del periodo. Para una cartera global diversificada se suelen usar escenarios conservadores de entre el 4 % y el 7 % anual nominal, sabiendo que ningún año será igual a la media.',
  },
  {
    question: '¿La inflación está incluida en el cálculo?',
    answer:
      'El resultado se muestra en euros nominales. Para ver el poder adquisitivo real, resta la inflación media anual a la rentabilidad que introduzcas.',
  },
];
