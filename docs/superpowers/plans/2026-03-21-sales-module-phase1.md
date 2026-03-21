# Sales Module Phase 1: Foundation — DB + Products + Customers + Hub Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the database schema, product catalog, customer management, and hub page integration for the pineapple sales module — the foundation all other phases build on.

**Architecture:** Single-page module (`sales.html`) following existing TG FarmHub patterns — static HTML/CSS/JS with Supabase backend. Tab-based navigation with sidebar. Mobile-first card-based layouts. All mutations use `sbQuery()` with `.select()`. IDs generated via `dbNextId()`.

**Tech Stack:** HTML, CSS, vanilla JS, Supabase v2.49.1 (CDN), shared.css/shared.js

**Spec:** `docs/superpowers/specs/2026-03-21-sales-module-design.md`

**Scope:** This is Phase 1 of 8. It covers DB schema, product catalog, customer management, dashboard stub, and hub integration. `delivery.html` and `display-sales.html` are deferred to Phases 7 and 8.

**Prerequisites:** `crop_varieties` table must contain MD2 and SG1 records (created by `phase4_farm_config_migration.sql`). The `next_id` RPC function auto-creates counter rows for new prefixes (SC, SP, SO, SI, SY, SR).

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `sales_migration.sql` | Create | All 6 sales tables, indexes, RLS, triggers |
| `sales.html` | Create | Main sales module — tabs, sidebar, all UI |
| `sales.css` | Create | Module-specific styles |
| `index.html` | Modify | Add Sales module card to hub page |
| `CLAUDE.md` | Modify | Document new module, migration, tables |

---

## Task 1: Database Migration

**Files:**
- Create: `sales_migration.sql`

- [ ] **Step 1: Write the migration SQL**

Create `sales_migration.sql` with all 6 tables, indexes, RLS policies, and triggers. Follow the idempotent pattern from `salary_advances_migration.sql` (DO blocks checking pg_policies).

