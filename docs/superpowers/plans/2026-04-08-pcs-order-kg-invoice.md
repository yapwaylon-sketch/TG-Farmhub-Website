# Pcs-Ordered / Kg-Billed Sales Lines — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow individual order lines to be ordered in pcs while still billed in kg, with actual weight captured at the "Mark Prepared" step.

**Architecture:** Two new nullable columns on `sales_order_items` (`order_pcs`, `actual_weight_kg`). Order entry adds a per-line "Order in pcs" toggle. Mark Prepared modal is extended to require a weight for pcs-ordered lines, which then writes that weight into `quantity` so all existing reports/invoicing keep working unchanged. Document templates show pcs on the prep message and kg+pcs subtitle on DO/CS docs.

**Tech Stack:** Vanilla JS in a single `sales.html` file, Supabase Postgres backend (`sales_order_items` table), `npx supabase db query` for migrations, `npx netlify-cli deploy --prod --dir=.` for deploys. No test framework — verification is manual via browser DevTools and SQL queries.

**Spec:** `docs/superpowers/specs/2026-04-08-pcs-order-kg-invoice-design.md`

**Key files touched:**
- `supabase/2026-04-08_pcs_order_kg_invoice.sql` (NEW) — migration
- `sales.html` — all UI/logic changes (single-file app)

---

## Task 1: Database migration

**Files:**
- Create: `supabase/2026-04-08_pcs_order_kg_invoice.sql`

- [ ] **Step 1: Verify columns do not yet exist**

Run:
```bash
npx supabase db query --linked "SELECT column_name FROM information_schema.columns WHERE table_name='sales_order_items' AND column_name IN ('order_pcs','actual_weight_kg');"
```
Expected: empty result set.

- [ ] **Step 2: Create migration file**

Create `supabase/2026-04-08_pcs_order_kg_invoice.sql`:

```sql
-- ============================================================
-- Pcs-Ordered / Kg-Billed Sales Lines
-- TG FarmHub / TG Agro Fruits Sdn Bhd
-- 2026-04-08
-- ============================================================
-- Adds two nullable columns to sales_order_items:
--   order_pcs        -- pcs the customer ordered (NULL = normal kg line)
--   actual_weight_kg -- weight keyed in at "Mark Prepared" (NULL until weighed)
-- Existing `quantity` column continues to mean "kg used for billing".
-- For pcs-ordered lines: quantity = 0 before weighing, quantity = actual_weight_kg after.
-- ============================================================

ALTER TABLE sales_order_items
  ADD COLUMN IF NOT EXISTS order_pcs INTEGER,
  ADD COLUMN IF NOT EXISTS actual_weight_kg NUMERIC;

COMMENT ON COLUMN sales_order_items.order_pcs IS
  'Pcs the customer ordered. NULL means this is a normal kg line.';
COMMENT ON COLUMN sales_order_items.actual_weight_kg IS
  'Weight keyed in at Mark Prepared. NULL until weighed. When set, equals quantity.';
```

- [ ] **Step 3: Apply migration**

Run:
```bash
npx supabase db query --linked "$(cat supabase/2026-04-08_pcs_order_kg_invoice.sql)"
```
Expected: `ALTER TABLE` success message.

- [ ] **Step 4: Verify columns exist**

Run:
```bash
npx supabase db query --linked "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='sales_order_items' AND column_name IN ('order_pcs','actual_weight_kg');"
```
Expected: two rows, both `is_nullable = YES`, types `integer` and `numeric`.

- [ ] **Step 5: Commit**

```bash
git add supabase/2026-04-08_pcs_order_kg_invoice.sql
git commit -m "feat(db): add order_pcs and actual_weight_kg to sales_order_items"
```

---

## Task 2: Load new columns into client state

**Files:**
- Modify: `sales.html` — `soItems` push sites and the data load query

The client fetches `sales_order_items.select('*')` (sales.html:1121) so the new columns will arrive automatically. No fetch change needed. The work is in propagating them through `soItems` (the in-memory edit-modal state).

- [ ] **Step 1: Update `soAddItem` default shape**

Find at sales.html:6421:
```javascript
function soAddItem() {
  soItems.push({ id: Date.now(), productId: '', quantity: '', unitPrice: '', unit: '', indexMin: '', indexMax: '', lineTotal: 0 });
}
```

Replace with:
```javascript
function soAddItem() {
  soItems.push({ id: Date.now(), productId: '', quantity: '', unitPrice: '', unit: '', indexMin: '', indexMax: '', lineTotal: 0, orderInPcs: false, orderPcs: '' });
}
```

- [ ] **Step 2: Update edit-load to restore the toggle**

Find at sales.html:6311 inside `existingItems.forEach`:
```javascript
existingItems.forEach(function(item) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  soItems.push({
    id: Date.now() + Math.random(),
    productId: item.product_id || '',
    quantity: item.quantity || '',
    unitPrice: item.unit_price || '',
    unit: prod ? (prod.unit || '') : '',
    indexMin: item.index_min != null ? String(item.index_min) : '',
    indexMax: item.index_max != null ? String(item.index_max) : '',
    lineTotal: parseFloat(item.line_total) || 0,
    existingItemId: item.id // track for update
  });
});
```

Replace with:
```javascript
existingItems.forEach(function(item) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var isPcsOrdered = item.order_pcs != null;
  soItems.push({
    id: Date.now() + Math.random(),
    productId: item.product_id || '',
    quantity: isPcsOrdered ? '' : (item.quantity || ''),
    unitPrice: item.unit_price || '',
    unit: prod ? (prod.unit || '') : '',
    indexMin: item.index_min != null ? String(item.index_min) : '',
    indexMax: item.index_max != null ? String(item.index_max) : '',
    lineTotal: parseFloat(item.line_total) || 0,
    existingItemId: item.id, // track for update
    orderInPcs: isPcsOrdered,
    orderPcs: isPcsOrdered ? String(item.order_pcs) : ''
  });
});
```

