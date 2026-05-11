# Oil Palm Growth: L3.1 doc + Procurement math + Sales Summary rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add L3.1 document slot under Documents, rework Procurement to capture cash discount + seeds allowance with live invoice/cost-per-seed display, and reshape Oil Palm Sales Summary into a 7-column table with two distinct balances (Planted − Booked, and Actual = Planted − culls + doubletons − walk-in − booking-collected).

**Architecture:** Three additive DB columns on `oilpalm_batches` (`l3_1_url`, `cash_discount`, `seeds_allowance`); UI changes scoped to `oilpalmgrowth.html` Procurement + Documents sections and `oilpalmsales.html` Summary tab. Calculations are live-computed at render — no triggers, no stored derivatives.

**Tech Stack:** Static HTML/JS, Supabase REST via global `sb` client, shared.js helpers (`sbMutate`, `sbQuery`, `esc`, `fmtDate`, `notify`). No test framework — verification is live-curl + smoke test per project convention.

**Codebase gotchas every task must respect** (from CLAUDE.md "Module Build Gotchas"):
- Do NOT redeclare `SUPABASE_URL` / `SUPABASE_KEY` / `sb` in module files (shared.js owns them).
- `sbMutate` expects a THUNK: `sbMutate(() => sb.from(...).insert(...).select())`. Passing the builder directly throws `TypeError: queryFn is not a function`.
- `sbQuery` accepts the builder directly.
- `oilpalm_batch_events` and `oilpalm_payments` have NO `company_id` column — DO NOT filter by it (PostgREST 400 → swallowed by `sbQuery` → silent empty).
- `oilpalm_batches` HAS `company_id` — filter on read.
- All Supabase mutations must chain `.select()` before `sbMutate` (Supabase v2 returns empty data without it).
- Deploy command (per `feedback_auto_deploy` memory): `npx netlify-cli deploy --prod --dir=. --functions=netlify/functions --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26`

---

## File Structure

| File | Responsibility | Change scope |
|------|----------------|--------------|
| (DB) `oilpalm_batches` table | Add 3 nullable columns | Migration only |
| `oilpalmgrowth.html` | OPG_DOC_SLOTS array (Section A); Procurement section render + save + invoice live-calc (Section B); plant modal pre-fill | ~80 lines changed/added |
| `oilpalmsales.html` | Add mid-cull loader; rewrite `renderSummaryTab` per-batch table to 7 columns (Section C); keep top stat cards untouched | ~50 lines changed |

---

## Task 1: DB migration — add `l3_1_url`, `cash_discount`, `seeds_allowance`

**Files:**
- Create: `supabase/oilpalm_procurement_v2_migration.sql`

- [ ] **Step 1: Write the migration file**

Create `supabase/oilpalm_procurement_v2_migration.sql`:

```sql
-- 2026-05-11: L3.1 document slot + procurement math fields
-- All columns nullable + defaulted so existing rows are unaffected.

ALTER TABLE oilpalm_batches
  ADD COLUMN IF NOT EXISTS l3_1_url TEXT NULL,
  ADD COLUMN IF NOT EXISTS cash_discount NUMERIC(12,2) NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS seeds_allowance INTEGER NULL DEFAULT 0;

-- Sanity:
-- SELECT id, ordered_qty, unit_cost, total_cost, cash_discount, seeds_allowance, l3_1_url
-- FROM oilpalm_batches LIMIT 5;
```

- [ ] **Step 2: Apply migration via Node `pg` script**

Run from the repo root:

```bash
node -e "
const { Client } = require('pg');
const c = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 5432,
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  database: 'postgres',
  ssl: { rejectUnauthorized: false }
});
const fs = require('fs');
const sql = fs.readFileSync('supabase/oilpalm_procurement_v2_migration.sql', 'utf8');
c.connect().then(() => c.query(sql)).then(r => { console.log('OK'); return c.end(); }).catch(e => { console.error(e.message); c.end(); process.exit(1); });
"
```

Expected output: `OK`

- [ ] **Step 3: Verify columns exist via REST**

```bash
node -e "
const url = 'https://qwlagcriiyoflseduvvc.supabase.co/rest/v1/oilpalm_batches?select=id,l3_1_url,cash_discount,seeds_allowance&limit=1';
const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE';
fetch(url, { headers: { apikey: key, Authorization: 'Bearer '+key }})
  .then(r=>r.json()).then(d=>console.log(JSON.stringify(d, null, 2)));
"
```

