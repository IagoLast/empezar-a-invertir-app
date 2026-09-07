import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const manuscript = new URL('../libro-bolsa/manuscript/', import.meta.url);
const sourceMap = {
  '1_introduccion.md': ['purpose', 'introduction'],
  '2_1_dinero.md': ['money', 'fundamentals'],
  '2_1_1_suma_cero.md': ['zero-sum', 'fundamentals'],
  '2_2_activos.md': ['assets-liabilities', 'fundamentals'],
  '2_3_liquidez.md': ['liquidity', 'fundamentals'],
  '2_4_inflacion.md': ['inflation', 'fundamentals'],
  '2_5_volatilidad.md': ['volatility', 'fundamentals'],
  '2_6_riesgo.md': ['risk', 'fundamentals'],
  '2_7_interes_compuesto.md': ['compound-interest', 'fundamentals'],
  '2_7_diversificacion.md': ['diversification', 'fundamentals'],
  '2_8_rentabilidad_riesgo.md': ['risk-return', 'fundamentals'],
  '2_9_costes_invertir.md': ['investing-costs', 'fundamentals'],
  '2_10_tipos_de_interes.md': ['interest-rates', 'fundamentals'],
  '03_01_introduccion.md': ['investment-options', 'investments'],
  '03_02_contexto_historico.md': ['stock-market-history', 'investments'],
  '03_03_acciones.md': ['stocks', 'investments'],
  '03_04_renta_fija.md': ['fixed-income', 'investments'],
  '03_05_fondos.md': ['funds', 'investments'],
  '03_06_otras_inversiones.md': ['other-investments', 'investments'],
  '04_conclusion.md': ['conclusion', 'conclusion'],
};
const cleanTitle = text => text.replaceAll('**', '').trim();
export function parseBlocks(markdown) {
  const blocks = [];
  const lines = markdown.replaceAll('\r\n', '\n').split('\n');
  const add = (kind, text, extra = {}) => blocks.push({ id: `block-${blocks.length}`, kind, text, ...extra });
  for (let i = 0; i < lines.length;) {
    const line = lines[i].trim();
    if (!line) { i++; continue; }
    const heading = /^(#{1,6})\s+(.+)$/.exec(line);
    if (heading) { add('heading', cleanTitle(heading[2]), { level: heading[1].length }); i++; continue; }
    if (/^([-*_])(?:\s*\1){2,}$/.test(line)) { add('divider', ''); i++; continue; }
    if (line.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        const cells = lines[i++].trim().replace(/^\||\|$/g, '').split('|').map(x => x.trim());
        if (!cells.every(x => /^:?-+:?$/.test(x))) rows.push(cells);
      }
      add('table', '', { rows }); continue;
    }
    if (line.startsWith('>')) {
      const quote = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) quote.push(lines[i++].trim().replace(/^>\s?/, ''));
      add('quote', quote.join('\n')); continue;
    }
    const list = /^(?:[-*+]\s+|(\d+)\.\s+)(.+)$/.exec(line);
    if (list) { add('listItem', list[2], { marker: list[1] ? `${list[1]}.` : '•' }); i++; continue; }
    const paragraph = [line]; i++;
    while (i < lines.length && lines[i].trim() && !/^(?:#{1,6}\s|>|\||[-*+]\s|\d+\.\s)/.test(lines[i].trim())) paragraph.push(lines[i++].trim());
    add('paragraph', paragraph.join(' '));
  }
  return blocks;
}
export function importBook() {
  const order = readFileSync(new URL('Book.txt', manuscript), 'utf8').trim().split(/\r?\n/);
  const lessons = [];
  for (const source of order) {
    const markdown = readFileSync(new URL(source, manuscript), 'utf8');
    const blocks = parseBlocks(markdown);
    if (blocks.length === 1 && blocks[0].kind === 'heading') continue;
    const mapping = sourceMap[source];
    if (!mapping) throw new Error(`Add a stable English lesson ID for ${source}`);
    if (blocks[0]?.kind !== 'heading') throw new Error(`Missing chapter title: ${source}`);
    const title = blocks.shift().text;
    const words = markdown.trim().split(/\s+/u).length;
    lessons.push({ id: `book-${mapping[0]}`, section: mapping[1], number: lessons.length + 1,
      title, minutes: Math.max(1, Math.ceil(words / 200)), source, markdown, blocks });
  }
  return lessons;
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const lessons = importBook();
  const output = JSON.stringify(lessons, null, 2) + '\n';
  for (const target of ['../packages/contracts/book.json', '../apps/ios/Empezar/Resources/book.json']) writeFileSync(new URL(target, import.meta.url), output);
  console.log(`Imported ${lessons.length} complete book chapters.`);
}
