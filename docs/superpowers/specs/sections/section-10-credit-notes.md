# Section 10: Credit Note System

## Overview

This section implements the Credit Note (CN) system for the sales invoicing module. Credit notes are invoice-level credits that reduce an invoice's outstanding balance. They can be linked to existing returns (from the order-level returns system) or created as standalone manual adjustments. The section includes the CN creation modal, validation, balance recalculation, and A4 document generation with print and PNG export.

**File to modify:** `sales.html`

## Dependencies

- **Section 01 (DB Migration):** The `sales_credit_notes` table must exist with columns: `id` (TEXT PK, `CN-YYMMDD-NNN`), `invoice_id` (TEXT FK), `return_id` (TEXT FK nullable), `credit_date` (DATE), `amount` (NUMERIC), `reason` (TEXT), `lhdn_uuid` (TEXT), `created_by` (TEXT), `created_at` (TIMESTAMPTZ).
- **Section 02 (Data Loading):** Global arrays `creditNotes`, `invoices`, `invoiceOrders` and helper functions `invoiceBalance(inv)`, `recalcInvoicePaymentStatus(invoiceId)` must exist.
- **Section 06 (Invoice List):** The invoice detail expansion view must be rendered, including the "Add Credit Note" action button that triggers the CN modal.

## Background: CN vs DN Relationship

The existing returns system has **Debit Notes (DN)** which are order-level. A return with resolution `debit_note` gets a `DN-YYMMDD-NNN` number stored on `sales_returns.debit_note_no`. DNs can be applied to future orders via `debit_note_used_on`.

The new **Credit Notes (CN)** are invoice-level. They reduce an invoice's outstanding balance. The two systems coexist:

- **DN** = order-level credit (existing, unchanged). Customer gets credit applicable to future orders.
- **CN** = invoice-level credit (new). Reduces what the customer owes on a specific invoice.

When a return with resolution `debit_note` exists for a DO that is part of an invoice, a CN can be created that links to that return via `return_id`. This connects the order-level return to the invoice-level credit. DNs that were already applied to orders (`debit_note_used_on` is set) are historical and need no migration.

## Tests (Manual Verification)

### Verify: CN from return
1. Create a return (with debit_note resolution) on an order that belongs to an invoice
2. Open invoice detail, click "Add Credit Note"
3. Select the return from the dropdown -- amount should auto-fill from the return amount
4. Save the CN
5. Verify `return_id` is populated on the `sales_credit_notes` record:
```sql
SELECT id, invoice_id, return_id, amount, reason FROM sales_credit_notes WHERE return_id IS NOT NULL;
```

### Verify: CN standalone
1. Open invoice detail, click "Add Credit Note"
2. Select "None -- manual adjustment" for linked return
3. Enter amount and reason manually
4. Save -- verify `return_id` is null on the record

### Verify: CN validation
1. Open an invoice with outstanding balance of RM 100
2. Try to create CN with amount RM 150 -- should be prevented with error notification
3. Try to create CN with no reason -- should be prevented

### Verify: Balance recalculation
1. After saving a CN, check the invoice in the local `invoices` array:
   - `credit_total` should equal the sum of all CNs for that invoice
   - `payment_status` should be recalculated (e.g., if credits cover full balance, status becomes 'paid')
2. Database verification:
```sql
SELECT i.id, i.grand_total, i.credit_total, i.amount_paid, i.payment_status
FROM sales_invoices i
WHERE i.id = '<invoice_id>';

SELECT id, amount FROM sales_credit_notes WHERE invoice_id = '<invoice_id>';
```

### Verify: CN document
1. After creating a CN, click the print/view option for the CN
2. A4 print preview should show:
   - Title "CREDIT NOTE" (large, prominent)
   - CN number (e.g., CN-260403-001)
   - Credit date
   - Original invoice reference (invoice number)
   - Reason for credit
   - Amount being credited
   - Company letterhead (logo, name, reg no, TIN, address)
   - Signature block
3. PNG export via html2canvas should produce a shareable image

### Verify: CN appears in invoice detail
1. After creating a CN, expand the invoice detail in the Invoice List
2. The credit notes section should list all CNs with: CN number, date, amount, reason
3. The invoice totals should reflect the credit deduction

## Implementation Details

### 10.1 Credit Note Modal

Add a modal triggered by the "Add Credit Note" button in the invoice detail view. The button should only appear on invoices with status `issued` (not draft or cancelled).

**Modal fields:**
- Invoice reference (auto-filled, read-only) -- show invoice number and customer name
- Linked return dropdown -- populate with returns for orders in this invoice. Each option shows: return ID, item name, amount, reason. Include a "None -- manual adjustment" option at the top.
- Credit date (date input, default today)
- Amount (numeric input). If linked to a return, auto-fill from `return.amount` and make read-only. If manual, allow free entry.
- Reason (text input, required). If linked to return, pre-fill with "Return: " + return reason.

