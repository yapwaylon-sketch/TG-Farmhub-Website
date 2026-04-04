# Section 06: Invoice List (Invoicing Tab)

## Overview

This section implements the invoice list view within the Invoicing tab of `sales.html`. After invoices are created (section 05), users need to browse, filter, expand, and manage them. This section adds: a filter bar (customer, status, date range), summary cards (Outstanding, Overdue, This Month), invoice card rendering with status badges, click-to-expand detail view (items, DOs, payments, credit notes, action buttons), and invoice cancellation with cascade logic.

**File to modify:** `sales.html`

**Depends on:**
- Section 01 (DB migration -- tables exist)
- Section 02 (data loading -- `invoices`, `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes` arrays loaded; helper functions `invoiceBalance()`, `isInvoiceOverdue()`, `recalcInvoicePaymentStatus()`, `getCustomerUninvoicedDOs()`)
- Section 05 (invoice creation flow in the Invoicing tab -- invoices can be created as drafts)

**Blocks:** Sections 07 (document generation), 08 (approval workflow), 09 (invoice payments), 10 (credit notes) -- these add action button handlers that are stubbed here.

---

## Tests / Verification Steps

Run these after implementation to confirm correctness.

### Verify: Filters

1. Open `sales.html`, navigate to the Invoicing tab.
2. The invoice list section should appear below the "Create Invoice" section.
3. **Status filter**: dropdown with options All, Draft, Issued, Overdue, Partial, Paid. Selecting each option filters the list correctly.
4. **Customer filter**: dropdown narrows results to invoices for that customer only.
5. **Date range filter**: entering a start/end date shows only invoices within that range (based on `invoice_date`).

### Verify: Summary Cards

1. Three summary cards appear above the invoice list:
   - **Total Outstanding** -- sum of `invoiceBalance(inv)` for all issued/partial invoices.
   - **Overdue** -- count and total amount of invoices where `isInvoiceOverdue(inv)` is true. Red styling if count > 0.
   - **This Month** -- count and total of invoices created in the current calendar month.

### Verify: Status Badges

1. Invoice cards display colored status badges:
   - Draft = grey
   - Issued = blue
   - Overdue = red (overrides Issued/Partial when past due)
   - Partial = gold
   - Paid = green
   - Cancelled = dim/muted

### Verify: Detail Expansion

1. Click an invoice card -- it expands to show:
   - Invoice header info (number, date, due date, payment terms, customer)
   - Items table (product name, qty, unit price, line total)
   - Linked DOs list (doc numbers with dates)
   - Payment history (if any payments recorded)
   - Credit notes list (if any CNs applied)
   - Action buttons (Approve, Record Payment, Add Credit Note, Print/Share, Cancel, Add More DOs)
2. Click again to collapse.

### Verify: Cancellation

1. Cancel a **draft** invoice:
   - Confirmation modal appears (styled `confirmAction()`, not browser `confirm()`).
   - After confirming: linked DOs have `invoice_id` set back to `null`, junction records deleted, invoice status set to `cancelled`.
   - The DOs reappear in the "uninvoiced" list in the Create Invoice section.
2. Attempt to cancel an invoice **with payments recorded** -- should be blocked with a notification explaining why.
3. SQL validation after cancellation:
   ```sql
   -- Cancelled invoice should have status = 'cancelled'
   SELECT id, status FROM sales_invoices WHERE status = 'cancelled';

   -- DOs should be unlinked
   SELECT id, invoice_id FROM sales_orders WHERE invoice_id IS NULL AND doc_type = 'delivery_order';
   ```

### Verify: Empty State

1. If no invoices exist, the list section shows an appropriate empty state message (e.g., "No invoices yet").

---

## Implementation Details

### Location in renderInvoicing()

The existing `renderInvoicing()` function in `sales.html` (around line 3964) currently has two sections:
- Section A: "Uninvoiced Delivery Orders" (the create-invoice flow, rebuilt in section 05)
- Section B: "Invoice History" (the old QB-grouped list, removed in section 04)

This section replaces the old "Invoice History" (Section B) with a proper invoice list. The new Section B should be rendered after the Create Invoice section within `renderInvoicing()`.

### Filter Bar

Add a filter bar div at the top of Section B with three inline controls:

1. **Customer dropdown** (`<select>`) -- populated from the `invoices` array's unique `customer_id` values. Include an "All Customers" option. Populate on data load, not on every render (per project convention to prevent state reset).

2. **Status dropdown** (`<select>`) -- options: All, Draft, Issued, Overdue, Partial, Paid. "Overdue" is a computed status: filter invoices where `isInvoiceOverdue(inv)` returns true (past `due_date`, status is `issued`, payment_status is `unpaid` or `partial`).

3. **Date range** -- two date inputs (from/to) using the project's custom calendar picker (`calOpen()`). Filter on `invoice_date`.

