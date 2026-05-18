# Supabase → Cloudflare R2 Daily Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up automated daily backups of Supabase (Postgres database + storage buckets) to a Cloudflare R2 bucket, orchestrated by a free GitHub Actions cron job. Restore time target: ~30 min, RPO target: 24 hours.

**Architecture:** GitHub Actions cron at 03:00 MYT (19:00 UTC) → `pg_dump` produces a single gzipped SQL snapshot AND a Node script mirrors all Supabase storage bucket files to R2. SQL snapshots kept 30 days (daily) + 12 months (monthly via `db-monthly/` prefix); bucket files kept indefinitely as a one-way live mirror. R2 lifecycle rules handle automatic deletion of old snapshots. Failures email yapwaylon@gmail.com via GitHub's default workflow-failure notifications.

**Tech Stack:** GitHub Actions (free tier, ubuntu-latest runner), `pg_dump` (PostgreSQL 15 client), Node.js 20, `@supabase/supabase-js` (already in package.json), `@aws-sdk/client-s3` (new dependency, R2 is S3-compatible), Cloudflare R2 (S3-compatible object storage with zero egress fees).

---

## File structure

| File | Purpose |
|------|---------|
| `.github/workflows/backup.yml` | GitHub Actions cron workflow — orchestrates the daily run |
| `scripts/backup-files.mjs` | Node script — mirrors all Supabase storage buckets to R2 incrementally |
| `docs/RESTORE.md` | Disaster recovery playbook — copy-paste-ready commands for restoring from backup |
| `package.json` (root, modify) | Add `@aws-sdk/client-s3` dependency |

---

## Phase 1 — User-driven setup (Waylon does — ~15 min)

These tasks must be completed BEFORE Phase 2 ships, because the workflow won't run without the secrets in place. Each task here is "click in a web dashboard" — no code.

### Task 1.1: Sign up for Cloudflare and create the R2 bucket

**Done by:** Waylon (~5 min)

- [ ] **Step 1: Sign up for Cloudflare**

Go to `https://cloudflare.com/sign-up` and create an account using `yapwaylon@gmail.com` (the same email used elsewhere, so easy to find later).

Expected: dashboard at `https://dash.cloudflare.com` loads after email verification.

- [ ] **Step 2: Enable R2**

In the Cloudflare dashboard left sidebar, click **R2 Object Storage** → click **Purchase R2 Plan**.

You will be asked to enter a payment card. This is required even for the free tier — Cloudflare won't charge unless usage exceeds the 10 GB free quota.

Expected: R2 dashboard loads showing "0 buckets".

- [ ] **Step 3: Create the bucket**

Click **Create bucket**. Fill in:
- Bucket name: `tg-farmhub-backups`
- Location: **Asia-Pacific (APAC)** (closest to Tokyo where Supabase is hosted)
- Default storage class: **Standard**

Click **Create bucket**.

Expected: redirected to the bucket detail page showing "Empty bucket — no objects".

### Task 1.2: Create an R2 API token

**Done by:** Waylon (~3 min)

- [ ] **Step 1: Open token creation page**

In the R2 dashboard left sidebar (NOT the main Cloudflare sidebar — the one inside R2), click **Manage R2 API Tokens** → **Create API token**.

- [ ] **Step 2: Configure the token**

Fill in:
- Token name: `tg-farmhub-github-backup`
- Permissions: select **Object Read & Write**
- Specify bucket(s): **Apply to specific buckets only** → select `tg-farmhub-backups`
- TTL: **Forever** (leave default)
- Client IP filtering: leave blank

Click **Create API Token**.

- [ ] **Step 3: Copy the credentials to a notepad**

The next page shows 4 values that will NEVER be shown again. Copy ALL of them now:

1. **Token value** — long alphanumeric string starting with letters
2. **Access Key ID** — looks like a long hex string
3. **Secret Access Key** — long hex string
4. **Endpoint URL** — `https://<account-id>.r2.cloudflarestorage.com/<bucket-name>` — you only need the part BEFORE `/<bucket-name>`. Paste the whole thing for now; we'll trim later.

Save these to a plain text file on your desktop temporarily (delete after Task 1.5 below).

