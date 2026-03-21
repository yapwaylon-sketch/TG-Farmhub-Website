# TG FarmHub — Pineapple Sales Module Design Spec

**Date:** 2026-03-21
**Status:** Approved
**Module:** Sales Management
**Files:** `sales.html`, `delivery.html`, `display-sales.html`

---

## 1. Overview

A sales management module for TG FarmHub that handles the full pineapple sales lifecycle: customer management, order intake, preparation tracking, delivery/collection, document generation (Delivery Orders and Cash Sales), payment tracking, returns, and QuickBooks invoice reconciliation.

**Three pages serve three audiences:**
- `sales.html` — main module for supervisors/admin (mobile-first)
- `delivery.html` — stripped-down driver page (phone-only)
- `display-sales.html` — TV display for packing area (read-only)

All pages share the same Supabase database and follow existing TG FarmHub architecture (static HTML/CSS/JS, no build step, Supabase REST API + RLS).

---

## 2. Users & Access

| Role | Access | Primary Device |
|------|--------|---------------|
| Admin (Waylon) | Full access to all tabs, pricing, reports, invoicing | Phone + Desktop |
| Supervisor | Create/edit orders, manage customers, record payments, assign drivers | Phone |
| Worker | View preparation tasks, update status to preparing/prepared, take photos | Phone + TV |
| Driver | View assigned deliveries, mark delivered, take photos, generate documents | Phone only |

---

## 3. Data Model

**ID Strategy:** New sales tables use TEXT PKs with `dbNextId()` prefixes (SC, SP, SO, SI, SY, SR) matching existing app convention. FKs to existing tables (crop_varieties, workers, users) use TEXT to match their ID types.

### 3.1 `sales_customers`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Auto via dbNextId("SC") |
| name | TEXT | NOT NULL | Company or person name |
| contact_person | TEXT | | For companies |
| phone | TEXT | UNIQUE (nullable for walkin) | Duplicate prevention key; nullable for walk-in customers |
| address | TEXT | | Delivery address |
| type | TEXT | | `wholesale`, `retail`, `walkin` |
| channel | TEXT | | `whatsapp_delivery`, `whatsapp_collect`, `walkin` |
| payment_terms | TEXT | NOT NULL, default `cash` | `credit`, `cash` |
| notes | TEXT | | |
| is_active | BOOLEAN | default true | |
| created_at | TIMESTAMPTZ | default now() | |
| updated_at | TIMESTAMPTZ | default now(), auto-trigger | |

**Duplicate prevention:** Unique constraint on `phone`. UI searches existing customers by phone and name before allowing creation. Fuzzy match warning if similar name exists.

### 3.2 `sales_products`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Auto via dbNextId("SP") |
| variety_id | TEXT | FK → crop_varieties | MD2 or SG1 |
| name | TEXT | NOT NULL | e.g., "Whole Fruit >1kg (Crown)" |
| category | TEXT | NOT NULL | `whole_crown`, `whole_no_crown`, `slice`, `peeled`, `slice_box`, `chunk_box`, `ring_box` |
| unit | TEXT | NOT NULL | `kg`, `pcs`, `box` |
| default_price | NUMERIC | NOT NULL | Current standard price (RM) |
| box_quantity | INT | | Pcs per box for boxed products |
| is_active | BOOLEAN | default true | |
| sort_order | INT | default 0 | Display ordering |
| created_at | TIMESTAMPTZ | default now() | |
| updated_at | TIMESTAMPTZ | default now() | |

**Seed data examples:**
- SG1 Whole >1kg (Crown) — kg — RM 3.50
- SG1 Whole <1kg (Crown) — kg — RM 2.50
- MD2 Whole >1kg (Crown) — kg — RM 3.50
- SG1 Slices (Individual) — pcs — RM 2.00
- SG1 Peeled Whole — pcs — (price TBD)

