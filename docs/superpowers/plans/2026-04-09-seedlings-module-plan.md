# Oil Palm Seedlings Module — Implementation Plan

**Date:** 2026-04-09
**Spec:** `docs/superpowers/specs/2026-04-09-seedlings-module-design.md`
**Module:** `seedlings.html` + `seedlings.css`
**Company:** TG Agribusiness (`tg_agribusiness`, code `AB`)

---

## Phase 0: Documentation Discovery (Complete)

### Allowed APIs & Patterns

| Pattern | Source | Usage |
|---------|--------|-------|
| `sbQuery(queryPromise, loadingMsg)` | shared.js:136 | All SELECT queries |
| `sbMutate(queryFn, loadingMsg)` | shared.js:167 | All INSERT/UPDATE/DELETE (with retry) |
| `sbUpdateWithLock(table, id, updates, expectedUpdatedAt)` | shared.js:215 | Concurrent edit protection |
| `dbNextId(prefix)` | shared.js:358 | ID generation — calls `sb.rpc("next_id", {p_prefix, p_company_code})` |
| `getCompanyId()` / `getCompanyCode()` | shared.js:389-395 | Company scoping |
| `notify(msg, type, duration)` | shared.js:80 | Toast notifications |
| `confirmAction(title, message, onConfirm, danger)` | shared.js:278 | Confirmation modals |
| `showLoading(msg)` / `hideLoading(el)` | shared.js:243 | Loading overlay |
| `btnLoading(btn, loading, originalText)` | shared.js:259 | Button disable/spinner |
| `validateRequired(ids)` | shared.js:511 | Form validation |
| `esc(s)` | shared.js:72 | XSS-safe HTML escaping |
| `formatRM(val)` | shared.js:467 | Malaysian Ringgit formatting |
| `fmtDate(d)` / `fmtDateNice(d)` | shared.js:449-460 | Date formatting |
| `closeModal(id)` | shared.js | Modal close helper |
| `trapFocus(el)` / `releaseFocus(el)` | shared.js:327 | Modal accessibility |
| `hasPermission(moduleKey, permKey)` | index.html:420 | Permission checks |
| `injectCompanySwitcher()` | shared.js:402 | Sidebar company buttons |
| `injectUserBadge(user)` | shared.js:532 | Sidebar user section |

### Anti-Patterns to Avoid
- **Never** call Supabase queries without `sbQuery()` / `sbMutate()` wrappers
- **Never** omit `.select()` after `.insert()` / `.update()` / `.delete()` / `.upsert()`
- **Never** hardcode company_id — always use `getCompanyId()`
- **Never** use `confirm()` browser dialogs — use `confirmAction()`
- **Never** create module-specific CSS in shared.css — use `seedlings.css`

### Copy-From References
| What | Source File | Lines | Copy Pattern |
|------|------------|-------|--------------|
| HTML scaffold + sidebar | spraytracker.html | 1-76 | Sidebar, nav-items, main-content structure |
| Tab switching | sales.html | 1257-1298 | `switchTab()` function |
| Supplier CRUD | inventory.html | 2875-2960 | Table + modal + save/delete |
| Customer creation + dup check | sales.html | 3472-3560 | Phone check + save |
| Photo upload + resize | sales.html | 2900-2921 | Canvas resize → Supabase storage |
| Photo modal (camera/album/skip) | sales.html | 441-461 | Modal markup |
| Report rendering | sales.html | 7050-7125 | Report buttons + filters + table |
| DB migration structure | supabase/invoicing_migration.sql | Full file | Table + RLS + triggers + indexes |
| Module registration | index.html | 281-401 | MODULES array entry |
| Permission definitions | index.html | 414-442 | `hasPermission()` gating |
| Company mapping | shared.js | 379-387 | MODULE_COMPANY entry |

---

## Phase 1: Database Migration

**Goal:** Create all 7 tables, RLS policies, triggers, indexes, and Supabase storage bucket.