Expected: 4 values copied. Do NOT close the page yet — read the next step first.

⚠️ **If you lose any of these values, you have to delete the token and create a new one.** Cloudflare does not show them twice.

### Task 1.3: Configure R2 lifecycle rules (auto-delete old DB snapshots)

**Done by:** Waylon (~3 min)

- [ ] **Step 1: Open lifecycle rules**

In the bucket detail page for `tg-farmhub-backups`, click **Settings** tab → scroll to **Object lifecycle rules** → click **Add rule**.

- [ ] **Step 2: Add rule for daily DB snapshots**

Fill in:
- Rule name: `delete-daily-db-after-30-days`
- Prefix: `db/`
- Action: **Delete objects after** → **30 days**
- Object age based on: **Creation date**

Click **Save**.

- [ ] **Step 3: Add rule for monthly DB snapshots**

Click **Add rule** again. Fill in:
- Rule name: `delete-monthly-db-after-365-days`
- Prefix: `db-monthly/`
- Action: **Delete objects after** → **365 days**
- Object age based on: **Creation date**

Click **Save**.

Expected: Lifecycle rules tab shows 2 active rules. Files under `files/` prefix have NO rule → they live forever (live mirror policy).

### Task 1.4: Get the Supabase DB pooler connection string

**Done by:** Waylon (~2 min)

- [ ] **Step 1: Open Supabase project settings**

Go to `https://supabase.com/dashboard/project/qwlagcriiyoflseduvvc/settings/database`.

- [ ] **Step 2: Copy the Session pooler connection string**

Scroll to **Connection string** → click the **Session pooler** tab (NOT Direct connection, NOT Transaction pooler — Session pooler).

Copy the entire string. It looks like:
```
postgresql://postgres.qwlagcriiyoflseduvvc:[YOUR-PASSWORD]@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres
```

- [ ] **Step 3: Substitute the password**

The string has `[YOUR-PASSWORD]` as a placeholder. Replace it with the actual database password (which is `Hlfqdbi6wcM4Omsm` per CLAUDE.md).

Final string:
```
postgresql://postgres.qwlagcriiyoflseduvvc:Hlfqdbi6wcM4Omsm@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres
```

Add this to your notepad alongside the R2 credentials.

Expected: a complete connection string starting with `postgresql://postgres.` and ending with `/postgres`.

### Task 1.5: Add 5 secrets to GitHub

**Done by:** Waylon (~5 min)

- [ ] **Step 1: Open GitHub repo secrets page**

Go to `https://github.com/yapwaylon-sketch/TG-Farmhub-Website/settings/secrets/actions`.

If prompted, log into GitHub.

- [ ] **Step 2: Add each secret**

Click **New repository secret** five times — once for each row below. For each: paste the **Name** exactly as shown, paste the **Value** from your notepad, click **Add secret**.

| Name (paste EXACTLY) | Value (from your notepad) |
|---|---|
| `SUPABASE_DB_URL` | The full pooler connection string from Task 1.4 |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE` |
| `R2_ENDPOINT_URL` | The endpoint URL from Task 1.2, but TRIM off the `/<bucket-name>` part. Example: `https://abc123def456.r2.cloudflarestorage.com` (NO trailing slash, NO bucket name) |
| `R2_ACCESS_KEY_ID` | From Task 1.2 |
| `R2_SECRET_ACCESS_KEY` | From Task 1.2 |

Expected: secrets page shows 5 entries listed. You cannot view their values again (GitHub design); you can only update or delete.

- [ ] **Step 3: Delete the notepad with credentials**

Now that everything is in GitHub Secrets, securely delete the plain-text notepad file from your desktop.

Expected: no plain-text credentials sitting around.

---

## Phase 2 — Code implementation (Claude writes — ~30 min)

These tasks I will execute. Each commits independently so Waylon can review per-task.

### Task 2.1: Add @aws-sdk/client-s3 dependency

**Files:**
- Modify: `package.json` (root, lines 1-8)

- [ ] **Step 1: Add the dependency entry**

Update `package.json` to add `@aws-sdk/client-s3`:

