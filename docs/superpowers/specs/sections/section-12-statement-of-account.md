# Section 12: Statement of Account

## Overview

This section replaces the existing order-based customer statement (`soGenerateStatement` / `soGenerateStatementConfirm`) with an invoice-based Statement of Account. The new statement shows invoices as debits, payments and credit notes as credits, with a running balance and aging summary. It is accessed from the customer detail page and/or the Invoicing tab.

**File to modify:** `sales.html`

**Dependencies:**
- Section 01 (DB migration) -- tables `sales_invoices`, `sales_invoice_payments`, `sales_credit_notes` must exist
- Section 02 (Data loading) -- global arrays `invoices`, `invoicePayments`, `creditNotes` loaded; helper `invoiceBalance()` available
- Section 09 (Invoice payments) -- payment recording must work so payments appear in statement
- Section 10 (Credit notes) -- credit notes must exist so they appear in statement

---

## Tests (Manual Verification)

### Verify: Statement Generation
- Navigate to a customer who has invoices. Click "Print Statement" button.
- The statement modal appears with customer name, date range fields (default: last 3 months to today), and a Generate button.
- Select a date range and click Generate.
- The A4 document renders in the document modal.

### Verify: Opening Balance
- Choose a date range that does NOT start from the beginning of the customer relationship (e.g., last 30 days only).
- The first row of the transaction table should be "Brought Forward" with the correct balance calculated from all invoices, payments, and credit notes BEFORE the `date_from`.
- If the customer has no history before `date_from`, the opening balance should be RM 0.00.

### Verify: Transaction Rows
- Invoices issued within the date range appear as debit entries (positive in Debit column).
- Payments received within the date range appear as credit entries (positive in Credit column).
- Credit notes within the date range appear as credit entries (positive in Credit column).
- Each row shows: Date, Doc No (INV-/PMT-/CN- prefix), Description, Debit, Credit, Running Balance.
- Running balance starts from the opening balance and correctly adds debits and subtracts credits.

### Verify: Aging Summary
- At the bottom of the statement, an aging table shows: Current, 1-30 Days, 31-60 Days, 61-90 Days, 90+ Days, Total.
- Aging is calculated from each invoice's `due_date` relative to today.
- Only outstanding invoices (with remaining balance > 0) are included in aging.

### Verify: Document Layout
- A4 print preview shows: company logo, "TG AGRO FRUITS SDN. BHD.", registration details, address.
- Title reads "STATEMENT OF ACCOUNT".
- Customer info section shows name, address (if available), credit terms, statement period.
- Bank details box appears at the bottom when total outstanding > 0.
- Payment reminder text is present when outstanding > 0.
- "If payment has already been made, please disregard this statement" disclaimer.
- Footer shows "Prepared By: [current user name]".

### Verify: Print and PNG Export
- Print button triggers `window.print()` with correct A4 formatting.
- Share/PNG button generates an image via `html2canvas`.
- WhatsApp sharing works (or clipboard fallback).

### Verify: Access Points
- Customer detail page has a "Print Statement" button that opens the statement modal for that customer.
- Invoicing tab has a per-customer "Statement" button (in invoice list or customer grouping).

---

## Implementation Details

### 12.1 Update Statement Modal HTML

The existing statement modal (`so-stmt-modal`) needs to be updated. The "Transaction Type" dropdown (all/outstanding/cash_sales/delivery_order/paid) should be removed since statements are now invoice-based. The modal should have:

- Hidden `stmt-customer-id` input (unchanged)
- Customer name display (unchanged)
- Date range: FROM and TO date inputs (unchanged, default last 3 months to today)
- Remove the `stmt-type` select dropdown entirely
- Generate button calls the new `soGenerateStatementConfirm()`

The modal ID remains `so-stmt-modal` so existing button references continue to work.

### 12.2 Replace `soGenerateStatement()` Function

The existing function opens the modal and sets defaults. Update it to work the same way but remove the `stmt-type` field initialization:

```javascript
function soGenerateStatement(customerId) {
  // Find customer, populate modal fields
  // Default date range: 3 months ago to today
  // Show modal
}
```

### 12.3 Replace `soGenerateStatementConfirm()` Function

This is the main implementation. The new function must:

1. **Read parameters** from the modal: `customerId`, `dateFrom`, `dateTo`.

2. **Calculate opening balance** -- sum of all transaction effects BEFORE `dateFrom`:
   - For each invoice where `invoice_date < dateFrom` and `customer_id` matches: add `grand_total` to opening balance.
   - For each invoice payment where payment date < `dateFrom` and belongs to a matching customer invoice: subtract `amount` from opening balance.
   - For each credit note where `credit_date < dateFrom` and belongs to a matching customer invoice: subtract `amount` from opening balance.

3. **Collect transactions within date range** into a single array, each with `date`, `docNo`, `description`, `debit`, `credit` fields:
   - **Invoices**: where `invoice_date` is within range and `customer_id` matches and status is not `cancelled`. Debit = `grand_total`. Description = "Invoice" or "Invoice - [notes summary]".
   - **Payments**: where `payment_date` is within range and the payment's invoice belongs to this customer. Credit = `amount`. Description = "Payment - [method]" (e.g., "Payment - Bank Transfer").
   - **Credit Notes**: where `credit_date` is within range and the CN's invoice belongs to this customer. Credit = `amount`. Description = "Credit Note - [reason]".

