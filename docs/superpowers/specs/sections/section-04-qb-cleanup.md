# Section 04: QB Cleanup + Dashboard Fix

## Overview

This section removes all QuickBooks (QB) references from the sales module and updates the dashboard to use the new `invoice_id` field on `sales_orders` instead of the old `qb_invoice_no`. The Invoicing tab is stubbed with a placeholder so it remains functional between cleanup and the rebuild in sections 05-06.

**File to modify:** `sales.html`

**Dependencies:** Section 01 (DB migration) must be complete -- the `sales_orders.invoice_id` column must exist before the dashboard logic can reference it. This section can run in parallel with sections 02 and 03.

**Blocks:** Section 05 (Create Invoice) depends on this cleanup being done first.

---

## Tests / Verification

All verification is manual (no test framework -- vanilla JS/HTML project).

### Verify: QB references removed

1. Open `sales.html` in browser.
2. Navigate to the **Invoicing** tab.
   - Confirm the tab does NOT show "QuickBooks" or "QB" anywhere.
   - Confirm the old QB invoice number input modal is gone.
   - Confirm a placeholder message appears (e.g., "Invoicing system coming soon" or a stub UI).
3. Navigate to the **Payments** tab.
   - In the Delivery Orders section, confirm there is no "QB Invoice" column in the table.
   - Confirm the status column no longer references "Invoiced"/"Uninvoiced" based on `qb_invoice_number`.
4. Open browser console and verify:
   - `typeof invSaveInvoice` returns `'undefined'` (function removed).
   - No JS errors on page load or tab switching.

### Verify: Dashboard updated

1. Navigate to the **Dashboard** tab.
2. The "Uninvoiced DO" card should show a count of completed DOs where `invoice_id` is null (not based on `qb_invoice_no`).
3. The "Total Owed" calculation should be: `unpaidCS + uninvoicedDO` where uninvoiced DOs are filtered by `!o.invoice_id` instead of `!o.qb_invoice_no`.
4. In browser console, confirm the uninvoiced DO filter logic:
   - Find a DO in the `orders` array. Its `qb_invoice_no` field (if any) should be irrelevant to the dashboard count.
   - The dashboard should check `o.invoice_id` instead.

### Verify: No regressions

1. Switch between all sidebar tabs (Dashboard, Orders, Payments, Invoicing, Customers, Products, Reports) -- no JS errors.
2. Existing order creation, editing, and completion flows still work.
3. Payments tab CS section is unchanged and functional.

---

## Implementation Details

### Step 1: Remove QB Modal HTML (lines ~930-954)

Delete the entire `<!-- INVOICE MODAL -->` block from the HTML. This is the modal with id `inv-modal` that contains:
- Title "Mark as Invoiced"
- `inv-do-list` container
- `inv-total` display
- `inv-qb-number` input field (labeled "QB INVOICE NUMBER")
- `inv-date` input field
- "Save Invoice" button calling `invSaveInvoice()`

The complete block to remove starts at `<!-- INVOICE MODAL -->` and ends at the closing `</div>` before the `<script>` tag.

### Step 2: Remove `invSaveInvoice()` function (lines ~4424-4464)

Delete the entire `async function invSaveInvoice()` function. This function:
- Reads `inv-qb-number` and `inv-date` inputs
- Updates `sales_orders` with `qb_invoice_no` and `qb_invoiced_at`
- Updates local `orders` array with QB fields

### Step 3: Remove `invOpenInvoiceModal()` function (lines ~4401-4422)

Delete the entire `function invOpenInvoiceModal()` function. This populates and opens the QB modal.

### Step 4: Remove `invToggleHistory()` function (lines ~4117-4128)

Delete this function. It toggles the expansion of QB invoice history groups, which will no longer exist.

### Step 5: Update the Invoicing tab subtitle (line ~156)

Change the page subtitle from:
```html
<div class="page-subtitle">QuickBooks invoice management</div>
```
to:
```html
<div class="page-subtitle">Invoice management</div>
```

### Step 6: Rewrite `renderInvoicing()` with placeholder stub

Replace the entire `renderInvoicing()` function body. The current function has two sections:
- Section A: "Uninvoiced Delivery Orders" with DO selection, checkboxes, and "Mark as Invoiced" button (references `qb_invoice_no`)
- Section B: "Invoice History" grouping by `qb_invoice_no`

Replace with a placeholder stub that will be expanded in sections 05 and 06. The stub should:
1. Show an "Uninvoiced Delivery Orders" section listing the count of completed DOs where `invoice_id` is null (using the new field, not `qb_invoice_no`).
2. Show a placeholder message like "Full invoicing system coming soon" or simply an empty state.

