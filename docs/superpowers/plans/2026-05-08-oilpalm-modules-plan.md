# Oil Palm Growth + Sales Modules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing monolithic `seedlings.html` with two focused modules — `oilpalmgrowth.html` (procurement → planting → MN → ready-for-sale) and `oilpalmsales.html` (bookings, walk-ins, collections, customer ops) — sharing a single backing schema renamed from `seedling_*` to `oilpalm_*`.

**Architecture:** Static HTML/CSS/JS modules consuming Supabase via the existing `shared.js` helpers. Two HTML files, shared backing tables. Existing `seedling_*` tables are EMPTY and will be dropped. Pattern follows the established sales/tender/seedlings module structure: sidebar tabs, single-page data sheet for entity detail, modals for create/edit actions, `confirmAction()` for confirmations, `sbUpdateWithLock()` for optimistic locking on critical paths.

**Tech Stack:** Static HTML + vanilla JS + Supabase v2.49.1 (CDN, pinned), shared.css/shared.js, Plus Jakarta Sans, light theme (cream `#FAF6EF` / plum `#2A1A3E` / gold `#D4AF37`). No build step. No test framework — verification is curl-grep + manual UI check.

**Note on TDD:** This codebase has no test harness (no jest/vitest/pytest). "Test" steps are verification steps: SQL query result checks, curl-grep on deployed HTML, or manual browser walk-through. Where unit-level logic deserves verification (formula correctness for guardrails, lifecycle stage transitions), the verification step runs the formula in a Node REPL block and asserts the expected output.

**Working directory:** `C:\dev\TG-Farmhub-Website` (main branch, no worktree per project convention).

**Deploy command** (run after each phase that ships UI):
```bash
npx netlify-cli deploy --prod --dir=. --functions=netlify/functions --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26
```

**Verification after deploy** (always):
```bash
curl -s https://tgfarmhub.com/<file>.html | grep -c '<unique-marker-from-this-phase>'
```

---

## File Map

**Created:**
- `supabase/oilpalm_migration.sql` — schema: drop old `seedling_*`, create new `oilpalm_*` (8 tables), indexes, triggers, RLS
- `oilpalmgrowth.html` — Growth module (sidebar + tabs + Batches/Suppliers/Reports + batch detail page)
- `oilpalmgrowth.css` — module-specific styles (lifecycle badges, batch detail layout)
- `oilpalmsales.html` — Sales module (sidebar + tabs + Summary/Bookings/Collections/Customers/Reports + booking detail page)
- `oilpalmsales.css` — module-specific styles (status badges, booking detail layout, L3.1 modal)
- `icons/modules/oilpalm-growth.png` — 3D clay-rendered icon (Gemini Flash, locked style anchor)

**Modified:**
- `index.html` — replace single `oilpalmseedling` MODULES entry with two entries (`oilpalmgrowth`, `oilpalmsales`); update MODULE_CATEGORIES under TG Agribusiness > Operations; update permissions panel render
- `shared.js` — update MODULE_COMPANY map (both new modules → `tg_agribusiness`)
- `CLAUDE.md` — add module sections for oil palm growth/sales; remove the seedlings module section; add changelog entry under Tech Debt

**Deleted:**
- `seedlings.html` — replaced
- `seedlings.css` — replaced
- `supabase/seedlings_migration.sql` — superseded by `oilpalm_migration.sql`
- `docs/superpowers/specs/2026-04-09-seedlings-module-design.md` — historical (kept in git history)
- `docs/superpowers/plans/2026-04-09-seedlings-module-plan.md` — historical (kept in git history)

**Storage bucket changes** (run via Supabase REST API, not in SQL migration):
- Drop bucket `seedling-photos` (empty)
- Create bucket `oilpalm-photos` (public, no MIME allowlist — must support PDF for procurement docs)

---

## Phase 0 — Migration & Storage Setup

### Task 0.1: Write SQL migration file

**Files:**
- Create: `supabase/oilpalm_migration.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- ============================================================
-- Oil Palm Modules Migration
-- Date: 2026-05-08
-- Drops: 7 seedling_* tables (empty)
-- Creates: 8 oilpalm_* tables, indexes, triggers, RLS policies
-- ============================================================

-- ============================================================
-- PART 1: DROP OLD TABLES
-- ============================================================

DROP TABLE IF EXISTS seedling_collections CASCADE;
DROP TABLE IF EXISTS seedling_payments CASCADE;
DROP TABLE IF EXISTS seedling_bookings CASCADE;
DROP TABLE IF EXISTS seedling_customers CASCADE;
DROP TABLE IF EXISTS seedling_batch_events CASCADE;
DROP TABLE IF EXISTS seedling_batches CASCADE;
DROP TABLE IF EXISTS seedling_suppliers CASCADE;

-- ============================================================
-- PART 2: CREATE NEW TABLES
-- ============================================================

-- 1. Suppliers
CREATE TABLE oilpalm_suppliers (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Batches (one row per procurement; lifecycle Ordered → Received → PN → MN → Selling → Sold Out → Closed)
CREATE TABLE oilpalm_batches (
  id TEXT PRIMARY KEY,                            -- AB-OB001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  batch_number TEXT NOT NULL,                     -- display: 1-2026, 2-2026, ...
  supplier_id TEXT REFERENCES oilpalm_suppliers(id),
  variety_id UUID REFERENCES crop_varieties(id),  -- shared crop_varieties table

  -- Procurement
  ordered_qty INT NOT NULL DEFAULT 0,
  unit_cost NUMERIC NOT NULL DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  order_date DATE,
  estimated_delivery_date DATE,
  actual_delivery_date DATE,                       -- filling this flips Ordered → Received

  -- Single payment per batch
  payment_amount NUMERIC,
  payment_date DATE,
  payment_method TEXT,                             -- cash | bank | cheque
  payment_reference TEXT,
  payment_slip_url TEXT,
  payment_notes TEXT,

  -- 5 fixed document slots
  proforma_url TEXT,
  k3_chit_url TEXT,
  airwaybill_url TEXT,
  official_invoice_url TEXT,
  phyto_cert_url TEXT,

  -- Planting / counts
  date_planted DATE,
  seeds_received INT NOT NULL DEFAULT 0,           -- arrived from supplier
  seeds_damaged INT NOT NULL DEFAULT 0,            -- damaged on arrival
  qty_planted INT NOT NULL DEFAULT 0,              -- = seeds_received - seeds_damaged
  date_transplanted DATE,
  transplant_culls INT NOT NULL DEFAULT 0,
  transplant_extras INT NOT NULL DEFAULT 0,        -- multi-germination gain
  qty_mn_start INT NOT NULL DEFAULT 0,             -- = qty_planted - transplant_culls + transplant_extras

  -- Selling-side
  default_price NUMERIC,                           -- per-batch default unit price
  bookable_pct INT NOT NULL DEFAULT 50,            -- % of qty_mn_start that's bookable (soft cap)

  -- Lifecycle
  status TEXT NOT NULL DEFAULT 'ordered',          -- ordered | received | pre_nursery | main_nursery | selling | sold_out | closed

  -- Misc
  notes TEXT,
  closed_at TIMESTAMPTZ,
  closed_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Batch events (count adjustments: plant, transplant, cull)
CREATE TABLE oilpalm_batch_events (
  id TEXT PRIMARY KEY,                             -- AB-OE001
  batch_id TEXT NOT NULL REFERENCES oilpalm_batches(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,                        -- plant | transplant | cull
  qty INT NOT NULL DEFAULT 0,                      -- delta (positive for plant/extras, negative meaning depends on event_type)
  reason TEXT,
  event_date DATE NOT NULL,
  logged_by TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Customers (booking + walk-in)
CREATE TABLE oilpalm_customers (
  id TEXT PRIMARY KEY,                             -- AB-OC001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  customer_type TEXT NOT NULL DEFAULT 'booking',   -- booking | walkin
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Bookings
CREATE TABLE oilpalm_bookings (
  id TEXT PRIMARY KEY,                             -- AB-OK001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  customer_id TEXT NOT NULL REFERENCES oilpalm_customers(id),
  batch_id TEXT NOT NULL REFERENCES oilpalm_batches(id),  -- CURRENT batch (changes on reassignment)
  booked_qty INT NOT NULL,                         -- original booking qty
  unit_price NUMERIC NOT NULL,                     -- locked-in at booking creation
  total_amount NUMERIC NOT NULL DEFAULT 0,         -- = booked_qty * unit_price
  booking_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'active',           -- active | completed | cancelled
  reassignment_history JSONB DEFAULT '[]'::jsonb,  -- [{from_batch, to_batch, date, by_user, reason, kept_price_or_changed}]
  cancel_reason TEXT,
  cancelled_at TIMESTAMPTZ,
  cancelled_by TEXT,
  refund_status TEXT,                              -- null | pending | paid | forfeited
  refund_owed NUMERIC,                             -- calculated at cancellation time
  refund_amount NUMERIC,                           -- actual amount paid out by finance
  refund_method TEXT,
  refund_reference TEXT,
  refund_slip_url TEXT,
  refund_paid_at TIMESTAMPTZ,
  refund_paid_by TEXT,
  refund_notes TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Payments (booking-tied OR collection-tied; negative = refund-on-the-payments-table)
CREATE TABLE oilpalm_payments (
  id TEXT PRIMARY KEY,                             -- AB-OP001
  booking_id TEXT REFERENCES oilpalm_bookings(id) ON DELETE CASCADE,
  collection_id TEXT,                              -- FK added after collections table exists
  amount NUMERIC NOT NULL,                         -- positive for payment, negative for refund (we use booking.refund_* fields instead, but reserved)
  method TEXT NOT NULL DEFAULT 'cash',             -- cash | bank | cheque
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  reference TEXT,
  slip_url TEXT,
  notes TEXT,
  logged_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  CHECK (booking_id IS NOT NULL OR collection_id IS NOT NULL)
);

-- 7. Collections (every L3.1 issuance — booking-driven OR walk-in)
CREATE TABLE oilpalm_collections (
  id TEXT PRIMARY KEY,                             -- AB-OL001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  customer_id TEXT NOT NULL REFERENCES oilpalm_customers(id),
  booking_id TEXT REFERENCES oilpalm_bookings(id), -- NULL = walk-in
  batch_id TEXT NOT NULL REFERENCES oilpalm_batches(id),  -- denormalized: locked at collection time
  qty INT NOT NULL,
  unit_price NUMERIC NOT NULL,                     -- locked at collection time
  subtotal NUMERIC NOT NULL,                       -- = qty * unit_price
  l3_form_no TEXT NOT NULL,                        -- pre-printed serial from MPOB booklet
  l3_photo_url TEXT NOT NULL,
  collection_photo_url TEXT NOT NULL,
  plate_no TEXT NOT NULL,
  collection_date DATE NOT NULL DEFAULT CURRENT_DATE,
  logged_by TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Add FK from payments.collection_id after collections exists
ALTER TABLE oilpalm_payments
  ADD CONSTRAINT fk_oilpalm_payments_collection_id
  FOREIGN KEY (collection_id) REFERENCES oilpalm_collections(id);

-- Unique L3.1 form numbers (system-wide block)
CREATE UNIQUE INDEX idx_oilpalm_collections_l3_unique ON oilpalm_collections(l3_form_no);

-- ============================================================
-- PART 3: INDEXES
-- ============================================================

CREATE INDEX idx_oilpalm_batches_status ON oilpalm_batches(status);
CREATE INDEX idx_oilpalm_batches_supplier ON oilpalm_batches(supplier_id);
CREATE INDEX idx_oilpalm_batches_variety ON oilpalm_batches(variety_id);
CREATE INDEX idx_oilpalm_batch_events_batch ON oilpalm_batch_events(batch_id);
CREATE INDEX idx_oilpalm_batch_events_date ON oilpalm_batch_events(event_date);
CREATE INDEX idx_oilpalm_customers_phone ON oilpalm_customers(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_oilpalm_bookings_customer ON oilpalm_bookings(customer_id);
CREATE INDEX idx_oilpalm_bookings_batch ON oilpalm_bookings(batch_id);
CREATE INDEX idx_oilpalm_bookings_status ON oilpalm_bookings(status);
CREATE INDEX idx_oilpalm_payments_booking ON oilpalm_payments(booking_id);
CREATE INDEX idx_oilpalm_payments_collection ON oilpalm_payments(collection_id);
CREATE INDEX idx_oilpalm_collections_batch ON oilpalm_collections(batch_id);
CREATE INDEX idx_oilpalm_collections_booking ON oilpalm_collections(booking_id);
CREATE INDEX idx_oilpalm_collections_customer ON oilpalm_collections(customer_id);
CREATE INDEX idx_oilpalm_collections_date ON oilpalm_collections(collection_date);

-- ============================================================
-- PART 4: TRIGGERS (updated_at)
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_oilpalm_suppliers_updated_at  BEFORE UPDATE ON oilpalm_suppliers  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_oilpalm_batches_updated_at    BEFORE UPDATE ON oilpalm_batches    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_oilpalm_customers_updated_at  BEFORE UPDATE ON oilpalm_customers  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_oilpalm_bookings_updated_at   BEFORE UPDATE ON oilpalm_bookings   FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- PART 5: ROW LEVEL SECURITY (open policies — same as other modules)
-- ============================================================

ALTER TABLE oilpalm_suppliers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_batches       ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_batch_events  ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_customers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_bookings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_payments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_collections   ENABLE ROW LEVEL SECURITY;

-- Open policies for both anon (PIN login) and authenticated (Google OAuth) on every table.
-- This mirrors the pattern in seedlings_migration.sql lines 217-285. For each table, create:
--   <table>_anon_select, <table>_anon_insert, <table>_anon_update, <table>_anon_delete
--   <table>_auth_select, <table>_auth_insert, <table>_auth_update, <table>_auth_delete
-- All USING (true) and WITH CHECK (true).

-- oilpalm_suppliers
CREATE POLICY oilpalm_suppliers_anon_select ON oilpalm_suppliers FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_suppliers_anon_insert ON oilpalm_suppliers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_anon_update ON oilpalm_suppliers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_anon_delete ON oilpalm_suppliers FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_suppliers_auth_select ON oilpalm_suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_suppliers_auth_insert ON oilpalm_suppliers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_auth_update ON oilpalm_suppliers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_auth_delete ON oilpalm_suppliers FOR DELETE TO authenticated USING (true);

-- Repeat the same 8-policy block for: oilpalm_batches, oilpalm_batch_events,
--   oilpalm_customers, oilpalm_bookings, oilpalm_payments, oilpalm_collections.
-- (See seedlings_migration.sql lines 227-285 for the exact pattern.)

-- ============================================================
-- PART 6: ID COUNTERS (seed initial counter rows for each new prefix)
-- ============================================================

INSERT INTO id_counters (company_id, prefix, last_number) VALUES
  ('tg_agribusiness', 'OS', 0),
  ('tg_agribusiness', 'OB', 0),
  ('tg_agribusiness', 'OE', 0),
  ('tg_agribusiness', 'OC', 0),
  ('tg_agribusiness', 'OK', 0),
  ('tg_agribusiness', 'OP', 0),
  ('tg_agribusiness', 'OL', 0)
ON CONFLICT (company_id, prefix) DO NOTHING;

-- DONE
```

- [ ] **Step 2: Verify the migration file lints**

Run on Windows:
```bash
node -e "const fs=require('fs'); const sql=fs.readFileSync('supabase/oilpalm_migration.sql','utf8'); console.log('Length:',sql.length,'chars,', sql.split('\n').length,'lines'); console.log('Tables created:',(sql.match(/CREATE TABLE oilpalm_/g)||[]).length,'(expect 7)'); console.log('Indexes:',(sql.match(/CREATE (UNIQUE )?INDEX/g)||[]).length); console.log('Triggers:',(sql.match(/CREATE TRIGGER/g)||[]).length); console.log('Policies:',(sql.match(/CREATE POLICY/g)||[]).length,'(expect 56 = 7 tables * 8 policies)');"
```

Expected: 7 tables, 16+ indexes, 4 triggers, 56 policies. If policies count < 56, expand the policy block per the Part 5 comment (the migration above only spells out the supplier policies in full — the engineer must duplicate the 8-policy block for the other 6 tables before applying).

- [ ] **Step 3: Commit**

```bash
git add supabase/oilpalm_migration.sql
git commit -m "feat(oilpalm): SQL migration for growth + sales modules"
```

---

### Task 0.2: Apply migration to production Supabase

**Files:**
- Run: `supabase/oilpalm_migration.sql` against production database

