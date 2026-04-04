# Section 11: Payments Tab Split View

## Overview

This section modifies `renderPayments()` in `sales.html` to display two distinct sections: the existing Cash Sales Payments section and a new Invoice Payments section. The DO section currently showing "paid via QB Invoice" references is replaced with a proper invoice payments view grouped by customer, with aging colors, filters, summary cards, and a Record Payment button per invoice.

**File to modify:** `sales.html`

## Dependencies

- **Section 01 (DB Migration):** `sales_invoices`, `sales_invoice_payments`, `sales_credit_notes` tables must exist.
- **Section 02 (Data Loading):** Global arrays `invoices`, `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes` must be loaded. Helper functions `invoiceBalance()`, `isInvoiceOverdue()`, `calcDueDate()` must exist.
- **Section 04 (QB Cleanup):** QB references removed from the DO section of payments tab.
- **Section 09 (Invoice Payments):** The `invOpenPaymentModal()` function for recording payments against invoices must exist.
- **Section 10 (Credit Notes):** Credit note data loaded and `credit_total` reflected in invoice balance calculations.

## Tests (Manual Verification)

### Verify: Two sections visible
- Open Payments tab in sales.html.
- Confirm a "Cash Sales Payments" section heading is visible at the top, showing CS orders grouped by customer (existing behavior, unchanged).
- Confirm an "Invoice Payments" section heading appears below the CS section, showing issued invoices.

### Verify: Invoice payments section content
- Invoices are grouped by customer name.
- Each customer group is expandable (click to toggle).
- Each invoice row shows: invoice number, invoice date, due date, total, paid, balance, payment status badge.
- Aging colors are applied correctly based on days past due date:
  - Current (not overdue) = green
  - 1-30 days overdue = gold
  - 31-60 days overdue = orange
  - 60+ days overdue = red
- A "Record Payment" button appears on each invoice with outstanding balance.
- Clicking "Record Payment" opens the invoice payment modal (from Section 09).

### Verify: Invoice payments filters
- A filter bar above the Invoice Payments section includes:
  - Customer dropdown (all customers with invoices)
  - Status dropdown: Outstanding, Overdue, All
  - Date range (from/to) filters on invoice date
- Filters correctly narrow the displayed invoices.

### Verify: Invoice payments summary cards
- Summary cards above the invoice list show:
  - "Total Outstanding" (sum of `invoiceBalance()` for all issued invoices with unpaid/partial status)
  - "Overdue Amount" (sum of `invoiceBalance()` for overdue invoices, red if > 0)
  - "Payments This Month" (sum of `invoicePayments` with `payment_date` in current month)

### Verify: DO section removed from CS grouping
- The old "Delivery Orders (paid via QB Invoice)" sub-section within each customer group is gone.
- DOs no longer appear in the Payments tab at all (they are handled via Invoicing tab).

### Verify: Payment history in invoice detail
- Expanding an invoice shows payment history rows below it (date, method, reference, amount).
- Credit notes applied to the invoice are also shown.

## Implementation Details

### 1. Restructure `renderPayments()`

The current `renderPayments()` function renders a single combined view of CS and DO orders grouped by customer. This needs to be split into two independent sections.

**Approach:** Keep the existing CS logic mostly intact but remove DO orders from it entirely. Then append a new Invoice Payments section below.

The function body should be restructured as follows:

```
function renderPayments() {
  var body = document.getElementById('page-payments').querySelector('.page-body');
  var html = '';

  // === SECTION 1: Cash Sales Payments ===
  html += renderPaymentsCS();

  // === SECTION 2: Invoice Payments ===
  html += renderPaymentsInvoice();

  body.innerHTML = html;
}
```

Extract the existing CS logic into `renderPaymentsCS()` and create a new `renderPaymentsInvoice()` function.

### 2. `renderPaymentsCS()` -- Refactor Existing CS Section

Extract the current CS rendering logic with these changes:

- **Remove the doc type filter dropdown** (no longer needed since DOs are separate).
- **Remove the DO grouping** entirely -- filter `orders` to only `doc_type === 'cash_sales'` and `status === 'completed'`.
- **Remove the "Delivery Orders" sub-section** within each customer group.
- **Remove the "Go to Invoicing" button** from within customer rows.
- **Keep** existing date range, status (outstanding/unpaid/partial/all), and sort filters.
- **Keep** existing summary cards (CS Outstanding, Customers Owing, etc.) but remove the "Delivery Orders" count card.
- **Keep** existing expandable customer rows, CS order table with checkboxes, payment history rows, batch pay functionality.
- Add a section heading: `<h3>` styled element reading "Cash Sales Payments" with a subtle divider.

### 3. `renderPaymentsInvoice()` -- New Invoice Payments Section

This is the new section that displays invoice payment tracking.

**Section heading:** An `<h3>` styled heading reading "Invoice Payments" with a divider line above it.

**Filter bar:** A row of filter controls:
- **Customer dropdown:** Populated from customers who have at least one issued invoice. Default "All Customers".
- **Status dropdown:** Options are "Outstanding" (default, shows unpaid + partial), "Overdue" (only invoices where `isInvoiceOverdue()` is true), "All" (includes paid).
- **Date range:** FROM and TO date inputs filtering on `invoice_date`.

Store filter state in module-level variables:
```
var invPayFilterCustomer = '';
var invPayFilterStatus = 'outstanding';
var invPayFilterFrom = '';
var invPayFilterTo = '';
```

