# Multi-Branch Customers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-branch delivery points per customer, enrich customer profiles with accounting fields, update documents to show Bill To + Ship To, and merge the two DailyMart entries.

**Architecture:** New `sales_customer_branches` table stores delivery points per customer. Orders get a `branch_id` FK. Customer form gains accounting fields (registration_name, email, secondary_phone, credit_limit, currency). Documents show Bill To (HQ) + Ship To (branch). DailyMart merge via Node.js pg migration script.

**Tech Stack:** Supabase (PostgreSQL), vanilla JS, HTML, Node.js pg for migration

**Spec:** `docs/superpowers/specs/2026-04-09-multi-branch-customers-design.md`

---

### Task 1: Database Migration — New Table + New Columns

**Files:**
- Create: `migrate-branches.js` (Node.js pg script, delete after running)

This task adds the `sales_customer_branches` table, new columns on `sales_customers`, and `branch_id` on `sales_orders`. Run via `node migrate-branches.js`.

- [ ] **Step 1: Create migration script**

```js
// migrate-branches.js
const { Client } = require('pg');

const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await client.connect();
  console.log('Connected.');

  // 1. Create sales_customer_branches table
  await client.query(`
    CREATE TABLE IF NOT EXISTS sales_customer_branches (
      id TEXT PRIMARY KEY,
      customer_id TEXT NOT NULL REFERENCES sales_customers(id),
      name TEXT NOT NULL,
      address TEXT,
      contact_person TEXT,
      phone TEXT,
      is_default BOOLEAN DEFAULT false,
      is_active BOOLEAN DEFAULT true,
      company_id TEXT NOT NULL REFERENCES companies(id),
      created_at TIMESTAMPTZ DEFAULT now(),
      updated_at TIMESTAMPTZ DEFAULT now()
    );
  `);
  console.log('Created sales_customer_branches table.');

  // 2. Index for branch lookups
  await client.query(`
    CREATE INDEX IF NOT EXISTS idx_branches_customer_active
    ON sales_customer_branches(customer_id, is_active);
  `);
  console.log('Created index on (customer_id, is_active).');

  // 3. RLS on branches
  await client.query(`ALTER TABLE sales_customer_branches ENABLE ROW LEVEL SECURITY;`);
  await client.query(`
    CREATE POLICY "branches_anon_all" ON sales_customer_branches
    FOR ALL TO anon USING (true) WITH CHECK (true);
  `);
  await client.query(`
    CREATE POLICY "branches_auth_all" ON sales_customer_branches
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
  `);
  console.log('RLS policies added.');

  // 4. New columns on sales_customers
  await client.query(`ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS registration_name TEXT;`);
  await client.query(`ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS email TEXT;`);
  await client.query(`ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS secondary_phone TEXT;`);
  await client.query(`ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS credit_limit NUMERIC;`);
  await client.query(`ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'MYR';`);
  console.log('Added new columns to sales_customers.');

  // 5. branch_id on sales_orders
  await client.query(`ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS branch_id TEXT REFERENCES sales_customer_branches(id);`);
  console.log('Added branch_id to sales_orders.');

  await client.end();
  console.log('Done.');
}

run().catch(e => { console.error(e); process.exit(1); });
```

- [ ] **Step 2: Run migration**

Run: `node migrate-branches.js`
Expected: All 5 steps print "Created/Added" with "Done." at end.

- [ ] **Step 3: Commit**

```bash
git add migrate-branches.js
git commit -m "db: add sales_customer_branches table + enrich sales_customers + branch_id on orders"
```

---

### Task 2: Load Branches in Data Layer

**Files:**
- Modify: `sales.html:1152` (global vars)
- Modify: `sales.html:1229-1260` (`loadAllData()`)

Add `branches` array to global state and load from Supabase on startup.

- [ ] **Step 1: Add global variable**

At `sales.html:1152`, change:

```js
var customers = [], salesProducts = [], orders = [], orderItems = [], payments = [], returns = [];
```

to:

```js
var customers = [], salesProducts = [], orders = [], orderItems = [], payments = [], returns = [], branches = [];
```

- [ ] **Step 2: Load branches in `loadAllData()`**

At `sales.html:1229`, add a new query to the `Promise.all` array. Insert after the `sales_credit_notes` query (line 1244):

```js
    sbQuery(sb.from('sales_customer_branches').select('*').eq('company_id', cid).eq('is_active', true).order('name'))
```

Then after line 1259 (where `creditNotes` is assigned), add:

```js
  branches = results[15] || [];
```

- [ ] **Step 3: Add helper functions**

After the `loadAllData()` function, add these helpers:

```js
function getCustomerBranches(customerId) {
  return branches.filter(function(b) { return b.customer_id === customerId && b.is_active !== false; });
}

function getBranch(branchId) {
  return branches.find(function(b) { return b.id === branchId; });
}
```

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "feat: load customer branches data on sales module startup"
```

---

### Task 3: Enrich Customer Form — New Fields

**Files:**
- Modify: `sales.html:275-349` (customer modal HTML)
- Modify: `sales.html:3289-3314` (`scOpenModal` field population)
- Modify: `sales.html:3335-3399` (`scSaveCustomer`)

Add registration_name, email, secondary_phone, credit_limit, currency to the customer create/edit modal.

- [ ] **Step 1: Add HTML fields to customer modal**

In `sales.html`, after the `sc-name` field (line 292-293), add:

```html
    <div class="form-field">
      <label>REGISTRATION NAME</label>
      <input type="text" id="sc-registration-name" placeholder="Legal company name (optional)" style="width:100%;">
    </div>
