/**
 * 用 Bing／DuckDuckGo「圖片」搜尋自動抓第一張可見縮圖網址，寫回 shop_seed_json.dart
 * 裡仍為空的 imgURL:（依 /product/{id} 對應）。先 Bing，失敗再試 DDG。
 *
 * 限制：搜尋結果未必是該商品、連結可能為縮圖代理；僅作 demo，請人工抽查。
 *
 *   node scripts/fetch_ddg_images.mjs           # 只試前 5 筆（預設）
 *   node scripts/fetch_ddg_images.mjs --all     # 全部待補（耗時）
 *   node scripts/fetch_ddg_images.mjs --limit=20
 *   node scripts/fetch_ddg_images.mjs --dry-run
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const SEED_PATH = path.join(ROOT, 'lib/features/shop/data/shop_seed_json.dart');

const DELAY_AFTER_LOAD_MS = 2200;

async function tryDismissBanners(page) {
  const candidates = [
    '#bnp_btn_accept',
    'button[id="accept"]',
    '[aria-label="Accept"]',
    'button:has-text("接受")',
    'button:has-text("同意")',
    'button:has-text("Agree")',
    '[data-testid="privacy-accept"]',
  ];
  for (const sel of candidates) {
    try {
      const loc = page.locator(sel).first();
      if (await loc.isVisible({ timeout: 800 }).catch(() => false)) {
        await loc.click({ timeout: 2000 });
        await page.waitForTimeout(600);
        return;
      }
    } catch {
      /* ignore */
    }
  }
}

function isBadImageUrl(s) {
  if (!s || typeof s !== 'string' || !s.startsWith('http')) return true;
  const u = s.toLowerCase();
  if (u.startsWith('data:')) return true;
  if (u.includes('favicon')) return true;
  if (u.endsWith('.svg')) return true;
  return false;
}

async function bingFirstImageUrl(page, query) {
  const url = `https://www.bing.com/images/search?q=${encodeURIComponent(query)}&form=HDRSC2`;
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
  await tryDismissBanners(page);
  await page.waitForTimeout(DELAY_AFTER_LOAD_MS);
  return page.evaluate(() => {
    const pick = (img) => {
      const s =
        img.getAttribute('src') ||
        img.getAttribute('data-src') ||
        img.getAttribute('data-src-hi') ||
        img.currentSrc ||
        '';
      return s;
    };
    const selectors = ['img.mimg', 'a.iusc img', '.img_cont img', '.inflnk img'];
    for (const sel of selectors) {
      for (const img of document.querySelectorAll(sel)) {
        const s = pick(img);
        if (!s || !s.startsWith('http') || s.startsWith('data:')) continue;
        const w = img.naturalWidth || img.width || 0;
        const h = img.naturalHeight || img.height || 0;
        if (w >= 40 && h >= 40) return s;
      }
    }
    return null;
  });
}