**Keep these existing helper functions** (they will be reused in sections 05-06):
- `invSelectedDOs` variable
- `invToggleCustomer()`
- `invToggleDO()`
- `invSelectAllCustomer()`
- `invUpdateSelectAll()`
- `invUpdateButtons()`
- `invRenderBillingSummary()`
- `invBuildSummaryText()`
- `invCopySummary()`
- `invPrintSummary()`

These functions are generic DO-selection and billing-summary helpers. However, update any internal references to `qb_invoice_no` within them. Specifically, `renderInvoicing()` is the only function that filters by `!o.qb_invoice_no` -- the helpers operate on `invSelectedDOs` which is populated by checkbox clicks, not by QB fields. So the helpers can stay as-is.

The stub `renderInvoicing()` should filter uninvoiced DOs using:
```javascript
var uninvoicedDOs = orders.filter(function(o) {
    return o.doc_type === 'delivery_order' && !o.invoice_id && o.status === 'completed';
});
```

Note the change from `o.status !== 'cancelled'` to `o.status === 'completed'` -- only completed DOs should be eligible for invoicing (not pending/preparing/etc.). Also uses `!o.invoice_id` instead of `!o.qb_invoice_no`.

### Step 7: Update Payments tab DO section (lines ~3642-3667)

In `renderPayments()`, the Delivery Orders section currently has a table with columns: Doc #, Date, Total, **QB Invoice**, **Status** (where status shows "Invoiced"/"Uninvoiced" based on `qb_invoice_number`).

Changes:
1. Remove the "QB Invoice" column header and data cell (`o.qb_invoice_number`).
2. Change the status badge logic from `o.qb_invoice_number ? 'Invoiced' : 'Uninvoiced'` to check `o.invoice_id` instead. Use: `o.invoice_id ? 'Invoiced' : 'Uninvoiced'`.
3. Remove the "(paid via QB Invoice)" text from the DO section header. Replace with "(paid via Invoice)" or just remove the parenthetical.

### Step 8: Update Dashboard uninvoiced DO calculation (lines ~1122-1127)

Change the uninvoiced DO filter in `renderDashboard()` from:
```javascript
if (o.doc_type === 'delivery_order' && !o.qb_invoice_no && o.status !== 'cancelled') {
```
to:
```javascript
if (o.doc_type === 'delivery_order' && !o.invoice_id && o.status === 'completed') {
```

This makes two changes:
1. Uses `invoice_id` instead of `qb_invoice_no` (the core QB cleanup).
2. Filters to `status === 'completed'` only (non-completed DOs should not count as "uninvoiced" because they are still in progress).

The `totalOwed` calculation (`unpaidCS + uninvoicedDO`) remains the same formula. In section 13, it will be updated further to include outstanding invoices, but for now the immediate fix is just the field reference change.

### Step 9: Clean up any remaining QB string references

Search the entire `sales.html` for any remaining occurrences of:
- `qb_invoice` (in variable names, object property access, string literals)
- `QuickBooks`
- `QB`

Ensure none remain in active code. The `qb_invoice_no` and `qb_invoiced_at` columns stay in the database (no migration needed), but the JS should no longer read or write them.

---

## Summary of Changes (Implemented)

169 lines deleted, 13 inserted (net -156 lines).

| What | Action |
|------|--------|
| `inv-modal` HTML block (24 lines) | Deleted entirely |
| `invSaveInvoice()` | Deleted |
| `invOpenInvoiceModal()` | Deleted |
| `invToggleHistory()` | Deleted |
| Invoicing tab subtitle | Changed "QuickBooks invoice management" to "Invoice management" |
| `renderInvoicing()` | Rewrote — uninvoiced DOs use `!o.invoice_id` + `status === 'completed'`; Section B replaced with "Invoice list coming soon" placeholder |
| Payments tab DO table | Removed QB Invoice column, status badge uses `o.invoice_id` |
| Dashboard `uninvoicedDO` | Changed from `!o.qb_invoice_no` to `!o.invoice_id`, filter `status === 'completed'` |
| DO section header text | "paid via QB Invoice" → "paid via Invoice" |
| `invUpdateButtons()` | Updated button ID from `inv-mark-btn` to `inv-create-btn`, label "Create Invoice" (code review fix) |
| Reusable helpers | All 10 preserved unchanged |

## Deviations from Plan
- Button renamed from "Mark as Invoiced" to "Create Invoice" to match future section-05 workflow
- `invUpdateButtons()` required fix (code review caught stale button ID reference)