- [ ] **Step 3: Verify in browser**

1. `npx netlify-cli deploy --prod --dir=.` from website directory.
2. Open https://tgfarmhub.com/sales.html, log in.
3. Open DevTools console. Find any existing order's first item: `orderItems[0]`. Confirm the result has `order_pcs` and `actual_weight_kg` keys (both `null` for legacy rows).

Expected: `null` for both new fields on legacy items.

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "feat(sales): wire pcs-order columns into soItems state shape"
```

---

## Task 3: Add "Order in pcs" toggle to order item rows

**Files:**
- Modify: `sales.html` — `soRenderItems` (sales.html:6432)

The toggle is shown only when:
- The selected product has `unit === 'kg'`, AND
- The order is not a walk-in (`!soIsWalkIn`)

When the toggle is on, the qty input switches to integer pcs and the line total displays a placeholder.

- [ ] **Step 1: Locate `soRenderItems` and identify the qty/unit/price block**

The block to modify spans sales.html:6478–6483:
```javascript
// Qty + Unit + Price row
html += '<div class="oir-nums-row">';
html += '<div class="oir-qty"><input type="number" step="' + qtyStep + '" min="0" placeholder="Qty" value="' + (item.quantity || '') + '" oninput="soItemFieldChange(' + item.id + ',\'quantity\',this.value);soCalcTotals()"></div>';
html += '<div class="oir-unit">' + esc(unitLabel) + '</div>';
html += '<div class="oir-price"><input type="number" step="0.01" min="0" placeholder="Price" value="' + (item.unitPrice || '') + '" oninput="soItemFieldChange(' + item.id + ',\'unitPrice\',this.value);soCalcTotals()"></div>';
html += '</div>';
```

- [ ] **Step 2: Replace the block to support pcs mode and add the toggle**

Replace the block above with:
```javascript
// Qty + Unit + Price row
var canTogglePcs = unitLabel === 'kg' && !soIsWalkIn;
var pcsMode = !!item.orderInPcs;
var qtyDisplayValue = pcsMode ? (item.orderPcs || '') : (item.quantity || '');
var qtyPlaceholder = pcsMode ? 'Pcs' : 'Qty';
var qtyHandlerField = pcsMode ? 'orderPcs' : 'quantity';
var qtyStepRender = pcsMode ? '1' : qtyStep;
var unitDisplay = pcsMode ? 'pcs' : unitLabel;

html += '<div class="oir-nums-row">';
html += '<div class="oir-qty"><input type="number" step="' + qtyStepRender + '" min="0" placeholder="' + qtyPlaceholder + '" value="' + qtyDisplayValue + '" oninput="soItemFieldChange(' + item.id + ',\'' + qtyHandlerField + '\',this.value);soCalcTotals()"></div>';
html += '<div class="oir-unit">' + esc(unitDisplay) + '</div>';
html += '<div class="oir-price"><input type="number" step="0.01" min="0" placeholder="Price" value="' + (item.unitPrice || '') + '" oninput="soItemFieldChange(' + item.id + ',\'unitPrice\',this.value);soCalcTotals()"></div>';
html += '</div>';

