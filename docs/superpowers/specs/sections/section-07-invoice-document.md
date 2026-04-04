# Section 07: Invoice Document Generation

## Overview

This section implements the A4 invoice document generation function `generateInvoiceA4()`, along with print and PNG export (WhatsApp sharing). The invoice is a formal business document for TG Agro Fruits Sdn Bhd that consolidates one or more Delivery Orders into a single billing document. It includes company letterhead with logo, registration details, TIN, MSIC code, customer info, an items table, DO references, totals (including credit notes and payments), bank details, an e-Invoice placeholder, and a signature block.

**File to modify:** `sales.html`

## Dependencies

- **Section 01 (DB Migration):** `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, `sales_credit_notes` tables must exist.
- **Section 02 (Data Loading):** Global arrays `invoices`, `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes` must be loaded. Helper functions `invoiceBalance()` and `getInvoiceDOs()` must be available.
- **Section 05 (Create Invoice):** Invoices must be creatable so there is data to render.
- **Section 06 (Invoice List):** The invoice detail view provides the "Print/Share" button that triggers this function.

## Background Context

### Existing A4 Document Pattern

The codebase already has `soGenerateDocA4(orderId)` for Delivery Order / Cash Sales A4 documents. The invoice document follows the same architectural pattern:

1. Build HTML string with class-prefixed elements (e.g., `.a4-page`, `.a4-letterhead`, `.a4-items-table`)
2. Inject HTML into `#so-doc-a4-content` container
3. Show the document modal in A4 mode (`so-doc-modal` with class `a4-mode`)
4. Print via `window.print()` with `@page { size: A4; margin: 10mm; }` override
5. PNG export via `html2canvas` at 2x scale, then Web Share API or WhatsApp fallback

### Existing CSS Classes (Reusable)

All A4 styling is scoped under `#so-doc-a4-content` and already exists in `sales.html` inline styles:
- `.a4-page` -- min-height 267mm, page break between pages
- `.a4-letterhead` -- flex container with logo + company text
- `.a4-divider` -- 2px solid black horizontal rule
- `.a4-title` -- centered 18px bold title
- `.a4-doc-number` -- centered 14px bold document number
- `.a4-info-grid` -- 4-column grid for document metadata
- `.a4-items-table` -- full-width bordered table with header styling
- `.a4-totals` -- right-aligned totals section
- `.a4-grand-total` -- 16px bold with top border
- `.a4-sig-section` -- flex container for signature blocks
- `.a4-sig-block` -- 45% width signature area
- `.a4-footer` -- centered small text footer

These classes are reused directly. The invoice document needs only minor additions for invoice-specific elements (bank details box, DO reference line, e-Invoice placeholder).

### Company Details (Hardcoded)

- **Company:** TG AGRO FRUITS SDN. BHD.
- **Registration:** (201401034124 / 1110222-T)
- **TIN:** 24302625000
- **MSIC:** 46909
- **Address:** Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak
- **Phone:** 012-3286661
- **Bank:** Public Bank Berhad, A/C: 3243036710, TG Agro Fruits Sdn. Bhd.

### Key Data Relationships

An invoice has:
- `sales_invoice_items` -- aggregated product lines (product_name snapshot, qty, unit_price, line_total)
- `sales_invoice_orders` -- junction to linked DOs (order_id references)
- `sales_invoice_payments` -- payments recorded against the invoice
- `sales_credit_notes` -- credit adjustments against the invoice

The document displays items from `invoiceItems`, references DOs via `invoiceOrders` joined to `orders`, and shows totals accounting for `credit_total` and `amount_paid` from the invoice record.

### Global Variables and Helpers Available