### Tasks

1. **Write migration SQL** (`supabase/seedlings_migration.sql`) containing:

   **Tables (7):**
   - `seedling_suppliers` — id (TEXT PK), company_id, name, address, phone, license_no, notes, created_at, updated_at
   - `seedling_batches` — id (TEXT PK), company_id, batch_number, supplier_id (FK), supplier_l31_no, supplier_do_no, variety, seed_source_desc, qty_seeds_received, qty_transplanted, qty_doubletons_gained, qty_culled_total, qty_sold_total, date_received, date_planted, date_transplanted, date_sellable, field_block, price_per_seedling, status, notes, created_at, updated_at
   - `seedling_batch_events` — id (TEXT PK), batch_id (FK), event_type, qty, reason, event_date, logged_by, notes, created_at
   - `seedling_customers` — id (TEXT PK), company_id, name, address, phone, ic_number, company_reg, license_no, planting_location, planting_area_ha, customer_type, linked_customer_id, notes, created_at, updated_at
   - `seedling_bookings` — id (TEXT PK), company_id, customer_id (FK), batch_id (FK), qty_booked, price_per_seedling, total_amount, total_paid, total_collected, status, booking_date, expected_ready_date, invoice_no, notes, created_at, updated_at
   - `seedling_payments` — id (TEXT PK), booking_id (FK nullable), collection_id (FK nullable), customer_id (FK), amount, payment_method, payment_date, reference, slip_url, notes, created_at
   - `seedling_collections` — id (TEXT PK), company_id, customer_id (FK), booking_id (FK nullable), batch_id (FK), l31_serial_no, qty_collected, price_per_seedling, subtotal, payment_received, collection_date, collected_by, photo_url, l31_photo_url, invoice_no, transport_fee, notes, logged_by, created_at

   **RLS:** Enable on all 7 tables. Policies for `anon` (SELECT/INSERT/UPDATE/DELETE) and `authenticated` (same). Pattern: `USING (true)` / `WITH CHECK (true)` — same as invoicing migration.

   **Triggers:** `set_updated_at()` on `seedling_suppliers`, `seedling_batches`, `seedling_customers`, `seedling_bookings` (tables with `updated_at`).

   **Indexes:**
   - `seedling_batches(company_id)`, `seedling_batches(status)`
   - `seedling_batch_events(batch_id)`
   - `seedling_customers(company_id)`, `seedling_customers(phone)` (partial WHERE NOT NULL)
   - `seedling_bookings(customer_id)`, `seedling_bookings(batch_id)`, `seedling_bookings(status)`
   - `seedling_payments(booking_id)`, `seedling_payments(customer_id)`
   - `seedling_collections(batch_id)`, `seedling_collections(booking_id)`, `seedling_collections(customer_id)`

   **Foreign Keys:**
   - `seedling_batches.supplier_id` → `seedling_suppliers(id)`
   - `seedling_batch_events.batch_id` → `seedling_batches(id)`
   - `seedling_bookings.customer_id` → `seedling_customers(id)`
   - `seedling_bookings.batch_id` → `seedling_batches(id)`
   - `seedling_payments.booking_id` → `seedling_bookings(id)`
   - `seedling_payments.collection_id` → `seedling_collections(id)`
   - `seedling_payments.customer_id` → `seedling_customers(id)`
   - `seedling_collections.customer_id` → `seedling_customers(id)`
   - `seedling_collections.booking_id` → `seedling_bookings(id)`
   - `seedling_collections.batch_id` → `seedling_batches(id)`

2. **Create Node.js runner script** (`supabase/run_seedlings_migration.js`) — connects via `pg` using DB credentials from CLAUDE.md, executes the SQL file.

3. **Create Supabase storage bucket** `seedling-photos` — via Supabase dashboard or SQL. Public read access.