4. **Sort transactions** by date ascending, then by type (invoices before payments/CNs on same date).

5. **Calculate running balance** starting from opening balance. Each invoice adds to balance, each payment/CN subtracts.

6. **Calculate aging summary** from ALL outstanding invoices for this customer (not limited to date range). For each invoice with `invoiceBalance(inv) > 0`:
   - Days overdue = difference between today and `due_date`
   - Current: not yet due (days overdue <= 0)
   - 1-30 Days: 1 to 30 days past due
   - 31-60 Days: 31 to 60 days past due
   - 61-90 Days: 61 to 90 days past due
   - 90+ Days: more than 90 days past due

7. **Render A4 HTML** using the same CSS classes as existing documents.

### 12.4 A4 Document Structure

The HTML structure follows the existing pattern using classes `a4-page`, `a4-letterhead`, `a4-divider`, `a4-title`, `a4-info-grid`, `a4-items-table`, `a4-totals`, `a4-footer`.

**Letterhead** (identical to existing invoice/statement):
```
Logo + "TG AGRO FRUITS SDN. BHD."
(201401034124 / 1110222-T)
Lot 189, Kampung Riam Jaya, Airport Road,
98000 Miri, Sarawak
Tel: 012-3286661
```

**Title:** "STATEMENT OF ACCOUNT"

**Subtitle:** Statement period (e.g., "01/01/2026 to 31/03/2026")

**Customer info grid:**
- Customer name (bold)
- Address (if available, spanning columns)
- Payment terms (e.g., "Net 30")
- Date generated (today)

**Transaction table columns:**

| Date | Doc No | Description | Debit (RM) | Credit (RM) | Balance (RM) |

- First row: "Brought Forward" with opening balance in the Balance column.
- Subsequent rows: one per transaction, running balance updated.
- Final row or summary: closing balance.

**Aging summary table** (only if there is outstanding balance):

| Current | 1-30 Days | 31-60 Days | 61-90 Days | 90+ Days | Total |

Each cell shows the RM amount. Color code: Current = default, 31-60 = gold, 61-90 = orange, 90+ = red (via inline styles).

**Bank details** (only if total outstanding > 0):
```
Payment via Bank Transfer:
Public Bank Berhad
A/C: 3243036710
TG Agro Fruits Sdn Bhd
Please WhatsApp your payment slip to 012-3286661 once transferred. Thank you.
```

**Disclaimer:** "If payment has already been made, please disregard this statement."

**Prepared By:** Auto-filled from `currentUser.displayName`.

**Footer:** "TG Agro Fruits Sdn Bhd -- Thank you for your business"

### 12.5 Display in Document Modal

After generating the HTML string, display it in the existing A4 document modal (`so-doc-modal`):

```javascript
document.getElementById('so-doc-content').style.display = 'none';
document.getElementById('so-doc-a4-content').innerHTML = html;
document.getElementById('so-doc-a4-content').style.display = 'block';
document.getElementById('so-doc-modal').classList.add('a4-mode');
document.getElementById('so-doc-modal').style.display = 'flex';
```

### 12.6 Print and PNG Export

The existing A4 modal already has Print and Share buttons. No additional work needed.

### 12.7 Access Points

Two places trigger `soGenerateStatement(customerId)`:

1. **Customer detail page** -- the existing "Print Statement" button already calls `soGenerateStatement()`.
2. **Invoicing tab** -- each customer group should have a "Statement" button.

### 12.8 Edge Cases

- **Customer with no invoices:** Show "No transactions found for this period" message.
- **All invoices paid:** Aging summary shows all zeros or is hidden. Bank details hidden.
- **Opening balance is negative** (customer overpaid): Display as negative balance.
- **Cancelled invoices:** Exclude from all calculations.
- **Date range with no transactions but non-zero opening balance:** Show only the "Brought Forward" row.

---

## Summary of Changes

| Location | Change |
|----------|--------|
| `sales.html` modal HTML (`so-stmt-modal`) | Remove `stmt-type` dropdown, keep date range fields |
| `sales.html` JS `soGenerateStatement()` | Remove `stmt-type` initialization line |
| `sales.html` JS `soGenerateStatementConfirm()` | Full rewrite: invoice-based transactions, opening balance, running balance, aging summary |
| Customer detail page button | No change needed (already calls `soGenerateStatement`) |
| Invoicing tab | Ensure per-customer "Statement" button exists |

## Actual Implementation Notes

- **Modal HTML:** Removed `stmt-type` dropdown, added descriptive text
- **`soGenerateStatement()`:** Removed `stmt-type` initialization
- **`soGenerateStatementConfirm()`:** Full rewrite with opening balance, invoice/payment/CN transactions, running balance, aging summary (Current/1-30/31-60/61-90/90+), bank details, disclaimer
- **TIN/MSIC added to letterhead** (consistent with invoice A4)
- **Code review:** No fixes needed — all findings were acceptable behavior