Expected: one row with all three new columns present (values `null`, `0`, `0`).

If PostgREST schema cache is stale, send a reload signal:

```bash
node -e "
const url = 'https://qwlagcriiyoflseduvvc.supabase.co/rest/v1/rpc/pgrst_reload';
const key = '<service-role-key>';
fetch(url, { method:'POST', headers: { apikey: key, Authorization: 'Bearer '+key }}).then(()=>console.log('reloaded'));
" 2>/dev/null || true
```
(Usually unnecessary — PostgREST reloads schema within seconds.)

- [ ] **Step 4: Commit**

```bash
git add supabase/oilpalm_procurement_v2_migration.sql
git commit -m "feat(oilpalm-db): add l3_1_url + cash_discount + seeds_allowance columns"
```

---

## Task 2: Section A — L3.1 doc slot in Documents section

**Files:**
- Modify: `oilpalmgrowth.html:79-85` (OPG_DOC_SLOTS array)

- [ ] **Step 1: Add L3.1 entry to OPG_DOC_SLOTS**

In `oilpalmgrowth.html`, locate the OPG_DOC_SLOTS array (currently lines 79-85):

```js
const OPG_DOC_SLOTS = [
  { key: 'proforma_url',         slot: 'proforma',         label: 'Proforma Invoice' },
  { key: 'k3_chit_url',          slot: 'k3_chit',          label: 'K3 Chit' },
  { key: 'airwaybill_url',       slot: 'airwaybill',       label: 'Airwaybill' },
  { key: 'official_invoice_url', slot: 'official_invoice', label: 'Official Invoice' },
  { key: 'phyto_cert_url',       slot: 'phyto_cert',       label: 'Phytosanitary Certificate' }
];
```

Replace with:

```js
const OPG_DOC_SLOTS = [
  { key: 'proforma_url',         slot: 'proforma',         label: 'Proforma Invoice' },
  { key: 'k3_chit_url',          slot: 'k3_chit',          label: 'K3 Chit' },
  { key: 'airwaybill_url',       slot: 'airwaybill',       label: 'Airwaybill' },
  { key: 'official_invoice_url', slot: 'official_invoice', label: 'Official Invoice' },
  { key: 'phyto_cert_url',       slot: 'phyto_cert',       label: 'Phytosanitary Certificate' },
  { key: 'l3_1_url',             slot: 'l3_1',             label: 'L3.1 Form (from supplier)' }
];
```

- [ ] **Step 2: Local grep verification**

```bash
```

Run:
```
grep -n "l3_1_url" oilpalmgrowth.html
```

Expected: exactly 1 match (the array entry above).

- [ ] **Step 3: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): add L3.1 form as 6th document slot"
```

---

## Task 3: Section B — Procurement form fields (cash_discount + seeds_allowance)

**Files:**
- Modify: `oilpalmgrowth.html:313-325` (Procurement section render in `opgRenderDetail`)
- Modify: `oilpalmgrowth.html:344-348` (`opgRecomputeTotalCost` → replace with `opgRecomputeInvoice`)
- Modify: `oilpalmgrowth.html:333-336` (event listener wiring)
- Modify: `oilpalmgrowth.html:350-376` (`opgSaveProcurement`)

- [ ] **Step 1: Replace the Procurement section markup**

Current block at `oilpalmgrowth.html:313-325`:

```html
<div class="opg-section">
  <h3>Procurement</h3>
  <div class="form-grid">
    <label>Order Date <input id="opg-d-od" type="date" value="${b.order_date || ''}" /></label>
    <label>Estimated Delivery <input id="opg-d-edd" type="date" value="${b.estimated_delivery_date || ''}" /></label>
    <label>Actual Delivery <input id="opg-d-add" type="date" value="${b.actual_delivery_date || ''}" /></label>
    <label>Ordered Qty <input id="opg-d-qty" type="number" min="0" value="${b.ordered_qty || 0}" /></label>
    <label>Unit Cost (RM) <input id="opg-d-uc" type="number" step="0.01" min="0" value="${b.unit_cost || 0}" /></label>
    <label>Total Cost (RM) <input id="opg-d-tc" type="number" step="0.01" min="0" value="${(b.total_cost || 0)}" readonly /></label>
    <label class="full">Notes <textarea id="opg-d-notes">${esc(b.notes || '')}</textarea></label>
  </div>
  <div class="modal-actions"><button class="btn btn-primary" onclick="opgSaveProcurement()">Save Procurement</button></div>
