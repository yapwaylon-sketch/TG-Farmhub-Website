# Sales Invoicing Module — Implementation Plan

## 1. Overview

This plan adds a complete invoicing system to the TG FarmHub sales module (`sales.html`). It replaces the placeholder QuickBooks bridge with native invoice generation, credit notes, invoice payments, statements of account, and e-Invoice-ready data structures.

**The system serves TG Agro Fruits Sdn Bhd** (Reg: 1110222-T), a pineapple sales company in Miri, Sarawak. Credit customers receive Delivery Orders (DOs) which are batched into formal invoices for billing. Cash customers continue using the existing Cash Sales (CS) receipt system.

**Key architectural constraint:** The entire sales module is a single HTML file (`sales.html`) with inline CSS/JS, using Supabase PostgreSQL via REST API with Row Level Security. No build tools, no framework. All document generation is client-side HTML rendered to print or PNG.

---

## 2. Database Migration

### 2.1 New Tables

**`sales_invoices`** — The core invoice entity.

Fields: `id` (TEXT PK, `INV-YYMMDD-NNN`), `customer_id` (TEXT FK → sales_customers), `invoice_date` (DATE), `due_date` (DATE), `payment_terms` (TEXT — one of: cod, 7days, 14days, 30days, 60days), `subtotal` (NUMERIC), `grand_total` (NUMERIC — equals subtotal since no SST), `credit_total` (NUMERIC DEFAULT 0 — sum of credit notes applied), `amount_paid` (NUMERIC DEFAULT 0), `payment_status` (TEXT DEFAULT 'unpaid' — unpaid/partial/paid), `status` (TEXT DEFAULT 'draft' — draft/issued/cancelled), `approved_by` (TEXT — user ID who approved), `approved_at` (TIMESTAMPTZ), `notes` (TEXT), `lhdn_uuid` (TEXT — reserved for e-Invoice), `lhdn_submission_id` (TEXT — reserved), `lhdn_qr_url` (TEXT — reserved), `created_by` (TEXT), `created_at` (TIMESTAMPTZ DEFAULT now()), `updated_at` (TIMESTAMPTZ DEFAULT now()).

**`sales_invoice_items`** — Aggregated product lines per invoice.

Fields: `id` (TEXT PK, `II-*`), `invoice_id` (TEXT FK → sales_invoices ON DELETE CASCADE), `product_id` (TEXT FK → sales_products), `product_name` (TEXT — snapshot at invoice time), `quantity` (NUMERIC), `unit_price` (NUMERIC), `line_total` (NUMERIC).

**`sales_invoice_orders`** — Junction table linking invoices to DOs.

Fields: `invoice_id` (TEXT FK → sales_invoices ON DELETE CASCADE), `order_id` (TEXT FK → sales_orders). Composite primary key on (invoice_id, order_id).

**`sales_invoice_payments`** — Payments recorded against invoices.

Fields: `id` (TEXT PK, `IP-*`), `invoice_id` (TEXT FK → sales_invoices), `amount` (NUMERIC), `payment_date` (DATE), `method` (TEXT — cash/bank_transfer/cheque), `reference` (TEXT), `slip_url` (TEXT — Supabase Storage path for bank transfer slip), `notes` (TEXT), `created_by` (TEXT), `created_at` (TIMESTAMPTZ DEFAULT now()).

**`sales_credit_notes`** — Credit adjustments against invoices.

Fields: `id` (TEXT PK, `CN-YYMMDD-NNN`), `invoice_id` (TEXT FK → sales_invoices), `return_id` (TEXT FK → sales_returns, nullable), `credit_date` (DATE), `amount` (NUMERIC), `reason` (TEXT), `lhdn_uuid` (TEXT — reserved), `created_by` (TEXT), `created_at` (TIMESTAMPTZ DEFAULT now()).

### 2.2 Table Alterations

**`sales_customers`** — Add fields for invoicing and e-Invoice readiness:
- ADD `ssm_brn` TEXT — company registration number
- ADD `tin` TEXT — tax identification number  
- ADD `ic_number` TEXT — IC for individual customers
- ADD `payment_terms_days` INT DEFAULT 30

