# Section 05: Create Invoice (Invoicing Tab)

## Overview

This section builds the invoice creation UI in the Invoicing tab of `sales.html`. It replaces the old QB-based "Mark as Invoiced" flow with a proper invoice entity creation flow. Users select a customer, pick uninvoiced completed DOs, review an aggregated billing summary, and create a draft invoice that inserts records into `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, and updates `sales_orders.invoice_id`.

**File to modify:** `sales.html`

## Dependencies

- **Section 01 (DB Migration):** Tables `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders` must exist. `sales_orders.invoice_id` column must exist. `sales_customers.payment_terms_days` column must exist and be populated.
- **Section 02 (Data Loading):** Global arrays `invoices`, `invoiceItems`, `invoiceOrders` must be loaded. Helper functions `invoiceBalance()`, `isOrderInvoiced()`, `getCustomerUninvoicedDOs()`, `calcDueDate()` must be defined.
- **Section 03 (Payment Terms):** Customer records must have `payment_terms_days` populated.
- **Section 04 (QB Cleanup):** The old QB modal, `invSaveInvoice()`, QB history section, and QB references must be removed. The invoicing tab should be stubbed with a placeholder ready for this section to replace.

## Verification Steps (Tests)

### Verify: Customer dropdown
- Open the Invoicing tab
- The customer dropdown only shows customers who have uninvoiced completed DOs (completed delivery orders where `invoice_id` is null)
- Walk-in customers (`type === 'walkin'`) are excluded from the dropdown
- Selecting a customer shows their uninvoiced completed DOs below

### Verify: DO selection
- Checkboxes appear next to each uninvoiced DO for the selected customer
- "Select All" checkbox works (checks/unchecks all DOs for the customer)
- Billing summary updates live as DOs are selected/deselected
- Billing summary aggregates products correctly: one line per unique product+price combination
- DO numbers are listed as references in the summary

### Verify: Create Draft
- Click "Create Draft Invoice" with DOs selected
- Invoice is created in the database with status `'draft'`
- Invoice number follows format `INV-YYMMDD-NNN` (generated via `dbNextId('INV')`)
- Invoice appears in the Invoice List section (built in Section 06) with "Draft" badge
- All selected DOs now have `invoice_id` set (not null) in `sales_orders`
- Those DOs no longer appear in the "uninvoiced" list when re-rendering
- `sales_invoice_items` records are created (one per aggregated product+price)
- `sales_invoice_orders` junction records are created (one per selected DO)

### Verify: Double-invoicing prevention
- After invoicing some DOs, they should not appear in the uninvoiced list
- The UNIQUE constraint on `sales_invoice_orders.order_id` prevents the same DO from appearing in two invoices
- SQL validation: `SELECT order_id, count(*) FROM sales_invoice_orders GROUP BY order_id HAVING count(*) > 1` should return 0 rows

### Verify: Edge cases
- If a customer has no uninvoiced DOs, they do not appear in the dropdown
- If all DOs for the only eligible customer are invoiced, the section shows an empty state
- Invoice date defaults to today
- Payment terms default from the selected customer's `payment_terms_days`
- Due date is calculated as `invoice_date + payment_terms_days`

## Implementation Details

### 1. Rewrite `renderInvoicing()` — Section A: Create Invoice

The existing `renderInvoicing()` function (around line 3964 of `sales.html`) renders the Invoicing tab. After QB cleanup (Section 04), this function should be stubbed. This section replaces the stub with the new Create Invoice UI.

The layout of Section A ("Create Invoice") within `renderInvoicing()` should be:

1. **Customer dropdown** (searchable) — shows only customers with uninvoiced completed DOs, excluding walk-in type customers
2. **On customer select:** show a list of their uninvoiced completed DOs with checkboxes
3. **Each DO row:** checkbox, doc number, date, item count, total amount
4. **"Select All" checkbox** for the selected customer
5. **Below DOs:** live billing summary (aggregated products from selected DOs)
6. **Invoice date input** (date picker, default today)
7. **Payment terms dropdown** (populated from customer's `payment_terms_days`, options: COD/0, Net 7/7, Net 14/14, Net 30/30, Net 60/60)
8. **Notes textarea** (optional)
9. **"Create Draft Invoice" button** (disabled until at least one DO is selected)

Section B (Invoice List) is built in Section 06 and should be rendered below Section A.

### 2. Customer Dropdown Filtering Logic

Build the customer dropdown by filtering the global `customers` array:

```
// Pseudocode for eligible customers
customers who meet ALL of:
  - type !== 'walkin'
  - have at least one completed DO where invoice_id is null
    (i.e., getCustomerUninvoicedDOs(customer.id).length > 0)