### Verification
- [ ] All 7 tables exist in Supabase (`SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename LIKE 'seedling_%'`)
- [ ] RLS enabled on all tables
- [ ] Triggers fire on update (test with `UPDATE seedling_suppliers SET name='test' WHERE false`)
- [ ] Storage bucket `seedling-photos` accessible

---

## Phase 2: Module Scaffold + Hub Registration

**Goal:** Create `seedlings.html` and `seedlings.css` with working sidebar, tab switching, data loading, and hub page integration.

### Tasks

1. **Create `seedlings.css`** — Module-specific styles. Start minimal (batch cards, status badges, collection cards). Copy pattern from `spraytracker.css` / `inventory.css` for structure.

2. **Create `seedlings.html`** with:
   - Head: meta, viewport, fonts, Supabase SDK CDN, shared.css, seedlings.css, shared.js
   - Loading overlay (same as spraytracker.html:15)
   - Sidebar: logo (`assets/logo-agribusiness.png`), brand text "Seedlings", company-switcher container, 6 nav-items (Batches, Bookings, Collections, Customers, Suppliers, Reports), user section, sync indicator
   - Main content: 6 `<div class="page" id="page-{tab}">` sections (empty placeholders)
   - Tab switching function: `navigateTo(page)` — copy from spraytracker pattern
   - Session guard + data loading: `initModule()` async function that:
     - Checks session (redirect to index.html if none)
     - Sets company to `tg_agribusiness` (hardcoded — this module is Agribusiness only)
     - Loads all data via parallel `Promise.all([sbQuery(...)])`:
       - `seedling_suppliers`, `seedling_batches`, `seedling_batch_events`
       - `seedling_customers`, `seedling_bookings`, `seedling_payments`, `seedling_collections`
     - Calls render functions for each tab
     - Hides loading overlay
   - Company switcher: inject but redirect to hub if user selects Agro Fruits (module is Agribusiness only)

3. **Register module in hub** (`index.html`):
   - Update MODULES array: set `active: true`, update permissions list to match spec (view, manageBatches, manageBookings, recordCollections, manageCustomers, manageSuppliers, viewReports)
   - Ensure `MODULE_COMPANY.seedlings = 'tg_agribusiness'` already exists in shared.js (it does)

### Verification
- [ ] `seedlings.html` loads without errors in browser
- [ ] Sidebar renders with 6 tabs, clicking each shows correct page div
- [ ] Company switcher shows, selecting Agro Fruits redirects to hub
- [ ] Hub page shows Seedlings module card under TG Agribusiness
- [ ] User Management shows Seedlings permissions panel
- [ ] Session guard works (redirects to hub if not logged in)

---

## Phase 3: Suppliers + Customers Tabs

**Goal:** Full CRUD for suppliers and customers, including cross-company customer detection.

### Tasks

#### 3A: Suppliers Tab
Copy pattern from `inventory.html` supplier management (lines 2875-2960).

1. **Suppliers table view** — columns: Name, Phone, License No, Actions (Edit/Delete)
2. **Add/Edit Supplier modal** — fields: name, address, phone, license_no, notes
3. **Save supplier** — `dbNextId('SS')` for new, `sbMutate()` for insert/update
4. **Delete supplier** — `confirmAction()` + check no batches reference this supplier
5. **Permission gate** — `hasPermission('seedlings', 'manageSuppliers')`

#### 3B: Customers Tab
Copy pattern from `sales.html` customer management (lines 3472-3560).

1. **Customer table view** — columns: #, Name, Phone, IC/Company Reg, Type, Planting Location, Actions
2. **Add/Edit Customer modal** — fields: name, address, phone, ic_number, company_reg, license_no, planting_location, planting_area_ha, customer_type (dropdown: estate/smallholder/agent/government), notes
3. **Cross-company detection** — on phone input blur:
   - Search `sales_customers` table for matching phone (cross-company query, no company_id filter)
   - If match found: show info banner "This customer exists as '{name}' under TG Agro Fruits. Link them?"
   - If user confirms: set `linked_customer_id` on save