// Order-in-pcs toggle (only for kg products on non-walk-in orders)
if (canTogglePcs) {
  html += '<div class="oir-pcs-toggle" style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--text-muted);margin-top:4px;">';
  html += '<label style="display:inline-flex;align-items:center;gap:4px;cursor:pointer;">';
  html += '<input type="checkbox" ' + (pcsMode ? 'checked' : '') + ' onchange="soTogglePcsMode(' + item.id + ',this.checked)"> Order in pcs (bill by kg after weighing)';
  html += '</label>';
  html += '</div>';
}
```

- [ ] **Step 3: Update line-total display for pcs-mode lines**

Find at sales.html:6494 (just below the index row):
```javascript
// Line total + remove
html += '<div class="oir-bottom">';
html += '<span class="oir-line-total">' + formatRM(item.lineTotal) + '</span>';
html += '<button class="btn btn-outline btn-sm oir-remove" onclick="soRemoveItem(' + item.id + ')" title="Remove">&times;</button>';
html += '</div>';
```

Replace with:
```javascript
// Line total + remove
html += '<div class="oir-bottom">';
var lineTotalDisplay = pcsMode ? '<span style="color:var(--text-muted);font-style:italic;">— pending weight</span>' : formatRM(item.lineTotal);
html += '<span class="oir-line-total">' + lineTotalDisplay + '</span>';
html += '<button class="btn btn-outline btn-sm oir-remove" onclick="soRemoveItem(' + item.id + ')" title="Remove">&times;</button>';
html += '</div>';
```

- [ ] **Step 4: Add the toggle handler function**

Add this function immediately below `soItemFieldChange` (after sales.html:6509):

```javascript
function soTogglePcsMode(itemId, on) {
  var item = soItems.find(function(i) { return i.id === itemId; });
  if (!item) return;
  item.orderInPcs = !!on;
  if (on) {
    // Switching to pcs mode: clear kg quantity, keep pcs (if any)
    item.quantity = '';
    item.lineTotal = 0;
  } else {
    // Switching back to kg mode: clear pcs
    item.orderPcs = '';
  }
  soRenderItems();
  soCalcTotals();
}
```

- [ ] **Step 5: Update `soCalcTotals` to skip pcs-mode lines from the subtotal and show a hint**

Find at sales.html:6526:
```javascript
function soCalcTotals() {
  soItems.forEach(function(item) {
    item.lineTotal = (parseFloat(item.quantity) || 0) * (parseFloat(item.unitPrice) || 0);
  });
  var subtotal = soItems.reduce(function(sum, i) { return sum + i.lineTotal; }, 0);
  document.getElementById('so-subtotal').textContent = formatRM(subtotal);

  // Update line totals in DOM
  var rows = document.querySelectorAll('.oir-line-total');
  soItems.forEach(function(item, idx) {
    if (rows[idx]) rows[idx].textContent = formatRM(item.lineTotal);
  });
}
```

Replace with:
```javascript
function soCalcTotals() {
  var pendingPcs = 0;
  soItems.forEach(function(item) {
    if (item.orderInPcs) {
      item.lineTotal = 0;
      if (parseInt(item.orderPcs, 10) > 0) pendingPcs++;
    } else {
      item.lineTotal = (parseFloat(item.quantity) || 0) * (parseFloat(item.unitPrice) || 0);
    }
  });
  var subtotal = soItems.reduce(function(sum, i) { return sum + i.lineTotal; }, 0);
  document.getElementById('so-subtotal').textContent = formatRM(subtotal);

  // Pending-weight hint
  var hintEl = document.getElementById('so-pending-pcs-hint');
  if (!hintEl) {
    var subtotalEl = document.getElementById('so-subtotal');
    if (subtotalEl && subtotalEl.parentElement) {
      hintEl = document.createElement('div');
      hintEl.id = 'so-pending-pcs-hint';
      hintEl.style.cssText = 'font-size:11px;color:var(--text-muted);font-style:italic;text-align:right;margin-top:2px;';
      subtotalEl.parentElement.appendChild(hintEl);
    }
  }
  if (hintEl) {
    hintEl.textContent = pendingPcs > 0 ? '+ ' + pendingPcs + ' item' + (pendingPcs > 1 ? 's' : '') + ' pending weight' : '';
  }

  // Update line totals in DOM (note: full re-render via soRenderItems handles the "— pending weight" placeholder)
  var rows = document.querySelectorAll('.oir-line-total');
  soItems.forEach(function(item, idx) {
    if (!rows[idx]) return;
    if (item.orderInPcs) {
      rows[idx].innerHTML = '<span style="color:var(--text-muted);font-style:italic;">— pending weight</span>';
    } else {
      rows[idx].textContent = formatRM(item.lineTotal);
    }
  });
}
```

- [ ] **Step 6: Verify in browser**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. Open New Order modal, select a customer (not walk-in), pick a kg product.
3. Verify the "Order in pcs (bill by kg after weighing)" checkbox appears below the qty/price row.
4. Toggle it on. Verify:
   - Qty input placeholder becomes "Pcs"
   - Unit label changes from "kg" to "pcs"
   - Line total shows "— pending weight" in italic
5. Type `50` into the qty field. Verify:
   - Subtotal stays `RM 0.00` (or sums only kg lines)
   - Hint "+ 1 item pending weight" appears below the subtotal
6. Toggle off. Verify state reverts to kg mode and line total recalculates.
7. Open New Walk-in Sale modal — verify the toggle does NOT appear.
8. Pick a product with `unit = pcs` — verify the toggle does NOT appear.

- [ ] **Step 7: Commit**

```bash
git add sales.html
git commit -m "feat(sales): add 'Order in pcs' toggle to order item rows"
```

---

## Task 4: Persist pcs-ordered lines through `soSaveOrder`

**Files:**
- Modify: `sales.html` — `soSaveOrder` (sales.html:6540)

A pcs-ordered line is valid even with `quantity = 0`, as long as `orderPcs > 0`. We must store `order_pcs` in both insert and update paths and explicitly set `quantity = 0`, `line_total = 0`, `actual_weight_kg = null`.

- [ ] **Step 1: Update validation to accept pcs-only lines**

Find at sales.html:6543:
```javascript
var validItems = soItems.filter(function(i) { return i.productId && parseFloat(i.quantity) > 0; });
```

Replace with:
```javascript
var validItems = soItems.filter(function(i) {
  if (!i.productId) return false;
  if (i.orderInPcs) return parseInt(i.orderPcs, 10) > 0;
  return parseFloat(i.quantity) > 0;
});
```

- [ ] **Step 2: Update the EDIT-path insert (sales.html:6584)**

Find:
```javascript
var itemData = {
  id: itemId,
  order_id: soEditOrderId,
  product_id: item.productId,
  quantity: parseFloat(item.quantity),
  unit_price: parseFloat(item.unitPrice) || 0,
  line_total: item.lineTotal,
  index_min: item.indexMin !== '' ? parseInt(item.indexMin) : null,
  index_max: item.indexMax !== '' ? parseInt(item.indexMax) : null,
  company_id: getCompanyId()
};
```

Replace with:
```javascript
var isPcs = !!item.orderInPcs;
var itemData = {
  id: itemId,
  order_id: soEditOrderId,
  product_id: item.productId,
  quantity: isPcs ? 0 : parseFloat(item.quantity),
  unit_price: parseFloat(item.unitPrice) || 0,
  line_total: isPcs ? 0 : item.lineTotal,
  index_min: item.indexMin !== '' ? parseInt(item.indexMin) : null,
  index_max: item.indexMax !== '' ? parseInt(item.indexMax) : null,
  order_pcs: isPcs ? parseInt(item.orderPcs, 10) : null,
  actual_weight_kg: null,
  company_id: getCompanyId()
};
```

- [ ] **Step 3: Update the CREATE-path insert (sales.html:6640)**

Find:
```javascript
var itemData = {
  id: itemId,
  order_id: orderId,
  product_id: item.productId,
  quantity: parseFloat(item.quantity),
  unit_price: parseFloat(item.unitPrice) || 0,
  line_total: item.lineTotal,
  index_min: item.indexMin !== '' ? parseInt(item.indexMin) : null,
  index_max: item.indexMax !== '' ? parseInt(item.indexMax) : null,
  company_id: getCompanyId()
};
```

Replace with:
```javascript
var isPcs = !!item.orderInPcs;
var itemData = {
  id: itemId,
  order_id: orderId,
  product_id: item.productId,
  quantity: isPcs ? 0 : parseFloat(item.quantity),
  unit_price: parseFloat(item.unitPrice) || 0,
  line_total: isPcs ? 0 : item.lineTotal,
  index_min: item.indexMin !== '' ? parseInt(item.indexMin) : null,
  index_max: item.indexMax !== '' ? parseInt(item.indexMax) : null,
  order_pcs: isPcs ? parseInt(item.orderPcs, 10) : null,
  actual_weight_kg: null,
  company_id: getCompanyId()
};
```

- [ ] **Step 4: Update `subtotalVal` calculation in `soSaveOrder`**

Find at sales.html:6555:
```javascript
var subtotalVal = soItems.reduce(function(sum, i) { return sum + i.lineTotal; }, 0);
```

This already produces the correct value because pcs-ordered lines have `lineTotal = 0` after Task 3 step 5. No code change needed — but verify by reading the line and confirming it's still present.

- [ ] **Step 5: Verify in browser & DB**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. Create a new order with one normal kg line (e.g., 5 kg pineapple) and one pcs-ordered line (e.g., 50 pcs pineapple). Save.
3. Confirm order saves without error.
4. Run:
```bash
npx supabase db query --linked "SELECT id, order_id, quantity, unit_price, line_total, order_pcs, actual_weight_kg FROM sales_order_items WHERE order_id = (SELECT id FROM sales_orders ORDER BY created_at DESC LIMIT 1) ORDER BY id;"
```
Expected: two rows. Normal line has `quantity > 0`, `order_pcs = NULL`, `actual_weight_kg = NULL`. Pcs line has `quantity = 0`, `line_total = 0`, `order_pcs = 50`, `actual_weight_kg = NULL`.

5. Re-open the order in edit mode. Verify the pcs line shows the toggle ON with "50" in the input.

- [ ] **Step 6: Commit**

```bash
git add sales.html
git commit -m "feat(sales): persist order_pcs on save and validate pcs-only lines"
```

---

## Task 5: Extend Mark Prepared modal to capture actual weight

**Files:**
- Modify: `sales.html` — `soMarkPrepared` (sales.html:2330) and `soPrepQtyConfirm` (sales.html:2374)

For pcs-ordered lines, the row gets an extra "Actual weight (kg)" input. Confirm is blocked until every pcs line has a weight > 0.

- [ ] **Step 1: Replace `soMarkPrepared` row rendering**

Find at sales.html:2334:
```javascript
var html = '<div class="table-wrap"><table class="data-table" style="margin:0;">';
html += '<thead><tr><th>Product</th><th style="text-align:right;">Ordered</th><th style="text-align:right;width:100px;">Actual</th><th>Unit</th><th style="text-align:right;">Price</th><th style="text-align:right;">Total</th></tr></thead><tbody>';

