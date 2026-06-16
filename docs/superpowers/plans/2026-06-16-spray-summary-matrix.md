# Pineapple Spray Summary Matrix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Pineapple Spray Tracker's Summary tab as a simple at-a-glance block × category matrix (Fungicide · Pesticide · Foliar Fertilizer · Fertilizer), each cell showing the last application date + days elapsed with a detailed hover popup, and add a separate granular-fertilizer log to feed the Fertilizer column.

**Architecture:** Inventory remains the single source of truth for products (categories drive everything). Two inventory categories are added (`Foliar Fertilizer`, `Granular Fertilizer`) replacing the combined `Fertilizer`. Foliar fertilizer is sprayed (flows through the existing spray-job pipeline → `pnd_spray_logs`). Granular fertilizer is broadcast and logged via a NEW dedicated "Fertilizer" tab into a NEW `pnd_fertilizer_applications` table. The Summary matrix reads spray history (grouped by product_type) for three columns and the new fertilizer table for the fourth. No urgency colours, no per-category intervals.

**Tech Stack:** Static HTML/CSS/vanilla JS (no build, no test framework). Supabase (PostgREST + RLS). Node `pg` scripts for DB migrations/inspection. Netlify CLI deploy. Verification = `node` pg scripts for DB, browser DevTools console + targeted `grep`, and `curl`-grep live after deploy.

**Conventions reminder (from CLAUDE.md "Module Build Gotchas"):**
- `sb`, `esc`, `notify`, `fmtDate`, `fmtDateShort`, `fmtNum` come from shared.js — never redeclare `SUPABASE_URL`/`SUPABASE_KEY`/`sb`.
- spraytracker.html uses `sbQuery(sb.from(...).insert(...).select())` for mutations (NOT `sbMutate`). Always chain `.select()`.
- spraytracker.html overrides `closeModal()` to clear `#modal-container` innerHTML; modals are injected as innerHTML into `#modal-container`.
- `pnd_blocks`, `pnd_spray_logs` "block" column is `block_name`. `pnd_blocks` has NO `company_id`. `pnd_spray_logs` HAS `company_id`.
- `esc()` does not escape quotes — use it only for text content, and use `data-*`/in-memory lookups (not interpolated onclick strings) for anything user-controlled.
- Tables WITHOUT `company_id` (never filter/insert it): includes `pnd_blocks`, `block_crops`, `crop_statuses`. `pnd_products`, `pnd_spray_logs`, `pnd_job_products`, `pnd_jobs`, and the new `pnd_fertilizer_applications` all HAVE `company_id`.

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `supabase/spray_fertilizer_migration.sql` | Create | Reference copy of the DB migration (constraint widen + new table + RLS). Applied via Node pg script. |
| `inventory.html` | Modify (`CONFIG.categories`, ~line 774-783) | Add `Foliar Fertilizer` + `Granular Fertilizer`, retire combined `Fertilizer`. |
| `spraytracker.html` | Modify (multiple regions) | Category/type maps, new Fertilizer tab + log, rebuilt Summary matrix + popup, dead-code removal. |

All spraytracker work is in the single inline `<script>` of `spraytracker.html`. Line numbers below are from the current file and will drift as edits land — match on the quoted code, not the number.

---

## Task 1: DB migration — widen product_type + create fertilizer table

**Files:**
- Create: `supabase/spray_fertilizer_migration.sql` (reference copy)
- Apply via: temporary Node pg script (delete after)

- [ ] **Step 1: Write the migration SQL reference file**

Create `supabase/spray_fertilizer_migration.sql`:

```sql
-- Spray Summary Matrix migration (2026-06-16)

-- 1. Widen pnd_products.product_type CHECK to allow foliar_fertilizer.
--    (Granular fertilizer is NEVER a spray product, so no granular_fertilizer type.)
ALTER TABLE public.pnd_products DROP CONSTRAINT IF EXISTS pnd_products_product_type_check;
ALTER TABLE public.pnd_products ADD CONSTRAINT pnd_products_product_type_check
  CHECK (product_type = ANY (ARRAY['fungicide','pesticide','herbicide','pgr','adjuvant','carbide','foliar_fertilizer']));

-- 2. New table for granular fertilizer applications (broadcast, not sprayed).
CREATE TABLE IF NOT EXISTS public.pnd_fertilizer_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES public.pnd_blocks(id),
  inventory_product_id text NOT NULL REFERENCES public.products(id),  -- products.id is TEXT, not uuid
  quantity numeric,
  quantity_unit text,
  worker_name text,
  date_applied date NOT NULL,
  notes text,
  logged_by text,
  company_id text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pnd_fert_apps_block ON public.pnd_fertilizer_applications(block_id);
CREATE INDEX IF NOT EXISTS idx_pnd_fert_apps_company ON public.pnd_fertilizer_applications(company_id);

-- 3. RLS — open for anon (PIN login) + authenticated (Google), matching other pnd_* tables.
ALTER TABLE public.pnd_fertilizer_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pnd_fert_apps_anon ON public.pnd_fertilizer_applications;
CREATE POLICY pnd_fert_apps_anon ON public.pnd_fertilizer_applications
  FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS pnd_fert_apps_auth ON public.pnd_fertilizer_applications;
CREATE POLICY pnd_fert_apps_auth ON public.pnd_fertilizer_applications
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
```

- [ ] **Step 2: Apply the migration via a Node pg script**

Create `_migrate.js` in the project root (delete after running):

```js
const fs = require('fs');
const { Client } = require('pg');
const c = new Client({ host:'aws-1-ap-northeast-1.pooler.supabase.com', port:5432, user:'postgres.qwlagcriiyoflseduvvc', password:'Hlfqdbi6wcM4Omsm', database:'postgres', ssl:{rejectUnauthorized:false} });
(async () => {
  await c.connect();
  const sql = fs.readFileSync('supabase/spray_fertilizer_migration.sql','utf8');
  await c.query(sql);
  console.log('migration applied');
  await c.end();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
```

Run: `cd "C:/dev/TG-Farmhub-Website" && node _migrate.js`
Expected: `migration applied`

- [ ] **Step 3: Verify the constraint + table exist**

Create `_verify.js` (delete after):

