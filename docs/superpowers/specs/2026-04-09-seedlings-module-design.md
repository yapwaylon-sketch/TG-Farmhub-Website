# Oil Palm Seedlings Module — Design Spec

**Date:** 2026-04-09
**Module:** `seedlings.html` (single HTML file, same pattern as other modules)
**Company:** TG Agribusiness (`tg_agribusiness`)
**MPOB License:** NN (Nursery Site) — No. Lesen MPOB: 522231011000

---

## 1. Overview

Batch-based oil palm seedling management system covering the full lifecycle from seed purchase to customer collection. Core focus areas: batch inventory tracking, booking management with deposit/payment controls, collection with L3.1 certificate tracking, and MPOB monthly reporting.

### What's In Scope (Initial Build)
- Batch management (create, lifecycle, culling logs, doubleton/tripleton gains)
- Customer management (with cross-company duplicate detection)
- Booking management (deposit, payment tracking, batch allocation, collection control)
- Collection/walk-in sales (L3.1 tracking, photos, payment recording)
- Monthly reporting (MPOB format: planted, culled, sold, balance)
- Granular permissions (full access by default, lockable per section)

### KIV (Future)
- Dashboard with at-a-glance metrics
- Spray/fertilizer records for nursery batches (separate from pineapple spray tracker)
- Growth measurements (height, girth, leaf count)
- Cost tracking per batch
- Invoice generation (invoices currently issued outside the system)

---

## 2. Business Rules

### MPOB Regulations
- Cannot sell seedlings younger than **10 months** (seedlings <10 months can only be sold to other licensed nurseries)
- Every seedling sold must be accompanied by an **L3.1 certificate** (Borang Akuan Jualan dan Penerimaan Bahan Tanaman Kelapa Sawit)
- L3.1 is a **pre-printed physical booklet** from MPOB with serial numbers — system tracks usage, does not generate the form
- Monthly report submitted to MPOB via their portal (system generates data, staff keys into MPOB system)
- All planting material must be traceable to its seed source

### Batch Rules
- One batch = one seed purchase/delivery from one supplier
- Batch number format: `{sequence}-{year}` (e.g., `1-2026`, `2-2026`) — auto-generated, sequential within year
- Each batch has one variety/cross (e.g., DxP, Deli Dura x Avros)
- Each batch has a physical field/block location in the nursery
- Booking opens from the day seeds are planted
- Seedlings become sellable at 10+ months (MN only — no pre-nursery sales)
- **Allocation rule**: default 50% of seeds planted = maximum bookable qty (configurable per batch). Remaining 50% reserved for walk-in/cash sales + culling buffer
- Allocation % stored as a system setting, can be changed anytime

### Doubleton/Tripleton Handling
- Doubletons (2 shoots from 1 seed) and tripletons (3 shoots) are **split and kept** — they increase the count above original seeds planted
- Recorded at transplant as "bonus" seedlings gained

### Booking & Payment Rules
- One booking = one customer, one batch
- Customer wanting seedlings from multiple batches → multiple bookings
- Minimum deposit: 50% (flexible — system warns if below 50% but allows override)
- **Collection is controlled by payment**: customer cannot collect more seedlings than what they've paid for
  - Example: 500 seedlings @ RM20 = RM10,000. Paid RM5,000 → can collect max 250 seedlings
- Customer may top up deposit or pay balance at any time (including at collection)
- Collections are partial — customer may collect in multiple trips over time
- Each collection event issues one L3.1 page
- Batch can be reassigned if shortfall from culling (booking moved to another batch)

### Cash/Walk-in Sales
- Very common — smallholders buying without prior booking
- Same L3.1 issuance per transaction
- Payment at collection (no deposit/booking flow)

### Pricing
- Default price set per batch (varies by variety/batch)
- Can be overridden per booking/transaction

---

## 3. L3.1 Certificate — Fields to Track

Reference: "Borang Akuan Jualan dan Penerimaan Bahan Tanaman Kelapa Sawit" — Peraturan 21(1), Akta 582