### 3.3 `sales_orders`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Auto via dbNextId("SO") — also serves as order_no |
| customer_id | TEXT | FK → sales_customers, NOT NULL | |
| order_date | DATE | NOT NULL, default today | |
| delivery_date | DATE | | Requested delivery/collection date |
| delivery_time | TEXT | | Optional time string e.g. "10:00 AM" |
| channel | TEXT | | `whatsapp`, `walkin`, `phone` |
| fulfillment | TEXT | NOT NULL | `delivery`, `collection` |
| status | TEXT | NOT NULL, default `pending` | See status flow below |
| doc_type | TEXT | NOT NULL | `cash_sales`, `delivery_order` |
| doc_number | TEXT | UNIQUE | Auto: CS-YYMMDD-NNN or DO-YYMMDD-NNN |
| driver_id | TEXT | FK → workers | Nullable, set when dispatched |
| qb_invoice_no | TEXT | | QuickBooks invoice number |
| qb_invoiced_at | DATE | | When marked as invoiced |
| subtotal | NUMERIC | default 0 | Sum of line items |
| return_total | NUMERIC | default 0 | Sum of approved returns |
| grand_total | NUMERIC | default 0 | subtotal - return_total |
| amount_paid | NUMERIC | default 0 | Sum of payments received |
| payment_status | TEXT | default `unpaid` | `unpaid`, `partial`, `paid` |
| prep_photo_url | TEXT | | Supabase storage path |
| delivery_photo_url | TEXT | | Supabase storage path |
| notes | TEXT | | |
| created_by | TEXT | FK → users | |
| created_at | TIMESTAMPTZ | default now() | |
| updated_at | TIMESTAMPTZ | default now(), auto-trigger | |

**Doc number format:** `DO-YYMMDD-NNN` or `CS-YYMMDD-NNN` (via dbNextId)

### 3.4 `sales_order_items`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Auto via dbNextId("SI") |
| order_id | TEXT | FK → sales_orders, NOT NULL | CASCADE delete |
| product_id | TEXT | FK → sales_products, NOT NULL | |
| index_min | INT | CHECK (0-5) | Ripeness range minimum |
| index_max | INT | CHECK (0-5) | Ripeness range maximum |
| quantity | NUMERIC | NOT NULL | Weight (kg) or count (pcs) |
| unit_price | NUMERIC | NOT NULL | Price at time of sale |
| line_total | NUMERIC | NOT NULL | quantity x unit_price |
| notes | TEXT | | |
| created_at | TIMESTAMPTZ | default now() | |

**Note:** Variety is derived from the linked `sales_products.variety_id` — not duplicated here.

### 3.5 `sales_payments`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Auto via dbNextId("SY") |
| order_id | TEXT | FK → sales_orders, NOT NULL | |
| amount | NUMERIC | NOT NULL | |
| payment_date | DATE | NOT NULL | |
| method | TEXT | NOT NULL | `cash`, `bank_transfer`, `cheque` |
| reference | TEXT | | Bank ref, cheque number |
| notes | TEXT | | |
| created_by | TEXT | FK → users | |
| created_at | TIMESTAMPTZ | default now() | |

### 3.6 `sales_returns`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Auto via dbNextId("SR") |
| order_id | TEXT | FK → sales_orders, NOT NULL | |
| item_id | TEXT | FK → sales_order_items | Which product line |
| quantity | NUMERIC | NOT NULL | Weight or pcs returned |
| amount | NUMERIC | NOT NULL | Monetary value of the return (qty x unit_price) |
| reason | TEXT | | |
| resolution | TEXT | NOT NULL, CHECK | `deduct`, `refund`, `debit_note` |
| debit_note_no | TEXT | | Auto-generated via dbNextId("DN") |
| debit_note_used_on | TEXT | FK → sales_orders | Order where debit note was applied |
| photo_url | TEXT | | Customer proof photo (Supabase storage) |
| created_by | TEXT | FK → users | |
| created_at | TIMESTAMPTZ | default now() | |

---

## 4. Order Status Flow

```
PENDING → PREPARING → PREPARED → DELIVERING → COMPLETED
                                      ↓
                              CANCELLED (from any stage)
```