- `invoices` -- array of all invoice records
- `invoiceItems` -- array of all invoice item records
- `invoiceOrders` -- array of all invoice-order junction records
- `orders` -- array of all order records (for DO doc_number lookups)
- `customers` -- array of all customer records
- `salesProducts` -- array of all product records
- `currentUser` -- logged-in user object with `displayName`
- `esc(str)` -- HTML-escapes a string (defined in `shared.js`)
- `fmtDate(dateStr)` -- formats date for display
- `invoiceBalance(inv)` -- returns `grand_total - credit_total - amount_paid`
- `soGetProductVariety(productId)` -- returns variety name for a product

## Tests (Manual Verification)

### Verify: A4 Layout

1. Open an existing invoice from the Invoice List (section 06) and click the Print/Share button.
2. Confirm the document modal opens in A4 mode.
3. Verify the following elements are present:
   - Logo (`assets/logo.png?v=2`) at top-left
   - "TG AGRO FRUITS SDN. BHD." in bold below logo
   - Company details line: Reg No: 1110222-T, TIN: 24302625000, MSIC: 46909
   - Address: Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak
   - "INVOICE" title centered, large and prominent
   - Invoice number and date displayed
   - Due date and payment terms displayed
   - Customer name shown; customer address shown if available
   - Customer SSM/TIN shown if available
   - Items table with columns: No., Description, Qty, Unit, Unit Price (RM), Amount (RM)
   - Product descriptions include variety and packing info (e.g., "MD2 Grade A (Box, 8pcs, 400-450g)")
   - Reference line listing all linked DO numbers with dates (e.g., "Ref: DO-260315-001 (15/03), DO-260318-002 (18/03)")
   - Totals section: Subtotal, Credit Notes (if any, shown as deduction), Grand Total (bold), Amount Paid (if any), Balance Due (bold, highlighted if > 0)
   - Bank details box: Public Bank Berhad, A/C: 3243036710, TG Agro Fruits Sdn. Bhd.
   - e-Invoice placeholder space (text: "e-Invoice: Pending")
   - Signature block: "Prepared By" with auto-filled name, "Authorized By" with blank signature line
   - Footer: "Thank you for your business"

### Verify: Print

1. Click the Print button in the document modal.
2. Browser print dialog opens with A4 page size.
3. The printed output matches the on-screen preview (no clipping, proper page breaks).

### Verify: PNG Export and WhatsApp Sharing

1. Click the Share button in the document modal.
2. A "Generating image..." notification appears.
3. On devices with Web Share API: the share sheet opens with the PNG image.
4. On devices without Web Share API: the image is copied to clipboard or a fallback is triggered.
5. The generated file is named with the invoice number (e.g., `INV-260403-001.png`).

### Verify: Edge Cases

- Invoice with zero credit notes and zero payments: Credit Notes line hidden, Amount Paid line hidden, Balance Due equals Grand Total.
- Invoice with credit notes: Credit Notes line shows as deduction (negative, e.g., "-RM 50.00").
- Invoice with partial payment: Amount Paid line shows, Balance Due is reduced.
- Invoice fully paid: Balance Due shows "RM 0.00" (no highlight).
- Customer with no address: address row omitted from info grid.
- Customer with no SSM/TIN: those fields omitted from info grid.

## Implementation Details

### 1. New Function: `generateInvoiceA4(invoiceId)`

Add this function in `sales.html` near the existing `soGenerateDocA4()` function (around line 5662). The function:

1. Looks up the invoice from the `invoices` array by ID.
2. Looks up the customer from `customers` by `invoice.customer_id`.
3. Filters `invoiceItems` for items belonging to this invoice.
4. Filters `invoiceOrders` for linked DOs, then maps to `orders` to get doc numbers and dates.
5. Builds a single-page A4 HTML string (invoices are single-copy, unlike DO/CS which have customer + office copies).
6. Injects into `#so-doc-a4-content` and shows the modal in A4 mode.

Function signature and docstring:

```javascript
/**
 * Generate A4 invoice document for printing / PNG export.
 * Renders into the existing #so-doc-a4-content container and shows so-doc-modal in a4-mode.
 * @param {string} invoiceId - The invoice ID (e.g., "INV-260403-001")
 */
function generateInvoiceA4(invoiceId) { ... }
```

