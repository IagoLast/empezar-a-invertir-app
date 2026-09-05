import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { symbols } from '../apps/api/lib/market.js';
const read = path => JSON.parse(readFileSync(new URL(path, import.meta.url)));
const catalog = read('../packages/contracts/catalog.json');
const lessons = read('../packages/contracts/lessons.json');
assert.deepEqual(catalog.map(x => x.symbol).sort(), [...symbols].sort());
assert.equal(new Set(lessons.map(x => x.id)).size, 4);
for (const name of ['catalog', 'lessons']) {
  assert.deepEqual(read(`../packages/contracts/${name}.json`), read(`../apps/ios/Empezar/Resources/${name}.json`), 'Run npm run ios:prepare after changing shared content');
}
console.log('Shared catalog and iOS resources match.');