items.forEach(function(item, idx) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var name = soGetProductName(item.product_id);
  var unit = prod ? (prod.unit || '') : '';
  var price = parseFloat(item.unit_price) || 0;
  var qty = item.quantity || 0;

  html += '<tr>';
  html += '<td style="font-weight:600;">' + esc(name) + '</td>';
  html += '<td style="text-align:right;color:var(--text-muted);">' + qty + '</td>';
  html += '<td style="text-align:right;"><input type="number" class="prepqty-input" data-item-id="' + esc(item.id) + '" data-price="' + price + '" value="' + qty + '" min="0" step="any" oninput="soPrepQtyRecalc()" style="width:80px;text-align:right;padding:4px 6px;font-size:13px;"></td>';
  html += '<td>' + esc(unit) + '</td>';
  html += '<td style="text-align:right;">' + price.toFixed(2) + '</td>';
  html += '<td style="text-align:right;font-weight:600;" id="prepqty-line-' + idx + '">' + (qty * price).toFixed(2) + '</td>';
  html += '</tr>';
});

html += '</tbody></table></div>';
```

Replace with:
```javascript
var html = '<div class="table-wrap"><table class="data-table" style="margin:0;">';
html += '<thead><tr><th>Product</th><th style="text-align:right;">Ordered</th><th style="text-align:right;width:100px;">Prepared</th><th style="text-align:right;width:100px;">Weight (kg)</th><th style="text-align:right;">Price</th><th style="text-align:right;">Total</th></tr></thead><tbody>';