4. **Save customer** — `dbNextId('SC')` for new, `sbMutate()` for insert/update
5. **Delete customer** — check no bookings/collections reference this customer
6. **Permission gate** — `hasPermission('seedlings', 'manageCustomers')`

### Verification
- [ ] Can create, edit, delete suppliers
- [ ] Can create, edit, delete customers
- [ ] Cross-company phone detection works (shows banner when phone matches Agro Fruits customer)
- [ ] Linking works (linked_customer_id saved)
- [ ] Permission gating hides Add/Edit/Delete for unauthorized users

---

## Phase 4: Batches Tab

**Goal:** Batch lifecycle management — create, transplant, log culling, view events, track inventory.

### Tasks

1. **Batch list view** — card layout or table with:
   - Batch number, variety, supplier, status badge, qty breakdown (seeds → transplanted → available → sold)
   - Progress bar (seeds_received as 100%, showing culled/sold/available proportions)
   - Date planted, date sellable, field block
   - Click to expand/open detail

2. **Create Batch modal** — fields:
   - Supplier (dropdown from `seedling_suppliers`)
   - Variety (text input — e.g., "DxP", "Deli Dura x Avros")
   - Qty Seeds Received (number)
   - Date Received, Date Planted
   - Supplier L3.1 No, Supplier DO No
   - Seed Source Description (freetext, for L3.1 field 6)
   - Field Block (text — physical location)
   - Price Per Seedling (number, RM)
   - Allocation % (default 50%, editable)
   - Notes
   - Auto-calculate: batch_number (`{next_seq}-{year}`), date_sellable (`date_planted + 10 months`), qty_allocation (`seeds × allocation_pct / 100`), status = `pre_nursery`

3. **Batch number generation** — query `seedling_batches` for max batch_number in current year, increment. Not via `dbNextId` — this is a display number, not a primary key.

4. **Batch detail view** — expanded section showing:
   - Summary cards: Seeds Received, Transplanted, Doubletons Gained, Total Culled, Total Sold, Available, Booked
   - Event timeline (from `seedling_batch_events`) — chronological list with type icon, qty, reason, date, logged_by
   - Bookings against this batch (mini table)
   - Collections from this batch (mini table)

5. **Record Transplant action** — button on batch detail (only when status = `pre_nursery`):
   - Modal: Date, Qty Transplanted, Qty Culled at Transplant, Qty Doubletons/Tripletons Gained
   - Creates 2-3 batch events (transplant, cull if >0, doubleton_gain if >0)
   - Updates batch: qty_transplanted, qty_culled_total, qty_doubletons_gained
   - Status → `main_nursery`
   - Recalculate qty_available

6. **Log Culling action** — button on batch detail (any active status):
   - Modal: Date, Qty Culled, Reason (dropdown of common reasons + freetext)
   - Common reasons: Stunted growth, Abnormal, Pest damage, Disease, Mechanical damage, Overaged, Other
   - Creates batch event (type: `cull`)
   - Updates batch: qty_culled_total += qty
   - Recalculate qty_available

7. **Batch status transitions:**
   - `pre_nursery` → `main_nursery` (on transplant)
   - `main_nursery` → `selling` (manual button when seedlings reach 10+ months, or auto when date_sellable passed)
   - `selling` → `sold_out` (auto when qty_available = 0)
   - Any → `closed` (manual — batch lifecycle complete)