Store filter state in module-level variables (e.g., `invFilterCustomer`, `invFilterStatus`, `invFilterDateFrom`, `invFilterDateTo`). On change, re-render the list portion only (not the entire tab, to preserve Create Invoice state).

### Summary Cards

Three cards in a flex row, styled consistently with the dashboard summary cards pattern already used in the Sales module:

1. **Total Outstanding**: Sum `invoiceBalance(inv)` for invoices where `status === 'issued'` and `payment_status !== 'paid'`. Display as "RM X,XXX.XX".

2. **Overdue**: Count and sum for invoices where `isInvoiceOverdue(inv)` is true. Red background/text when count > 0.

3. **This Month Invoiced**: Count and sum of invoices where `invoice_date` falls in the current month (regardless of status).

### Invoice Cards

Render each invoice as a card (styled like existing order cards -- `background:var(--bg-card)`, border, border-radius 10px). Each card shows:

- **Invoice number** (bold, e.g., "INV-260403-001")
- **Customer name**
- **Invoice date** and **due date**
- **Grand total**, **amount paid**, **balance due** (using `invoiceBalance()`)
- **Status badge** -- small inline badge with background color:
  - Draft: `background:#666; color:#fff`
  - Issued: `background:var(--info); color:#fff` (blue)
  - Partial: `background:var(--gold); color:#000` (gold/amber)
  - Paid: `background:var(--green); color:#fff`
  - Cancelled: `background:var(--border); color:var(--text-muted)`
  - Overdue: `background:var(--danger); color:#fff` (red) -- takes precedence over Issued/Partial when overdue
- **Overdue indicator**: If `isInvoiceOverdue(inv)`, show "Overdue X days" in red text. Calculate days as `Math.floor((today - due_date) / 86400000)`.

Sort invoices by `created_at` descending (newest first), matching the load order.

### Detail Expansion

On card click, toggle a detail section below the card header. Use the same expand/collapse pattern as `invToggleCustomer()` and `invToggleHistory()` (toggle `display:none/block`, rotate chevron icon).

The expanded detail contains:

**Items table:**
```
| # | Product | Qty | Unit Price | Amount |
```
Pull from `invoiceItems` filtered by `invoice_id`.

**Linked DOs:**
A comma-separated or listed set of DO doc numbers with dates. Pull from `invoiceOrders` joined with `orders` array.

**Payment history:**
List of payments from `invoicePayments` filtered by `invoice_id`. Each row: date, amount, method, reference. Show "No payments yet" if empty.

**Credit notes:**
List from `creditNotes` filtered by `invoice_id`. Each row: CN number, date, amount, reason. Show "No credit notes" if empty.

**Action buttons row:**
- **Approve** (draft only) -- calls `invApproveInvoice(invoiceId)`. Stub this function for now (implemented in section 08). Hide for non-admin users (`currentUser.role !== 'admin'`).
- **Record Payment** -- calls `invOpenPaymentModal(invoiceId)`. Stub for now (section 09). Only show for issued invoices.
- **Add Credit Note** -- calls `invOpenCNModal(invoiceId)`. Stub for now (section 10). Only show for issued invoices.
- **Print / Share** -- calls `generateInvoiceA4(invoiceId)`. Stub for now (section 07). Show for issued/partial/paid invoices.
- **Add More DOs** (draft only) -- calls `invAddMoreDOs(invoiceId)`. Opens DO selection for this customer's uninvoiced DOs, adds them to the existing draft.
- **Cancel** -- calls `invCancelInvoice(invoiceId)`. Implemented in this section (see below).

### Stub Functions for Future Sections

Define these as placeholder functions that show a `notify()` message indicating they are not yet implemented:

```javascript
function invApproveInvoice(invoiceId) { /* Section 08 */ }
function invOpenPaymentModal(invoiceId) { /* Section 09 */ }
function invOpenCNModal(invoiceId) { /* Section 10 */ }
function generateInvoiceA4(invoiceId) { /* Section 07 */ }
```

### Add More DOs (Draft Only)

`invAddMoreDOs(invoiceId)` should:
1. Find the invoice in the `invoices` array.
2. Get the customer's uninvoiced completed DOs via `getCustomerUninvoicedDOs(inv.customer_id)`.
3. Show a modal or inline section with checkboxes for available DOs.
4. On confirm:
   - Insert new `sales_invoice_orders` junction records.
   - Update each selected DO's `invoice_id`.
   - Re-aggregate invoice items (delete old `sales_invoice_items`, re-insert with new totals).
   - Update `sales_invoices.subtotal` and `grand_total`.
   - Refresh local arrays and re-render.

### Invoice Cancellation Logic

`invCancelInvoice(invoiceId)` implements the full cancellation cascade:

1. **Pre-check**: Look up payments in `invoicePayments` for this invoice. If any exist, show `notify('Cannot cancel invoice with recorded payments', 'error')` and return.

2. **Confirmation**: Use `confirmAction('Cancel Invoice', 'This will unlink all DOs and cancel this invoice. Continue?')`.

3. **On confirm**, execute in sequence:
   a. Get all linked order IDs from `invoiceOrders` where `invoice_id` matches.
   b. For each linked order, update `sales_orders` to set `invoice_id = null` (use `sbMutate()`).
   c. Delete any `sales_credit_notes` for this invoice (in draft scenario where CNs might exist).
   d. The `sales_invoice_items` and `sales_invoice_orders` records are cleaned up by CASCADE on the invoice, but since we soft-delete (set status to cancelled), explicitly delete junction records:
      - Delete from `sales_invoice_orders` where `invoice_id` matches.
      - Delete from `sales_invoice_items` where `invoice_id` matches.
   e. Update the invoice: set `status = 'cancelled'`.
   f. Refresh local arrays (remove items/orders/CNs from local arrays, update invoice status in local array).
   g. Re-render the invoicing tab.

### Rendering the Invoice List (Helper Function)

Extract the list rendering into a separate function `invRenderList()` that can be called independently from `renderInvoicing()`. This allows filter changes to re-render just the list without rebuilding the entire tab (preserving Create Invoice section state and selections).

```javascript
function invRenderList() {
  // 1. Apply filters to invoices array
  // 2. Calculate summary card values
  // 3. Render summary cards HTML
  // 4. Render filtered invoice cards HTML
  // 5. Set innerHTML of list container element
}
```

The `renderInvoicing()` function should render the Create Invoice section (section 05) and an empty container div for the list, then call `invRenderList()` to populate it.

### Display Helpers

Use the existing `formatRM()` function for currency formatting and `fmtDateNice()` for date display. Use `esc()` for all user-supplied text to prevent XSS.

The `getDisplayStatus(inv)` helper should return the display-friendly status, accounting for the overdue computed state:
- If `isInvoiceOverdue(inv)` returns true, return `'overdue'`
- Otherwise return `inv.status` or `inv.payment_status` as appropriate (e.g., show `'partial'` for issued invoices with partial payment)

### CSS

No new CSS file needed. Use inline styles consistent with existing sales module patterns (dark theme variables: `var(--bg-card)`, `var(--border)`, `var(--text)`, `var(--text-muted)`, `var(--green)`, `var(--gold)`, `var(--danger)`, `var(--info)`). Status badge styles should match the existing order status badge patterns in the Orders tab.

---

## Key Files

- **`sales.html`** -- All changes go here. Modify `renderInvoicing()` to add the invoice list section. Add new functions: `invRenderList()`, `invCancelInvoice()`, `invAddMoreDOs()`, `getDisplayStatus()`, and stub functions for sections 07-10.

## Edge Cases

- **No invoices yet**: Show empty state in list, summary cards show RM 0.00 / 0 counts.
- **All invoices filtered out**: Show "No invoices match filters" message.
- **Cancelled invoices**: Show in the list (with dim styling) but only when "All" status filter is selected or a dedicated "Cancelled" filter option. They should not appear in Outstanding/Overdue/This Month summaries.
- **Concurrent modification**: When cancelling, use `sbUpdateWithLock()` on the invoice record to prevent race conditions with another user approving the same invoice simultaneously.
- **Large number of invoices**: The list renders all matching invoices. For now, no pagination is needed (farm operation will have low invoice volume). If needed later, add a "Show More" button.

---

## Implementation Summary (Completed)

349 insertions, 5 deletions in `sales.html`.

### Functions Added
- `invRenderList()` — full invoice list with filter bar, 3 summary cards, invoice cards with expand/collapse
- `invToggleInvoice(id)` — toggle detail expansion
- `invGetDisplayStatus(inv)` — computed status (overdue overrides issued/partial)
- `invStatusBadge(status)` — colored inline badge HTML
- `invCancelInvoice(id)` — full cascade cancel with optimistic lock + payment check
- `invAddMoreDOs(id)` — add DOs to draft with re-aggregation
- Stub functions: `invApproveInvoice`, `invOpenPaymentModal`, `invOpenCNModal`, `generateInvoiceA4`

### renderInvoicing() Modified
- Section B placeholder replaced with `<div id="inv-list-container">` + call to `invRenderList()`

### Code Review Fixes
1. Cancellation uses `sbUpdateWithLock()` (prevents race with concurrent approve)
2. Approve button only visible for admin role

### Deviations from Plan
- Named `invGetDisplayStatus` instead of `getDisplayStatus` (prefixed for consistency)
- Filter bar uses native date inputs (consistent with invoice details section)
