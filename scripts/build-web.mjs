#!/usr/bin/env node
// Generates the static site into apps/web from the sources in web/.
// Generated files are committed: CI only needs Node and never a build step.
import { mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildSite } from '../web/build.mjs';

const outputDir = fileURLToPath(new URL('../apps/web', import.meta.url));
const generatedExtensions = new Set(['.html', '.xml', '.txt']);
const { files } = buildSite();

// Remove previously generated pages that are no longer part of the site.
function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) return entry.name === 'img' ? [] : walk(full);
    return [full];
  });
}

const expected = new Set([...files.keys()].map(path => resolve(outputDir, `.${path}`)));
for (const file of walk(outputDir)) {
  const isGenerated =
    generatedExtensions.has(file.slice(file.lastIndexOf('.'))) || file.endsWith('site.webmanifest');
  if (isGenerated && !expected.has(resolve(file))) {
    rmSync(file);
    console.log(`removed ${relative(outputDir, file)}`);
  }
}

for (const [path, contents] of files) {
  const target = resolve(outputDir, `.${path}`);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, contents);
}

const pages = [...files.keys()].filter(path => path.endsWith('.html')).length;
console.log(`Wrote ${files.size} files (${pages} pages) into ${relative(process.cwd(), outputDir)}${sep}`);
