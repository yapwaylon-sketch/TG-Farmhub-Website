# Sales Invoicing Module — Complete Specification

## 1. Business Context

**TG Agro Fruits Sdn Bhd** (Reg: 1110222-T, TIN: 24302625000) is the sales and marketing arm for pineapple produce from Ladang PND in Sarawak, Malaysia. The company sells to wholesale, retail, and walk-in customers via the TG FarmHub sales module (`sales.html`).

Currently, Delivery Orders (DO) for credit customers were intended to be batched into QuickBooks invoices — but no QB invoices were ever created. The system needs a full native invoicing capability built directly into sales.html, completely replacing the QB bridge.

**Annual revenue is below RM 1M**, making TG Agro Fruits currently exempt from Malaysia's e-Invoice (MyInvois) mandate. However, the data structure should be e-Invoice-ready for future compliance.

## 2. Company Details (for Invoice Letterhead)

- **Name:** TG Agro Fruits Sdn. Bhd.
- **Reg No:** 1110222-T
- **TIN:** 24302625000
- **SST:** Not registered (fresh produce exempt) — "NA" on documents
- **MSIC:** 46909 — Wholesale of a variety of goods n.e.c
- **Address:** Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak, Malaysia
- **Bank:** Public Bank Berhad — Account: 3243036710 — Name: TG Agro Fruits Sdn. Bhd.

## 3. Scope

### In Scope (Phase 1)
- Invoice generation from completed Delivery Orders
- Invoice document (A4 printable + PNG export)
- Invoice approval workflow (Draft → Issued)
- Credit notes (linked to returns or standalone)
- Payment recording against invoices
- Statement of Account (monthly, with aging)
- Customer fields for invoicing (address, SSM, TIN, IC)
- Payment terms system (COD, Net 7/14/30/60)
- Payments tab split view (CS + Invoice payments)
- Dashboard updates (invoice metrics)
- Remove all QuickBooks references
- e-Invoice data structure (columns reserved, no API)

### Out of Scope
- LHDN MyInvois API integration (future phase)
- Cash Sales invoicing (CS already has receipt/document generation)
- Inter-company billing (TG Agribusiness → TG Agro Fruits)
- Self-billed invoices

## 4. Invoice Generation

### 4.1 Creating Invoices
- Only **completed Delivery Orders** are eligible for invoicing
- Select customer → see their uninvoiced completed DOs
- Tick DOs to include → system aggregates line items
- **Line items are summarized per product** across all selected DOs (total qty × unit price)
- DO numbers and dates listed as reference below the items table
- Flexible: can create multiple invoices per customer, or add DOs to existing draft invoices

