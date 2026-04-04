# Section 09: Invoice Payment Recording

## Overview

This section implements the invoice payment recording system. Users can record payments against issued invoices from the invoice detail view. Each payment updates the invoice's `amount_paid` and recalculates the `payment_status`. Payment history is displayed within the invoice detail expansion.

**File to modify:** `sales.html`

## Dependencies

- **Section 01 (DB Migration):** The `sales_invoice_payments` table must exist with columns: `id`, `invoice_id`, `amount`, `payment_date`, `method`, `reference`, `slip_url`, `notes`, `created_by`, `created_at`.
- **Section 02 (Data Loading):** The `invoicePayments` global array must be loaded, and helper functions `invoiceBalance()`, `recalcInvoicePaymentStatus()` must be defined.
- **Section 06 (Invoice List):** The invoice detail expansion view must exist so the "Record Payment" button and payment history section can be placed.
- **Section 08 (Approval Workflow):** Only issued invoices can receive payments (status must be `'issued'`).

---

## Tests (Manual Verification)

These are acceptance criteria to verify after implementation.

### Verify: Payment modal opens correctly

- Navigate to Invoicing tab, expand an issued invoice with outstanding balance.
- Click "Record Payment" button.
- **Check:** Modal displays with invoice reference (invoice number) and outstanding balance shown prominently.
- **Check:** Amount field is pre-filled with the outstanding balance.
- **Check:** Method dropdown shows options: Cash, Bank Transfer, Cheque.
- **Check:** Reference text input is visible and empty.
- **Check:** Bank transfer slip upload area is visible with "Attach slip" label.
- **Check:** Payment date defaults to today.

### Verify: Payment saves correctly

- Record a partial payment (e.g., RM 500 on a RM 1000 invoice).
- **Check:** Payment appears in the invoice detail's payment history list.
- **Check:** Invoice `amount_paid` is updated in the UI (e.g., shows RM 500 paid).
- **Check:** Invoice `payment_status` changes to `'partial'` and badge shows gold "Partial".
- **Check:** Outstanding balance displayed correctly (RM 500 remaining).
- **SQL validation:**
  ```sql
  SELECT id, amount, method, payment_date FROM sales_invoice_payments WHERE invoice_id = '<test_invoice_id>';
  SELECT amount_paid, payment_status FROM sales_invoices WHERE id = '<test_invoice_id>';
  ```

### Verify: Full payment marks invoice as paid

- Record remaining balance as payment on a partially paid invoice.
- **Check:** `payment_status` changes to `'paid'`, badge shows green "Paid".
- **Check:** Outstanding balance shows RM 0.00.
- **Check:** "Record Payment" button is hidden or disabled when balance is zero.

### Verify: Overpayment warning

- Enter an amount greater than the outstanding balance.
- **Check:** A warning notification appears (e.g., "Amount exceeds outstanding balance").
- **Check:** Payment is still allowed if user confirms (overpayment creates a credit situation).

### Verify: Draft invoices cannot receive payments

- Expand a draft invoice.
- **Check:** "Record Payment" button is NOT visible (only shown for issued invoices).

### Verify: Bank slip upload

- Record a payment with method "Bank Transfer" and attach a slip image.
- **Check:** Slip preview shows in modal before saving.
- **Check:** After save, payment record has `slip_url` populated.
- **Check:** Payment history entry shows a clickable "View Slip" link.

### Verify: Multiple payments on same invoice

- Record two separate payments on the same invoice.
- **Check:** Both payments appear in the payment history list, ordered by date (newest first).
- **Check:** `amount_paid` equals the sum of both payments.

---

## Implementation Details

### 9.1 Invoice Payment Modal HTML

Add a new modal to `sales.html` (near the existing `pay-modal`). The modal ID should be `inv-pay-modal` to avoid conflicts with the existing CS payment modal.

**Modal structure:**