```

After the `sc-contact-person` field (line 295-297), before the ADDRESS field, add:

```html
    <div class="form-field">
      <label>EMAIL</label>
      <input type="email" id="sc-email" placeholder="e.g., accounts@company.com (optional)" style="width:100%;">
    </div>
```

After the ADDRESS field (line 299-300), add:

```html
    <div class="form-field">
      <label>SECONDARY PHONE</label>
      <input type="tel" id="sc-secondary-phone" placeholder="Alternate contact number (optional)" style="width:100%;">
    </div>
```

After the PAYMENT TERMS select (line 321-329), add:

```html
    <div class="form-row">
      <div class="form-field">
        <label>CREDIT LIMIT (RM)</label>
        <input type="number" id="sc-credit-limit" placeholder="Optional" style="width:100%;" min="0" step="0.01">
      </div>
      <div class="form-field">
        <label>CURRENCY</label>
        <select id="sc-currency" style="width:100%;">
          <option value="MYR">MYR</option>
        </select>
      </div>
    </div>
```

- [ ] **Step 2: Update `scOpenModal` to populate new fields on edit**

Find the edit-mode population block (around line 3289-3299). After `document.getElementById('sc-notes').value = c.notes || '';` add:

```js
      document.getElementById('sc-registration-name').value = c.registration_name || '';
      document.getElementById('sc-email').value = c.email || '';
      document.getElementById('sc-secondary-phone').value = c.secondary_phone || '';
      document.getElementById('sc-credit-limit').value = c.credit_limit || '';
      document.getElementById('sc-currency').value = c.currency || 'MYR';
```

Find the reset block (around line 3304-3314). After `document.getElementById('sc-notes').value = '';` add:

```js
    document.getElementById('sc-registration-name').value = '';
    document.getElementById('sc-email').value = '';
    document.getElementById('sc-secondary-phone').value = '';
    document.getElementById('sc-credit-limit').value = '';
    document.getElementById('sc-currency').value = 'MYR';
```

- [ ] **Step 3: Update `scSaveCustomer` to read + save new fields**

In `scSaveCustomer()` (around line 3337-3347), after `var notes = ...` add:

```js
  var registrationName = document.getElementById('sc-registration-name').value.trim();
  var email = document.getElementById('sc-email').value.trim();
  var secondaryPhone = document.getElementById('sc-secondary-phone').value.trim();
  var creditLimit = document.getElementById('sc-credit-limit').value;
  var currency = document.getElementById('sc-currency').value;
```

In the `data` object (around line 3360-3366), add after `notes: notes || null`:

```js
    registration_name: registrationName || null,
    email: email || null,
    secondary_phone: secondaryPhone || null,
    credit_limit: creditLimit ? parseFloat(creditLimit) : null,
    currency: currency || 'MYR'
```

- [ ] **Step 4: Update customer detail page to show new fields**

In `scRenderDetail()` (around line 3498-3512), after the existing fields grid, add the new fields. After the `c.notes` line (3512), but before the closing `html += '</div>';` of the grid (3513), add:

```js
  if (c.registration_name) html += '<div style="grid-column:1/-1;"><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Registration Name</div><div style="color:var(--text);">' + esc(c.registration_name) + '</div></div>';
  if (c.email) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Email</div><div style="color:var(--text);">' + esc(c.email) + '</div></div>';
  if (c.secondary_phone) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Secondary Phone</div><div style="color:var(--text);">' + esc(c.secondary_phone) + '</div></div>';
  if (c.credit_limit) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Credit Limit</div><div style="color:var(--text);">RM ' + parseFloat(c.credit_limit).toFixed(2) + '</div></div>';