### Seller Side (MAKLUMAT PENJUAL) — Pre-filled / Constant
| # | Field | Value |
|---|-------|-------|
| 1 | Nama Pemegang Lesen | TG AGRIBUSINESS |
| 2 | Alamat | Lot 174, Block 9, Lambir Land District, 98000 Miri, Sarawak |
| 3 | No. Lesen MPOB | 522231011000 |
| 4 | No. Sijil CoPN | (if applicable) |
| 5 | Jumlah Unit Dijual | Qty by type (Anak Benih Kelapa Sawit) |
| 6 | Sumber Bekalan Bahan Tanaman | Seed source (from batch record) |
| 7 | Tarikh Belian Bahan Tanaman | Date seeds were purchased (from batch) |
| 8 | No. Invois / Nota Penghantaran | Invoice/DO number, delivery date |
| 9 | Jenama Bahan Tanaman | Variety/cross (from batch, e.g., "Deli Dura x Avros") |

### Buyer Side (MAKLUMAT PEMBELI) — Per Customer/Collection
| # | Field | DB Column |
|---|-------|-----------|
| 1 | Nama | Customer name |
| 2 | Alamat | Customer address |
| 3 | No. Lesen / No. Syarikat / No. Kad Pengenalan | License/company reg/IC |
| 4 | Jumlah Unit Dibeli | Qty collected this transaction |
| 5 | Premis penanaman kelapa sawit | Planting location/estate |
| 7 | Keluasan (hektar) | Area in hectares |
| 8 | No. Resit Belian (jika ada) | Receipt/invoice number |

### System Tracking Per L3.1 Entry
- L3.1 serial number (from pre-printed booklet)
- Date issued
- Customer ID (FK)
- Booking ID (FK, nullable — null for walk-in cash sales)
- Batch ID (FK)
- Quantity collected
- Payment received at this collection
- Photo of loaded seedlings (optional)
- Photo of L3.1 page (optional)

---

## 4. Database Schema

### `seedling_suppliers`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `SS001`, `SS002` via dbNextId() |
| company_id | TEXT | Always `tg_agribusiness` |
| name | TEXT | Supplier name (e.g., "IOI", "Sime Darby Seeds") |
| address | TEXT | |
| phone | TEXT | |
| license_no | TEXT | Supplier's MPOB license number |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### `seedling_batches`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `AB-SB001` via dbNextId() |
| company_id | TEXT | Always `tg_agribusiness` |
| batch_number | TEXT | Display number: `1-2026`, `2-2026` (auto-generated) |
| supplier_id | TEXT FK | → seedling_suppliers |
| supplier_l31_no | TEXT | L3.1 serial number from supplier's form (received with seeds) |
| supplier_do_no | TEXT | Supplier's delivery order / invoice number |
| variety | TEXT | e.g., "DxP", "Deli Dura x Avros" |
| seed_source_desc | TEXT | Freetext — seed source as written on L3.1 (e.g., "Dr IOI") |
| qty_seeds_received | INT | Original seed count received |
| qty_pre_nursery | INT | Seedlings currently in pre-nursery (computed or updated) |
| qty_transplanted | INT | Seedlings moved to main nursery |
| qty_doubletons_gained | INT | Extra seedlings from doubletons/tripletons |
| qty_culled_total | INT | Total culled across all stages |
| qty_sold_total | INT | Total collected/sold |
| qty_available | INT | Current sellable stock (computed) |
| qty_booked | INT | Currently committed to bookings (computed) |
| allocation_pct | INT | Bookable % of seeds (default 50, configurable) |
| qty_allocation | INT | Computed: floor(qty_seeds_received × allocation_pct / 100) |
| date_received | DATE | When seeds arrived |
| date_planted | DATE | When planted into pre-nursery |
| date_transplanted | DATE | When moved to large bags |
| date_sellable | DATE | Computed: date_planted + 10 months |
| field_block | TEXT | Physical location in nursery |
| price_per_seedling | NUMERIC | Default price for this batch |
| status | TEXT | `pre_nursery`, `main_nursery`, `selling`, `sold_out`, `closed` |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### `seedling_batch_events`
Tracks all inventory-changing events on a batch (culling, transplant, adjustments).

| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `AB-SE001` via dbNextId() |
| batch_id | TEXT FK | → seedling_batches |
| event_type | TEXT | `cull`, `transplant`, `doubleton_gain`, `adjustment` |
| qty | INT | Number affected (positive for gains, negative for losses) |
| reason | TEXT | Culling reason, adjustment note, etc. |
| event_date | DATE | When it happened |
| logged_by | TEXT | User who logged it |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | |

### `seedling_customers`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `AB-SC001` via dbNextId() |
| company_id | TEXT | `tg_agribusiness` |
| name | TEXT | |
| address | TEXT | |
| phone | TEXT | Partial unique index WHERE NOT NULL |
| ic_number | TEXT | IC / Kad Pengenalan |
| company_reg | TEXT | No. Syarikat (company registration) |
| license_no | TEXT | MPOB license number (for estate buyers) |
| planting_location | TEXT | Premis penanaman (estate/farm name + location) |
| planting_area_ha | NUMERIC | Keluasan in hectares |
| customer_type | TEXT | `estate`, `smallholder`, `agent`, `government` |
| linked_customer_id | TEXT | FK → sales_customers (cross-company link, nullable) |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### `seedling_bookings`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `AB-BK001` via dbNextId() |
| company_id | TEXT | `tg_agribusiness` |
| customer_id | TEXT FK | → seedling_customers |
| batch_id | TEXT FK | → seedling_batches |
| qty_booked | INT | Seedlings reserved |
| price_per_seedling | NUMERIC | Agreed price (can override batch default) |
| total_amount | NUMERIC | qty_booked × price_per_seedling |
| total_paid | NUMERIC | Sum of all payments (computed or updated) |
| total_collected | INT | Sum of all collections (computed or updated) |
| qty_collectible | INT | Computed: floor(total_paid / price_per_seedling) - total_collected |
| status | TEXT | `active`, `completed`, `cancelled` |
| booking_date | DATE | |
| expected_ready_date | DATE | When seedlings will be 10+ months |
| invoice_no | TEXT | Optional — external invoice reference |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### `seedling_payments`
| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `AB-SP001` via dbNextId() |
| booking_id | TEXT FK | → seedling_bookings (nullable for cash sales) |
| collection_id | TEXT FK | → seedling_collections (nullable — payment can be deposit before any collection) |
| customer_id | TEXT FK | → seedling_customers |
| amount | NUMERIC | |
| payment_method | TEXT | `cash`, `bank_transfer`, `cheque` |
| payment_date | DATE | |
| reference | TEXT | Bank ref, cheque number, etc. |
| slip_url | TEXT | Payment slip photo URL |
| notes | TEXT | |
| created_at | TIMESTAMPTZ | |

### `seedling_collections`
Each collection event = one L3.1 issued.

| Column | Type | Notes |
|--------|------|-------|
| id | TEXT PK | `AB-CL001` via dbNextId() |
| company_id | TEXT | `tg_agribusiness` |
| customer_id | TEXT FK | → seedling_customers |
| booking_id | TEXT FK | → seedling_bookings (nullable for walk-in cash sales) |
| batch_id | TEXT FK | → seedling_batches |
| l31_serial_no | TEXT | Pre-printed L3.1 serial number |
| qty_collected | INT | Seedlings collected this trip |
| price_per_seedling | NUMERIC | Price applied |
| subtotal | NUMERIC | qty × price |
| payment_received | NUMERIC | Amount paid at this collection |
| collection_date | DATE | |
| collected_by | TEXT | Person who collected (driver/customer name) |
| photo_url | TEXT | Photo of loaded seedlings |
| l31_photo_url | TEXT | Photo/scan of the filled L3.1 page |
| invoice_no | TEXT | Optional external invoice reference |
| transport_fee | NUMERIC | Optional delivery charge |
| notes | TEXT | |
| logged_by | TEXT | Staff who processed |
| created_at | TIMESTAMPTZ | |

---

## 5. UI Layout — Sidebar Tabs

Same sidebar pattern as other modules. Tabs:

| Tab | Content |
|-----|---------|
| **Batches** | Batch list (cards or table), create/edit batch, batch detail (lifecycle, events, inventory, bookings against it, collections from it) |
| **Bookings** | Active bookings list, create booking, booking detail (payments, collections, L3.1 history) |
| **Collections** | Collection log (all L3.1 issuances), record new collection (walk-in or from booking) |
| **Customers** | Customer list, create/edit (with cross-company detection), customer detail |
| **Suppliers** | Supplier list, create/edit |
| **Reports** | MPOB Monthly Report, Batch Summary, Cash Flow Projection |

---

## 6. Key Workflows

### 6.1 Create New Batch
1. Select supplier (or create new)
2. Enter: variety, qty seeds, date received, date planted, supplier L3.1 no, supplier DO no, seed source description, field block, price per seedling
3. Batch number auto-generated (`{next seq}-{year}`)
4. Status: `pre_nursery`
5. `date_sellable` auto-calculated: `date_planted + 10 months`