```json
{
  "dependencies": {
    "@aws-sdk/client-s3": "^3.620.0",
    "@supabase/supabase-js": "^2.103.0",
    "pg": "^8.20.0",
    "sharp": "^0.34.5",
    "xlsx": "^0.18.5"
  }
}
```

- [ ] **Step 2: Install locally to generate lockfile entries**

Run: `npm install`

Expected: `node_modules/@aws-sdk/client-s3/` appears. No errors.

- [ ] **Step 3: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore(deps): add @aws-sdk/client-s3 for R2 backup mirror"
```

Expected: one commit on `main`, branch ready for next task.

### Task 2.2: Create scripts/backup-files.mjs (storage bucket mirror)

**Files:**
- Create: `scripts/backup-files.mjs`

Script responsibilities:
1. Read env vars (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, R2_ENDPOINT_URL, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY)
2. List all storage buckets via Supabase Storage API
3. For each bucket, recursively list every file
4. For each file, HEAD-check R2 at `files/<bucket-name>/<path>` — skip if exists with same size, otherwise download from Supabase and upload to R2
5. Log per-bucket summary: total files / uploaded / skipped / errors
6. Exit code 0 on full success, 1 on any error

- [ ] **Step 1: Write the script**

Create `scripts/backup-files.mjs` with this content:

```javascript
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
```

- [ ] **Step 2: Lint-check the file**

Run: `node --check scripts/backup-files.mjs`

Expected: no output (syntactically valid).

- [ ] **Step 3: Commit**

```bash
git add scripts/backup-files.mjs
git commit -m "feat(backup): add storage bucket mirror script for R2"
```

### Task 2.3: Create the GitHub Actions workflow

**Files:**
- Create: `.github/workflows/backup.yml`

- [ ] **Step 1: Create the directory and file**

Create `.github/workflows/backup.yml` with this content:

```yaml
name: TG Farmhub Daily Backup

on:
  schedule:
    # 03:00 Malaysia time = 19:00 UTC the previous day
    - cron: '0 19 * * *'
  workflow_dispatch: # allow manual trigger from Actions tab

concurrency:
  group: backup
  cancel-in-progress: false

permissions:
  contents: read

env:
  # Public Supabase URL (not secret — already exposed in shared.js)
  SUPABASE_URL: https://qwlagcriiyoflseduvvc.supabase.co
  R2_BUCKET: tg-farmhub-backups