```

- [ ] **Step 5: Commit**

```bash
git add sales.html
git commit -m "feat: enrich customer form with registration name, email, secondary phone, credit limit, currency"
```

---

### Task 4: Branch Management UI in Customer Detail Page

**Files:**
- Modify: `sales.html` — `scRenderDetail()` function (around line 3470)
- Modify: `sales.html` — add new functions for branch CRUD

Add a "Delivery Branches" section below the customer details card.

- [ ] **Step 1: Add branch section HTML in `scRenderDetail()`**

In `scRenderDetail()`, after the "Overview" summary cards section (after the closing `</div>` of the summary cards around line 3543), add the branches section. Find where the "Purchases by Month" section starts and insert BEFORE it:

```js
  // ── Delivery Branches ──
  var custBranches = getCustomerBranches(c.id);
  html += '<div class="so-detail-section">';
  html += '<div class="so-detail-section-title" style="display:flex;justify-content:space-between;align-items:center;">Delivery Branches';
  html += '<button class="btn btn-primary btn-sm" onclick="brOpenModal(\'' + esc(c.id) + '\')">+ Add Branch</button>';
  html += '</div>';
  if (custBranches.length === 0) {
    html += '<div style="color:var(--text-muted);font-size:13px;padding:12px 0;">No delivery branches added yet. Click "+ Add Branch" to add one.</div>';
  } else {
    html += '<div style="overflow-x:auto;"><table class="data-table" style="width:100%;font-size:13px;">';
    html += '<thead><tr><th>#</th><th>Branch Name</th><th>Address</th><th>Contact</th><th>Phone</th><th></th><th></th></tr></thead><tbody>';
    custBranches.forEach(function(br, idx) {
      html += '<tr>';
      html += '<td>' + (idx + 1) + '</td>';
      html += '<td style="font-weight:600;">' + esc(br.name);
      if (br.is_default) html += ' <span class="badge badge-gold" style="font-size:10px;padding:1px 6px;">Default</span>';
      html += '</td>';
      html += '<td style="white-space:pre-line;max-width:200px;">' + esc(br.address || '\u2014') + '</td>';
      html += '<td>' + esc(br.contact_person || '\u2014') + '</td>';
      html += '<td>' + esc(br.phone || '\u2014') + '</td>';
      html += '<td style="text-align:right;">';
      if (!br.is_default) html += '<a href="javascript:void(0)" onclick="brSetDefault(\'' + esc(br.id) + '\',\'' + esc(c.id) + '\')" style="font-size:11px;color:var(--gold);margin-right:8px;">Set Default</a>';
      html += '<a href="javascript:void(0)" onclick="brOpenModal(\'' + esc(c.id) + '\',\'' + esc(br.id) + '\')" style="font-size:11px;color:var(--green-light);margin-right:8px;">Edit</a>';
      html += '<a href="javascript:void(0)" onclick="brDelete(\'' + esc(br.id) + '\')" style="font-size:11px;color:#c00;">Delete</a>';
      html += '</td>';
      html += '</tr>';
    });
    html += '</tbody></table></div>';
  }
  html += '</div>';
```

- [ ] **Step 2: Add branch modal HTML**

After the customer modal (`</div>` closing `#sc-modal`), add:

```html
<!-- BRANCH MODAL -->
<div id="br-modal" class="modal-overlay" style="display:none;">
  <div class="modal-box" style="max-width:440px;" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title" id="br-modal-title">Add Branch</div>
      <button class="modal-close" onclick="closeModal('br-modal')">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
      </button>
    </div>
    <input type="hidden" id="br-edit-id" value="">
    <input type="hidden" id="br-customer-id" value="">
    <div class="form-field">
      <label>BRANCH NAME</label>
      <input type="text" id="br-name" placeholder="e.g., MY DAILY MART 08 (Times Square)" style="width:100%;">
    </div>
    <div class="form-field">
      <label>ADDRESS</label>
      <textarea id="br-address" rows="3" placeholder="Full delivery address" style="width:100%;"></textarea>
    </div>
    <div class="form-field">
      <label>CONTACT PERSON</label>
      <input type="text" id="br-contact-person" placeholder="Branch contact (optional)" style="width:100%;">
    </div>
    <div class="form-field">
      <label>PHONE</label>
      <input type="tel" id="br-phone" placeholder="Branch phone (optional)" style="width:100%;">
    </div>
    <div class="form-field">
      <label style="display:flex;align-items:center;gap:8px;">
        <input type="checkbox" id="br-is-default"> Set as default branch
      </label>
    </div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal('br-modal')">Cancel</button>
      <button class="btn btn-primary" id="br-save-btn" onclick="brSaveBranch()">Add Branch</button>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Add branch CRUD JS functions**

Add after the `scPaySelected` function (around line 3463):

```js
// ── Branch Management ──
function brOpenModal(customerId, branchId) {
  document.getElementById('br-customer-id').value = customerId;
  document.getElementById('br-edit-id').value = '';
  document.getElementById('br-name').value = '';
  document.getElementById('br-address').value = '';
  document.getElementById('br-contact-person').value = '';
  document.getElementById('br-phone').value = '';
  document.getElementById('br-is-default').checked = false;
  document.getElementById('br-modal-title').textContent = 'Add Branch';
  document.getElementById('br-save-btn').textContent = 'Add Branch';

  if (branchId) {
    var br = getBranch(branchId);
    if (br) {
      document.getElementById('br-edit-id').value = branchId;
      document.getElementById('br-name').value = br.name || '';
      document.getElementById('br-address').value = br.address || '';
      document.getElementById('br-contact-person').value = br.contact_person || '';
      document.getElementById('br-phone').value = br.phone || '';
      document.getElementById('br-is-default').checked = !!br.is_default;
      document.getElementById('br-modal-title').textContent = 'Edit Branch';
      document.getElementById('br-save-btn').textContent = 'Save Changes';
    }
  }
  document.getElementById('br-modal').style.display = 'flex';
}

