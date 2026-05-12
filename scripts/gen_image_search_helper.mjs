/**
 * 產生「圖片搜尋輔助」HTML：每列一鍵開 Google / DuckDuckGo 圖片搜尋，
 * 你在結果裡右鍵「複製圖片網址」後貼回 shop_seed_json.dart 的 imgURL: 即可。
 *
 * 使用：node scripts/gen_image_search_helper.mjs
 * 輸出：lib/features/shop/data/image_search_helper.html
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const SEED_PATH = path.join(ROOT, 'lib/features/shop/data/shop_seed_json.dart');
const OUT_PATH = path.join(ROOT, 'lib/features/shop/data/image_search_helper.html');

function extractDartInner(text) {
  const m = text.match(/shopSeedCometText = r'''([\s\S]*?)''';/);
  return m ? m[1] : null;
}

function parseBlocks(inner) {
  return inner.split(/\n\n/).map((raw) => {
    const lines = raw.split(/\n/).map((l) => l.replace(/\r/g, ''));
    if (!lines.length || !lines[0].trim()) return null;
    const titleLine =
      lines.find((l) => l.trim().startsWith('【')) || lines[0].trim();
    let productId = null;
    for (const line of lines) {
      const mm = line.match(/\/product\/(\d+)/);
      if (mm) {
        productId = mm[1];
        break;
      }
    }
    const imgLine = lines.find((l) => l.trim().startsWith('imgURL:'));
    const imgEmpty =
      imgLine &&
      !imgLine.includes('http://') &&
      !imgLine.includes('https://');
    return {
      title: titleLine.trim(),
      productId,
      imgEmpty: !!imgEmpty,
    };
  });
}

function enc(s) {
  return encodeURIComponent(s);
}

const text = fs.readFileSync(SEED_PATH, 'utf8');
const inner = extractDartInner(text);
if (!inner) {
  console.error('找不到 shopSeedCometText');
  process.exit(1);
}

const blocks = parseBlocks(inner).filter(Boolean);
const need = blocks.filter((b) => b.imgEmpty);
const allForRef = blocks.filter((b) => b.productId);

const rows = need.map((b) => {
  const q = b.title;
  const g = `https://www.google.com/search?tbm=isch&q=${enc(q)}`;
  const d = `https://duckduckgo.com/?q=${enc(q)}&iax=images&ia=images`;
  return { ...b, google: g, ddg: d };
});

const esc = (s) =>
  String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const html = `<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>柑仔店圖片搜尋輔助（${rows.length} 筆待補）</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 16px; background: #f6f7f9; }
    h1 { font-size: 1.1rem; }
    p.note { color: #444; max-width: 56rem; line-height: 1.5; }
    table { border-collapse: collapse; width: 100%; max-width: 72rem; background: #fff; }
    th, td { border: 1px solid #ddd; padding: 8px 10px; vertical-align: top; font-size: 13px; }
    th { background: #eee; text-align: left; }
    tr:nth-child(even) { background: #fafafa; }
    a { word-break: break-all; }
    .pid { color: #666; white-space: nowrap; }
  </style>
</head>
<body>
  <h1>待補圖：${rows.length} 筆（imgURL: 仍為空）</h1>
  <p class="note">
    用法：依序列點「Google 圖」或「DDG 圖」→ 在圖片上右鍵「在新分頁開啟圖片」或「複製圖片網址」→ 貼到
    <code>shop_seed_json.dart</code> 對應商品的 <code>imgURL:</code> 同一行後方（例如 <code>imgURL:https://…</code>）。
    若連結失效或版權有疑慮，請自行斟酌；僅供 demo。
  </p>
  <table>
    <thead>
      <tr><th>#</th><th>商品 id</th><th>品名</th><th>Google 圖片</th><th>DuckDuckGo 圖片</th></tr>
    </thead>
    <tbody>
${rows
  .map(
    (r, i) => `<tr>
  <td>${i + 1}</td>
  <td class="pid">${r.productId ? esc(r.productId) : '—'}</td>
  <td>${esc(r.title)}</td>
  <td><a href="${esc(r.google)}" target="_blank" rel="noopener">開啟</a></td>
  <td><a href="${esc(r.ddg)}" target="_blank" rel="noopener">開啟</a></td>
</tr>`,
  )
  .join('\n')}
    </tbody>
  </table>
  <p class="note">全檔商品筆數（含已補圖）：${allForRef.length}</p>
</body>
</html>
`;

fs.writeFileSync(OUT_PATH, html, 'utf8');
console.log(`已寫入 ${path.relative(ROOT, OUT_PATH)}（${rows.length} 列待補圖）`);
