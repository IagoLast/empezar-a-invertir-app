import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { importBook, parseBlocks } from './import-book.mjs';
const read = path => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
const lessons = read('../packages/contracts/book.json');
assert.equal(lessons.length, 20);
assert.equal(new Set(lessons.map(lesson => lesson.id)).size, lessons.length);
assert.deepEqual(lessons.map(lesson => lesson.number), Array.from({ length: lessons.length }, (_, i) => i + 1));
for (const lesson of lessons) {
  assert.match(lesson.id, /^book-[a-z-]+$/);
  assert.ok(lesson.minutes > 0 && lesson.blocks.length > 0);
  assert.deepEqual(lesson.blocks, parseBlocks(lesson.markdown).slice(1), `Full text must be preserved: ${lesson.id}`);
  assert.equal(new Set(lesson.blocks.map(block => block.id)).size, lesson.blocks.length);
}
assert.deepEqual(lessons, read('../apps/ios/Empezar/Resources/book.json'));
if (existsSync(new URL('../libro-bolsa/manuscript/Book.txt', import.meta.url))) {
  assert.deepEqual(lessons, importBook(), 'Run npm run book:import to update the bundled manuscript');
}
const table = lessons.flatMap(lesson => lesson.blocks).find(block => block.kind === 'table');
assert.equal(table.rows.length, 6);
assert.ok(table.rows.every(row => row.length === 3));
assert.deepEqual(parseBlocks('## Heading\n\nA **bold** paragraph.\n\n1. First\n2. Second\n\n> Quoted\n> Author').map(block => block.kind), ['heading', 'paragraph', 'listItem', 'listItem', 'quote']);
console.log('All 20 complete manuscript chapters and reader blocks verified.');