```sql
-- ============================================================
-- TG FarmHub — Sales Module Migration
-- Tables: sales_customers, sales_products, sales_orders,
--         sales_order_items, sales_payments, sales_returns
-- ============================================================

-- 1. SALES CUSTOMERS
CREATE TABLE IF NOT EXISTS sales_customers (
  id              TEXT PRIMARY KEY,
  name            TEXT NOT NULL,
  contact_person  TEXT,
  phone           TEXT,
  address         TEXT,
  type            TEXT DEFAULT 'retail',
  channel         TEXT DEFAULT 'whatsapp_delivery',
  payment_terms   TEXT NOT NULL DEFAULT 'cash',
  notes           TEXT,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_customers_phone
  ON sales_customers(phone) WHERE phone IS NOT NULL;

-- 2. SALES PRODUCTS
CREATE TABLE IF NOT EXISTS sales_products (
  id              TEXT PRIMARY KEY,
  variety_id      TEXT REFERENCES crop_varieties(id),
  name            TEXT NOT NULL,
  category        TEXT NOT NULL,
  unit            TEXT NOT NULL DEFAULT 'kg',
  default_price   NUMERIC NOT NULL DEFAULT 0,
  box_quantity    INT,
  is_active       BOOLEAN DEFAULT true,
  sort_order      INT DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. SALES ORDERS
CREATE TABLE IF NOT EXISTS sales_orders (
  id              TEXT PRIMARY KEY,
  customer_id     TEXT NOT NULL REFERENCES sales_customers(id),
  order_date      DATE NOT NULL DEFAULT CURRENT_DATE,
  delivery_date   DATE,
  delivery_time   TEXT,
  channel         TEXT,
  fulfillment     TEXT NOT NULL DEFAULT 'delivery',
  status          TEXT NOT NULL DEFAULT 'pending',
  doc_type        TEXT NOT NULL DEFAULT 'cash_sales',
  doc_number      TEXT UNIQUE,
  driver_id       TEXT REFERENCES workers(id),
  qb_invoice_no   TEXT,
  qb_invoiced_at  DATE,
  subtotal        NUMERIC DEFAULT 0,
  return_total    NUMERIC DEFAULT 0,
  grand_total     NUMERIC DEFAULT 0,
  amount_paid     NUMERIC DEFAULT 0,
  payment_status  TEXT DEFAULT 'unpaid',
  prep_photo_url  TEXT,
  delivery_photo_url TEXT,
  notes           TEXT,
  created_by      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_orders_customer ON sales_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_orders_status ON sales_orders(status);
CREATE INDEX IF NOT EXISTS idx_sales_orders_order_date ON sales_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_sales_orders_delivery_date ON sales_orders(delivery_date);
CREATE INDEX IF NOT EXISTS idx_sales_orders_doc_type ON sales_orders(doc_type);
CREATE INDEX IF NOT EXISTS idx_sales_orders_payment_status ON sales_orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_sales_orders_driver ON sales_orders(driver_id);

-- 4. SALES ORDER ITEMS
CREATE TABLE IF NOT EXISTS sales_order_items (
  id              TEXT PRIMARY KEY,
  order_id        TEXT NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
  product_id      TEXT NOT NULL REFERENCES sales_products(id),
  index_min       INT CHECK (index_min >= 0 AND index_min <= 5),
  index_max       INT CHECK (index_max >= 0 AND index_max <= 5),
  quantity        NUMERIC NOT NULL,
  unit_price      NUMERIC NOT NULL,
  line_total      NUMERIC NOT NULL,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_order_items_order ON sales_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_sales_order_items_product ON sales_order_items(product_id);

-- 5. SALES PAYMENTS
CREATE TABLE IF NOT EXISTS sales_payments (
  id              TEXT PRIMARY KEY,
  order_id        TEXT NOT NULL REFERENCES sales_orders(id),
  amount          NUMERIC NOT NULL,
  payment_date    DATE NOT NULL DEFAULT CURRENT_DATE,
  method          TEXT NOT NULL DEFAULT 'cash',
  reference       TEXT,
  notes           TEXT,
  created_by      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_payments_order ON sales_payments(order_id);

-- 6. SALES RETURNS
CREATE TABLE IF NOT EXISTS sales_returns (
  id              TEXT PRIMARY KEY,
  order_id        TEXT NOT NULL REFERENCES sales_orders(id),
  item_id         TEXT REFERENCES sales_order_items(id),
  quantity        NUMERIC NOT NULL,
  amount          NUMERIC NOT NULL,
  reason          TEXT,
  resolution      TEXT NOT NULL CHECK (resolution IN ('deduct','refund','debit_note')),
  debit_note_no   TEXT,
  debit_note_used_on TEXT REFERENCES sales_orders(id),
  photo_url       TEXT,
  created_by      TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sales_returns_order ON sales_returns(order_id);

-- ============================================================
-- RLS POLICIES (all tables, anon + authenticated)
-- ============================================================

ALTER TABLE sales_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_returns ENABLE ROW LEVEL SECURITY;

-- Helper: create SELECT/INSERT/UPDATE/DELETE policies for a table
DO $$
DECLARE
  t TEXT;
  ops TEXT[] := ARRAY['SELECT','INSERT','UPDATE','DELETE'];
  op TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['sales_customers','sales_products','sales_orders','sales_order_items','sales_payments','sales_returns']
  LOOP
    FOREACH op IN ARRAY ops
    LOOP
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = t || '_' || lower(op) || '_anon') THEN
        EXECUTE format('CREATE POLICY %I ON %I FOR %s TO anon USING (true) WITH CHECK (true)', t || '_' || lower(op) || '_anon', t, op);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = t || '_' || lower(op) || '_auth') THEN
        EXECUTE format('CREATE POLICY %I ON %I FOR %s TO authenticated USING (true) WITH CHECK (true)', t || '_' || lower(op) || '_auth', t, op);
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sales_customers_set_updated_at') THEN
    CREATE TRIGGER sales_customers_set_updated_at BEFORE UPDATE ON sales_customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sales_products_set_updated_at') THEN
    CREATE TRIGGER sales_products_set_updated_at BEFORE UPDATE ON sales_products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sales_orders_set_updated_at') THEN
    CREATE TRIGGER sales_orders_set_updated_at BEFORE UPDATE ON sales_orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END;
$$;
```

- [ ] **Step 2: Run the migration**