```

The function `getCustomerUninvoicedDOs(customerId)` (from Section 02) returns completed DOs for the customer where `invoice_id` is null and `doc_type === 'delivery_order'`.

When the customer dropdown value changes, render the DO list for that customer. Clear any previous DO selections.

### 3. Reuse Existing Patterns

The existing code has several reusable patterns and functions that should be adapted rather than rewritten:

- **`invSelectedDOs`** — keep this global object for tracking selected DO IDs (`{orderId: true}`)
- **`invToggleDO(orderId, custId, checked)`** — keep for individual DO checkbox toggling
- **`invSelectAllCustomer(custId, checked)`** — keep for select-all behavior
- **`invUpdateButtons()`** — adapt to update the "Create Draft Invoice" button text/state instead of "Mark as Invoiced"
- **`invRenderBillingSummary()`** — keep mostly as-is for live product aggregation preview. It already aggregates by product and shows a table with quantities, prices, and amounts.
- **`invBuildSummaryText()`** — keep for clipboard copy
- **`invCopySummary()`** and **`invPrintSummary()`** — keep for Copy/Print buttons on the billing summary

The main change is replacing `invOpenInvoiceModal()` and `invSaveInvoice()` with the new draft invoice creation flow.

### 4. Product Aggregation Logic

When multiple DOs have the same product at different prices (e.g., price changed mid-month), create **one line per unique product+price combination**. This preserves pricing accuracy.

The existing `invRenderBillingSummary()` groups by `product_id` only and computes an average price. Change the grouping key to `product_id + '_' + unit_price` so that different prices create separate invoice item lines.

```
// Pseudocode for aggregation key
var key = item.product_id + '_' + (parseFloat(item.unit_price) || 0).toFixed(2);
```

Each unique key becomes one `sales_invoice_items` record with the exact `unit_price` from the order items, the summed `quantity`, and `line_total = quantity * unit_price`.

### 5. Create Draft Invoice — DB Insert Flow

The "Create Draft Invoice" button triggers an async function (e.g., `invCreateDraftInvoice()`) that performs these steps in order:

1. **Validate:** At least one DO must be selected. Invoice date must be set.

2. **Generate IDs:**
   - Invoice ID: `await dbNextId('INV')` — produces format `INV-YYMMDD-NNN`
   - Invoice item IDs: `await dbNextId('II')` for each aggregated product line

3. **Calculate fields:**
   - `due_date` = `calcDueDate(invoiceDate, paymentTermsDays)` (invoice date + days)
   - `subtotal` = sum of all aggregated line totals
   - `grand_total` = `subtotal` (no SST currently)
   - Map `payment_terms_days` to a payment terms code string: 0 = `'cod'`, 7 = `'7days'`, 14 = `'14days'`, 30 = `'30days'`, 60 = `'60days'`

4. **Insert `sales_invoices`:**
   ```
   {
     id: invoiceId,
     customer_id: selectedCustomerId,
     invoice_date: invoiceDateValue,
     due_date: calculatedDueDate,
     payment_terms: paymentTermsCode,
     subtotal: subtotal,
     grand_total: grandTotal,
     credit_total: 0,
     amount_paid: 0,
     payment_status: 'unpaid',
     status: 'draft',
     notes: notesValue,
     created_by: currentUser.id
   }
   ```
   Use `sbQuery(sb.from('sales_invoices').insert({...}).select())`.

5. **Insert `sales_invoice_items`** (one per aggregated product+price):
   ```
   {
     id: itemId,
     invoice_id: invoiceId,
     product_id: productId,
     product_name: snapshotProductName,  // frozen at invoice time
     quantity: totalQty,
     unit_price: unitPrice,
     line_total: totalQty * unitPrice
   }
   ```
   Insert all items in a single batch: `sbQuery(sb.from('sales_invoice_items').insert(itemsArray).select())`.

6. **Insert `sales_invoice_orders`** (one per selected DO):
   ```
   { invoice_id: invoiceId, order_id: orderId }
   ```
   Insert all junction records in a batch.

7. **Update `sales_orders.invoice_id`** on each selected DO:
   For each selected DO, update `invoice_id = invoiceId`. Include `WHERE invoice_id IS NULL` as a guard against concurrent invoice creation (defense against race conditions).
   ```
   sbQuery(sb.from('sales_orders').update({ invoice_id: invoiceId }).eq('id', orderId).is('invoice_id', null).select())
   ```

8. **Update local arrays:**
   - Push the new invoice into `invoices` array
   - Push new items into `invoiceItems` array
   - Push new junction records into `invoiceOrders` array
   - Update `invoice_id` on the corresponding orders in the local `orders` array

9. **Clear and re-render:**
   - Reset `invSelectedDOs = {}`
   - Show success notification: `notify('Invoice ' + invoiceId + ' created', 'success')`
   - Call `renderInvoicing()` to refresh the tab

### 6. Product Name Snapshot

The `product_name` field in `sales_invoice_items` captures the product description at invoice creation time. Build the snapshot name by combining variety (if present) and product name, e.g.:

```
var prod = salesProducts.find(p => p.id === productId);
var variety = soGetProductVariety(productId);
var snapshot = '';
if (variety && variety !== '\u2014') snapshot += variety + ' ';
snapshot += prod ? prod.name : 'Unknown';
// optionally append packing info: (Box, 8pcs) etc.
```

The function `soGetProductVariety(productId)` already exists in the codebase and returns the variety name for a product.

### 7. Payment Terms Dropdown

Render a `<select>` element with these options:

| Label | Value (days) |
|-------|-------------|
| COD | 0 |
| Net 7 | 7 |
| Net 14 | 14 |
| Net 30 | 30 |
| Net 60 | 60 |

When a customer is selected, auto-set the dropdown to the customer's `payment_terms_days` value. The user can override it per-invoice.

### 8. Invoice Date and Due Date

- Invoice date: `<input type="date">` (or use the custom `calOpen()` picker if consistent with the rest of the sales module), default to `todayStr()`
- Due date is not a separate input field — it is calculated automatically from `invoice_date + payment_terms_days` and shown as a read-only display below the inputs
- The `calcDueDate(invoiceDate, days)` helper (from Section 02) handles this calculation

### 9. HTML Structure

The invoice creation section should be rendered inside `renderInvoicing()`. The overall structure within the `page-invoicing` page body:

```
Section A: Create Invoice
  - Title: "Create Invoice"
  - Subtitle: "Select a customer and their uninvoiced DOs to create an invoice"
  - Customer dropdown (with search/filter if many customers)
  - DO list area (populated on customer select)
  - Invoice details area (date, terms, notes — shown after DOs selected)
  - Billing summary area (live-updating)
  - Create Draft Invoice button

