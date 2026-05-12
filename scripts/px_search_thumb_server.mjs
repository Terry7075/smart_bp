/**
 * 全聯「搜尋結果」第一張商品縮圖 API（給 Flutter Demo 用）。
 *
 * 使用者點「全聯搜尋」會開外部瀏覽器——無法把圖傳回 App；此服務用相同關鍵字在伺服器端開 Playwright，
 * 抓搜尋頁上的主圖 URL，再讓前端 Image.network 顯示。
 *
 *   npm run shop:px-search-thumb
 *
 *   GET http://127.0.0.1:8790/px-search-thumb?keyword=一匙靈%20洗衣精
 *   → { "ok": true, "image_url": "https://b2eimg..." }
 *
 * 可選：`product_id`（全聯 `/product/{id}` 數字）— 搜尋結果中優先使用該 SKU 連結的主圖，同系列不同口味較不易撞到同一張圖。
 *
 * 限制：僅供本機／私有 Demo；頻繁請求可能觸發防爬。
 */
import http from 'node:http';
import { URL } from 'node:url';
import { chromium } from 'playwright';

const PORT = Number(process.env.PX_SEARCH_THUMB_PORT || 8790);
const WAIT_AFTER_LOAD_MS = 2600;
const SEARCH_TIMEOUT_MS = 32_000;

/** @type {import('playwright').Browser | null} */
let browser = null;

/** 序列化請求，避免同時開太多分頁 */
let chain = Promise.resolve();

/**
 * @param {() => Promise<void>} task
 */
function runQueued(task) {
  const next = chain.then(task, task);
  chain = next.catch(() => {});
  return next;
}

async function ensureBrowser() {
  // Playwright 的 browser 可能因為暫時性錯誤被關閉；此時要自動重開，
  // 否則後續請求會一直回 "Target page, context or browser has been closed"。
  if (browser) {
    try {
      if (!browser.isConnected()) browser = null;
    } catch {
      browser = null;
    }
  }
  if (!browser) {
    // 用本機已安裝的 Chrome，避免 Playwright browser binaries 缺失／架構不符造成無圖。
    browser = await chromium.launch({ headless: true, channel: 'chrome' });
  }
  return browser;
}

/**
 * @param {import('playwright').Page} page
 * @param {string} preferPid
 * @returns {Promise<string | null>}
 */
async function evaluateSearchThumb(page, preferPid) {
  return page.evaluate((pid) => {
    /**
     * @param {HTMLImageElement} el
     */
    function imgCandidates(el) {
      const raw =
        el.currentSrc ||
        el.src ||
        el.getAttribute('data-src') ||
        el.getAttribute('data-original') ||
        el.getAttribute('data-lazy-src') ||
        '';
      return typeof raw === 'string' ? raw.trim() : '';
    }

    /**
     * @param {HTMLAnchorElement} anchor
     */
    function pickImgFromProductAnchor(anchor) {
      const candidates = [];
      anchor.querySelectorAll('img').forEach((i) => candidates.push(i));
      const card =
        anchor.closest('[class*="product"], [class*="Product"], li, article') ||
        anchor.parentElement?.parentElement;
      if (card) {
        card.querySelectorAll('img').forEach((i) => {
          if (!candidates.includes(i)) candidates.push(i);
        });
      }
      for (const img of candidates) {
        const el = /** @type {HTMLImageElement} */ (img);
        const s = imgCandidates(el);
        if (!s.startsWith('http') || s.startsWith('data:')) continue;
        if (/logo|icon|avatar|banner|header|promo|badge|sprite/i.test(s)) continue;
        const w = el.naturalWidth || el.width || 0;
        const h = el.naturalHeight || el.height || 0;
        const pxLike =
          /b2eimg\.pxec\.com\.tw|pxec\.com\.tw|PX-PROD|\/Vendor\//i.test(s);
        // 延遲載入時常為 0×0，但仍可取 src 給前端載入
        if ((w >= 40 && h >= 40) || (pxLike && w === 0 && h === 0)) return s;
      }
      return null;
    }

    function fallbackBroad() {
      const selectors = [
        '.product-card img',
        'a[href*="/product/"] img',
        'img[src*="b2eimg.pxec.com.tw"]',
        'img[src*="pxec.com.tw"]',
      ];
      for (const sel of selectors) {
        for (const img of document.querySelectorAll(sel)) {
          const el = /** @type {HTMLImageElement} */ (img);
          const s = imgCandidates(el);
          if (!s.startsWith('http') || s.startsWith('data:')) continue;
          const w = el.naturalWidth || el.width || 0;
          const h = el.naturalHeight || el.height || 0;
          const pxLike =
            /b2eimg\.pxec\.com\.tw|pxec\.com\.tw|PX-PROD|\/Vendor\//i.test(s);
          if ((w >= 36 && h >= 36) || (pxLike && w === 0 && h === 0)) return s;
        }
      }
      return null;
    }

    const anchors = Array.from(document.querySelectorAll('a[href*="/product/"]')).filter((a) =>
      /\/product\/\d+/.test(a.getAttribute('href') || ''),
    );

    if (pid) {
      const hit = anchors.find((a) => (a.getAttribute('href') || '').includes(`/product/${pid}`));
      if (hit) {
        const u = pickImgFromProductAnchor(hit);
        if (u) return u;
      }
    }

    for (const a of anchors) {
      const u = pickImgFromProductAnchor(a);
      if (u) return u;
    }

    return fallbackBroad();
  }, preferPid || '');
}