### 2. Document Structure (HTML String)

The HTML string built inside `generateInvoiceA4` follows this structure. Use the same CSS classes as `soGenerateDocA4` for consistent styling.

**Header block** -- reuse `.a4-letterhead` with logo and company text. Add TIN and MSIC to the company details (these are not on the existing DO/CS A4 but are required for invoices):

```
TG AGRO FRUITS SDN. BHD.
(201401034124 / 1110222-T)
TIN: 24302625000 | MSIC: 46909
Lot 189, Kampung Riam Jaya, Airport Road, 98000 Miri, Sarawak
Tel: 012-3286661
```

**Title** -- use `.a4-title` with text "INVOICE". Below it, use `.a4-doc-number` with the invoice number.

**Info grid** -- use `.a4-info-grid` (4-column layout). Left column contains invoice metadata, right column contains customer details:

- Left: Invoice No, Invoice Date, Due Date, Payment Terms (formatted label like "Net 30")
- Right: Customer Name, Address (if available), SSM/BRN (if available), TIN (if available)

Payment terms formatting: map the `payment_terms` field value to a display label. The invoice stores a terms code (e.g., "30days"); display as "Net 30". If "cod", display as "COD". Alternatively, calculate from `payment_terms_days` on the customer record.

**Items table** -- use `.a4-items-table`. Columns: No., Description, Qty, Unit, Unit Price (RM), Amount (RM). For each item in `invoiceItems` filtered to this invoice:
- Description = product variety + product name + packing info (pcs_per_box, weight_range), matching the pattern in `soGenerateDocA4`
- Look up the product from `salesProducts` by `item.product_id` for unit and packing details
- Use `item.product_name` as fallback if product not found (snapshot field)

**DO reference line** -- after the items table, render a line listing all linked DO numbers:
```
Ref: DO-260315-001 (15/03), DO-260318-002 (18/03), DO-260320-003 (20/03)
```
Build by iterating `invoiceOrders` filtered to this invoice, looking up each order's `doc_number` and `delivery_date` (or `order_date`).

**Totals section** -- use `.a4-totals`:
- Subtotal: `invoice.subtotal`
- Credit Notes: only show if `invoice.credit_total > 0`, displayed as deduction (e.g., "Credit Notes: -RM 50.00" in red)
- Grand Total: `invoice.grand_total` using `.a4-grand-total` class
- Amount Paid: only show if `invoice.amount_paid > 0`
- Balance Due: `invoiceBalance(invoice)`, bold, highlighted with a background color if > 0

**Bank details box** -- add a bordered box below totals (styled inline or with a new class `.a4-bank-details`):
```
Payment to:
Public Bank Berhad
A/C: 3243036710
TG Agro Fruits Sdn. Bhd.
```
Style: 1px solid border, padding 8px, font-size 11px. Similar to the bank details box on 80mm CS receipts but adapted for A4.

**e-Invoice placeholder** -- a small section below bank details:
```
e-Invoice: Pending
```
This is reserved space for the future LHDN QR code. For now, just display the text in a muted style. If `invoice.lhdn_uuid` is populated (future), display the UUID and QR code instead.

**Signature block** -- use `.a4-sig-section` and `.a4-sig-block`:
- Left: "Prepared By" with `currentUser.displayName` auto-filled (no signature line)
- Right: "Authorized By" with blank signature line, name line, date line, and "Signature" label

**Footer** -- use `.a4-footer`: "Thank you for your business"

### 3. Additional CSS

Add minimal new CSS rules inside the existing `<style>` block for invoice-specific elements. These are scoped under `#so-doc-a4-content`:

- `.a4-bank-details` -- bordered box for bank payment info (1px solid #999, padding 10px, font-size 11px, margin-bottom 12px, background #fafafa)
- `.a4-do-ref` -- DO reference line styling (font-size 11px, color #555, margin 8px 0 14px, font-style italic)
- `.a4-einvoice-placeholder` -- muted text for e-Invoice section (font-size 10px, color #999, margin-bottom 16px)
- `.a4-balance-due` -- highlighted balance if > 0 (font-size 14px, font-weight 800, background #fff3cd, padding 4px 8px, display inline-block)

### 4. Print Integration

The existing `soPrintDoc()` function already handles A4 mode printing. When the modal has class `a4-mode`, it injects `@page { size: A4; margin: 10mm; }` and calls `window.print()`. No changes needed to `soPrintDoc()`.

### 5. PNG Export / Share Integration

The existing `soShareDoc()` function already handles A4 mode. It selects the first `.a4-page` element inside `#so-doc-a4-content`, renders it with `html2canvas` at 2x scale, and triggers the Web Share API. The only change needed is to set the share filename to the invoice number instead of the order doc number.

To support this, store the current document reference in a variable (e.g., `soDocCurrentRef`) when `generateInvoiceA4` is called, so `soShareDoc` can use it for the filename. Alternatively, update `soShareDoc` to detect invoice mode and pull the invoice number from the rendered content or a data attribute.

Suggested approach: set `soDocCurrentOrderId = null` and add a new variable `soDocCurrentInvoiceId = invoiceId` when entering invoice document mode. Then in `soShareDoc`, use this to determine the filename:

```javascript
var filename = soDocCurrentInvoiceId
  ? soDocCurrentInvoiceId + '.png'
  : (soDocCurrentOrderId ? /* existing order filename logic */ : 'document.png');
```

### 6. Triggering the Function

The invoice detail view (built in section 06) includes a "Print/Share" action button. That button should call `generateInvoiceA4(invoiceId)`. The function opens the document modal, and the modal's existing Print/Share buttons handle the rest.

### 7. Closing the Modal

The existing `closeDocModal()` function resets both `#so-doc-content` and `#so-doc-a4-content`. Add a reset for `soDocCurrentInvoiceId` alongside the existing `soDocCurrentOrderId = null` reset.

## Implementation Checklist

1. [x] Add new CSS classes (`.a4-bank-details`, `.a4-do-ref`, `.a4-einvoice-placeholder`, `.a4-balance-due`) to the inline `<style>` block in `sales.html`.
2. [x] Add `var soDocCurrentInvoiceId = null;` near the existing `soDocCurrentOrderId` variable declaration.
3. [x] Implement `generateInvoiceA4(invoiceId)` function that builds the full A4 HTML and shows the modal.
4. [x] Update `closeDocModal()` to reset `soDocCurrentInvoiceId`.
5. [x] Update `soShareDoc()` to use invoice number for the PNG filename when in invoice mode.
6. [x] Update `soDownloadDocImage()` and `soOpenWhatsAppDoc()` to handle invoice mode filenames and messages.
7. [x] Verify the Print/Share button in the invoice detail view (section 06) already calls `generateInvoiceA4` — confirmed, wired in section 06.

## Actual Implementation Notes

- **File modified:** `sales.html` only
- **Lines affected:** ~180 lines added for `generateInvoiceA4`, ~30 lines modified in share/download/WhatsApp functions
- **Deviations from plan:** Also updated `soDownloadDocImage()` and `soOpenWhatsAppDoc()` (not just `soShareDoc()`) to handle invoice mode — the spec mentioned `soShareDoc` but the filename/message logic exists in all three sharing functions
- **Code review fix:** Hoisted duplicate `var cust` declaration in `soOpenWhatsAppDoc` to function scope
- **Existing wiring confirmed:** Section 06 already has `generateInvoiceA4()` call on the Print button in invoice detail (line ~4636)
- **Print/thermal:** No changes needed to `soPrintDoc()` or `soPrintThermal()` — they already handle A4 mode generically