```js
const { Client } = require('pg');
const c = new Client({ host:'aws-1-ap-northeast-1.pooler.supabase.com', port:5432, user:'postgres.qwlagcriiyoflseduvvc', password:'Hlfqdbi6wcM4Omsm', database:'postgres', ssl:{rejectUnauthorized:false} });
(async () => {
  await c.connect();
  const con = await c.query(`SELECT pg_get_constraintdef(oid) d FROM pg_constraint WHERE conname='pnd_products_product_type_check'`);
  console.log('CHECK:', con.rows[0] && con.rows[0].d);
  const cols = await c.query(`SELECT column_name FROM information_schema.columns WHERE table_name='pnd_fertilizer_applications' ORDER BY ordinal_position`);
  console.log('TABLE COLS:', cols.rows.map(r=>r.column_name).join(', '));
  const pol = await c.query(`SELECT policyname FROM pg_policies WHERE tablename='pnd_fertilizer_applications'`);
  console.log('POLICIES:', pol.rows.map(r=>r.policyname).join(', '));
  await c.end();
})().catch(e => { console.error(e.message); process.exit(1); });
```

Run: `cd "C:/dev/TG-Farmhub-Website" && node _verify.js`
Expected: CHECK includes `foliar_fertilizer`; TABLE COLS lists all 11 columns; POLICIES lists `pnd_fert_apps_anon, pnd_fert_apps_auth`.

- [ ] **Step 4: Delete temp scripts and commit the reference SQL**

```bash
cd "C:/dev/TG-Farmhub-Website"
rm -f _migrate.js _verify.js
git add supabase/spray_fertilizer_migration.sql
git commit -m "feat(spray): DB migration — foliar_fertilizer type + pnd_fertilizer_applications table"
```

---

## Task 2: Data re-tag — split Fertilizer into Foliar / Granular

**Files:**
- Apply via: temporary Node pg script (delete after)

- [ ] **Step 1: Write the re-tag script**

Create `_retag.js` (delete after):

```js
const { Client } = require('pg');
const c = new Client({ host:'aws-1-ap-northeast-1.pooler.supabase.com', port:5432, user:'postgres.qwlagcriiyoflseduvvc', password:'Hlfqdbi6wcM4Omsm', database:'postgres', ssl:{rejectUnauthorized:false} });
(async () => {
  await c.connect();
  // Water Soluble + the lone no-subcategory "Yara Krista SOP" -> Foliar Fertilizer
  const foliar = await c.query(`
    UPDATE products SET category='Foliar Fertilizer', subcategory=NULL
    WHERE category='Fertilizer' AND (subcategory='Water Soluble' OR subcategory IS NULL OR subcategory='')
    RETURNING name`);
  console.log('Foliar Fertilizer:', foliar.rowCount, foliar.rows.map(r=>r.name).join(', '));
  // Granular -> Granular Fertilizer
  const gran = await c.query(`
    UPDATE products SET category='Granular Fertilizer', subcategory=NULL
    WHERE category='Fertilizer' AND subcategory='Granular'
    RETURNING name`);
  console.log('Granular Fertilizer:', gran.rowCount, gran.rows.map(r=>r.name).join(', '));
  // Confirm nothing left under the old combined category
  const left = await c.query(`SELECT count(*)::int n FROM products WHERE category='Fertilizer'`);
  console.log('Remaining old "Fertilizer":', left.rows[0].n);
  await c.end();
})().catch(e => { console.error(e.message); process.exit(1); });
```

- [ ] **Step 2: Run it**

Run: `cd "C:/dev/TG-Farmhub-Website" && node _retag.js`
Expected: `Foliar Fertilizer: 11 ...` (includes "Yara Krista SOP"), `Granular Fertilizer: 4 ...`, `Remaining old "Fertilizer": 0`.

- [ ] **Step 3: Delete temp script**

```bash
cd "C:/dev/TG-Farmhub-Website" && rm -f _retag.js
```

(No commit — this is a data change in Supabase, not a repo change. The reference SQL from Task 1 documents the schema; the re-tag is captured in this plan.)

---

## Task 3: Inventory category config

**Files:**
- Modify: `inventory.html` (`CONFIG.categories`, ~line 774-783)

- [ ] **Step 1: Update the categories object**

Find:

```js
  categories: {
    "Fertilizer": ["Granular", "Water Soluble"],
    "Pesticide": [],
    "Herbicide": [],
    "Fungicide": [],
    "PGR": [],
    "Adjuvant": [],
    "Carbide": [],
    "Other": [],
  },
```

Replace with:

```js
  categories: {
    "Fungicide": [],
    "Pesticide": [],
    "Herbicide": [],
    "Foliar Fertilizer": [],
    "Granular Fertilizer": [],
    "PGR": [],
    "Adjuvant": [],
    "Carbide": [],
    "Other": [],
  },
```

- [ ] **Step 2: Verify the change is present**

Run: `grep -n "Foliar Fertilizer\|Granular Fertilizer" inventory.html`
Expected: both present in the `categories` block; the old combined `"Fertilizer":` line is gone.

- [ ] **Step 3: Commit**

```bash
git add inventory.html
git commit -m "feat(inventory): split Fertilizer into Foliar/Granular top-level categories"
```

---

## Task 4: spraytracker — category/type maps in lockstep