/**
 * 搜尋無圖時，直接開商品頁抓 og:image／swiper（需有 product id）。
 * @param {import('playwright').Browser} b
 * @param {string} productId
 * @returns {Promise<string | null>}
 */
async function imageFromProductDetailPage(b, productId) {
  const id = String(productId || '').trim();
  if (!/^\d+$/.test(id)) return null;

  const context = await b.newContext({
    userAgent:
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 900 },
    locale: 'zh-TW',
  });
  const page = await context.newPage();
  page.setDefaultTimeout(SEARCH_TIMEOUT_MS);
  try {
    const url = `https://pxbox.es.pxmart.com.tw/product/${id}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: SEARCH_TIMEOUT_MS });
    await page.waitForTimeout(1800);
    return await page.evaluate(() => {
      const og = document.querySelector('meta[property="og:image"]')?.getAttribute('content');
      if (og && og.startsWith('http')) return og;
      const sel = ['#prod-detail-swiper img', '.swiper-slide img', 'img[src*="b2eimg"]', 'img[src*="pxec"]'];
      for (const s of sel) {
        const img = document.querySelector(s);
        if (!img) continue;
        const el = /** @type {HTMLImageElement} */ (img);
        const u =
          el.currentSrc ||
          el.src ||
          el.getAttribute('data-src') ||
          '';
        if (u.startsWith('http') && !u.startsWith('data:')) return u;
      }
      return null;
    });
  } catch {
    return null;
  } finally {
    await page.close();
    await context.close();
  }
}

/**
 * @param {string} keyword
 * @param {string} [preferredProductId]
 * @returns {Promise<string | null>}
 */
async function firstSearchResultImage(keyword, preferredProductId) {
  const b = await ensureBrowser();
  const pid = preferredProductId && String(preferredProductId).trim();

  const context = await b.newContext({
    userAgent:
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 900 },
    locale: 'zh-TW',
  });
  const page = await context.newPage();
  page.setDefaultTimeout(SEARCH_TIMEOUT_MS);
  try {
    const url = `https://pxbox.es.pxmart.com.tw/search/result?keyword=${encodeURIComponent(keyword)}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: SEARCH_TIMEOUT_MS });
    await page.waitForTimeout(WAIT_AFTER_LOAD_MS);
    await page.waitForSelector('a[href*="/product/"]', { timeout: 14_000 }).catch(() => {});

    if (pid) {
      const hit = page.locator(`a[href*="/product/${pid}"]`).first();
      if ((await hit.count()) > 0) await hit.scrollIntoViewIfNeeded().catch(() => {});
    } else {
      const first = page.locator('a[href*="/product/"]').first();
      if ((await first.count()) > 0) await first.scrollIntoViewIfNeeded().catch(() => {});
    }
    await page.waitForTimeout(900);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(600);

    let imageUrl = await evaluateSearchThumb(page, pid || '');
    if (!imageUrl) {
      await page.mouse.wheel(0, 700);
      await page.waitForTimeout(1100);
      imageUrl = await evaluateSearchThumb(page, pid || '');
    }

    if (!imageUrl && pid && /^\d+$/.test(pid)) {
      imageUrl = await imageFromProductDetailPage(b, pid);
    }

    return imageUrl;
  } finally {
    await page.close();
    await context.close();
  }
}

/** @type {Map<string, string | null>} */
const cache = new Map();
const CACHE_MAX = 400;

function cacheKey(keyword, productId) {
  return `${keyword.trim()}\0${productId ? String(productId).trim() : ''}`;
}

/**
 * @param {string} keyword
 * @param {string} [productId]
 */
async function thumbForKeyword(keyword, productId) {
  const k = keyword.trim();
  if (!k) return null;
  const ck = cacheKey(k, productId);
  if (cache.has(ck)) {
    return cache.get(ck) ?? null;
  }
  let img = await firstSearchResultImage(k, productId);
  if (!img) {
    img = await firstSearchResultImage(k, productId);
  }
  // 只快取成功結果，避免一度網慢／版面未完成時永遠拿不到圖
  if (img) {
    if (cache.size >= CACHE_MAX) {
      const firstKey = cache.keys().next().value;
      cache.delete(firstKey);
    }
    cache.set(ck, img);
  }
  return img;
}

const server = http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

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

  if (urlObj.pathname !== '/px-search-thumb') {
    res.writeHead(404);
    res.end('not found');
    return;
  }

  const keyword = urlObj.searchParams.get('keyword') || '';
  const productId = urlObj.searchParams.get('product_id') || '';
  if (!keyword.trim()) {
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ ok: false, image_url: null, error: 'missing keyword' }));
    return;
  }

  runQueued(async () => {
    try {
      const imageUrl = await thumbForKeyword(keyword, productId);
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify({ ok: !!imageUrl, image_url: imageUrl }));
    } catch (e) {
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(
        JSON.stringify({
          ok: false,
          image_url: null,
          error: e && e.message ? e.message : String(e),
        }),
      );
    }
  }).catch((e) => {
    if (!res.headersSent) {
      res.writeHead(500);
      res.end(String(e));
    }
  });
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`PX search thumbnail API: http://127.0.0.1:${PORT}/px-search-thumb?keyword=`);
});