After adding the column, run a data migration: UPDATE `sales_customers` SET `payment_terms_days` = 0 WHERE `payment_terms` = 'cash'; UPDATE `sales_customers` SET `payment_terms_days` = 30 WHERE `payment_terms` = 'credit'. The old `payment_terms` column stays in the DB but the UI switches to using `payment_terms_days`.

**`sales_orders`** — Add invoice link:
- ADD `invoice_id` TEXT (FK → sales_invoices, nullable)

When a DO is included in an invoice, this field gets set. Used to determine if a DO is "invoiced" (replaces the old `qb_invoice_no` check).

### 2.3 RLS Policies

All new tables need policies for both `anon` and `authenticated` roles, following the existing pattern:
- SELECT: allow for both roles (all sales data is readable by logged-in users)
- INSERT/UPDATE/DELETE: allow for both roles (RLS trusts the app-level auth — PIN or Google OAuth)

Create policies named `{table}_anon_select`, `{table}_anon_insert`, etc. matching the pattern used on `sales_orders`, `sales_payments`, etc.

### 2.4 Constraints

- `sales_invoice_orders.order_id` must have a **UNIQUE constraint** — a DO can only belong to one invoice. This prevents double-invoicing race conditions.
- When updating `sales_orders.invoice_id`, always include `WHERE invoice_id IS NULL` in the update condition to guard against concurrent invoice creation.

### 2.5 Indexes

- `sales_invoices`: index on `customer_id`, index on `status`, index on `payment_status`
- `sales_invoice_orders`: UNIQUE index on `order_id`
- `sales_invoice_payments`: index on `invoice_id`
- `sales_credit_notes`: index on `invoice_id`

### 2.6 Triggers

- Add `updated_at` trigger on `sales_invoices`: auto-set `updated_at = now()` on UPDATE. This is required for the `sbUpdateWithLock()` pattern used in critical update paths.

---

## 3. Data Loading

### 3.1 Extend `loadAllData()`

Add to the existing `Promise.all()` in `loadAllData()`:

```
sbQuery(sb.from('sales_invoices').select('*').order('created_at', {ascending: false}))
sbQuery(sb.from('sales_invoice_items').select('*'))
sbQuery(sb.from('sales_invoice_orders').select('*'))
sbQuery(sb.from('sales_invoice_payments').select('*').order('created_at', {ascending: false}))
sbQuery(sb.from('sales_credit_notes').select('*').order('created_at', {ascending: false}))
```

Store in global arrays: `invoices`, `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes`.

### 3.2 Helper Functions

**`invoiceBalance(inv)`** — Returns `grand_total - credit_total - amount_paid`. This is the outstanding amount.

**`recalcInvoicePaymentStatus(invoiceId)`** — Sums all `sales_invoice_payments` for the invoice plus `credit_total`, compares to `grand_total`. Sets: unpaid (0), partial (0 < paid+credits < total), paid (paid+credits >= total). Updates both local array and DB.

**`isOrderInvoiced(orderId)`** — Returns true if the order has a non-null `invoice_id` or if `invoiceOrders` contains a record for this order.

**`getInvoiceDOs(invoiceId)`** — Returns all orders linked to this invoice via `invoiceOrders`.

**`getCustomerUninvoicedDOs(customerId)`** — Returns completed DOs for this customer where `invoice_id` is null. These are eligible for invoicing.

**`calcDueDate(invoiceDate, paymentTerms)`** — Adds the appropriate number of days based on payment terms code. Returns a date string.

**`isInvoiceOverdue(inv)`** — Returns true if `due_date < today` AND status is 'issued' AND payment_status is 'unpaid' or 'partial'.

---

## 4. Payment Terms Migration

### 4.1 Customer Model Change

The existing `payment_terms` field (credit/cash) is replaced by `payment_terms_days` (integer). The UI needs to change everywhere `payment_terms` is referenced:

**Customer edit modal (`scOpenModal`)**: Replace the credit/cash dropdown with a payment terms dropdown showing: COD (0), Net 7 (7), Net 14 (14), Net 30 (30), Net 60 (60). When saving, store the selected days value in `payment_terms_days`.

**Customer list and detail views**: Where badges currently show "Credit"/"Cash", show the payment terms label instead (e.g., "Net 30", "COD").