```html
<!-- INVOICE PAYMENT MODAL -->
<div id="inv-pay-modal" class="modal-overlay" style="display:none;">
  <div class="modal-box" style="max-width:440px;" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title">Record Invoice Payment</div>
      <button class="modal-close" onclick="closeModal('inv-pay-modal')">...</button>
    </div>
    <div style="padding:0 16px 16px;">
      <!-- Invoice info display (reference + balance) -->
      <div id="inv-pay-info">...</div>
      <input type="hidden" id="inv-pay-invoice-id" value="">
      <!-- Amount input -->
      <!-- Method dropdown: Cash, Bank Transfer, Cheque -->
      <!-- Reference text input -->
      <!-- Payment date input (default today) -->
      <!-- Slip upload (reuse existing pattern) -->
      <!-- Notes textarea -->
    </div>
    <div class="modal-actions">
      <button class="btn btn-outline" onclick="closeModal('inv-pay-modal')">Cancel</button>
      <button class="btn btn-primary" id="inv-pay-save-btn" onclick="invPaySave()">Save Payment</button>
    </div>
  </div>
</div>
```

The modal follows the exact same visual pattern as the existing `pay-modal` used for CS order payments (same `modal-box` class, same 440px max-width, same form field styling). Key differences:

- Hidden field stores `invoice_id` instead of `order_id`.
- Info display shows invoice number and outstanding balance instead of order doc number.
- Method is a simple dropdown (not the multi-line split payment system used for CS), since invoice payments are typically single-method.

### 9.2 Open Payment Modal Function

Define `invOpenPaymentModal(invoiceId)`:

1. Find the invoice in the `invoices` array by ID.
2. Calculate outstanding balance using `invoiceBalance(inv)` (which returns `grand_total - credit_total - amount_paid`).
3. Find the customer name from `customers` array using `inv.customer_id`.
4. Populate the modal:
   - Info section: invoice number, customer name, grand total, amount paid, credit notes applied, **outstanding balance** (bold, prominent).
   - Amount input: pre-fill with outstanding balance (formatted to 2 decimal places).
   - Method dropdown: default to `'bank_transfer'` (most common for invoice payments).
   - Payment date: default to `todayStr()`.
   - Clear any previous slip preview.
5. Show the modal: `document.getElementById('inv-pay-modal').style.display = 'flex'`.

**Guard:** If the invoice status is not `'issued'`, do not open the modal. Show a notification: "Only issued invoices can receive payments."

### 9.3 Save Payment Function

Define `async invPaySave()`:

1. Read form values: invoice ID, amount (parse float), payment date, method, reference, notes.
2. **Validate:**
   - Amount must be > 0.
   - Payment date is required.
   - If amount > outstanding balance, show a warning via `notify('Amount exceeds outstanding balance', 'warning')` but do NOT block the save.
3. Show loading state on the save button via `btnLoading(btn, true)`.
4. **Upload slip** (if attached): Reuse the same pattern from `payUploadSlip()`. Generate the payment ID first via `dbNextId('IP')`, then upload to `sales-photos/payment-slips/<paymentId>.jpg` using the existing resize-to-1200px + JPEG 80% pattern.
5. **Insert payment record** into `sales_invoice_payments`:
   ```
   {
     id: paymentId,          // from dbNextId('IP')
     invoice_id: invoiceId,
     amount: amount,
     payment_date: payDate,
     method: method,
     reference: reference || null,
     slip_url: slipUrl || null,
     notes: notes || null,
     created_by: currentUser ? currentUser.id : null
   }
   ```
   Use: `sbQuery(sb.from('sales_invoice_payments').insert(payData).select())`
6. **Update local array:** Push the new payment into `invoicePayments` array (unshift to keep newest first).
7. **Recalculate invoice payment status:** Call `recalcInvoicePaymentStatus(invoiceId)`. This function (defined in Section 02) should:
   - Sum all payments for this invoice from `invoicePayments`.
   - Read `credit_total` from the invoice.
   - Calculate new `amount_paid` and `payment_status`.
   - Update the invoice record in DB: `sbQuery(sb.from('sales_invoices').update({ amount_paid, payment_status }).eq('id', invoiceId).select())`.
   - Update the local `invoices` array entry.