| Transition | Triggered By | Requires |
|-----------|-------------|----------|
| pending → preparing | Worker taps "Start Preparing" | — |
| preparing → prepared | Worker taps "Mark Prepared" | Photo (optional but prompted) |
| prepared → delivering | Supervisor assigns driver, taps "Send for Delivery" | Driver selection |
| prepared → completed | Supervisor taps "Collected" (for collection orders) | — |
| delivering → completed | Driver taps "Delivered" | Photo (optional but prompted) |
| any → cancelled | Supervisor/Admin | Confirmation modal |

**Walk-in shortcut:** Supervisor creates order with all items, then immediately marks as `completed`. The order creation form includes all item entry — the status jump only happens after items are saved, so the document always has complete data.

**Document generation:** Triggered automatically when status reaches `completed`. Generates DO or CS based on `doc_type`.

---

## 5. UI Design — `sales.html`

### 5.1 Tab Structure

| Tab | Icon | Purpose |
|-----|------|---------|
| Dashboard | Grid icon | Today's summary, outstanding payments aging, quick actions |
| Orders | List icon | Order list, create/edit, status management |
| Customers | People icon | Customer profiles, search, history, return rates |
| Products | Box icon | Product catalog, pricing |
| Payments | Dollar icon | Outstanding payment tracking, record payments |
| Invoicing | File icon | Batch DOs into QB invoices, enter invoice numbers |
| Reports | Chart icon | Sales analytics, customer reports, return rates |

### 5.2 Mobile-First Design Rules

- **Card-based lists** on mobile (not tables) — each order/customer is a tappable card
- **Vertical stacked forms** — all fields full-width, no side-by-side on mobile
- **Bottom action bar** — persistent "New Order" and "Quick Sale" buttons
- **Large touch targets** — all buttons min 44px height
- **Swipeable status** — order cards can show quick actions
- **Tables only on desktop** (>768px) — switch to card layout on mobile

### 5.3 Dashboard Tab

**Summary cards (top row):**
- Orders Today (count)
- Pending Preparation (count, red if any)
- Ready for Delivery (count)
- Outstanding Payments (total RM, with aging)

**Outstanding Payments Aging:**
- Quick view: 0-7 days, 8-14 days, 15-30 days, 30+ days
- Each bucket shows customer count and total RM
- Tap a bucket to see the customers

**Today's Orders List:**
- Grouped by status (pending → preparing → prepared → delivering)
- Each card: customer name, items summary, delivery time, status badge

### 5.4 Orders Tab

**Filter bar:**
- Status filter dropdown
- Date range (from/to)
- Customer search
- Doc type (DO/CS)
- Sort: Date (newest/oldest), Customer (A-Z)
- Clear Filters button

**Order list:**
- Mobile: card layout (customer name, date, status badge, total, doc number)
- Desktop: table layout
- Tap card/row to open order detail

**New Order flow (modal or full-screen on mobile):**
1. Customer selection — search by phone/name, or create new inline
2. Order details — delivery date, fulfillment type (delivery/collection), doc type (DO/CS), channel
3. Add items — select product, enter quantity, unit price (pre-filled from default), ripeness index range, line total auto-calculated
4. Order summary — subtotal, notes
5. Save — creates order in `pending` status

**Order detail view:**
- Header: order number, customer, date, status badge
- Items table/list
- Status timeline (visual progress bar)
- Action buttons based on current status
- Payment section (payments made, balance due)
- Returns section (if any)
- Photos section (prep photo, delivery photo)
- WhatsApp share button (sends order summary to workers)

### 5.5 Customers Tab

**Customer list:**
- Search by name or phone (real-time)
- Filter: type, payment terms, active/inactive
- Each card shows: name, phone, type badge, payment terms, total purchased (lifetime)
- Return rate indicator: green (<5%), yellow (5-10%), red (>10%)

**Add Customer modal:**
- Phone number field — on blur, checks for existing customer with same phone
- If match found: shows warning "Customer with this phone already exists" with link to view
- Name, contact person, phone, address, type, channel, payment terms, notes

**Customer detail view:**
- Profile info (editable)
- Purchase history (all orders, filterable by date)
- Payment history
- Return history with rate calculation
- Lifetime stats: total purchased, total paid, outstanding balance

### 5.6 Products Tab

- Product list with variety grouping (MD2 products, SG1 products)
- Each product shows: name, category badge, unit, current price
- Edit price inline with Save button (not auto-save)
- Add new product modal
- Activate/deactivate toggle

