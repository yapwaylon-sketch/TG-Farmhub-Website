# Section 13: Dashboard Updates

## Overview

This section updates the Sales Dashboard in `sales.html` to replace the legacy QB-related financial cards with invoice-aware metrics. The `renderDashboard()` function is modified to show Outstanding Invoices, Overdue Invoices, and Uninvoiced DOs as separate cards, and the Total Owed calculation is updated to incorporate invoice data.

**File to modify:** `sales.html`

**Dependencies:**
- Section 01 (DB migration) -- `sales_invoices` table and `sales_orders.invoice_id` column must exist
- Section 02 (data loading) -- global arrays (`invoices`, `invoiceOrders`) and helper functions (`invoiceBalance()`, `isInvoiceOverdue()`) must be available
- Section 04 (QB cleanup) -- QB references already removed; `uninvoicedDO` already checks `invoice_id` instead of `qb_invoice_no`
- Section 05 (create invoice) -- invoicing tab exists so clickable cards have a destination

---

## Tests First (Manual Verification)

### Verify: New cards present

1. Open `sales.html`, navigate to Dashboard tab.
2. Confirm the financial summary row (Row 1) now contains **6 cards**:
   - **Unpaid CS** (existing, unchanged)
   - **Outstanding Invoices** (new)
   - **Overdue Invoices** (new)
   - **Uninvoiced DOs** (updated)
   - **Total Owed** (updated calculation)
   - **Today** (existing, unchanged)

### Verify: Outstanding Invoices card

- Console: create a test invoice with `status = 'issued'`, `payment_status = 'unpaid'`, `grand_total = 500`, `credit_total = 0`, `amount_paid = 0`.
- Dashboard should show "Outstanding Invoices" = RM 500.00.
- Click the card -- should call `switchTab('invoicing')`.

### Verify: Overdue Invoices card

- Console: create a test invoice with `status = 'issued'`, `payment_status = 'unpaid'`, `due_date` in the past.
- Dashboard should show "Overdue Invoices" with a count and amount, styled red.
- If no overdue invoices exist, the card should not be red.
- Click the card -- should call `switchTab('invoicing')`.

### Verify: Uninvoiced DOs card

- Check that the Uninvoiced DOs card counts completed delivery orders where `invoice_id` is null.
- Click the card -- should call `switchTab('invoicing')`.

### Verify: Total Owed updated

- Total Owed = `unpaidCS + outstandingInvoices + uninvoicedDOAmount`.

---

## Implementation Details

### Location in Code

The function `renderDashboard()` starts at approximately line 1107 in `sales.html`. The "Row 1: Financial summary" section (starting around line 1158) is the target.

### Current State (to be replaced)

The current Row 1 has 4 cards:
1. **Unpaid CS** -- sums outstanding cash sales balances
2. **Uninvoiced DO** -- sums grand_total of DOs without `qb_invoice_no`
3. **Total Owed** -- `unpaidCS + uninvoicedDO`
4. **Today** -- count of orders today

### New Row 1 Layout

Replace with 6 cards:

#### Data Gathering Changes

After the existing `unpaidCS` calculation, add:

1. **`outstandingInvoices`** -- Sum of `invoiceBalance(inv)` for all invoices where `status === 'issued'` and `payment_status !== 'paid'`.

2. **`overdueCount` and `overdueAmount`** -- Count and sum of `invoiceBalance(inv)` for invoices where `isInvoiceOverdue(inv)` returns true.

3. **`uninvoicedDOCount` and `uninvoicedDOAmount`** -- Filter: `doc_type === 'delivery_order'` AND `!o.invoice_id` AND `o.status === 'completed'`.

4. **`totalOwed`** -- Updated formula: `unpaidCS + outstandingInvoices + uninvoicedDOAmount`

#### Card Specifications

**Card: Unpaid CS** (unchanged)
- Label: "Unpaid CS"
- Value: `formatRM(unpaidCS)`, gold color
- Click: `switchTab('payments')`

**Card: Outstanding Invoices** (new)
- Label: "Outstanding Invoices"
- Value: `formatRM(outstandingInvoices)`, blue color (`#5B9BD5`)
- Click: `switchTab('invoicing')`

**Card: Overdue Invoices** (new)
- Label: "Overdue Invoices"
- Value: Show count + amount, e.g., `overdueCount + ' (' + formatRM(overdueAmount) + ')'`
- Styling: Red if `overdueCount > 0`, otherwise muted
- Click: `switchTab('invoicing')`

**Card: Uninvoiced DOs** (updated)
- Label: "Uninvoiced DOs"
- Value: Show count + amount
- Color: blue (`#5B9BD5`)
- Click: `switchTab('invoicing')`

**Card: Total Owed** (updated calculation)
- Label: "Total Owed"
- Value: `formatRM(totalOwed)`, red color
- Border: gold highlight

**Card: Today** (unchanged)
- Label: "Today"
- Value: `ordersToday`

### No Other Dashboard Changes

Row 2 (operational cards, Active Orders table) remains unchanged.

### Invoicing Tab Navigation

Cards use `switchTab('invoicing')`. Optionally set filter state before switching:
- Outstanding Invoices click: `invFilterStatus = 'outstanding'`
- Overdue Invoices click: `invFilterStatus = 'overdue'`

---

## Summary of Changes

| What | Action |
|------|--------|
| `renderDashboard()` data gathering | Add `outstandingInvoices`, `overdueCount`, `overdueAmount` calculations |
| Uninvoiced DO calculation | Change filter to `!o.invoice_id`, `status === 'completed'` only |
| Total Owed formula | `unpaidCS + outstandingInvoices + uninvoicedDOAmount` |
| Row 1 HTML | Replace 4 cards with 6 cards |
| Card click handlers | Outstanding/Overdue/Uninvoiced navigate to Invoicing tab |

## Actual Implementation Notes

- **6 cards** in Row 1: Unpaid CS, Outstanding Invoices, Overdue Invoices, Uninvoiced DOs, Total Owed, Today
- **Total Owed** = unpaidCS + outstandingInvoices + uninvoicedDOAmount
- **Overdue** uses `isInvoiceOverdue()` — shows count + amount, red when > 0
- **Uninvoiced DOs** now tracks count + amount separately
- **Inline review** — simple change, no subagent review needed
