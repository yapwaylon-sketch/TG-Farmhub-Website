# Sales Invoicing Module — Specification

## Overview

Replace QuickBooks with a full invoicing system built into TG FarmHub's sales module (`sales.html`). TG Agro Fruits Sdn Bhd is the sales & marketing arm that sells pineapple produce to customers and issues all commercial documents (DO, CS, Invoices, Credit Notes, Statements).

## Business Context

- **TG Agribusiness** = production arm (farm, growing, harvest)
- **TG Agro Fruits Sdn Bhd** = sales & marketing arm (issues invoices, collects payments)
- TG Agribusiness bills TG Agro Fruits for produce (inter-company — out of scope for now)
- QuickBooks is being dropped entirely — no invoices were ever created there
- All pineapple sales invoicing will happen in this system

## Company Details (Invoice Letterhead)

- **Company Name**: TG Agro Fruits Sdn. Bhd.
- **Registration No.**: 1110222-T
- **TIN**: 24302625000
- **SST**: NOT registered (fresh produce exempt — no SST line on invoices)
- **MSIC Code**: 46909 — Wholesale of a variety of goods without any particular specialization n.e.c
- **Address**: Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak, Malaysia
- **Bank**: Public Bank Berhad
- **Account Name**: TG Agro Fruits Sdn. Bhd.
- **Account No.**: 3243036710

## Current System State

### Existing Sales Module (`sales.html`)
- 7 tabs: Dashboard, Orders, Payments, Invoicing, Manage Customers, Manage Products, Reports
- **Orders**: status flow `pending → preparing → prepared → delivering → completed`
- **Document types**: Delivery Order (DO) for credit customers, Cash Sales (CS) for cash customers
- **Document numbering**: `DO-YYMMDD-NNN`, `CS-YYMMDD-NNN` via `dbNextId()`
- **Invoicing tab (current)**: QB bridge only — select DOs, enter QB invoice number, mark as invoiced. To be completely replaced.
- **Payments tab**: tracks payments per order (CS direct, DO was supposed to go through QB)
- **Returns**: trust-based, resolution options: deduct/refund/debit note. Debit notes auto-numbered `DN-YYMMDD-NNN`
- **Customers**: name, phone, type (wholesale/retail/walkin), payment_terms (credit/cash)
- **Products**: catalog with optional variety link, categories, pricing, name_bm, pcs_per_box, weight_range

### Existing Database Tables
- `sales_customers` — customer profiles
- `sales_products` — product catalog
- `sales_orders` — orders with status workflow, has `qb_invoice_no` and `qb_invoiced_at` fields
- `sales_order_items` — line items per order
- `sales_payments` — payment records per order
- `sales_returns` — returns with debit note tracking

### Tech Stack
- Static HTML/CSS/vanilla JS (no framework, no build step)
- Supabase PostgreSQL backend with RLS
- Single HTML file per module
- Supabase SDK v2.49.1 via CDN

## Requirements

### 1. Invoice Generation

**Create invoices from completed Delivery Orders:**
- Select customer → shows their uninvoiced completed DOs
- Tick DOs to include in this invoice
- System aggregates line items: **summary per product** (total qty × unit price across all selected DOs)
- DO numbers and dates listed as reference on the invoice (not individual line items per DO)
- Invoice number: `INV-YYMMDD-NNN` via `dbNextId()`
- Invoice date: defaults to today, editable
- Due date: auto-calculated from customer's payment terms, editable
- Notes: optional free text

**Invoice status flow:**
```
Draft → Issued → Partial Payment → Paid → (Cancelled)
```

### 2. Invoice Document

**A4 printable format with:**
- Company letterhead (name, reg no, TIN, address)
- Customer details (name, address, SSM/BRN if available)
- Invoice number, date, due date, payment terms
- Product summary table (product name, total qty, unit price, line total)
- Reference section: list of DO numbers + dates included
- Subtotal and Grand Total (no SST)
- Bank details for payment (Public Bank 3243036710)
- Space reserved for LHDN QR code (future Phase 3)
- PNG export for WhatsApp sharing (like current DO/CS)

### 3. Credit Notes

- For adjustments to issued invoices (damage, returns, pricing errors)
- Number format: `CN-YYMMDD-NNN`
- Links to a specific invoice
- Reduces the invoice's outstanding balance
- A4 printable document similar to invoice format
- Ties into existing returns system where applicable

### 4. Payment Against Invoices

- Record payments against invoices (not individual DOs)
- Partial payments supported
- Payment methods: cash, bank transfer, cheque
- Auto-calculate outstanding balance (invoice total - payments - credit notes)
- Payment status auto-updates: unpaid → partial → paid

### 5. Statement of Account