### 5.7 Payments Tab

**Outstanding payments view:**
- Sorted by age (oldest first)
- Grouped by customer
- Each row: order number, doc type, date, total, amount paid, balance, days outstanding
- "Record Payment" button per order → opens payment modal (amount, date, method, reference)
- Bulk actions: select multiple orders for same customer, record single payment split across them

**Cash sales tracking:**
- Filter to show only unpaid cash sales
- Highlighted if > 7 days old

### 5.8 Invoicing Tab

**Uninvoiced delivery orders:**
- Grouped by customer
- Checkbox selection to batch DOs together
- "Mark as Invoiced" button → requires QB invoice number input (mandatory)
- Once invoiced: DOs locked, shows QB invoice number

**Invoice history:**
- List of QB invoice numbers with associated DOs
- Date invoiced, customer, total amount

### 5.9 Reports Tab

| Report | Filters | Output |
|--------|---------|--------|
| Sales by Customer | Date range, customer | Purchases, product breakdown, payment status |
| Sales by Product | Date range, variety, category | Qty sold, revenue, avg price |
| Sales by Period | Monthly/weekly toggle | Revenue trend, order count, avg order value |
| Outstanding Payments | Doc type, age range | Aging buckets, customer breakdown |
| Return Rate | Date range, customer | Returns per customer, %, reasons |
| Driver Delivery Log | Date range, driver | Deliveries completed, customers served |
| Customer History | Single customer | All orders, payments, returns, lifetime value |

All reports support Print and CSV export.

---

## 6. UI Design — `delivery.html`

**Phone-only, no sidebar, minimal UI.**

- Auth: Drivers need a `users` table entry (with PIN) — supervisor creates a user account for each driver. The driver logs in via PIN on `delivery.html`, same as existing session system (`?session=<user_id>`). The `driver_id` on orders maps to `workers.id`, but the user links to workers via matching name or a `worker_id` field on `users`.
- Shows only orders assigned to logged-in driver with status `delivering`
- Each order is a large card:
  - Customer name (large)
  - Address (tappable for Google Maps navigation)
  - Items list (variety, quantity, index)
  - Total amount
  - Doc type badge (DO/CS)
- Action button: "Mark Delivered"
  - Prompts for photo (camera opens)
  - Generates document (DO or CS)
  - Shows document preview
  - Buttons: "Print" (browser print for thermal), "Share WhatsApp" (sends image to customer), "Done"
- Completed deliveries section (collapsed, for reference)
- Auto-refreshes every 30 seconds for new assignments
- Imports `shared.css` + `shared.js` for Supabase client, `sbQuery()`, `notify()`, `dbNextId()`, and other shared utilities
- Has its own `delivery.css` for phone-optimized layout (no sidebar styles needed)

---

## 7. UI Design — `display-sales.html`

**Read-only TV display for packing area.**

- Token auth: `?token=pnd2026` (same as existing TV displays)
- Layout: full-screen, large text, dark mode
- Shows today's and tomorrow's orders
- Grouped by status with color-coded headers:
  - Red: Pending (not started)
  - Orange: Preparing (in progress)
  - Green: Prepared (ready)
  - Blue: Out for Delivery / Awaiting Collection
- Each order card shows:
  - Customer name
  - Items: variety, quantity/weight, ripeness index
  - Delivery/collection date and time (if set)
  - Fulfillment type badge (Delivery/Collection)
- Auto-refreshes every 60 seconds
- Auto-rotates pages if too many orders for one screen (same pattern as nanasgrowth TV)

---

## 8. Document Generation

### 8.1 Document Types

**Delivery Order (DO):**
- Header: company name, "DELIVERY ORDER", DO number
- Customer info: name, address
- Date, driver name
- Items table: product, variety, qty, unit, price, total
- Subtotal, returns (if any), grand total
- Payment terms: "CREDIT"
- Signature line: "Received by: ___________"

**Cash Sales (CS):**
- Header: company name, "CASH SALES", CS number
- Customer info: name, phone
- Date
- Items table: same as DO
- Subtotal, returns (if any), grand total
- Payment status: "PAID" / "UNPAID"
- No signature line