items.forEach(function(item, idx) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var name = soGetProductName(item.product_id);
  var unit = prod ? (prod.unit || '') : '';
  var price = parseFloat(item.unit_price) || 0;
  var isPcs = item.order_pcs != null;
  var orderedDisplay = isPcs ? (item.order_pcs + ' pcs') : ((item.quantity || 0) + ' ' + unit);
  var preparedQty = isPcs ? item.order_pcs : (item.quantity || 0);
  var weightVal = item.actual_weight_kg != null ? item.actual_weight_kg : (isPcs ? '' : (item.quantity || 0));
  var weightStep = 'any';
  var weightLabel = isPcs ? 'kg' : unit;

  html += '<tr>';
  html += '<td style="font-weight:600;">' + esc(name) + (isPcs ? ' <span style="font-size:10px;color:var(--text-muted);">[ordered in pcs]</span>' : '') + '</td>';
  html += '<td style="text-align:right;color:var(--text-muted);">' + esc(orderedDisplay) + '</td>';
  html += '<td style="text-align:right;">';
  if (isPcs) {
    html += '<input type="number" class="prepqty-pcs-input" data-item-id="' + esc(item.id) + '" value="' + preparedQty + '" min="0" step="1" style="width:70px;text-align:right;padding:4px 6px;font-size:13px;"> pcs';
  } else {
    html += '<span style="color:var(--text-muted);font-size:11px;">— same —</span>';
  }
  html += '</td>';
  html += '<td style="text-align:right;">';
  html += '<input type="number" class="prepqty-input" data-item-id="' + esc(item.id) + '" data-price="' + price + '" data-is-pcs="' + (isPcs ? '1' : '0') + '" value="' + weightVal + '" min="0" step="' + weightStep + '" oninput="soPrepQtyRecalc()" placeholder="' + (isPcs ? 'required' : '') + '" style="width:80px;text-align:right;padding:4px 6px;font-size:13px;' + (isPcs && weightVal === '' ? 'border-color:#E8A020;' : '') + '"> ' + weightLabel;
  html += '</td>';
  html += '<td style="text-align:right;">' + price.toFixed(2) + '</td>';
  html += '<td style="text-align:right;font-weight:600;" id="prepqty-line-' + idx + '">' + ((parseFloat(weightVal) || 0) * price).toFixed(2) + '</td>';
  html += '</tr>';
});