**Filtering logic:**
1. Start with `invoices` array.
2. Only include invoices with `status === 'issued'` (drafts and cancelled are excluded unless "All" status is selected, in which case include all non-cancelled).
3. Apply customer filter if set.
4. Apply status filter: "outstanding" = `payment_status !== 'paid'`, "overdue" = `isInvoiceOverdue(inv)`, "all" = no filter.
5. Apply date range filter on `invoice_date`.

**Summary cards:** Three cards in a `cards-grid`:
- **Total Outstanding:** Sum of `invoiceBalance(inv)` for all filtered invoices with `payment_status !== 'paid'`. Color: `var(--gold)`.
- **Overdue Amount:** Sum of `invoiceBalance(inv)` for filtered invoices where `isInvoiceOverdue(inv)` is true. Color: `var(--red)` if > 0, else `var(--green-light)`.
- **Payments This Month:** Sum of `amount` from `invoicePayments` where `payment_date` falls in the current month. Color: `var(--green-light)`.

**Grouping by customer:**

Group filtered invoices by `customer_id`. For each customer group, calculate:
- `totalOwed`: Sum of `invoiceBalance(inv)` for outstanding invoices.
- `totalPaid`: Sum of `amount_paid` across all invoices.
- `oldestOverdueDays`: Maximum days past `due_date` among overdue invoices.
- `invoiceCount`: Number of invoices in this group.

Sort customer groups by `totalOwed` descending (biggest debtors first).

**Customer row rendering:**

Each customer gets an expandable card (same pattern as existing CS section):
- **Header:** Customer name (left, bold), total outstanding amount (right, gold if > 0, green if 0), invoice count, oldest overdue days with aging color, expand chevron.
- **Left border color** based on aging: no border if current, gold border if 1-30d overdue, orange if 31-60d, red if 60d+.

**Expanded detail -- Invoice table:**

Within the expanded section, render a table with columns:
| Invoice # | Date | Due Date | Age | Total | Paid | Credits | Balance | Status | Action |

For each invoice row:
- **Invoice #:** Styled as a link (clickable) -- clicking navigates to the invoice detail in the Invoicing tab.
- **Age:** Days since `due_date` if overdue, or days until due date if not yet due. Color-coded using the aging scale.
- **Balance:** `invoiceBalance(inv)`, bold, gold if > 0.
- **Status:** Badge with payment status (`badge-unpaid`, `badge-partial`, `badge-paid`).
- **Action:** "Record Payment" button if balance > 0, calls `invOpenPaymentModal(invoiceId)`.

**Payment history sub-rows:**

Below each invoice row, show its payment history:
- Query `invoicePayments.filter(p => p.invoice_id === inv.id)`.
- Each payment row: date, method label, reference, slip link if available, amount in green.
- Also show credit notes: query `creditNotes.filter(cn => cn.invoice_id === inv.id)`.
- Each CN row: date, "Credit Note" label, CN number, reason, amount in green.

### 4. Aging Color Helper

Create a helper function for consistent aging colors:

```
function invoiceAgingColor(inv) {
  // Returns CSS color based on days past due_date
  // Not overdue: var(--green-light)
  // 1-30 days: var(--gold)
  // 31-60 days: #E8A020 or orange
  // 60+ days: var(--red)
}

function invoiceAgeDays(inv) {
  // Returns number of days past due_date (positive = overdue, negative = not yet due)
}
```

### 5. Navigation from Invoice Payments to Invoicing Tab

When a user clicks an invoice number in the payments view, navigate to the Invoicing tab:
- Call `switchTab('invoicing')` to change tabs.
- Optionally set a global variable to auto-expand the target invoice.

### 6. Empty States

- If no invoices exist: "No invoices yet. Create invoices in the Invoicing tab."
- If filters yield no results: "No matching invoices."

### 7. Module-Level Variables

Add these variables near the existing `payFilter*` variables:

```
var invPayFilterCustomer = '';
var invPayFilterStatus = 'outstanding';
var invPayFilterFrom = '';
var invPayFilterTo = '';
```

## Summary of Changes

1. **Split** `renderPayments()` into a coordinator calling `renderPaymentsCS()` and `renderPaymentsInvoice()`.
2. **Refactor** existing CS logic to remove DO orders and QB references.
3. **Add** `renderPaymentsInvoice()` with customer-grouped invoice list, filters, summary cards, aging colors, payment history, and Record Payment buttons.
4. **Add** `invoiceAgingColor()` and `invoiceAgeDays()` helper functions.
5. **Add** filter state variables for invoice payments section.
6. **Add** navigation link from invoice number clicks to Invoicing tab.

## Actual Implementation Notes

- **renderPayments()** split into coordinator + `renderPaymentsCS()` + `renderPaymentsInvoice()`
- **CS section:** Removed DOC TYPE filter, DO grouping, DO summary card, "Go to Invoicing" button
- **Invoice section:** Customer-grouped with aging colors (green/gold/orange/red), 3 summary cards, payment + CN sub-rows
- **Helpers added:** `invoiceAgeDays(inv)`, `invoiceAgingColor(inv)`
- **Filter variables:** `invPayFilterCustomer`, `invPayFilterStatus`, `invPayFilterFrom`, `invPayFilterTo`
- **Code review:** `isInvoiceOverdue()` already guards against drafts and paid invoices — no fixes needed
- **`payFilterDocType` removed** — no longer needed since DO orders are handled via Invoice section
