/**
 * 爬全聯商品頁／搜尋備援取得主圖，寫入 lib/features/shop/data/product_images.json。
 * App 啟動時會自動依 product_id 與種子的連結對應覆寫圖片網址（無須手動貼種子）。
 *
 *   npm run scrape:px-images
 */
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = process.cwd();
const SEED_PATH = path.join(ROOT, 'lib/features/shop/data/shop_seed_json.dart');
const OUTPUT_PATH = path.join(ROOT, 'lib/features/shop/data/product_images.json');
const PAGE_TIMEOUT_MS = 10_000;
const CONCURRENCY = 2;

function extractProductId(url) {
  const m = url.match(/\/product\/(\d+)/);
  return m ? m[1] : null;
}

function normalizeKeyword(text) {
  if (!text) return '';
  return text
    .replace(/【[^】]*】/g, ' ')
    .replace(/\([^)]*\)/g, ' ')
    .replace(/[-_/]/g, ' ')
    .replace(/[^\u4e00-\u9fffA-Za-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .filter(Boolean)
    .slice(0, 5)
    .join(' ');
}

function readSeedEntries() {
  if (!fs.existsSync(SEED_PATH)) return [];
  const text = fs.readFileSync(SEED_PATH, 'utf8');
  const lines = text.split(/\r?\n/);
  const entries = [];
  let currentTitle = null;
  let currentUrl = null;

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith('【') || line.startsWith('蛋清分離器') || line.startsWith('地板清潔片') || line.startsWith('大公雞 ') ) {
      if (currentTitle && currentUrl) {
        entries.push({
          title: currentTitle,
          url: currentUrl,
          product_id: extractProductId(currentUrl),
        });
      }
      currentTitle = line;
      currentUrl = null;
      continue;
    }
    const m = line.match(/https:\/\/pxbox\.es\.pxmart\.com\.tw\/product\/\d+/);
    if (m && currentTitle) {
      currentUrl = m[0];
    }
  }
  if (currentTitle && currentUrl) {
    entries.push({
      title: currentTitle,
      url: currentUrl,
      product_id: extractProductId(currentUrl),
    });
  }
  // 以 title+url 去重，避免重複資料
  const seen = new Set();
  return entries.filter((e) => {
    const key = `${e.title}__${e.url}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function normalizeTitleForCompare(text) {
  return normalizeKeyword(text).replace(/\s+/g, '');
}

function titleSeemsMatching(expectedTitle, pageTitle) {
  if (!expectedTitle || !pageTitle) return false;
  const e = normalizeTitleForCompare(expectedTitle);
  const p = normalizeTitleForCompare(pageTitle);
  if (!e || !p) return false;
  return p.includes(e.slice(0, Math.min(e.length, 6))) || e.includes(p.slice(0, Math.min(p.length, 6)));
}

function isValidImageUrl(value) {
  if (!value || typeof value !== 'string') return false;
  if (value.startsWith('data:')) return false;
  return /^https?:\/\//.test(value);
}

async function firstImageBySelector(page, selector, attr = 'src') {
  const handle = await page.$(selector);
  if (!handle) return null;
  const value = await handle.getAttribute(attr);
  return isValidImageUrl(value) ? value : null;
}

async function firstImageFromSelectors(page, selectorDefs) {
  for (const def of selectorDefs) {
    const value = await firstImageBySelector(page, def.selector, def.attr || 'src');
    if (value) return value;
  }
  return null;
}

async function scrapeFromSearch(page, keyword) {
  if (!keyword) return null;
  const url = `https://pxbox.es.pxmart.com.tw/search/result?keyword=${encodeURIComponent(keyword)}`;
  await page.goto(url, { waitUntil: 'networkidle', timeout: PAGE_TIMEOUT_MS });

  return firstImageFromSelectors(page, [
    { selector: 'img[src*="b2eimg.pxec.com.tw"]' },
    { selector: '.product-card img' },
    { selector: '.swiper img' },
    { selector: 'img[src*="pxec.com.tw"]' },
  ]);
}

async function extractPageTitle(page) {
  const ogTitle = await firstImageBySelector(page, 'meta[property="og:title"]', 'content');
  if (ogTitle) return ogTitle;
  const h1 = await page.$eval('h1', (el) => el.textContent || '').catch(() => '');
  if (h1 && h1.trim()) return h1.trim();
  const title = await page.title().catch(() => '');
  return title || null;
}

async function scrapeOne(context, entry) {
  const page = await context.newPage();
  page.setDefaultTimeout(PAGE_TIMEOUT_MS);
  const productUrl = entry.url;
  const productId = entry.product_id;
  const title = entry.title || '';
  const keyword = normalizeKeyword(title);

  try {
    let pageTitle = null;
    await page.goto(productUrl, { waitUntil: 'networkidle', timeout: PAGE_TIMEOUT_MS });
    pageTitle = await extractPageTitle(page);

    const mappedCorrect = titleSeemsMatching(title, pageTitle);

    // 先抓商品頁主圖；若頁面不符或抓不到，再走搜尋頁備援。
    let imageUrl = await firstImageFromSelectors(page, [
      { selector: '#prod-detail-swiper img' },
      { selector: '.swiper img' },
      { selector: 'img[src*="b2eimg.pxec.com.tw"]' },
      { selector: 'img[src*="pxec.com.tw"]' },
      { selector: 'meta[property="og:image"]', attr: 'content' },
    ]);
    let source = imageUrl ? (mappedCorrect ? 'detail' : 'detail_unverified') : 'search';

    if (!imageUrl && keyword) {
      imageUrl = await scrapeFromSearch(page, keyword);
    }

    if (!imageUrl) {
      return {
        product_id: productId,
        product_url: productUrl,
        product_title: title || null,
        page_title: pageTitle,
        mapped_correct: mappedCorrect,
        search_keyword: keyword || null,
        image_url: null,
        ok: false,
        error: 'image_not_found',
      };
    }

    return {
      product_id: productId,
      product_url: productUrl,
      product_title: title || null,
      page_title: pageTitle,
      mapped_correct: mappedCorrect,
      search_keyword: keyword || null,
      image_url: imageUrl,
      source,
      ok: true,
      error: null,
    };
  } catch (err) {
    return {
      product_id: productId,
      product_url: productUrl,
      product_title: title || null,
      page_title: null,
      mapped_correct: false,
      search_keyword: keyword || null,
      image_url: null,
      ok: false,
      error: err && err.message ? err.message : 'unknown_error',
    };
  } finally {
    await page.close();
  }
}

async function main() {
  const entries = readSeedEntries();
  if (entries.length === 0) {
    throw new Error(`No product entries found in ${SEED_PATH}`);
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();

  const results = new Array(entries.length);
  let cursor = 0;
  let done = 0;

  async function worker() {
    while (true) {
      const idx = cursor;
      cursor += 1;
      if (idx >= entries.length) return;
      const entry = entries[idx];
      const item = await scrapeOne(context, entry);
      results[idx] = item;
      done += 1;
      // eslint-disable-next-line no-console
      console.log(`[${done}/${entries.length}] ${item.product_id || 'N/A'} ok=${item.ok} mapped=${item.mapped_correct}`);
    }
  }

  await Promise.all(Array.from({ length: CONCURRENCY }, () => worker()));

  await context.close();
  await browser.close();

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(results, null, 2), 'utf8');

  const ok = results.filter((r) => r.ok).length;
  const failed = results.length - ok;
  // eslint-disable-next-line no-console
  console.log(`Done. total=${results.length}, success=${ok}, failed=${failed}`);
  // eslint-disable-next-line no-console
  console.log(`Saved: ${OUTPUT_PATH}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