### 6.2 Transplant (Month ~4)
1. Open batch → "Record Transplant" action
2. Enter: date, qty transplanted to large bag, qty culled, qty doubletons/tripletons gained
3. Creates batch events (transplant + cull + doubleton_gain)
4. Updates batch: qty_transplanted, qty_culled_total, qty_doubletons_gained
5. Status changes to `main_nursery`
6. qty_available recalculated

### 6.3 Log Culling
1. Open batch → "Log Culling" action
2. Enter: date, qty culled, reason (freetext or from common list)
3. Creates batch event
4. Updates batch qty_culled_total, qty_available

### 6.4 Create Booking
1. Select customer (or create new with cross-company check)
2. Select batch → shows available qty and allocation remaining
3. Enter: qty, price per seedling (pre-filled from batch default, overridable per customer)
4. System warns if booking would exceed batch allocation (allocation_pct of seeds)
5. System warns if deposit below 50%
6. Record initial deposit payment
7. Status: `active`, expected_ready_date from batch
8. **Generate booking slip** — printable/shareable document (print + WhatsApp image)

### 6.5 Record Collection (Booked Customer)
1. Select booking → shows: qty booked, total paid, total collected, qty collectible
2. **System enforces**: cannot collect more than `floor(total_paid / price) - total_collected`
3. If customer wants to collect more → must top up payment first (can do inline)
4. Enter: qty to collect, L3.1 serial number, payment received (if any top-up)
5. Capture photos (seedlings + L3.1 page)
6. Optional: invoice number, transport fee
7. Creates collection record + payment record (if payment received)
8. Updates booking totals + batch qty_sold_total + qty_available
9. If fully collected → booking status = `completed`

### 6.6 Walk-in Cash Sale
1. Select or create customer
2. Select batch → shows available (uncommitted) qty
3. Enter: qty, price, L3.1 serial number
4. Record payment (expected: full payment)
5. Capture photos
6. Creates collection record (no booking_id) + payment record
7. Updates batch qty_sold_total + qty_available

### 6.7 Monthly MPOB Report
1. Select month/year
2. System generates:
   - **Seeds planted/purchased**: batches created in this period (qty_seeds_received)
   - **Culled/destroyed**: sum of cull events in this period (by batch)
   - **Sold**: sum of collections in this period (qty, customer name, L3.1 serial numbers)
   - **Balance**: current qty_available across all active batches
3. Display as printable table matching MPOB portal fields
4. Staff manually keys into MPOB system

### 6.8 Cash Flow Projection Report
Monthly breakdown showing:
- **Booking payments**: deposits + balance payments received per month
- **Cash sales**: walk-in revenue per month
- **Grand total**: combined monthly income
- **Projected**: upcoming balance payments due (from active bookings with outstanding balances)
- Filter by year, scrollable month-by-month view

### 6.9 Booking Slip Generation
1. After booking is created (or from booking detail → "Print Slip" button)
2. System renders booking slip document (see Section 14)
3. Options: Print (browser print) / Share (WhatsApp image)
4. Can be regenerated anytime from booking detail

---

## 7. Batch Status Flow

```
pre_nursery → main_nursery → selling → sold_out → closed
```

| Status | Trigger |
|--------|---------|
| `pre_nursery` | Batch created |
| `main_nursery` | Transplant recorded |
| `selling` | Auto when `date_sellable` reached (or manual) |
| `sold_out` | qty_available reaches 0 |
| `closed` | Manual — batch lifecycle complete |

---

## 8. Customer Cross-Company Detection

When creating a new seedling customer:
1. User enters name and/or phone
2. System searches `sales_customers` (Agro Fruits) for matches by phone number (exact) or name (fuzzy/partial)
3. If match found → show: "This customer already exists under TG Agro Fruits. Link them?"
4. If linked → `linked_customer_id` set on the seedling customer record
5. Each company's customer list remains independent — no auto-import
6. Linking is informational only (no data sharing, just a reference)

---

## 9. Permissions (in hub User Management)

Module: `seedlings` under TG Agribusiness

| Permission Key | Controls |
|----------------|----------|
| `view` | Access to module |
| `manageBatches` | Create/edit batches, log events |
| `manageBookings` | Create/edit bookings |
| `recordCollections` | Process collections, record L3.1 |
| `manageCustomers` | Create/edit customers |
| `manageSuppliers` | Create/edit suppliers |
| `viewReports` | Access reports tab |