jobs:
  backup:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set date variables (Malaysia time)
        id: date
        run: |
          TODAY=$(TZ=Asia/Kuala_Lumpur date +%Y-%m-%d)
          YEAR_MONTH=$(TZ=Asia/Kuala_Lumpur date +%Y-%m)
          TODAY_DOM=$(TZ=Asia/Kuala_Lumpur date +%d)
          LAST_DOM=$(TZ=Asia/Kuala_Lumpur date -d "$(TZ=Asia/Kuala_Lumpur date +%Y-%m-01) +1 month -1 day" +%d)
          if [ "$TODAY_DOM" = "$LAST_DOM" ]; then IS_LAST=true; else IS_LAST=false; fi
          echo "today=$TODAY" >> "$GITHUB_OUTPUT"
          echo "year_month=$YEAR_MONTH" >> "$GITHUB_OUTPUT"
          echo "is_last_day=$IS_LAST" >> "$GITHUB_OUTPUT"
          echo "Today (MYT): $TODAY  |  Year-Month: $YEAR_MONTH  |  Last day of month: $IS_LAST"

      - name: Install PostgreSQL 15 client (for pg_dump)
        run: |
          sudo install -d /usr/share/postgresql-common/pgdg
          sudo curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
          sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
          sudo apt-get update
          sudo apt-get install -y postgresql-client-15

      - name: Dump database
        env:
          SUPABASE_DB_URL: ${{ secrets.SUPABASE_DB_URL }}
          TODAY: ${{ steps.date.outputs.today }}
        run: |
          set -euo pipefail
          DUMP_FILE="db-${TODAY}.sql.gz"
          pg_dump "${SUPABASE_DB_URL}" \
            --no-owner \
            --no-acl \
            --schema=public \
            --format=plain \
            --quote-all-identifiers \
            | gzip > "${DUMP_FILE}"
          SIZE=$(stat -c%s "${DUMP_FILE}")
          echo "Dump size: ${SIZE} bytes ($((SIZE / 1024 / 1024)) MB)"
          if [ "${SIZE}" -lt 1048576 ]; then
            echo "::error::Dump file too small (${SIZE} bytes < 1 MB) — likely pg_dump failure. Aborting."
            exit 1
          fi
          echo "DUMP_FILE=${DUMP_FILE}" >> "$GITHUB_ENV"

      - name: Upload daily DB dump to R2
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: auto
          R2_ENDPOINT_URL: ${{ secrets.R2_ENDPOINT_URL }}
          TODAY: ${{ steps.date.outputs.today }}
        run: |
          set -euo pipefail
          aws s3 cp "${DUMP_FILE}" \
            "s3://${R2_BUCKET}/db/${TODAY}.sql.gz" \
            --endpoint-url "${R2_ENDPOINT_URL}"
          echo "Daily dump uploaded: db/${TODAY}.sql.gz"

      - name: Upload monthly DB dump to R2 (only on last day of month)
        if: steps.date.outputs.is_last_day == 'true'
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: auto
          R2_ENDPOINT_URL: ${{ secrets.R2_ENDPOINT_URL }}
          YEAR_MONTH: ${{ steps.date.outputs.year_month }}
        run: |
          set -euo pipefail
          aws s3 cp "${DUMP_FILE}" \
            "s3://${R2_BUCKET}/db-monthly/${YEAR_MONTH}.sql.gz" \
            --endpoint-url "${R2_ENDPOINT_URL}"
          echo "Monthly dump uploaded: db-monthly/${YEAR_MONTH}.sql.gz"

      - name: Verify daily dump landed on R2
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: auto
          R2_ENDPOINT_URL: ${{ secrets.R2_ENDPOINT_URL }}
          TODAY: ${{ steps.date.outputs.today }}
        run: |
          set -euo pipefail
          REMOTE_SIZE=$(aws s3api head-object \
            --bucket "${R2_BUCKET}" \
            --key "db/${TODAY}.sql.gz" \
            --endpoint-url "${R2_ENDPOINT_URL}" \
            --query 'ContentLength' --output text)
          LOCAL_SIZE=$(stat -c%s "${DUMP_FILE}")
          if [ "${REMOTE_SIZE}" != "${LOCAL_SIZE}" ]; then
            echo "::error::Size mismatch — local=${LOCAL_SIZE} remote=${REMOTE_SIZE}"
            exit 1
          fi
          echo "Size verified: ${REMOTE_SIZE} bytes"

      - name: Setup Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install Node dependencies
        run: npm ci

      - name: Mirror Supabase Storage buckets to R2
        env:
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
          R2_ENDPOINT_URL: ${{ secrets.R2_ENDPOINT_URL }}
          R2_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          R2_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
        run: node scripts/backup-files.mjs

      - name: Summary
        if: always()
        env:
          TODAY: ${{ steps.date.outputs.today }}
          IS_LAST: ${{ steps.date.outputs.is_last_day }}
        run: |
          echo "=== Backup Summary ==="
          echo "Date (MYT):     ${TODAY}"
          echo "Monthly saved:  ${IS_LAST}"
          echo "Status:         ${{ job.status }}"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/backup.yml
git commit -m "feat(backup): add daily GitHub Actions backup workflow

Daily at 03:00 MYT (19:00 UTC):
- pg_dump public schema → R2 db/YYYY-MM-DD.sql.gz (30-day retention via R2 lifecycle)
- Last day of month: also → R2 db-monthly/YYYY-MM.sql.gz (12-month retention)
- Storage buckets → live-mirrored to R2 files/<bucket>/<path>