```bash
cd "C:/Users/yapwa/OneDrive/TG Web and Android Project/TG Farmhub Website"
npm install pg
node -e "
const fs = require('fs');
const { Client } = require('pg');
const sql = fs.readFileSync('sales_migration.sql', 'utf8');
const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 5432, database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false }
});
(async () => {
  await client.connect();
  await client.query(sql);
  console.log('Done');
  await client.end();
})().catch(e => { console.error(e); });
"
rm -rf node_modules package-lock.json package.json
```

Expected: `Done` with no errors.

- [ ] **Step 3: Verify tables exist**

Run a quick query to confirm all 6 tables were created:
```bash
node -e "
const { Client } = require('pg');
const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com', port: 5432, database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc', password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false }
});
(async () => {
  await client.connect();
  const r = await client.query(\"SELECT tablename FROM pg_tables WHERE tablename LIKE 'sales_%' ORDER BY tablename\");
  console.log(r.rows.map(r=>r.tablename));
  await client.end();
})().catch(console.error);
"
```

Expected: `['sales_customers', 'sales_order_items', 'sales_orders', 'sales_payments', 'sales_products', 'sales_returns']`

- [ ] **Step 4: Commit**

```bash
git add sales_migration.sql
git commit -m "Add sales module database migration (6 tables, RLS, indexes, triggers)"
```

---

## Task 2: Create `sales.css` — Module Styles

**Files:**
- Create: `sales.css`

- [ ] **Step 1: Create the module CSS file**

Create `sales.css` with mobile-first styles for the sales module. Follow the pattern from `spraytracker.css` — module-specific overrides only, shared styles come from `shared.css`.

```css
/* ============================================================
   TG FarmHub — Sales Module Styles
   ============================================================ */

/* Order/Customer cards (mobile-first, card-based layout) */
.sales-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 14px 16px;
  margin-bottom: 10px;
  cursor: pointer;
  transition: border-color 0.15s;
}
.sales-card:hover { border-color: var(--green); }
.sales-card:active { background: var(--bg-hover); }

.sales-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 8px;
}

.sales-card-title {
  font-weight: 700;
  font-size: 14px;
  color: var(--white);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sales-card-meta {
  font-size: 11px;
  color: var(--text-muted);
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.sales-card-total {
  font-size: 16px;
  font-weight: 800;
  color: var(--gold-light);
}

.sales-card-items {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 6px;
  line-height: 1.6;
}

/* Status badges */
.badge-pending { background: rgba(96,160,232,0.15); color: #60A0E8; }
.badge-preparing { background: rgba(232,160,32,0.15); color: #E8A020; }
.badge-prepared { background: rgba(74,124,63,0.15); color: #6B9E5E; }
.badge-delivering { background: rgba(160,120,230,0.15); color: #A078E6; }
.badge-completed { background: rgba(74,124,63,0.2); color: #6ECB63; }
.badge-cancelled { background: rgba(128,128,128,0.15); color: #888; }

/* Doc type badges */
.badge-do { background: rgba(100,149,237,0.15); color: #6495ED; }
.badge-cs { background: rgba(232,160,32,0.15); color: #E8A020; }

/* Payment status badges */
.badge-unpaid { background: rgba(232,96,96,0.15); color: #E86060; }
.badge-partial { background: rgba(232,160,32,0.15); color: #E8A020; }
.badge-paid { background: rgba(74,124,63,0.15); color: #6B9E5E; }

/* Customer return rate */
.return-rate-green { color: var(--good); }
.return-rate-yellow { color: var(--gold); }
.return-rate-red { color: var(--red); }

/* Tab bar (horizontal scrollable on mobile) */
.sales-tabs {
  display: flex;
  gap: 0;
  border-bottom: 1px solid var(--border);
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  margin-bottom: 20px;
}
.sales-tab {
  padding: 10px 18px;
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  transition: all 0.15s;
  white-space: nowrap;
  flex-shrink: 0;
  background: none;
  border-top: none;
  border-left: none;
  border-right: none;
  font-family: inherit;
}
.sales-tab:hover { color: var(--text); }
.sales-tab.active { color: var(--green-light); border-bottom-color: var(--green-light); }

/* Bottom action bar (mobile) */
.bottom-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--bg-card);
  border-top: 1px solid var(--border);
  padding: 10px 16px;
  display: flex;
  gap: 10px;
  z-index: 100;
}
.bottom-actions .btn { flex: 1; justify-content: center; min-height: 44px; font-size: 13px; }

/* Aging buckets */
.aging-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
  border-bottom: 1px solid var(--border);
  font-size: 13px;
}
.aging-label { flex: 1; color: var(--text); }
.aging-count { color: var(--text-muted); font-size: 12px; min-width: 60px; }
.aging-amount { font-weight: 700; min-width: 100px; text-align: right; }
.aging-0-7 .aging-amount { color: var(--text); }
.aging-8-14 .aging-amount { color: var(--gold); }
.aging-15-30 .aging-amount { color: var(--gold-light); }
.aging-30plus .aging-amount { color: var(--red); }

/* Customer duplicate warning */
.duplicate-warning {
  background: var(--gold-pale);
  border: 1px solid rgba(232,160,32,0.25);
  border-radius: 8px;
  padding: 10px 14px;
  font-size: 12px;
  color: var(--gold-light);
  margin-top: 6px;
}

/* Order item row (in order form) */
.order-item-row {
  background: var(--bg-input);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 12px;
  margin-bottom: 8px;
}

/* Empty state */
.empty-state { padding: 40px; text-align: center; color: var(--text-dim); font-size: 14px; }

/* Spin */
.spin { animation: spin 1s linear infinite; }

/* Search bar */
.search-bar {
  position: relative;
  margin-bottom: 14px;
}
.search-bar input {
  width: 100%;
  padding: 10px 14px 10px 36px;
  font-size: 14px;
}
.search-bar svg {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 16px;
  height: 16px;
  color: var(--text-dim);
}

/* Filter bar */
.sales-filters {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 14px;
  align-items: center;
}
.sales-filters select { min-width: 130px; }

/* Status timeline */
.status-timeline {
  display: flex;
  align-items: center;
  gap: 0;
  margin: 16px 0;
}
.timeline-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  position: relative;
}
.timeline-dot {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  color: var(--text-dim);
  z-index: 1;
}
.timeline-dot.done { background: var(--green); color: white; }
.timeline-dot.current { background: var(--gold); color: #1a1a1a; }
.timeline-label { font-size: 9px; color: var(--text-dim); margin-top: 4px; text-align: center; }
.timeline-line {
  position: absolute;
  top: 12px;
  left: 50%;
  right: -50%;
  height: 2px;
  background: var(--border);
}
.timeline-line.done { background: var(--green); }
.timeline-step:last-child .timeline-line { display: none; }

/* Print */
@media print {
  .sales-tabs, .sales-filters, .bottom-actions, .btn { display: none !important; }
  .page { display: none !important; }
  .page.active { display: block !important; }
}

/* Mobile: bottom padding for fixed action bar */
@media (max-width: 768px) {
  .main-content { padding-bottom: 80px !important; }
  .sales-card-header { flex-wrap: wrap; }
}
```

