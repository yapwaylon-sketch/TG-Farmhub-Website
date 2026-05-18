// scripts/backup-files.mjs
// Mirrors every Supabase Storage bucket file to Cloudflare R2 under files/<bucket>/<path>.
// Run from GitHub Actions daily; safe to re-run any time (idempotent — only uploads new/changed files).
// Required env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, R2_ENDPOINT_URL, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET.

import { createClient } from '@supabase/supabase-js';
import { S3Client, HeadObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';

const {
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
  R2_ENDPOINT_URL,
  R2_ACCESS_KEY_ID,
  R2_SECRET_ACCESS_KEY,
  R2_BUCKET,
} = process.env;

for (const [name, val] of Object.entries({ SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, R2_ENDPOINT_URL, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET })) {
  if (!val) { console.error(`Missing env: ${name}`); process.exit(1); }
}

const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const r2 = new S3Client({
  region: 'auto',
  endpoint: R2_ENDPOINT_URL,
  credentials: { accessKeyId: R2_ACCESS_KEY_ID, secretAccessKey: R2_SECRET_ACCESS_KEY },
});

// Recursively list every file in a bucket. Supabase storage list() returns folders (no metadata) + files (with metadata).
async function listAllFiles(bucket, prefix = '') {
  const out = [];
  let offset = 0;
  const limit = 1000;
  for (;;) {
    const { data, error } = await sb.storage.from(bucket).list(prefix, { limit, offset, sortBy: { column: 'name', order: 'asc' } });
    if (error) throw new Error(`list ${bucket}/${prefix}: ${error.message}`);
    if (!data || data.length === 0) break;
    for (const item of data) {
      const fullPath = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.metadata) {
        // File
        out.push({ path: fullPath, size: item.metadata.size });
      } else {
        // Folder — recurse
        const nested = await listAllFiles(bucket, fullPath);
        out.push(...nested);
      }
    }
    if (data.length < limit) break;
    offset += limit;
  }
  return out;
}

// HEAD on R2; returns { exists: bool, size: number | null }
async function r2Head(key) {
  try {
    const res = await r2.send(new HeadObjectCommand({ Bucket: R2_BUCKET, Key: key }));
    return { exists: true, size: res.ContentLength };
  } catch (err) {
    if (err.$metadata?.httpStatusCode === 404 || err.name === 'NotFound') return { exists: false, size: null };
    throw err;
  }
}

async function uploadToR2(key, body, contentType) {
  await r2.send(new PutObjectCommand({ Bucket: R2_BUCKET, Key: key, Body: body, ContentType: contentType || 'application/octet-stream' }));
}

async function mirrorBucket(bucket) {
  console.log(`\n=== bucket: ${bucket} ===`);
  const files = await listAllFiles(bucket);
  let uploaded = 0, skipped = 0, errors = 0, bytesUploaded = 0;
  for (const f of files) {
    const r2Key = `files/${bucket}/${f.path}`;
    try {
      const head = await r2Head(r2Key);
      if (head.exists && head.size === f.size) { skipped++; continue; }
      const { data, error } = await sb.storage.from(bucket).download(f.path);
      if (error) throw new Error(`download ${f.path}: ${error.message}`);
      const buffer = Buffer.from(await data.arrayBuffer());
      // Best-effort content-type — fall back to octet-stream
      await uploadToR2(r2Key, buffer, data.type);
      uploaded++;
      bytesUploaded += buffer.length;
    } catch (err) {
      errors++;
      console.error(`  ERROR ${f.path}: ${err.message}`);
    }
  }
  console.log(`  files: ${files.length} | uploaded: ${uploaded} (${(bytesUploaded / 1024 / 1024).toFixed(2)} MB) | skipped: ${skipped} | errors: ${errors}`);
  return { uploaded, skipped, errors };
}

async function main() {
  const { data: buckets, error } = await sb.storage.listBuckets();
  if (error) { console.error(`listBuckets: ${error.message}`); process.exit(1); }
  console.log(`Found ${buckets.length} buckets: ${buckets.map(b => b.name).join(', ')}`);

  let totalErrors = 0;
  for (const b of buckets) {
    const { errors } = await mirrorBucket(b.name);
    totalErrors += errors;
  }

  console.log(`\nDone. Total errors: ${totalErrors}`);
  process.exit(totalErrors > 0 ? 1 : 0);
}

main().catch(err => { console.error('FATAL:', err); process.exit(1); });