8. **Close modal**, show success notification, re-render the invoicing tab via `renderInvoicing()` (or `renderCurrentTab()`).
9. On error: restore button state, show error notification.

### 9.4 Payment History in Invoice Detail

In the invoice detail expansion (built in Section 06), add a "Payments" subsection. This should render after the items table and linked DOs list.

**Payment history rendering logic:**

1. Filter `invoicePayments` for records where `invoice_id === inv.id`.
2. Sort by `payment_date` descending (newest first).
3. For each payment, render a row showing:
   - Date (formatted).
   - Amount (formatted as RM).
   - Method label (Cash / Bank Transfer / Cheque).
   - Reference (if present).
   - Slip link (if `slip_url` is populated, show a clickable "View Slip" link opening in new tab).
4. If no payments, show "No payments recorded" in muted text.

### 9.5 Record Payment Button Visibility

In the invoice detail action buttons area (Section 06):

- Show "Record Payment" button **only** when:
  - Invoice `status === 'issued'` (not draft, not cancelled).
  - `invoiceBalance(inv) > 0` (there is still an outstanding amount).
- The button calls `invOpenPaymentModal(inv.id)`.
- Style: `btn btn-primary btn-sm` (green primary button, matching existing patterns).

### 9.6 Slip Upload for Invoice Payments

The slip upload reuses the exact same pattern as the existing CS payment slip upload. The implementation needs its own set of DOM element IDs to avoid conflicts:

- `inv-pay-slip-file` -- file input (hidden).
- `inv-pay-slip-preview` -- preview container.
- `inv-pay-slip-img` -- preview image element.
- `inv-pay-slip-label` -- label text ("Attach slip").

Define helper functions (or reuse with parameterization):

- `invPaySlipPreview(input)` -- reads the file and shows preview (same logic as `paySlipPreview`).
- `invPayClearSlip()` -- clears preview and resets file input.
- `invPayUploadSlip(paymentId)` -- resizes image to max 1200px, uploads to `sales-photos/payment-slips/<paymentId>.jpg` via Supabase Storage, returns public URL.

### 9.7 Method Dropdown Values

| Display Label | DB Value |
|---|---|
| Cash | `cash` |
| Bank Transfer | `bank_transfer` |
| Cheque | `cheque` |

### 9.8 Integration with recalcInvoicePaymentStatus

The `recalcInvoicePaymentStatus(invoiceId)` function (from Section 02) is the single source of truth for payment status calculation. After saving a payment, always call this function rather than manually computing the status. The function should:

1. Sum all `invoicePayments` where `invoice_id === invoiceId` to get total paid.
2. Read the invoice's `credit_total`.
3. Compare `(totalPaid + creditTotal)` against `grand_total`:
   - If `<= 0`: status = `'unpaid'`
   - If `> 0` and `< grand_total`: status = `'partial'`
   - If `>= grand_total`: status = `'paid'`
4. Update DB and local array.

This ensures consistency whether payments, credit notes, or both are applied.

## Actual Implementation Notes

- **Modal HTML:** Added `inv-pay-modal` with all fields (amount, method, reference, date, slip upload, notes)
- **Functions added:** `invOpenPaymentModal()`, `invPaySave()`, `invPaySlipPreview()`, `invPayClearSlip()`, `invPayUploadSlip()`
- **Payment history enhanced:** Added sort by date descending, method display labels (Cash/Bank Transfer/Cheque), "View Slip" links for payments with slip_url
- **Button visibility:** Record Payment button now gated on `invoiceBalance(inv) > 0` in addition to `status === 'issued'`
- **Code review fix:** Added `img.onerror` handler to `invPayUploadSlip()` to prevent Promise hang on corrupt images
- **Deviations:** Overpayment shows warning toast but doesn't block save (per spec 9.3 step 2: "do NOT block the save")