Fails loudly on dump <1 MB, R2 upload size mismatch, or any storage error.
GitHub emails yapwaylon@gmail.com on workflow failure."
```

### Task 2.4: Create the restore playbook

**Files:**
- Create: `docs/RESTORE.md`

- [ ] **Step 1: Write RESTORE.md**

Create `docs/RESTORE.md` with this content:

````markdown
# TG Farmhub Restore Playbook

**When to read this:** Supabase is broken, corrupted, wiped, or you've been locked out. You need to restore the site to a working state.

**Time budget:** ~30 minutes from "oh no" to "website running again."
**Data loss:** at most 1 day (since the last 03:00 MYT backup).

---

## Prerequisites

You need installed on your PC:

- `aws` CLI (Windows: `winget install Amazon.AWSCLI`)
- `psql` (Windows: install PostgreSQL 15+ from postgresql.org, or use `winget install PostgreSQL.PostgreSQL`)
- `rclone` (optional, for fast file restore: `winget install Rclone.Rclone`)

You also need the 5 secrets that were saved to GitHub Secrets (Phase 1, Task 1.5). For restore, dig them out of GitHub:
- GitHub repo → Settings → Secrets and variables → Actions → click each secret → unfortunately GitHub does NOT show values, only edit. So you need a backup of these somewhere. **TODO during quarterly drill: confirm we have an offline copy of these credentials in a password manager.**

---

## Scenario A: Full restore (Supabase is gone or wiped)

### Step 1 — Take site into maintenance mode (1 min)

In `netlify/functions/` or by env var, set a "maintenance" flag. Easiest: in Netlify dashboard → Site configuration → Environment variables → add `MAINTENANCE_MODE=1` → redeploy.

(If a maintenance flag is not wired in, just skip — broken Supabase URL means the site will error gracefully. Customers see white-screen instead of maintenance banner.)

### Step 2 — Download the latest DB dump from R2 (3 min)

Configure AWS CLI for R2 (one-time per machine):

```powershell
aws configure --profile r2
# AWS Access Key ID:     <R2_ACCESS_KEY_ID from GitHub Secrets>
# AWS Secret Access Key: <R2_SECRET_ACCESS_KEY from GitHub Secrets>
# Default region:        auto
# Default output format: json
```

List recent dumps:

```powershell
aws s3 ls s3://tg-farmhub-backups/db/ --endpoint-url https://<your-r2-endpoint>.r2.cloudflarestorage.com --profile r2
```

Download the most recent:

```powershell
aws s3 cp s3://tg-farmhub-backups/db/2026-05-18.sql.gz . --endpoint-url https://<your-r2-endpoint>.r2.cloudflarestorage.com --profile r2
```

### Step 3 — Create a fresh Supabase project (5 min)

1. `https://supabase.com/dashboard` → **New Project**
2. Organization: same one as before
3. Name: `tg-farmhub-prod-v2` (or whatever makes sense)
4. Database password: generate a new one, save to your password manager
5. Region: **ap-northeast-1 (Tokyo)** — same as original for low-latency restore
6. Pricing: **Pro** ($25/month — required for the storage capacity and daily backups going forward)
7. Click **Create new project**
8. Wait ~2 min for provisioning

Once ready, copy from the dashboard:
- Project URL (looks like `https://abcdefghijklm.supabase.co`)
- `anon` API key (Settings → API → `anon public`)
- `service_role` API key (Settings → API → `service_role`)
- Database password (the one you just set)

### Step 4 — Restore the database (5 min)

Decompress the dump:

```powershell
gzip -d 2026-05-18.sql.gz
```

Get the new project's session pooler connection string from Supabase dashboard → Settings → Database → Connection string → Session pooler. It will look like:

```
postgresql://postgres.<new-project-ref>:[YOUR-PASSWORD]@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres
```

Replace `[YOUR-PASSWORD]` with the password you set in Step 3.

Restore:

```powershell
psql "postgresql://postgres.<new-project-ref>:<password>@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres" -f 2026-05-18.sql
```

Expected output: many lines of `CREATE TABLE`, `ALTER TABLE`, `CREATE INDEX`, `CREATE FUNCTION`, `CREATE POLICY`, ending with `psql: completed`.

If you see `ERROR: extension "..." does not exist`: install the extension in the new project via Supabase dashboard → Database → Extensions, then re-run psql.

### Step 5 — Reconnect Google OAuth (5 min)

