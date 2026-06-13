/**
 * Ollama CORS 代理（給 Flutter Web 用）。
 *
 *   npm run assistant:ollama-proxy
 *
 * 轉發至本機 Ollama（預設 http://127.0.0.1:11434）：
 *   GET  /api/tags
 *   POST /api/chat
 *
 * 環境變數：
 *   OLLAMA_PROXY_PORT=8791
 *   OLLAMA_UPSTREAM=http://127.0.0.1:11434
 */
import http from 'node:http';
import { URL } from 'node:url';

const PORT = Number(process.env.OLLAMA_PROXY_PORT || 8791);
const UPSTREAM = (process.env.OLLAMA_UPSTREAM || 'http://127.0.0.1:11434').replace(
  /\/+$/,
  '',
);

const ALLOWED = new Set(['/api/chat', '/api/tags']);

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

/**
 * @param {import('node:http').IncomingMessage} req
 * @returns {Promise<Buffer>}
 */
function readBody(req) {
  return new Promise((resolve, reject) => {
    /** @type {Buffer[]} */
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

/**
 * @param {import('node:http').IncomingMessage} req
 * @param {import('node:http').ServerResponse} res
 */
async function handle(req, res) {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  let pathname;
  try {
    pathname = new URL(req.url || '/', `http://127.0.0.1:${PORT}`).pathname;
  } catch {
    res.writeHead(400);
    res.end('bad request');
    return;
  }

  if (!ALLOWED.has(pathname)) {
    res.writeHead(404);
    res.end('not found');
    return;
  }

  const method = req.method === 'GET' ? 'GET' : req.method === 'POST' ? 'POST' : null;
  if (!method) {
    res.writeHead(405);
    res.end('method not allowed');
    return;
  }

  const target = `${UPSTREAM}${pathname}`;
  /** @type {RequestInit} */
  const init = { method, headers: { Accept: 'application/json' } };

  if (method === 'POST') {
    const body = await readBody(req);
    init.headers = {
      ...init.headers,
      'Content-Type': req.headers['content-type'] || 'application/json',
    };
    init.body = body;
  }

  try {
    const upstream = await fetch(target, init);
    const text = await upstream.text();
    res.writeHead(upstream.status, {
      'Content-Type': upstream.headers.get('content-type') || 'application/json',
    });
    res.end(text);
  } catch (e) {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        error: `無法連到 Ollama（${UPSTREAM}）。請先執行：ollama serve`,
        detail: String(e && e.message ? e.message : e),
      }),
    );
  }
}

const server = http.createServer((req, res) => {
  handle(req, res).catch((e) => {
    res.writeHead(500);
    res.end(String(e));
  });
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Ollama proxy http://127.0.0.1:${PORT} → ${UPSTREAM}`);
  // eslint-disable-next-line no-console
  console.log('  GET  /api/tags');
  // eslint-disable-next-line no-console
  console.log('  POST /api/chat');
});