Section B: Invoice List (placeholder for Section 06)
```

No separate modal is needed for invoice creation — it is inline in the Invoicing tab. The old QB modal (`#inv-modal`) should have been removed in Section 04.

### 10. Button Loading State

Use the existing `btnLoading(btn, true)` / `btnLoading(btn, false, 'Create Draft Invoice')` pattern on the create button during the async insert operation to prevent double-clicks and show progress.

### 11. Error Handling

Wrap the entire creation flow in try/catch. On any `sbQuery` returning null (which indicates an error already notified by `sbQuery`), stop the flow and restore the button state. If a partial failure occurs (e.g., invoice inserted but items fail), the user will need to manually clean up via cancellation (Section 06). The CASCADE delete on `sales_invoice_items` and `sales_invoice_orders` means cancelling the invoice cleans up everything.

---

## Implementation Summary (Completed)

180 insertions, 21 deletions in `sales.html`.

### Functions Added
- `invCreateDraftInvoice()` — full async DB insert flow (invoice → items → junction → update orders → local arrays)
- `invUpdateDueDate()` — recalculates due date display when date or terms change

### Functions Modified
- `renderInvoicing()` — Section A now shows invoice details form (date, terms, notes, due date) when DOs selected; button wired to invCreateDraftInvoice
- `invUpdateButtons()` — also shows/hides inv-details section
- `invRenderBillingSummary()` — groups by product_id + unit_price (not just product_id)
- `invBuildSummaryText()` — same grouping change, uses unitPrice directly instead of avgPrice
- `invPrintSummary()` — same grouping change

### Code Review Fixes
- Added `onchange="invUpdateDueDate()"` to invoice date input (was missing)

### Deviations from Plan
- None significant. All planned features implemented as specified.