- [ ] **Step 1: Apply migration via Node `pg` script**

Create `scripts/run-oilpalm-migration.js` (temporary, will be deleted after):
```javascript
const { Client } = require('pg');
const fs = require('fs');

(async () => {
  const client = new Client({
    host: 'aws-1-ap-northeast-1.pooler.supabase.com',
    port: 5432,
    database: 'postgres',
    user: 'postgres.qwlagcriiyoflseduvvc',
    password: 'Hlfqdbi6wcM4Omsm',
    ssl: { rejectUnauthorized: false }
  });
  await client.connect();
  const sql = fs.readFileSync('supabase/oilpalm_migration.sql', 'utf8');
  try {
    await client.query(sql);
    console.log('Migration applied successfully');
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
})();
```

Run:
```bash
node scripts/run-oilpalm-migration.js
```

Expected: `Migration applied successfully`

- [ ] **Step 2: Verify schema in production**

```javascript
const { Client } = require('pg');
(async () => {
  const c = new Client({ host: 'aws-1-ap-northeast-1.pooler.supabase.com', port: 5432, database: 'postgres', user: 'postgres.qwlagcriiyoflseduvvc', password: 'Hlfqdbi6wcM4Omsm', ssl: { rejectUnauthorized: false } });
  await c.connect();
  const r = await c.query(`SELECT tablename FROM pg_tables WHERE tablename LIKE 'oilpalm_%' ORDER BY tablename`);
  console.log('Oil palm tables:', r.rows.map(x => x.tablename));
  const s = await c.query(`SELECT tablename FROM pg_tables WHERE tablename LIKE 'seedling_%' ORDER BY tablename`);
  console.log('Seedling tables (should be empty):', s.rows.map(x => x.tablename));
  await c.end();
})();
```

Expected output:
```
Oil palm tables: [ 'oilpalm_batch_events', 'oilpalm_batches', 'oilpalm_bookings', 'oilpalm_collections', 'oilpalm_customers', 'oilpalm_payments', 'oilpalm_suppliers' ]
Seedling tables (should be empty): []
```

- [ ] **Step 3: Verify id_counters seeded**

```javascript
// In the same Node REPL after the verify above:
const r = await c.query(`SELECT prefix, last_number FROM id_counters WHERE company_id='tg_agribusiness' AND prefix IN ('OS','OB','OE','OC','OK','OP','OL') ORDER BY prefix`);
console.log(r.rows);
```

Expected: 7 rows, all `last_number = 0`.

- [ ] **Step 4: Delete the migration script (one-shot use)**

```bash
rm scripts/run-oilpalm-migration.js
```

- [ ] **Step 5: Commit (no code change — just confirms migration applied)**

No files to commit. Migration is recorded in the SQL file from Task 0.1.

---

### Task 0.3: Storage bucket setup

**Files:**
- Run: Supabase REST API calls against production

- [ ] **Step 1: Drop old bucket + create new bucket via Supabase Storage API**

```javascript
// scripts/setup-oilpalm-bucket.js (temporary)
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE';
const BASE = 'https://qwlagcriiyoflseduvvc.supabase.co/storage/v1';

(async () => {
  // Drop old bucket (will succeed if empty, fail loudly if not — that's fine, signals leftover data)
  let r = await fetch(`${BASE}/bucket/seedling-photos`, { method: 'DELETE', headers: { 'Authorization': `Bearer ${SERVICE_KEY}` } });
  console.log('Drop seedling-photos:', r.status, await r.text());

  // Create new bucket (public, no MIME allowlist — we need PDF + images)
  r = await fetch(`${BASE}/bucket`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: 'oilpalm-photos', name: 'oilpalm-photos', public: true, file_size_limit: 10485760 })  // 10 MB
  });
  console.log('Create oilpalm-photos:', r.status, await r.text());
})();
```

Run:
```bash
node scripts/setup-oilpalm-bucket.js
```

Expected: `Drop seedling-photos: 200` and `Create oilpalm-photos: 200`.

- [ ] **Step 2: Verify bucket via REST**

```bash
curl -s "https://qwlagcriiyoflseduvvc.supabase.co/storage/v1/bucket/oilpalm-photos" -H "Authorization: Bearer eyJhbGci...service_key..."
```

Expected JSON: `{"id":"oilpalm-photos","name":"oilpalm-photos","public":true,...}`

- [ ] **Step 3: Delete the bucket setup script**

```bash
rm scripts/setup-oilpalm-bucket.js
```

---

## Phase 1 — Growth Module Foundation

### Task 1.1: Create empty `oilpalmgrowth.html` shell

**Files:**
- Create: `oilpalmgrowth.html`
- Create: `oilpalmgrowth.css`

- [ ] **Step 1: Write the HTML shell with sidebar + tabs**

Use `seedlings.html` (about to be deleted) as the structural reference for sidebar + tabs + Supabase init pattern, but renamed throughout. Key elements:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Oil Palm Growth — TG FarmHub</title>
  <link rel="stylesheet" href="shared.css?v=2" />
  <link rel="stylesheet" href="oilpalmgrowth.css?v=1" />
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.1/dist/umd/supabase.min.js"></script>
  <script src="shared.js?v=2"></script>
</head>
<body>
  <a href="#main" class="skip-link">Skip to main content</a>
  <div id="offline-banner" class="offline-banner" hidden>You're offline. Changes will retry.</div>

  <aside class="sidebar" aria-label="Module navigation">
    <a href="index.html" class="sidebar-brand">
      <img src="assets/logo-agribusiness.png" alt="TG Agribusiness" class="sidebar-logo" />
      <div class="sidebar-title">
        <span class="brand-name">Oil Palm Growth</span>
        <span class="brand-back">&lt; TG FarmHub</span>
      </div>
    </a>
    <nav aria-label="Tabs">
      <button class="tab-btn active" data-tab="batches" onclick="switchTab('batches')">Batches</button>
      <button class="tab-btn" data-tab="suppliers" onclick="switchTab('suppliers')">Suppliers</button>
      <button class="tab-btn" data-tab="reports" onclick="switchTab('reports')">Reports</button>
    </nav>
    <div class="sidebar-user">
      <span id="sidebar-user-name"></span>
      <button class="btn btn-ghost" onclick="logout()">Logout</button>
    </div>
  </aside>

  <main id="main" role="main" class="content">
    <div id="tab-batches" class="tab-pane active"></div>
    <div id="tab-suppliers" class="tab-pane"></div>
    <div id="tab-reports" class="tab-pane"></div>
  </main>

  <div id="modal-host"></div>

  <script>
    // === Supabase init ===
    const SUPABASE_URL = 'https://qwlagcriiyoflseduvvc.supabase.co';
    const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNDgxNDYsImV4cCI6MjA4NzkyNDE0Nn0.OJvzNykb_JjejFlWlEy7QUKJjL7bfiaQI0pPx62P5YA';
    const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

    // === State ===
    let currentTab = 'batches';
    let suppliers = [];
    let batches = [];
    let varieties = [];

    // === Init ===
    document.addEventListener('DOMContentLoaded', async () => {
      if (!ensureSession()) return;  // shared.js redirects to index.html if no session
      document.getElementById('sidebar-user-name').textContent = currentUser.name || currentUser.username;
      await Promise.all([loadSuppliers(), loadBatches(), loadVarieties()]);
      renderBatchesTab();
    });

    function switchTab(name) {
      currentTab = name;
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === 'tab-' + name));
      if (name === 'batches')   renderBatchesTab();
      if (name === 'suppliers') renderSuppliersTab();
      if (name === 'reports')   renderReportsTab();
    }

    // === Loaders (stub) ===
    async function loadSuppliers() {
      const data = await sbQuery(sb.from('oilpalm_suppliers').select('*').eq('company_id', getCompanyId()).order('name'));
      suppliers = data || [];
    }
    async function loadBatches() {
      const data = await sbQuery(sb.from('oilpalm_batches').select('*').eq('company_id', getCompanyId()).order('created_at', { ascending: false }));
      batches = data || [];
    }
    async function loadVarieties() {
      // crop_varieties is shared. Filter by oil palm crop.
      const crops = await sbQuery(sb.from('crops').select('id,name'));
      const oilPalm = (crops || []).find(c => /oil\s*palm/i.test(c.name));
      if (!oilPalm) { varieties = []; return; }
      const data = await sbQuery(sb.from('crop_varieties').select('id,name,crop_id').eq('crop_id', oilPalm.id).order('name'));
      varieties = data || [];
    }

    // === Render stubs (filled in later tasks) ===
    function renderBatchesTab()   { document.getElementById('tab-batches').innerHTML = '<p>Batches — TODO</p>'; }
    function renderSuppliersTab() { document.getElementById('tab-suppliers').innerHTML = '<p>Suppliers — TODO</p>'; }
    function renderReportsTab()   { document.getElementById('tab-reports').innerHTML = '<p>Reports — TODO</p>'; }
  </script>
</body>
</html>
```

- [ ] **Step 2: Write minimal `oilpalmgrowth.css` stub**

```css
/* Oil Palm Growth — module-specific styles */