async function brSaveBranch() {
  var customerId = document.getElementById('br-customer-id').value;
  var editId = document.getElementById('br-edit-id').value;
  var name = document.getElementById('br-name').value.trim();
  var address = document.getElementById('br-address').value.trim();
  var contactPerson = document.getElementById('br-contact-person').value.trim();
  var phone = document.getElementById('br-phone').value.trim();
  var isDefault = document.getElementById('br-is-default').checked;

  if (!name) { notify('Branch name is required', 'warning'); return; }

  var btn = document.getElementById('br-save-btn');
  btnLoading(btn, true);

  // If setting as default, clear other defaults for this customer
  if (isDefault) {
    var existing = getCustomerBranches(customerId);
    for (var i = 0; i < existing.length; i++) {
      if (existing[i].is_default && existing[i].id !== editId) {
        await sbQuery(sb.from('sales_customer_branches').update({ is_default: false, updated_at: new Date().toISOString() }).eq('id', existing[i].id).select());
        existing[i].is_default = false;
      }
    }
  }

  var data = {
    customer_id: customerId,
    name: name,
    address: address || null,
    contact_person: contactPerson || null,
    phone: phone || null,
    is_default: isDefault,
    updated_at: new Date().toISOString()
  };

  if (editId) {
    var result = await sbQuery(sb.from('sales_customer_branches').update(data).eq('id', editId).select());
    if (result === null) { btnLoading(btn, false, 'Save Changes'); return; }
    var idx = branches.findIndex(function(b) { return b.id === editId; });
    if (idx >= 0) Object.assign(branches[idx], data);
    notify('Branch updated');
  } else {
    var newId = await dbNextId('SB');
    data.id = newId;
    data.is_active = true;
    data.company_id = getCompanyId();
    var result = await sbQuery(sb.from('sales_customer_branches').insert(data).select());
    if (result === null) { btnLoading(btn, false, 'Add Branch'); return; }
    branches.push(result[0] || data);
    notify('Branch added');
  }

  btnLoading(btn, false, editId ? 'Save Changes' : 'Add Branch');
  closeModal('br-modal');
  scRenderDetail();
}

async function brSetDefault(branchId, customerId) {
  var existing = getCustomerBranches(customerId);
  for (var i = 0; i < existing.length; i++) {
    var newVal = existing[i].id === branchId;
    if (existing[i].is_default !== newVal) {
      await sbQuery(sb.from('sales_customer_branches').update({ is_default: newVal, updated_at: new Date().toISOString() }).eq('id', existing[i].id).select());
      existing[i].is_default = newVal;
    }
  }
  notify('Default branch updated');
  scRenderDetail();
}

function brDelete(branchId) {
  var br = getBranch(branchId);
  if (!br) return;
  confirmAction('Delete Branch?', 'Deactivate branch <strong>' + esc(br.name) + '</strong>? Existing orders referencing it will keep the link.', async function() {
    var result = await sbQuery(sb.from('sales_customer_branches').update({ is_active: false, updated_at: new Date().toISOString() }).eq('id', branchId).select());
    if (result === null) return;
    var idx = branches.findIndex(function(b) { return b.id === branchId; });
    if (idx >= 0) branches[idx].is_active = false;
    notify('Branch deactivated');
    scRenderDetail();
  });
}
```

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "feat: branch management UI — add/edit/delete/set default in customer detail page"
```

---

### Task 5: Branch Dropdown on Order Form

**Files:**
- Modify: `sales.html:758-768` (order modal customer section HTML)
- Modify: `sales.html:7320-7343` (`soSelectCustomer`)
- Modify: `sales.html:7345-7354` (`soClearCustomer`)
- Modify: `sales.html:7197-7264` (`openNewOrderModal`)
- Modify: `sales.html:7543-7670` (`soSaveOrder`)

Add a "Deliver To" branch dropdown that appears after customer selection.

- [ ] **Step 1: Add branch dropdown HTML**

In the order modal, after the customer section closing `</div>` (line 768), but inside the form area, add a new section. Insert after line 767 (the `+ Add New Customer` link div closing):

```html
    </div>
    <!-- Branch Selection (hidden until customer selected) -->
    <div id="so-branch-section" style="display:none;margin-top:8px;">
      <div class="so-section-label">DELIVER TO</div>
      <select id="so-branch" style="width:100%;">
        <option value="">— No branch selected —</option>
      </select>
    </div>
```

Note: The `</div>` before the comment is the existing closing tag from `so-cust-section`. The branch section sits inside `so-cust-section`.

- [ ] **Step 2: Update `soSelectCustomer` to show branch dropdown**

At the end of `soSelectCustomer()` (after line 7342 `soCheckDebitNotes(customerId);`), add:

```js
  // Show branch dropdown if customer has branches
  var custBranches = getCustomerBranches(customerId);
  var brSection = document.getElementById('so-branch-section');
  var brSelect = document.getElementById('so-branch');
  if (custBranches.length > 0) {
    brSelect.innerHTML = '<option value="">— No branch selected —</option>';
    custBranches.forEach(function(b) {
      var opt = document.createElement('option');
      opt.value = b.id;
      opt.textContent = b.name + (b.address ? ' — ' + b.address.split('\n')[0] : '');
      if (b.is_default) opt.selected = true;
      brSelect.appendChild(opt);
    });
    brSection.style.display = '';
  } else {
    brSection.style.display = 'none';
    brSelect.innerHTML = '<option value="">— No branch selected —</option>';
  }
```

- [ ] **Step 3: Update `soClearCustomer` to hide branch dropdown**

In `soClearCustomer()`, after the existing resets (line 7353), add:

```js
  document.getElementById('so-branch-section').style.display = 'none';
  document.getElementById('so-branch').innerHTML = '<option value="">— No branch selected —</option>';
```

- [ ] **Step 4: Update `openNewOrderModal` reset to clear branch**

In `openNewOrderModal()`, in the reset block (around line 7221), add after `document.getElementById('so-notes').value = '';`:

```js
  document.getElementById('so-branch-section').style.display = 'none';
  document.getElementById('so-branch').innerHTML = '<option value="">— No branch selected —</option>';
```

In the edit mode block (around line 7236), after `soSelectCustomer(o.customer_id);`, add:

```js
    // Pre-select branch if order has one
    if (o.branch_id) {
      var brSelect = document.getElementById('so-branch');
      if (brSelect.querySelector('option[value="' + o.branch_id + '"]')) {
        brSelect.value = o.branch_id;
      }
    }
```

- [ ] **Step 5: Update `soSaveOrder` to save branch_id**

In `soSaveOrder()`, in the UPDATE data object (around line 7567-7577), add after `notes:`:

```js
        branch_id: document.getElementById('so-branch').value || null
```

In the CREATE data object (around line 7624-7640), add after `notes:`:

```js
        branch_id: document.getElementById('so-branch').value || null,
```

- [ ] **Step 6: Commit**

```bash
git add sales.html
git commit -m "feat: branch dropdown on order form — auto-selects default, saves branch_id"
```

---

### Task 6: Show Branch on Order Cards + Detail View

**Files:**
- Modify: `sales.html` — order card rendering
- Modify: `sales.html` — order detail rendering

- [ ] **Step 1: Find order card rendering and add branch name**

Search for where order cards show the customer name. In the order card rendering function, after the customer name display, add branch info. Find the pattern where `cust.name` is rendered on the card (look for the customer name line in the card HTML).

After the customer name on the card, if the order has a `branch_id`, append the branch name:

```js
var orderBranch = o.branch_id ? getBranch(o.branch_id) : null;
```

Then where the customer name is displayed on the card, change from showing just `cust.name` to:

```js
esc(cust ? cust.name : '—') + (orderBranch ? '<div style="font-size:11px;color:var(--text-muted);font-weight:400;">' + esc(orderBranch.name) + '</div>' : '')
```

- [ ] **Step 2: Add branch to order detail view**

In `soRenderDetail()` (the order detail function), find where customer info is displayed. After the customer name, add:

```js
if (o.branch_id) {
  var detailBranch = getBranch(o.branch_id);
  if (detailBranch) {
    html += '<div style="font-size:12px;color:var(--text-muted);margin-top:2px;">';
    html += '<strong>Deliver To:</strong> ' + esc(detailBranch.name);
    if (detailBranch.address) html += ' — ' + esc(detailBranch.address.split('\n')[0]);
    html += '</div>';
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat: show branch name on order cards and detail view"
```

---

### Task 7: Update A4 DO/CS Document — Bill To + Ship To

**Files:**
- Modify: `sales.html:7879-7899` (A4 document customer info grid in `soGenerateDocA4`)

Replace the current 4-column customer info grid with a Bill To + Ship To two-column layout.

- [ ] **Step 1: Replace customer info grid in `soGenerateDocA4`**

In `soGenerateDocA4()` (around line 7879-7899), replace the `// Customer Info (4-column grid)` section with:

```js
    // Bill To + Ship To (two-column layout)
    var orderBranch = o.branch_id ? getBranch(o.branch_id) : null;
    html += '<div style="display:flex;gap:24px;margin:16px 0;">';

    // Left: Bill To
    html += '<div style="flex:1;">';
    html += '<div style="font-size:10px;font-weight:700;color:#666;text-transform:uppercase;margin-bottom:6px;">Bill To</div>';
    html += '<div style="font-size:14px;font-weight:700;color:#000;">' + esc(cust ? (cust.registration_name || cust.name) : '\u2014') + '</div>';
    if (cust && cust.ssm_brn) html += '<div style="font-size:11px;color:#333;margin-top:2px;">SSM/BRN: ' + esc(cust.ssm_brn) + '</div>';
    if (cust && cust.tin) html += '<div style="font-size:11px;color:#333;">TIN: ' + esc(cust.tin) + '</div>';
    if (cust && cust.ic_number) html += '<div style="font-size:11px;color:#333;">IC: ' + esc(cust.ic_number) + '</div>';
    if (cust && cust.address) html += '<div style="font-size:11px;color:#333;margin-top:4px;white-space:pre-line;">' + esc(cust.address) + '</div>';
    if (cust && cust.phone) html += '<div style="font-size:11px;color:#333;">Tel: ' + esc(cust.phone) + '</div>';
    html += '</div>';

    // Right: Ship To (or Order Details if no branch)
    html += '<div style="min-width:200px;">';
    if (orderBranch) {
      html += '<div style="font-size:10px;font-weight:700;color:#666;text-transform:uppercase;margin-bottom:6px;">Ship To</div>';
      html += '<div style="font-size:13px;font-weight:700;color:#000;">' + esc(orderBranch.name) + '</div>';
      if (orderBranch.address) html += '<div style="font-size:11px;color:#333;margin-top:4px;white-space:pre-line;">' + esc(orderBranch.address) + '</div>';
      if (orderBranch.contact_person) html += '<div style="font-size:11px;color:#333;">Attn: ' + esc(orderBranch.contact_person) + '</div>';
      if (orderBranch.phone) html += '<div style="font-size:11px;color:#333;">Tel: ' + esc(orderBranch.phone) + '</div>';
    }
    // Order details below ship-to (or standalone)
    html += '<div style="font-size:10px;font-weight:700;color:#666;text-transform:uppercase;margin-bottom:4px;' + (orderBranch ? 'margin-top:12px;' : '') + '">Order Details</div>';
    html += '<table style="font-size:11px;color:#333;border-collapse:collapse;">';
    html += '<tr><td style="padding:2px 8px 2px 0;font-weight:600;">Date:</td><td>' + fmtDate(o.delivery_date || o.order_date) + '</td></tr>';
    html += '<tr><td style="padding:2px 8px 2px 0;font-weight:600;">Order Date:</td><td>' + fmtDate(o.order_date) + '</td></tr>';
    if (o.fulfillment === 'delivery' && o.driver_id) {
      html += '<tr><td style="padding:2px 8px 2px 0;font-weight:600;">Driver:</td><td>' + esc(getDriverName(o.driver_id, o.driver_source)) + '</td></tr>';
    }
    html += '</table>';
    html += '</div>';

    html += '</div>';
```