html += '</tbody></table></div>';
```

- [ ] **Step 2: Add validation in `soPrepQtyConfirm`**

Find at sales.html:2374:
```javascript
async function soPrepQtyConfirm() {
  var orderId = soPrepQtyOrderId;
  var btn = document.getElementById('so-prepqty-confirm');
  btnLoading(btn, true);

  // Update each item's quantity + line_total
  var inputs = document.querySelectorAll('.prepqty-input');
  var grandTotal = 0;
  for (var i = 0; i < inputs.length; i++) {
    var inp = inputs[i];
    var itemId = inp.dataset.itemId;
    var newQty = parseFloat(inp.value) || 0;
    var price = parseFloat(inp.dataset.price) || 0;
    var lineTotal = newQty * price;
    grandTotal += lineTotal;

    // Update local array
    var localItem = orderItems.find(function(x) { return x.id === itemId; });
    if (localItem) {
      localItem.quantity = newQty;
      localItem.line_total = lineTotal;
    }

    // Update DB
    await sbQuery(sb.from('sales_order_items').update({ quantity: newQty, line_total: lineTotal }).eq('id', itemId).select());
  }
```

Replace with:
```javascript
async function soPrepQtyConfirm() {
  var orderId = soPrepQtyOrderId;
  var btn = document.getElementById('so-prepqty-confirm');

  // Pre-validate: every pcs-ordered line must have a weight > 0
  var weightInputs = document.querySelectorAll('.prepqty-input');
  for (var v = 0; v < weightInputs.length; v++) {
    var w = weightInputs[v];
    if (w.dataset.isPcs === '1' && !(parseFloat(w.value) > 0)) {
      notify('Please enter actual weight for all pcs-ordered items', 'warning');
      w.focus();
      return;
    }
  }

  btnLoading(btn, true);

  // Build a map of itemId -> prepared pcs (for pcs-ordered lines)
  var pcsMap = {};
  document.querySelectorAll('.prepqty-pcs-input').forEach(function(inp) {
    pcsMap[inp.dataset.itemId] = parseInt(inp.value, 10) || 0;
  });

  // Update each item's quantity + line_total + (for pcs lines) order_pcs + actual_weight_kg
  var inputs = document.querySelectorAll('.prepqty-input');
  var grandTotal = 0;
  for (var i = 0; i < inputs.length; i++) {
    var inp = inputs[i];
    var itemId = inp.dataset.itemId;
    var isPcsLine = inp.dataset.isPcs === '1';
    var newQty = parseFloat(inp.value) || 0;
    var price = parseFloat(inp.dataset.price) || 0;
    var lineTotal = newQty * price;
    grandTotal += lineTotal;

    var updatePayload = { quantity: newQty, line_total: lineTotal };
    if (isPcsLine) {
      updatePayload.actual_weight_kg = newQty;
      updatePayload.order_pcs = pcsMap[itemId] || 0;
    }

    // Update local array
    var localItem = orderItems.find(function(x) { return x.id === itemId; });
    if (localItem) {
      localItem.quantity = newQty;
      localItem.line_total = lineTotal;
      if (isPcsLine) {
        localItem.actual_weight_kg = newQty;
        localItem.order_pcs = pcsMap[itemId] || 0;
      }
    }

    // Update DB
    await sbQuery(sb.from('sales_order_items').update(updatePayload).eq('id', itemId).select());
  }
```

The rest of the function (order grand_total update, photo step) stays unchanged.

- [ ] **Step 3: Verify in browser & DB**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. Open the test order from Task 4 (with one pcs line and one kg line). Click Mark Prepared.
3. Verify the modal shows:
   - Normal kg line: "— same —" in Prepared column, weight input pre-filled with kg value
   - Pcs line: "[ordered in pcs]" badge, "50" in Prepared (pcs) column, EMPTY weight input with orange border
4. Try clicking Confirm. Expected: warning toast "Please enter actual weight for all pcs-ordered items".
5. Type `12.4` into the pcs line's weight input. Note that the line total RM updates as you type.
6. Click Confirm. Expected: modal closes, photo modal opens, order moves to prepared.
7. Run:
```bash
npx supabase db query --linked "SELECT id, quantity, line_total, order_pcs, actual_weight_kg FROM sales_order_items WHERE order_id = (SELECT id FROM sales_orders ORDER BY created_at DESC LIMIT 1) ORDER BY id;"
```
Expected: pcs line now has `quantity = 12.4`, `line_total = 12.4 × unit_price`, `actual_weight_kg = 12.4`, `order_pcs = 50`. Normal line unchanged.

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "feat(sales): capture actual weight for pcs-ordered lines at Mark Prepared"
```

---

## Task 6: Show pcs in worker prep WhatsApp message

**Files:**
- Modify: `sales.html` — `buildPrepMessage` (sales.html:2206)

Workers preparing the order need to see the pcs count, not the empty kg.

- [ ] **Step 1: Modify the items loop in `buildPrepMessage`**

Find at sales.html:2230:
```javascript
items.forEach(function(item) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var varName = soGetProductVariety(item.product_id);
  var nameBM = getProductNameBM(prod);
  var qty = item.quantity || 0;
  var unit = prod ? (prod.unit || '') : '';

  var line = '\u2022 ';
  if (varName && varName !== '\u2014') line += varName + ' ';
  line += nameBM;
  if (item.index_min != null && item.index_max != null) {
    line += ' (Index ' + item.index_min + '-' + item.index_max + ')';
  } else if (item.index_min != null) {
    line += ' (Index ' + item.index_min + ')';
  }
  line += ' \u2014 ' + qty + (unit ? ' ' + unit : '');
  msg += line + '\n';
});
```

Replace the last three lines (`line += ' — ' + qty...` block) with:
```javascript
items.forEach(function(item) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var varName = soGetProductVariety(item.product_id);
  var nameBM = getProductNameBM(prod);
  var qty = item.quantity || 0;
  var unit = prod ? (prod.unit || '') : '';
  var isPcs = item.order_pcs != null;

  var line = '\u2022 ';
  if (varName && varName !== '\u2014') line += varName + ' ';
  line += nameBM;
  if (item.index_min != null && item.index_max != null) {
    line += ' (Index ' + item.index_min + '-' + item.index_max + ')';
  } else if (item.index_min != null) {
    line += ' (Index ' + item.index_min + ')';
  }
  if (isPcs) {
    line += ' \u2014 ' + item.order_pcs + ' pcs (timbang ikut kg)';
  } else {
    line += ' \u2014 ' + qty + (unit ? ' ' + unit : '');
  }
  msg += line + '\n';
});
```

(`timbang ikut kg` = "weigh in kg" in Bahasa Malaysia, matching the message's existing language.)

- [ ] **Step 2: Verify in browser**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. On a non-prepared order containing a pcs line, click "Start Preparing" → assign worker → preview the WhatsApp message.
3. Expected: the pcs line shows `— 50 pcs (timbang ikut kg)`.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat(sales): show pcs in worker prep WhatsApp message"
```

---

## Task 7: Show kg + pcs subtitle on 80mm DO/Cash Sales doc

**Files:**
- Modify: `sales.html` — `soGenerateDoc` items loop (sales.html:6755)

For pcs-ordered lines that have been weighed, show the kg total normally and add a small `(50 pcs)` subtitle under the product name.

- [ ] **Step 1: Replace the items loop in `soGenerateDoc`**

Find at sales.html:6754:
```javascript
// Items list
var subtotal = 0;
items.forEach(function(item, idx) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var prodName = prod ? prod.name : '\u2014';
  var prodVariety = soGetProductVariety(item.product_id);
  var prodUnit = prod ? (prod.unit || '') : '';
  var fullName = '';
  if (prodVariety && prodVariety !== '\u2014') fullName += prodVariety + ' ';
  fullName += prodName;
  var packInfo = [];
  if (prod && prod.box_quantity) packInfo.push(prod.box_quantity + 'pcs');
  if (prod && prod.weight_range) packInfo.push(prod.weight_range);
  if (packInfo.length) fullName += ' (' + packInfo.join(', ') + ')';
  var lineTotal = parseFloat(item.line_total) || 0;
  subtotal += lineTotal;
  var qtyStr = (item.quantity || 0) + prodUnit;
  var price = (parseFloat(item.unit_price) || 0).toFixed(2);

  html += '<div style="margin-bottom:6px;">';
  html += '<div style="font-weight:700;font-size:11px;">' + (idx + 1) + '. ' + esc(fullName) + '</div>';
  html += '<div style="display:flex;justify-content:space-between;font-size:10px;padding-left:12px;">';
  html += '<span>' + esc(qtyStr) + ' x ' + price + '</span>';
  html += '<span style="font-weight:700;">' + lineTotal.toFixed(2) + '</span>';
  html += '</div>';
  html += '</div>';
});
```

Replace with:
```javascript
// Items list
var subtotal = 0;
items.forEach(function(item, idx) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var prodName = prod ? prod.name : '\u2014';
  var prodVariety = soGetProductVariety(item.product_id);
  var prodUnit = prod ? (prod.unit || '') : '';
  var fullName = '';
  if (prodVariety && prodVariety !== '\u2014') fullName += prodVariety + ' ';
  fullName += prodName;
  var packInfo = [];
  if (prod && prod.box_quantity) packInfo.push(prod.box_quantity + 'pcs');
  if (prod && prod.weight_range) packInfo.push(prod.weight_range);
  if (packInfo.length) fullName += ' (' + packInfo.join(', ') + ')';
  var lineTotal = parseFloat(item.line_total) || 0;
  subtotal += lineTotal;
  var qtyStr = (item.quantity || 0) + prodUnit;
  var price = (parseFloat(item.unit_price) || 0).toFixed(2);
  var isPcs = item.order_pcs != null;

  html += '<div style="margin-bottom:6px;">';
  html += '<div style="font-weight:700;font-size:11px;">' + (idx + 1) + '. ' + esc(fullName) + '</div>';
  if (isPcs) {
    html += '<div style="font-size:9px;color:#555;padding-left:12px;font-style:italic;">(' + item.order_pcs + ' pcs)</div>';
  }
  html += '<div style="display:flex;justify-content:space-between;font-size:10px;padding-left:12px;">';
  html += '<span>' + esc(qtyStr) + ' x ' + price + '</span>';
  html += '<span style="font-weight:700;">' + lineTotal.toFixed(2) + '</span>';
  html += '</div>';
  html += '</div>';
});
```

- [ ] **Step 2: Verify in browser**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. Open the test order (must be at status `prepared` or beyond, with weight entered).
3. Click the DO/Cash Sales doc button to generate the 80mm thermal doc.
4. Expected: the pcs line shows the product name on one row, then `(50 pcs)` italic line, then `12.4kg x 4.00     49.60` on the next row.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat(sales): show pcs subtitle on 80mm DO/CS document"
```

---

## Task 8: Show pcs subtitle on A4 DO/Cash Sales doc

**Files:**
- Modify: `sales.html` — `soGenerateDocA4` items loop (sales.html:6892)

- [ ] **Step 1: Replace the A4 items table row rendering**

Find at sales.html:6892:
```javascript
items.forEach(function(item, idx) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var prodName = prod ? prod.name : '—';
  var prodVariety = soGetProductVariety(item.product_id);
  var prodUnit = prod ? (prod.unit || '') : '';
  var fullName = '';
  if (prodVariety && prodVariety !== '—') fullName += prodVariety + ' ';
  fullName += prodName;
  var packInfo = [];
if (prod && prod.box_quantity) packInfo.push(prod.box_quantity + 'pcs');
if (prod && prod.weight_range) packInfo.push(prod.weight_range);
if (packInfo.length) fullName += ' (' + packInfo.join(', ') + ')';
  var lineTotal = parseFloat(item.line_total) || 0;
  subtotal += lineTotal;
  var qty = item.quantity || 0;
  var unitPrice = (parseFloat(item.unit_price) || 0).toFixed(2);

  html += '<tr>';
  html += '<td>' + (idx + 1) + '</td>';
  html += '<td>' + esc(fullName) + '</td>';
  html += '<td>' + qty + '</td>';
  html += '<td>' + esc(prodUnit) + '</td>';
  html += '<td>' + unitPrice + '</td>';
  html += '<td>' + lineTotal.toFixed(2) + '</td>';
  html += '</tr>';
});
```

Replace with:
```javascript
items.forEach(function(item, idx) {
  var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
  var prodName = prod ? prod.name : '—';
  var prodVariety = soGetProductVariety(item.product_id);
  var prodUnit = prod ? (prod.unit || '') : '';
  var fullName = '';
  if (prodVariety && prodVariety !== '—') fullName += prodVariety + ' ';
  fullName += prodName;
  var packInfo = [];
  if (prod && prod.box_quantity) packInfo.push(prod.box_quantity + 'pcs');
  if (prod && prod.weight_range) packInfo.push(prod.weight_range);
  if (packInfo.length) fullName += ' (' + packInfo.join(', ') + ')';
  var lineTotal = parseFloat(item.line_total) || 0;
  subtotal += lineTotal;
  var qty = item.quantity || 0;
  var unitPrice = (parseFloat(item.unit_price) || 0).toFixed(2);
  var isPcs = item.order_pcs != null;
  var descCell = esc(fullName);
  if (isPcs) {
    descCell += '<div style="font-size:10px;color:#666;font-style:italic;">(' + item.order_pcs + ' pcs)</div>';
  }

  html += '<tr>';
  html += '<td>' + (idx + 1) + '</td>';
  html += '<td>' + descCell + '</td>';
  html += '<td>' + qty + '</td>';
  html += '<td>' + esc(prodUnit) + '</td>';
  html += '<td>' + unitPrice + '</td>';
  html += '<td>' + lineTotal.toFixed(2) + '</td>';
  html += '</tr>';
});
```

- [ ] **Step 2: Verify in browser**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. Open the test order. Click the A4 doc button.
3. Expected: the pcs line's Description cell shows the product name with `(50 pcs)` italic line below it. Qty/Unit/Price/Amount columns show the kg figures.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat(sales): show pcs subtitle on A4 DO/CS document"
```

---

## Task 9: Block invoice creation for orders with un-weighed pcs lines

**Files:**
- Modify: `sales.html` — `invCreateDraftInvoice` (sales.html:5559)

This is a safety net. Mark Prepared already requires weights, but a future code path or manual SQL edit could leave a pcs line un-weighed. Block invoice creation with a clear message.

- [ ] **Step 1: Add the guard at the top of `invCreateDraftInvoice`**

Find at sales.html:5559:
```javascript
async function invCreateDraftInvoice() {
  var selectedIds = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; });
  if (!selectedIds.length) { notify('Select at least one DO', 'warning'); return; }