1. New Supabase project → **Authentication** → **Providers** → **Google** → toggle ON
2. In another tab, go to `https://console.cloud.google.com` → APIs & Services → Credentials → find the OAuth 2.0 Client ID `TG Farmhub` (existing)
3. Copy the **Client ID** and **Client Secret** → paste into Supabase Google provider config
4. Note the Supabase **callback URL** shown on the same page (e.g. `https://<new-project-ref>.supabase.co/auth/v1/callback`)
5. Back in Google Cloud Console → click your OAuth client → under **Authorized redirect URIs** → add the new callback URL
6. Save in both places

### Step 6 — Restore storage files (10 min)

Option A — via rclone (fastest, recommended):

Configure rclone for R2 (one-time):

```powershell
rclone config
# n) New remote
# name: r2
# Storage: s3
# provider: Cloudflare
# access_key_id: <R2_ACCESS_KEY_ID>
# secret_access_key: <R2_SECRET_ACCESS_KEY>
# region: auto
# endpoint: https://<your-r2-endpoint>.r2.cloudflarestorage.com
```

Configure rclone for the new Supabase storage (one-time):

```powershell
rclone config
# n) New remote
# name: supabase
# Storage: s3
# provider: Other
# access_key_id: <new project SERVICE_ROLE_KEY>
# secret_access_key: <same>
# endpoint: https://<new-project-ref>.supabase.co/storage/v1
```

Then for each bucket (sales-photos, oilpalm-photos, tender-documents):

```powershell
# First create the bucket in Supabase dashboard → Storage → New bucket
# Set "public: true" if the original was public
rclone copy r2:tg-farmhub-backups/files/sales-photos/ supabase:sales-photos/
rclone copy r2:tg-farmhub-backups/files/oilpalm-photos/ supabase:oilpalm-photos/
rclone copy r2:tg-farmhub-backups/files/tender-documents/ supabase:tender-documents/
```

Option B — point app at R2 directly (advanced, skip for first restore): rewrite the storage URLs in shared.js to point to R2 instead. Defer until app is back up.

Don't forget storage RLS policies — they were dumped with the public schema. Verify each bucket has its `<bucket>_all` policy on `storage.objects`:

```sql
SELECT * FROM pg_policies WHERE schemaname = 'storage';
```

If missing, recreate per the patterns in CLAUDE.md (e.g. `sales_photos_all`, `oilpalm_photos_all`, `tender-documents` policy).

### Step 7 — Update app config and deploy (5 min)

Edit `shared.js`:

```javascript
const SUPABASE_URL = "https://<new-project-ref>.supabase.co";
const SUPABASE_KEY = "<new anon key>";
```

Commit and push:

```bash
git add shared.js
git commit -m "ops(restore): repoint to new Supabase project after restore"
git push origin main
```

Netlify auto-deploys in ~2 min. If you used `MAINTENANCE_MODE` in Step 1, remove the env var and redeploy.

### Step 8 — Smoke test (3 min)

Open tgfarmhub.com:

1. Log in with admin PIN (the PIN hashes restored from the dump)
2. Open Sales → Orders → verify recent orders are visible
3. Open Sales → Customers → click one with photos → verify image renders (this tests storage restoration)
4. Open Oil Palm Growth → check a batch's procurement docs
5. Open Tender → Documents → click one to verify PDF opens

All good? You're done. Update CLAUDE.md to record the restoration date + new project ref.

---

## Scenario B: Partial restore (recover a specific table from N days ago)

Use case: "I accidentally cancelled invoice INV050 last week, can I see what it looked like before?"

1. Download the dump from N days ago (Step 2 above, change the filename)
2. Spin up a **temporary** Postgres database somewhere — easiest is a local Docker container:

   ```powershell
   docker run -d --name pg-restore -e POSTGRES_PASSWORD=temp -p 5432:5432 postgres:15
   gzip -d 2026-05-10.sql.gz
   psql "postgresql://postgres:temp@localhost:5432/postgres" -f 2026-05-10.sql
   ```

3. Inspect the specific row(s) you need:

   ```sql
   SELECT * FROM sales_invoices WHERE id = 'AF-INV050';
   SELECT * FROM sales_invoice_items WHERE invoice_id = 'AF-INV050';
   ```