Admin always has full access. Other users get all by default, with ability to revoke per permission.

---

## 10. Photo Storage

- Supabase Storage bucket: `seedling-photos`
- Paths: `collections/{collection_id}/seedlings.jpg`, `collections/{collection_id}/l31.jpg`
- Same resize logic as sales module (max 1200px, JPEG 80%)
- Payment slips: `seedling-photos/payment-slips/{payment_id}.jpg`

---

## 11. Document Numbering

All IDs use `dbNextId()` with company prefix `AB-`:

| Entity | Prefix | Example |
|--------|--------|---------|
| Supplier | AB-SS | AB-SS001 |
| Batch | AB-SB | AB-SB001 |
| Batch Event | AB-SE | AB-SE001 |
| Customer | AB-SC | AB-SC001 |
| Booking | AB-BK | AB-BK001 |
| Payment | AB-SP | AB-SP001 |
| Collection | AB-CL | AB-CL001 |

Batch display number is separate: `1-2026`, `2-2026` (not the ID).

---

## 12. Mobile Considerations

- Collection workflow must be mobile-friendly (similar to delivery.html)
- Photo capture: camera + gallery options
- L3.1 serial number input: text field (manual entry from physical booklet)
- Key actions on mobile: record collection, capture photos, view booking status
- Could be inline in seedlings.html (responsive) or separate page (TBD based on complexity)

---

## 13. Company Address Constants

Two addresses used for different documents:

### Office Address (Booking Slips)
```
TG AGRIBUSINESS
Lot 1609, Kpg. Riam Jaya, 98000 Miri, Sarawak
Tel: 085-615253  Fax: 085-616966
```

### Farm/License Address (L3.1 Certificate)
```
Nama Pemegang Lesen: TG AGRIBUSINESS
Alamat: Lot 174, Block 9, Lambir Land District, 98000 Miri, Sarawak
Tel: 085-615253  Fax: 085-616966
No. Lesen MPOB: 522231011000
```

Stored as constants in the module JS, not in the database.

---

## 14. Booking Slip — Printable Document

Generated after booking creation. Printable (browser print) + shareable (WhatsApp image via html2canvas).

### Layout (based on existing physical form)
```
                    TG AGRIBUSINESS
     Lot 1609, Kpg. Riam Jaya, 98000 Miri, Sarawak
              Tel: 085-615253  Fax: 085-616966

              Oil Palm Seedlings Booking
                                          No. AB-BK001

Mr/Ms: [Customer Name]                   Date: DD/MM/YYYY

| Quantity | Description          | Unit Price | Amount (RM) |
|----------|----------------------|------------|-------------|
| 100      | Oil Palm Seedlings   | 20.00      | 2,000.00    |
|          | Transportation       |            |             |

MPOB already/not issued.                 Total RM: 2,000.00
MPOB No: ________                        Deposit Paid: 1,000.00
Plants Collection Date: ________         Balance RM: 1,000.00

Contact Information:
Name: [name]              I/C No: [ic]
Address: [address]        Phone: [phone]

Batch: [batch_number] — [variety]
Expected Ready: [date]

_______________          _______________
  Issued by                Received by

Terms and Conditions:
1. Full payments to be made upon collection/delivery of plants.
2. If plants are not collected 1 month after the confirmed date,
   delivery will be based on availability basis or postponed to
   a future date as the company sees fit.
3. Any cancellation of bookings refund shall be made after 14
   working days from the date of bookings.
```

### Export Options
- **Print** — browser print window (same pattern as sales DO/CS)
- **Share** — html2canvas → WhatsApp image (same pattern as sales receipts)
- Descriptive filename: `AB-BK001_20260410_Customer_Name.png`

---

## 14. Key Differences from Sales Module

| Aspect | Sales (Pineapple) | Seedlings |
|--------|-------------------|-----------|
| Timeline | Order → deliver same day/week | Book → collect 10+ months later |
| Payment | Pay on delivery or credit terms | Deposit upfront, pay before collect |
| Collection control | N/A | Cannot collect more than paid for |
| Document | DO / Cash Sale / Invoice | L3.1 (physical booklet, system tracks) |
| Inventory unit | kg / pcs / box | Individual seedlings (count) |
| Batch importance | Low (product catalog) | Core — everything tied to batch |
| Customer overlap | Mostly different | Separate table, cross-company link optional |
| Pricing | Per product | Per batch (default), overridable per booking |