</div>
```

Replace with:

```html
<div class="opg-section">
  <h3>Procurement</h3>
  <div class="form-grid">
    <label>Order Date <input id="opg-d-od" type="date" value="${b.order_date || ''}" /></label>
    <label>Estimated Delivery <input id="opg-d-edd" type="date" value="${b.estimated_delivery_date || ''}" /></label>
    <label>Actual Delivery <input id="opg-d-add" type="date" value="${b.actual_delivery_date || ''}" /></label>
    <label>Ordered Qty <input id="opg-d-qty" type="number" min="0" value="${b.ordered_qty || 0}" /></label>
    <label>Unit Cost (RM) <input id="opg-d-uc" type="number" step="0.01" min="0" value="${b.unit_cost || 0}" /></label>
    <label>Gross (Ordered × Unit, RM) <input id="opg-d-tc" type="number" step="0.01" min="0" value="${(b.total_cost || 0)}" readonly /></label>
    <label>Cash Discount (RM) <input id="opg-d-disc" type="number" step="0.01" min="0" value="${(b.cash_discount || 0)}" /></label>
    <label>Seeds Allowance (free extras) <input id="opg-d-allow" type="number" min="0" value="${(b.seeds_allowance || 0)}" /></label>
    <label class="full">Notes <textarea id="opg-d-notes">${esc(b.notes || '')}</textarea></label>
  </div>

  <div id="opg-invoice-summary" style="margin:10px 0;padding:10px 12px;background:rgba(212,175,55,0.08);border:1px solid rgba(212,175,55,0.4);border-radius:4px;font-size:13px;">
    <!-- Filled by opgRecomputeInvoice() -->
  </div>

  <div class="modal-actions"><button class="btn btn-primary" onclick="opgSaveProcurement()">Save Procurement</button></div>
