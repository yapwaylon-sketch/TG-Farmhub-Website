# Sales Invoicing — Research Findings

## Part 1: Codebase Analysis (sales.html)

### Document Generation Patterns

**80mm Thermal (`soGenerateDoc()`)** — lines 5393-5514
- HTML-based, inline CSS, 200px width
- Sections: logo header → doc type/number → customer info grid → items table → totals → payment info → footer
- Uses `esc()` for XSS prevention, `soGetProductVariety()` for variety names
- Output: `window.print()`, RawBT thermal (mobile), PNG via html2canvas

**A4 Document (`soGenerateDocA4()`)** — lines 5515-5662
- Full letterhead: logo + company details (name, reg no, address)
- Generates 2 copies (Customer + Office) in one HTML block
- Items table: No., Description, Qty, Unit, Price, Amount
- Signature block: "Prepared By" (auto-filled) + "Received By" (blank)
- Uses `a4-*` CSS classes, `@page { size: A4; margin: 10mm; }`

**Payment Slip (`soGeneratePaymentSlip()`)** — lines 5889-5982
- 80mm format, shows breakdown by method (cash/bank/cheque)
- Allocation table: which orders the payment was applied to
- Lists remaining outstanding orders for the customer

**PNG Export Pattern:**
1. `html2canvas(element)` → canvas
2. Canvas → JPEG blob (80% quality, max 1200px width)
3. Upload to Supabase Storage or share via Web Share API

### Payment Tracking

**`recalcPaymentStatus(orderId)`** — lines 3419-3427
- Sums all `sales_payments` for the order
- Auto-sets: unpaid (0), partial (0 < paid < total), paid (paid >= total)

**`orderBalance(o)`** — `grand_total - amount_paid`

**Payment Recording (`paySavePayment()`)** — lines 3819-3910
- Multi-method support (cash+bank_transfer combined)
- Batch: single payment split across multiple orders (smallest first)
- Each order gets separate payment record
- After save: recalc status, update DB, generate slip

### Database Patterns

**`sbQuery()`** (shared.js 136-162) — wrapper for all Supabase calls
- Auto-retry with exponential backoff (max 3 attempts)
- Offline detection (returns null)
- Error notifications to user
- All errors return null (no exceptions)

**`dbNextId(prefix)`** (shared.js 358-367) — calls `next_id` RPC
- Returns e.g. `DO-260401-001` (date-based sequence)
- Prefixes: SO, SI, SC, SP, SY, SR, DO, CS, DN

**`loadAllData()`** (lines 1032-1055) — Promise.all parallel loading of 10 tables

### Current Invoicing Tab (QB Bridge)

**`renderInvoicing()`** — lines 3964-4101
- Section A: uninvoiced DOs grouped by customer, checkboxes, billing summary
- Section B: invoice history grouped by QB invoice number
- `invRenderBillingSummary()` — aggregates selected DOs by product (qty, avg price, total)
- `invSaveInvoice()` — stores QB number on `sales_orders.qb_invoice_no`

**Key: No separate invoice entity exists.** Just a QB reference on orders.

### Existing Table Schemas

**sales_customers:** id, name, contact_person, phone (UNIQUE), address, type (wholesale/retail/walkin), channel, payment_terms (credit/cash), notes, is_active

**sales_orders:** id, customer_id, order_date, delivery_date, doc_type (delivery_order/cash_sales), doc_number, status, driver_id, subtotal, returns_total, grand_total, amount_paid, payment_status, qb_invoice_no, qb_invoiced_at, prep_photo_url, delivery_photo_url, notes, created_by

**sales_order_items:** id, order_id, product_id, quantity, unit_price, line_total, index_min, index_max, notes

**sales_payments:** id, order_id, amount, payment_date, method, reference, slip_url, notes, created_by

**sales_returns:** id, order_id, item_id, quantity, amount, reason, resolution (deduct/refund/debit_note), debit_note_no, debit_note_used_on, photo_url, created_by

### Tab Switching

`switchTab(tab)` → resets detail views → updates URL hash → calls `renderCurrentTab()` which dispatches to the correct render function.

### Key Patterns for New Invoicing

1. Document generation is fully client-side HTML
2. All queries use `sbQuery()` wrapper — never raw Supabase calls
3. ID generation via `dbNextId()` with prefixes
4. Billing summary already aggregates products from selected DOs — reusable pattern
5. A4 + 80mm + PNG export all supported
6. Payment tracking is per-order with auto status recalc

---

## Part 2: Malaysia e-Invoice (LHDN MyInvois)

### API Overview

- REST API, supports JSON and XML (UBL 2.1 standard)
- 15 APIs in two categories: e-Invoice APIs + Platform APIs
- OAuth 2.0 Client Credentials Flow for authentication
- Sandbox: `https://preprod.myinvois.hasil.gov.my/`
- Production: `https://myinvois.hasil.gov.my/`

### 55 Mandatory Fields (Version 4.6)

