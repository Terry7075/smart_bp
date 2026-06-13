/**
 * 圖片跳板（伺服器向目標 URL 抓圖再回給 Flutter Web／App），略過瀏覽器 Referer/CORS。
 *
 *   IMAGE_PROXY_PORT=8788 node scripts/image_proxy_server.mjs
 *   npm run shop:image-proxy
 *
 * 端點：
 *   GET /image-proxy?url=https%3A%2F%2F…           → 直接回傳 image bytes（給 Image.network）
 *   GET /image-proxy?url=…&format=json             → JSON：mime、base64、dataUri
 *
 * 安全：預設僅允許常見台灣電商／CDN 網域；上線請改為環境變數 IMAGE_PROXY_ALLOWED_HOSTS（逗號分隔）。
 */
import http from 'node:http';
import { URL } from 'node:url';

const PORT = Number(process.env.IMAGE_PROXY_PORT || 8788);
const MAX_BYTES = 5 * 1024 * 1024;

const DEFAULT_ALLOWED = [
  'pchome.com.tw',
  'momoshop.com.tw',
  'carrefour.com.tw',
  'online.carrefour.com.tw',
  'pxec.com.tw',
  'b2eimg.pxec.com.tw',
  'pxmart.com.tw',
  'pxbox.es.pxmart.com.tw',
  'trplus.com.tw',
  'pcm3.trplus.com.tw',
  'img.pchome.com.tw',
  'cs-items.pchome.com.tw',
  'encrypted-tbn0.gstatic.com',
  'encrypted-tbn1.gstatic.com',
  'encrypted-tbn2.gstatic.com',
  'encrypted-tbn3.gstatic.com',
  'th.bing.com',
];

function hostnameAllowed(hostname) {
  const raw = process.env.IMAGE_PROXY_ALLOWED_HOSTS;
  const list = raw
    ? raw
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean)
    : DEFAULT_ALLOWED;
  return list.some((h) => hostname === h || hostname.endsWith('.' + h));
}

async function proxyFetch(targetUrl, format, res) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 15_000);
  try {
    const r = await fetch(targetUrl, {
      redirect: 'follow',
      signal: ctrl.signal,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; SmartBpImageProxy/1.0)',
        Accept: 'image/avif,image/webp,image/*,*/*;q=0.8',
      },
    });
    clearTimeout(timer);
    if (!r.ok) {
      res.writeHead(502);
      res.end(`upstream HTTP ${r.status}`);
      return;
    }
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > MAX_BYTES) {
      res.writeHead(413);
      res.end('payload too large');
      return;
    }
    let mime = r.headers.get('content-type') || 'application/octet-stream';
    mime = mime.split(';')[0].trim();

    if (format === 'json') {
      const base64 = buf.toString('base64');
      const safeMime = mime.startsWith('image/') ? mime : 'image/jpeg';
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(
        JSON.stringify({
          mime: safeMime,
          base64,
          dataUri: `data:${safeMime};base64,${base64}`,
        }),
      );
      return;
    }

    const outMime = mime.startsWith('image/') ? mime : 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': outMime,
      'Cache-Control': 'public, max-age=86400',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(buf);
  } catch (e) {
    clearTimeout(timer);
    res.writeHead(502);
    res.end(String(e && e.message ? e.message : e));
  }
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  if (req.method !== 'GET') {
    res.writeHead(405);
    res.end('method not allowed');
    return;
  }

  let urlObj;
  try {
    urlObj = new URL(req.url || '/', `http://127.0.0.1:${PORT}`);
  } catch {
    res.writeHead(400);
    res.end('bad request');
    return;
  }

  if (urlObj.pathname !== '/image-proxy') {
    res.writeHead(404);
    res.end('not found');
    return;
  }

  const target = urlObj.searchParams.get('url');
  const format = urlObj.searchParams.get('format');

  if (!target) {
    res.writeHead(400);
    res.end('missing url query');
    return;
  }

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    res.writeHead(400);
    res.end('invalid url');
    return;
  }

  if (parsed.protocol !== 'https:') {
    res.writeHead(400);
    res.end('only https URLs are allowed');
    return;
  }

  if (!hostnameAllowed(parsed.hostname)) {
    res.writeHead(403);
    res.end(`host not allowed: ${parsed.hostname}`);
    return;
  }

  proxyFetch(target, format, res);
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Image proxy listening on http://127.0.0.1:${PORT}`);
  // eslint-disable-next-line no-console
  console.log(`  GET /image-proxy?url=<encoded https URL>`);
  // eslint-disable-next-line no-console
  console.log(`  GET /image-proxy?url=…&format=json  (base64 / dataUri)`);
});