**Order creation**: The `doc_type` assignment (delivery_order vs cash_sales) currently checks `payment_terms === 'credit'`. Change this to check `payment_terms_days > 0` for delivery_order, `=== 0` for cash_sales.

### 4.2 Backward Compatibility

Keep the `payment_terms` column in the DB. The migration sets `payment_terms_days` from the existing values. Both columns coexist — the UI reads `payment_terms_days`, legacy code that still references `payment_terms` continues to work during transition.

---

## 5. Customer Fields Update

### 5.1 Edit Modal Changes

Add new fields to the customer edit modal (`scOpenModal`):
- **Address** (textarea — already exists but may need more prominence)
- **SSM / BRN** (text input, placeholder: "e.g., 1234567-A")
- **TIN** (text input, placeholder: "e.g., C1234567890")  
- **IC Number** (text input, placeholder: "e.g., 900101-13-1234")
- **Payment Terms** (dropdown replacing credit/cash)

These fields are optional — most customers won't have SSM/TIN initially. The address is important for invoices but can be added gradually.

### 5.2 Customer Detail View

Show the new fields in the customer detail page's info section. SSM, TIN, IC only displayed if populated (don't show empty fields).

---

## 6. Invoicing Tab Redesign

### 6.1 Remove QB Code

Delete these functions entirely: `invSaveInvoice()` (the QB save), the QB invoice number modal HTML, and the "Invoice History" section that groups by `qb_invoice_no`. Remove QB references from `renderInvoicing()`.

Keep `invSelectedDOs`, `invToggleDO`, `invSelectAllCustomer`, `invUpdateButtons`, `invRenderBillingSummary` — these are reusable for the new invoice creation flow. Modify them to work with the new invoice entity.

### 6.2 Section A: Create Invoice