/* Lifecycle status badges */
.opg-stage-badge {
  display: inline-block;
  padding: 2px 10px;
  border-radius: 3px;
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.opg-stage-ordered      { background: rgba(120, 120, 120, 0.18); color: #555; }
.opg-stage-received     { background: rgba(74, 124, 63, 0.20); color: #2D5224; }
.opg-stage-pre_nursery  { background: rgba(212, 175, 55, 0.22); color: #8A6D1F; }
.opg-stage-main_nursery { background: rgba(107, 76, 138, 0.20); color: #4D356B; }
.opg-stage-selling      { background: rgba(255, 140, 40, 0.20); color: #C96A1A; }
.opg-stage-sold_out     { background: rgba(196, 64, 64, 0.18); color: #8A2828; }
.opg-stage-closed       { background: rgba(80, 80, 80, 0.20); color: #333; }

/* Batch detail page — section blocks */
.opg-section {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 16px 20px;
  margin-bottom: 14px;
}
.opg-section h3 {
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #6B4C8A;
  margin: 0 0 12px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 8px;
}

/* Document upload slots */
.opg-doc-slot {
  display: grid;
  grid-template-columns: 200px 1fr auto;
  gap: 12px;
  padding: 8px 0;
  border-bottom: 1px dashed var(--border);
  align-items: center;
}
.opg-doc-slot:last-child { border-bottom: none; }
.opg-doc-label { font-size: 13px; font-weight: 600; }
.opg-doc-file  { font-size: 12px; color: var(--muted); word-break: break-all; }

/* Mobile */
@media (max-width: 720px) {
  .opg-doc-slot { grid-template-columns: 1fr; }
}
```

- [ ] **Step 3: Verify the page loads (manual)**

Open `oilpalmgrowth.html?session=<your_user_id>` in a browser. Confirm:
- Sidebar renders with 3 tabs
- "Batches — TODO" appears in main content
- No console errors
- Tab switching works (text content changes per tab)

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html oilpalmgrowth.css
git commit -m "feat(oilpalm): scaffold growth module shell"
```

---

### Task 1.2: Suppliers tab CRUD

**Files:**
- Modify: `oilpalmgrowth.html` (replace `renderSuppliersTab()` stub + add `osSaveSupplier`, `osEditSupplier`, `osDeleteSupplier`, `osOpenSupplierModal`)

- [ ] **Step 1: Implement Suppliers tab**

Replace the `renderSuppliersTab()` stub with:

```javascript
function renderSuppliersTab() {
  const tbody = suppliers.map((s, i) => `
    <tr>
      <td>${i + 1}</td>
      <td>${esc(s.name)}</td>
      <td>${esc(s.contact_person || '—')}</td>
      <td>${fmtPhone(s.phone) || '—'}</td>
      <td>${esc(s.address || '—')}</td>
      <td>${s.is_active ? '<span class="badge badge-active">Active</span>' : '<span class="badge badge-inactive">Inactive</span>'}</td>
      <td class="actions">
        <button class="btn btn-tiny" onclick="osOpenSupplierModal('${s.id}')">Edit</button>
        <button class="btn btn-tiny ${s.is_active ? 'danger' : ''}" onclick="osToggleSupplier('${s.id}', ${!s.is_active})">${s.is_active ? 'Deactivate' : 'Activate'}</button>
      </td>
    </tr>
  `).join('') || '<tr><td colspan="7" style="text-align:center; padding:20px; color:var(--muted)">No suppliers yet.</td></tr>';

  document.getElementById('tab-suppliers').innerHTML = `
    <div class="page-header">
      <h2>Suppliers</h2>
      <button class="btn btn-primary" onclick="osOpenSupplierModal()">+ Add Supplier</button>
    </div>
    <table class="data-table">
      <thead><tr><th>#</th><th>Name</th><th>Contact</th><th>Phone</th><th>Address</th><th>Status</th><th>Actions</th></tr></thead>
      <tbody>${tbody}</tbody>
    </table>
  `;
}

function osOpenSupplierModal(id) {
  const s = id ? suppliers.find(x => x.id === id) : { name: '', contact_person: '', phone: '', address: '', notes: '' };
  if (!s) return;
  showModal(`
    <h3>${id ? 'Edit' : 'Add'} Supplier</h3>
    <div class="form-grid">
      <label>Name <input id="os-name" value="${esc(s.name)}" /></label>
      <label>Contact Person <input id="os-contact" value="${esc(s.contact_person || '')}" /></label>
      <label>Phone <input id="os-phone" value="${esc(s.phone || '')}" /></label>
      <label class="full">Address <textarea id="os-addr">${esc(s.address || '')}</textarea></label>
      <label class="full">Notes <textarea id="os-notes">${esc(s.notes || '')}</textarea></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="osSaveSupplier('${id || ''}')">Save</button>
    </div>
  `);
}

async function osSaveSupplier(id) {
  const name = document.getElementById('os-name').value.trim();
  if (!name) { notify('Name is required', 'error'); return; }
  const data = {
    name,
    contact_person: document.getElementById('os-contact').value.trim() || null,
    phone: document.getElementById('os-phone').value.trim() || null,
    address: document.getElementById('os-addr').value.trim() || null,
    notes: document.getElementById('os-notes').value.trim() || null
  };
  if (id) {
    const result = await sbMutate(sb.from('oilpalm_suppliers').update(data).eq('id', id).select());
    if (result === null) return;
  } else {
    const newId = await dbNextId('OS');
    if (!newId) { notify('Failed to generate ID', 'error'); return; }
    data.id = newId;
    data.company_id = getCompanyId();
    const result = await sbMutate(sb.from('oilpalm_suppliers').insert(data).select());
    if (result === null) return;
  }
  await loadSuppliers();
  closeModal();
  renderSuppliersTab();
  notify(id ? 'Supplier updated' : 'Supplier added', 'success');
}

async function osToggleSupplier(id, makeActive) {
  const result = await sbMutate(sb.from('oilpalm_suppliers').update({ is_active: makeActive }).eq('id', id).select());
  if (result === null) return;
  await loadSuppliers();
  renderSuppliersTab();
  notify(makeActive ? 'Supplier activated' : 'Supplier deactivated', 'success');
}
```

- [ ] **Step 2: Verify in browser**

Reload the page. Switch to Suppliers tab. Click `+ Add Supplier`, fill in name + phone + address, click Save. Verify:
- Supplier appears in the table
- Click Edit, change something, save. Confirm change persists (refresh page).
- Click Deactivate. Status flips to Inactive, button label flips to Activate.

- [ ] **Step 3: Verify DB row**

Run via Node:
```javascript
const { Client } = require('pg'); const c = new Client({ host:'aws-1-ap-northeast-1.pooler.supabase.com', port:5432, database:'postgres', user:'postgres.qwlagcriiyoflseduvvc', password:'Hlfqdbi6wcM4Omsm', ssl:{rejectUnauthorized:false} });
(async()=>{ await c.connect(); console.log((await c.query('SELECT id,name,is_active FROM oilpalm_suppliers ORDER BY created_at DESC LIMIT 3')).rows); await c.end(); })();
```

Expected: 1+ rows with `id` like `AB-OS001`.

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): suppliers tab CRUD"
```

---

### Task 1.3: Batches list view

**Files:**
- Modify: `oilpalmgrowth.html` (replace `renderBatchesTab()` stub + add filter handlers, sort, render rows)

- [ ] **Step 1: Implement batches list with filters**

Replace `renderBatchesTab()`:

```javascript
let batchesFilter = { stage: 'all', supplier: 'all', variety: 'all' };

function renderBatchesTab() {
  const supplierMap = Object.fromEntries(suppliers.map(s => [s.id, s.name]));
  const varietyMap  = Object.fromEntries(varieties.map(v => [v.id, v.name]));

  const filtered = batches.filter(b => {
    if (batchesFilter.stage !== 'all' && b.status !== batchesFilter.stage) return false;
    if (batchesFilter.supplier !== 'all' && b.supplier_id !== batchesFilter.supplier) return false;
    if (batchesFilter.variety !== 'all' && b.variety_id !== batchesFilter.variety) return false;
    return true;
  });

  const rows = filtered.map(b => {
    const planted = b.qty_planted || 0;
    const mn      = b.qty_mn_start || 0;
    const collected = collectionsByBatch[b.id] || 0;
    const midCulls  = midCullsByBatch[b.id] || 0;
    const available = mn > 0 ? Math.max(0, mn - midCulls - collected) : 0;
    const age = b.date_planted ? Math.floor((Date.now() - new Date(b.date_planted).getTime()) / 86400000) : null;
    const ready = b.date_planted ? addMonths(b.date_planted, 10) : null;

    return `
      <tr onclick="opgOpenBatchDetail('${b.id}')" style="cursor:pointer">
        <td>${esc(b.batch_number)}</td>
        <td>${esc(supplierMap[b.supplier_id] || '—')}</td>
        <td>${esc(varietyMap[b.variety_id] || '—')}</td>
        <td><span class="opg-stage-badge opg-stage-${b.status}">${stageLabel(b.status)}</span></td>
        <td>${b.ordered_qty || 0}</td>
        <td>${planted || '—'}</td>
        <td>${mn || '—'}</td>
        <td>${available || '—'}</td>
        <td>${age != null ? age + 'd' : '—'}</td>
        <td>${ready ? fmtDateDM(ready) : '—'}</td>
      </tr>
    `;
  }).join('') || '<tr><td colspan="10" style="text-align:center; padding:20px; color:var(--muted)">No batches yet.</td></tr>';

  document.getElementById('tab-batches').innerHTML = `
    <div class="page-header">
      <h2>Batches</h2>
      <button class="btn btn-primary" onclick="opgOpenNewBatchModal()">+ New Batch</button>
    </div>
    <div class="filters-bar">
      <select onchange="batchesFilter.stage=this.value; renderBatchesTab()">
        <option value="all">All stages</option>
        <option value="ordered">Ordered</option>
        <option value="received">Received</option>
        <option value="pre_nursery">Pre-Nursery</option>
        <option value="main_nursery">Main Nursery</option>
        <option value="selling">Selling</option>
        <option value="sold_out">Sold Out</option>
        <option value="closed">Closed</option>
      </select>
      <select onchange="batchesFilter.supplier=this.value; renderBatchesTab()">
        <option value="all">All suppliers</option>
        ${suppliers.map(s => `<option value="${s.id}">${esc(s.name)}</option>`).join('')}
      </select>
      <select onchange="batchesFilter.variety=this.value; renderBatchesTab()">
        <option value="all">All varieties</option>
        ${varieties.map(v => `<option value="${v.id}">${esc(v.name)}</option>`).join('')}
      </select>
    </div>
    <table class="data-table">
      <thead><tr>
        <th>Batch #</th><th>Supplier</th><th>Variety</th><th>Stage</th>
        <th>Ordered</th><th>Planted</th><th>MN qty</th><th>Available</th><th>Age</th><th>Ready Date</th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>
  `;

  // Restore filter values
  const sels = document.querySelectorAll('#tab-batches .filters-bar select');
  if (sels[0]) sels[0].value = batchesFilter.stage;
  if (sels[1]) sels[1].value = batchesFilter.supplier;
  if (sels[2]) sels[2].value = batchesFilter.variety;
}

function stageLabel(s) {
  return ({
    ordered: 'Ordered', received: 'Received', pre_nursery: 'Pre-Nursery', main_nursery: 'Main Nursery',
    selling: 'Selling', sold_out: 'Sold Out', closed: 'Closed'
  })[s] || s;
}

function addMonths(d, m) {
  const x = new Date(d);
  x.setMonth(x.getMonth() + m);
  return x.toISOString().slice(0, 10);
}
```

Add helper loaders at the top with the other loaders:
```javascript
let collectionsByBatch = {};  // {batch_id: total_collected_qty}
let midCullsByBatch = {};     // {batch_id: total_mid_mn_cull_qty}

async function loadCollectionAggregates() {
  const data = await sbQuery(sb.from('oilpalm_collections').select('batch_id,qty').eq('company_id', getCompanyId()));
  collectionsByBatch = {};
  (data || []).forEach(c => { collectionsByBatch[c.batch_id] = (collectionsByBatch[c.batch_id] || 0) + c.qty; });
}

async function loadMidCullAggregates() {
  const data = await sbQuery(sb.from('oilpalm_batch_events').select('batch_id,event_type,qty').eq('event_type', 'cull'));
  midCullsByBatch = {};
  (data || []).forEach(e => { midCullsByBatch[e.batch_id] = (midCullsByBatch[e.batch_id] || 0) + e.qty; });
}
```

Update `DOMContentLoaded`:
```javascript
await Promise.all([loadSuppliers(), loadBatches(), loadVarieties(), loadCollectionAggregates(), loadMidCullAggregates()]);
```

- [ ] **Step 2: Stub `opgOpenBatchDetail` and `opgOpenNewBatchModal`** so clicks don't error

```javascript
function opgOpenBatchDetail(id) { notify('Batch detail page TBD next task', 'info'); }
function opgOpenNewBatchModal()  { notify('New batch modal TBD next task', 'info'); }
```

- [ ] **Step 3: Verify**

Reload. Switch to Batches tab. Confirm: empty state shows "No batches yet." Filter dropdowns render. No console errors.

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): batches list view + filters"
```

---

### Task 1.4: New Batch modal (creates Ordered-stage batch)

**Files:**
- Modify: `oilpalmgrowth.html` (replace `opgOpenNewBatchModal` stub + add `opgSaveNewBatch`)

- [ ] **Step 1: Implement new batch modal**

```javascript
async function opgOpenNewBatchModal() {
  const yr = new Date().getFullYear();
  const yrBatches = batches.filter(b => (b.batch_number || '').endsWith('-' + yr));
  const nextNum = yrBatches.length + 1;
  const defaultBatchNumber = `${nextNum}-${yr}`;

  showModal(`
    <h3>New Batch</h3>
    <div class="form-grid">
      <label>Batch # <input id="opg-bn" value="${defaultBatchNumber}" /></label>
      <label>Order Date <input id="opg-od" type="date" value="${new Date().toISOString().slice(0,10)}" /></label>
      <label>Supplier
        <select id="opg-sup">
          <option value="">— select —</option>
          ${suppliers.filter(s => s.is_active).map(s => `<option value="${s.id}">${esc(s.name)}</option>`).join('')}
        </select>
      </label>
      <label>Variety
        <select id="opg-var">
          <option value="">— select —</option>
          ${varieties.map(v => `<option value="${v.id}">${esc(v.name)}</option>`).join('')}
        </select>
      </label>
      <label>Ordered Qty <input id="opg-qty" type="number" min="1" /></label>
      <label>Unit Cost (RM) <input id="opg-uc" type="number" step="0.01" min="0" /></label>
      <label>Estimated Delivery <input id="opg-edd" type="date" /></label>
      <label class="full">Notes <textarea id="opg-notes"></textarea></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opgSaveNewBatch()">Create Batch</button>
    </div>
  `);
}

async function opgSaveNewBatch() {
  const bn  = document.getElementById('opg-bn').value.trim();
  const od  = document.getElementById('opg-od').value;
  const sup = document.getElementById('opg-sup').value;
  const va  = document.getElementById('opg-var').value;
  const qty = parseInt(document.getElementById('opg-qty').value, 10);
  const uc  = parseFloat(document.getElementById('opg-uc').value) || 0;
  const edd = document.getElementById('opg-edd').value || null;
  const notes = document.getElementById('opg-notes').value.trim() || null;

  if (!bn || !sup || !va || !qty || qty < 1) { notify('Batch #, supplier, variety, qty are required', 'error'); return; }

  const id = await dbNextId('OB');
  if (!id) { notify('Failed to generate ID', 'error'); return; }

  const result = await sbMutate(sb.from('oilpalm_batches').insert({
    id,
    company_id: getCompanyId(),
    batch_number: bn,
    supplier_id: sup,
    variety_id: va,
    ordered_qty: qty,
    unit_cost: uc,
    total_cost: qty * uc,
    order_date: od,
    estimated_delivery_date: edd,
    notes,
    status: 'ordered'
  }).select());

  if (result === null) return;
  await loadBatches();
  closeModal();
  renderBatchesTab();
  notify('Batch created', 'success');
}
```

- [ ] **Step 2: Verify**

Click `+ New Batch`. Fill in: Batch # = "1-2026", supplier (one created in Task 1.2), variety (must have an oil palm variety in `crop_varieties` — if none, add via Farm Config first), qty = 10000, unit cost = 1.20, estimated delivery = a future date. Save.

Confirm: row appears in batches list with Stage = `Ordered`, Ordered = 10000.

- [ ] **Step 3: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): new batch modal"
```

---

### Task 1.5: Batch detail page — header + procurement section

**Files:**
- Modify: `oilpalmgrowth.html` (replace `opgOpenBatchDetail` stub + add `opgRenderDetail`, `opgCloseDetail`, `opgSaveProcurement`)
- Modify: `oilpalmgrowth.css` (add detail page layout styles)

- [ ] **Step 1: Implement detail page open + close**

The detail page replaces the entire Batches tab content while open (vs. modal). Add a `selectedBatchId` state var. When set, `renderBatchesTab` delegates to `opgRenderDetail`.

```javascript
let selectedBatchId = null;

function opgOpenBatchDetail(id) {
  selectedBatchId = id;
  renderBatchesTab();
}
function opgCloseDetail() {
  selectedBatchId = null;
  renderBatchesTab();
}

// Modify renderBatchesTab top:
function renderBatchesTab() {
  if (selectedBatchId) { opgRenderDetail(); return; }
  // ... existing list render ...
}

function opgRenderDetail() {
  const b = batches.find(x => x.id === selectedBatchId);
  if (!b) { selectedBatchId = null; renderBatchesTab(); return; }

  const supplier = suppliers.find(s => s.id === b.supplier_id);
  const variety  = varieties.find(v => v.id === b.variety_id);
  const ready = b.date_planted ? addMonths(b.date_planted, 10) : null;
  const age   = b.date_planted ? Math.floor((Date.now() - new Date(b.date_planted).getTime()) / 86400000) : null;

  document.getElementById('tab-batches').innerHTML = `
    <button class="btn btn-ghost" onclick="opgCloseDetail()">← Back to Batches</button>

    <div class="opg-section opg-header">
      <div class="opg-header-row">
        <h2>${esc(b.batch_number)}</h2>
        <span class="opg-stage-badge opg-stage-${b.status}">${stageLabel(b.status)}</span>
        ${age != null ? `<span class="muted">Age: ${age} days</span>` : ''}
        ${ready ? `<span class="muted">Ready for Sale: ${fmtDateDM(ready)}</span>` : ''}
      </div>
      <div class="opg-header-row">
        <span><strong>Supplier:</strong> ${esc(supplier?.name || '—')}</span>
        <span><strong>Variety:</strong> ${esc(variety?.name || '—')}</span>
      </div>
      <div class="opg-actions">
        ${b.status === 'main_nursery' ? `<button class="btn btn-primary" onclick="opgMarkSelling()">Mark as Selling</button>` : ''}
        ${b.status !== 'closed' && b.status !== 'ordered' ? `<button class="btn danger" onclick="opgCloseBatch()">Close Batch</button>` : ''}
      </div>
    </div>

    <div class="opg-section">
      <h3>Procurement</h3>
      <div class="form-grid">
        <label>Order Date <input id="opg-d-od" type="date" value="${b.order_date || ''}" /></label>
        <label>Estimated Delivery <input id="opg-d-edd" type="date" value="${b.estimated_delivery_date || ''}" /></label>
        <label>Actual Delivery <input id="opg-d-add" type="date" value="${b.actual_delivery_date || ''}" /></label>
        <label>Ordered Qty <input id="opg-d-qty" type="number" min="0" value="${b.ordered_qty || 0}" /></label>
        <label>Unit Cost (RM) <input id="opg-d-uc" type="number" step="0.01" min="0" value="${b.unit_cost || 0}" /></label>
        <label>Total Cost (RM) <input id="opg-d-tc" type="number" step="0.01" min="0" value="${b.total_cost || 0}" readonly /></label>
        <label class="full">Notes <textarea id="opg-d-notes">${esc(b.notes || '')}</textarea></label>
      </div>
      <div class="modal-actions"><button class="btn btn-primary" onclick="opgSaveProcurement()">Save Procurement</button></div>
    </div>

    <div id="opg-payment-section"></div>
    <div id="opg-docs-section"></div>
    <div id="opg-receipt-section"></div>
    <div id="opg-mn-section"></div>
  `;

  // Auto-recompute total_cost when qty/unit_cost change
  document.getElementById('opg-d-qty').addEventListener('input', opgRecomputeTotalCost);
  document.getElementById('opg-d-uc').addEventListener('input', opgRecomputeTotalCost);

  // Render the rest of the sections (filled in next tasks)
  opgRenderPaymentSection(b);
  opgRenderDocsSection(b);
  opgRenderReceiptSection(b);
  opgRenderMnSection(b);
}

function opgRecomputeTotalCost() {
  const q = parseFloat(document.getElementById('opg-d-qty').value) || 0;
  const u = parseFloat(document.getElementById('opg-d-uc').value) || 0;
  document.getElementById('opg-d-tc').value = (q * u).toFixed(2);
}

async function opgSaveProcurement() {
  const id = selectedBatchId;
  const data = {
    order_date: document.getElementById('opg-d-od').value || null,
    estimated_delivery_date: document.getElementById('opg-d-edd').value || null,
    actual_delivery_date: document.getElementById('opg-d-add').value || null,
    ordered_qty: parseInt(document.getElementById('opg-d-qty').value, 10) || 0,
    unit_cost: parseFloat(document.getElementById('opg-d-uc').value) || 0,
    total_cost: parseFloat(document.getElementById('opg-d-tc').value) || 0,
    notes: document.getElementById('opg-d-notes').value.trim() || null
  };

  // Auto-flip Ordered → Received when actual_delivery_date is filled
  const before = batches.find(x => x.id === id);
  if (before.status === 'ordered' && data.actual_delivery_date) {
    data.status = 'received';
  }
  if (before.status === 'received' && !data.actual_delivery_date) {
    data.status = 'ordered';  // unflip if cleared
  }

  const result = await sbMutate(sb.from('oilpalm_batches').update(data).eq('id', id).select());
  if (result === null) return;
  await loadBatches();
  renderBatchesTab();
  notify('Procurement saved', 'success');
}

// Stubs for next tasks
function opgRenderPaymentSection(b) { document.getElementById('opg-payment-section').innerHTML = '<div class="opg-section"><h3>Payment</h3><p>TBD</p></div>'; }
function opgRenderDocsSection(b)    { document.getElementById('opg-docs-section').innerHTML    = '<div class="opg-section"><h3>Documents</h3><p>TBD</p></div>'; }
function opgRenderReceiptSection(b) { document.getElementById('opg-receipt-section').innerHTML = '<div class="opg-section"><h3>Receipt + Planting</h3><p>TBD</p></div>'; }
function opgRenderMnSection(b)      { document.getElementById('opg-mn-section').innerHTML      = ''; }
function opgMarkSelling() { notify('TBD', 'info'); }
function opgCloseBatch()  { notify('TBD', 'info'); }
```

- [ ] **Step 2: Add detail page styles**

Append to `oilpalmgrowth.css`:
```css
.opg-header { background: linear-gradient(180deg, #fff, #fbfaf6); }
.opg-header-row { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; margin-bottom: 8px; }
.opg-header-row h2 { margin: 0; font-size: 22px; }
.opg-actions { margin-top: 12px; display: flex; gap: 8px; }
```

- [ ] **Step 3: Verify**

Click a batch row → detail page renders with header (batch #, stage badge, supplier, variety) + Procurement section editable. Edit qty + unit cost → total_cost recalculates live. Click Save → page reloads with saved values. Set Actual Delivery date → save → stage flips to Received.

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html oilpalmgrowth.css
git commit -m "feat(oilpalm-growth): batch detail header + procurement"
```

---

### Task 1.6: Batch detail — Payment + Documents sections

**Files:**
- Modify: `oilpalmgrowth.html` (replace `opgRenderPaymentSection` and `opgRenderDocsSection` + add upload helpers)

- [ ] **Step 1: Payment section**

```javascript
function opgRenderPaymentSection(b) {
  const slipLink = b.payment_slip_url
    ? `<a href="${b.payment_slip_url}" target="_blank">View slip</a>`
    : '<span class="muted">No slip uploaded</span>';
  const slipExt = b.payment_slip_url ? b.payment_slip_url.split('.').pop().toLowerCase() : '';
  const slipLabel = slipExt === 'pdf' ? 'PDF' : 'Image';

  document.getElementById('opg-payment-section').innerHTML = `
    <div class="opg-section">
      <h3>Payment</h3>
      <div class="form-grid">
        <label>Date <input id="opg-pay-date" type="date" value="${b.payment_date || ''}" /></label>
        <label>Amount (RM) <input id="opg-pay-amount" type="number" step="0.01" min="0" value="${b.payment_amount || ''}" /></label>
        <label>Method
          <select id="opg-pay-method">
            <option value="">—</option>
            <option value="cash"  ${b.payment_method === 'cash' ? 'selected' : ''}>Cash</option>
            <option value="bank"  ${b.payment_method === 'bank' ? 'selected' : ''}>Bank Transfer</option>
            <option value="cheque"${b.payment_method === 'cheque' ? 'selected' : ''}>Cheque</option>
          </select>
        </label>
        <label>Reference <input id="opg-pay-ref" value="${esc(b.payment_reference || '')}" /></label>
        <label class="full">Slip
          <input type="file" id="opg-pay-slip" accept="image/*,application/pdf" />
          <div class="muted" style="font-size:12px;margin-top:4px">${slipLabel}: ${slipLink}</div>
        </label>
        <label class="full">Notes <textarea id="opg-pay-notes">${esc(b.payment_notes || '')}</textarea></label>
      </div>
      <div class="modal-actions"><button class="btn btn-primary" onclick="opgSavePayment()">Save Payment</button></div>
    </div>
  `;
}

async function opgSavePayment() {
  const id = selectedBatchId;
  const slipFile = document.getElementById('opg-pay-slip').files[0];
  let slipUrl = batches.find(x => x.id === id).payment_slip_url || null;

  if (slipFile) {
    const path = `procurement/${id}/payment-slip.${slipFile.name.split('.').pop()}`;
    const upload = await sb.storage.from('oilpalm-photos').upload(path, slipFile, { upsert: true, contentType: slipFile.type });
    if (upload.error) { notify('Slip upload failed: ' + upload.error.message, 'error'); return; }
    slipUrl = sb.storage.from('oilpalm-photos').getPublicUrl(path).data.publicUrl;
  }

  const data = {
    payment_date: document.getElementById('opg-pay-date').value || null,
    payment_amount: parseFloat(document.getElementById('opg-pay-amount').value) || null,
    payment_method: document.getElementById('opg-pay-method').value || null,
    payment_reference: document.getElementById('opg-pay-ref').value.trim() || null,
    payment_slip_url: slipUrl,
    payment_notes: document.getElementById('opg-pay-notes').value.trim() || null
  };

  const result = await sbMutate(sb.from('oilpalm_batches').update(data).eq('id', id).select());
  if (result === null) return;
  await loadBatches();
  renderBatchesTab();
  notify('Payment saved', 'success');
}
```

- [ ] **Step 2: Documents section** (5 fixed slots)

```javascript
const OPG_DOC_SLOTS = [
  { key: 'proforma_url',         label: 'Proforma Invoice' },
  { key: 'k3_chit_url',          label: 'K3 Chit' },
  { key: 'airwaybill_url',       label: 'Airwaybill' },
  { key: 'official_invoice_url', label: 'Official Invoice' },
  { key: 'phyto_cert_url',       label: 'Phytosanitary Certificate' }
];

function opgRenderDocsSection(b) {
  const slots = OPG_DOC_SLOTS.map(s => {
    const url = b[s.key];
    const ext = url ? url.split('.').pop().toLowerCase() : '';
    const label = ext === 'pdf' ? 'PDF' : 'Image';
    return `
      <div class="opg-doc-slot">
        <div class="opg-doc-label">${s.label}</div>
        <div class="opg-doc-file">${url ? `<a href="${url}" target="_blank">${label} ↗</a>` : '<span class="muted">No file</span>'}</div>
        <div>
          <input type="file" id="opg-doc-${s.key}" accept="image/*,application/pdf" style="display:none" onchange="opgUploadDoc('${s.key}', this.files[0])" />
          <button class="btn btn-tiny" onclick="document.getElementById('opg-doc-${s.key}').click()">${url ? 'Replace' : 'Upload'}</button>
          ${url ? `<button class="btn btn-tiny danger" onclick="opgClearDoc('${s.key}')">Remove</button>` : ''}
        </div>
      </div>
    `;
  }).join('');

  document.getElementById('opg-docs-section').innerHTML = `
    <div class="opg-section">
      <h3>Documents</h3>
      ${slots}
    </div>
  `;
}

async function opgUploadDoc(field, file) {
  if (!file) return;
  const id = selectedBatchId;
  const slotKey = OPG_DOC_SLOTS.find(s => s.key === field).key.replace('_url', '');
  const path = `procurement/${id}/${slotKey}.${file.name.split('.').pop()}`;
  btnLoading(event && event.target, true);
  const upload = await sb.storage.from('oilpalm-photos').upload(path, file, { upsert: true, contentType: file.type });
  if (upload.error) { notify('Upload failed: ' + upload.error.message, 'error'); btnLoading(event && event.target, false); return; }
  const url = sb.storage.from('oilpalm-photos').getPublicUrl(path).data.publicUrl;
  const result = await sbMutate(sb.from('oilpalm_batches').update({ [field]: url }).eq('id', id).select());
  if (result === null) { btnLoading(event && event.target, false); return; }
  await loadBatches();
  renderBatchesTab();
  notify('Document uploaded', 'success');
}

async function opgClearDoc(field) {
  const id = selectedBatchId;
  const result = await sbMutate(sb.from('oilpalm_batches').update({ [field]: null }).eq('id', id).select());
  if (result === null) return;
  await loadBatches();
  renderBatchesTab();
  notify('Document removed', 'success');
}
```

- [ ] **Step 3: Verify**

On batch detail: upload a PDF as Proforma → verify "PDF ↗" link works (clicks through to public URL). Upload an image as K3 Chit → verify "Image ↗" link. Click Replace → uploads a new file. Click Remove → clears the slot.

Save Payment with date + amount + method + slip upload → verify slip link appears, refreshes correctly.

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): payment + documents sections on batch detail"
```

---

### Task 1.7: Batch detail — Receipt, Plant event, Transplant event

**Files:**
- Modify: `oilpalmgrowth.html` (replace `opgRenderReceiptSection` + `opgRenderMnSection` stubs; add Plant + Transplant + Mid-MN Cull modals)

- [ ] **Step 1: Receipt + Plant event**

```javascript
function opgRenderReceiptSection(b) {
  const planted = b.qty_planted || 0;
  document.getElementById('opg-receipt-section').innerHTML = `
    <div class="opg-section">
      <h3>Receipt + Planting</h3>
      ${b.status === 'received' && !b.date_planted
        ? `<p class="muted">Stage: Received. Record planting to advance to Pre-Nursery.</p>
           <button class="btn btn-primary" onclick="opgOpenPlantModal()">Record Planting</button>`
        : b.date_planted
        ? `<div class="form-grid">
             <label>Seeds Received <input value="${b.seeds_received || 0}" readonly /></label>
             <label>Seeds Damaged <input value="${b.seeds_damaged || 0}" readonly /></label>
             <label>Total Planted <input value="${planted}" readonly /></label>
             <label>Date Planted <input value="${fmtDateDM(b.date_planted)}" readonly /></label>
           </div>
           ${b.status === 'pre_nursery' ? `<button class="btn btn-primary" onclick="opgOpenTransplantModal()" style="margin-top:8px">Record Transplant (PN → MN)</button>` : ''}`
        : `<p class="muted">Awaiting delivery. Set Actual Delivery date in Procurement to advance.</p>`
      }
    </div>
  `;
}

function opgOpenPlantModal() {
  showModal(`
    <h3>Record Planting</h3>
    <p class="muted">Stage: Received → Pre-Nursery.</p>
    <div class="form-grid">
      <label>Seeds Received <input id="opg-plant-rcvd" type="number" min="1" /></label>
      <label>Seeds Damaged <input id="opg-plant-dmg" type="number" min="0" value="0" /></label>
      <label>Total Planted <input id="opg-plant-total" readonly /></label>
      <label>Date Planted <input id="opg-plant-date" type="date" value="${new Date().toISOString().slice(0,10)}" /></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opgSavePlantEvent()">Save</button>
    </div>
  `);
  const recompute = () => {
    const r = parseInt(document.getElementById('opg-plant-rcvd').value, 10) || 0;
    const d = parseInt(document.getElementById('opg-plant-dmg').value, 10) || 0;
    document.getElementById('opg-plant-total').value = Math.max(0, r - d);
  };
  document.getElementById('opg-plant-rcvd').addEventListener('input', recompute);
  document.getElementById('opg-plant-dmg').addEventListener('input', recompute);
}

async function opgSavePlantEvent() {
  const id = selectedBatchId;
  const rcvd = parseInt(document.getElementById('opg-plant-rcvd').value, 10);
  const dmg  = parseInt(document.getElementById('opg-plant-dmg').value, 10) || 0;
  const date = document.getElementById('opg-plant-date').value;
  if (!rcvd || rcvd < 1) { notify('Seeds Received required', 'error'); return; }
  if (dmg < 0 || dmg >= rcvd) { notify('Damaged must be between 0 and Received', 'error'); return; }
  if (!date) { notify('Date required', 'error'); return; }

  const planted = rcvd - dmg;

  const eventId = await dbNextId('OE');
  const evResult = await sbMutate(sb.from('oilpalm_batch_events').insert({
    id: eventId,
    batch_id: id,
    event_type: 'plant',
    qty: planted,
    event_date: date,
    logged_by: currentUser.username,
    notes: `Received ${rcvd}, damaged ${dmg}, planted ${planted}`
  }).select());
  if (evResult === null) return;

  const result = await sbMutate(sb.from('oilpalm_batches').update({
    status: 'pre_nursery',
    date_planted: date,
    seeds_received: rcvd,
    seeds_damaged: dmg,
    qty_planted: planted
  }).eq('id', id).select());
  if (result === null) return;

  await loadBatches();
  closeModal();
  renderBatchesTab();
  notify('Planting recorded — batch is now in Pre-Nursery', 'success');
}
```

- [ ] **Step 2: Transplant event**

```javascript
function opgOpenTransplantModal() {
  const b = batches.find(x => x.id === selectedBatchId);
  showModal(`
    <h3>Record Transplant (Pre-Nursery → Main Nursery)</h3>
    <p class="muted">Planted: ${b.qty_planted}</p>
    <div class="form-grid">
      <label>Culls (dead/abnormal) <input id="opg-tp-culls" type="number" min="0" value="0" /></label>
      <label>Multi-germination Extras <input id="opg-tp-extras" type="number" min="0" value="0" /></label>
      <label>MN Qty (calculated) <input id="opg-tp-mn" readonly /></label>
      <label>Date Transplanted <input id="opg-tp-date" type="date" value="${new Date().toISOString().slice(0,10)}" /></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opgSaveTransplantEvent()">Save</button>
    </div>
  `);
  const recompute = () => {
    const c = parseInt(document.getElementById('opg-tp-culls').value, 10) || 0;
    const e = parseInt(document.getElementById('opg-tp-extras').value, 10) || 0;
    document.getElementById('opg-tp-mn').value = Math.max(0, b.qty_planted - c + e);
  };
  document.getElementById('opg-tp-culls').addEventListener('input', recompute);
  document.getElementById('opg-tp-extras').addEventListener('input', recompute);
  recompute();
}

async function opgSaveTransplantEvent() {
  const id = selectedBatchId;
  const b  = batches.find(x => x.id === id);
  const culls   = parseInt(document.getElementById('opg-tp-culls').value, 10) || 0;
  const extras  = parseInt(document.getElementById('opg-tp-extras').value, 10) || 0;
  const date    = document.getElementById('opg-tp-date').value;
  const mn = Math.max(0, b.qty_planted - culls + extras);
  if (!date) { notify('Date required', 'error'); return; }

  const eventId = await dbNextId('OE');
  const evResult = await sbMutate(sb.from('oilpalm_batch_events').insert({
    id: eventId,
    batch_id: id,
    event_type: 'transplant',
    qty: mn,
    event_date: date,
    logged_by: currentUser.username,
    notes: `Culls ${culls}, extras ${extras}, MN qty ${mn}`
  }).select());
  if (evResult === null) return;

  const result = await sbMutate(sb.from('oilpalm_batches').update({
    status: 'main_nursery',
    date_transplanted: date,
    transplant_culls: culls,
    transplant_extras: extras,
    qty_mn_start: mn
  }).eq('id', id).select());
  if (result === null) return;

  await loadBatches();
  closeModal();
  renderBatchesTab();
  notify('Transplant recorded — batch is now in Main Nursery', 'success');
}
```

- [ ] **Step 3: Verify**

On a batch in Received stage: click "Record Planting" → modal opens. Enter received=10000, damaged=121 → Total Planted shows 9879. Save → stage flips to Pre-Nursery, fields show 10000/121/9879. Click "Record Transplant" → modal opens with Planted=9879. Enter culls=200, extras=50 → MN qty = 9729. Save → stage flips to Main Nursery.

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): plant + transplant events"
```

---

### Task 1.8: Batch detail — Mid-MN cull events + stage transitions

**Files:**
- Modify: `oilpalmgrowth.html` (replace `opgRenderMnSection`, `opgMarkSelling`, `opgCloseBatch` + add Mid-MN cull modal)

- [ ] **Step 1: Mid-MN cull section + stage actions**

```javascript
async function opgRenderMnSection(b) {
  if (!['main_nursery', 'selling', 'sold_out'].includes(b.status)) {
    document.getElementById('opg-mn-section').innerHTML = '';
    return;
  }

  const events = await sbQuery(sb.from('oilpalm_batch_events').select('*').eq('batch_id', b.id).eq('event_type', 'cull').order('event_date', { ascending: false }));
  const cullEvents = events || [];
  const totalCulls = cullEvents.reduce((s, e) => s + (e.qty || 0), 0);
  const collected  = collectionsByBatch[b.id] || 0;
  const available  = Math.max(0, (b.qty_mn_start || 0) - totalCulls - collected);

  document.getElementById('opg-mn-section').innerHTML = `
    <div class="opg-section">
      <h3>Main Nursery — Counts & Culls</h3>
      <div class="opg-mn-summary">
        <div><strong>MN Start:</strong> ${b.qty_mn_start || 0}</div>
        <div><strong>Mid-MN Culls:</strong> ${totalCulls}</div>
        <div><strong>Collected:</strong> ${collected}</div>
        <div><strong>Available:</strong> ${available}</div>
      </div>
      <button class="btn btn-tiny" onclick="opgOpenCullModal()">+ Add Cull Event</button>
      <table class="data-table" style="margin-top:12px">
        <thead><tr><th>Date</th><th>Qty</th><th>Reason</th><th>Logged By</th></tr></thead>
        <tbody>
          ${cullEvents.map(e => `
            <tr>
              <td>${fmtDateDM(e.event_date)}</td>
              <td>${e.qty}</td>
              <td>${esc(e.reason || e.notes || '—')}</td>
              <td>${esc(e.logged_by || '—')}</td>
            </tr>
          `).join('') || '<tr><td colspan="4" style="text-align:center;color:var(--muted)">No mid-MN culls.</td></tr>'}
        </tbody>
      </table>
    </div>
  `;
}

function opgOpenCullModal() {
  showModal(`
    <h3>Add Cull Event</h3>
    <div class="form-grid">
      <label>Qty Culled <input id="opg-cull-qty" type="number" min="1" /></label>
      <label>Reason <input id="opg-cull-reason" placeholder="dead, abnormal, etc." /></label>
      <label>Date <input id="opg-cull-date" type="date" value="${new Date().toISOString().slice(0,10)}" /></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opgSaveCullEvent()">Save</button>
    </div>
  `);
}

async function opgSaveCullEvent() {
  const id  = selectedBatchId;
  const qty = parseInt(document.getElementById('opg-cull-qty').value, 10);
  const reason = document.getElementById('opg-cull-reason').value.trim();
  const date   = document.getElementById('opg-cull-date').value;
  if (!qty || qty < 1) { notify('Qty required', 'error'); return; }
  if (!date)           { notify('Date required', 'error'); return; }

  const eventId = await dbNextId('OE');
  const result = await sbMutate(sb.from('oilpalm_batch_events').insert({
    id: eventId,
    batch_id: id,
    event_type: 'cull',
    qty,
    reason: reason || null,
    event_date: date,
    logged_by: currentUser.username
  }).select());
  if (result === null) return;

  await loadMidCullAggregates();
  closeModal();
  renderBatchesTab();
  notify('Cull recorded', 'success');
}

async function opgMarkSelling() {
  const id = selectedBatchId;
  const b  = batches.find(x => x.id === id);
  if (b.status !== 'main_nursery') return;
  const ok = await confirmAction('Mark batch as Selling? Bookings can now collect from this batch.', 'Confirm');
  if (!ok) return;

  // Prompt for default selling price
  showModal(`
    <h3>Set Default Selling Price</h3>
    <p class="muted">This is the per-seedling default. Bookings can override per-customer.</p>
    <label>Default Price (RM) <input id="opg-sell-price" type="number" step="0.01" min="0" /></label>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opgConfirmMarkSelling()">Mark as Selling</button>
    </div>
  `);
}

async function opgConfirmMarkSelling() {
  const id    = selectedBatchId;
  const price = parseFloat(document.getElementById('opg-sell-price').value);
  if (!price || price <= 0) { notify('Default price must be positive', 'error'); return; }
  const result = await sbMutate(sb.from('oilpalm_batches').update({ status: 'selling', default_price: price }).eq('id', id).select());
  if (result === null) return;
  await loadBatches();
  closeModal();
  renderBatchesTab();
  notify('Batch is now Selling', 'success');
}

async function opgCloseBatch() {
  const id = selectedBatchId;
  const b  = batches.find(x => x.id === id);
  const collected = collectionsByBatch[id] || 0;
  const midCulls  = midCullsByBatch[id] || 0;
  const remaining = Math.max(0, (b.qty_mn_start || 0) - midCulls - collected);

  const ok = await confirmAction(
    `Close this batch?<br/><br/>Remaining ${remaining} seedlings will be recorded as a final cull (reason: "Batch closed — leftover").<br/><br/>This cannot be undone.`,
    'Close Batch'
  );
  if (!ok) return;

  if (remaining > 0) {
    const eventId = await dbNextId('OE');
    const evResult = await sbMutate(sb.from('oilpalm_batch_events').insert({
      id: eventId, batch_id: id, event_type: 'cull', qty: remaining,
      reason: 'Batch closed — leftover', event_date: new Date().toISOString().slice(0,10),
      logged_by: currentUser.username
    }).select());
    if (evResult === null) return;
  }
  const result = await sbMutate(sb.from('oilpalm_batches').update({
    status: 'closed', closed_at: new Date().toISOString(), closed_by: currentUser.username
  }).eq('id', id).select());
  if (result === null) return;

  await loadBatches();
  await loadMidCullAggregates();
  renderBatchesTab();
  notify('Batch closed', 'success');
}
```

- [ ] **Step 2: Auto sold_out flip — add helper that runs after collections**

In `loadCollectionAggregates`, after summing, scan batches in `selling` status whose `available === 0` and flip them to `sold_out`:
```javascript
async function autoFlipSoldOut() {
  for (const b of batches.filter(x => x.status === 'selling')) {
    const midC = midCullsByBatch[b.id] || 0;
    const col  = collectionsByBatch[b.id] || 0;
    const avail = (b.qty_mn_start || 0) - midC - col;
    if (avail <= 0) {
      await sbMutate(sb.from('oilpalm_batches').update({ status: 'sold_out' }).eq('id', b.id).select());
    }
  }
}
```

Call it after `loadCollectionAggregates()`:
```javascript
async function loadCollectionAggregates() {
  // ... existing code ...
  await autoFlipSoldOut();  // chained after sums recalculated
}
```

This won't fire on page-load because batches list loads in parallel; safe to also call after collections inserted (in Sales module, Task 3.7 / 3.10).

- [ ] **Step 3: Verify**

On MN-stage batch: open detail → MN section shows summary line + cull table empty + Add Cull button. Add a cull event (qty=10, reason="dead"). Verify it appears in the table, totalCulls increments, available decrements.

Click "Mark as Selling" → confirm modal → price modal → enter 6.50 → save. Stage flips to Selling.

Click "Close Batch" on an MN batch → confirm modal warns about remaining count → close. Stage flips to Closed, a final cull event is created.

- [ ] **Step 4: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): mid-MN cull events + selling/closed transitions"
```

---

## Phase 2 — Growth Module Reports

### Task 2.1: Procurement Summary report

**Files:**
- Modify: `oilpalmgrowth.html` (replace `renderReportsTab` stub)

- [ ] **Step 1: Implement reports tab with two report types**

```javascript
let reportsState = { type: 'procurement', from: '', to: '', supplier: 'all', variety: 'all' };

function renderReportsTab() {
  const today = new Date().toISOString().slice(0,10);
  const ago90 = new Date(Date.now() - 90*86400000).toISOString().slice(0,10);
  if (!reportsState.from) reportsState.from = ago90;
  if (!reportsState.to)   reportsState.to   = today;

  document.getElementById('tab-reports').innerHTML = `
    <div class="page-header"><h2>Reports</h2></div>
    <div class="filters-bar">
      <select id="opg-rpt-type" onchange="reportsState.type=this.value; renderReportsTab()">
        <option value="procurement" ${reportsState.type==='procurement'?'selected':''}>Procurement Summary</option>
        <option value="lifecycle"   ${reportsState.type==='lifecycle'?'selected':''}>Batch Lifecycle</option>
      </select>
      <input type="date" id="opg-rpt-from" value="${reportsState.from}" onchange="reportsState.from=this.value" />
      <input type="date" id="opg-rpt-to"   value="${reportsState.to}"   onchange="reportsState.to=this.value" />
      <select id="opg-rpt-sup" onchange="reportsState.supplier=this.value">
        <option value="all">All suppliers</option>
        ${suppliers.map(s => `<option value="${s.id}" ${reportsState.supplier===s.id?'selected':''}>${esc(s.name)}</option>`).join('')}
      </select>
      <select id="opg-rpt-var" onchange="reportsState.variety=this.value">
        <option value="all">All varieties</option>
        ${varieties.map(v => `<option value="${v.id}" ${reportsState.variety===v.id?'selected':''}>${esc(v.name)}</option>`).join('')}
      </select>
      <button class="btn btn-primary" onclick="opgRunReport()">Run</button>
      <button class="btn" onclick="window.print()">Print</button>
      <button class="btn" onclick="opgExportReportCsv()">CSV</button>
    </div>
    <div id="opg-rpt-output"></div>
  `;
}

function opgRunReport() {
  if (reportsState.type === 'procurement') opgRunProcurementReport();
  else opgRunLifecycleReport();
}

function opgRunProcurementReport() {
  const supplierMap = Object.fromEntries(suppliers.map(s => [s.id, s.name]));
  const varietyMap  = Object.fromEntries(varieties.map(v => [v.id, v.name]));
  const filtered = batches.filter(b => {
    if (b.order_date < reportsState.from || b.order_date > reportsState.to) return false;
    if (reportsState.supplier !== 'all' && b.supplier_id !== reportsState.supplier) return false;
    if (reportsState.variety  !== 'all' && b.variety_id  !== reportsState.variety)  return false;
    return true;
  });

  const totalQty   = filtered.reduce((s, b) => s + (b.ordered_qty || 0), 0);
  const totalSpent = filtered.reduce((s, b) => s + (b.total_cost || 0), 0);

  document.getElementById('opg-rpt-output').innerHTML = `
    <h3>Procurement Summary (${fmtDateDM(reportsState.from)} – ${fmtDateDM(reportsState.to)})</h3>
    <table class="data-table">
      <thead><tr>
        <th>Order Date</th><th>Batch #</th><th>Supplier</th><th>Variety</th>
        <th>Ordered Qty</th><th>Unit Cost</th><th>Total Cost</th><th>Stage</th><th>Delivery</th>
      </tr></thead>
      <tbody>
        ${filtered.map(b => `
          <tr>
            <td>${fmtDateDM(b.order_date)}</td>
            <td>${esc(b.batch_number)}</td>
            <td>${esc(supplierMap[b.supplier_id] || '—')}</td>
            <td>${esc(varietyMap[b.variety_id] || '—')}</td>
            <td>${b.ordered_qty || 0}</td>
            <td>RM ${(b.unit_cost || 0).toFixed(2)}</td>
            <td>RM ${(b.total_cost || 0).toFixed(2)}</td>
            <td>${stageLabel(b.status)}</td>
            <td>${b.actual_delivery_date ? fmtDateDM(b.actual_delivery_date) : (b.estimated_delivery_date ? 'Est: ' + fmtDateDM(b.estimated_delivery_date) : '—')}</td>
          </tr>
        `).join('') || '<tr><td colspan="9" style="text-align:center;color:var(--muted)">No batches in range.</td></tr>'}
      </tbody>
      <tfoot><tr>
        <td colspan="4"><strong>Total</strong></td>
        <td><strong>${totalQty}</strong></td>
        <td></td>
        <td><strong>RM ${totalSpent.toFixed(2)}</strong></td>
        <td colspan="2"></td>
      </tr></tfoot>
    </table>
  `;
}

function opgExportReportCsv() {
  // Generic: scrape the rendered table and convert
  const table = document.querySelector('#opg-rpt-output table');
  if (!table) { notify('Run a report first', 'error'); return; }
  const rows = [...table.querySelectorAll('tr')].map(tr =>
    [...tr.querySelectorAll('th,td')].map(td => `"${(td.textContent || '').replace(/"/g, '""').trim()}"`).join(',')
  ).join('\n');
  const blob = new Blob([rows], { type: 'text/csv' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `oilpalm-${reportsState.type}-${reportsState.from}-${reportsState.to}.csv`;
  a.click();
}
```

- [ ] **Step 2: Verify**

Switch to Reports tab → Procurement Summary loads with default 90-day range. Click Run → table shows batches in range. Filter by supplier → Run → table updates. Click CSV → downloads file with the same data.

- [ ] **Step 3: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): procurement summary report"
```

---

### Task 2.2: Batch Lifecycle report

**Files:**
- Modify: `oilpalmgrowth.html` (add `opgRunLifecycleReport`)

- [ ] **Step 1: Implement lifecycle report**

```javascript
async function opgRunLifecycleReport() {
  const supplierMap = Object.fromEntries(suppliers.map(s => [s.id, s.name]));
  const varietyMap  = Object.fromEntries(varieties.map(v => [v.id, v.name]));
  const filtered = batches.filter(b => {
    if (b.order_date < reportsState.from || b.order_date > reportsState.to) return false;
    if (reportsState.supplier !== 'all' && b.supplier_id !== reportsState.supplier) return false;
    if (reportsState.variety  !== 'all' && b.variety_id  !== reportsState.variety)  return false;
    return true;
  });

  // Pull all batch events for the filtered batches in one query
  const ids = filtered.map(b => b.id);
  const events = ids.length
    ? (await sbQuery(sb.from('oilpalm_batch_events').select('*').in('batch_id', ids).order('event_date', { ascending: true })) || [])
    : [];
  const eventsByBatch = Object.fromEntries(ids.map(id => [id, events.filter(e => e.batch_id === id)]));

  document.getElementById('opg-rpt-output').innerHTML = `
    <h3>Batch Lifecycle (${fmtDateDM(reportsState.from)} – ${fmtDateDM(reportsState.to)})</h3>
    ${filtered.map(b => {
      const evs = eventsByBatch[b.id] || [];
      const collected = collectionsByBatch[b.id] || 0;
      const midCulls  = midCullsByBatch[b.id] || 0;
      const leftover  = Math.max(0, (b.qty_mn_start || 0) - midCulls - collected);
      return `
        <div class="opg-lifecycle-block" style="margin-bottom:24px;padding:14px;border:1px solid var(--border);border-radius:6px">
          <h4>${esc(b.batch_number)} · ${esc(supplierMap[b.supplier_id] || '—')} · ${esc(varietyMap[b.variety_id] || '—')} · <span class="opg-stage-badge opg-stage-${b.status}">${stageLabel(b.status)}</span></h4>
          <table class="data-table">
            <thead><tr><th>Stage</th><th>Date</th><th>Qty</th><th>Notes</th></tr></thead>
            <tbody>
              <tr><td>Ordered</td><td>${fmtDateDM(b.order_date)}</td><td>${b.ordered_qty || 0}</td><td>—</td></tr>
              ${b.actual_delivery_date ? `<tr><td>Received</td><td>${fmtDateDM(b.actual_delivery_date)}</td><td>—</td><td>—</td></tr>` : ''}
              ${b.date_planted ? `<tr><td>Planted</td><td>${fmtDateDM(b.date_planted)}</td><td>${b.qty_planted || 0}</td><td>${b.seeds_received} received, ${b.seeds_damaged} damaged</td></tr>` : ''}
              ${b.date_transplanted ? `<tr><td>MN Start</td><td>${fmtDateDM(b.date_transplanted)}</td><td>${b.qty_mn_start || 0}</td><td>${b.transplant_culls} culls, ${b.transplant_extras} extras</td></tr>` : ''}
              ${evs.filter(e => e.event_type === 'cull').map(e => `<tr><td>Mid-MN Cull</td><td>${fmtDateDM(e.event_date)}</td><td>-${e.qty}</td><td>${esc(e.reason || e.notes || '—')}</td></tr>`).join('')}
              ${collected > 0 ? `<tr><td>Sold</td><td>—</td><td>-${collected}</td><td>Across ${(events.filter(e=>e.batch_id===b.id).length)} events</td></tr>` : ''}
              ${b.closed_at ? `<tr><td>Closed</td><td>${fmtDateDM(b.closed_at)}</td><td>-${leftover}</td><td>Leftover at close</td></tr>` : ''}
            </tbody>
          </table>
        </div>
      `;
    }).join('') || '<p class="muted">No batches in range.</p>'}
  `;
}
```

- [ ] **Step 2: Verify**

Switch to Reports → select "Batch Lifecycle" → Run. For each batch in range, see a block showing its full timeline. Make sure dates render in DD/MM/YYYY (or DD/MM/YY per project convention — confirm `fmtDateDM` matches).

- [ ] **Step 3: Commit + deploy Phase 1+2**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): batch lifecycle report"

# Deploy
npx netlify-cli deploy --prod --dir=. --functions=netlify/functions --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26
```

- [ ] **Step 4: Verify deployed**

```bash
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "opg-stage-badge"
# Expected: 7+ (one per stage label in CSS + render calls)
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "opgRunLifecycleReport"
# Expected: 2 (declaration + call site)
```

---

## Phase 3 — Sales Module Foundation

### Task 3.1: Create empty `oilpalmsales.html` shell

**Files:**
- Create: `oilpalmsales.html`
- Create: `oilpalmsales.css`

- [ ] **Step 1: Write the HTML shell**

Same scaffold as `oilpalmgrowth.html` Task 1.1, but:
- Title: "Oil Palm Sales — TG FarmHub"
- Sidebar tabs: `Summary` · `Bookings` · `Collections` · `Customers` · `Reports`
- Default tab: `summary`
- Loaders: `loadCustomers`, `loadBookings`, `loadCollections`, `loadPayments`, `loadBatches` (read-only — sales can't create batches), `loadVarieties`, `loadSuppliers` (for customer detail join only)
- The `loadBatches` here MUST also pull `qty_mn_start`, `qty_planted`, `default_price`, `bookable_pct`, `status` so we can compute Available client-side without a join

Render stubs:
```javascript
function renderSummaryTab()     { document.getElementById('tab-summary').innerHTML = '<p>Summary — TODO</p>'; }
function renderBookingsTab()    { document.getElementById('tab-bookings').innerHTML = '<p>Bookings — TODO</p>'; }
function renderCollectionsTab() { document.getElementById('tab-collections').innerHTML = '<p>Collections — TODO</p>'; }
function renderCustomersTab()   { document.getElementById('tab-customers').innerHTML = '<p>Customers — TODO</p>'; }
function renderReportsTab()     { document.getElementById('tab-reports').innerHTML = '<p>Reports — TODO</p>'; }
```

- [ ] **Step 2: Stub `oilpalmsales.css`**

```css
/* Oil Palm Sales — module-specific styles */
.ops-status-badge {
  display: inline-block; padding: 2px 10px; border-radius: 3px;
  font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px;
}
.ops-status-active     { background: rgba(74, 124, 63, 0.20); color: #2D5224; }
.ops-status-partial    { background: rgba(212, 175, 55, 0.22); color: #8A6D1F; }
.ops-status-completed  { background: rgba(80, 80, 80, 0.20); color: #333; }
.ops-status-cancelled  { background: rgba(196, 64, 64, 0.18); color: #8A2828; }
.ops-status-refund-pending { background: rgba(255, 140, 40, 0.20); color: #C96A1A; }

.ops-summary-card {
  background: var(--bg-card); border: 1px solid var(--border); border-radius: 6px;
  padding: 14px 18px; min-width: 160px;
}
.ops-summary-card .label { font-size: 11px; text-transform: uppercase; color: var(--muted); }
.ops-summary-card .value { font-size: 24px; font-weight: 700; color: #2A1A3E; margin-top: 4px; }
```

- [ ] **Step 3: Verify the shell loads**

Open `oilpalmsales.html?session=<user_id>` → 5 tabs render, each shows "TODO" stub.

- [ ] **Step 4: Commit**

```bash
git add oilpalmsales.html oilpalmsales.css
git commit -m "feat(oilpalm-sales): scaffold sales module shell"
```

---

### Task 3.2: Customers tab CRUD

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement Customers tab**

Mirror Task 1.2 (suppliers) pattern but for `oilpalm_customers`. Fields: name (required), contact_person, phone (intl-tel-input — load lib in head), address, customer_type (booking/walkin), notes.

Use phone helpers from `shared.js`: `fmtPhone`, `phoneCanonical`, `phoneDigitsOnly`. For phone input, lazy-init `intlTelInput` per the sales-module pattern (CDN `intlTelInputWithUtils.min.js`).

Add to `<head>`:
```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/intl-tel-input@23.0.7/build/css/intlTelInput.css" />
<script src="https://cdn.jsdelivr.net/npm/intl-tel-input@23.0.7/build/js/intlTelInputWithUtils.min.js"></script>
```

Customers table columns:
| # | Name | Type | Phone | Address | Total Booked | Total Collected | Outstanding | Actions |

"Total Booked / Collected / Outstanding" computed from `bookings` + `collections` + `payments` aggregates (cached in module state).

Render code (compressed; full pattern follows Task 1.2):
```javascript
function renderCustomersTab() {
  // ... build aggregates, render table, add modal (ocOpenCustomerModal),
  //     ocSaveCustomer (insert/update with phone validation), ocToggle ...
}
```

Phone modal pattern (lazy-init pre-fill):
```javascript
let opscPhoneIti = null;
function opsInitPhoneInput() {
  const input = document.getElementById('oc-phone');
  if (!input) return;
  opscPhoneIti = window.intlTelInput(input, {
    initialCountry: 'my',
    preferredCountries: ['my', 'sg', 'bn', 'id', 'th'],
    utilsScript: 'https://cdn.jsdelivr.net/npm/intl-tel-input@23.0.7/build/js/utils.js'
  });
}
```

- [ ] **Step 2: Verify**

Add a customer (booking type) with phone. Phone field shows country dropdown + Malaysia preselected. Save → row in customers table. Edit → phone pre-fills correctly via `setNumber`. Reload → state persists.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): customers CRUD"
```

---

### Task 3.3: Summary tab dashboard

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement Summary**

Replace `renderSummaryTab` stub:

```javascript
async function renderSummaryTab() {
  // Aggregates
  const pnTotal = batches.filter(b => b.status === 'pre_nursery').reduce((s, b) => s + (b.qty_planted || 0), 0);
  const mnTotal = batches.filter(b => b.status === 'main_nursery').reduce((s, b) => s + (b.qty_mn_start || 0), 0);
  const sellingBatches = batches.filter(b => b.status === 'selling');

  const collectedByBatch = {};
  collections.forEach(c => { collectedByBatch[c.batch_id] = (collectedByBatch[c.batch_id] || 0) + c.qty; });
  const bookedByBatch = {};
  bookings.filter(b => b.status === 'active').forEach(bk => {
    const collected = collections.filter(c => c.booking_id === bk.id).reduce((s, c) => s + c.qty, 0);
    bookedByBatch[bk.batch_id] = (bookedByBatch[bk.batch_id] || 0) + (bk.booked_qty - collected);
  });

  const sellingPerBatch = sellingBatches.map(b => {
    const collected = collectedByBatch[b.id] || 0;
    const booked    = bookedByBatch[b.id] || 0;
    const total     = b.qty_mn_start || 0;
    const available = Math.max(0, total - collected - booked);
    return { ...b, total, booked, collected, available };
  });
  const availableTotal = sellingPerBatch.reduce((s, b) => s + b.available, 0);

  // Active bookings
  const activeBks = bookings.filter(b => b.status === 'active');
  const activeQty = activeBks.reduce((s, b) => s + b.booked_qty, 0);
  const activePaid = activeBks.reduce((s, b) => s + (paymentsByBooking[b.id] || 0), 0);
  const activeTotal = activeBks.reduce((s, b) => s + b.total_amount, 0);
  const activeOwed = activeTotal - activePaid;

  // Today's activity
  const today = new Date().toISOString().slice(0, 10);
  const todaysCols = collections.filter(c => c.collection_date === today);
  const todaysCount = todaysCols.length;
  const todaysQty   = todaysCols.reduce((s, c) => s + c.qty, 0);

  document.getElementById('tab-summary').innerHTML = `
    <div class="page-header">
      <h2>Summary</h2>
      <div>
        <button class="btn btn-primary" onclick="opsOpenNewBookingModal()">+ New Booking</button>
        <button class="btn btn-primary" onclick="opsOpenWalkInModal()">+ New Walk-in Sale</button>
      </div>
    </div>

    <div style="display:flex; gap:14px; flex-wrap:wrap; margin-bottom:18px">
      <div class="ops-summary-card"><div class="label">Pre-Nursery</div><div class="value">${pnTotal}</div></div>
      <div class="ops-summary-card"><div class="label">Main Nursery</div><div class="value">${mnTotal}</div></div>
      <div class="ops-summary-card"><div class="label">Available (Total)</div><div class="value">${availableTotal}</div></div>
      <div class="ops-summary-card"><div class="label">Active Bookings</div><div class="value">${activeBks.length}</div><div class="muted">${activeQty} qty · RM ${activeOwed.toFixed(2)} owed</div></div>
      <div class="ops-summary-card"><div class="label">Today's Activity</div><div class="value">${todaysCount}</div><div class="muted">${todaysQty} seedlings collected</div></div>
    </div>

    <h3>Available for Sale (Per Batch)</h3>
    <table class="data-table">
      <thead><tr><th>Batch #</th><th>Variety</th><th>Total</th><th>Booked</th><th>Collected</th><th>Available</th><th>Ready Date</th></tr></thead>
      <tbody>
        ${sellingPerBatch.map(b => {
          const v = varieties.find(x => x.id === b.variety_id);
          const ready = b.date_planted ? addMonths(b.date_planted, 10) : null;
          return `<tr>
            <td>${esc(b.batch_number)}</td>
            <td>${esc(v?.name || '—')}</td>
            <td>${b.total}</td>
            <td>${b.booked}</td>
            <td>${b.collected}</td>
            <td><strong>${b.available}</strong></td>
            <td>${ready ? fmtDateDM(ready) : '—'}</td>
          </tr>`;
        }).join('') || '<tr><td colspan="7" style="text-align:center;color:var(--muted)">No batches in selling stage.</td></tr>'}
      </tbody>
    </table>
  `;
}
```

- [ ] **Step 2: Stub the New Booking + New Walk-in modals**

```javascript
function opsOpenNewBookingModal() { notify('TBD next task', 'info'); }
function opsOpenWalkInModal()      { notify('TBD next task', 'info'); }
```

- [ ] **Step 3: Verify**

Switch to Summary tab. Cards render with current state (likely 0s if no data yet). After Phase 1 batches exist with selling status, those appear in the per-batch table.

- [ ] **Step 4: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): summary dashboard"
```

---

### Task 3.4: Bookings list view

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement Bookings list**

Pattern matches Task 1.3 (Growth batches list). Filters: status (Active/Completed/Cancelled), customer (search), batch (dropdown).

Columns:
| Booking # | Customer | Batch | Booked / Collected / Remaining | Total | Paid | Balance | Status | Actions |

Status badge mapping: `active` → Active (green), `completed` → Completed (gray), `cancelled` (refund_status=`paid` or `forfeited`) → Cancelled (red), `cancelled` (refund_status=`pending`) → Refund Pending (orange).

Click row → `opsOpenBookingDetail(id)` (stubbed for next task).

- [ ] **Step 2: Verify**

Bookings tab loads with empty state. Filters render. Click any future row → "TBD" stub message.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): bookings list view"
```

---

### Task 3.5: New Booking modal

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement modal + save**

```javascript
async function opsOpenNewBookingModal() {
  const eligibleBatches = batches.filter(b => ['pre_nursery', 'main_nursery', 'selling'].includes(b.status));
  showModal(`
    <h3>New Booking</h3>
    <div class="form-grid">
      <label class="full">Customer
        <input id="ops-bk-cust-search" placeholder="Type to search..." oninput="opsSearchCustomers()" />
        <input type="hidden" id="ops-bk-cust-id" />
        <div id="ops-bk-cust-results"></div>
        <button class="btn btn-tiny" type="button" onclick="opsOpenInlineNewCustomer()">+ New Customer</button>
      </label>
      <label>Batch
        <select id="ops-bk-batch" onchange="opsBookingBatchChanged()">
          <option value="">— select —</option>
          ${eligibleBatches.map(b => {
            const v = varieties.find(x => x.id === b.variety_id);
            return `<option value="${b.id}" data-price="${b.default_price || 0}" data-mn="${b.qty_mn_start || 0}" data-pct="${b.bookable_pct || 50}">${esc(b.batch_number)} · ${esc(v?.name || '—')} · ${stageLabel(b.status)}</option>`;
          }).join('')}
        </select>
      </label>
      <label>Booked Qty <input id="ops-bk-qty" type="number" min="1" oninput="opsBookingRecalc()" /></label>
      <label>Unit Price (RM) <input id="ops-bk-price" type="number" step="0.01" min="0" oninput="opsBookingRecalc()" /></label>
      <label>Total Amount (RM) <input id="ops-bk-total" readonly /></label>
      <label class="full">Initial Payment (mandatory, > 0)</label>
      <label>Amount (RM) <input id="ops-bk-pay-amt" type="number" step="0.01" min="0.01" oninput="opsBookingRecalc()" /></label>
      <label>Method
        <select id="ops-bk-pay-method">
          <option value="cash">Cash</option>
          <option value="bank">Bank Transfer</option>
          <option value="cheque">Cheque</option>
        </select>
      </label>
      <label>Reference <input id="ops-bk-pay-ref" /></label>
      <label class="full">Slip <input type="file" id="ops-bk-pay-slip" accept="image/*,application/pdf" /></label>
      <div id="ops-bk-warning" class="warn-box" style="display:none"></div>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opsSaveNewBooking()">Create Booking</button>
    </div>
  `);
}

function opsBookingBatchChanged() {
  const sel = document.getElementById('ops-bk-batch');
  const opt = sel.options[sel.selectedIndex];
  const price = parseFloat(opt.dataset.price) || 0;
  document.getElementById('ops-bk-price').value = price.toFixed(2);
  opsBookingRecalc();
}

function opsBookingRecalc() {
  const sel  = document.getElementById('ops-bk-batch');
  const opt  = sel.options[sel.selectedIndex];
  const mn   = parseFloat(opt?.dataset?.mn || 0);
  const pct  = parseFloat(opt?.dataset?.pct || 50);
  const cap  = Math.floor(mn * pct / 100);
  const qty  = parseFloat(document.getElementById('ops-bk-qty').value) || 0;
  const px   = parseFloat(document.getElementById('ops-bk-price').value) || 0;
  document.getElementById('ops-bk-total').value = (qty * px).toFixed(2);

  // Existing booked + cap warning
  const existing = bookings.filter(b => b.batch_id === sel.value && b.status === 'active')
    .reduce((s, b) => s + (b.booked_qty - (collections.filter(c => c.booking_id === b.id).reduce((a, c) => a + c.qty, 0))), 0);
  const totalIfThis = existing + qty;
  const warn = document.getElementById('ops-bk-warning');
  if (qty > 0 && totalIfThis > cap) {
    warn.style.display = 'block';
    warn.innerHTML = `⚠️ This booking would push total bookings to <strong>${totalIfThis}</strong> on a batch with cap <strong>${cap}</strong> (${pct}% of ${mn}). Save will require confirmation.`;
  } else {
    warn.style.display = 'none';
  }
}

async function opsSaveNewBooking() {
  const custId  = document.getElementById('ops-bk-cust-id').value;
  const batchId = document.getElementById('ops-bk-batch').value;
  const qty     = parseInt(document.getElementById('ops-bk-qty').value, 10);
  const price   = parseFloat(document.getElementById('ops-bk-price').value);
  const total   = parseFloat(document.getElementById('ops-bk-total').value);
  const payAmt  = parseFloat(document.getElementById('ops-bk-pay-amt').value);
  const payMethod = document.getElementById('ops-bk-pay-method').value;
  const payRef  = document.getElementById('ops-bk-pay-ref').value.trim();
  const slipFile = document.getElementById('ops-bk-pay-slip').files[0];

  if (!custId)             { notify('Customer required', 'error'); return; }
  if (!batchId)            { notify('Batch required', 'error'); return; }
  if (!qty || qty < 1)     { notify('Qty required', 'error'); return; }
  if (!price || price <= 0){ notify('Unit price must be positive', 'error'); return; }
  if (!payAmt || payAmt <= 0) { notify('Initial payment must be > 0 (zero-deposit not allowed)', 'error'); return; }

  // Cap warning override
  const warn = document.getElementById('ops-bk-warning');
  if (warn.style.display === 'block') {
    const ok = await confirmAction('This exceeds the bookable cap. Continue anyway?', 'Override Cap');
    if (!ok) return;
  }

  const bookingId = await dbNextId('OK');
  if (!bookingId) { notify('ID gen failed', 'error'); return; }

  const bkResult = await sbMutate(sb.from('oilpalm_bookings').insert({
    id: bookingId,
    company_id: getCompanyId(),
    customer_id: custId,
    batch_id: batchId,
    booked_qty: qty,
    unit_price: price,
    total_amount: total,
    booking_date: new Date().toISOString().slice(0,10),
    status: 'active'
  }).select());
  if (bkResult === null) return;

  // Initial payment
  let slipUrl = null;
  if (slipFile) {
    const path = `payments/${bookingId}/initial.${slipFile.name.split('.').pop()}`;
    const up = await sb.storage.from('oilpalm-photos').upload(path, slipFile, { upsert: true, contentType: slipFile.type });
    if (!up.error) slipUrl = sb.storage.from('oilpalm-photos').getPublicUrl(path).data.publicUrl;
  }
  const payId = await dbNextId('OP');
  await sbMutate(sb.from('oilpalm_payments').insert({
    id: payId, booking_id: bookingId, amount: payAmt, method: payMethod,
    payment_date: new Date().toISOString().slice(0,10),
    reference: payRef || null, slip_url: slipUrl,
    logged_by: currentUser.username
  }).select());

  await Promise.all([loadBookings(), loadPayments()]);
  closeModal();
  renderBookingsTab();
  notify('Booking created', 'success');
}
```

Implement `opsSearchCustomers()`, `opsOpenInlineNewCustomer()` per the sales.html pattern (live filter on customers array; inline-add modal that returns to bookings flow).

- [ ] **Step 2: Verify**

Open New Booking. Search for customer → list filters live. Pick batch → unit price auto-populates from `default_price`. Enter qty → total recomputes. Try qty > 50% of MN → warning banner appears. Override → save. New booking appears in Bookings list with Active status, balance = total − initial payment.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): new booking modal with cap warning"
```

---

### Task 3.6: Booking detail page

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Booking detail layout**

Mirror Task 1.5 (batch detail). Sections:

1. **Customer info** (read-only; edit goes to Customers tab)
2. **Booking summary** — current batch, qty (booked/collected/remaining), unit price, total, total paid, balance, status badge
3. **Payments** — table + `+ Add Payment` button (modal: amount, method, ref, slip, date)
4. **Collections** — table of collections with L3.1 #, photos, plate, date, qty + `+ Record Collection` button
5. **Reassignment history** (JSONB array, render as table if non-empty)
6. **Action buttons** — `Reassign to Another Batch` (only if zero collections), `Cancel Booking`, `Print/Share Booking Slip`

`opsRenderBookingDetail(id)` builds the layout. State var `selectedBookingId`.

- [ ] **Step 2: Add Payment modal**

```javascript
async function opsAddPaymentModal() { /* amount + method + ref + slip + date; saves to oilpalm_payments with booking_id=selectedBookingId */ }
```

- [ ] **Step 3: Verify**

Click a booking row → detail page renders. Customer info correct. Add a payment → it appears in payments table, balance updates. Cancel button etc. stubbed for next task.

- [ ] **Step 4: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): booking detail page + add payment"
```

---

### Task 3.7: Record Collection modal (booking-driven, with all guardrails)

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement collection modal**

```javascript
async function opsOpenRecordCollectionModal(bookingId) {
  const bk = bookings.find(b => b.id === bookingId);
  if (!bk) return;
  const batch = batches.find(b => b.id === bk.batch_id);
  if (batch.status !== 'selling') { notify('Batch must be in Selling stage to collect', 'error'); return; }

  const collected = collections.filter(c => c.booking_id === bookingId).reduce((s, c) => s + c.qty, 0);
  const paid = paymentsByBooking[bookingId] || 0;
  const maxCollectable = Math.max(0, Math.floor(paid / bk.unit_price) - collected);

  showModal(`
    <h3>Record Collection</h3>
    <div class="muted" style="margin-bottom:8px">Booking ${esc(bk.id)} · ${bk.booked_qty} booked, ${collected} collected. Customer paid RM ${paid.toFixed(2)}, can collect ${maxCollectable} more.</div>
    <div class="form-grid">
      <label>Quantity <input id="ops-col-qty" type="number" min="1" max="${bk.booked_qty - collected}" /></label>
      <label>L3.1 Form # <input id="ops-col-l3" /></label>
      <label class="full">L3.1 Photo <input type="file" id="ops-col-l3-photo" accept="image/*,application/pdf" /></label>
      <label class="full">Collection Photo <input type="file" id="ops-col-photo" accept="image/*" /></label>
      <label>Car Plate # <input id="ops-col-plate" /></label>
      <label>Date <input id="ops-col-date" type="date" value="${new Date().toISOString().slice(0,10)}" /></label>
      <label class="full">Additional Payment Now (optional)</label>
      <label>Amount (RM) <input id="ops-col-pay-amt" type="number" step="0.01" min="0" /></label>
      <label>Method <select id="ops-col-pay-method"><option value="">—</option><option value="cash">Cash</option><option value="bank">Bank</option><option value="cheque">Cheque</option></select></label>
      <label>Reference <input id="ops-col-pay-ref" /></label>
      <label class="full">Slip <input type="file" id="ops-col-pay-slip" accept="image/*,application/pdf" /></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opsSaveCollection('${bookingId}')">Save</button>
    </div>
  `);
}

async function opsSaveCollection(bookingId) {
  const qty   = parseInt(document.getElementById('ops-col-qty').value, 10);
  const l3    = document.getElementById('ops-col-l3').value.trim();
  const l3Photo = document.getElementById('ops-col-l3-photo').files[0];
  const colPhoto = document.getElementById('ops-col-photo').files[0];
  const plate = document.getElementById('ops-col-plate').value.trim();
  const date  = document.getElementById('ops-col-date').value;
  const payAmt    = parseFloat(document.getElementById('ops-col-pay-amt').value) || 0;
  const payMethod = document.getElementById('ops-col-pay-method').value;
  const payRef    = document.getElementById('ops-col-pay-ref').value.trim();
  const paySlip   = document.getElementById('ops-col-pay-slip').files[0];

  if (!qty || qty < 1) { notify('Qty required', 'error'); return; }
  if (!l3)      { notify('L3.1 Form # required', 'error'); return; }
  if (!l3Photo) { notify('L3.1 Photo required', 'error'); return; }
  if (!colPhoto){ notify('Collection Photo required', 'error'); return; }
  if (!plate)   { notify('Plate # required', 'error'); return; }
  if (!date)    { notify('Date required', 'error'); return; }

  // L3.1 dup check
  const dup = await sbQuery(sb.from('oilpalm_collections').select('id').eq('l3_form_no', l3));
  if (dup && dup.length > 0) { notify(`L3.1 #${l3} was already used. Cannot reuse.`, 'error'); return; }

  // Compute payment-controlled cap (with optional payment factored in)
  const bk = bookings.find(b => b.id === bookingId);
  const collected = collections.filter(c => c.booking_id === bookingId).reduce((s, c) => s + c.qty, 0);
  const paid = (paymentsByBooking[bookingId] || 0) + payAmt;
  const maxCollectable = Math.floor(paid / bk.unit_price) - collected;
  if (qty > maxCollectable) {
    notify(`Customer paid for ${maxCollectable + collected} seedlings, already collected ${collected}, can collect ${maxCollectable} more. Either reduce qty or record more payment first.`, 'error');
    return;
  }

  // Generate collection ID
  const colId = await dbNextId('OL');
  if (!colId) { notify('ID gen failed', 'error'); return; }

  // Upload photos
  const ext1 = l3Photo.name.split('.').pop();
  const ext2 = colPhoto.name.split('.').pop();
  const u1 = await sb.storage.from('oilpalm-photos').upload(`collections/${colId}/l3.${ext1}`, l3Photo, { upsert: true, contentType: l3Photo.type });
  if (u1.error) { notify('L3 photo upload failed: ' + u1.error.message, 'error'); return; }
  const u2 = await sb.storage.from('oilpalm-photos').upload(`collections/${colId}/seedlings.${ext2}`, colPhoto, { upsert: true, contentType: colPhoto.type });
  if (u2.error) { notify('Collection photo upload failed: ' + u2.error.message, 'error'); return; }
  const l3Url  = sb.storage.from('oilpalm-photos').getPublicUrl(`collections/${colId}/l3.${ext1}`).data.publicUrl;
  const colUrl = sb.storage.from('oilpalm-photos').getPublicUrl(`collections/${colId}/seedlings.${ext2}`).data.publicUrl;

  // Insert payment FIRST if applicable (CS047 atomic pattern)
  if (payAmt > 0) {
    let slipUrl = null;
    if (paySlip) {
      const ext = paySlip.name.split('.').pop();
      const up = await sb.storage.from('oilpalm-photos').upload(`payments/${bookingId}/${colId}.${ext}`, paySlip, { upsert: true, contentType: paySlip.type });
      if (!up.error) slipUrl = sb.storage.from('oilpalm-photos').getPublicUrl(`payments/${bookingId}/${colId}.${ext}`).data.publicUrl;
    }
    const payId = await dbNextId('OP');
    const payResult = await sbMutate(sb.from('oilpalm_payments').insert({
      id: payId, booking_id: bookingId, collection_id: colId,
      amount: payAmt, method: payMethod || 'cash',
      payment_date: date, reference: payRef || null, slip_url: slipUrl,
      logged_by: currentUser.username
    }).select());
    if (payResult === null) { notify('Payment failed — collection not saved', 'error'); return; }
  }

  // Insert collection
  const colResult = await sbMutate(sb.from('oilpalm_collections').insert({
    id: colId,
    company_id: getCompanyId(),
    customer_id: bk.customer_id,
    booking_id: bookingId,
    batch_id: bk.batch_id,
    qty,
    unit_price: bk.unit_price,
    subtotal: qty * bk.unit_price,
    l3_form_no: l3,
    l3_photo_url: l3Url,
    collection_photo_url: colUrl,
    plate_no: plate,
    collection_date: date,
    logged_by: currentUser.username
  }).select());
  if (colResult === null) return;

  // Check if booking now complete
  const totalCollected = collected + qty;
  if (totalCollected >= bk.booked_qty) {
    await sbMutate(sb.from('oilpalm_bookings').update({ status: 'completed' }).eq('id', bookingId).select());
  }

  // Auto sold_out check on batch
  await opsAutoFlipSoldOutOnBatch(bk.batch_id);

  await Promise.all([loadCollections(), loadPayments(), loadBookings(), loadBatches()]);
  closeModal();
  renderBookingsTab();
  notify('Collection recorded — L3.1 ' + l3, 'success');
}

async function opsAutoFlipSoldOutOnBatch(batchId) {
  const b = batches.find(x => x.id === batchId);
  if (!b || b.status !== 'selling') return;
  const collected = collections.filter(c => c.batch_id === batchId).reduce((s, c) => s + c.qty, 0);
  const culls     = (await sbQuery(sb.from('oilpalm_batch_events').select('qty').eq('batch_id', batchId).eq('event_type', 'cull')) || []).reduce((s, e) => s + e.qty, 0);
  const avail = (b.qty_mn_start || 0) - culls - collected;
  if (avail <= 0) {
    await sbMutate(sb.from('oilpalm_batches').update({ status: 'sold_out' }).eq('id', batchId).select());
  }
}
```

- [ ] **Step 2: Verify**

On a booking with batch in Selling stage: click Record Collection → modal opens. Try qty > paid_for amount → error. Pay enough → qty allowed. Submit with L3.1 #001 → row appears in collections table. Try again with same L3.1 #001 → blocked with duplicate error.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): record collection modal with guardrails"
```

---

### Task 3.8: Reassign Batch + Cancel Booking + Refund flow

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Reassign modal**

```javascript
async function opsOpenReassignModal(bookingId) {
  const bk = bookings.find(b => b.id === bookingId);
  const collected = collections.filter(c => c.booking_id === bookingId).length;
  if (collected > 0) { notify('Cannot reassign — collections already issued. Cancel & re-book.', 'error'); return; }

  const eligibleBatches = batches.filter(b => b.id !== bk.batch_id && ['pre_nursery', 'main_nursery', 'selling'].includes(b.status));
  const currentBatch = batches.find(b => b.id === bk.batch_id);

  showModal(`
    <h3>Reassign Booking to Another Batch</h3>
    <p class="muted">Current: ${esc(currentBatch.batch_number)} at RM ${(bk.unit_price).toFixed(2)}/seedling</p>
    <div class="form-grid">
      <label>New Batch
        <select id="ops-rsg-batch" onchange="opsRsgPriceChanged()">
          <option value="">— select —</option>
          ${eligibleBatches.map(b => {
            const v = varieties.find(x => x.id === b.variety_id);
            return `<option value="${b.id}" data-price="${b.default_price || 0}">${esc(b.batch_number)} · ${esc(v?.name || '—')} · ${stageLabel(b.status)} · RM ${(b.default_price || 0).toFixed(2)}/each</option>`;
          }).join('')}
        </select>
      </label>
      <label>Pricing
        <select id="ops-rsg-price-mode">
          <option value="keep">Keep current RM ${(bk.unit_price).toFixed(2)}</option>
          <option value="new">Use new batch's default price</option>
        </select>
      </label>
      <label class="full">Reason <textarea id="ops-rsg-reason"></textarea></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opsSaveReassign('${bookingId}')">Reassign</button>
    </div>
  `);
}
function opsRsgPriceChanged() { /* updates the "new" option label with the actual price for clarity */ }

async function opsSaveReassign(bookingId) {
  const newBatchId = document.getElementById('ops-rsg-batch').value;
  const priceMode  = document.getElementById('ops-rsg-price-mode').value;
  const reason     = document.getElementById('ops-rsg-reason').value.trim();
  if (!newBatchId) { notify('Select a batch', 'error'); return; }

  const bk = bookings.find(b => b.id === bookingId);
  const newBatch = batches.find(b => b.id === newBatchId);
  const newPrice = priceMode === 'keep' ? bk.unit_price : (newBatch.default_price || bk.unit_price);
  const newTotal = bk.booked_qty * newPrice;

  const history = Array.isArray(bk.reassignment_history) ? [...bk.reassignment_history] : [];
  history.push({
    from_batch: bk.batch_id, to_batch: newBatchId,
    date: new Date().toISOString(), by_user: currentUser.username,
    reason, kept_price: priceMode === 'keep', old_price: bk.unit_price, new_price: newPrice
  });

  const result = await sbMutate(sb.from('oilpalm_bookings').update({
    batch_id: newBatchId,
    unit_price: newPrice,
    total_amount: newTotal,
    reassignment_history: history
  }).eq('id', bookingId).select());
  if (result === null) return;
  await loadBookings();
  closeModal();
  renderBookingsTab();
  notify('Booking reassigned to ' + newBatch.batch_number, 'success');
}
```

- [ ] **Step 2: Cancel modal**

```javascript
async function opsOpenCancelModal(bookingId) {
  const bk = bookings.find(b => b.id === bookingId);
  const paid = paymentsByBooking[bookingId] || 0;
  const collected = collections.filter(c => c.booking_id === bookingId).reduce((s, c) => s + c.qty, 0);
  const usedValue = collected * bk.unit_price;
  const owed = Math.max(0, paid - usedValue);

  showModal(`
    <h3>Cancel Booking</h3>
    <p>Customer paid RM ${paid.toFixed(2)}, collected ${collected} seedlings (value RM ${usedValue.toFixed(2)}).</p>
    <p>Refund owed: <strong>RM ${owed.toFixed(2)}</strong></p>
    <div class="form-grid">
      <label class="full">Cancel Reason <textarea id="ops-cnc-reason"></textarea></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Don't cancel</button>
      <button class="btn danger" onclick="opsSaveCancel('${bookingId}', ${owed})">Cancel Booking</button>
    </div>
  `);
}

async function opsSaveCancel(bookingId, owed) {
  const reason = document.getElementById('ops-cnc-reason').value.trim();
  const result = await sbMutate(sb.from('oilpalm_bookings').update({
    status: 'cancelled',
    cancel_reason: reason || null,
    cancelled_at: new Date().toISOString(),
    cancelled_by: currentUser.username,
    refund_status: owed > 0 ? 'pending' : 'forfeited',
    refund_owed: owed
  }).eq('id', bookingId).select());
  if (result === null) return;
  await loadBookings();
  closeModal();
  renderBookingsTab();
  notify(owed > 0 ? `Cancelled — RM ${owed.toFixed(2)} refund pending` : 'Cancelled — no refund owed', 'success');
}
```

- [ ] **Step 3: Mark Refund Paid modal**

```javascript
async function opsOpenMarkRefundPaidModal(bookingId) {
  const bk = bookings.find(b => b.id === bookingId);
  if (bk.refund_status !== 'pending') return;
  showModal(`
    <h3>Mark Refund Paid</h3>
    <p>Owed: <strong>RM ${(bk.refund_owed || 0).toFixed(2)}</strong></p>
    <div class="form-grid">
      <label>Actual Refund Amount (RM) <input id="ops-rf-amt" type="number" step="0.01" min="0" value="${bk.refund_owed || 0}" /></label>
      <label>Method <select id="ops-rf-method"><option value="cash">Cash</option><option value="bank">Bank</option><option value="cheque">Cheque</option></select></label>
      <label>Reference <input id="ops-rf-ref" /></label>
      <label class="full">Slip <input type="file" id="ops-rf-slip" accept="image/*,application/pdf" /></label>
      <label>Date <input id="ops-rf-date" type="date" value="${new Date().toISOString().slice(0,10)}" /></label>
      <label class="full">Notes <textarea id="ops-rf-notes"></textarea></label>
    </div>
    <div class="modal-actions">
      <button class="btn" onclick="closeModal()">Cancel</button>
      <button class="btn btn-primary" onclick="opsSaveRefund('${bookingId}')">Mark Paid</button>
    </div>
  `);
}

async function opsSaveRefund(bookingId) {
  const amt    = parseFloat(document.getElementById('ops-rf-amt').value);
  const method = document.getElementById('ops-rf-method').value;
  const ref    = document.getElementById('ops-rf-ref').value.trim();
  const slipFile = document.getElementById('ops-rf-slip').files[0];
  const date   = document.getElementById('ops-rf-date').value;
  const notes  = document.getElementById('ops-rf-notes').value.trim();
  if (amt < 0 || !date) { notify('Amount + date required', 'error'); return; }

  let slipUrl = null;
  if (slipFile) {
    const ext = slipFile.name.split('.').pop();
    const path = `refunds/${bookingId}/slip.${ext}`;
    const up = await sb.storage.from('oilpalm-photos').upload(path, slipFile, { upsert: true, contentType: slipFile.type });
    if (!up.error) slipUrl = sb.storage.from('oilpalm-photos').getPublicUrl(path).data.publicUrl;
  }

  const result = await sbMutate(sb.from('oilpalm_bookings').update({
    refund_status: 'paid',
    refund_amount: amt,
    refund_method: method,
    refund_reference: ref || null,
    refund_slip_url: slipUrl,
    refund_paid_at: new Date(date).toISOString(),
    refund_paid_by: currentUser.username,
    refund_notes: notes || null
  }).eq('id', bookingId).select());
  if (result === null) return;
  await loadBookings();
  closeModal();
  renderBookingsTab();
  notify('Refund marked paid', 'success');
}
```

- [ ] **Step 4: Verify**

Reassign — only enabled if 0 collections. Confirm price option works. Cancel — auto-suggest refund correct. Mark Refund Paid — slip uploads, pending → paid badge updates.

- [ ] **Step 5: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): reassign + cancel + refund flows"
```

---

### Task 3.9: New Walk-in Sale modal

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement walk-in modal**

Combines New Customer + Record Collection into one save:
- Customer fields: name, contact, phone (intl-tel-input), address
- Then: batch (selling stage only), qty, unit price (default from batch), L3.1 #, L3.1 photo, collection photo, plate, full payment (mandatory)
- On save: insert customer (or find existing by phone canonical), insert collection (booking_id=null), insert payment (collection_id=collection.id, booking_id=null)
- Same L3.1 dup-check

Reuse `opsSaveCollection` save path with adjustments for the walk-in case (booking_id null, customer either created inline or matched).

- [ ] **Step 2: Verify**

Walk-in Sale → fill customer + batch + qty + L3.1 + photos + plate + payment → save. Customer appears in Customers tab. Collection appears in Collections tab with type "Walk-in". Payment appears against the collection.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): walk-in sale modal"
```

---

### Task 3.10: Collections tab list

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement Collections list**

Columns: Date · L3.1 # · Customer · Batch · Qty · Type (Booking/Walk-in) · Plate. Filters: date range, batch, type, customer search.

Click row → modal showing all collection details + photos thumbnails + L3.1 link.

- [ ] **Step 2: Verify**

Collections tab loads. Adding a collection (booking-driven or walk-in) makes it appear. Click row → detail modal shows photos.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): collections list view"
```

---

### Task 3.11: Booking slip print/share

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement booking slip generator**

Mirror existing `seedlings.html` booking-slip pattern (reuse same office address: Lot 1609, Kpg. Riam Jaya, 98000 Miri, Sarawak; same T&C). Generates an A4 HTML page with header, customer block, items table (1 row: variety + qty + unit price + total), deposit/balance, signature lines. Print button + WhatsApp share via html2canvas.

- [ ] **Step 2: Verify**

On a booking detail, click "Print Booking Slip" → A4 layout in new window. Print works. WhatsApp share generates image and opens share sheet.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): booking slip print/share"
```

---

## Phase 4 — Sales Module Reports

### Task 4.1: MPOB Monthly Report

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement MPOB report**

Monthly snapshot per batch (only batches with activity that month):
- Seeds planted (sum of `plant` events that month)
- Transplanted (sum of `transplant` events)
- Culled (sum of all cull events incl. transplant.culls + mid-MN culls)
- Doubletons/extras gained
- Sold qty (sum of `collections.qty` that month) + L3.1 numbers listed inline
- Balance at month-end (running)

Header: "TG Agribusiness Sdn Bhd" + farm address (Lot 174, Block 9, Lambir Land District, 98000 Miri, Sarawak) + "MPOB License: 522231011000".

Print-formatted (A4, no shadows, black text).

- [ ] **Step 2: Verify**

Run for current month → shows batches with activity. Numbers match what's in the DB.

- [ ] **Step 3: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): MPOB monthly report"
```

---

### Task 4.2: Sales Summary report

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement**

Date range + group-by (Month / Batch / Customer). Columns: Period · Booking count · Walk-in count · Qty sold · Revenue · Avg price. Totals row. Filters: batch, variety, customer type.

- [ ] **Step 2: Verify + Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): sales summary report"
```

---

### Task 4.3: Outstanding Balances report

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement**

All `active` bookings with balance > 0. Aging buckets: 0-30 / 31-60 / 61-90 / 90+ days since booking_date. Color-coded (green/gold/orange/red). Sort by balance desc.

- [ ] **Step 2: Verify + Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): outstanding balances report"
```

---

### Task 4.4: Cash Flow Projection

**Files:**
- Modify: `oilpalmsales.html`

- [ ] **Step 1: Implement**

12-month forward table:
- For each month, sum:
  - Confirmed inflow: per active booking, balance owed × scheduled at the booking's batch's `Ready for Sale` date (date_planted + 10mo)
  - Projected inflow: per batch in Selling/MN, remaining-available × default_price × scheduled at Ready Date
- Totals per month

- [ ] **Step 2: Verify + Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): cash flow projection report"
```

---

## Phase 5 — Hub Integration + Cleanup

### Task 5.1: Update `index.html` MODULES + permissions + categories

**Files:**
- Modify: `index.html`

- [ ] **Step 1: Replace `oilpalmseedling` MODULES entry**

Find the existing `oilpalmseedling` entry. Remove it. Add two new entries (use `iconImg` paths once Task 5.2 completes; for now point to existing seedlings icon for both as a placeholder):

```javascript
// In MODULES config:
{
  id: 'oilpalmgrowth',
  label: 'Oil Palm Growth',
  url: 'oilpalmgrowth.html',
  icon: '🌱',
  iconImg: 'icons/modules/oilpalm-growth.png',
  description: 'Procurement → planting → main nursery',
  category: 'operations',
  permissions: {
    view:             { label: 'View' },
    editBatch:        { label: 'Edit Batch' },
    manageSuppliers:  { label: 'Manage Suppliers' },
    recordCounts:     { label: 'Record Counts (Plant / Transplant / Cull)' },
    markStage:        { label: 'Advance Stage (Selling / Close)' }
  }
},
{
  id: 'oilpalmsales',
  label: 'Oil Palm Sales',
  url: 'oilpalmsales.html',
  icon: '🌴',
  iconImg: 'icons/modules/oil-palm-seedlings.png',
  description: 'Bookings, walk-ins, L3.1 collections',
  category: 'operations',
  permissions: {
    view:               { label: 'View' },
    createBooking:      { label: 'Create Booking' },
    recordCollection:   { label: 'Record Collection' },
    cancelBooking:      { label: 'Cancel Booking' },
    processRefund:      { label: 'Process Refund' },
    manageCustomers:    { label: 'Manage Customers' }
  }
}
```

Update `MODULE_CATEGORIES`: under TG Agribusiness > Operations, list both new modules.

Update `MODULE_COMPANY` (in `shared.js`):
```javascript
const MODULE_COMPANY = {
  // ... existing ...
  oilpalmgrowth: 'tg_agribusiness',
  oilpalmsales: 'tg_agribusiness'
};
```

- [ ] **Step 2: Wipe existing oilpalmseedling permissions on user records**

Run via Node:
```javascript
const r = await c.query(`UPDATE users SET permissions = permissions - 'oilpalmseedling' - 'oilpalmsales' - 'oilpalmgrowth' WHERE permissions ?| ARRAY['oilpalmseedling', 'oilpalmsales', 'oilpalmgrowth'] RETURNING username`);
console.log('Wiped', r.rows.length, 'users');
```

(Admin auto-true, no permission keys needed for them.)

- [ ] **Step 3: Verify**

Reload hub. Under TG Agribusiness > Operations, see both "Oil Palm Growth" and "Oil Palm Sales" cards. Switch to non-admin user, verify they see "Coming Soon" / disabled state until permissions granted.

- [ ] **Step 4: Commit**

```bash
git add index.html shared.js
git commit -m "feat(oilpalm): hub modules + permissions + categories"
```

---

### Task 5.2: Generate Oil Palm Growth icon

**Files:**
- Create: `icons/modules/oilpalm-growth.png`

- [ ] **Step 1: Generate via Gemini Flash with locked style**

Prompt (locked style anchor per CLAUDE.md icon set):
> "3D clay-rendered icon, chunky rounded friendly shapes, soft studio lighting, matte finish, cream background #FAF6EF, Pixar Disney style, warm palette gold #D4AF37 + green #4A7C3F + brown #8B6F47 + cream, NO purple/violet, NO text. Subject: a sturdy seed bag (burlap brown) tied at top, with a sprouting green oil palm shoot emerging from the open mouth — 2 small fronds visible, soil visible at bag base. Square 1:1 aspect, 180×180px source resolution."

Run via the Gemini image MCP. If first generation looks wrong (e.g., has text, has purple), iterate up to 3 times before falling back to using the same `oil-palm-seedlings.png` for both modules with a CSS tint or letter overlay.

- [ ] **Step 2: Save + verify**

Save as `icons/modules/oilpalm-growth.png`. Verify it loads on hub:
```bash
curl -I https://tgfarmhub.com/icons/modules/oilpalm-growth.png  # after deploy
```

- [ ] **Step 3: Commit**

```bash
git add icons/modules/oilpalm-growth.png
git commit -m "feat(oilpalm): growth module icon"
```

---

### Task 5.3: Delete legacy seedlings files + spec/plan from repo

**Files:**
- Delete: `seedlings.html`, `seedlings.css`, `supabase/seedlings_migration.sql`

- [ ] **Step 1: Delete files**

```bash
rm seedlings.html seedlings.css supabase/seedlings_migration.sql
```

(Specs/plans for the old seedlings module stay in git history — don't delete `docs/superpowers/specs/2026-04-09-seedlings-module-design.md` or `docs/superpowers/plans/2026-04-09-seedlings-module-plan.md` since they're committed history; new spec history serves the same role.)

- [ ] **Step 2: Verify nothing references the deleted files**

```bash
grep -rn "seedlings\.html\|seedlings\.css\|seedlings_migration" --include="*.html" --include="*.js" --include="*.css" .
```

Expected: only matches inside CLAUDE.md changelog entries.

- [ ] **Step 3: Commit**

```bash
git add -u  # stages deletions
git commit -m "chore(oilpalm): delete legacy seedlings module files"
```

---

### Task 5.4: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add new module sections**

In the "Modules — Status" section:
- Remove `Oil Palm Seedlings` line under "Recently Built".
- Add under "Active (Built)": `Oil Palm Growth` (description: "Procurement → planting → MN → ready-for-sale") and `Oil Palm Sales` (description: "Bookings, walk-ins, L3.1 collections, MPOB monthly + 3 other reports").

Add a new full architecture section "Oil Palm Modules — Architecture" mirroring the existing "Seedlings Module — Architecture" section but covering both new modules. Keep it concise — just the table summary, lifecycle, ID prefixes, key business rules.

- [ ] **Step 2: Add changelog entry under Tech Debt**

```markdown
- [x] **Oil Palm Growth + Sales modules** (2026-05-08): Replaced monolithic `seedlings.html` with two focused modules — `oilpalmgrowth.html` (procurement, planting, MN, sale-ready) + `oilpalmsales.html` (bookings, walk-ins, L3.1 collections). 8 DB tables renamed `seedling_*` → `oilpalm_*`. New 7-stage lifecycle (Ordered → Received → PN → MN → Selling → Sold Out → Closed). Procurement docs (5 fixed slots: proforma + K3 + AWB + invoice + phyto), single payment per batch. Counting events for plant/transplant/mid-MN cull. Bookings from PN onwards, 50% soft cap, no zero-deposit. Walk-in flow skips booking entirely (customer + collection + payment). Collection guardrail: `max_collectable = floor(paid / unit_price) − collected`. Reassignment via batch_id swap (zero-collections-only, but now allows partial via the swap pattern with denormalized `collections.batch_id`). Two-stage cancellation (cancel immediately releases qty, refund stays pending until finance updates). 6 reports (4 sales + 2 growth). Hub: Oil Palm Growth (new card) + Oil Palm Sales (re-pointed) under TG Agribusiness > Operations. Storage: `oilpalm-photos` bucket. ID prefixes: OS, OB, OE, OC, OK, OP, OL.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(oilpalm): update CLAUDE.md with new modules"
```

---

### Task 5.5: Final deploy + end-to-end verification

**Files:**
- (Deploy + manual smoke test)

- [ ] **Step 1: Deploy**

```bash
npx netlify-cli deploy --prod --dir=. --functions=netlify/functions --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26
```

- [ ] **Step 2: Curl-grep verification (10 checks)**

```bash
# Each line should output a positive number
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "Oil Palm Growth"
curl -s https://tgfarmhub.com/oilpalmsales.html  | grep -c "Oil Palm Sales"
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "opg-stage-badge"
curl -s https://tgfarmhub.com/oilpalmsales.html  | grep -c "ops-status-badge"
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "OPG_DOC_SLOTS"
curl -s https://tgfarmhub.com/oilpalmsales.html  | grep -c "opsSaveCollection"
curl -s https://tgfarmhub.com/oilpalmsales.html  | grep -c "opsOpenWalkInModal"
curl -s https://tgfarmhub.com/index.html         | grep -c "oilpalmgrowth"
curl -s https://tgfarmhub.com/index.html         | grep -c "oilpalmsales"
curl -I https://tgfarmhub.com/icons/modules/oilpalm-growth.png  # 200 OK
```

If any of these return 0, that phase's commit didn't make it. Investigate before proceeding.

- [ ] **Step 3: Manual smoke test (browser)**

In production with admin login:
1. Hub → click Oil Palm Growth → Suppliers → add a supplier → ✓
2. Batches → New Batch (1-2026, supplier just added, MD2 variety, 10000 qty, RM 1.20 cost, +30 days estimated delivery) → ✓
3. Click batch → set actual_delivery_date to today → save → stage flips to Received → ✓
4. Record Planting (10000 received, 100 damaged) → stage flips to PN, Total Planted = 9900 → ✓
5. Record Transplant (200 culls, 50 extras) → stage flips to MN, MN qty = 9750 → ✓
6. Add Cull Event (qty=10) → MN section updates → ✓
7. Mark as Selling (price RM 6.50) → stage flips to Selling → ✓
8. Hub → Oil Palm Sales → Customers → add customer → ✓
9. Bookings → New Booking (the customer, the batch, qty=100, default price RM 6.50, deposit RM 200) → ✓ booking appears Active
10. Booking detail → Record Collection (qty=10, L3.1=TST001, photos, plate=ABC123, no extra payment) → guardrail allows because 200/6.50 = 30 collectable, only collected 10 → ✓
11. Try same L3.1=TST001 again → blocked → ✓
12. Walk-in Sale (new customer + same batch + qty=5 + L3.1=TST002 + photos + plate + RM 32.50 cash) → ✓
13. Bookings → cancel the booking → refund pending RM 135 (200 paid − 65 collected value) → ✓
14. Mark refund paid → status flips to "Refund Done" → ✓
15. Reports → MPOB Monthly for current month → see batch 1-2026 with activity → ✓

- [ ] **Step 4: Final commit (if any tweaks emerged)**

If the smoke test surfaces any bug, fix + commit individually. Then mark plan complete.

---

## Self-Review Notes

(Run after writing this plan. Findings:)

1. **Spec coverage:** All 5 design sections accounted for — data model (Phase 0), Growth (Phase 1+2), Sales (Phase 3+4), permissions/migration (Phase 5).
2. **Placeholder scan:** Tasks 3.4, 3.6, 3.9, 3.10, 3.11, 4.2, 4.3, 4.4 reference existing patterns rather than spelling every line — acceptable per "exact patterns from previous tasks" rule, but the executing engineer must read `seedlings.html` (still in git history) for the booking-slip and walk-in patterns and `sales.html` for live customer-search inline-add. The exec instructions in each "TBD pattern follows" line should make this navigation explicit.
3. **Type consistency:** function naming convention `opg*` for growth, `ops*` for sales, `oc*` and `os*` for shared utilities. Verified consistency across phases.
4. **Schema gotcha:** `payments.collection_id` FK is added AFTER `oilpalm_collections` exists (matches existing seedlings migration pattern at line 144-147). The migration file Step 1 in Task 0.1 includes this in PART 2.
5. **Soft-cap math** in Task 3.5 is computed from existing-uncollected, which excludes any same-batch bookings already partially-collected — correct behavior (collected portion no longer competes for shelf).

If new gotchas surface during build, append below this line.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-08-oilpalm-modules-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