</div>
```

- [ ] **Step 2: Replace `opgRecomputeTotalCost` with `opgRecomputeInvoice`**

Current function at `oilpalmgrowth.html:344-348`:

```js
function opgRecomputeTotalCost() {
  const q = parseFloat(document.getElementById('opg-d-qty').value) || 0;
  const u = parseFloat(document.getElementById('opg-d-uc').value) || 0;
  document.getElementById('opg-d-tc').value = (q * u).toFixed(2);
}
```

Replace with:

```js
function opgRecomputeInvoice() {
  const q     = parseFloat(document.getElementById('opg-d-qty').value)   || 0;
  const u     = parseFloat(document.getElementById('opg-d-uc').value)    || 0;
  const disc  = parseFloat(document.getElementById('opg-d-disc').value)  || 0;
  const allow = parseInt(document.getElementById('opg-d-allow').value, 10) || 0;

  const gross   = q * u;
  const invoice = Math.max(0, gross - disc);
  const seeds   = q + allow;
  const cps     = seeds > 0 ? (invoice / seeds) : 0;

  document.getElementById('opg-d-tc').value = gross.toFixed(2);
  document.getElementById('opg-invoice-summary').innerHTML = `
    <div style="font-weight:700;color:var(--gold);margin-bottom:6px;">Invoice Summary</div>
    <div style="display:grid;grid-template-columns:auto 1fr;gap:4px 16px;align-items:baseline;">
      <span class="muted">Gross invoice</span><span><strong>RM ${gross.toFixed(2)}</strong> &nbsp;<span class="muted">(${q.toLocaleString()} × RM ${u.toFixed(2)})</span></span>
      <span class="muted">− Cash discount</span><span>RM ${disc.toFixed(2)}</span>
      <span class="muted">Invoice total</span><span><strong style="color:var(--gold)">RM ${invoice.toFixed(2)}</strong> &nbsp;<span class="muted">(final supplier bill)</span></span>
      <span class="muted">Seeds received</span><span><strong>${seeds.toLocaleString()}</strong> &nbsp;<span class="muted">(${q.toLocaleString()} ordered + ${allow.toLocaleString()} allowance)</span></span>
      <span class="muted">Cost per seed</span><span><strong>RM ${cps.toFixed(2)}</strong></span>
    </div>
  `;
}
```

- [ ] **Step 3: Update event listener wiring**

Current at `oilpalmgrowth.html:333-336`:

```js
// Auto-recompute total_cost when qty/unit_cost change
document.getElementById('opg-d-qty').addEventListener('input', opgRecomputeTotalCost);
document.getElementById('opg-d-uc').addEventListener('input', opgRecomputeTotalCost);
```

Replace with:

```js
// Auto-recompute invoice + cost-per-seed when any procurement input changes
['opg-d-qty','opg-d-uc','opg-d-disc','opg-d-allow'].forEach(id => {
  document.getElementById(id).addEventListener('input', opgRecomputeInvoice);
});
opgRecomputeInvoice();  // initial render
```

- [ ] **Step 4: Update `opgSaveProcurement` to persist new columns**

Current function at `oilpalmgrowth.html:350-376` — modify the `data` object construction. Replace:

```js
const data = {
  order_date: document.getElementById('opg-d-od').value || null,
  estimated_delivery_date: document.getElementById('opg-d-edd').value || null,
  actual_delivery_date: document.getElementById('opg-d-add').value || null,
  ordered_qty: parseInt(document.getElementById('opg-d-qty').value, 10) || 0,
  unit_cost: parseFloat(document.getElementById('opg-d-uc').value) || 0,
  total_cost: parseFloat(document.getElementById('opg-d-tc').value) || 0,
  notes: document.getElementById('opg-d-notes').value.trim() || null
};
```

With:

```js
const data = {
  order_date: document.getElementById('opg-d-od').value || null,
  estimated_delivery_date: document.getElementById('opg-d-edd').value || null,
  actual_delivery_date: document.getElementById('opg-d-add').value || null,
  ordered_qty: parseInt(document.getElementById('opg-d-qty').value, 10) || 0,
  unit_cost: parseFloat(document.getElementById('opg-d-uc').value) || 0,
  total_cost: parseFloat(document.getElementById('opg-d-tc').value) || 0,
  cash_discount: parseFloat(document.getElementById('opg-d-disc').value) || 0,
  seeds_allowance: parseInt(document.getElementById('opg-d-allow').value, 10) || 0,
  notes: document.getElementById('opg-d-notes').value.trim() || null
};
```

- [ ] **Step 5: Pre-fill `seeds_received` in plant modal from ordered + allowance**

In `oilpalmgrowth.html`, locate `opgOpenPlantModal` (currently starts ~line 529). The `Seeds Received` input has no default value. Update the modal markup so the input renders with a pre-filled value based on the batch:

Replace:

```js
<label>Seeds Received <input id="opg-plant-rcvd" type="number" min="1" /></label>
```

With:

```js
<label>Seeds Received <input id="opg-plant-rcvd" type="number" min="1" value="${(b.ordered_qty || 0) + (b.seeds_allowance || 0)}" /></label>
```

This requires `b` in scope. The existing function does not look up `b` — add at the top of `opgOpenPlantModal` (right after `function opgOpenPlantModal() {`):

```js
const b = batches.find(x => x.id === selectedBatchId) || {};
```

Then call `recompute()` once at the end so the `Total Planted` field reflects the pre-fill on open:

After the existing two `addEventListener('input', recompute)` lines, add:

```js
recompute();
```

- [ ] **Step 6: Local grep verification**

Run:
```
grep -n "opgRecomputeInvoice\|opg-d-disc\|opg-d-allow\|cash_discount\|seeds_allowance" oilpalmgrowth.html
```

Expected: at least 12 matches across the function definition, event listeners, save payload, and form markup.

- [ ] **Step 7: Commit**

```bash
git add oilpalmgrowth.html
git commit -m "feat(oilpalm-growth): cash discount + seeds allowance with live invoice + cost-per-seed"
```

---

## Task 4: Section C — Sales Summary 7-column table

**Files:**
- Modify: `oilpalmsales.html` — add new state global + loader for batch events
- Modify: `oilpalmsales.html:2548-2589` (`sortedBatches` + `batchRows` construction in `renderSummaryTab`)
- Modify: `oilpalmsales.html:2628-2647` (table markup)

- [ ] **Step 1: Add state global for mid-MN culls**

Near the other state globals at the top of the `<script>` block in `oilpalmsales.html` (look for `let batches = [];` etc., probably around line 60-90), add:

```js
let midCullsByBatch = {};  // { batch_id: total_mid_mn_cull_qty } — culls after transplant event
```

- [ ] **Step 2: Add loader for `oilpalm_batch_events` mid-MN culls**

Add a new loader function near the other `loadX()` functions (around `oilpalmsales.html:191`):

```js
async function loadMidCulls() {
  // oilpalm_batch_events has NO company_id column — DO NOT filter by it
  // (PostgREST 400 → swallowed by sbQuery → silent empty result).
  // Mid-MN culls = event_type='cull' AND event_date AFTER the batch's transplant date.
  // We approximate by summing ALL cull events here, then subtracting transplant_culls per
  // batch at render time (those are already on oilpalm_batches.transplant_culls).
  const data = await sbQuery(sb.from('oilpalm_batch_events').select('batch_id, qty, event_type').eq('event_type', 'cull'));
  midCullsByBatch = {};
  (data || []).forEach(e => {
    midCullsByBatch[e.batch_id] = (midCullsByBatch[e.batch_id] || 0) + Number(e.qty || 0);
  });
}
```

- [ ] **Step 3: Call `loadMidCulls()` on page load**

Find the `Promise.all` block that runs all loaders on `DOMContentLoaded` (search for `loadCustomers()`, `loadBookings()`). Add `loadMidCulls()` to the array. Example (paths may differ):

Before:
```js
await Promise.all([
  loadCustomers(),
  loadBookings(),
  loadCollections(),
  loadPayments(),
  loadBatches(),
  loadVarieties(),
  loadSuppliers()
]);
```

After:
```js
await Promise.all([
  loadCustomers(),
  loadBookings(),
  loadCollections(),
  loadPayments(),
  loadBatches(),
  loadVarieties(),
  loadSuppliers(),
  loadMidCulls()
]);
```

If multiple `Promise.all` loader blocks exist, add to each (typically there's a `refreshData()`-style helper too — check around lines 540-560).

- [ ] **Step 4: Rewrite per-batch row construction in `renderSummaryTab`**

Locate the block in `renderSummaryTab` starting around `oilpalmsales.html:2548` (the comment `// Per-batch table — ALL batches...`) and ending at the `batchRows = sortedBatches.map(...)` block close, around line 2589.

Replace the entire block from line 2548 through end of the map (the `batchRows = sortedBatches.map(b => { ... }).join('');` close) with:

```js
// Per-batch table — ALL batches, sorted by stage priority then batch number.
const STAGE_ORDER = { selling:1, main_nursery:2, pre_nursery:3, received:4, ordered:5, sold_out:6, closed:7 };
const STAGE_LABEL = { ordered:'Ordered', received:'Received', pre_nursery:'Pre-Nursery', main_nursery:'Main Nursery', selling:'Selling', sold_out:'Sold Out', closed:'Closed' };
const sortedBatches = [...batches].sort((a, b) => {
  const sa = STAGE_ORDER[a.status] || 99, sb = STAGE_ORDER[b.status] || 99;
  if (sa !== sb) return sa - sb;
  return (a.batch_number || '').localeCompare(b.batch_number || '');
});

// Pre-aggregate walk-in vs booking-collected per batch
const walkInByBatch = {};
const bookingCollByBatch = {};
collections.forEach(c => {
  if (c.booking_id) {
    bookingCollByBatch[c.batch_id] = (bookingCollByBatch[c.batch_id] || 0) + Number(c.qty || 0);
  } else {
    walkInByBatch[c.batch_id] = (walkInByBatch[c.batch_id] || 0) + Number(c.qty || 0);
  }
});

let batchRows = '';
if (sortedBatches.length === 0) {
  batchRows = '<tr><td colspan="7" style="text-align:center;padding:20px;color:var(--text-muted);">No batches yet. Create one in Oil Palm Growth.</td></tr>';
} else {
  batchRows = sortedBatches.map(b => {
    const isPrePlanted = (b.status === 'ordered' || b.status === 'received');
    const totalPlanted = Number(b.qty_planted) || 0;

    // Column 5 — Booked = sum of (booked_qty − collected) for ACTIVE bookings only.
    // bookedByBatch was already computed above using bookings.filter(b => b.status === 'active').
    const booked = bookedByBatch[b.id] || 0;

    // Column 6 — Balance less booking
    const balanceLessBooking = totalPlanted - booked;

    // Column 7 — Actual Balance
    //   = qty_planted − (transplant_culls + mid_culls) + transplant_extras − walk_in − booking_collected
    // midCullsByBatch already includes the transplant-time cull event (event_type='cull' at transplant),
    // so subtract transplant_culls separately would double-count IF the transplant flow ALSO inserts a
    // cull event. Inspect oilpalm_batch_events for this batch's transplant event_type to confirm.
    // SAFE FALLBACK: use only batch_events sum (it covers BOTH transplant + mid-MN culls).
    const allCulls = midCullsByBatch[b.id] || 0;
    const extras   = Number(b.transplant_extras) || 0;
    const walkIn   = walkInByBatch[b.id] || 0;
    const bkColl   = bookingCollByBatch[b.id] || 0;
    const actualBalance = totalPlanted - allCulls + extras - walkIn - bkColl;

    // Pre-PN stages render "—" for the derived columns (no meaningful data yet)
    const dash = '<span class="muted">—</span>';

    return `
      <tr>
        <td>${esc(b.batch_number || '—')}</td>
        <td>${esc(varietyMap[b.variety_id] || '—')}</td>
        <td><span class="ops-status-badge ops-status-${b.status}">${STAGE_LABEL[b.status] || b.status}</span></td>
        <td style="text-align:right;">${isPrePlanted ? dash : totalPlanted.toLocaleString()}</td>
        <td style="text-align:right;">${isPrePlanted ? dash : (booked || '0')}</td>
        <td style="text-align:right;">${isPrePlanted ? dash : balanceLessBooking.toLocaleString()}</td>
        <td style="text-align:right;font-weight:600;">${isPrePlanted ? dash : actualBalance.toLocaleString()}</td>
      </tr>
    `;
  }).join('');
}
```

Note the comment on `allCulls`: the existing transplant flow at `oilpalmgrowth.html:627-640` (`opgSaveTransplantEvent`) DOES insert a `transplant` event_type, not `cull` — so `midCullsByBatch` (filtered to `event_type='cull'`) will NOT double-count `transplant_culls`. **However**, mid-MN cull section may insert events with `event_type='cull'`. The safest formula:

- `total_culls = transplant_culls + mid_culls_from_events` (assuming transplant flow doesn't emit a 'cull' event for transplant-time culls)

If the transplant flow DOES emit a 'cull' event for `transplant_culls`, this becomes:

- `total_culls = mid_culls_from_events` (which already includes transplant-time culls)

**Verify which is the case before shipping**: grep `oilpalmgrowth.html` for `event_type: 'cull'` insertions. If you find one in `opgSaveTransplantEvent`, switch to the second formula and replace the `const allCulls` line above with:

```js
const allCulls = midCullsByBatch[b.id] || 0;  // includes transplant-time culls
```

If transplant flow emits only `event_type: 'transplant'`, use:

```js
const transplantCulls = Number(b.transplant_culls) || 0;
const midCulls = midCullsByBatch[b.id] || 0;
const allCulls = transplantCulls + midCulls;
```

- [ ] **Step 5: Update the table header markup**

Locate the `<thead>` block at `oilpalmsales.html:2632-2643`:

```html
<thead>
  <tr>
    <th>Batch #</th>
    <th>Variety</th>
    <th>Stage</th>
    <th style="text-align:right;">Total</th>
    <th style="text-align:right;">Booked</th>
    <th style="text-align:right;">Collected</th>
    <th style="text-align:right;">Available</th>
    <th>Ready Date</th>
  </tr>
</thead>
```

Replace with:

```html
<thead>
  <tr>
    <th>Batch #</th>
    <th>Variety</th>
    <th>Stage</th>
    <th style="text-align:right;">Total Planted</th>
    <th style="text-align:right;">Booked</th>
    <th style="text-align:right;">Balance (less booking)</th>
    <th style="text-align:right;">Actual Balance</th>
  </tr>
</thead>
```

(Ready Date column dropped — was 8 columns, now 7 per user spec.)

- [ ] **Step 6: Verify transplant flow assumption**

Run:
```
grep -n "event_type" oilpalmgrowth.html
```

Expected output should show:
- `plant` event in `opgSavePlantEvent` (line ~569)
- `transplant` event in `opgSaveTransplantEvent` (line ~630)
- `cull` event in the mid-MN cull section (somewhere around line 700-800)

If the transplant flow emits ONLY `'transplant'` (not `'cull'`), the formula in Step 4 should use `transplant_culls + midCullsByBatch[b.id]` (the second option). Apply the corresponding edit if needed.

- [ ] **Step 7: Local grep verification**

Run:
```
grep -n "Balance (less booking)\|Actual Balance\|midCullsByBatch\|loadMidCulls\|walkInByBatch\|bookingCollByBatch" oilpalmsales.html
```

Expected: at least 10 matches.

- [ ] **Step 8: Commit**

```bash
git add oilpalmsales.html
git commit -m "feat(oilpalm-sales): summary 7-column rework — Total Planted, Booked, Balance less booking, Actual Balance"
```

---

## Task 5: Deploy + post-deploy verification

- [ ] **Step 1: Deploy**

```bash
npx netlify-cli deploy --prod --dir=. --functions=netlify/functions --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26
```

Expected: `Deploy is live!` with website URL.

- [ ] **Step 2: Verify Section A live**

```bash
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "L3.1 Form"
```

Expected: `1` (or more — the OPG_DOC_SLOTS entry).

- [ ] **Step 3: Verify Section B live**

```bash
curl -s https://tgfarmhub.com/oilpalmgrowth.html | grep -c "opgRecomputeInvoice\|Cash Discount\|Seeds Allowance\|Invoice Summary"
```

Expected: `4` or more matches.

- [ ] **Step 4: Verify Section C live**

```bash
curl -s https://tgfarmhub.com/oilpalmsales.html | grep -c "Balance (less booking)\|Actual Balance\|loadMidCulls\|midCullsByBatch"
```

Expected: `4` or more matches.

- [ ] **Step 5: Smoke test in browser**

1. Open https://tgfarmhub.com/oilpalmgrowth.html in browser (with DevTools Console open).
2. Click into an existing batch (e.g. AB-OB002).
3. Confirm: Procurement section shows Cash Discount + Seeds Allowance inputs + a yellow Invoice Summary box. Edit any number → summary recomputes live. Save → reload → values persist.
4. Confirm: Documents section now lists 6 slots, with "L3.1 Form (from supplier)" at the bottom. Upload a small PDF → verify link appears.
5. Open https://tgfarmhub.com/oilpalmsales.html → Summary tab.
6. Confirm: per-batch table now has 7 columns (Batch / Variety / Stage / Total Planted / Booked / Balance less Booking / Actual Balance), no "Ready Date" or "Collected" or "Available" columns. Pre-PN stage batches show "—" for the right 4 columns.

Console must have **zero red errors** during these flows.

- [ ] **Step 6: Final commit (if any post-deploy fixes were needed)**

If smoke test passes without changes: nothing to commit. If a fix-up commit was needed, push it now.

---

## Self-Review

**Spec coverage:**
- Section A (L3.1 doc slot) → Task 1 (DB) + Task 2 (UI) ✓
- Section B (procurement math) → Task 1 (DB) + Task 3 (form + live calc + save + plant pre-fill) ✓
- Section C (7-column summary) → Task 4 (loader + render + header) ✓
- Scope decision (Sales-only, not Growth Batches list) → reflected — no edits to `renderBatchesTab` in oilpalmgrowth.html ✓

**Placeholder scan:** no "TBD" / "TODO" / placeholder phrasing. Step 4 of Task 4 contains conditional code based on a runtime grep result; this is **resolved during the task itself** via Step 6 verification, not deferred.

**Type/name consistency:**
- New columns: `l3_1_url` (TEXT), `cash_discount` (NUMERIC), `seeds_allowance` (INTEGER) — names match across migration, save payload, render reads.
- Function rename: `opgRecomputeTotalCost` → `opgRecomputeInvoice` — replaced everywhere (definition + listener wiring).
- Element IDs: `opg-d-disc`, `opg-d-allow`, `opg-invoice-summary` — used consistently.
- Loader: `loadMidCulls`, `midCullsByBatch` — defined and consumed in the same module.

**Frequent commits:** 4 logical commits (DB migration / Section A / Section B / Section C) plus optional fix-up. Each commit produces a working state.