Add `foliar_fertilizer` everywhere a spray type/category is enumerated, and make `Foliar Fertilizer` spray-eligible. **`Granular Fertilizer` is deliberately NOT added to the spray-eligible list** (it's logged via the new Fertilizer tab, never sprayed).

**Files:**
- Modify: `spraytracker.html` (`PRODUCT_TYPES` ~line 335; `renderEnableProductsSection` `sprayCategories` ~line 3391; `enableForSpraying` `typeMap` ~line 3416; AI-link `typeMap` ~line 3033; products-page type label map ~line 3531)

- [ ] **Step 1: Update `PRODUCT_TYPES`**

Find:

```js
const PRODUCT_TYPES = [
  { key: 'all',       label: 'All' },
  { key: 'fungicide', label: 'Fungicide' },
  { key: 'pesticide', label: 'Pesticide' },
  { key: 'herbicide', label: 'Herbicide' },
  { key: 'pgr',       label: 'PGR' },
  { key: 'adjuvant',  label: 'Adjuvant' },
  { key: 'carbide',   label: 'Carbide' },
];
```

Replace with:

```js
const PRODUCT_TYPES = [
  { key: 'all',              label: 'All' },
  { key: 'fungicide',        label: 'Fungicide' },
  { key: 'pesticide',        label: 'Pesticide' },
  { key: 'foliar_fertilizer',label: 'Foliar Fertilizer' },
  { key: 'herbicide',        label: 'Herbicide' },
  { key: 'pgr',              label: 'PGR' },
  { key: 'adjuvant',         label: 'Adjuvant' },
  { key: 'carbide',          label: 'Carbide' },
];
```

- [ ] **Step 2: Update `sprayCategories` in `renderEnableProductsSection`**

Find: `const sprayCategories = ['Pesticide', 'Fungicide', 'Herbicide', 'PGR', 'Adjuvant', 'Carbide'];`

Replace with: `const sprayCategories = ['Pesticide', 'Fungicide', 'Herbicide', 'Foliar Fertilizer', 'PGR', 'Adjuvant', 'Carbide'];`

- [ ] **Step 3: Update `typeMap` in `enableForSpraying`**

Find: `const typeMap = { 'Fungicide': 'fungicide', 'Pesticide': 'pesticide', 'Herbicide': 'herbicide', 'PGR': 'pgr', 'Adjuvant': 'adjuvant', 'Carbide': 'carbide' };`

Replace with: `const typeMap = { 'Fungicide': 'fungicide', 'Pesticide': 'pesticide', 'Herbicide': 'herbicide', 'Foliar Fertilizer': 'foliar_fertilizer', 'PGR': 'pgr', 'Adjuvant': 'adjuvant', 'Carbide': 'carbide' };`

- [ ] **Step 4: Update the AI-link category→type map (~line 3033)**

Find (inside the function that maps spray product_type to inventory category, near `category = typeMap[...]`):

```js
    const typeMap = {fungicide:'Fungicide',pesticide:'Pesticide',herbicide:'Herbicide',pgr:'PGR',adjuvant:'Adjuvant',carbide:'Carbide'};
```

Replace with:

```js
    const typeMap = {fungicide:'Fungicide',pesticide:'Pesticide',herbicide:'Herbicide',foliar_fertilizer:'Foliar Fertilizer',pgr:'PGR',adjuvant:'Adjuvant',carbide:'Carbide'};
```

(If the literal differs slightly, the rule is: add `foliar_fertilizer:'Foliar Fertilizer'` to whichever product_type→category object exists here.)

- [ ] **Step 5: Update the products-page type label map (~line 3531)**

Find: `${{'fungicide':'Fungicide','pesticide':'Pesticide','herbicide':'Herbicide','pgr':'PGR','adjuvant':'Adjuvant','carbide':'Carbide'}[p.product_type]||p.product_type||'—'}`

Replace with: `${{'fungicide':'Fungicide','pesticide':'Pesticide','herbicide':'Herbicide','foliar_fertilizer':'Foliar Fertilizer','pgr':'PGR','adjuvant':'Adjuvant','carbide':'Carbide'}[p.product_type]||p.product_type||'—'}`

- [ ] **Step 6: Verify all five edits**

Run: `grep -n "foliar_fertilizer\|Foliar Fertilizer" spraytracker.html`
Expected: at least 5 hits across the regions above.

- [ ] **Step 7: Commit**

```bash
git add spraytracker.html
git commit -m "feat(spray): make Foliar Fertilizer spray-eligible across type/category maps"
```

---

## Task 5: spraytracker — loaders for spray logs + fertilizer applications

Repurpose the already-declared-but-unused `sprayLogs` global to hold ALL spray logs, and add `fertilizerApplications`.

**Files:**
- Modify: `spraytracker.html` (global state ~line 326; loaders region ~line 485; `loadAll` ~line 396; `renderCurrentPage` ~line 428; `startAutoRefresh` ~line 410)

- [ ] **Step 1: Add `fertilizerApplications` to global state**

Find: `let inventoryProducts=[], inventoryTransactions=[];`

Replace with:

```js
let inventoryProducts=[], inventoryTransactions=[];
let fertilizerApplications=[];
```

(`sprayLogs=[]` already exists on line 326 — reuse it, do not redeclare.)

- [ ] **Step 2: Add the two loader functions**

Immediately after `loadLatestSpraysByAI()` (ends ~line 492), add:

```js
async function loadSprayLogs() {
  const data = await sbQuery(sb.from("pnd_spray_logs").select("*").eq("company_id", getCompanyId()));
  if(data) sprayLogs = data;
}
async function loadFertilizerApplications() {
  const data = await sbQuery(sb.from("pnd_fertilizer_applications").select("*").eq("company_id", getCompanyId()).order("date_applied", {ascending:false}));
  if(data) fertilizerApplications = data;
}
```

- [ ] **Step 3: Wire into `loadAll`**

Find the `await Promise.all([loadStatuses(), loadBlocks(), ... loadAIComboDefaults()]);` line in `loadAll`. Add `loadSprayLogs(), loadFertilizerApplications()` to the array (anywhere before the closing `]`).

- [ ] **Step 4: Wire into `renderCurrentPage` summary path**

Find:

```js
  if(currentPage === 'summary') { await Promise.all([loadLatestSprays(), loadLatestSpraysByAI(), loadJobs(), loadBlockCrops(), loadCropStatuses(), loadIngredients(), loadProductIngredients()]); renderSummary(); }
```

Replace with:

```js
  if(currentPage === 'summary') { await Promise.all([loadSprayLogs(), loadFertilizerApplications(), loadJobs(), loadJobProducts(), loadProducts(), loadBlockCrops(), loadCropStatuses(), loadInventoryProducts()]); renderSummary(); }
```

- [ ] **Step 5: Add the Fertilizer page path to `renderCurrentPage`**

Find: `else if(currentPage === 'reports') initReports();`

Replace with:

```js
  else if(currentPage === 'fertilizer') { await Promise.all([loadFertilizerApplications(), loadBlocks(), loadWorkers(), loadInventoryProducts()]); renderFertilizerPage(); }
  else if(currentPage === 'reports') initReports();
```

- [ ] **Step 6: Wire into `startAutoRefresh`**

Find:

```js
    await Promise.all([loadLatestSprays(), loadLatestSpraysByAI(), loadJobs(), loadOverrides()]);
    if(currentPage === 'summary') renderSummary();
```

Replace with:

```js
    await Promise.all([loadLatestSprays(), loadLatestSpraysByAI(), loadJobs(), loadOverrides(), loadSprayLogs(), loadFertilizerApplications()]);
    if(currentPage === 'summary') renderSummary();
    if(currentPage === 'fertilizer') renderFertilizerPage();
```

- [ ] **Step 7: Verify + commit**

Run: `grep -n "loadSprayLogs\|loadFertilizerApplications\|fertilizerApplications" spraytracker.html`
Expected: loaders defined + referenced in loadAll, renderCurrentPage, startAutoRefresh.

```bash
git add spraytracker.html
git commit -m "feat(spray): loaders for all spray logs + fertilizer applications"
```

---

## Task 6: spraytracker — add "Fertilizer" nav tab + page container

**Files:**
- Modify: `spraytracker.html` (sidebar `<nav>` ~line 56; pages region — add a new `<div class="page" id="page-fertilizer">` before `<!-- /main-content -->` ~line 305)

- [ ] **Step 1: Add the nav item** (between "Manage Products" and "Reports")

Find the Reports nav item:

```html
    <div class="nav-item" data-page="reports" onclick="navigateTo('reports')">
```

Insert BEFORE it:

```html
    <div class="nav-item" data-page="fertilizer" onclick="navigateTo('fertilizer')">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2C7 7 7 12 12 22 17 12 17 7 12 2z"/><path d="M5 12c2 1 4 3 7 10"/><path d="M19 12c-2 1-4 3-7 10"/></svg>
      <span class="nav-label">Fertilizer</span>
    </div>
```

- [ ] **Step 2: Add the page container**

Find the closing of the last page + `</div><!-- /main-content -->` (~line 303-305):

```html
  <div class="data-table" id="report-results" style="display:none;">
    <div class="table-wrap"><div id="report-table-wrap"></div></div>
  </div>
</div>

</div><!-- /main-content -->
```

Insert a new page block immediately BEFORE `</div><!-- /main-content -->` (after the reports page's closing `</div>`):

```html
<!-- PAGE: FERTILIZER -->
<div id="page-fertilizer" class="page">
  <div class="page-header">
    <div><div class="page-title">Fertilizer Applications</div><div class="page-subtitle">Log granular fertilizer rounds (broadcast on soil)</div></div>
    <button class="btn btn-primary" onclick="fertOpenForm()">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:14px;height:14px;"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
      Log Application
    </button>
  </div>
  <div id="fert-filter-row" style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px;"></div>
  <div id="fert-list"></div>
</div>
```

- [ ] **Step 3: Verify + commit**

Run: `grep -n "page-fertilizer\|data-page=\"fertilizer\"" spraytracker.html`
Expected: nav item + page container present.

```bash
git add spraytracker.html
git commit -m "feat(spray): add Fertilizer nav tab + page scaffold"
```

---

## Task 7: spraytracker — Fertilizer log form, save, history list

**Files:**
- Modify: `spraytracker.html` (add a new functions region, e.g. just before the `// JOBS PAGE` section ~line 1097)

- [ ] **Step 1: Add the render + form + save + delete functions**

Insert this block (one self-contained region):

```js
// ============================================================
// FERTILIZER APPLICATIONS (granular, broadcast — separate from spray jobs)
// ============================================================
let fertFilterBlock = '';

function fertGranularProducts() {
  // Source of truth = inventory; only Granular Fertilizer category is loggable here.
  return inventoryProducts
    .filter(p => p.category === 'Granular Fertilizer')
    .sort((a,b) => (a.name||'').localeCompare(b.name||''));
}

function renderFertilizerPage() {
  // Filter bar: block dropdown
  const activeBlocks = blocks.filter(b => b.is_active).sort((a,b)=>(a.block_name||'').localeCompare(b.block_name||'',undefined,{numeric:true}));
  const blockOpts = '<option value="">All Blocks</option>' + activeBlocks.map(b => `<option value="${b.id}" ${fertFilterBlock===b.id?'selected':''}>${esc(b.block_name)}</option>`).join('');
  document.getElementById('fert-filter-row').innerHTML =
    `<label style="font-size:12px;color:var(--text-muted);">Block</label>
     <select id="fert-filter-block" onchange="fertFilterBlock=this.value;renderFertilizerPage();" style="min-width:140px;">${blockOpts}</select>`;

  // List
  let rows = fertilizerApplications.slice();
  if(fertFilterBlock) rows = rows.filter(r => r.block_id === fertFilterBlock);
  rows.sort((a,b) => (b.date_applied||'').localeCompare(a.date_applied||''));

  const listEl = document.getElementById('fert-list');
  if(!rows.length) {
    listEl.innerHTML = `<div class="empty-state" style="padding:30px 20px;text-align:center;color:var(--text-muted);font-size:13px;">No fertilizer applications logged yet. Click <strong>Log Application</strong> to add one.</div>`;
    return;
  }
  let html = '<div class="data-table"><div class="table-wrap"><table><thead><tr>' +
    '<th>Date</th><th>Block</th><th>Product</th><th>Quantity</th><th>Worker</th><th>Notes</th><th></th>' +
    '</tr></thead><tbody>';
  rows.forEach(r => {
    const b = getBlock(r.block_id);
    const inv = getInventoryProduct(r.inventory_product_id);
    html += '<tr>' +
      `<td style="white-space:nowrap;">${fmtDateShort(r.date_applied)}</td>` +
      `<td style="font-weight:600;white-space:nowrap;">${esc(b ? b.block_name : '—')}</td>` +
      `<td>${esc(inv ? inv.name : '—')}</td>` +
      `<td style="white-space:nowrap;">${r.quantity != null ? esc(fmtNum(r.quantity) + ' ' + (r.quantity_unit||'')) : '—'}</td>` +
      `<td>${esc(r.worker_name || '—')}</td>` +
      `<td style="font-size:11px;color:var(--text-dim);">${esc(r.notes || '')}</td>` +
      `<td style="white-space:nowrap;"><button class="btn btn-outline btn-sm" data-fid="${r.id}" onclick="fertEditFromEvent(event)">Edit</button> <button class="btn btn-outline btn-sm" data-fid="${r.id}" onclick="fertDeleteFromEvent(event)">Delete</button></td>` +
    '</tr>';
  });
  html += '</tbody></table></div></div>';
  listEl.innerHTML = html;
}

function fertOpenForm(existing) {
  const activeBlocks = blocks.filter(b => b.is_active).sort((a,b)=>(a.block_name||'').localeCompare(b.block_name||'',undefined,{numeric:true}));
  const blockOpts = '<option value="">— Select —</option>' + activeBlocks.map(b => `<option value="${b.id}" ${existing&&existing.block_id===b.id?'selected':''}>${esc(b.block_name)}</option>`).join('');
  const prods = fertGranularProducts();
  const prodOpts = '<option value="">— Select —</option>' + prods.map(p => `<option value="${p.id}" data-unit="${esc(p.pack_unit||'')}" ${existing&&existing.inventory_product_id===p.id?'selected':''}>${esc(p.name)}</option>`).join('');
  const workerOpts = '<option value="">— Select —</option>' + workers.map(w => `<option value="${esc(w.name)}" ${existing&&existing.worker_name===w.name?'selected':''}>${esc(w.name)}</option>`).join('');
  const today = todayStr();
  const noProducts = prods.length === 0
    ? `<div style="font-size:11px;color:var(--gold);margin-top:6px;">No Granular Fertilizer products in inventory. Add them in the Inventory module (category "Granular Fertilizer").</div>` : '';
  document.getElementById('modal-container').innerHTML = `
    <div class="modal-overlay" style="display:flex;">
      <div class="modal-box" style="max-width:460px;">
        <div class="modal-header"><div class="modal-title">${existing?'Edit':'Log'} Fertilizer Application</div>
          <button class="modal-close" onclick="closeModal()"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>
        <div class="modal-body">
          <div class="form-field"><label>Block</label><select id="fert-block" style="width:100%;">${blockOpts}</select></div>
          <div class="form-field"><label>Granular Fertilizer</label><select id="fert-product" style="width:100%;" onchange="fertSyncUnit()">${prodOpts}</select>${noProducts}</div>
          <div style="display:flex;gap:10px;">
            <div class="form-field" style="flex:1;"><label>Quantity</label><input type="number" id="fert-qty" min="0" step="any" value="${existing&&existing.quantity!=null?existing.quantity:''}" style="width:100%;"></div>
            <div class="form-field" style="flex:1;"><label>Unit</label><input type="text" id="fert-unit" value="${existing?esc(existing.quantity_unit||''):''}" placeholder="kg / bags" style="width:100%;"></div>
          </div>
          <div class="form-field"><label>Worker</label><select id="fert-worker" style="width:100%;">${workerOpts}</select></div>
          <div class="form-field"><label>Date Applied</label><input type="date" id="fert-date" value="${existing?existing.date_applied:today}" style="width:100%;"></div>
          <div class="form-field"><label>Notes (optional)</label><textarea id="fert-notes" rows="2" style="width:100%;">${existing?esc(existing.notes||''):''}</textarea></div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-outline" onclick="closeModal()">Cancel</button>
          <button class="btn btn-primary" onclick="fertSave(${existing?`'${existing.id}'`:'null'})">Save</button>
        </div>
      </div>
    </div>`;
  fertSyncUnit();
}

function fertSyncUnit() {
  const sel = document.getElementById('fert-product');
  const unitEl = document.getElementById('fert-unit');
  if(!sel || !unitEl) return;
  // Only auto-fill the unit if it's currently empty (don't clobber an edited value).
  if(!unitEl.value) {
    const opt = sel.options[sel.selectedIndex];
    if(opt && opt.dataset.unit) unitEl.value = opt.dataset.unit;
  }
}

async function fertSave(id) {
  const block_id = document.getElementById('fert-block').value;
  const inventory_product_id = document.getElementById('fert-product').value;
  const qtyRaw = document.getElementById('fert-qty').value;
  const quantity_unit = document.getElementById('fert-unit').value.trim() || null;
  const worker_name = document.getElementById('fert-worker').value || null;
  const date_applied = document.getElementById('fert-date').value;
  const notes = document.getElementById('fert-notes').value.trim() || null;
  if(!block_id) { notify('Please select a block', 'error'); return; }
  if(!inventory_product_id) { notify('Please select a fertilizer product', 'error'); return; }
  if(!date_applied) { notify('Please set the date applied', 'error'); return; }
  const quantity = qtyRaw === '' ? null : parseFloat(qtyRaw);
  const payload = {
    block_id, inventory_product_id, quantity, quantity_unit, worker_name, date_applied, notes,
    logged_by: (currentUser && currentUser.name) ? currentUser.name : null,
    company_id: getCompanyId()
  };
  let result;
  if(id) {
    result = await sbQuery(sb.from('pnd_fertilizer_applications').update(payload).eq('id', id).select());
  } else {
    result = await sbQuery(sb.from('pnd_fertilizer_applications').insert(payload).select());
  }
  if(result === null) return; // sbQuery already notified on error
  closeModal();
  await loadFertilizerApplications();
  renderFertilizerPage();
  notify('Fertilizer application saved', 'success');
}

function fertEditFromEvent(event) {
  const id = event.currentTarget.dataset.fid;
  const row = fertilizerApplications.find(r => r.id === id);
  if(row) fertOpenForm(row);
}

function fertDeleteFromEvent(event) {
  const id = event.currentTarget.dataset.fid;
  const row = fertilizerApplications.find(r => r.id === id);
  if(!row) return;
  const b = getBlock(row.block_id);
  confirmAction('Delete Application', 'Delete this fertilizer application for ' + (b?b.block_name:'this block') + '?', async function() {
    const result = await sbQuery(sb.from('pnd_fertilizer_applications').delete().eq('id', id).select());
    if(result === null) return;
    await loadFertilizerApplications();
    renderFertilizerPage();
    notify('Application deleted', 'success');
  }, true);
}
```

- [ ] **Step 2: Local console check**

Open `spraytracker.html` in the browser (logged in), open DevTools Console, navigate to the Fertilizer tab. Expected: no console errors; "Log Application" opens the modal; the product dropdown lists Granular Fertilizer items; saving creates a row that appears in the list; Edit/Delete work.

- [ ] **Step 3: Commit**

```bash
git add spraytracker.html
git commit -m "feat(spray): Fertilizer tab — log form, save, history, edit/delete"
```

---

## Task 8: spraytracker — rebuild Summary page HTML (matrix + filters)

Replace the old Summary page body (overview cards, type pills, watchlist bar, sub-pills, status-only filter row, sections div) with: a status filter + block search + the matrix container + the print header.

**Files:**
- Modify: `spraytracker.html` (the `#page-summary` block ~line 82-130+)

- [ ] **Step 1: Replace the Summary page inner HTML**

Find the `<div id="page-summary" class="page active">` block. Replace its ENTIRE inner content (from after the opening tag through just before its matching closing `</div>` that ends the page) with:

```html
  <div class="print-header"><h2>TG Agro Fruits Sdn Bhd</h2><p>Spray Summary Report — Generated <span class="print-date"></span></p></div>
  <div class="page-header">
    <div><div class="page-title">Spray Summary</div><div class="page-subtitle">Last application date + days elapsed, per block</div></div>
  </div>

  <!-- Filters: status + block search -->
  <div id="summary-filter-row" style="display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin-bottom:12px;">
    <div style="display:flex;align-items:center;gap:6px;">
      <label style="font-size:12px;color:var(--text-muted);">Status</label>
      <select id="summary-status-filter" onchange="summaryStatusFilter=this.value;renderSummary();" style="font-size:12px;min-width:130px;"></select>
    </div>
    <div style="display:flex;align-items:center;gap:6px;">
      <label style="font-size:12px;color:var(--text-muted);">Search block</label>
      <input type="text" id="summary-search" oninput="summarySearchInput(this.value)" placeholder="Block name…" style="font-size:12px;min-width:150px;padding:5px 8px;">
    </div>
  </div>

  <div id="summary-matrix"></div>
```

(The old IDs `summary-cards`, `summary-type-pills`, `summary-product-pills`, `summary-watchlist-*`, `summary-sections` must NOT remain. The status filter `summary-status-filter` is kept/reused.)

- [ ] **Step 2: Verify removed IDs are gone from the page HTML**

Run: `grep -n "summary-cards\|summary-type-pills\|summary-product-pills\|summary-watchlist\|summary-sections" spraytracker.html`
Expected: no matches (the page HTML no longer references them; JS referencing them is removed in Task 10).

- [ ] **Step 3: Commit**

```bash
git add spraytracker.html
git commit -m "feat(spray): replace Summary page HTML with matrix + status/search filters"
```

---

## Task 9: spraytracker — matrix render + aggregation + hover popup

Rewrite `renderSummary()` to build the block × category matrix from `sprayLogs` (grouped by product_type) and `fertilizerApplications`, with a detailed hover popup.

**Files:**
- Modify: `spraytracker.html` (replace the body of `renderSummary()` ~line 705-813; the old Level-1/Level-2/section helpers are deleted in Task 10)

- [ ] **Step 1: Add search state + input handler near the other summary state**

Find: `let summaryStatusFilter = '';`

Add immediately after:

```js
let summarySearch = '';
let _summarySearchTO = null;
function summarySearchInput(v) {
  summarySearch = v;
  if(_summarySearchTO) clearTimeout(_summarySearchTO);
  _summarySearchTO = setTimeout(renderSummary, 200);
}
```

- [ ] **Step 2: Replace the entire `renderSummary()` function**

Replace `function renderSummary() { ... }` (the whole current body, ending at its closing brace before `// Level 1 simplified per-block view`) with:

```js
// Matrix columns — first three map to pnd_products.product_type; 'fertilizer' = granular log.
const SUMMARY_COLS = [
  { key:'fungicide',         label:'Fungicide',        bg:'rgba(74,124,63,0.12)' },
  { key:'pesticide',         label:'Pesticide',        bg:'rgba(212,175,55,0.12)' },
  { key:'foliar_fertilizer', label:'Foliar Fertilizer',bg:'rgba(80,140,200,0.12)' },
  { key:'fertilizer',        label:'Fertilizer',       bg:'rgba(150,110,70,0.14)' },
];
let summaryCellData = {}; // `${block_id}_${colKey}` -> popup payload

function renderSummary() {
  const activeBlocks = blocks.filter(b => b.is_active);
  const today = todayStr();

  // Status filter dropdown (reused element)
  const filterEl = document.getElementById('summary-status-filter');
  if(filterEl) {
    const uniqueStatuses = [...new Set(activeBlocks.map(b => {
      const bc = getBlockCrop(b.id); return bc ? getCropStatusName(bc.status_id) : '—';
    }))].sort();
    filterEl.innerHTML = '<option value="">All Statuses</option>' +
      uniqueStatuses.map(s => `<option value="${esc(s)}" ${summaryStatusFilter===s?'selected':''}>${esc(s)}</option>`).join('');
  }

  // Latest spray log per block + product_type (the 3 sprayed columns)
  const sprayCols = ['fungicide','pesticide','foliar_fertilizer'];
  const sprayLatest = {}; // `${block}_${type}` -> log
  sprayLogs.forEach(log => {
    const prod = getProduct(log.product_id);
    if(!prod) return;
    const type = (prod.product_type||'').toLowerCase();
    if(!sprayCols.includes(type)) return;
    const k = log.block_id + '_' + type;
    const cur = sprayLatest[k];
    if(!cur || (log.date_completed||'') > (cur.date_completed||'')) sprayLatest[k] = log;
  });

  // Latest granular fertilizer application per block
  const fertLatest = {};
  fertilizerApplications.forEach(fa => {
    const cur = fertLatest[fa.block_id];
    if(!cur || (fa.date_applied||'') > (cur.date_applied||'')) fertLatest[fa.block_id] = fa;
  });

  // Build rows (with status + search filters applied)
  summaryCellData = {};
  let rowBlocks = activeBlocks.map(b => {
    const bc = getBlockCrop(b.id);
    return { block:b, statusName: bc ? getCropStatusName(bc.status_id) : '—' };
  });
  if(summaryStatusFilter) rowBlocks = rowBlocks.filter(r => r.statusName === summaryStatusFilter);
  if(summarySearch.trim()) {
    const q = summarySearch.trim().toLowerCase();
    rowBlocks = rowBlocks.filter(r => (r.block.block_name||'').toLowerCase().includes(q));
  }
  rowBlocks.sort((a,b) => (a.block.block_name||'').localeCompare(b.block.block_name||'', undefined, {numeric:true}));

  // Header
  let html = '<div class="data-table"><div class="table-wrap"><table style="white-space:nowrap;"><thead>';
  html += '<tr>' +
    '<th rowspan="2" style="position:sticky;left:0;z-index:2;background:#1E261E;min-width:90px;text-align:left;">Block</th>';
  SUMMARY_COLS.forEach(c => {
    html += `<th colspan="2" style="text-align:center;background:${c.bg};">${esc(c.label)}</th>`;
  });
  html += '</tr><tr>';
  SUMMARY_COLS.forEach(() => {
    html += '<th style="text-align:center;font-size:10.5px;color:var(--text-dim);text-transform:uppercase;">Date</th>' +
            '<th style="text-align:center;font-size:10.5px;color:var(--text-dim);text-transform:uppercase;">Days</th>';
  });
  html += '</tr></thead><tbody>';

  if(!rowBlocks.length) {
    html += `<tr><td colspan="${1 + SUMMARY_COLS.length*2}" class="empty-state" style="text-align:center;padding:24px;color:var(--text-muted);">No blocks match the filter.</td></tr>`;
  } else {
    rowBlocks.forEach(({block, statusName}) => {
      html += '<tr>';
      html += `<td style="position:sticky;left:0;background:var(--bg-card);z-index:1;font-weight:600;white-space:nowrap;">${esc(block.block_name)}` +
              `<div style="font-size:10px;color:var(--text-dim);font-weight:400;">${esc(statusName)}</div></td>`;
      SUMMARY_COLS.forEach(c => {
        let dateStr = '—', daysStr = '—', hasData = false;
        const cellId = block.id + '_' + c.key;
        if(c.key === 'fertilizer') {
          const fa = fertLatest[block.id];
          if(fa && fa.date_applied) {
            hasData = true;
            dateStr = fmtDateShort(fa.date_applied);
            const d = daysDiff(fa.date_applied, today);
            daysStr = d != null ? d + 'd' : '—';
            summaryCellData[cellId] = { kind:'fert', fa };
          }
        } else {
          const log = sprayLatest[block.id + '_' + c.key];
          if(log && log.date_completed) {
            hasData = true;
            dateStr = fmtDateShort(log.date_completed);
            const d = daysDiff(log.date_completed, today);
            daysStr = d != null ? d + 'd' : '—';
            summaryCellData[cellId] = { kind:'spray', log, colLabel:c.label, blockName:block.block_name };
          }
        }
        if(hasData) {
          html += `<td style="text-align:center;text-decoration:underline dotted;cursor:help;" data-cell="${cellId}" onmouseenter="summaryShowPopup(event)" onmouseleave="summaryHidePopup()">${dateStr}</td>` +
                  `<td style="text-align:center;">${daysStr}</td>`;
        } else {
          html += `<td style="text-align:center;color:var(--text-dim);">—</td><td style="text-align:center;color:var(--text-dim);">—</td>`;
        }
      });
      html += '</tr>';
    });
  }
  html += '</tbody></table></div></div>';
  document.getElementById('summary-matrix').innerHTML = html;
}
```

- [ ] **Step 3: Add the popup functions**

Immediately after `renderSummary()`, add:

```js
function summaryEnsurePopupEl() {
  let el = document.getElementById('summary-cell-popup');
  if(!el) {
    el = document.createElement('div');
    el.id = 'summary-cell-popup';
    el.style.cssText = 'position:fixed;z-index:9999;display:none;max-width:340px;background:var(--bg-card);border:1px solid var(--border);border-radius:8px;padding:12px 14px;font-size:12px;line-height:1.7;box-shadow:0 8px 24px rgba(0,0,0,0.4);pointer-events:none;';
    document.body.appendChild(el);
  }
  return el;
}

function summaryShowPopup(event) {
  const cellId = event.currentTarget.dataset.cell;
  const data = summaryCellData[cellId];
  if(!data) return;
  const el = summaryEnsurePopupEl();
  const today = todayStr();
  let html = '';
  if(data.kind === 'fert') {
    const fa = data.fa;
    const b = getBlock(fa.block_id);
    const inv = getInventoryProduct(fa.inventory_product_id);
    const d = daysDiff(fa.date_applied, today);
    html =
      `<div style="font-weight:700;color:var(--green-light);">Fertilizer — ${esc(b?b.block_name:'—')}</div>` +
      `<div style="color:var(--text-muted);">Applied ${fmtDate(fa.date_applied)} · ${d!=null?d+' days ago':'—'}</div>` +
      `<hr style="border:none;border-top:1px solid var(--border);margin:8px 0;">` +
      `<div><b>Product:</b> ${esc(inv?inv.name:'—')}</div>` +
      `<div><b>Quantity:</b> ${fa.quantity!=null?esc(fmtNum(fa.quantity)+' '+(fa.quantity_unit||'')):'—'}</div>` +
      `<div style="color:var(--text-muted);margin-top:5px;">Worker: ${esc(fa.worker_name||'—')}</div>`;
  } else {
    const log = data.log;
    const prod = getProduct(log.product_id);
    const d = daysDiff(log.date_completed, today);
    const job = getSprayLogJob(log.logged_by);
    let mixHtml = '';
    if(job) {
      const jps = getJobProducts(job.id);
      if(jps.length) {
        mixHtml = '<div style="margin-top:5px;"><b>Tank mix (sprayed together):</b></div>' +
          '<div style="padding-left:10px;color:var(--text-muted);">' +
          jps.map(jp => {
            const pn = getProduct(jp.product_id); const used = fmtSprayProductUsed(log.logged_by, jp.product_id);
            return '• ' + esc(pn?pn.product_name:'?') + (used && used !== '—' ? ' — ' + esc(used) : '');
          }).join('<br>') + '</div>';
      }
    }
    const qty = fmtSprayProductUsed(log.logged_by, log.product_id);
    const water = fmtSprayWater(log.logged_by);
    html =
      `<div style="font-weight:700;color:var(--green-light);">${esc(data.colLabel)} — ${esc(data.blockName)}</div>` +
      `<div style="color:var(--text-muted);">Sprayed ${fmtDate(log.date_completed)} · ${d!=null?d+' days ago':'—'}</div>` +
      `<hr style="border:none;border-top:1px solid var(--border);margin:8px 0;">` +
      `<div><b>Product:</b> ${esc(prod?prod.product_name:'—')}</div>` +
      `<div><b>Quantity used:</b> ${qty && qty!=='—'?esc(qty):'—'}</div>` +
      mixHtml +
      (water && water!=='—' ? `<div style="margin-top:5px;"><b>Tank:</b> ${esc(water)} water</div>` : '') +
      `<div style="color:var(--text-muted);margin-top:5px;">Worker: ${esc(fmtSprayWorker(log.logged_by))} · Logged by: ${esc(fmtLoggedBy(log.logged_by))}</div>`;
  }
  el.innerHTML = html;
  el.style.display = 'block';
  // Position near the cell, clamped to viewport
  const r = event.currentTarget.getBoundingClientRect();
  let top = r.bottom + 8, left = r.left;
  const pw = el.offsetWidth, ph = el.offsetHeight;
  if(left + pw > window.innerWidth - 12) left = window.innerWidth - pw - 12;
  if(top + ph > window.innerHeight - 12) top = r.top - ph - 8;
  if(left < 8) left = 8;
  if(top < 8) top = 8;
  el.style.top = top + 'px';
  el.style.left = left + 'px';
}

function summaryHidePopup() {
  const el = document.getElementById('summary-cell-popup');
  if(el) el.style.display = 'none';
}
```

- [ ] **Step 4: Local console check**

In the browser: Summary tab loads the matrix; all active blocks listed; columns show last date + days; `—` where none; hovering a date shows the detailed popup (spray cells show product/quantity/mix/tank/worker; fertilizer cells show product/quantity/worker); status filter + block search work; no console errors.

- [ ] **Step 5: Commit**

```bash
git add spraytracker.html
git commit -m "feat(spray): Summary matrix render + aggregation + detailed hover popup"
```

---

## Task 10: spraytracker — remove dead Summary code

Delete the now-unused watchlist/type-pill/drill-down machinery so it can't be called or leak state.

**Files:**
- Modify: `spraytracker.html`

- [ ] **Step 1: Delete the old summary helper functions**

Delete these functions entirely (they are replaced by the matrix): `renderSummaryLevel1`, `toggleSummarySort`, `onSummaryTypeClick`, `onSummaryProductClick`, `renderSummarySection`, `removeFromWatchlist`, `clearWatchlist`, `openAddToMonitoringModal`, `closeAddMonitoringModal`, `renderAddMonitoringList`, `saveMonitoringSelection`, `pruneWatchlist`.

- [ ] **Step 2: Delete the watchlist state + storage helpers**

Delete these declarations/functions: `summaryWatchlist`, `summaryTypeFilter`, `summaryProductFilter`, `summarySortDir`, `summaryStorageKey`, `summaryTypeFilterKey`, `loadWatchlist`, `saveWatchlist`, `saveTypeFilter`. Keep `summaryStatusFilter` and the new `summarySearch`/`summarySearchInput`/`SUMMARY_COLS`/`summaryCellData`.

- [ ] **Step 3: Remove references to deleted symbols**

Run: `grep -n "summaryWatchlist\|summaryTypeFilter\|summaryProductFilter\|summarySortDir\|loadWatchlist\|saveWatchlist\|pruneWatchlist\|renderSummaryLevel1\|renderSummarySection\|onSummaryType\|onSummaryProduct\|openAddToMonitoring\|saveMonitoringSelection\|addMonitoringModal\|PRODUCT_TYPES" spraytracker.html`

For each hit:
- If it's a call site in `init()`/`loadAll()` (e.g. `loadWatchlist()`), delete that call.
- If `PRODUCT_TYPES` is now unused anywhere (the type pills are gone), and grep shows zero remaining references, delete the `PRODUCT_TYPES` array too. If it's still referenced (e.g. some products-page label), leave it.
- Any `addMonitoringModal` HTML block in the page markup → delete it.
Expected after cleanup: no remaining references to the watchlist/drill-down symbols.

- [ ] **Step 4: Local console check**

In the browser: load each tab (Summary, Active Jobs, Job Logs, Manage Products, Fertilizer, Reports). Expected: no `ReferenceError`/`is not defined` in the console; Summary still renders the matrix.

- [ ] **Step 5: Commit**

```bash
git add spraytracker.html
git commit -m "refactor(spray): remove dead watchlist/type-pill/drill-down code from Summary"
```

---

## Task 11: Verify live + deploy

**Files:** none (deploy + verification)

- [ ] **Step 1: Deploy to Netlify**

```bash
cd "C:/dev/TG-Farmhub-Website"
npx netlify-cli deploy --prod --dir=. --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26
```

(Do NOT pass `--functions` — per the 2026-05-11 lesson it triggers a 403 extensions path; `netlify.toml` already declares the functions dir.)
Expected: deploy succeeds, prints the live URL.

- [ ] **Step 2: Live curl-grep verification**

```bash
cd "C:/dev/TG-Farmhub-Website"
for s in "data-page=\"fertilizer\"" "id=\"page-fertilizer\"" "renderFertilizerPage" "id=\"summary-matrix\"" "SUMMARY_COLS" "summaryShowPopup" "foliar_fertilizer" "loadFertilizerApplications"; do
  n=$(curl -s https://tgfarmhub.com/spraytracker.html | grep -c "$s"); echo "$s : $n";
done
for dead in "summary-watchlist" "openAddToMonitoringModal" "renderSummaryLevel1"; do
  n=$(curl -s https://tgfarmhub.com/spraytracker.html | grep -c "$dead"); echo "DEAD $dead : $n (expect 0)";
done
curl -s https://tgfarmhub.com/inventory.html | grep -c "Foliar Fertilizer\|Granular Fertilizer" | xargs echo "inventory categories:"
```

Expected: each new-symbol count ≥ 1; each DEAD count = 0; inventory categories ≥ 2.

- [ ] **Step 3: Manual smoke test (browser, logged in)**

1. Inventory → confirm category dropdown shows Foliar Fertilizer + Granular Fertilizer; a re-tagged product (e.g. Yara Krista SOP) shows category "Foliar Fertilizer".
2. Spray Tracker → Manage Products → "Enable Inventory Products for Spraying" lists Foliar Fertilizer products (NOT Granular). Enable one; confirm it gets `product_type` foliar_fertilizer with no error.
3. Fertilizer tab → Log Application for a block with a Granular Fertilizer product + quantity + worker + date → saves and appears in the list. Edit + Delete work.
4. Summary tab → matrix shows all active blocks; the enabled foliar fertilizer spray (if any completed job exists) and the granular log appear in their columns; hover a date → detailed popup; status filter + search work.
5. DevTools Console clean throughout.

- [ ] **Step 4: Update CLAUDE.md changelog**

Add a dated entry under the changelog summarizing: recategorization (Foliar/Granular split + re-tag counts), the `foliar_fertilizer` product_type + widened CHECK, the new `pnd_fertilizer_applications` table + Fertilizer tab, and the Summary matrix rebuild (4 columns, plain date+days, detailed hover popup, watchlist/drill-down removed). Note deferred: Herbicide tab, Flowering (PGR/Carbide) tab, Adjuvant placement.

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): spray summary matrix + fertilizer log + recategorization"
```

---

## Self-Review Notes (coverage check)

- **§1 Recategorization** → Tasks 1 (constraint + table), 2 (re-tag), 3 (inventory config), 4 (spray type/category maps). ✓
- **§2 Fertilizer tab + table** → Tasks 1 (table), 5 (loaders), 6 (tab/page), 7 (form/save/list). ✓
- **§3 Matrix Summary** → Tasks 8 (HTML), 9 (render/aggregation), with status filter + block search. ✓
- **§4 Hover popup (detailed; granular variant)** → Task 9 Step 3. ✓
- **§5 Removed vs kept** → Tasks 8 (HTML) + 10 (dead code). Active Jobs/Job Logs/Products/Reports untouched. ✓
- **§6 Migration safety** → Task 1 verify, Task 2 verify counts, no spray product references fertilizer. ✓
- **§7 Deferred** → noted in Task 11 Step 4 changelog; no Herbicide/Flowering/Adjuvant work. ✓
- **Type consistency:** loaders `loadSprayLogs`/`loadFertilizerApplications`, state `sprayLogs`/`fertilizerApplications`, render `renderFertilizerPage`/`renderSummary`, popup `summaryShowPopup`/`summaryHidePopup`/`summaryCellData`, helpers reused `getSprayLogJob`/`getJobProducts`/`fmtSprayProductUsed`/`fmtSprayWater`/`fmtSprayWorker`/`fmtLoggedBy` — names consistent across tasks. ✓
```