- Monthly summary per customer
- Shows: brought forward balance, invoices issued, payments received, credit notes, ending balance
- Running balance column
- A4 printable format
- Date range selectable
- Includes bank details + payment reminder

### 6. Payment Terms

Configurable per customer with these defaults:
| Code | Label | Days |
|------|-------|------|
| `cod` | Cash on Delivery | 0 |
| `7days` | Net 7 | 7 |
| `14days` | Net 14 | 14 |
| `30days` | Net 30 | 30 |
| `60days` | Net 60 | 60 |

Replace current binary `credit/cash` with the above. Default per customer, overridable per invoice.

### 7. Customer Fields (e-Invoice Readiness)

Add to `sales_customers`:
- `ssm_brn` — Company registration / SSM number
- `tin` — Tax identification number
- `ic_number` — IC for individual customers
- `address` — Full address (required on invoices)
- `payment_terms_days` — Default days (replaces binary credit/cash)

### 8. Invoicing Tab Redesign

Replace the current QB bridge with:

**Section A: Create Invoice**
- Customer filter/search
- Uninvoiced DOs per customer with checkboxes
- Live preview of aggregated products
- Create Invoice button

**Section B: Invoice List**
- All invoices with status badges (Draft, Issued, Partial, Paid, Overdue, Cancelled)
- Filter by customer, status, date range
- Click to view detail / record payment / print
- Overdue highlighting (past due date + unpaid/partial)

**Section C: Removed — no QB history needed**

### 9. Dashboard Updates

- Replace "Uninvoiced DO" card with invoice-aware metrics
- Outstanding invoices total
- Overdue invoices count + amount
- This month's invoiced total

### 10. Reports Updates

- Invoice register (all invoices with status, amounts)
- Aging report (30/60/90 day buckets by customer)
- Customer statement (as described above)

### 11. Remove QuickBooks References

- Remove all `qb_invoice_no`, `qb_invoiced_at` references from UI
- Remove QB-related modal and functions
- Keep DB columns for historical data but don't display

### 12. Malaysia e-Invoice (LHDN MyInvois) — Future Phase

**NOT in scope for Phase 1 implementation, but design for it:**
- Reserve `lhdn_uuid`, `lhdn_submission_id`, `lhdn_qr_url` columns on invoices table
- Reserve space on invoice document for QR code
- Customer TIN/SSM fields (being added in this phase)
- Will require Supabase Edge Functions for server-side digital signing
- Will require LHDN MyInvois portal registration

## Database Schema Changes

### New Table: `sales_invoices`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | INV-YYMMDD-NNN |
| customer_id | TEXT FK | → sales_customers |
| invoice_date | DATE | |
| due_date | DATE | |
| payment_terms | TEXT | cod, 7days, 14days, 30days, 60days |
| subtotal | NUMERIC | |
| grand_total | NUMERIC | (= subtotal, no SST) |
| amount_paid | NUMERIC | Running total |
| payment_status | TEXT | unpaid, partial, paid |
| status | TEXT | draft, issued, cancelled |
| notes | TEXT | |
| lhdn_uuid | TEXT | Future e-Invoice |
| lhdn_submission_id | TEXT | Future e-Invoice |
| lhdn_qr_url | TEXT | Future e-Invoice |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### New Table: `sales_invoice_items`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | |
| invoice_id | TEXT FK | → sales_invoices |
| product_id | TEXT FK | → sales_products |
| product_name | TEXT | Snapshot at invoice time |
| quantity | NUMERIC | Aggregated from DOs |
| unit_price | NUMERIC | |
| line_total | NUMERIC | |

### New Table: `sales_invoice_orders`
| Column | Type | Notes |
|--------|------|-------|
| invoice_id | TEXT FK | → sales_invoices |
| order_id | TEXT FK | → sales_orders |

### New Table: `sales_credit_notes`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | CN-YYMMDD-NNN |
| invoice_id | TEXT FK | → sales_invoices |
| credit_date | DATE | |
| amount | NUMERIC | |
| reason | TEXT | |
| return_id | TEXT FK | Optional → sales_returns |
| created_at | TIMESTAMPTZ | |

### Alter: `sales_customers`
- ADD `ssm_brn` TEXT
- ADD `tin` TEXT
- ADD `ic_number` TEXT
- ADD `address` TEXT
- ADD `payment_terms_days` INT DEFAULT 30
- Migrate existing `payment_terms` (credit→30, cash→0) then phase out old column

### Alter: `sales_orders`
- ADD `invoice_id` TEXT FK → sales_invoices

## Constraints

- Single HTML file architecture (sales.html) — all JS inline
- No build tools, no npm, no framework
- Must work on mobile (phone-first for supervisors)
- Supabase RLS on all new tables
- Document generation must support print + WhatsApp PNG share
- Must not break existing DO/CS/order workflows
