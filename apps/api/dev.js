import { createServer } from 'node:http';
const routes = new Set(['state', 'trade', 'quote', 'fundamentals', 'lesson', 'revenuecat', 'account']);
createServer(async (req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname.split('/').pop();
  if (!routes.has(path)) { res.writeHead(404); res.end(); return; }
  try {
    const module = await import(`./api/${path}.js`);
    const handler = module[req.method];
    if (!handler) { res.writeHead(405); res.end(); return; }
    let raw = '';
    for await (const chunk of req) { raw += chunk; if (raw.length > 16384) { res.writeHead(413); res.end(); return; } }
    const request = new Request(`http://localhost:3000${req.url}`, { method: req.method, headers: req.headers, ...(['GET', 'HEAD'].includes(req.method) ? {} : { body: raw }) });
    const response = await handler(request);
    res.writeHead(response.status, Object.fromEntries(response.headers)); res.end(await response.text());
  } catch { res.writeHead(500); res.end(); }
}).listen(3000, '127.0.0.1', () => console.log('Empezar API: http://localhost:3000 (use node --env-file=.env dev.js)'));