**How to find returns for an invoice:** Use `invoiceOrders` to get order IDs linked to the invoice, then filter the global `returns` array for those order IDs. Only show returns that are not already linked to a CN (check `creditNotes` array for existing `return_id` matches).

**Modal function signature:**

```javascript
function cnOpenModal(invoiceId) {
  // Find invoice from invoices array
  // Get linked order IDs from invoiceOrders
  // Get eligible returns (not already linked to a CN)
  // Build and show modal
}
```

### 10.2 Validation

Before saving, validate:

1. `amount > 0`
2. `amount <= invoiceBalance(inv)` -- CN amount must not exceed outstanding balance (grand_total - credit_total - amount_paid). Show error notification if exceeded.
3. `reason` is not empty
4. `credit_date` is set

### 10.3 Save Flow

On save:

1. Generate CN ID via `dbNextId('CN')`
2. Build record object with: `id`, `invoice_id`, `return_id` (or null), `credit_date`, `amount`, `reason`, `created_by` (from `currentUser.id`)
3. Insert into `sales_credit_notes` with `.select()`
4. Update local `creditNotes` array (unshift the new record)
5. Sum all CNs for this invoice and update `sales_invoices.credit_total`:
   ```javascript
   var totalCredits = creditNotes
     .filter(function(cn) { return cn.invoice_id === invoiceId; })
     .reduce(function(sum, cn) { return sum + (parseFloat(cn.amount) || 0); }, 0);
   ```
6. Update the invoice record in DB: set `credit_total = totalCredits`
7. Call `recalcInvoicePaymentStatus(invoiceId)` to recalculate payment status
8. Show success notification
9. Close modal and re-render the invoice detail/list

```javascript
async function cnSave(invoiceId) {
  // Gather form values
  // Validate
  // btnLoading on save button
  // dbNextId('CN'), insert, update invoice credit_total, recalc status
  // Update local arrays, re-render, notify
}
```

### 10.4 Credit Note A4 Document

Create a function `generateCreditNoteA4(cnId)` following the same pattern as `soGenerateDocA4()` and `generateInvoiceA4()` from section-07.

**Document structure:**

**Header block:**
- Company logo (`assets/logo.png?v=2`)
- "TG AGRO FRUITS SDN. BHD." (bold, large)
- Reg No: 1110222-T | TIN: 24302625000 | MSIC: 46909
- Address: Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak

**Title:** "CREDIT NOTE" (large, prominent, centered)

**Info grid:**
- CN Number: CN-YYMMDD-NNN
- Credit Date
- Original Invoice: INV-YYMMDD-NNN (reference)
- Customer Name

**Body:**
- Reason for credit (displayed prominently)
- If linked to a return: show return reference and original order reference
- Amount: RM X,XXX.XX (large, bold)

**Signature block:**
- Left: "Prepared By" with name auto-filled from `currentUser`
- Right: "Authorized By" with blank signature line

**Footer:** "This credit note reduces the amount due on the referenced invoice."

**Print and share:** Use `window.print()` with `@page { size: A4; margin: 10mm; }` and `html2canvas` for PNG export. Share filename: `CN-YYMMDD-NNN.png`.

### 10.5 Integration Points

**Invoice detail view (from section-06):** The "Add Credit Note" button calls `cnOpenModal(invoiceId)`. The credit notes list within the detail renders all CNs for the invoice, each showing: CN number, date, amount, reason, and a Print/Share button that calls `generateCreditNoteA4(cnId)`.

**Invoice totals display:** Wherever invoice totals are shown (detail view, invoice document, statement), the credit_total appears as a deduction line:
```
Grand Total:    RM 5,000.00
Credit Notes:  -RM   500.00
Amount Paid:   -RM 2,000.00
Balance Due:    RM 2,500.00
```

**Existing returns flow:** No changes needed to the existing return creation flow. The linkage happens only when creating a CN and selecting a return from the dropdown.

### 10.6 Styling

Use existing sales.html modal and badge patterns. CN-specific additions:
- CN rows in the invoice detail should show the CN number as a clickable link that triggers the A4 document view
- Amount should be formatted with the existing currency formatter

## Actual Implementation Notes

- **Modal HTML:** Added `cn-modal` with linked return dropdown, date, amount, reason fields
- **Functions added:** `invOpenCNModal()`, `cnReturnChanged()`, `cnSave()`, `generateCreditNoteA4()`
- **Credit notes in detail view:** CN numbers are clickable golden links that open A4 document, date field fixed from `cn_date` to `credit_date`
- **Code review fix:** Added CN-specific branch in `soOpenWhatsAppDoc()` — detects CN- prefix to build appropriate WhatsApp message instead of failing to find invoice
- **CN A4 document:** Uses `soDocCurrentInvoiceId = cnId` so share/download filename uses CN number
- **Deviations:** None significant — all spec requirements met
