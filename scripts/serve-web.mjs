#!/usr/bin/env node
// Minimal static server for previewing apps/web locally (npm run web:serve).
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createGzip } from 'node:zlib';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../apps/web', import.meta.url));
const port = Number(process.env.PORT ?? 4173);

const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
};

const compressible = /^(text\/|application\/(javascript|json|xml|manifest\+json)|image\/svg)/;

createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  let target = resolve(root, `.${normalize(pathname)}`);

  if (!target.startsWith(root)) {
    response.writeHead(403).end('Forbidden');
    return;
  }
  if (existsSync(target) && statSync(target).isDirectory()) target = join(target, 'index.html');
  if (!existsSync(target)) {
    const notFound = join(root, '404.html');
    if (!existsSync(notFound)) {
      response.writeHead(404).end('Not found');
      return;
    }
    response.writeHead(404, { 'content-type': types['.html'] });
    createReadStream(notFound).pipe(response);
    return;
  }

  const type = types[extname(target)] ?? 'application/octet-stream';
  // Compress like a production host so local transfer sizes are realistic.
  if (compressible.test(type) && /\bgzip\b/.test(request.headers['accept-encoding'] ?? '')) {
    response.writeHead(200, { 'content-type': type, 'content-encoding': 'gzip', vary: 'accept-encoding' });
    createReadStream(target).pipe(createGzip()).pipe(response);
    return;
  }

  response.writeHead(200, { 'content-type': type });
  createReadStream(target).pipe(response);
}).listen(port, () => {
  console.log(`Serving apps/web at http://localhost:${port}`);
});
