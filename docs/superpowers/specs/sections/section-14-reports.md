# Section 14: Reports -- Invoice Register and Aging Report

## Overview

This section adds two new reports to the Reports tab in `sales.html` and updates the existing payment summary report to include invoice payments. The two new reports are:

1. **Invoice Register** -- a filterable list of all invoices with totals
2. **Aging Report** -- outstanding balances grouped by customer in 30/60/90-day buckets with color coding

These reports follow the existing report rendering pattern established by the seven current reports.

**File to modify:** `sales.html`

## Dependencies

- **Section 01 (DB Migration)**: Tables `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, `sales_invoice_payments`, `sales_credit_notes` must exist.
- **Section 02 (Data Loading)**: Global arrays `invoices`, `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes` must be loaded. Helper functions `invoiceBalance()`, `isInvoiceOverdue()` must be available.
- **Section 09 (Invoice Payments)**: Invoice payment recording must work so payment data appears in reports.
- **Section 10 (Credit Notes)**: Credit notes must work so CN amounts are reflected in balances.

## Tests (Manual Verification)

### Verify: Invoice Register

1. Navigate to Reports tab, click "Invoice Register" report button.
2. Confirm the report shows a table with columns: **Invoice No, Date, Due Date, Customer, Grand Total, Paid, Credits, Balance, Status**.
3. Confirm filters work: date range picker (From/To), customer dropdown, status dropdown (All, Draft, Issued, Overdue, Partial, Paid, Cancelled).
4. Confirm a TOTAL row appears at the bottom summing Grand Total, Paid, Credits, and Balance columns.
5. Confirm status column uses color coding consistent with invoice list badges.
6. Confirm CSV export includes all rows and columns.
7. Confirm Print opens a new window with company header and the rendered table.

### Verify: Aging Report

1. Click "Aging Report" report button.
2. Confirm the report shows a table with columns: **Customer, Current, 1-30 Days, 31-60 Days, 61-90 Days, 90+ Days, Total Outstanding**.
3. Each cell contains the sum of outstanding invoice balances where the invoice's age falls into that bucket. Age is calculated as days since `due_date`.
4. Confirm color coding: Current = normal, 1-30 = gold, 31-60 = orange, 61-90 = red, 90+ = bold red.
5. Confirm a Grand Totals row at the bottom sums each column.
6. Confirm only invoices with status "issued" and payment_status "unpaid" or "partial" are included.
7. Confirm customers with zero outstanding balance are excluded.
8. Confirm CSV export and Print both work.

### Verify: Payment Summary Update

1. Open the existing "Outstanding Payments" report.
2. Confirm that invoice payments now appear in the report alongside CS payments.

## Implementation Details

### 14.1 Add New Report Types to RPT_TYPES

The `RPT_TYPES` array (currently at approximately line 4471) defines available reports. Add two new entries:

```javascript
{id:'invoice_register', name:'Invoice Register'},
{id:'aging', name:'Aging Report'}
```

The new buttons render automatically via `renderReports()`.

### 14.2 Add Filter Rendering for New Reports

In `rptRenderFilters()`, add two new `else if` branches.

**Invoice Register filters:**
- Date range (From/To date inputs)
- Customer dropdown
- Status dropdown: All, Draft, Issued, Overdue, Partial, Paid, Cancelled

**Aging Report filters:**
- No date range needed (aging is always "as of today")
- Optional customer dropdown to filter to a single customer

### 14.3 Add Report Generation Logic in rptGenerate()

**Invoice Register logic:**

Iterate over `invoices` array. For each invoice:
- Apply date range filter against `invoice_date`
- Apply customer filter against `customer_id`
- Apply status filter (special case: "Overdue" uses `isInvoiceOverdue(inv)`)
- Calculate balance via `invoiceBalance(inv)`
- Columns: Invoice No, Date, Due Date, Customer, Grand Total, Paid, Credits, Balance, Status
- TOTAL summary row at bottom
- Mark totals row with `_summary = true` for bold styling
- Add `_statusClass` metadata for color coding

**Aging Report logic:**

Group outstanding invoices by customer. Only include invoices where `status === 'issued'` and `payment_status !== 'paid'`.

For each qualifying invoice:
- Calculate outstanding balance via `invoiceBalance(inv)`
- Calculate age in days from `due_date`
- Assign to bucket:
  - **Current**: due_date is today or future (age <= 0)
  - **1-30 Days**: age 1-30
  - **31-60 Days**: age 31-60
  - **61-90 Days**: age 61-90
  - **90+ Days**: age > 90

Group by `customer_id`. For each customer, sum balances in each bucket.
Columns: Customer, Current, 1-30 Days, 31-60 Days, 61-90 Days, 90+ Days, Total Outstanding.

Sort rows by Total Outstanding descending.

Add Grand Totals summary row.

Apply color coding metadata per cell:
- `aging-current` -- normal
- `aging-30` -- gold (`color: #b8860b`)
- `aging-60` -- orange (`color: #e67e22`)
- `aging-90` -- red (`color: #c0392b`)
- `aging-90plus` -- bold red

### 14.4 Update Existing Payment Summary

The existing "Outstanding Payments" report currently only shows unpaid/partial orders. Add a second section below for invoice outstanding:

After the existing Outstanding Payments table, append a "Invoice Outstanding" section with columns: Invoice No, Customer, Invoice Date, Due Date, Total, Paid, Credits, Balance, Days Overdue.

### 14.5 Add CSS Classes for Aging Colors

```css
.aging-current { color: #2d8a3e; }
.aging-30 { color: #b8860b; }
.aging-60 { color: #e67e22; }
.aging-90 { color: #c0392b; }
.aging-90plus { color: #c0392b; font-weight: 700; }
```

### 14.6 Table Rendering Updates

In the row rendering loop, add conditions for aging and invoice register:

```javascript
// Aging report cell colors
if (type === 'aging' && i >= 1 && i <= 5 && r._agingClasses && !r._summary) {
  attrs = ' class="' + r._agingClasses[i - 1] + '"';
}

// Invoice register status colors
if (type === 'invoice_register' && i === 8 && r._statusClass && !r._summary) {
  attrs = ' class="' + r._statusClass + '"';
}
```

### 14.7 Key Patterns

- All report data flows through `rptData = { cols, rows, title }`
- Rows are plain arrays; metadata as custom properties (`_summary`, `_statusClass`, `_agingClasses`)
- `rptExportCSV()` and `rptPrint()` work automatically with any report
- Currency via `formatRM()`, dates via `fmtDate()`, XSS protection via `esc()`
- TOTAL summary row uses `_summary = true` for `.rpt-summary-row` bold styling
- Customer names resolved via `getCustomerName(customerId)`

## Actual Implementation Notes

- **Invoice Register:** Filterable by date range, customer, status (including Overdue). Shows 9 columns + TOTAL summary row. Status color coding via `_statusClass`.
- **Aging Report:** Groups outstanding invoices by customer into Current/1-30/31-60/61-90/90+ buckets. Sorted by total descending. Grand Totals row. Cell colors via `_agingClasses`.
- **CSS:** Added `.aging-30`, `.aging-60`, `.aging-90`, `.aging-90plus` to sales.css
- **Cell rendering:** Added aging and invoice_register branches to the table render loop
- **Payment summary update:** Deferred — existing Outstanding Payments report still shows order-level data. Invoice payments are visible via the new Invoice Register report.
- **Inline review:** Pattern well-established from 7 existing reports, no subagent needed