### 8.2 Output Formats

1. **HTML rendering** — styled for 80mm thermal printer (narrow layout, browser print)
2. **PNG image** — generated via HTML canvas, for WhatsApp sharing
3. **PDF** — generated via browser print to PDF

All generated client-side. No server-side rendering needed.

**Library:** `html2canvas` via CDN (pinned version) for PNG export. Example: `https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js`

### 8.3 Numbering

- DO numbers: `DO-YYMMDD-NNN` (sequential per day, auto-generated)
- CS numbers: `CS-YYMMDD-NNN` (sequential per day, auto-generated)
- Uses existing `id_counters` table pattern from shared.js `dbNextId()`

---

## 9. WhatsApp Integration

### 9.1 Worker Preparation Message

Generated when supervisor taps "Send to Workers" on an order:

```
🍍 Pesanan Baru — PND
━━━━━━━━━━━━━━━━━━━━
📋 No: SO-260321-001
👤 Pelanggan: [customer name]
📅 Tarikh Hantar: [delivery date]
📦 Jenis: [Delivery/Collection]

📝 Senarai:
• SG1 >1kg (Index 2-3) — 500kg
• MD2 Slices — 20 pcs

📌 Nota: [order notes]
━━━━━━━━━━━━━━━━━━━━
```

### 9.2 Document Sharing

After delivery/collection completion:
- DO or CS rendered as PNG image
- "Share on WhatsApp" opens `wa.me/?text=` with order summary + image attachment (via Web Share API where supported, fallback to copy text + manual image share)

---

## 10. Payment Tracking Rules

### 10.1 Cash Sales (`doc_type = cash_sales`)
- Expected to pay immediately or ASAP
- If unpaid after 7 days: highlighted yellow in dashboard
- If unpaid after 14 days: highlighted red
- Supervisor can record partial or full payment anytime

### 10.2 Delivery Orders (`doc_type = delivery_order`)
- Credit-based, invoiced periodically via QuickBooks
- DOs accumulate until supervisor batches them into a QB invoice
- Closing DOs requires mandatory QB invoice number input
- Payment tracked at the QB invoice level (but recorded per-order in our system)
- Once invoiced and paid, orders marked `paid`

### 10.3 Payment Status Calculation
- `unpaid`: amount_paid = 0
- `partial`: 0 < amount_paid < grand_total
- `paid`: amount_paid >= grand_total

Auto-calculated on every payment insert/update.

---

## 11. Returns Handling

### 11.1 Flow
1. Customer reports defective/damaged fruits (sends photo via WhatsApp)
2. Supervisor creates return in system: selects order, item, quantity, reason, uploads photo
3. Supervisor selects resolution:
   - **Deduct**: reduces balance on current unpaid order
   - **Refund**: records cash/bank refund (for already-paid orders)
   - **Debit Note**: generates DN number, stored for future use
4. System updates order's `return_total` and `grand_total`

### 11.2 Debit Notes
- Auto-numbered: `DN-YYMMDD-NNN`
- Tracked in `sales_returns` table
- When creating a new order, system shows available debit notes for that customer
- Supervisor can apply debit note to reduce new order total
- Once applied, `debit_note_used_on` is set (can only be used once)

### 11.3 Return Rate Tracking
- Per customer: (total return quantity / total purchased quantity) x 100
- Displayed on customer profile as badge:
  - Green: < 5%
  - Yellow: 5-10%
  - Red: > 10%
- Report available for all customers with return history

---

## 12. Photos

- Storage: Supabase Storage bucket `sales-photos`
- Folder structure: `{order_id}/prep.jpg`, `{order_id}/delivery.jpg`, `{order_id}/return-{return_id}.jpg`
- Captured via `<input type="file" accept="image/*" capture="environment">` (opens camera on mobile)
- Resized client-side before upload (max 1200px width, JPEG 80% quality) to save storage
- Internal use only — not shared with customers

---

## 13. Reports