4. Manually copy values back into the live Supabase via SQL Editor or the existing app.

5. Tear down: `docker rm -f pg-restore`

---

## Scenario C: Single file accidentally deleted from Supabase storage

Use case: "Driver deleted a delivery photo by mistake."

1. Open Cloudflare R2 dashboard → `tg-farmhub-backups` → navigate to `files/<bucket>/<path>`
2. Download the file
3. Upload back into Supabase Storage via the dashboard, same path

Takes ~2 min, no SQL involved.

---

## Quarterly restore drill (do this every 3 months)

The only way to KNOW backups work is to use them. Schedule this for the first Saturday of every quarter:

1. Pick a random recent dump from R2 (e.g. last week's Tuesday)
2. Spin up a Docker Postgres container locally
3. Restore the dump (Scenario B steps 1-2)
4. Run sanity queries:
   - `SELECT COUNT(*) FROM sales_orders;`
   - `SELECT COUNT(*) FROM sales_customers;`
   - `SELECT COUNT(*) FROM oilpalm_batches;`
   - `SELECT COUNT(*) FROM tender_los;`
   - `SELECT * FROM pg_policies WHERE schemaname = 'public' LIMIT 5;`  -- RLS policies present?
5. Confirm numbers look reasonable
6. Tear down the container
7. Log the drill in CLAUDE.md changelog

If any sanity check fails — flag it immediately, we'll dig into why.

---

## Cost notes

- New Supabase project (post-restore): $25/month Pro plan
- R2 storage: free up to 10 GB, then $0.015/GB-month
- R2 egress during restore: $0 (Cloudflare doesn't charge egress)
- Quarterly drill (Docker container): $0 (local)

A full restore costs nothing extra beyond your normal monthly bills.
````

- [ ] **Step 2: Commit**

```bash
git add docs/RESTORE.md
git commit -m "docs(backup): add disaster recovery playbook

Three scenarios covered:
- A: Full restore from R2 to a fresh Supabase project (~30 min)
- B: Partial restore (one table from N days ago, via local Docker)
- C: Single deleted file (~2 min, R2 dashboard)

Includes quarterly drill procedure for proving backups actually work."
```

### Task 2.5: Push the implementation to main

- [ ] **Step 1: Push commits**

```bash
git push origin main
```

Expected: 4 new commits on `origin/main`: AWS SDK dep, mirror script, workflow, RESTORE.md.

---

## Phase 3 — First-run verification (together — ~15 min)

After Phase 1 (Waylon's secrets) AND Phase 2 (Claude's code) are both done, kick the tires.

### Task 3.1: Trigger the workflow manually

**Done by:** Waylon (~2 min)

- [ ] **Step 1: Open the Actions tab**

Go to `https://github.com/yapwaylon-sketch/TG-Farmhub-Website/actions`.

- [ ] **Step 2: Run the workflow**

In the left sidebar, click **TG Farmhub Daily Backup** → click **Run workflow** button (top right of the runs list) → select branch `main` → click the green **Run workflow** button in the popup.

Expected: a new run appears at the top of the list, status spinning yellow.

- [ ] **Step 3: Wait for completion**

Click into the run. Watch the steps execute. Total time ~3-7 min depending on bucket sizes.

Expected: all steps end with green checkmarks. Workflow status: ✅ Success.

If any step fails red: click into that step, read the error log, paste to Claude for diagnosis.

### Task 3.2: Verify the dump on R2

**Done by:** Waylon, with Claude checking (~5 min)

- [ ] **Step 1: Open the R2 bucket**

Cloudflare dashboard → R2 → `tg-farmhub-backups` → browse.

- [ ] **Step 2: Confirm folder structure**

Expected:
- `db/` folder exists, contains `2026-05-18.sql.gz` (today's date)
- `files/` folder exists, contains subfolders: `sales-photos/`, `oilpalm-photos/`, `tender-documents/` (matching your current Supabase buckets)
- `db-monthly/` may or may not exist (only created if today happens to be the last day of the month)

- [ ] **Step 3: Spot-check sizes**

- Click `db/2026-05-18.sql.gz` → check size > 1 MB
- Navigate to `files/sales-photos/` → pick any photo → check it's a reasonable size (~100-500 KB) and the filename looks sensible

### Task 3.3: Smoke-test the dump file is valid

**Done by:** Claude, optional but recommended (~5 min)

- [ ] **Step 1: Download today's dump from R2 to local PC**

```powershell
aws s3 cp s3://tg-farmhub-backups/db/2026-05-18.sql.gz . --endpoint-url https://<r2-endpoint> --profile r2
```

- [ ] **Step 2: Verify gzip integrity**

```powershell
gzip -t db-2026-05-18.sql.gz
```

Expected: no output, exit code 0. If corrupt: prints "invalid compressed data".

- [ ] **Step 3: Peek at the SQL header**

```powershell
gzip -dc db-2026-05-18.sql.gz | head -50
```

Expected: top lines look like `-- PostgreSQL database dump`, then a bunch of `SET ...` commands, then `CREATE SCHEMA public`, then table definitions.

If those look right, the dump is valid. Delete the local file.

### Task 3.4: Confirm the daily schedule will fire

**Done by:** Waylon (~1 min)

- [ ] **Step 1: Verify the cron schedule**

On the workflow page in Actions tab, look at the **Schedule** section in the right sidebar. It should say next run is at the next 19:00 UTC (= 03:00 MYT).

If no schedule shown: confirm `.github/workflows/backup.yml` has the `schedule:` block intact and was merged to `main`.

### Task 3.5: Add quarterly drill reminder to CLAUDE.md

**Done by:** Claude (~2 min)

- [ ] **Step 1: Update CLAUDE.md "Blueprint — What's Next" section**

Add a line under the Blueprint section:

```markdown
- [ ] **Quarterly restore drill** — first one ~2026-08-18 (3 months after backup ships). See `docs/RESTORE.md` "Quarterly restore drill" section. Repeat every 3 months.
```

Also add to the "Tech Debt" section (as a completed item):

```markdown
- [x] **Off-Supabase backup to Cloudflare R2** (2026-05-18): Daily GitHub Actions cron at 03:00 MYT runs `pg_dump --schema=public` + storage-bucket mirror to `tg-farmhub-backups` R2 bucket. 30-day daily DB retention + 12-month monthly snapshots via R2 lifecycle rules. Files live-mirrored never-deleted. ~$0/month (free tier). Playbook at `docs/RESTORE.md`.
```

- [ ] **Step 2: Commit and push**

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): record backup-to-R2 setup + quarterly drill schedule"
git push origin main
```

---

## Self-review checklist (Claude runs after writing the plan, before handoff)

- [ ] All five GitHub secrets have a value source (Task 1.5 lists each one's origin)
- [ ] The pg_dump command excludes ownership/ACL (safe to restore to a different project)
- [ ] Date formatting uses Asia/Kuala_Lumpur consistently (cron is UTC but file names are MYT)
- [ ] R2 lifecycle rules cover both `db/` and `db-monthly/` prefixes; `files/` has no rule (intentional)
- [ ] backup-files.mjs is idempotent (re-running skips already-uploaded files)
- [ ] backup-files.mjs handles pagination (Supabase storage list has limit + offset)
- [ ] Workflow exits non-zero on any failure → GitHub emails on failure (default behaviour, no extra setup)
- [ ] RESTORE.md covers all 3 scenarios: full, partial, single-file
- [ ] Quarterly drill is scheduled (CLAUDE.md update in Task 3.5)
- [ ] No mention of `tgfarmhub_company` filter on `id_counters` or other no-company_id tables (not relevant here, but good to check we didn't introduce one)

---

## Out of scope (deferred — see design discussion in conversation 2026-05-18)

- Hot standby (second live Supabase project)
- Multi-region (R2 is already global; not adding a third destination)
- Real-time / replication slots
- App-side encryption-at-rest beyond what R2 provides
- Backup of Netlify deploy history / Cloudflare DNS (re-creatable from git + manual config)
- Automated restore testing (replaced by manual quarterly drill — more reliable)
- "Backup Now" button in the hub UI
- Mirroring git repo to GitLab (low priority, easy to add later)
