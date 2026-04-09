# Multi-Company Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a company selection layer (TG Agro Fruits / TG Agribusiness) to TG FarmHub so every transaction is attributed to the correct company, with instant sidebar switching and per-company module visibility.

**Architecture:** A `companies` table with 2 rows. A `company_id` column added to all relevant data tables. A company toggle in the sidebar (shared.js) controls which modules are visible and scopes all queries. The `next_id` RPC is updated to accept a company code prefix for document numbering (AF-/AB-). Hub page module cards filter by selected company.

**Tech Stack:** Supabase (PostgreSQL), vanilla JS, static HTML/CSS, Node.js `pg` for migrations

**Design Spec:** `docs/superpowers/specs/2026-04-04-multi-company-architecture-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `shared.js` | Modify | Company state management, `getCompanyId()`, `getCompanyCode()`, company-scoped query helpers |
| `shared.css` | Modify | Company switcher widget styles |
| `index.html` | Modify | Company switcher in hub header, module card filtering by company, company overview report section |
| `sales.html` | Modify | Add `company_id` to all insert queries, update `dbNextId()` calls with company prefix |
| `inventory.html` | Modify | Add `company_id` to all insert/select queries |
| `workers.html` | Modify | Add `company_id` to all insert/select queries |
| `spraytracker.html` | Modify | Add `company_id` to all insert/select queries |
| `growthtracker.html` | Modify | Add `company_id` to select queries (read-only module) |
| `delivery.html` | Modify | Add `company_id` to delivery queries |
| `display-sales.html` | Modify | Filter by Agro Fruits company_id |

---

## Task 1: Database Migration — Companies Table & company_id Columns

**Files:**
- Create: `multi_company_migration.sql` (run via Node.js `pg`, then delete after applying)

This is the foundation. Creates the companies table, adds `company_id` to all relevant tables, backfills existing data, and updates the `next_id` RPC to support company-prefixed document numbers.

- [ ] **Step 1: Write the migration SQL**

Create `multi_company_migration.sql` with:

```sql
-- ============================================================
-- MULTI-COMPANY MIGRATION
-- ============================================================

-- 1. Create companies table
CREATE TABLE IF NOT EXISTS companies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  short_name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO companies (id, name, short_name, code) VALUES
  ('tg_agro_fruits', 'TG Agro Fruits Sdn Bhd', 'TG Agro Fruits', 'AF'),
  ('tg_agribusiness', 'TG Agribusiness Sdn Bhd', 'TG Agribusiness', 'AB')
ON CONFLICT (id) DO NOTHING;

-- 2. RLS on companies (read-only for all)
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_read_companies" ON companies FOR SELECT TO anon USING (true);
CREATE POLICY "auth_read_companies" ON companies FOR SELECT TO authenticated USING (true);

-- 3. Add company_id to sales tables (default: tg_agro_fruits)
ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoices ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_payments ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_returns ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoice_items ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoice_orders ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoice_payments ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_credit_notes ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);

-- 4. Add company_id to operations tables (default: tg_agribusiness)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_jobs ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_spray_logs ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE growth_records ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE payroll_periods ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE salary_advances ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE task_types ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE worker_roles ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE responsibility_types ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE worker_default_responsibilities ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE worker_loans ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE loan_repayments ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE employment_stints ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_ingredients ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_formulations ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_product_ingredients ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_job_products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_block_product_overrides ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE ai_combo_defaults ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);

-- 5. Add company_id to id_counters
ALTER TABLE id_counters ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);

-- 6. Backfill existing data
UPDATE sales_customers SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_orders SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_products SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoices SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_payments SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_returns SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoice_items SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoice_orders SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoice_payments SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_credit_notes SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;

UPDATE workers SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE products SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE suppliers SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE transactions SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_jobs SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_products SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_spray_logs SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE growth_records SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE payroll_periods SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE salary_advances SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE task_types SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE worker_roles SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE responsibility_types SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE worker_default_responsibilities SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE worker_loans SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE loan_repayments SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE employment_stints SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_ingredients SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_formulations SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_product_ingredients SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_job_products SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_block_product_overrides SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE ai_combo_defaults SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE id_counters SET company_id = 'tg_agro_fruits' WHERE prefix IN ('SC','SP','SO','SI','SY','SR','DN','INV','II','IP','CN');
UPDATE id_counters SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;

