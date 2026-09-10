#!/usr/bin/env node
// Bundles the vgpu shader module in web/gpu into apps/web/js/webgpu-effect.js and
// copies the loader to apps/web/js/webgpu.js.
//
// The output is committed, so the served site stays plain static files and CI
// never installs vgpu. Install the shader toolchain only when you change the
// shaders:
//
//   npm --prefix web/gpu install
//   npm run web:gpu
import { createHash } from 'node:crypto';
import { chmodSync, copyFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';

const sourceDir = fileURLToPath(new URL('../web/gpu/', import.meta.url));
const outputDir = fileURLToPath(new URL('../apps/web/js/', import.meta.url));
const budgets = { raw: 220 * 1024, gzip: 60 * 1024 };

if (!existsSync(new URL('node_modules/esbuild', new URL('file://' + sourceDir)))) {
  console.error('Missing shader toolchain. Run:\n  npm --prefix web/gpu install');
  process.exit(1);
}

const esbuild = await import(new URL('node_modules/esbuild/lib/main.js', new URL('file://' + sourceDir)));
const entry = new URL('effect.js', new URL('file://' + sourceDir));
const sourceHash = createHash('sha256').update(readFileSync(entry)).digest('hex').slice(0, 16);
const vgpuVersion = JSON.parse(
  readFileSync(new URL('node_modules/vgpu/package.json', new URL('file://' + sourceDir)), 'utf8'),
).version;

const result = await esbuild.build({
  entryPoints: [fileURLToPath(entry)],
  bundle: true,
  format: 'esm',
  target: 'es2022',
  minify: true,
  legalComments: 'none',
  write: false,
  banner: { js: `/* webgpu-effect source=${sourceHash} vgpu=${vgpuVersion} */` },
});

const code = result.outputFiles[0].text;
const gzip = gzipSync(code).length;
if (code.length > budgets.raw || gzip > budgets.gzip) {
  console.error(`Bundle exceeds the budget: ${code.length} B raw / ${gzip} B gzip.`);
  process.exit(1);
}

mkdirSync(outputDir, { recursive: true });
writeFileSync(new URL('webgpu-effect.js', new URL('file://' + outputDir)), code);
copyFileSync(new URL('loader.js', new URL('file://' + sourceDir)), new URL('webgpu.js', new URL('file://' + outputDir)));
// Served artifacts, not local tooling: keep them world readable.
chmodSync(new URL('webgpu-effect.js', new URL('file://' + outputDir)), 0o644);
chmodSync(new URL('webgpu.js', new URL('file://' + outputDir)), 0o644);

console.log(
  `Wrote js/webgpu.js (${statSync(new URL('webgpu.js', new URL('file://' + outputDir))).size} B) ` +
  `and js/webgpu-effect.js (${(code.length / 1024).toFixed(1)} KB raw, ${(gzip / 1024).toFixed(1)} KB gzip, ` +
  `source=${sourceHash}, vgpu=${vgpuVersion}).`,
);
