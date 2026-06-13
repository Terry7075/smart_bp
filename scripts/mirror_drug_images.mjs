/**
 * 一次性將 drug_dictionary 的外部 image_url 鏡像到 Supabase Storage。
 *
 *   SUPABASE_URL=https://xxx.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=... \
 *   node scripts/mirror_drug_images.mjs
 *
 *   node scripts/mirror_drug_images.mjs --dry-run
 *   node scripts/mirror_drug_images.mjs --limit=10
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const OUT_DIR = path.join(__dirname, 'out');
const REPORT_PATH = path.join(OUT_DIR, 'drug_mirror_report.json');

const BUCKET = 'drug-images';
const MIRROR_PREFIX = 'mirror';
const REQUEST_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
  Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const limitArg = args.find((a) => a.startsWith('--limit='));
const limit = limitArg ? Number.parseInt(limitArg.split('=')[1], 10) : null;
const throttleMs = 300;

const supabaseUrl = (
  process.env.SUPABASE_URL ?? 'https://ntufhwqxaidwnelorcsv.supabase.co'
).replace(/\/$/, '');
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function displayName(row) {
  return (row.name_zh || row.name_en || row.id).trim();
}

function isAlreadyMirrored(imageUrl) {
  const v = (imageUrl ?? '').trim();
  return v.startsWith(`${BUCKET}/`);
}

function isExternalUrl(imageUrl) {
  const v = (imageUrl ?? '').trim();
  return v.startsWith('http://') || v.startsWith('https://');
}

function expandUrlAttempts(url) {
  const out = [];
  const seen = new Set();
  const add = (raw) => {
    const v = raw.trim();
    if (!v || seen.has(v)) return;
    seen.add(v);
    out.push(v);
    if (v.startsWith('http://')) {
      const https = `https://${v.slice(7)}`;
      if (!seen.has(https)) {
        seen.add(https);
        out.push(https);
      }
    }
  };
  add(url);
  return out;
}

function extFromContentType(contentType, url) {
  const ct = (contentType ?? '').toLowerCase();
  if (ct.includes('png')) return 'png';
  if (ct.includes('webp')) return 'webp';
  if (ct.includes('gif')) return 'gif';
  if (ct.includes('jpeg') || ct.includes('jpg')) return 'jpg';

  const m = url.match(/\.(jpe?g|png|webp|gif)(?:\?|$)/i);
  if (m) return m[1].toLowerCase().replace('jpeg', 'jpg');
  return 'jpg';
}

function mimeFromExt(ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/jpeg';
  }
}

async function fetchRows() {
  const url = `${supabaseUrl}/rest/v1/drug_dictionary?select=id,name_zh,name_en,image_url&image_url=not.is.null&order=id.asc`;
  const resp = await fetch(url, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
  });
  if (!resp.ok) {
    throw new Error(`fetch drug_dictionary failed: ${resp.status} ${await resp.text()}`);
  }
  return resp.json();
}

async function downloadImage(originalUrl) {
  const attempts = expandUrlAttempts(originalUrl);
  let lastError = 'unknown';

  for (const url of attempts) {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 15000);
      const resp = await fetch(url, {
        headers: REQUEST_HEADERS,
        redirect: 'follow',
        signal: controller.signal,
      });
      clearTimeout(timer);

      if (!resp.ok) {
        lastError = `HTTP ${resp.status}`;
        continue;
      }

      const contentType = resp.headers.get('content-type') ?? '';
      const bytes = Buffer.from(await resp.arrayBuffer());
      if (bytes.length === 0) {
        lastError = 'empty body';
        continue;
      }
      if (contentType && !contentType.toLowerCase().startsWith('image/')) {
        lastError = `not image (${contentType})`;
        continue;
      }

      const ext = extFromContentType(contentType, url);
      return {
        bytes,
        ext,
        contentType: mimeFromExt(ext),
        fetchedFrom: url,
      };
    } catch (e) {
      lastError = e?.name === 'AbortError' ? 'timeout' : String(e.message ?? e);
    }
  }

  return { error: lastError };
}

async function uploadToStorage(objectPath, bytes, contentType) {
  const url = `${supabaseUrl}/storage/v1/object/${BUCKET}/${objectPath}`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': contentType,
      'x-upsert': 'true',
    },
    body: bytes,
  });
  if (!resp.ok) {
    throw new Error(`upload failed: ${resp.status} ${await resp.text()}`);
  }
}

async function updateImageUrl(id, imageUrl) {
  const url = `${supabaseUrl}/rest/v1/drug_dictionary?id=eq.${id}`;
  const resp = await fetch(url, {
    method: 'PATCH',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({ image_url: imageUrl }),
  });
  if (!resp.ok) {
    throw new Error(`update failed: ${resp.status} ${await resp.text()}`);
  }
}

async function main() {
  if (!serviceKey) {
    console.error('Missing SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }

  console.log(`Supabase: ${supabaseUrl}`);
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'LIVE'}`);

  const allRows = await fetchRows();
  let candidates = allRows.filter(
    (r) => r.image_url && !isAlreadyMirrored(r.image_url) && isExternalUrl(r.image_url),
  );
  if (limit != null && Number.isFinite(limit)) {
    candidates = candidates.slice(0, limit);
  }

  console.log(`Total rows: ${allRows.length}, to process: ${candidates.length}`);

  const report = {
    startedAt: new Date().toISOString(),
    dryRun,
    supabaseUrl,
    totals: { mirrored: 0, failed: 0, skipped: 0 },
    mirrored: [],
    failed: [],
    skipped: [],
  };

  for (let i = 0; i < candidates.length; i++) {
    const row = candidates[i];
    const name = displayName(row);
    const oldUrl = row.image_url.trim();
    const objectPath = `${MIRROR_PREFIX}/${row.id}.jpg`;
    const storedValue = `${BUCKET}/${objectPath}`;

    process.stdout.write(`[${i + 1}/${candidates.length}] ${name} ... `);

    if (dryRun) {
      console.log('dry-run');
      report.skipped.push({ id: row.id, name, old_url: oldUrl, reason: 'dry-run' });
      report.totals.skipped++;
      continue;
    }

    const downloaded = await downloadImage(oldUrl);
    if (downloaded.error) {
      console.log(`FAIL (${downloaded.error})`);
      report.failed.push({
        id: row.id,
        name,
        old_url: oldUrl,
        reason: downloaded.error,
      });
      report.totals.failed++;
      await sleep(throttleMs);
      continue;
    }

    const ext = downloaded.ext;
    const finalObjectPath = `${MIRROR_PREFIX}/${row.id}.${ext}`;
    const finalStoredValue = `${BUCKET}/${finalObjectPath}`;

    try {
      await uploadToStorage(finalObjectPath, downloaded.bytes, downloaded.contentType);
      await updateImageUrl(row.id, finalStoredValue);
      console.log(`OK -> ${finalStoredValue}`);
      report.mirrored.push({
        id: row.id,
        name,
        old_url: oldUrl,
        new_url: finalStoredValue,
        fetched_from: downloaded.fetchedFrom,
        bytes: downloaded.bytes.length,
      });
      report.totals.mirrored++;
    } catch (e) {
      console.log(`UPLOAD/UPDATE FAIL (${e.message})`);
      report.failed.push({
        id: row.id,
        name,
        old_url: oldUrl,
        reason: e.message,
      });
      report.totals.failed++;
    }

    await sleep(throttleMs);
  }

  report.finishedAt = new Date().toISOString();
  fs.mkdirSync(OUT_DIR, { recursive: true });
  fs.writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2), 'utf8');

  console.log('\n--- Summary ---');
  console.log(`mirrored: ${report.totals.mirrored}`);
  console.log(`failed:   ${report.totals.failed}`);
  console.log(`skipped:  ${report.totals.skipped}`);
  console.log(`Report: ${REPORT_PATH}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