-- 7. Set NOT NULL after backfill (skip for tables that may have edge cases)
ALTER TABLE sales_customers ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_customers ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_orders ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_orders ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_products ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_products ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_invoices ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_invoices ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_payments ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_payments ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_returns ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_returns ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_invoice_items ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_invoice_items ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_invoice_orders ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_invoice_orders ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_invoice_payments ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_invoice_payments ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_credit_notes ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_credit_notes ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE workers ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE workers ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';
ALTER TABLE products ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE products ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';
ALTER TABLE pnd_jobs ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE pnd_jobs ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';
ALTER TABLE growth_records ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE growth_records ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';

-- 8. Update next_id RPC to support company prefix
-- The new signature: next_id(p_prefix TEXT, p_company_code TEXT DEFAULT NULL)
-- If p_company_code is provided, output = company_code + '-' + prefix + '-' + YYMMDD + '-' + NNN
-- If NULL, output = prefix + '-' + YYMMDD + '-' + NNN (backward compatible)
CREATE OR REPLACE FUNCTION next_id(p_prefix TEXT, p_company_code TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_date TEXT := to_char(now() AT TIME ZONE 'Asia/Kuala_Lumpur', 'YYMMDD');
  v_key TEXT := COALESCE(p_company_code || '-', '') || p_prefix || '-' || v_date;
  v_seq INT;
BEGIN
  INSERT INTO id_counters (prefix, counter, company_id)
  VALUES (v_key, 1, CASE
    WHEN p_company_code = 'AF' THEN 'tg_agro_fruits'
    WHEN p_company_code = 'AB' THEN 'tg_agribusiness'
    ELSE NULL
  END)
  ON CONFLICT (prefix) DO UPDATE SET counter = id_counters.counter + 1
  RETURNING counter INTO v_seq;

  RETURN v_key || '-' || lpad(v_seq::TEXT, 3, '0');
END;
$$;

-- 9. Update growth_records_view to include company_id
DROP VIEW IF EXISTS growth_records_view;
CREATE VIEW growth_records_view AS
SELECT
  gr.*,
  gr.company_id,
  CASE
    WHEN gr.date_induced_start IS NOT NULL THEN
      (CURRENT_DATE - gr.date_induced_start)
    ELSE NULL
  END AS days_after_induce,
  CASE
    WHEN gr.target_harvest_start IS NOT NULL THEN
      (gr.target_harvest_start - CURRENT_DATE)
    ELSE NULL
  END AS days_to_harvest
FROM growth_records gr
WHERE EXISTS (
  SELECT 1 FROM block_crops bc
  WHERE bc.block_id = gr.block_id
    AND bc.variety_id = gr.variety_id
    AND bc.is_current = true
);
```

- [ ] **Step 2: Run the migration**

Run via Node.js `pg` script against Supabase:
```bash
node -e "
const { Client } = require('pg');
const fs = require('fs');
const sql = fs.readFileSync('multi_company_migration.sql', 'utf8');
const c = new Client({ host:'aws-1-ap-northeast-1.pooler.supabase.com', port:5432, database:'postgres', user:'postgres.qwlagcriiyoflseduvvc', password:'Hlfqdbi6wcM4Omsm', ssl:{rejectUnauthorized:false} });
c.connect().then(() => c.query(sql)).then(r => { console.log('Migration complete'); c.end(); }).catch(e => { console.error(e); c.end(); });
"
```

- [ ] **Step 3: Verify migration**

Run a quick check to confirm:
```bash
node -e "
const { Client } = require('pg');
const c = new Client({ host:'aws-1-ap-northeast-1.pooler.supabase.com', port:5432, database:'postgres', user:'postgres.qwlagcriiyoflseduvvc', password:'Hlfqdbi6wcM4Omsm', ssl:{rejectUnauthorized:false} });
c.connect().then(async () => {
  const r1 = await c.query('SELECT * FROM companies');
  console.log('Companies:', r1.rows);
  const r2 = await c.query('SELECT company_id, count(*) FROM sales_orders GROUP BY company_id');
  console.log('Sales orders by company:', r2.rows);
  const r3 = await c.query('SELECT company_id, count(*) FROM workers GROUP BY company_id');
  console.log('Workers by company:', r3.rows);
  const r4 = await c.query(\"SELECT next_id('DO', 'AF')\");
  console.log('Test AF-DO id:', r4.rows[0].next_id);
  c.end();
}).catch(e => { console.error(e); c.end(); });
"
```
Expected: Companies table has 2 rows, all sales_orders have `tg_agro_fruits`, all workers have `tg_agribusiness`, test ID returns `AF-DO-YYMMDD-001`.

- [ ] **Step 4: Commit**

```bash
git add multi_company_migration.sql
git commit -m "feat: add multi-company database migration (companies table, company_id columns, next_id update)"
```

---

## Task 2: shared.js — Company State Management

**Files:**
- Modify: `shared.js` (add company state functions after existing session code)

Add company selection state management, helper functions, and the company switcher widget injection.

- [ ] **Step 1: Add company constants and state functions to shared.js**

Add after the existing `dbNextId()` function (around line 367):

```javascript
// ============================================================
// COMPANY MANAGEMENT
// ============================================================
const COMPANIES = {
  tg_agro_fruits: { id: 'tg_agro_fruits', name: 'TG Agro Fruits Sdn Bhd', short: 'TG Agro Fruits', code: 'AF' },
  tg_agribusiness: { id: 'tg_agribusiness', name: 'TG Agribusiness Sdn Bhd', short: 'TG Agribusiness', code: 'AB' }
};

// Module-to-company mapping: which company each module belongs to
// 'shared' means visible in both companies
const MODULE_COMPANY = {
  sales: 'tg_agro_fruits',
  inventory: 'tg_agribusiness',
  workers: 'tg_agribusiness',
  spraytracker: 'tg_agribusiness',
  growthtracker: 'tg_agribusiness',
  farmconfig: 'shared',
  seedlings: 'tg_agribusiness'
};

function getCompanyId() {
  return localStorage.getItem('tgfarmhub_company') || 'tg_agro_fruits';
}

function setCompanyId(companyId) {
  localStorage.setItem('tgfarmhub_company', companyId);
}

function getCompany() {
  return COMPANIES[getCompanyId()];
}

function getCompanyCode() {
  return getCompany().code;
}

// Check if a module is visible for the currently selected company
function isModuleVisible(moduleKey) {
  var mapping = MODULE_COMPANY[moduleKey];
  if (!mapping || mapping === 'shared') return true;
  return mapping === getCompanyId();
}
```

- [ ] **Step 2: Update dbNextId to pass company code**

Replace the existing `dbNextId` function in shared.js (lines 358-367):

```javascript
// Generate next ID via DB function — includes company prefix
async function dbNextId(prefix) {
  try {
    var code = getCompanyCode();
    var result = await sb.rpc("next_id", { p_prefix: prefix, p_company_code: code });
    if (result.error) throw result.error;
    return result.data;
  } catch(e) {
    console.error("ID gen error:", e);
    var code = getCompanyCode();
    return code + '-' + prefix + String(Date.now()).slice(-6);
  }
}
```

- [ ] **Step 3: Verify shared.js loads without errors**

Open any module page in browser, check browser console for JavaScript errors. The new functions should be available globally.

- [ ] **Step 4: Commit**

```bash
git add shared.js
git commit -m "feat: add company state management and update dbNextId with company prefix"
```

---

## Task 3: shared.css — Company Switcher Styles

**Files:**
- Modify: `shared.css` (add company switcher styles)

- [ ] **Step 1: Add company switcher CSS**

Add after the existing `.sidebar-brand` styles in shared.css:

```css
/* ---- Company Switcher ---- */
.company-switcher {
  padding: 8px 12px;
  border-bottom: 1px solid var(--border);
  display: flex;
  gap: 4px;
}
.company-switcher .company-btn {
  flex: 1;
  padding: 7px 4px;
  border: 1px solid var(--border);
  border-radius: 6px;
  background: transparent;
  color: var(--text-muted);
  font-size: 10px;
  font-weight: 600;
  cursor: pointer;
  text-align: center;
  line-height: 1.3;
  transition: all 0.15s;
}
.company-switcher .company-btn:hover {
  border-color: var(--text-muted);
}
.company-switcher .company-btn.active {
  background: var(--green);
  border-color: var(--green);
  color: #fff;
}
/* Mobile: stack vertically if sidebar is narrow */
@media (max-width: 768px) {
  .company-switcher {
    padding: 6px 10px;
  }
  .company-switcher .company-btn {
    font-size: 9px;
    padding: 6px 3px;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add shared.css
git commit -m "feat: add company switcher CSS styles"
```

---

## Task 4: index.html — Hub Page Company Switcher & Module Filtering

**Files:**
- Modify: `index.html` (hub page)

This is the main UX change. Add the company toggle to the hub header and filter module cards based on selected company.

- [ ] **Step 1: Add company switcher HTML to the hub header**

In `index.html`, find the hub header section (around line 42-60) and add the company switcher after the hub brand div, before the hub-nav:

```html
<!-- Company Switcher -->
<div class="hub-company-switcher">
  <button class="hub-company-btn" data-company="tg_agro_fruits" onclick="switchCompany('tg_agro_fruits')">
    🍍 TG Agro Fruits
  </button>
  <button class="hub-company-btn" data-company="tg_agribusiness" onclick="switchCompany('tg_agribusiness')">
    🌴 TG Agribusiness
  </button>
</div>
```

Add the CSS for the hub company switcher in the `<style>` section of index.html (in index.css or inline):

```css
.hub-company-switcher {
  display: flex;
  gap: 8px;
  justify-content: center;
  margin: 12px auto 0;
  max-width: 400px;
}
.hub-company-btn {
  flex: 1;
  padding: 10px 16px;
  border: 2px solid var(--border);
  border-radius: 10px;
  background: var(--card-bg);
  color: var(--text-muted);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}
.hub-company-btn:hover {
  border-color: var(--green);
  color: var(--text);
}
.hub-company-btn.active {
  background: var(--green);
  border-color: var(--green);
  color: #fff;
}
@media (max-width: 768px) {
  .hub-company-btn {
    font-size: 12px;
    padding: 8px 10px;
  }
}
```

- [ ] **Step 2: Add switchCompany() function and update renderModuleCards()**

In the `<script>` section of index.html, add the `switchCompany` function:

```javascript
function switchCompany(companyId) {
  setCompanyId(companyId);
  // Update button states
  document.querySelectorAll('.hub-company-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.company === companyId);
  });
  // Re-render module cards filtered by company
  renderModuleCards();
}
```

- [ ] **Step 3: Update renderModuleCards() to filter by company**

Modify the existing `renderModuleCards()` function (line 611-637). Add company filtering at the top of the `.map()` callback, right after the existing `if (m.hubPage) return "";` check:

```javascript
// Filter by selected company
if (!isModuleVisible(m.key)) return "";
```

So the full function becomes:

```javascript
function renderModuleCards() {
  const grid = document.getElementById("module-grid");
  grid.innerHTML = MODULES.map(m => {
    const hasAccess = hasModuleAccess(m.key);
    const clickable = m.active && hasAccess;
    const badgeClass = m.active ? "badge-active" : "badge-soon";
    const badgeText = m.active ? "Active" : "Coming Soon";

    // Skip hub-page entries (they are not module cards)
    if (m.hubPage) return "";

    // Filter by selected company
    if (!isModuleVisible(m.key)) return "";

    // Hide coming-soon modules from non-admin users who have no access
    if (!m.active && currentUser.role !== "admin") return "";

    return `
      <div class="module-card${clickable ? "" : " disabled"}"
        onclick="${clickable ? "window.location.href='" + m.url + "?session=" + currentUser.id + "'" : ""}"
        title="${!m.active ? "Coming soon" : !hasAccess ? "No access — contact admin" : "Open " + m.name}">
        <span class="module-badge ${badgeClass}">${badgeText}</span>
        <span class="module-icon">${m.icon}</span>
        <div class="module-name">${m.name}</div>
        <div class="module-desc">${m.desc}</div>
        ${!hasAccess && m.active ? '<div style="font-size:11px;color:var(--critical);margin-top:10px;">🔒 No access — contact admin</div>' : ""}
      </div>
    `;
  }).join("");
}
```

- [ ] **Step 4: Initialize company switcher on page load**

In the hub initialization code (after login/session restore succeeds), add:

```javascript
// Initialize company switcher
var savedCompany = getCompanyId();
document.querySelectorAll('.hub-company-btn').forEach(btn => {
  btn.classList.toggle('active', btn.dataset.company === savedCompany);
});
renderModuleCards();
```

- [ ] **Step 5: Update the MODULES array — add `company` property**

Update each module definition in the MODULES array to include which company it belongs to (this is a convenience for hub-specific logic, the canonical mapping is in shared.js `MODULE_COMPANY`):

```javascript
const MODULES = [
  { key: "sales", name: "Sales", icon: "🍍", desc: "...", url: "sales.html", active: true, company: "tg_agro_fruits", permissions: [...] },
  { key: "inventory", name: "Inventory Management", icon: "📦", desc: "...", url: "inventory.html", active: true, company: "tg_agribusiness", permissions: [...] },
  { key: "workers", name: "Worker Management", icon: "👷", desc: "...", url: "workers.html", active: true, company: "tg_agribusiness", permissions: [...] },
  { key: "spraytracker", name: "PND Spray Tracker", icon: "🌿", desc: "...", url: "spraytracker.html", active: true, company: "tg_agribusiness", permissions: [...] },
  { key: "growthtracker", name: "Growth Tracker", icon: "🌱", desc: "...", url: "growthtracker.html", active: true, company: "tg_agribusiness", permissions: [...] },
  { key: "farmconfig", name: "Farm Configuration", icon: "🌾", desc: "...", url: null, active: true, hubPage: true, company: "shared", permissions: [...] },
  { key: "seedlings", name: "Oil Palm Seedlings", icon: "🌴", desc: "...", url: "seedlings.html", active: false, company: "tg_agribusiness", permissions: [...] },
];
```

- [ ] **Step 6: Test hub page**

Open `index.html` in browser:
1. Verify company switcher shows two buttons
2. Click "TG Agro Fruits" → only Sales module card visible + Farm Config nav tab
3. Click "TG Agribusiness" → Inventory, Workers, Spray Tracker, Growth Tracker visible + Farm Config
4. Refresh page → last selected company is remembered
5. Check mobile view → switcher buttons readable on phone width

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: add company switcher to hub page with module filtering"
```

---

## Task 5: Module Sidebar Company Switcher

**Files:**
- Modify: `shared.js` (add sidebar company switcher injection function)
- Modify: `sales.html`, `inventory.html`, `workers.html`, `spraytracker.html`, `growthtracker.html` (add switcher container div)

Each module page needs a compact company switcher in the sidebar so users can see which company context they're in. For modules that belong to only one company, the switcher shows the current company as a label (not clickable). The switcher is clickable only on the hub page — on module pages, clicking switches back to the hub with that company selected.

- [ ] **Step 1: Add injectCompanySwitcher() to shared.js**

Add after the company management section:

```javascript
// Inject company switcher into sidebar (called by each module on load)
function injectCompanySwitcher() {
  var container = document.getElementById('company-switcher');
  if (!container) return;
  var current = getCompany();
  container.innerHTML = '<div class="company-switcher">' +
    Object.values(COMPANIES).map(function(c) {
      var isActive = c.id === current.id;
      return '<button class="company-btn' + (isActive ? ' active' : '') + '"' +
        ' onclick="' + (isActive ? '' : "setCompanyId('" + c.id + "');location.href='index.html?session=" + (window.currentUser ? currentUser.id : '') + "'") + '"' +
        '>' + c.short + '</button>';
    }).join('') +
    '</div>';
}
```

- [ ] **Step 2: Add company switcher container to each module's sidebar HTML**

In each module file (`sales.html`, `inventory.html`, `workers.html`, `spraytracker.html`, `growthtracker.html`), add this div inside the `.sidebar` element, right after the `.sidebar-brand` closing div and before the `<nav class="sidebar-nav">`:

```html
<div id="company-switcher"></div>
```

- [ ] **Step 3: Call injectCompanySwitcher() on module load**

In each module's initialization code (where `injectUserBadge()` is already called), add a call to `injectCompanySwitcher()` right before or after it:

```javascript
injectCompanySwitcher();
```

- [ ] **Step 4: Test across modules**

Open each module and verify:
1. Company switcher appears in sidebar below brand
2. Current company button is highlighted green
3. Clicking the other company button redirects to hub with that company selected
4. Mobile: switcher is compact and readable

- [ ] **Step 5: Commit**

```bash
git add shared.js sales.html inventory.html workers.html spraytracker.html growthtracker.html
git commit -m "feat: add company switcher to all module sidebars"
```

---

## Task 6: Sales Module — Add company_id to All Queries

**Files:**
- Modify: `sales.html`

The Sales module belongs to TG Agro Fruits. All queries need to include `.eq('company_id', getCompanyId())` on selects and include `company_id: getCompanyId()` in all inserts.

- [ ] **Step 1: Update loadAllData() — add company_id filter to all SELECT queries**

In `sales.html`, find `loadAllData()` (around line 1113). Add `.eq('company_id', getCompanyId())` to every `sbQuery(sb.from(...))` call for company-owned tables. Do NOT add to `crop_varieties`, `workers`, or `users` queries (those are shared/cross-company).

Example for sales_customers:
```javascript
// Before:
sbQuery(sb.from('sales_customers').select('*').order('name'))
// After:
sbQuery(sb.from('sales_customers').select('*').eq('company_id', getCompanyId()).order('name'))
```

Apply to: `sales_customers`, `sales_products`, `sales_orders`, `sales_order_items`, `sales_payments`, `sales_returns`, `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, `sales_invoice_payments`, `sales_credit_notes`.

Do NOT filter: `crop_varieties`, `workers`, `users`, `sales_drivers`.

- [ ] **Step 2: Update all INSERT operations — add company_id field**

Search sales.html for all `.insert(` calls. Each insert object needs `company_id: getCompanyId()` added. There are inserts for:
- `sales_customers` (around line 3064)
- `sales_products` (around line 3581)
- `sales_orders` (around line 6581)
- `sales_order_items` (around line 6555, 6609)
- `sales_payments` (around line 2703, 2779, 4148, 4174)
- `sales_returns` (around line 7748)
- `sales_invoices` (around line 5547)
- `sales_invoice_items` (around line 5462, 5611)
- `sales_invoice_payments` (around line 4955)
- `sales_credit_notes` (around line 5111)

Example:
```javascript
// Before:
.insert({ id: newId, name: name, ... }).select()
// After:
.insert({ id: newId, name: name, company_id: getCompanyId(), ... }).select()
```

- [ ] **Step 3: Verify document numbering**

The `dbNextId()` calls in sales.html already use the updated function from Task 2 which automatically includes the company code. Verify by creating a test order — the ID should be `AF-SO-YYMMDD-NNN`.

No code changes needed for dbNextId calls — they were already updated in shared.js.

- [ ] **Step 4: Test the Sales module**

1. Open sales.html → verify all existing data loads (it should — company_id was backfilled)
2. Create a new customer → check in Supabase that `company_id = 'tg_agro_fruits'`
3. Create a new order → verify document number starts with `AF-`
4. Check all tabs (Dashboard, Orders, Payments, Invoicing, Customers, Products, Reports)

- [ ] **Step 5: Commit**

```bash
git add sales.html
git commit -m "feat: add company_id filtering and insertion to Sales module"
```

---

## Task 7: Inventory Module — Add company_id to All Queries

**Files:**
- Modify: `inventory.html`

- [ ] **Step 1: Update all SELECT queries with company_id filter**

Add `.eq('company_id', getCompanyId())` to queries for: `products`, `suppliers`, `transactions`.

Do NOT filter: `pnd_ingredients`, `pnd_formulations` (these are shared reference data linked to spray products).

- [ ] **Step 2: Update all INSERT operations with company_id**

Add `company_id: getCompanyId()` to all insert objects for: `products`, `suppliers`, `transactions`.

- [ ] **Step 3: Test**

1. Open inventory.html → existing data loads
2. Add a new product → verify `company_id = 'tg_agribusiness'` in DB
3. Record a stock-in transaction → verify company_id set

- [ ] **Step 4: Commit**

```bash
git add inventory.html
git commit -m "feat: add company_id filtering and insertion to Inventory module"
```

---

## Task 8: Workers Module — Add company_id to All Queries

**Files:**
- Modify: `workers.html`

- [ ] **Step 1: Update all SELECT queries with company_id filter**

Add `.eq('company_id', getCompanyId())` to queries for: `workers`, `payroll_periods`, `salary_advances`, `task_types`, `worker_roles`, `responsibility_types`, `worker_default_responsibilities`, `worker_loans`, `loan_repayments`, `employment_stints`.

- [ ] **Step 2: Update all INSERT operations with company_id**

Add `company_id: getCompanyId()` to all insert objects for the same tables.

- [ ] **Step 3: Test**

1. Open workers.html → existing worker data loads
2. Add a new worker → verify `company_id = 'tg_agribusiness'`
3. Create payroll period → verify company_id set
4. Check all tabs (Workers, Payroll, Summary, Contract Types, Roles, Changelog)

- [ ] **Step 4: Commit**

```bash
git add workers.html
git commit -m "feat: add company_id filtering and insertion to Workers module"
```

---

## Task 9: Spray Tracker Module — Add company_id to All Queries

**Files:**
- Modify: `spraytracker.html`

- [ ] **Step 1: Update all SELECT queries with company_id filter**

Add `.eq('company_id', getCompanyId())` to queries for: `pnd_jobs`, `pnd_products`, `pnd_spray_logs`, `pnd_job_products`, `pnd_block_product_overrides`, `pnd_ingredients`, `pnd_formulations`, `pnd_product_ingredients`, `ai_combo_defaults`.

Do NOT filter: `pnd_blocks`, `pnd_block_statuses`, `block_crops`, `crop_statuses` (Farm Config shared data), `workers` (shared), `products` (inventory products loaded for linking — filter by company), `transactions`.

- [ ] **Step 2: Update all INSERT operations with company_id**

Add `company_id: getCompanyId()` to all insert objects for: `pnd_jobs`, `pnd_products`, `pnd_spray_logs`, `pnd_job_products`, `pnd_block_product_overrides`, `pnd_ingredients`, `pnd_formulations`, `pnd_product_ingredients`, `ai_combo_defaults`.

- [ ] **Step 3: Test**

1. Open spraytracker.html → existing data loads
2. Check Summary, Active Jobs, Job Logs, Products, Reports tabs
3. Create a new spray job → verify company_id set

- [ ] **Step 4: Commit**

```bash
git add spraytracker.html
git commit -m "feat: add company_id filtering and insertion to Spray Tracker module"
```

---

## Task 10: Growth Tracker & Delivery — Add company_id to Queries

**Files:**
- Modify: `growthtracker.html` (read-only, only SELECT queries)
- Modify: `delivery.html` (delivery queries need company_id)
- Modify: `display-sales.html` (filter by Agro Fruits)

- [ ] **Step 1: Update growthtracker.html**

Add `.eq('company_id', getCompanyId())` to `growth_records` / `growth_records_view` queries. Do NOT filter `block_crops`, `crop_varieties`, `blocks` (Farm Config shared data).

- [ ] **Step 2: Update delivery.html**

Add `.eq('company_id', 'tg_agro_fruits')` to delivery order queries (delivery is always Agro Fruits sales). Delivery.html uses its own Supabase init — add the filter to its order loading queries.

- [ ] **Step 3: Update display-sales.html**

Add `.eq('company_id', 'tg_agro_fruits')` to the sales order queries in the TV display. This is a standalone page with direct REST API calls — add the filter parameter.

- [ ] **Step 4: Test all three**

1. growthtracker.html → growth data loads normally
2. delivery.html → delivery orders load (phone view)
3. display-sales.html?token=pnd2026 → TV display works

- [ ] **Step 5: Commit**

```bash
git add growthtracker.html delivery.html display-sales.html
git commit -m "feat: add company_id filtering to Growth Tracker, Delivery, and Sales TV display"
```

---

## Task 11: Hub Page — Company Overview Report

**Files:**
- Modify: `index.html` (add a Company Overview section to the Modules page)

- [ ] **Step 1: Add Company Overview cards to the hub**

Below the module grid on the hub page, add a summary section that shows key numbers per company. Add the HTML:

```html
<div class="company-overview" id="company-overview" style="margin-top:24px;">
  <h3 style="color:var(--text-muted);font-size:14px;margin-bottom:12px;">Company Overview</h3>
  <div class="company-overview-cards" id="company-overview-cards" style="display:grid;grid-template-columns:1fr 1fr;gap:12px;"></div>
</div>
```

- [ ] **Step 2: Add loadCompanyOverview() function**

```javascript
async function loadCompanyOverview() {
  var container = document.getElementById('company-overview-cards');
  if (!container) return;

  // Load summary counts
  var [ordersAF, ordersAB, workersAB, jobsAB] = await Promise.all([
    sbQuery(sb.from('sales_orders').select('id,total_amount,payment_status', { count: 'exact' }).eq('company_id', 'tg_agro_fruits')),
    sbQuery(sb.from('sales_orders').select('id', { count: 'exact' }).eq('company_id', 'tg_agribusiness')),
    sbQuery(sb.from('workers').select('id', { count: 'exact' }).eq('company_id', 'tg_agribusiness').eq('active', true)),
    sbQuery(sb.from('pnd_jobs').select('id', { count: 'exact' }).eq('company_id', 'tg_agribusiness').eq('status', 'active'))
  ]);

  var afOrders = ordersAF || [];
  var afRevenue = afOrders.reduce((sum, o) => sum + (parseFloat(o.total_amount) || 0), 0);
  var afOutstanding = afOrders.filter(o => o.payment_status !== 'paid').reduce((sum, o) => sum + (parseFloat(o.total_amount) || 0), 0);

  container.innerHTML = `
    <div class="overview-card" style="background:var(--card-bg);border-radius:10px;padding:16px;border:1px solid var(--border);">
      <div style="font-weight:700;color:var(--green);margin-bottom:8px;">🍍 TG Agro Fruits</div>
      <div style="font-size:13px;color:var(--text-muted);">Orders: <b style="color:var(--text);">${afOrders.length}</b></div>
      <div style="font-size:13px;color:var(--text-muted);">Revenue: <b style="color:var(--text);">RM ${afRevenue.toFixed(2)}</b></div>
      <div style="font-size:13px;color:var(--text-muted);">Outstanding: <b style="color:var(--gold);">RM ${afOutstanding.toFixed(2)}</b></div>
    </div>
    <div class="overview-card" style="background:var(--card-bg);border-radius:10px;padding:16px;border:1px solid var(--border);">
      <div style="font-weight:700;color:var(--green);margin-bottom:8px;">🌴 TG Agribusiness</div>
      <div style="font-size:13px;color:var(--text-muted);">Active Workers: <b style="color:var(--text);">${(workersAB || []).length}</b></div>
      <div style="font-size:13px;color:var(--text-muted);">Active Spray Jobs: <b style="color:var(--text);">${(jobsAB || []).length}</b></div>
    </div>
  `;
}
```

- [ ] **Step 3: Call loadCompanyOverview() on hub load**

Add `loadCompanyOverview()` to the hub page initialization, after `renderModuleCards()` is called.

- [ ] **Step 4: Test**

1. Open hub page → company overview cards show below module grid
2. Verify numbers match actual data (cross-check with Supabase dashboard)
3. Check mobile view → cards stack properly

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: add Company Overview report cards to hub page"
```

---

## Task 12: Final Verification & Cleanup

- [ ] **Step 1: Full end-to-end test**

Test the complete flow:
1. Login → hub loads with company switcher defaulting to last selection
2. Select "TG Agro Fruits" → only Sales card visible
3. Open Sales → create a customer, create an order → doc number has AF- prefix
4. Go back to hub → switch to "TG Agribusiness"
5. See Inventory, Workers, Spray Tracker, Growth Tracker cards
6. Open Workers → verify worker list loads
7. Open Inventory → verify product list loads
8. Open Spray Tracker → verify spray data loads
9. Open Growth Tracker → verify growth data loads
10. Farm Config tab → accessible from either company selection
11. Company Overview cards → show correct numbers
12. delivery.html → still works (loads Agro Fruits orders)
13. display-sales.html?token=pnd2026 → still works
14. display-growth.html?token=pnd2026 → still works
15. Mobile view → company switcher works on phone

- [ ] **Step 2: Delete migration file**

```bash
rm multi_company_migration.sql
```

(Migration has been applied — file no longer needed per project convention)

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore: remove applied migration file, finalize multi-company architecture"
```

---

## Verification Summary

| Test | Expected Result |
|------|----------------|
| Hub: company switcher | Two buttons, last selection remembered |
| Hub: Agro Fruits selected | Only Sales card visible |
| Hub: Agribusiness selected | Inventory, Workers, Spray, Growth visible |
| Hub: Farm Config | Always visible as nav tab |
| Hub: Company Overview | Shows numbers for both companies |
| Sales: new order | Doc number starts with AF- |
| Sales: data loads | All existing data visible (company_id = tg_agro_fruits) |
| Workers: data loads | All existing workers visible (company_id = tg_agribusiness) |
| Inventory: data loads | All existing products visible |
| Spray Tracker: data loads | All spray data visible |
| Growth Tracker: data loads | Growth records visible |
| Delivery page | Loads Agro Fruits orders |
| TV displays | Work unchanged |
| Mobile | Company switcher usable on phone |
| Browser refresh | Company selection persisted |