- [ ] **Step 2: Commit**

```bash
git add sales.css
git commit -m "Add sales module CSS (cards, badges, tabs, mobile-first)"
```

---

## Task 3: Create `sales.html` — Scaffold with Sidebar + Tabs

**Files:**
- Create: `sales.html`

- [ ] **Step 1: Create the base HTML structure**

Create `sales.html` with the standard TG FarmHub structure: head (fonts, Supabase SDK, shared.css, sales.css, shared.js), loading screen, skip link, sidebar, main content with tab navigation, and the script section with Supabase init + session guard.

Follow the exact pattern from `spraytracker.html` — sidebar with back link to hub, nav items for each tab, main content area with page divs.

The HTML should include:
- Standard head (favicon, viewport, fonts, Supabase CDN, shared.css, sales.css, shared.js)
- Loading overlay (`#tg-loading`)
- Skip link
- App container with sidebar (back to hub, module logo, nav items for 7 tabs)
- Main content with 7 page divs (dashboard, orders, customers, products, payments, invoicing, reports)
- Tab switching JS
- Session guard (redirect to index.html if no session)
- Data loading functions (empty stubs for now)

**Key elements to include:**
- Nav items: Dashboard, Orders, Customers, Products, Payments, Invoicing, Reports
- Bottom action bar with "New Order" button (visible on mobile)
- All page sections as `<div class="page" id="page-xxx">`
- Tab switching function `switchTab(tabName)`

- [ ] **Step 2: Add session guard and data loading stubs**

