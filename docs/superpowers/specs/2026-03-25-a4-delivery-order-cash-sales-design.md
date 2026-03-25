# A4 Delivery Order for Cash Sales Customers

**Date:** 2026-03-25
**Module:** Sales (`sales.html`)
**Approach:** Separate A4 template alongside existing 80mm receipt

---

## Problem

Cash sales customers currently receive the same 80mm thermal receipt-format document as credit (DO) customers. Cash sales customers need a proper A4-sized delivery order copy as their primary proof of purchase — professional, printable, and shareable via WhatsApp.

## Requirements

1. A4-sized (210mm x 297mm) delivery order document for cash sales orders
2. Two separate full-page copies: **Customer Copy** and **Office Copy**
3. Used both for physical printing and digital sharing (WhatsApp)
4. Same document number as the 80mm receipt, with "(A4)" appended
5. "Prepared By" auto-filled from logged-in user — no signature line
6. "Received By" with signature line for customer
7. Existing 80mm receipt remains unchanged and available for all orders

## Company Letterhead

```
[Logo]  TG AGRO FRUITS SDN. BHD.
        (201401034124 / 1110222-T)
        Lot 189, Kampung Riam Jaya, Airport Road,
        98000 Miri, Sarawak
        Tel: 012-3286661
```

## Document Layout

### Header
- Company logo (larger than 80mm version — ~80x80px)
- Company name, registration number, address, phone
- Horizontal rule divider

### Title Section
- Document title: "DELIVERY ORDER" (for CS doc type it still says delivery order)
- Document number: `{doc_number} (A4)` — e.g. "CS-00123 (A4)"
- Copy label: "CUSTOMER COPY" or "OFFICE COPY"

### Customer Information (2-column grid)
- Customer name
- Phone number (if available)
- Address (if available)
- Date (delivery date or order date)
- Order date
- Driver name (if delivery fulfillment with assigned driver)

### Items Table

| No. | Description | Qty | Unit | Price (RM) | Amount (RM) |
|-----|-------------|-----|------|------------|-------------|
| 1   | MD2 Pineapple | 100 | pcs | 2.50 | 250.00 |

- Sequential row numbering
- Description = variety + product name (same as current logic)
- Qty and Unit in separate columns
- Right-aligned monetary values

### Totals Section (right-aligned)
- Subtotal
- Returns (only shown if > 0, in red with negative sign)
- Grand Total (bold, prominent)

### Payment & Acknowledgement Section
- Payment method: "CASH"
- Payment status: PAID / PARTIAL / UNPAID
- Prepared By: `{currentUser.displayName}` (text only, no signature line)
- Received By: signature line, name line, date line

### Footer
- "Thank you for your business"

## Two-Page Output

- **Page 1:** Full A4 document labeled "CUSTOMER COPY"
- **Page 2:** Identical content labeled "OFFICE COPY"
- Printing: CSS `page-break-before: always` on second copy
- Sharing (WhatsApp): Only the **Customer Copy** is shared (office copy is for internal filing and unnecessary in WhatsApp). html2canvas renders just the first copy block.

## UI Integration

### Order Detail View (`sales.html` ~line 1541)
- Inside the existing `if (o.status === 'completed')` block (which already shows "View Document"):
  - Add an **additional inner condition**: if `o.doc_type !== 'delivery_order'` (i.e. cash sales), render a second button **"A4 Document"** beside "View Document"
  - The existing "View Document" button (80mm receipt) remains for ALL completed orders
- For completed DO (credit) orders: no change — only "View Document" (80mm)

### Document Modal
- Reuse existing `#so-doc-modal` structure
- Add new content container `#so-doc-a4-content` alongside existing `#so-doc-content`
- A4 container has width: 210mm
- **Content switching logic:**
  - When `soGenerateDocA4()` is called: hide `#so-doc-content` (`display:none`), show `#so-doc-a4-content`
  - When `soGenerateDoc()` is called: hide `#so-doc-a4-content` (`display:none`), show `#so-doc-content`
  - `closeDocModal()` must reset both containers (clear innerHTML of both, hide both)
- Same toolbar: Close, Print, Share buttons

## Technical Implementation

### New Function: `soGenerateDocA4(orderId)`
- Located after existing `soGenerateDoc()` (~line 4740)
- Fetches same data: order, customer, items, products, workers
- Builds A4-formatted HTML with letterhead, table, signature blocks
- Generates both Customer Copy and Office Copy in one HTML block
- Renders into `#so-doc-a4-content`
- Opens the document modal

### New Styles (scoped under `#so-doc-a4-content`)
- Width: 210mm
- Padding: 15mm
- Font: Arial/sans-serif (professional, not monospace)
- Font sizes: 14px header, 12px body, 10px fine print
- Table: bordered, alternating row shading optional

### Print Media Query Switching
The existing `@media print` block hardcodes `@page { size: 80mm auto; }`. To support both formats:
- Add a class `.a4-mode` on `#so-doc-modal` when A4 content is active
- CSS rules:
  - Default (no class): `@page { size: 80mm auto; margin: 0; }` — existing behavior
  - `.a4-mode` present: `@page { size: A4; margin: 10mm; }` and `#so-doc-a4-content { width: 210mm; }`
- `soGenerateDocA4()` adds `.a4-mode` class; `soGenerateDoc()` removes it; `closeDocModal()` removes it

### Modified Functions
- `soPrintDoc()` — no changes needed; the `.a4-mode` class on the modal controls `@page` size via CSS
- `soShareDoc()` — detect active content element: use `#so-doc-a4-content` if visible, else `#so-doc-content`; html2canvas renders whichever is active
- `soDownloadDocImage()` — filename includes "(A4)" suffix when A4 content is active, e.g. `CS-00123 (A4).png`

### Data Source
- `currentUser.displayName` — for "Prepared By" field
- All other data from existing variables: `orders`, `customers`, `orderItems`, `salesProducts`, `allWorkers`

### No Database Changes
- No new tables or columns required
- All data already exists in current schema

## What Stays Unchanged
- Existing 80mm receipt template and styles
- `soGenerateDoc()` function — untouched
- DO (credit) customer workflow — no A4 option
- Share/WhatsApp infrastructure — reused, not replaced
- Document numbering system — same numbers, "(A4)" is display-only suffix

## Known Limitations (v1)

- **Page overflow for large orders:** If an order has 30+ items, the items table may overflow a single A4 page per copy. For v1 this is acceptable — CSS `break-inside: avoid` on table rows will keep rows intact but no table header repetition on continuation pages.
- **Company name format:** The A4 document uses the official SSM-registered name "TG AGRO FRUITS SDN. BHD." (with periods). The existing 80mm receipt uses "TG AGRO FRUITS SDN BHD" (no periods) — this is intentional; the A4 version uses the formal registered name.