8. **qty_available calculation** (computed on every event):
   ```
   qty_available = qty_seeds_received + qty_doubletons_gained - qty_culled_total - qty_sold_total
   ```
   Note: qty_transplanted is informational (doesn't change total count — just tracks the event).

9. **Edit Batch** — edit non-computed fields (variety, field_block, price, notes, dates)

10. **Permission gate** — `hasPermission('seedlings', 'manageBatches')`

### Verification
- [ ] Can create batch with auto-generated batch number
- [ ] Batch list shows with correct status badges and qty breakdown
- [ ] Transplant flow works (creates events, updates counts, changes status)
- [ ] Culling log works (creates event, updates counts)
- [ ] Status transitions work correctly
- [ ] qty_available always accurate after any event
- [ ] Batch detail shows event timeline, bookings, and collections
- [ ] Edit batch works for editable fields

---

## Phase 5: Bookings Tab

**Goal:** Booking management with deposit tracking and payment control.

### Tasks

1. **Booking list view** — table or cards:
   - Customer name, batch number, variety, qty booked, price, total amount
   - Payment progress bar (total_paid / total_amount)
   - Collection progress (total_collected / qty_booked)
   - Status badge (active/completed/cancelled)
   - Expected ready date
   - Filter: status (active/completed/all), customer, batch

2. **Create Booking modal:**
   - Customer (dropdown from `seedling_customers`, with search)
   - Batch (dropdown — only batches with available uncommitted stock, showing: batch_number, variety, available qty)
   - Qty to Book (number — max = batch available - already booked)
   - Price Per Seedling (pre-filled from batch default, editable)
   - Auto-calculate: Total Amount = qty × price
   - **Allocation warning**: if this booking would exceed batch's allocation qty (seeds × allocation_pct%), show gold warning banner (not blocking)
   - Expected Ready Date (pre-filled from batch.date_sellable, editable)
   - Invoice No (optional text)
   - Notes
   - After save → immediately prompt for initial deposit payment (see payment modal)

3. **Booking detail view** — expanded section:
   - Summary: Qty Booked, Total Amount, Total Paid, Balance Due, Total Collected, Qty Collectible
   - **Qty Collectible** = `floor(total_paid / price_per_seedling) - total_collected`
   - Payment history table (from `seedling_payments` where booking_id matches)
   - Collection history table (from `seedling_collections` where booking_id matches, with L3.1 numbers)
   - Actions: Record Payment, Record Collection, Print Slip, Cancel Booking

4. **Record Payment modal** (for booking deposits/top-ups):
   - Amount (number)
   - Payment Method (cash/bank_transfer/cheque)
   - Payment Date
   - Reference (text)
   - Payment Slip photo (optional — upload to `seedling-photos/payment-slips/`)
   - On save: create `seedling_payments` record, update `seedling_bookings.total_paid`

5. **Cancel Booking** — `confirmAction()`, set status = `cancelled`, release batch stock (reduce qty_booked on batch)

6. **Edit Booking** — change qty (within available), price, notes, invoice_no

7. **Batch reassignment** — if batch has shortfall, allow changing booking to a different batch (button in booking detail)

8. **Booking slip generation** — printable document (see spec Section 14):
   - Renders booking slip with office address, customer info, items table, deposit/balance, terms & conditions
   - Print button (browser print) + Share button (html2canvas → WhatsApp image)
   - Available from booking detail ("Print Slip") and auto-prompted after booking creation
   - Same export pattern as sales DO/CS (soOpenA4Window, soA4PrintStyles)

9. **Permission gate** — `hasPermission('seedlings', 'manageBookings')`

### Verification
- [ ] Can create booking with customer + batch selection
- [ ] 50% warning shows when over-committing batch
- [ ] Deposit payment records correctly, updates total_paid
- [ ] Qty Collectible calculates correctly based on payments
- [ ] Payment history shows in booking detail
- [ ] Cancel booking releases batch stock
- [ ] Batch reassignment works
- [ ] Completed status auto-sets when fully collected

---

## Phase 6: Collections Tab

**Goal:** Record collections (booked + walk-in cash sales) with L3.1 tracking, photos, and payment control.

### Tasks

1. **Collections list view** — table of all collections:
   - Date, Customer, Batch, Qty, L3.1 Serial No, Amount Paid, Type (Booking/Walk-in)
   - Filter: date range, customer, batch
   - Search by L3.1 serial number

2. **Record Collection — From Booking:**
   - Select booking (dropdown — active bookings with collectible qty > 0)
   - Shows: Customer, Batch, Price, Qty Booked, Paid, Collected, **Qty Collectible** (key number)
   - Qty to Collect (max = qty_collectible, enforced)
   - **If customer wants more than collectible**: show warning "Customer must pay more first" with inline "Record Payment" button to top up before proceeding
   - L3.1 Serial Number (text input — manual from physical booklet)
   - Collection Date
   - Collected By (text — person who physically collected)
   - Payment at collection (optional — top-up or balance payment amount)
   - Payment method (if payment > 0)
   - Photos: seedlings loaded + L3.1 page (camera/album, same pattern as sales.html:2900)
   - Transport fee (optional, if delivery)
   - Invoice No (optional)
   - On save:
     - Create `seedling_collections` record
     - If payment > 0: create `seedling_payments` record (linked to both booking + collection)
     - Update `seedling_bookings`: total_collected += qty, total_paid += payment
     - Update `seedling_batches`: qty_sold_total += qty, recalc qty_available
     - If total_collected >= qty_booked → booking status = `completed`

3. **Record Collection — Walk-in Cash Sale:**
   - Select or create customer (with cross-company detection)
   - Select batch (only batches with status `selling` and available uncommitted stock)
   - Qty (max = available uncommitted)
   - Price per seedling (from batch default, editable)
   - L3.1 Serial Number
   - Full payment expected (pre-filled = qty × price, editable)
   - Payment method
   - Collection Date, Collected By
   - Photos
   - Transport fee, Invoice No (optional)
   - On save:
     - Create `seedling_collections` record (no booking_id)
     - Create `seedling_payments` record (no booking_id)
     - Update `seedling_batches`: qty_sold_total += qty, recalc qty_available

4. **Photo upload** — copy pattern from sales.html:
   - Two photo slots: "Seedlings Loaded" and "L3.1 Certificate"
   - Canvas resize (max 1200px, JPEG 80%)
   - Upload to `seedling-photos` bucket, path: `collections/{id}/seedlings.jpg` and `collections/{id}/l31.jpg`

5. **Collection detail view** — click to expand:
   - All fields displayed (customer, batch, qty, price, L3.1 no, payment, photos)
   - Photo thumbnails (click to enlarge)

6. **Permission gate** — `hasPermission('seedlings', 'recordCollections')`

### Verification
- [ ] Booking collection enforces payment-controlled qty limit
- [ ] Inline payment top-up works before collecting
- [ ] Walk-in cash sale flow works end-to-end
- [ ] L3.1 serial number tracked per collection
- [ ] Photos upload and display correctly
- [ ] Batch qty_sold_total and qty_available update after collection
- [ ] Booking auto-completes when fully collected
- [ ] Collections searchable by L3.1 serial number

---

## Phase 7: Reports Tab

**Goal:** MPOB monthly report, batch summary, and cash flow projection.

### Tasks

1. **Report type selector** — buttons for: "MPOB Monthly Report", "Batch Summary", "Cash Flow Projection"

2. **MPOB Monthly Report:**
   - Filter: Month/Year picker (defaults to current month)
   - **Seeds Planted/Purchased**: batches where `date_planted` falls in selected month — show batch_number, supplier, variety, qty_seeds_received, date_planted
   - **Transplanted**: batch events of type `transplant` in selected month — batch_number, qty, date
   - **Culled/Destroyed**: batch events of type `cull` in selected month — batch_number, qty, reason, date
   - **Doubletons Gained**: batch events of type `doubleton_gain` in selected month — batch_number, qty, date
   - **Sold**: collections in selected month — customer name, qty, L3.1 serial no, date, batch
   - **Balance**: current qty_available across all active batches (snapshot, not period-specific)
   - **Summary row**: Total Planted, Total Transplanted, Total Culled, Total Gained, Total Sold, Total Balance
   - Print button (CSS print styles)
   - Export CSV button

3. **Batch Summary Report:**
   - All batches (or filter by status)
   - Columns: Batch #, Variety, Supplier, Seeds, Transplanted, Doubletons, Culled, Sold, Available, Booked, Uncommitted, Status, Date Planted, Date Sellable
   - Uncommitted = Available - Booked (shows what's left for walk-in sales)
   - Totals row
   - Print + CSV export

4. **Cash Flow Projection Report:**
   - Filter: Year picker (defaults to current year)
   - Monthly columns showing:
     - **Booking Payments**: deposits + balance payments received from booked customers
     - **Cash Sales**: walk-in collection payments
     - **Grand Total**: combined monthly income
   - **Projected row**: upcoming balance payments due from active bookings (outstanding amounts by expected collection month)
   - Totals row per column
   - Print + CSV export

5. **Permission gate** — `hasPermission('seedlings', 'viewReports')`

### Verification
- [ ] Monthly report correctly aggregates events/collections by month
- [ ] Balance shows current snapshot across all batches
- [ ] Batch summary shows correct computed columns
- [ ] Cash flow projection shows actual + projected amounts by month
- [ ] Print layout renders cleanly
- [ ] CSV export works

---

## Phase 8: Final Integration + Polish

**Goal:** Wire everything together, test end-to-end, deploy.

### Tasks

1. **Update hub module card:**
   - Set `active: true` in MODULES array
   - Update permissions list to final 7 keys
   - Verify module icon (`icons/modules/seedlings.png` exists)

2. **Update CLAUDE.md:**
   - Move Seedlings from "Coming Soon" to "Active"
   - Add architecture section documenting tables, workflows, L3.1 tracking
   - Document ID prefixes: SS, SB, SE, SC, BK, SP, CL

3. **Supabase storage bucket** — confirm `seedling-photos` created with public read

4. **End-to-end test workflow:**
   - Create supplier → Create batch → Log transplant → Log culling
   - Create customer (test cross-company detection)
   - Create booking → Record deposit → Record collection (verify payment control)
   - Walk-in cash sale
   - Generate MPOB monthly report
   - Verify all numbers are consistent

5. **Mobile testing:**
   - Collection flow on phone (photo capture, L3.1 input)
   - All tabs readable on mobile
   - Touch targets ≥ 36px

6. **Deploy** — `netlify deploy --prod --dir=.` or API deploy

### Verification
- [ ] Full workflow: supplier → batch → transplant → booking → deposit → collection → report
- [ ] All computed fields (qty_available, qty_collectible, totals) stay consistent
- [ ] Mobile collection flow works (photos, L3.1 input)
- [ ] Hub page shows module, permissions work
- [ ] No console errors
- [ ] Deployed and accessible at tgfarmhub.com/seedlings.html

---

## Estimated Scope

| Phase | Tables/Files | Approx Lines |
|-------|-------------|-------------|
| Phase 1: DB Migration | 1 SQL + 1 JS runner | ~250 |
| Phase 2: Scaffold | seedlings.html + seedlings.css | ~300 |
| Phase 3: Suppliers + Customers | Inline in seedlings.html | ~500 |
| Phase 4: Batches | Inline in seedlings.html | ~800 |
| Phase 5: Bookings | Inline in seedlings.html | ~600 |
| Phase 6: Collections | Inline in seedlings.html | ~700 |
| Phase 7: Reports | Inline in seedlings.html | ~400 |
| Phase 8: Integration | index.html updates, CLAUDE.md | ~50 |
| **Total** | | **~3,600** |

---

## Execution Notes

- Each phase is self-contained and can be executed in a separate session
- Phases 3-7 build on Phase 2's scaffold — each adds one tab's functionality
- Phase 6 (Collections) is the most complex due to payment-controlled logic
- Photo upload reuses the exact pattern from sales.html — no new infrastructure needed
- All data loads in `initModule()` at startup (same pattern as all other modules)