Remove the old `a4-info-grid` block entirely (lines 7880-7898).

- [ ] **Step 2: Update 80mm receipt to show branch**

In `soGenerateDoc()` (around line 7747-7761), after the customer address line, add branch info:

After `html += '<div class="doc-info-label">Address:</div><div class="doc-info-value">' + esc(cust.address) + '</div>';` add:

```js
  var receiptBranch = o.branch_id ? getBranch(o.branch_id) : null;
  if (receiptBranch) {
    html += '<div class="doc-info-label">Ship To:</div><div class="doc-info-value">' + esc(receiptBranch.name) + '</div>';
  }
```

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat: Bill To + Ship To layout on A4 DO/CS documents, branch on 80mm receipt"
```

---

### Task 8: Update Invoice A4 — Bill To Uses Registration Name

**Files:**
- Modify: `sales.html:5782-5791` (invoice A4 Bill To)

- [ ] **Step 1: Update invoice Bill To to use `registration_name`**

In the invoice A4 generation (around line 5785), change:

```js
  html += '<div style="font-size:14px;font-weight:700;color:#000;">' + esc(cust ? cust.name : '\u2014') + '</div>';
```

to:

```js
  html += '<div style="font-size:14px;font-weight:700;color:#000;">' + esc(cust ? (cust.registration_name || cust.name) : '\u2014') + '</div>';
```

Do the same for the Credit Note A4 Bill To (around line 5684). Change:

```js
  html += '<div style="font-size:14px;font-weight:700;color:#000;">' + esc(cust ? cust.name : '\u2014') + '</div>';
```

to:

```js
  html += '<div style="font-size:14px;font-weight:700;color:#000;">' + esc(cust ? (cust.registration_name || cust.name) : '\u2014') + '</div>';
```

- [ ] **Step 2: Commit**

```bash
git add sales.html
git commit -m "feat: invoice and credit note Bill To shows registration name when available"
```

---

### Task 9: Update Invoice DO Summary — Show Branch Info Per DO

**Files:**
- Modify: `sales.html:5926-5962` (DO Summary blocks in invoice A4)

- [ ] **Step 1: Add branch info to each DO block**

In the DO Summary section (around line 5934), after the DO header line with doc_number/date/driver (line 5939 `html += '</div>';`), add a Ship To line:

After `if (o.driver_name) html += ' &nbsp;|&nbsp; Driver: ' + esc(o.driver_name);` and before the closing `html += '</div>';` of the header div, we don't change that. Instead, add a new line AFTER the header div closes (after line 5939 `html += '</div>';`):

```js
      // Branch / Ship To info
      var doBranch = o.branch_id ? getBranch(o.branch_id) : null;
      if (doBranch) {
        html += '<div style="font-size:11px;color:#444;margin-bottom:6px;padding:3px 0;border-bottom:1px dotted #ccc;">';
        html += '<strong>Ship To:</strong> ' + esc(doBranch.name);
        if (doBranch.address) html += ' — ' + esc(doBranch.address.replace(/\n/g, ', '));
        html += '</div>';
      }
      // Order notes
      if (o.notes) {
        html += '<div style="font-size:10px;color:#666;margin-bottom:6px;font-style:italic;">';
        html += '<strong>Note:</strong> ' + esc(o.notes);
        html += '</div>';
      }
```

- [ ] **Step 2: Commit**

```bash
git add sales.html
git commit -m "feat: invoice DO summary shows branch name + address + notes per DO"
```

---

### Task 10: DailyMart Data Merge Migration

**Files:**
- Create: `migrate-dailymart-merge.js` (Node.js pg script, delete after running)

This merges the two DailyMart customer records into one with two branches. Must be run AFTER Task 1 migration.

- [ ] **Step 1: Create merge script**

```js
// migrate-dailymart-merge.js
const { Client } = require('pg');