**Layout:**
1. Customer dropdown (searchable, shows only customers with uninvoiced DOs)
2. On customer select: show list of their uninvoiced completed DOs with checkboxes
3. Each DO row: checkbox, doc number, date, item count, total amount
4. "Select All" per customer
5. Below DOs: live billing summary (aggregated products from selected DOs — reuse `invRenderBillingSummary` pattern)
6. Invoice date input (default today)
7. Payment terms dropdown (default from customer's `payment_terms_days`)
8. Notes textarea
9. "Create Draft Invoice" button

**On Create:**
1. Generate invoice ID via `dbNextId('INV')`
2. Calculate `due_date` from `invoice_date` + `payment_terms_days`
3. Aggregate selected DO items by product: group by `product_id`, sum quantities, use the most recent unit price (or weighted average if prices differ)
4. Insert `sales_invoices` record (status: 'draft')
5. Insert `sales_invoice_items` records (one per aggregated product)
6. Insert `sales_invoice_orders` records (one per selected DO)
7. Update each selected DO's `invoice_id` field
8. Clear selections, re-render

**Product aggregation logic:** When multiple DOs have the same product at different prices (e.g., price changed mid-month), create **one line per unique product+price combination**. This preserves accuracy — no weighted averages or price merging.

### 6.3 Section B: Invoice List

**Layout:**
1. Filter bar: customer dropdown, status filter (All, Draft, Issued, Overdue, Partial, Paid), date range
2. Summary cards: Total Outstanding (issued+partial), Overdue Count+Amount, This Month Invoiced
3. Invoice cards/rows sorted by date (newest first), each showing:
   - Invoice number, date, due date
   - Customer name
   - Grand total, amount paid, balance
   - Status badge (Draft=grey, Issued=blue, Partial=gold, Paid=green, Overdue=red, Cancelled=dim)
   - Overdue indicator: if past due_date and unpaid/partial, show red "Overdue X days"

**On click (expand/detail):**
- Invoice header info
- Items table (products with quantities and amounts)
- Linked DOs list (doc numbers + dates)
- Credit notes list (if any)
- Payment history (if any)
- Action buttons:
  - **Approve** (draft only, admin-only — check `currentUser.role === 'admin'` in JS, hide button for non-admin) → changes status to 'issued', sets approved_by/approved_at
  - **Record Payment** → opens payment modal
  - **Add Credit Note** → opens CN modal
  - **Print/Share** → generates A4 document
  - **Cancel** → only if no payments recorded, confirmation required
  - **Add More DOs** (draft only) → opens DO selection for this customer

### 6.4 Draft Invoice Editing

While an invoice is in 'draft' status:
- Can add more DOs (re-aggregates products)
- Can remove DOs (re-aggregates)
- Can edit invoice date, payment terms, notes
- Can delete the entire draft (unlinks all DOs)

Once 'issued', the invoice is locked. Adjustments only via credit notes.

### 6.5 Invoice Cancellation

**Rules:**
- Can cancel from Draft (always) or Issued (only if no payments recorded)
- Cannot cancel if any `sales_invoice_payments` exist for this invoice
- Requires confirmation modal

**Cascade on cancellation:**
1. Delete `sales_credit_notes` linked to this invoice (if any, draft-only scenario)
2. Delete `sales_invoice_items` (CASCADE handles this)
3. Delete `sales_invoice_orders` junction records (CASCADE handles this)
4. Set `invoice_id = null` on all linked `sales_orders`
5. Set invoice `status = 'cancelled'` (soft delete — keep record)
6. Re-render invoicing tab

### 6.6 Walk-in Customer Filtering

The invoice creation customer dropdown must **exclude walk-in type customers** (`type === 'walkin'`). Walk-in customers always get Cash Sales, never invoices. Additionally, only show customers who have uninvoiced completed DOs (no point showing customers with nothing to invoice).

---

## 7. Invoice Document Generation

### 7.1 A4 Invoice (`generateInvoiceA4()`)

Follow the existing `soGenerateDocA4()` pattern but with invoice-specific content.

**Document structure:**

**Header block:**
- Left: Company logo (same `assets/logo.png?v=2` used in other A4 docs)
- Below logo: "TG AGRO FRUITS SDN. BHD." (bold, large)
- Company details: Reg No: 1110222-T | TIN: 24302625000 | MSIC: 46909
- Address: Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak
- Right side or below: "INVOICE" title (large, prominent)

**Info grid (2 columns):**
- Left column: Invoice No, Invoice Date, Due Date, Payment Terms
- Right column: Customer Name, Customer Address (if available), SSM/TIN (if available)

**Items table:**
- Columns: No., Description, Qty, Unit, Unit Price (RM), Amount (RM)
- Description includes product name + variety (e.g., "MD2 Grade A (Box, 8pcs)")
- After table: reference line — "Ref: DO-260315-001 (15/03), DO-260318-002 (18/03), ..."

**Totals section:**
- Subtotal
- Credit Notes (if any) — shown as deduction
- Grand Total (bold, large)
- Amount Paid (if any)
- Balance Due (bold, highlighted if > 0)

**Bank details box:**
- "Payment to:" Public Bank Berhad
- Account: 3243036710
- Name: TG Agro Fruits Sdn. Bhd.

**e-Invoice placeholder:**
- Reserved space at bottom for future LHDN QR code (currently empty or shows "e-Invoice: Pending")

**Signature block:**
- Left: "Prepared By" with name auto-filled
- Right: "Authorized By" with blank signature line

**Footer:**
- "Thank you for your business"

### 7.2 Print and Share

Same patterns as existing A4 DO:
- `window.print()` with `@page { size: A4; margin: 10mm; }`
- `html2canvas` → JPEG blob → Web Share API or WhatsApp
- Share filename: `INV-260403-001.png`

---

## 8. Credit Notes vs Existing Debit Notes

### 8.1 Relationship Clarification

The existing returns system has **Debit Notes (DN)** — these are order-level. A return with resolution `debit_note` gets a `DN-YYMMDD-NNN` number stored on `sales_returns.debit_note_no`. DNs can be applied to future orders via `debit_note_used_on`.

The new **Credit Notes (CN)** are invoice-level. They reduce an invoice's outstanding balance. The two systems coexist:

- **DN** = order-level credit (existing, unchanged). Customer gets credit applicable to future orders.
- **CN** = invoice-level credit (new). Reduces what the customer owes on a specific invoice.

When a return with resolution `debit_note` exists for a DO that's part of an invoice, you can create a CN that **links to that return** via `return_id`. This connects the order-level return to the invoice-level credit.

DNs that were already applied to orders (`debit_note_used_on` is set) are historical — they reduced order totals, which already flowed into invoice totals. No migration needed.

## 9. Credit Note System

### 8.1 Credit Note Modal

Triggered from invoice detail view → "Add Credit Note" button.

**Fields:**
- Invoice reference (auto-filled, read-only)
- Linked return (dropdown — shows returns for orders in this invoice, or "None — manual adjustment")
- Credit date (default today)
- Amount (if linked to return, auto-filled from return amount; if manual, editable)
- Reason (required — e.g., "Damaged goods", "Pricing error", "Customer return")

**Validation:**
- CN amount must not exceed invoice outstanding balance (`grand_total - credit_total - amount_paid`). This prevents negative balances.
- Reason is required.

**On Save:**
1. Generate CN ID via `dbNextId('CN')`
2. Insert `sales_credit_notes` record
3. Update `sales_invoices.credit_total` (sum all CNs for this invoice)
4. Recalculate invoice `payment_status` via `recalcInvoicePaymentStatus()`
5. Notify user

### 8.2 Credit Note Document (A4)

Similar to invoice document but:
- Title: "CREDIT NOTE"
- Shows: CN number, date, original invoice number
- Reason for credit
- Amount being credited
- Signature block

---

## 9. Invoice Payment Recording

### 9.1 Payment Modal

Triggered from invoice detail view → "Record Payment" button.

**Fields:**
- Invoice reference (read-only) + outstanding balance shown prominently
- Payment date (default today)
- Amount (pre-filled with outstanding balance)
- Method dropdown: Cash, Bank Transfer, Cheque
- Reference (text — bank ref number, cheque number)
- Bank transfer slip upload (optional — existing photo upload pattern)
- Notes (optional)

**Validation:**
- Amount must be > 0
- Amount should not exceed outstanding balance (warn if it does, but allow — overpayment creates credit)
- Payment date required

**On Save:**
1. Generate payment ID via `dbNextId('IP')`
2. Insert `sales_invoice_payments` record
3. Update `sales_invoices.amount_paid` (sum all payments)
4. Recalculate `payment_status` via `recalcInvoicePaymentStatus()`
5. Show payment confirmation notification

### 9.2 Payments Tab — Split View

**Redesign `renderPayments()` to show two sections:**

**Section 1: Cash Sales Payments** (existing functionality, unchanged)
- Shows completed CS orders with payment tracking
- Existing filters, summary cards, aging

**Section 2: Invoice Payments** (new)
- Shows all invoices with payment status
- Grouped by customer
- Expandable: invoice detail with payment history
- Filters: customer, status (outstanding/overdue/all), date range
- Summary cards: Total Outstanding, Overdue Amount, Payments This Month
- Record Payment button per invoice
- Aging colors: current=green, 1-30d=gold, 31-60d=orange, 60d+=red

---

## 10. Statement of Account

### 10.1 Generation (`generateStatement()`)

Triggered from:
- Customer detail page → "Statement" button
- Invoicing tab → per-customer "Statement" button

**Parameters:** customer_id, date_from, date_to (default: current month)

**Document structure (A4):**

**Header:** Company letterhead (same as invoice)

**Title:** "STATEMENT OF ACCOUNT"

**Customer info:** Name, address, credit terms, statement period

**Transaction table:**

| Date | Doc No | Description | Debit (RM) | Credit (RM) | Balance (RM) |
|------|--------|-------------|-----------|------------|-------------|

**Opening balance:** Calculate sum of all invoice debits minus all payments and credit notes **before** `date_from`. Show as first row: "Brought Forward — RM X,XXX.XX". This ensures the running balance is correct even for partial date ranges.

Transactions include:
- Invoices issued → Debit column (increases balance)
- Payments received → Credit column (decreases balance)
- Credit notes → Credit column (decreases balance)

Running balance calculated row by row, starting from the opening balance.

**Aging summary (bottom):**

| Current | 1-30 Days | 31-60 Days | 61-90 Days | 90+ Days | Total |
|---------|-----------|-----------|-----------|---------|-------|

Calculate by iterating invoices, checking age from due_date.

**Footer:**
- Bank details (Public Bank 3243036710)
- "Kindly send payment slip via WhatsApp to [number] upon payment"
- "If payment has already been made, please disregard this statement"

### 10.2 Print and Share

Same A4 patterns: `window.print()` + `html2canvas` PNG export.

---

## 11. Dashboard Updates

### 11.1 Replace QB Card

In `renderDashboard()`, replace the "Uninvoiced DO" card with three invoice-related cards:

**Card 1: Outstanding Invoices**
- Sum of `invoiceBalance(inv)` for all invoices with status 'issued' and payment_status 'unpaid' or 'partial'
- Click → switch to Invoicing tab with status filter set to "Outstanding"

**Card 2: Overdue Invoices**  
- Count and amount of invoices where `isInvoiceOverdue(inv)` is true
- Red styling if > 0
- Click → switch to Invoicing tab with status filter set to "Overdue"

**Card 3: Uninvoiced DOs**
- Count of completed DOs with no `invoice_id` (replaces old `!o.qb_invoice_no` check)
- Click → switch to Invoicing tab (create invoice section)

**Important:** The existing "Total Owed" calculation on the dashboard (which sums unpaidCS + uninvoicedDO) must be updated to: `unpaidCS + outstandingInvoices + uninvoicedDO`. The uninvoiced DO check must change from `!o.qb_invoice_no` to `!o.invoice_id` as part of the QB cleanup step.

### 12.2 Invoices are A4-only

Invoices are formal business documents — no 80mm thermal version. A4 print + PNG WhatsApp share only.

---

## 12. Reports

### 12.1 Invoice Register Report

New report in the Reports tab: "Invoice Register"

Table columns: Invoice No, Date, Due Date, Customer, Grand Total, Paid, Credits, Balance, Status

Filters: date range, customer, status
Sortable by any column.
Totals row at bottom.

### 12.2 Aging Report

New report: "Aging Report"

Grouped by customer. For each customer:

| Customer | Current | 1-30 | 31-60 | 61-90 | 90+ | Total |

Each cell = sum of outstanding invoice balances in that age bucket.
Color coding: current=normal, 30d=gold, 60d=orange, 90d+=red.

Grand totals row at bottom.

### 12.3 Update Existing Reports

The payment summary report should include a section for invoice payments (separate from CS payments) so the total payments picture is complete.

---

## 13. QB Cleanup

### 13.1 Remove from UI

- Remove QB invoice number input modal HTML
- Remove `invSaveInvoice()` function (the QB save)
- Remove QB-related variables and helpers
- Remove "QB Invoice" column from Payments tab DO section
- Remove QB invoice grouping from invoice history
- Remove "paid via QB Invoice" references

### 13.2 Keep in DB

- `sales_orders.qb_invoice_no` and `qb_invoiced_at` columns stay (no migration risk)
- No data deletion — they just become unused columns

---

## 14. Implementation Order

The sections should be implemented in this order due to dependencies:

1. **Database migration** — create tables, alter columns, add RLS, triggers, constraints, run data migration
2. **Data loading** — extend `loadAllData()`, add helper functions
3. **Payment terms + customer fields** — update customer model, edit modal, detail view
4. **QB cleanup + dashboard fix** — remove QB code, update dashboard uninvoiced DO check from `qb_invoice_no` to `invoice_id`, update Total Owed calculation. Stub the invoicing tab with a placeholder so it's not broken between cleanup and rebuild.
5. **Invoicing tab — Create Invoice** — the core invoice creation flow
6. **Invoicing tab — Invoice List** — viewing, filtering, detail expansion, cancellation
7. **Invoice document generation** — A4 document with letterhead, print, PNG export
8. **Invoice approval workflow** — Draft → Issued transition (admin-only)
9. **Invoice payment recording** — payment modal, recalculation
10. **Credit note system** — CN modal, document, CN/DN relationship, balance recalc
11. **Payments tab split view** — add invoice payments section
12. **Statement of Account** — generation with opening balance, aging, document, print/share
13. **Dashboard updates** — replace QB card with invoice metrics (outstanding, overdue, uninvoiced)
14. **Reports** — invoice register, aging report, payment report updates

Each section builds on the previous ones. The DB migration must come first. Document generation and payments depend on the invoice entity existing.