function extractDartInner(text) {
  const m = text.match(/shopSeedCometText = r'''([\s\S]*?)''';/);
  return m ? { inner: m[1], full: text, start: m.index, end: m.index + m[0].length, pre: text.slice(0, m.index), match: m } : null;
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

function applyImgUrls(fullText, idToUrl) {
  const hit = extractDartInner(fullText);
  if (!hit) throw new Error('找不到 shopSeedCometText');
  const blocks = hit.inner.split('\n\n');
  const newBlocks = blocks.map((block) => {
    let pid = null;
    for (const line of block.split('\n')) {
      const mm = line.match(/\/product\/(\d+)/);
      if (mm) {
        pid = mm[1];
        break;
      }
    }
    if (!pid || !idToUrl[pid]) return block;
    return block
      .split('\n')
      .map((line) => {
        const t = line.trim();
        if (
          t === 'imgURL:' ||
          (t.startsWith('imgURL:') &&
            !line.includes('http://') &&
            !line.includes('https://'))
        ) {
          return `imgURL:${idToUrl[pid]}`;
        }
        return line;
      })
      .join('\n');
  });
  const inner2 = newBlocks.join('\n\n');
  const m = fullText.match(/(shopSeedCometText = r''')([\s\S]*?)(''';)/);
  return fullText.slice(0, m.index) + m[1] + inner2 + m[3] + fullText.slice(m.index + m[0].length);
}

async function ddgFirstImageUrl(page, query) {
  const url = `https://duckduckgo.com/?q=${encodeURIComponent(query)}&iax=images&ia=images`;
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45_000 });
  await tryDismissBanners(page);
  await page.waitForTimeout(DELAY_AFTER_LOAD_MS);
  return page.evaluate(() => {
    const bad = (s) => {
      if (!s || !s.startsWith('http')) return true;
      const u = s.toLowerCase();
      if (u.includes('duckduckgo.com')) return true;
      if (u.includes('icons.')) return true;
      if (u.endsWith('.svg')) return true;
      return false;
    };
    for (const sel of [
      '[data-testid="tile-image"] img',
      'article img',
      'li img',
      'img[src*="http"]',
    ]) {
      for (const img of document.querySelectorAll(sel)) {
        const s =
          img.getAttribute('src') ||
          img.getAttribute('data-src') ||
          img.currentSrc ||
          '';
        if (bad(s)) continue;
        const w = img.naturalWidth || img.width || 0;
        const h = img.naturalHeight || img.height || 0;
        if (w >= 60 && h >= 60) return s;
      }
    }
    return null;
  });
}

async function fetchFirstImageUrl(page, query) {
  let u = await bingFirstImageUrl(page, query).catch(() => null);
  if (u && !isBadImageUrl(u)) return u;
  u = await ddgFirstImageUrl(page, query).catch(() => null);
  if (u && !isBadImageUrl(u)) return u;
  return null;
}

function parseArgs() {
  const dry = process.argv.includes('--dry-run');
  const all = process.argv.includes('--all');
  let limit = 5;
  const limArg = process.argv.find((a) => a.startsWith('--limit='));
  if (limArg) limit = Math.max(1, parseInt(limArg.split('=')[1], 10) || 5);
  if (all) limit = 1e9;
  return { dry, limit };
}

async function main() {
  const { dry, limit } = parseArgs();
  const text = fs.readFileSync(SEED_PATH, 'utf8');
  const hit = extractDartInner(text);
  if (!hit) {
    console.error('找不到 shopSeedCometText');
    process.exit(1);
  }
  const blocks = parseBlocks(hit.inner).filter(Boolean);
  const todo = blocks.filter((b) => b.imgEmpty && b.productId).slice(0, limit);
  console.log(`待自動補圖：${todo.length} 筆${dry ? '（dry-run）' : ''}`);

  const idToUrl = {};
  if (!dry && todo.length) {
    const headful = process.env.HEADFUL === '1' || process.argv.includes('--headed');
    const browser = await chromium.launch({ headless: !headful });
    const context = await browser.newContext({
      userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      locale: 'zh-TW',
    });
    const page = await context.newPage();
    page.setDefaultNavigationTimeout(28_000);
    page.setDefaultTimeout(18_000);
    try {
      for (const row of todo) {
        process.stdout.write(`${row.productId} ${row.title.slice(0, 40)}… `);
        try {
          const u = await fetchFirstImageUrl(page, row.title);
          if (u) {
            idToUrl[row.productId] = u;
            console.log('OK');
            const latest = fs.readFileSync(SEED_PATH, 'utf8');
            fs.writeFileSync(SEED_PATH, applyImgUrls(latest, idToUrl), 'utf8');
          } else {
            console.log('（未取得）');
          }
        } catch (e) {
          console.log('ERR', e.message);
        }
        await page.waitForTimeout(800);
      }
    } finally {
      await browser.close();
    }
  } else if (dry) {
    for (const row of todo) console.log(' -', row.productId, row.title);
    return;
  }

  const n = Object.keys(idToUrl).length;
  if (n === 0) {
    console.log('沒有取得任何網址，未寫入檔案。');
    return;
  }
  if (!dry) {
    console.log(`本輪累計已寫入 ${n} 筆 imgURL（逐筆存檔）至 shop_seed_json.dart`);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