| Report | Filters | Columns/Data |
|--------|---------|-------------|
| Sales by Customer | Date range, customer, variety | Customer, orders count, total qty, total revenue, returns, net revenue |
| Sales by Product | Date range, variety, category | Product, qty sold, revenue, avg price, % of total |
| Sales by Period | Monthly/weekly, variety | Period, order count, total qty, revenue, avg order value |
| Outstanding Payments | Doc type, age buckets | Customer, order no, doc type, date, total, paid, balance, days old |
| Return Rate | Date range, customer | Customer, orders, returns count, return qty, return %, top reasons |
| Driver Delivery Log | Date range, driver | Driver, deliveries count, customers served, total delivered value |
| Customer History | Single customer | Order date, order no, items, total, payments, returns, balance |

All reports: Print button, CSV export button, date range filter.

---

## 14. Database Indexes

```sql
-- Performance indexes
CREATE INDEX idx_sales_orders_customer ON sales_orders(customer_id);
CREATE INDEX idx_sales_orders_status ON sales_orders(status);
CREATE INDEX idx_sales_orders_order_date ON sales_orders(order_date);
CREATE INDEX idx_sales_orders_delivery_date ON sales_orders(delivery_date);
CREATE INDEX idx_sales_orders_doc_type ON sales_orders(doc_type);
CREATE INDEX idx_sales_orders_payment_status ON sales_orders(payment_status);
CREATE INDEX idx_sales_orders_driver ON sales_orders(driver_id);
CREATE INDEX idx_sales_order_items_order ON sales_order_items(order_id);
CREATE INDEX idx_sales_payments_order ON sales_payments(order_id);
CREATE INDEX idx_sales_returns_order ON sales_returns(order_id);
CREATE INDEX idx_sales_customers_phone ON sales_customers(phone);
```

### 14.1 `updated_at` Triggers

Tables with `updated_at`: `sales_customers`, `sales_products`, `sales_orders`. Each requires:
```sql
CREATE TRIGGER set_updated_at BEFORE UPDATE ON <table>
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```
Uses the existing `set_updated_at()` function from `phase4_farm_config_migration.sql`.

### 14.2 `payment_status` Sync Trigger

Application-level: after inserting/updating/deleting a `sales_payments` row, JS recalculates `amount_paid` (SUM of payments for that order) and sets `payment_status` accordingly. Not a DB trigger — keeps logic in the UI layer consistent with existing patterns.

### 14.3 Supabase Storage Bucket

```sql
-- Run via Supabase Dashboard → Storage → New Bucket
-- Bucket name: sales-photos
-- Public: false (private, accessed via signed URLs)
-- File size limit: 5MB
-- Allowed MIME types: image/jpeg, image/png
```

RLS policies for storage:
- `anon` and `authenticated` roles: INSERT, SELECT on `sales-photos` bucket
- Path pattern: `{order_id}/*`

---

## 15. RLS Policies

All tables require RLS policies for both `anon` (PIN login) and `authenticated` (Google OAuth) roles, following the existing pattern from other TG FarmHub modules.

- `sales_customers`: full CRUD for both roles
- `sales_products`: full CRUD for both roles
- `sales_orders`: full CRUD for both roles
- `sales_order_items`: full CRUD for both roles
- `sales_payments`: full CRUD for both roles
- `sales_returns`: full CRUD for both roles

---

## 16. Integration Points

### 16.1 Existing Tables Used
- `crop_varieties` — links products to MD2/SG1
- `workers` — driver assignment
- `users` — auth, created_by tracking
- `id_counters` — sequential numbering (SO, DO, CS, DN prefixes)

### 16.2 Hub Page (`index.html`)
- Add "Sales" module card to hub page
- Link to `sales.html?session=<user_id>`

### 16.3 Future: Delivery Route Planning
- `sales_orders` has `driver_id` ready
- Future `delivery_routes` table can group orders by driver + date
- No changes needed to current schema

---

## 17. Tech Stack (unchanged)

- Frontend: Static HTML, CSS, vanilla JS (no framework)
- Backend: Supabase (PostgreSQL + REST API + RLS + Storage)
- Hosting: Netlify at tgfarmhub.com
- Auth: Same hybrid PIN/Google OAuth system
- Theme: Dark mode, green + gold accents (consistent with all modules)