```

Insert immediately after the `if (!selectedIds.length)` line:
```javascript
  // Guard: every selected DO must have all pcs-ordered lines weighed
  var pendingByOrder = {};
  selectedIds.forEach(function(orderId) {
    var pending = orderItems.filter(function(i) {
      return i.order_id === orderId && i.order_pcs != null && (i.actual_weight_kg == null || !(parseFloat(i.actual_weight_kg) > 0));
    }).length;
    if (pending > 0) pendingByOrder[orderId] = pending;
  });
  var pendingOrderIds = Object.keys(pendingByOrder);
  if (pendingOrderIds.length) {
    var firstOrderId = pendingOrderIds[0];
    var firstOrder = orders.find(function(o) { return o.id === firstOrderId; });
    var label = firstOrder ? (firstOrder.doc_number || firstOrder.id) : firstOrderId;
    notify('Cannot invoice — order ' + label + ' has ' + pendingByOrder[firstOrderId] + ' item(s) pending weight. Mark Prepared first.', 'warning');
    return;
  }
```

- [ ] **Step 2: Verify in browser & DB**

1. Deploy: `npx netlify-cli deploy --prod --dir=.`
2. Manually create a "broken" state to test the guard. Run:
```bash
npx supabase db query --linked "UPDATE sales_order_items SET actual_weight_kg = NULL, quantity = 0, line_total = 0 WHERE order_pcs IS NOT NULL AND id = (SELECT id FROM sales_order_items WHERE order_pcs IS NOT NULL ORDER BY id DESC LIMIT 1);"
```
3. Reload the sales page. Go to Invoicing tab. Select the affected DO. Click "Create Draft Invoice".
4. Expected: warning toast like "Cannot invoice — order DO-XXXX has 1 item(s) pending weight. Mark Prepared first."
5. Restore the test row by re-running the Mark Prepared flow on the affected order, OR run:
```bash
npx supabase db query --linked "UPDATE sales_order_items SET actual_weight_kg = 12.4, quantity = 12.4, line_total = 12.4 * unit_price WHERE order_pcs IS NOT NULL AND actual_weight_kg IS NULL;"
```
6. Reload, select the DO again, create invoice. Expected: success.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat(sales): guard invoice creation against un-weighed pcs lines"
```