### 4.2 Invoice Fields
- Invoice number: `INV-YYMMDD-NNN` via `dbNextId('INV')`
- Customer (auto from selected DOs)
- Invoice date (defaults to today, editable)
- Due date (auto-calculated from customer's payment terms, editable)
- Payment terms (from customer default, overridable)
- Notes (optional free text)

### 4.3 Invoice Status Flow
```
Draft → Issued → Partial Payment → Paid
                                 → Cancelled
```
- **Draft**: created, can add/remove DOs, edit details. Not yet sent to customer.
- **Issued**: approved by admin, locked. Sent/printed for customer. Payments can be recorded.
- **Partial**: some payment received, not fully paid.
- **Paid**: fully paid (amount_paid >= grand_total).
- **Cancelled**: voided (only from Draft or Issued with no payments).

### 4.4 Approval Workflow
- Supervisor/staff creates invoice as Draft
- Admin reviews and approves → status changes to Issued
- Only Issued invoices can receive payments or be printed for customers

## 5. Invoice Document (A4)

### 5.1 Layout
- **Header**: Company logo + full letterhead (name, reg no, TIN, MSIC, address, contact)
- **Title**: "INVOICE"
- **Info grid**: Invoice number, date, due date, payment terms | Customer name, address, SSM/TIN (if available)
- **Items table**: No., Description (product name + variety), Qty, Unit, Unit Price (RM), Amount (RM)
- **Reference section**: "Delivery Orders: DO-260315-001 (15/03), DO-260318-002 (18/03), ..."
- **Totals**: Subtotal → Grand Total (no SST line since not registered)
- **Bank details**: Public Bank 3243036710
- **QR code space**: Reserved area for future LHDN QR (show placeholder text "e-Invoice QR" or leave blank)
- **Signature block**: "Prepared By" (auto) + "Authorized By" (blank line)

### 5.2 Output Methods
- Browser print (A4)
- PNG export via html2canvas for WhatsApp sharing
- Same patterns as existing A4 DO document

## 6. Credit Notes

### 6.1 Creation
- Can be created from an existing return record (auto-links invoice + return)
- Can also be created standalone directly against an invoice (manual adjustment)
- Number format: `CN-YYMMDD-NNN` via `dbNextId('CN')`

### 6.2 Fields
- Credit note number, date
- Linked invoice (required)
- Linked return (optional — if created from returns system)
- Reason
- Line items or lump sum amount
- References original invoice UUID (reserved for e-Invoice)

### 6.3 Effect
- Reduces the invoice's outstanding balance
- Auto-recalculates invoice payment_status

### 6.4 Document
- A4 printable, similar format to invoice
- Title: "CREDIT NOTE"
- Shows original invoice reference
- PNG export for WhatsApp

## 7. Payment Against Invoices

### 7.1 Recording
- Payments recorded against invoices (not individual DOs)
- Partial payments supported
- Payment methods: cash, bank transfer, cheque (same as existing CS flow)
- Bank transfer slip upload (existing pattern via Supabase Storage)
- Auto-calculate: outstanding = grand_total - amount_paid - credit_notes_total
- Auto-update payment_status: unpaid → partial → paid

### 7.2 Payments Tab (Split View)
- **Section 1: Cash Sales Payments** — existing CS payment tracking (unchanged)
- **Section 2: Invoice Payments** — new section showing payments against invoices
- Both sections have their own filters, summaries, and aging

## 8. Statement of Account

### 8.1 Format
- A4 printable
- Company letterhead
- Customer details + credit terms
- Transaction table: Date, Doc No, Description, Debit (RM), Credit (RM), Balance (RM)
- Running balance column
- Aging summary: Current / 1-30 / 31-60 / 61-90 / 90+ days
- Bank details + WhatsApp payment reminder
- "If payment has been made, please disregard this statement"
- Date range selectable

### 8.2 Triggers
- Generated on-demand from customer detail page or Invoicing tab
- Can be printed or shared as PNG via WhatsApp

## 9. Payment Terms

### 9.1 Options
| Code | Label | Days |
|------|-------|------|
| cod | Cash on Delivery | 0 |
| 7days | Net 7 | 7 |
| 14days | Net 14 | 14 |
| 30days | Net 30 | 30 |
| 60days | Net 60 | 60 |

### 9.2 Behavior
- Set per customer as default (`payment_terms_days` on `sales_customers`)
- Overridable per invoice
- Replaces existing binary credit/cash field
- Migration: credit → 30 days, cash → 0 days (COD)
- Due date auto-calculated: invoice_date + payment_terms_days

## 10. Customer Fields (e-Invoice Readiness)

### 10.1 New Fields
- `ssm_brn` (TEXT) — Company registration / SSM number
- `tin` (TEXT) — Tax identification number
- `ic_number` (TEXT) — IC for individual customers
- `address` (TEXT) — Full address (needed on invoices)
- `payment_terms_days` (INT, default 30) — replaces binary credit/cash

### 10.2 Data Collection
- Most customers don't have addresses yet — will be collected gradually
- Only credit/wholesale customers strictly need these for invoicing
- Customer edit modal updated with new fields
- Address shows on invoice if available, "—" if not

## 11. Database Schema

### 11.1 New Table: `sales_invoices`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | INV-YYMMDD-NNN |
| customer_id | TEXT FK | → sales_customers |
| invoice_date | DATE | |
| due_date | DATE | |
| payment_terms | TEXT | cod/7days/14days/30days/60days |
| subtotal | NUMERIC | |
| grand_total | NUMERIC | = subtotal (no SST) |
| credit_total | NUMERIC | Sum of credit notes |
| amount_paid | NUMERIC | Running total of payments |
| payment_status | TEXT | unpaid/partial/paid |
| status | TEXT | draft/issued/cancelled |
| approved_by | TEXT | User who approved (Draft→Issued) |
| approved_at | TIMESTAMPTZ | |
| notes | TEXT | |
| lhdn_uuid | TEXT | Future e-Invoice |
| lhdn_submission_id | TEXT | Future e-Invoice |
| lhdn_qr_url | TEXT | Future e-Invoice |
| created_by | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### 11.2 New Table: `sales_invoice_items`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | II-* |
| invoice_id | TEXT FK | → sales_invoices |
| product_id | TEXT FK | → sales_products |
| product_name | TEXT | Snapshot at invoice time |
| quantity | NUMERIC | Aggregated from DOs |
| unit_price | NUMERIC | |
| line_total | NUMERIC | |

### 11.3 New Table: `sales_invoice_orders`
| Column | Type | Notes |
|--------|------|-------|
| invoice_id | TEXT FK | → sales_invoices |
| order_id | TEXT FK | → sales_orders |
| (composite PK) | | |

### 11.4 New Table: `sales_credit_notes`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | CN-YYMMDD-NNN |
| invoice_id | TEXT FK | → sales_invoices |
| return_id | TEXT FK | Optional → sales_returns |
| credit_date | DATE | |
| amount | NUMERIC | |
| reason | TEXT | |
| lhdn_uuid | TEXT | Future e-Invoice |
| created_by | TEXT | |
| created_at | TIMESTAMPTZ | |

### 11.5 New Table: `sales_invoice_payments`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | IP-* |
| invoice_id | TEXT FK | → sales_invoices |
| amount | NUMERIC | |
| payment_date | DATE | |
| method | TEXT | cash/bank_transfer/cheque |
| reference | TEXT | |
| slip_url | TEXT | |
| notes | TEXT | |
| created_by | TEXT | |
| created_at | TIMESTAMPTZ | |

### 11.6 Alter: `sales_customers`
- ADD `ssm_brn` TEXT
- ADD `tin` TEXT
- ADD `ic_number` TEXT
- ADD `payment_terms_days` INT DEFAULT 30
- Ensure `address` field exists (it does)
- Migrate: payment_terms 'credit' → payment_terms_days 30, 'cash' → 0

### 11.7 Alter: `sales_orders`
- ADD `invoice_id` TEXT FK → sales_invoices (set when DO is included in an invoice)
- Keep `qb_invoice_no` and `qb_invoiced_at` in DB but remove from UI

### 11.8 RLS
- All new tables need RLS policies matching existing sales tables
- Both `anon` (PIN login) and `authenticated` (Google OAuth) roles

## 12. Invoicing Tab Redesign

### 12.1 Section A: Create Invoice
- Customer dropdown/search
- Shows uninvoiced completed DOs for selected customer
- Checkboxes per DO (reuse existing `invSelectedDOs` pattern)
- Live product aggregation preview (reuse `invRenderBillingSummary` pattern)
- Invoice date, payment terms fields
- "Create Draft Invoice" button

### 12.2 Section B: Invoice List
- All invoices with status badges (Draft, Issued, Partial, Paid, Overdue, Cancelled)
- Filter by: customer, status, date range
- Overdue = past due_date AND (unpaid OR partial)
- Click to expand: invoice detail, linked DOs, payments, credit notes
- Action buttons per invoice: View/Print, Record Payment, Approve (draft only), Cancel
- Statement of Account button (per customer)

### 12.3 Remove QB References
- Remove Section B "Invoice History" (QB grouped view)
- Remove QB modal and `invSaveInvoice()` function
- Remove `qb_invoice_no` display from orders/payments UI
- Keep DB columns untouched for data preservation

## 13. Dashboard Updates

Replace "Uninvoiced DO" card with:
- **Outstanding Invoices**: total amount of issued + partial invoices
- **Overdue Invoices**: count + amount of overdue invoices
- **This Month Invoiced**: total amount invoiced this month

## 14. Reports

### 14.1 New Reports
- **Invoice Register**: all invoices with status, customer, amounts, dates
- **Aging Report**: 30/60/90 day aging buckets by customer
- **Customer Statement**: on-demand per customer (covered in Section 8)

### 14.2 Existing Report Updates
- Payment reports should include invoice payments alongside CS payments

## 15. Constraints

- Single HTML file (`sales.html`) — all JS inline
- No build tools, no npm, no framework
- Supabase SDK v2.49.1 via CDN
- Must work on mobile (phone-first)
- RLS on all new tables
- Document generation: print + WhatsApp PNG share
- Must not break existing DO/CS/order workflows
- All Supabase calls via `sbQuery()` wrapper
- ID generation via `dbNextId()` with appropriate prefixes
- Follow existing code patterns (tab switching, modal patterns, data loading)