In the `<script>` section, add:
- Session guard (same pattern as spraytracker.html)
- Global arrays: `customers`, `salesProducts`, `orders`, `orderItems`, `payments`, `returns`
- `loadAllData()` async function that loads all 6 tables
- Render stubs for each tab (empty functions for now)
- Tab switching logic
- Inactivity timer start

- [ ] **Step 3: Verify page loads**

Open `sales.html?session=U001` in browser. Should show:
- Sidebar with 7 nav items
- Empty dashboard page
- Tab navigation working (click each tab, correct page shows)
- No console errors

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "Add sales.html scaffold (sidebar, tabs, session guard, data stubs)"
```

---

## Task 4: Products Tab — CRUD

**Files:**
- Modify: `sales.html`

- [ ] **Step 1: Implement Products tab UI**

In the Products page div, add:
- Product list grouped by variety (MD2 section, SG1 section)
- Each product card shows: name, category badge, unit, price
- "Add Product" button in header
- Price editing with explicit Save button (not auto-save)
- Active/inactive toggle with confirmation

- [ ] **Step 2: Implement product modal**

Add product modal HTML with fields:
- Variety (dropdown from crop_varieties)
- Name (text)
- Category (dropdown: whole_crown, whole_no_crown, slice, peeled, slice_box, chunk_box, ring_box)
- Unit (dropdown: kg, pcs, box)
- Default Price (number)
- Box Quantity (number, shown only when category is *_box)

- [ ] **Step 3: Implement save/edit/toggle functions**

Add JS functions:
- `openProductModal(editId)` — opens modal, pre-fills if editing
- `saveProduct()` — insert or update via sbQuery, with btnLoading
- `toggleProductActive(id)` — toggle with confirmAction for deactivation
- `renderProducts()` — renders the product list grouped by variety
- `loadVarieties()` — load crop_varieties for dropdown

- [ ] **Step 4: Verify CRUD works**

- Add a test product (SG1 Whole >1kg Crown, RM 3.50/kg)
- Edit its price to RM 4.00
- Deactivate it (should show confirmation)
- Reactivate it

- [ ] **Step 5: Commit**

```bash
git add sales.html
git commit -m "Sales: implement Products tab (CRUD, variety grouping, price management)"
```

---

## Task 5: Customers Tab — CRUD with Duplicate Prevention

**Files:**
- Modify: `sales.html`

- [ ] **Step 1: Implement Customers tab UI**

In the Customers page div, add:
- Search bar (search by name or phone, real-time filter)
- Customer list as cards (name, phone, type badge, payment terms badge)
- "Add Customer" button
- Filter: type (all, wholesale, retail, walkin), payment terms (all, credit, cash), active/inactive

- [ ] **Step 2: Implement customer modal with duplicate prevention**

Add customer modal with fields:
- Phone (text) — on blur, calls `checkDuplicatePhone(phone)` which queries existing customers
- If duplicate found: show warning banner with existing customer name + link
- Name (text)
- Contact Person (text, optional)
- Address (textarea)
- Type (dropdown: wholesale, retail, walkin)
- Channel (dropdown: whatsapp_delivery, whatsapp_collect, walkin)
- Payment Terms (dropdown: credit, cash)
- Notes (textarea)

- [ ] **Step 3: Implement save/edit functions**

Add JS functions:
- `openCustomerModal(editId)` — opens modal, pre-fills if editing
- `saveCustomer()` — validate phone uniqueness, insert/update via sbQuery
- `checkDuplicatePhone(phone)` — queries sales_customers by phone, shows warning if found
- `renderCustomers()` — renders filtered/searched customer cards
- `openCustomerDetail(id)` — shows customer profile with purchase history (stub for now, Phase 2 will populate)

- [ ] **Step 4: Verify duplicate prevention**

- Add customer "Test Farm" with phone "0121234567"
- Try adding another customer with same phone — should show duplicate warning
- Edit existing customer — should not trigger duplicate warning for own phone

- [ ] **Step 5: Commit**

```bash
git add sales.html
git commit -m "Sales: implement Customers tab (CRUD, search, duplicate phone prevention)"
```

---

## Task 6: Dashboard Tab — Summary Cards + Outstanding Payments Stub

**Files:**
- Modify: `sales.html`

- [ ] **Step 1: Implement Dashboard layout**

Add to Dashboard page:
- 4 summary cards (Orders Today, Pending Preparation, Ready for Delivery, Outstanding Payments)
- Outstanding Payments aging section (4 rows: 0-7d, 8-14d, 15-30d, 30+d)
- Today's Orders section (grouped by status) — reads from orders array

All values compute from in-memory arrays. For Phase 1, most will show 0 since we haven't built order creation yet.

- [ ] **Step 2: Implement render functions**

Add JS functions:
- `renderDashboard()` — calculates all summary values and renders cards + aging
- `calcAgingBuckets()` — groups unpaid orders by days since order_date

- [ ] **Step 3: Verify dashboard renders**

Open sales.html — Dashboard tab should show all cards with 0 values and empty aging section.

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "Sales: implement Dashboard tab (summary cards, aging section)"
```