---

## Task 10: Final end-to-end smoke test

- [ ] **Step 1: Full happy path through the UI**

1. Make sure latest code is deployed: `npx netlify-cli deploy --prod --dir=.`
2. Create a fresh order with a real customer:
   - Line 1: 10 kg of any kg product (normal mode)
   - Line 2: 30 pcs of the same kg product (toggle "Order in pcs" on)
3. Verify subtotal shows only Line 1's RM, with "+ 1 item pending weight" hint.
4. Save order. Verify it appears in the orders list.
5. Click Start Preparing → assign worker → confirm.
6. Worker WhatsApp message preview: verify Line 2 shows `30 pcs (timbang ikut kg)`.
7. Click Mark Prepared. In the modal:
   - Line 1: Prepared shows "— same —", weight pre-filled.
   - Line 2: shows "[ordered in pcs]" badge, prepared = 30, weight empty.
8. Try Confirm without weight → warning.
9. Enter `8.5` for Line 2's weight. Confirm. Take/skip photo.
10. Order status moves to Prepared.
11. Open the 80mm doc. Line 2 shows `(30 pcs)` subtitle and `8.5kg x <price>`.
12. Open the A4 doc. Same.
13. Go to Invoicing tab. Select the DO. Click Create Draft Invoice. Expected: invoice created.
14. Open the invoice. Verify the aggregated line for that product reflects 10 kg + 8.5 kg = 18.5 kg at the unit price.

- [ ] **Step 2: Confirm DB state for the test order**

```bash
npx supabase db query --linked "SELECT i.id, p.name, i.quantity, i.unit_price, i.line_total, i.order_pcs, i.actual_weight_kg FROM sales_order_items i JOIN sales_products p ON p.id = i.product_id WHERE i.order_id = (SELECT id FROM sales_orders ORDER BY created_at DESC LIMIT 1) ORDER BY i.id;"
```

Expected: the kg line has `quantity = 10, order_pcs = NULL, actual_weight_kg = NULL`. The pcs line has `quantity = 8.5, order_pcs = 30, actual_weight_kg = 8.5, line_total = 8.5 × unit_price`.

- [ ] **Step 3: Confirm monthly kg report still works**

Run:
```bash
npx supabase db query --linked "SELECT p.name, SUM(i.quantity) AS total_kg FROM sales_order_items i JOIN sales_products p ON p.id = i.product_id JOIN sales_orders o ON o.id = i.order_id WHERE o.delivery_date >= date_trunc('month', CURRENT_DATE) GROUP BY p.name ORDER BY total_kg DESC;"
```

Expected: figures include the test order's contributions (kg line + actual weight from pcs line) summed correctly.

- [ ] **Step 4: Final commit if any cleanup needed**

```bash
git status
# If clean: feature complete.
# If any pending changes from manual fixes:
git add sales.html
git commit -m "chore(sales): minor fixups from end-to-end smoke test"
```

---

## Self-Review Checklist (run before handing off)

- [x] **Spec coverage**
  - Data model (`order_pcs`, `actual_weight_kg`, `quantity` semantics) → Task 1
  - Toggle visibility rules (kg products only, hidden for walk-ins) → Task 3 step 2 (`canTogglePcs`)
  - "+ N items pending weight" hint → Task 3 step 5
  - Pcs-ordered line storage (quantity=0, line_total=0, order_pcs=N, actual_weight_kg=null) → Task 4
  - Mark Prepared modal extension → Task 5
  - Edit weight after prepared → already supported by existing edit handlers (`localItem.quantity` editable in `soPrepQtyConfirm` and `soDelQtyConfirm` paths use the same input class; the design says weight remains editable from order detail — this works through the existing edit-quantity flow because once `actual_weight_kg = quantity`, future edits to `quantity` reflect a new weight)
  - Prep doc shows pcs → Task 6
  - DO/CS docs show kg + (pcs) subtitle → Tasks 7, 8
  - Invoice generation guard → Task 9
  - Returns/reports work unchanged → no task needed (reads `quantity`/`line_total`)

- [x] **No placeholders** — every step has either exact code or an exact command + expected output.

- [x] **Type consistency** — `orderInPcs` (boolean), `orderPcs` (string in soItems, int on save) used consistently. DB columns `order_pcs` (int) and `actual_weight_kg` (numeric) used consistently across tasks.

- [x] **Frequent commits** — each task ends with a commit.

- [x] **DRY** — the duplicated insert blocks in Task 4 steps 2 & 3 are intentional: `soSaveOrder` has separate edit and create paths in the source today. Refactoring them is out of scope; the duplication is the smallest correct change.