**Supplier:** Name, TIN, Registration No, SST Reg (or "NA"), MSIC Code, Business Activity Description, Address, Contact
**Buyer:** Name, TIN (or "EI00000000010" for B2C/foreign), Registration No, SST Reg, Address, Contact
**Invoice Header:** Version, Type Code (01=Invoice, 02=Credit Note, 03=Debit Note), Number, Date/Time, Currency, Digital Signature
**Line Items:** Classification Code (3-char IRBM code), Description, Unit Price, Quantity, UOM, Subtotal, Discount, Tax Type (E=Exempt), Tax Rate, Tax Amount
**Totals:** Total Excl Tax, Total Discount, Total Tax, Total Net, Total Payable

### Document Type Codes

| Code | Type |
|------|------|
| 01 | Invoice |
| 02 | Credit Note |
| 03 | Debit Note |
| 04 | Refund Note |
| 11 | Self-billed Invoice |
| 12 | Self-billed Credit Note |
| 13 | Self-billed Debit Note |

### Digital Signing

- XAdES standard, SHA-256 hash
- Requires digital certificate from licensed Malaysian CA (Pos Digicert, MSC Trustgate, etc.)
- Soft Certificate: ~RM 1,500/year
- Certificate must be on server that signs documents

### Validation Flow

1. Sign document (XAdES/SHA-256)
2. POST to `/api/v1.0/documentsubmissions` (base64-encoded doc + hash)
3. LHDN validates → returns: UUID, longId, Status, DateTimeValidated, QR code URL
4. QR URL format: `https://myinvois.hasil.gov.my/{longId}/share`
5. 72-hour cancellation/rejection window
6. After 72h: adjustments only via Credit Note/Debit Note

### Timeline for TG Agro Fruits

| Phase | Revenue | Date | Grace Period |
|-------|---------|------|-------------|
| Phase 3 | RM 5M-25M | 1 Jul 2025 | 31 Dec 2025 |
| Phase 4 | RM 1M-5M | 1 Jan 2026 | 31 Dec 2026 |
| Below RM 1M | Exempt | Cancelled | — |

**TG Agro Fruits:** If annual revenue > RM 1M, mandatory from Jan 2026 with 12-month grace (no penalties in 2026). If < RM 1M, currently exempt.

### SST & Agricultural Exemption

- Local pineapples are NOT subject to Sales Tax (MOF confirmed)
- Tax Type on e-Invoice: "E" (Exempt)
- SST exemption does NOT exempt from e-Invoice mandate (revenue-based obligation)
- TG Agro Fruits SST Registration: "NA" on e-Invoice submissions

### Credit Notes in e-Invoice

- Type Code 02
- Must reference original e-Invoice UUID (mandatory field)
- One CN can adjust multiple original invoices
- If within 72 hours: cancel original + re-issue instead
- After 72 hours: must use CN/DN (cannot cancel)

### Self-Billed Invoices

- Relevant if buying from individual farmers/smallholders
- Buyer issues invoice on behalf of supplier
- Type Code 11
- Roles reversed in submission

### Open Source Resources

- `amaseng/myinvois-open-sdk` — TypeScript client (closest to our stack)
- `klsheng/myinvois-php-sdk` — PHP with full examples
- Official Postman collection available for API testing
- Recommended architecture: middleware/gateway that accepts simple JSON → handles UBL/signing

---

## Part 3: Invoice Document Design (Malaysian Standards)

### Required Fields (Non-SST Registered)

- Title: "INVOICE" (not "Tax Invoice" since not SST-registered)
- Invoice number (unique sequential)
- Invoice date
- Seller: company name, reg no, TIN, address, contact
- Buyer: name, address
- Line items: description, qty, unit price, line total
- Total amount
- Currency (MYR)

### Standard Malaysian Invoice Layout

```
[Logo]  COMPANY NAME SDN BHD
        Reg No: 1110222-T | TIN: 24302625000
        Address line 1, City, Postcode, State
        Tel: xxx | Email: xxx

        INVOICE

Invoice No: INV-260403-001     Date: 03/04/2026
Terms: Net 30                   Due: 03/05/2026

BILL TO:
Customer Name
SSM/IC: xxx
Address

No. | Description      | Qty  | Unit Price | Amount (RM)
1   | MD2 Grade A     | 120  | 45.00      | 5,400.00
2   | MD2 Grade B     |  80  | 35.00      | 2,800.00

Reference: DO-260315-001, DO-260318-002, DO-260322-001

                                    Subtotal: RM 8,200.00
                                       TOTAL: RM 8,200.00

Bank: Public Bank Berhad
Account: TG Agro Fruits Sdn. Bhd. — 3243036710

[LHDN QR Code]  UUID: xxxxxxxx-xxxx  (future)
```

### Statement of Account Format

- Header: company letterhead + "STATEMENT OF ACCOUNT" + period
- Customer section: name, address, credit terms
- Transaction table: Date, Doc No, Description, Debit, Credit, Balance (running)
- Footer: total outstanding, aging summary (Current/30/60/90+), bank details
- Note: "If payment has been made, please disregard this statement"

### Credit Note Format

- Title: "CREDIT NOTE"
- CN number, date
- Original invoice reference (mandatory)
- Reason for credit
- Line items being credited
- Net credit amount
- For e-Invoice: must include original UUID

### QR Code Placement

- Bottom-right corner (A4) or bottom-center (80mm)
- Minimum 2cm × 2cm
- Label: "Scan to Verify" or "LHDN Validated"
- UUID must also appear in text (QR alone not sufficient)
- Only print QR on validated invoices (never before LHDN confirms)