---

## Task 7: Hub Page Integration

**Files:**
- Modify: `index.html`

- [ ] **Step 1: Add Sales module to MODULES array**

In `index.html`, the hub page renders module cards dynamically from a `MODULES` JavaScript array. Find this array and add a Sales entry after Growth Tracker:

```javascript
{
  key: "sales",
  name: "Sales",
  icon: "🍍",
  desc: "Pineapple sales orders, customers, payments, delivery tracking, and reports",
  url: "sales.html",
  active: true,
  permissions: [
    { key: "view", label: "View orders & customers" },
    { key: "create", label: "Create / edit orders" },
    { key: "payments", label: "Record payments" },
    { key: "reports", label: "View sales reports" }
  ]
}
```

**Important:** Do NOT add raw HTML. The hub page renders cards from this array.

- [ ] **Step 2: Verify navigation**

- Log in to hub page
- See Sales card with 🍍 icon
- Click it — should navigate to sales.html with session param
- Sales page loads with sidebar, tabs, empty data

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "Hub: add Sales module card"
```

---

## Task 8: Seed Products Data

**Files:**
- Modify: `sales.html` (use the Products tab UI)

- [ ] **Step 1: Add initial products via the UI**

Using the Products tab, add these initial products:

| Variety | Name | Category | Unit | Price |
|---------|------|----------|------|-------|
| SG1 | Whole Fruit >1kg (Crown) | whole_crown | kg | 3.50 |
| SG1 | Whole Fruit <1kg (Crown) | whole_crown | kg | 2.50 |
| MD2 | Whole Fruit >1kg (Crown) | whole_crown | kg | 3.50 |
| MD2 | Whole Fruit <1kg (Crown) | whole_crown | kg | 2.50 |
| SG1 | Slices (Individual) | slice | pcs | 2.00 |
| SG1 | Peeled Whole | peeled | pcs | 0 |

Note: Peeled Whole price is 0 (TBD — Waylon will set later).

- [ ] **Step 2: Verify products render correctly**

Products tab should show two groups (MD2, SG1) with products listed under each.

- [ ] **Step 3: No commit needed** (data is in Supabase, not in code)

---

## Task 9: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add Sales module documentation**

Add to the Modules — Status section under "Active (Built)":
```
7. **Sales** — Customer management, order workflow, payment tracking, delivery orders, cash sales, reports
```

Add to Key Files table:
```
| `sales.html` | Sales Management module |
| `sales.css` | Sales module styles |
```

Add migration to SQL Migrations table:
```
| `sales_migration.sql` | Created 6 sales tables (customers, products, orders, items, payments, returns) with RLS + indexes |
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Update CLAUDE.md with Sales module documentation"
```

---

## Phase 1 Completion Checklist

After all tasks complete, verify:
- [ ] All 6 database tables exist with correct columns, RLS, and indexes
- [ ] `sales.html` loads with sidebar, 7 tabs, session guard
- [ ] Products tab: can add, edit, deactivate products
- [ ] Customers tab: can add, edit customers; duplicate phone prevention works
- [ ] Dashboard tab: shows summary cards (all 0s for now)
- [ ] Hub page: Sales card visible and navigates correctly
- [ ] Mobile: page loads cleanly on phone, tabs scroll horizontally, cards are tappable
- [ ] No console errors on any tab

---

## What's Next (Phase 2)

Phase 2 will build on this foundation:
- Order creation flow (customer selection → items → save)
- Order status workflow (pending → preparing → prepared → delivering → completed)
- WhatsApp message generation for workers
- Order detail view with status timeline