const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await client.connect();
  console.log('Connected.');

  // 1. Find the two DailyMart customers
  var res = await client.query(`SELECT * FROM sales_customers WHERE name ILIKE '%dailymart%' OR name ILIKE '%daily mart%' ORDER BY name`);
  console.log('Found ' + res.rows.length + ' DailyMart customers:');
  res.rows.forEach(function(r) { console.log('  ' + r.id + ' | ' + r.name + ' | ' + (r.phone || 'no phone')); });

  if (res.rows.length !== 2) {
    console.error('Expected exactly 2 DailyMart customers. Aborting.');
    await client.end();
    return;
  }

  // Pick the first as "keep", second as "lose" (both will be updated)
  var keep = res.rows[0];
  var lose = res.rows[1];
  console.log('\nKEEP: ' + keep.id + ' (' + keep.name + ')');
  console.log('LOSE: ' + lose.id + ' (' + lose.name + ')');

  // 2. Before-counts
  var beforeOrders = await client.query(`SELECT COUNT(*) as c FROM sales_orders WHERE customer_id IN ($1, $2)`, [keep.id, lose.id]);
  var beforeInvoices = await client.query(`SELECT COUNT(*) as c FROM sales_invoices WHERE customer_id IN ($1, $2)`, [keep.id, lose.id]);
  console.log('\n--- BEFORE ---');
  console.log('Total orders: ' + beforeOrders.rows[0].c);
  console.log('Total invoices: ' + beforeInvoices.rows[0].c);

  // 3. Start transaction
  await client.query('BEGIN');

  try {
    // 4. Update KEEP customer with merged HQ data
    await client.query(`
      UPDATE sales_customers SET
        name = 'My DailyMart',
        registration_name = 'MY DAILY MART SDN BHD',
        address = 'Lot 2495-2496, Ground Floor, Boulevard Commercial Centre, 98000 Miri Sarawak Malaysia',
        phone = '011-18707757',
        ssm_brn = '201401022362 (1098448-U)',
        tin = 'C23627748000',
        contact_person = COALESCE(contact_person, $2),
        payment_terms = COALESCE($3, payment_terms),
        payment_terms_days = COALESCE($4, payment_terms_days),
        type = COALESCE($5, type),
        channel = COALESCE($6, channel),
        notes = 'Merged from two entries on 2026-04-09. Previously: ' || $7 || ' + ' || $8
      WHERE id = $1
    `, [keep.id, lose.contact_person, keep.payment_terms || lose.payment_terms, keep.payment_terms_days || lose.payment_terms_days, keep.type || lose.type, keep.channel || lose.channel, keep.name, lose.name]);
    console.log('Updated KEEP customer with HQ data.');

    // 5. Generate branch IDs (simple text IDs)
    // Get next SB counter
    var idRes1 = await client.query(`SELECT next_id('SB', $1) as id`, [keep.company_id]);
    var branchId1 = idRes1.rows[0].id;
    var idRes2 = await client.query(`SELECT next_id('SB', $1) as id`, [keep.company_id]);
    var branchId2 = idRes2.rows[0].id;

    // 6. Create Branch 1: Boulevard (default)
    await client.query(`
      INSERT INTO sales_customer_branches (id, customer_id, name, address, contact_person, phone, is_default, is_active, company_id)
      VALUES ($1, $2, 'MY DAILY MART 01 (Boulevard)', 'Lot 2496, Ground Floor, Boulevard Commercial Centre, 98000 Miri Sarawak Malaysia', NULL, '6085 427 229', true, true, $3)
    `, [branchId1, keep.id, keep.company_id]);
    console.log('Created branch: Boulevard (' + branchId1 + ')');

    // 7. Create Branch 2: Times Square
    await client.query(`
      INSERT INTO sales_customer_branches (id, customer_id, name, address, contact_person, phone, is_default, is_active, company_id)
      VALUES ($1, $2, 'MY DAILY MART 08 (Times Square)', 'Lot 2251, Blk 9, Prcel No: B1-G15 & B1-G16, Times Square, 98000 Miri Sarawak', NULL, NULL, false, true, $3)
    `, [branchId2, keep.id, keep.company_id]);
    console.log('Created branch: Times Square (' + branchId2 + ')');

    // 8. Reassign orders from LOSE to KEEP, and set branch_id
    // First figure out which was Times Square and which was Boulevard from original names
    var tsCustomer = res.rows.find(function(r) { return r.name.toLowerCase().includes('times') || r.name.toLowerCase().includes('square'); });
    var blCustomer = res.rows.find(function(r) { return r.id !== (tsCustomer ? tsCustomer.id : null); });

    if (tsCustomer && tsCustomer.id !== keep.id) {
      // LOSE is Times Square — reassign its orders with Times Square branch
      await client.query(`UPDATE sales_orders SET customer_id = $1, branch_id = $2 WHERE customer_id = $3`, [keep.id, branchId2, lose.id]);
      console.log('Reassigned LOSE orders to KEEP with Times Square branch.');
      // KEEP orders get Boulevard branch
      await client.query(`UPDATE sales_orders SET branch_id = $1 WHERE customer_id = $2 AND branch_id IS NULL`, [branchId1, keep.id]);
      console.log('Set KEEP orders to Boulevard branch.');
    } else if (tsCustomer && tsCustomer.id === keep.id) {
      // KEEP is Times Square, LOSE is Boulevard
      // Reassign LOSE orders to KEEP with Boulevard branch
      await client.query(`UPDATE sales_orders SET customer_id = $1, branch_id = $2 WHERE customer_id = $3`, [keep.id, branchId1, lose.id]);
      console.log('Reassigned LOSE orders to KEEP with Boulevard branch.');
      // KEEP orders get Times Square branch
      await client.query(`UPDATE sales_orders SET branch_id = $1 WHERE customer_id = $2 AND branch_id IS NULL`, [branchId2, keep.id]);
      console.log('Set KEEP orders to Times Square branch.');
    } else {
      // Can't determine — reassign without branch assignment
      await client.query(`UPDATE sales_orders SET customer_id = $1 WHERE customer_id = $2`, [keep.id, lose.id]);
      console.log('Reassigned LOSE orders to KEEP (no branch auto-assignment — names unclear).');
    }

    // 9. Reassign invoices
    await client.query(`UPDATE sales_invoices SET customer_id = $1 WHERE customer_id = $2`, [keep.id, lose.id]);
    console.log('Reassigned invoices.');

    // 10. Deactivate LOSE customer
    await client.query(`UPDATE sales_customers SET is_active = false, notes = COALESCE(notes, '') || ' [MERGED into ' || $1 || ' on 2026-04-09]' WHERE id = $2`, [keep.id, lose.id]);
    console.log('Deactivated LOSE customer.');

    // 11. After-counts
    var afterOrders = await client.query(`SELECT COUNT(*) as c FROM sales_orders WHERE customer_id = $1`, [keep.id]);
    var afterInvoices = await client.query(`SELECT COUNT(*) as c FROM sales_invoices WHERE customer_id = $1`, [keep.id]);
    console.log('\n--- AFTER ---');
    console.log('Total orders on KEEP: ' + afterOrders.rows[0].c + ' (was ' + beforeOrders.rows[0].c + ')');
    console.log('Total invoices on KEEP: ' + afterInvoices.rows[0].c + ' (was ' + beforeInvoices.rows[0].c + ')');

    if (parseInt(afterOrders.rows[0].c) < parseInt(beforeOrders.rows[0].c)) {
      throw new Error('ORDER COUNT MISMATCH — ABORTING');
    }
    if (parseInt(afterInvoices.rows[0].c) < parseInt(beforeInvoices.rows[0].c)) {
      throw new Error('INVOICE COUNT MISMATCH — ABORTING');
    }

    await client.query('COMMIT');
    console.log('\nMerge complete. LOSE customer deactivated (not deleted).');

  } catch (e) {
    await client.query('ROLLBACK');
    console.error('ROLLED BACK:', e.message);
  }

  await client.end();
}

