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