run().catch(e => { console.error(e); process.exit(1); });
```

- [ ] **Step 2: Run merge script**

Run: `node migrate-dailymart-merge.js`
Expected: Before/after counts match, "Merge complete" printed.

- [ ] **Step 3: Verify in browser**

Open sales module, go to Manage Customers, find "My DailyMart". Verify:
- Customer details show registration name, SSM, TIN, phone
- Branches section shows Boulevard (default) + Times Square
- All previous orders from both DailyMarts now appear under one customer
- Deactivated customer dimmed in list (if show inactive is on)

- [ ] **Step 4: Commit**

```bash
git add migrate-dailymart-merge.js
git commit -m "data: merge two DailyMart customers into one with two branches"
```

---

### Task 11: Cleanup + Final Verification

**Files:**
- Modify: `sales.html` — address label in customer form
- Delete: `migrate-branches.js`, `migrate-dailymart-merge.js` (after confirming success)

- [ ] **Step 1: Update address label in customer form**

In the customer modal (around line 299-300), change the ADDRESS label/placeholder to clarify it's the HQ/billing address:

Change:
```html
      <label>ADDRESS</label>
      <textarea id="sc-address" rows="2" placeholder="Delivery address (optional)" style="width:100%;"></textarea>
```

to:
```html
      <label>BILLING / HQ ADDRESS</label>
      <textarea id="sc-address" rows="2" placeholder="Main office / billing address (optional)" style="width:100%;"></textarea>
```

- [ ] **Step 2: Delete migration scripts**

```bash
rm migrate-branches.js migrate-dailymart-merge.js
```

- [ ] **Step 3: Full verification**

Test the following:
1. Create a new customer with registration_name, email, credit_limit
2. Add 2 branches to the customer (one as default)
3. Create an order — verify branch dropdown appears, default pre-selected
4. View order card — branch name shown
5. Generate A4 DO — Bill To (HQ) + Ship To (branch) displayed
6. Generate 80mm receipt — Ship To line shown
7. Generate invoice for DOs — DO Summary shows branch + notes per DO
8. Edit order — branch pre-selected
9. My DailyMart — all orders, correct branches assigned

- [ ] **Step 4: Final commit**

```bash
git add sales.html
git commit -m "chore: update address label to billing/HQ, remove migration scripts"
```

---

## Summary

| Task | Description | Key Changes |
|------|-------------|-------------|
| 1 | DB Migration | New table + columns + RLS |
| 2 | Data Layer | Load branches, helper functions |
| 3 | Customer Form | 5 new fields (registration_name, email, secondary_phone, credit_limit, currency) |
| 4 | Branch UI | CRUD in customer detail page |
| 5 | Order Form | Branch dropdown after customer selection |
| 6 | Order Display | Branch name on cards + detail |
| 7 | A4 DO/CS | Bill To + Ship To layout |
| 8 | Invoice A4 | registration_name on Bill To |
| 9 | Invoice DO Summary | Branch + notes per DO |
| 10 | DailyMart Merge | Merge 2 → 1, create branches, reassign orders |
| 11 | Cleanup | Label fix, delete scripts, verify |
