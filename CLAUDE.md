# TG FarmHub Website

## IMPORTANT — Memory Instructions
- **This file (`CLAUDE.md`) is the single source of truth** for project context, conventions, credentials, and roadmap
- This project lives on OneDrive and moves between machines — do NOT rely on global/local Claude memory files
- **Always save new learnings, decisions, and session outcomes back into this file**
- When updating memory, update THIS file — not `~/.claude/` memory folders
- On session start: read this file, then follow Session Start Protocol below

## Session Start Protocol
- **Always** begin each conversation with: Project Summary, Roadmap, Current TODOs, and Next Steps
- No prompt needed from user — do this automatically

## User Preferences
- User: Waylon (yapwaylon@gmail.com)
- Prefers concise, action-oriented communication
- Deploy is manual (git push does NOT auto-deploy)
- SQL migrations: run via Node.js `pg` script (credentials below)
- **DO NOT suggest regenerating or rotating API keys/tokens** — they are intentional and confirmed
- Project syncs between Mac and Windows via OneDrive
  - Windows: `C:\Users\yapwa\OneDrive\TG Web and Android Project\TG Farmhub Website`
  - Mac: `/Users/waylonyap/Library/CloudStorage/OneDrive-Personal/TG Web and Android Project/TG Farmhub Website`

## Project Overview
Farm management web application for TG Group / Ladang PND (pineapple farm, Malaysia). Static HTML/CSS/JS frontend hosted on Netlify, with Supabase (PostgreSQL) backend.

## Tech Stack
- **Frontend**: Static HTML, CSS, vanilla JS (no framework, no build step)
- **Backend**: Supabase (REST API + Row Level Security)
- **Hosting**: Netlify at **tgfarmhub.com**
- **Auth**: Hybrid — Google OAuth for admin (yapwaylon@gmail.com), PIN-based for workers/supervisors
  - Google OAuth via Supabase Auth (`signInWithOAuth({ provider: 'google' })`)
  - Admin can still use PIN as fallback
  - Workers/supervisors use PIN only (no Google option)
  - Auto-login on 6th PIN digit (no click needed), last username remembered
  - Sessions persist in localStorage (survives tabs/browser close)
  - Multi-device detection: login elsewhere auto-logs out previous session (token checked every 30s)
  - Inactivity timeout: 60 minutes
- **Theme**: Dark mode, green (#4A7C3F) + gold (#E8A020) accents

## Key Files
| File | Purpose |
|------|---------|
| `index.html` | Hub page — login, user management, module cards, farm config |
| `inventory.html` | Inventory Management module |
| `workers.html` | Worker Management module |
| `spraytracker.html` | PND Spray Tracker module |
| `growthtracker.html` | Growth Tracker module (read-only dashboard) |
| `display-growth.html` | TV display for Growth Tracker |
| `sales.html` | Sales Management module (7 tabs: Dashboard, Orders, Customers, Products, Payments, Invoicing, Reports) |
| `sales.css` | Sales module styles (cards, badges, timeline, aging) |
| `delivery.html` | Mobile driver delivery page (phone-only, PIN login, mark delivered, print DO/CS) |
| `display-sales.html` | TV display for packing station (token auth, auto-refresh, status-grouped orders) |
| `shared.css` | Shared styles (sidebar, layout, variables, offline banner) |
| `shared.js` | Shared JS (session guard, Supabase init, sidebar logic, sbMutate, sbUpdateWithLock) |
| `{module}.css` | Per-module styles (index.css, inventory.css, workers.css, spraytracker.css, growthtracker.css) |
| `trial-theme.css` | Light theme CSS override (KIV) — used by sales-trial.html |
| `guide-sales.html` | Staff workflow guide (English) |
| `guide-sales-cn.html` | Staff workflow guide (中文) — interface labels in English |
| `walkthrough-sales.html` | Interactive 14-step walkthrough with mockup screens + auto-play |
| `AUDIT-2026-03-22.md` | Full website audit report (12 issues, all fixed) |
| `*.sql` | Database migration scripts |

## Git
- **Repo**: github.com/yapwaylon-sketch/TG-Farmhub-Website (main branch)

## Supabase
- Project ref: `qwlagcriiyoflseduvvc`
- Region: ap-northeast-1 (Tokyo)
- API: `https://qwlagcriiyoflseduvvc.supabase.co`
- Anon Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNDgxNDYsImV4cCI6MjA4NzkyNDE0Nn0.OJvzNykb_JjejFlWlEy7QUKJjL7bfiaQI0pPx62P5YA`
- Service Role Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE`
- DB Host (Session Pooler): `aws-1-ap-northeast-1.pooler.supabase.com`
- DB User: `postgres.qwlagcriiyoflseduvvc`
- DB Password: `Hlfqdbi6wcM4Omsm`
- All tables use RLS policies for both `anon` (PIN login) and `authenticated` (Google OAuth) roles
- **RLS fix (2026-03-14)**: Added `authenticated` role policies to 6 tables that only had `anon`: `pnd_ingredients`, `pnd_formulations`, `pnd_product_ingredients`, `pnd_job_products`, `salary_advances`, `id_counters`

## Google OAuth
- **Google Cloud credentials**: Stored in Supabase Dashboard → Authentication → Providers → Google (not in repo for security)
- Authorized redirect URI: `https://qwlagcriiyoflseduvvc.supabase.co/auth/v1/callback`
- Only admin email (yapwaylon@gmail.com) is matched to a user in `public.users`
- RLS policies exist for both `anon` (PIN login) and `authenticated` (Google login) roles on all tables

## Netlify Deployment
- Site ID: `a0ac5d18-a968-414c-a531-c78ed390e5c2`
- Netlify token: `nfp_jQof4DyVHjPEN4xRxHU6WxxjKhPM3Aav414e`
- Domain: `tgfarmhub.com`
- Deploy: `netlify deploy --prod --dir=.` (or zip upload via Netlify API)

## Modules — Status

### Active (Built)
1. **Inventory Management** — Stock in/out, suppliers, reports, stock checks
2. **Worker Management** — Profiles, monthly payroll, task-based pay, deductions
3. **PND Spray Tracker** — Spray job system, product management (with ingredient/formulation lookups), batch job delete, logs, intervention logic, WhatsApp job sharing
4. **Growth Tracker** — Read-only dashboard: block growth monitoring, plant counts by variety/status, target dates, harvest windows
5. **Farm Configuration** — Centralized crop & block management, all data entry lives here
6. **TV Display (Growth)** — Standalone sub-project at `TG Nanas Growth TV/index.html`, deployed to `nanasgrowth.tgfarmhub.com`, password gate (session-based)
7. **Sales** — Customer management, order workflow (pending→preparing→prepared→delivering→completed), payment tracking, delivery orders, cash sales, returns/debit notes, 7 report types, document generation (DO/CS with print + WhatsApp image share)
8. **Delivery (Sales)** — `delivery.html`, phone-only driver page, PIN login, mark delivered + photo + print/share DO/CS
9. **TV Display (Sales)** — `display-sales.html`, read-only packing station display, password gate (session-based), auto-refresh 60s, auto-rotate pages

### Coming Soon (Not Built)
10. **Oil Palm Seedlings** — Booking management, sales tracking, seedling stock

## Architecture — Growth Data Flow

### Variety Defaults (set in Farm Config → Crop Management)
| Column | Table | Purpose |
|--------|-------|---------|
| `days_to_induce` | `crop_varieties` | Default days from planting to induction (MD2=300, SG1=210) |
| `harvest_days_from_induction` | `crop_varieties` | Default days from induction to harvest (MD2=140, SG1=120) |

### Per-Block Target Dates (stored in `growth_records`)
| Column | Populated When | Calculation |
|--------|---------------|-------------|
| `target_induce_date` | date_planted is set | `date_planted + variety.days_to_induce` |
| `target_harvest_start` | induction is saved | `date_induced_start + harvest_days` |
| `target_harvest_end` | induction is saved | `date_induced_end + harvest_days` |

**Key principle**: All pages read from `growth_records_view` (not the base table) — no client-side calculation. The view adds computed `days_after_induce` and `days_to_harvest` columns. Writes still go to `growth_records` table. Supervisor can override per-block dates.

### Data Entry Flow
1. **Farm Config** creates block → assigns crop variety + date_planted → auto-creates `growth_records.target_induce_date`
2. **Farm Config** changes status to "Induced" → induction modal saves dates → auto-stores `target_harvest_start/end`
3. **Growth Tracker** is read-only — displays data, no editing
4. **Other pages** (TV display, future dashboards) query `growth_records` directly

### Crop Statuses (active)
Growing → To Induce → Induced → Suckers → To Replant → *(Start New Cycle → Growing)*

### Planting Cycle System
- `block_crops` has `cycle` (INT, default 1) and `is_current` (BOOLEAN, default true)
- When status = "To Replant", a **"New Cycle"** button appears in Farm Config
- Clicking it: marks old block_crop `is_current=false`, creates new block_crop with `is_current=true`, increments cycle
- Variety can change on replant (e.g., MD2 → SG1)
- **All queries** filter `block_crops.is_current = true` (index.html, growthtracker.html)
- `growth_records_view` uses `WHERE EXISTS` to only show current-cycle records (Nanas TV needs no code change)
- Old cycle data preserved — accessible via "View History" button in Farm Config
- UNIQUE constraint: `(block_id, variety_id, cycle)` + partial index on `(block_id, variety_id) WHERE is_current = true`
- **Spray Tracker is NOT affected** — uses separate legacy `pnd_blocks` data model

**Note**: No "Harvesting" status — harvest timing is tracked via `target_harvest_start/end` dates. "Abandoned" is handled by deactivating the block in Block Management (not a status).

## SQL Migrations
All migrations have been applied to Supabase. Migration `.sql` files were removed from the repo on 2026-03-22 (historical reference only — schema lives in the database).

## Shared Assets
- **Folder**: `assets/` in project root — deployed to `https://tgfarmhub.com/assets/`
- **Files**: `logo.png` (56KB), `logo.jpg` (460KB)
- Sub-projects reference `https://tgfarmhub.com/assets/logo.png` (not local copies)
- To update: edit file in `assets/`, redeploy main site, all sub-sites auto-update
- Local `assets/` folder = backup + source of truth, synced via OneDrive

## Multi-Company Architecture (2026-04-05)
- **Two companies**: TG Agro Fruits (code: AF, id: `tg_agro_fruits`) and TG Agribusiness (code: AB, id: `tg_agribusiness`)
- **`companies` table**: 2 rows, read-only for all roles
- **`company_id` column** on 35 tables — every transaction is attributed to one company
- **Hub page**: Company switcher (two-button toggle) filters which module cards are visible
- **Module assignment**: `MODULE_COMPANY` in shared.js — Sales→Agro Fruits, Workers/Inventory/Spray/Growth→Agribusiness, Farm Config→shared
- **Sidebar**: Each module has compact company switcher; clicking other company redirects to hub
- **Document numbering**: `next_id()` RPC generates company-prefixed IDs (AF-SO001, AB-W028). Existing docs keep old format.
- **Data scoping**: All SELECT queries filter `.eq('company_id', getCompanyId())` on company-owned tables. All INSERTs include `company_id: getCompanyId()`.
- **Workers exception**: Workers table loaded WITHOUT company_id filter in sales/inventory/spray/delivery — Agro Fruits needs Agribusiness workers for driver/assignment dropdowns
- **Farm Config growth_records**: Hardcoded `company_id: 'tg_agribusiness'` on inserts (Farm Config is shared but growth records always Agribusiness)
- **Tables WITHOUT company_id** (never filter/insert): audit_log, block_crops, companies, crop_statuses, crop_varieties, crops, id_counters, payroll_entries, payroll_responsibilities, pnd_block_statuses, pnd_blocks, sales_drivers, task_entries, task_units, users
- **Views WITHOUT company_id**: pnd_latest_sprays, pnd_latest_sprays_by_ai (do NOT filter these)
- **localStorage key**: `tgfarmhub_company` stores selected company (defaults to `tg_agro_fruits`)
- **Company Overview**: Hub page shows both companies' key numbers (hardcoded, not filtered by selection)
- **Intercompany model**: Agro Fruits buys pineapples from Agribusiness (monthly bulk), sells at markup. Billing not yet tracked in system.
- **Future-ready**: Intercompany billing, expense tracking, per-company P&L, cost allocation deferred but structurally supported
- **Design spec**: `docs/superpowers/specs/2026-04-04-multi-company-architecture-design.md`

## Conventions
- Each module is a single self-contained HTML file (styles + JS inline)
- Shared sidebar/layout uses shared.css + shared.js
- DB schema managed directly in Supabase (migration files removed 2026-03-22)
- Session stored in localStorage (`tg_session`, `tg_user`), passed via `?session=<user_id>` query param between pages
- PIN input: numeric-only enforcement on all PIN fields (`inputmode="numeric"`, keypress filter)
- Supabase anon key is embedded in frontend (RLS provides security)
- Sidebar logo: `assets/logo.png?v=2` — TG Agro Fruits pineapple, 84x84px, white bg, rounded corners
- Company name: **TG Agro Fruits Sdn Bhd** (used in receipts, documents, footers — NOT "TG Group", NOT "Ladang PND")
- Sidebar brand: clickable logo+title links back to hub, "< TG FarmHub" subtitle
- Mobile sidebar: hides user/logout section, shows compact Logout button in brand bar
- Desktop: content max-width 1200px centered, larger fonts at ≥1024px breakpoint
- Trial light theme: `trial-theme.css` + `sales-trial.html` — KIV for later

## Key Patterns
- Each module = single HTML file importing shared.css + shared.js, module CSS/JS inline
- Supabase SDK v2.49.1 via CDN (pinned), RLS on all tables
- All data entry for growth/blocks in Farm Config; Growth Tracker is read-only
- Target dates stored in DB, not calculated client-side (consistency across pages)
- `pnd_blocks` uses column `block_name` (NOT `name`)
- `pnd_products` uses `formulation_id` FK → `pnd_formulations`; ingredients are many-to-many via `pnd_product_ingredients` junction table
- **Multi-product jobs (tank mix)**: `pnd_job_products` junction table stores all products in a job. Primary product also stored on `pnd_jobs` for backward compat. Dose fields (amount/unit/per_litres) stored per-product in junction table. Products are set at job creation and read-only in edit modal.
- **Spray log multi-product**: DB trigger handles primary product on completion; JS manually inserts spray logs for additional products in the mix
- **`pnd_latest_sprays` view**: Sorts by `created_at DESC` (most recently inserted log wins). Excludes intervention logs. Previously sorted by `date_completed DESC` which caused future-dated test data to mask real entries.
- **Spray Tracker summary tab**: Block status + variety + age pulled from `block_crops` (Farm Config) + `crop_statuses`, NOT from `pnd_blocks.status_id` (which is legacy/empty). Loads `blockCrops` and `cropStatuses` at startup.
- **Report tank mix grouping**: Spray log reports use `rowspan` cell merging for shared columns (Block, Date, Done By, Water Used, Logged By, Notes) when multiple products belong to the same job. Per-product columns (Product, AI, Next Spray, Product Used) remain separate rows.
- **Report "Logged By"**: Shows supervisor name from `pnd_jobs.logged_by` (not raw `auto:job:uuid`). "Done By" shows `pnd_jobs.worker_name`. Auto-generated notes are hidden.
- **Product field lock-down**: Formulation, Type, Dose Unit, Active Ingredients, Packaging (size/unit/type) are all read-only once set on a product (cannot be changed after initial entry)
- **Product packaging**: `pnd_products` has `packaging_size` (NUMERIC), `packaging_unit` (TEXT: g, kg, ml, L), `packaging_type` (TEXT: packet, box, bottle, drum, bag, can)
- **WhatsApp job sharing**: Green WhatsApp button on each job row → popup with message preview, "Copy Text" + "Send WhatsApp" buttons. Message in Bahasa Malaysia with emojis, includes per-tank dose calculation: `(tankSize / dosePer) × doseAmount`. Packaging count: `Math.ceil(perTankDose / packagingSize)`
- **Default tank size**: 1000L for new spray jobs
- All Supabase mutation queries (insert/update/delete/upsert) must chain `.select()` before `sbQuery()` — Supabase v2 returns empty data without it
- **Block management reminder**: Clickable to filter/show only incomplete blocks; excludes inactive (deactivated) blocks from count
- Filter dropdowns: populate on data load only, NOT on every render (prevents state reset)
- TV displays: password gate (session-based, sessionStorage key `tg_tv_auth`), shared password across all 3 displays, re-prompts on browser restart, read-only. Password stored in memory file, not in CLAUDE.md.
- **Spray-Inventory Link**: `pnd_products.inventory_product_id` FK links each spray product directly to `products` (inventory). Products are managed in Inventory module; Spray Tracker only configures spray-specific fields (interval, dose). Products page has "Enable for Spraying" to activate inventory products, and "Link to Inventory" banner for legacy unlinked products. Active Jobs page shows product-level stock check cards (need vs have + cost).
- **Multiple jobs per block**: Scheduled jobs no longer blocked by existing active jobs for same block+product. Shows info warning instead.

## Sales Module — Architecture

### Tables
| Table | Purpose |
|-------|---------|
| `sales_customers` | Customer profiles, phone unique constraint, type (wholesale/retail/walkin), payment_terms (credit/cash) |
| `sales_products` | Product catalog, optional variety link (nullable `variety_id`), categories, pricing, `name_bm`, `pcs_per_box`, `weight_range` |
| `sales_orders` | Orders with status workflow, doc_type, doc_number, driver_id, `assigned_worker_id`, payment tracking, `prep_photo_url`, `delivery_photo_url` |
| `sales_order_items` | Line items per order: product, quantity, unit_price, ripeness index_min/max |
| `sales_payments` | Payment records per order: amount, method, reference, `slip_url` (bank transfer slip photo) |
| `sales_returns` | Returns with resolution (deduct/refund/debit_note), photo proof, debit note tracking |

### Order Status Flow & Labels
DB values → Display labels: `pending` → "Order Received", `preparing` → "Preparing", `prepared` → "Prepared", `delivering` → "Ready For Delivery", `completed` → "Completed"
- Walk-in shortcut: `pending` → `completed` (skip preparation/delivery)
- Collection orders: `prepared` → `completed` (no driver assignment)
- **Start Preparing**: popup with worker assignment dropdown + WhatsApp message preview (BM format)
- **Edit Order**: available at all stages (pending, preparing, prepared, delivering) — not just pending
- **Mark Delivered**: qty confirmation modal (driver adjusts for damage) → photo prompt → payment collection popup (CS only) → receipt generation
- Document generation auto-triggered on `completed`

### Document Types
- **Delivery Order (DO)**: Credit customers, signature line, batched into QB invoices later
- **Cash Sales (CS)**: Cash customers, PAID/UNPAID status
- **Receipt format**: 80mm thermal width, Courier New monospace, black & white, company logo at top
- **Bank details on receipts**: CS receipts + customer statements show Public Bank account details + WhatsApp payment slip reminder (when outstanding balance)
- Company: "TG AGRO FRUITS SDN BHD" on all documents
- PNG export via html2canvas for WhatsApp sharing
- Numbering: `DO-YYMMDD-NNN`, `CS-YYMMDD-NNN` via `dbNextId()`

### Payment Tracking
- Cash Sales: expected to pay immediately, aging dashboard highlights overdue (7d yellow, 14d red)
- Delivery Orders: batched into invoices via Invoicing tab (QB removed)
- Partial payments supported, payment_status auto-calculated (unpaid/partial/paid)

### Invoicing System (built 2026-04-04, 14 sections)
- **Tables**: `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, `sales_invoice_payments`, `sales_credit_notes`
- **Invoice workflow**: Create draft from completed DOs → Admin approves (draft→issued) → Record payments → Fully paid
- **Invoice creation**: Select credit customer → pick uninvoiced DOs → product aggregation preview → Create Draft Invoice
- **Invoice document**: A4 with company letterhead (TIN: 24302625000, MSIC: 46909), items table, DO references, totals (credits, payments, balance), bank details (Public Bank 3243036710), e-Invoice placeholder, signature block
- **Approval**: Admin-only, uses `sbUpdateWithLock()` for optimistic locking, sets `approved_by`/`approved_at`
- **Invoice payments**: Modal with amount, method (cash/bank/cheque), reference, bank slip upload. `recalcInvoicePaymentStatus()` auto-updates status
- **Credit notes**: CN modal with linked return dropdown or manual entry. Amount cannot exceed balance. A4 CN document with print/share
- **Payments tab**: Split into CS Payments (existing) + Invoice Payments (new). Invoice section: customer-grouped, aging colors (green/gold/orange/red), filters, summary cards
- **Statement of Account**: Invoice-based SOA with opening balance, transaction table (invoices=debit, payments/CNs=credit), running balance, aging summary (Current/30/60/90+), bank details
- **Dashboard**: 7 cards — Unpaid CS, Draft Invoices, Outstanding Invoices, Overdue Invoices, Uninvoiced DOs, Total Owed (includes drafts), Today
- **Reports**: Invoice Register (filterable by date/customer/status with totals) + Aging Report (customer-grouped 30/60/90 buckets)
- **ID formats**: `INV-YYMMDD-NNN`, `IP-YYMMDD-NNN`, `CN-YYMMDD-NNN` via `dbNextId()`
- **Customer fields added**: `ssm_brn`, `tin`, `ic_number`, `payment_terms_days` on `sales_customers`; `invoice_id` on `sales_orders`
- **Planning docs**: `docs/superpowers/specs/sections/` (14 section files), `docs/superpowers/specs/implementation/` (state + code reviews)

### Returns & Debit Notes
- Trust-based (customer sends photo proof, no physical return)
- Resolution: deduct from balance, refund, or debit note
- Debit notes auto-numbered (`DN-YYMMDD-NNN`), can be applied to future orders
- Return rate tracked per customer (green <5%, yellow 5-10%, red >10%)

### Key Patterns (Sales-specific)
- `workers` table uses column `active` (NOT `is_active`) — driver dropdown must filter `.eq('active', true)`
- `crop_varieties.id` is UUID type — `sales_products.variety_id` is UUID FK (not TEXT), **nullable** for non-pineapple products
- **Product packing fields**: `pcs_per_box` (INT, optional) and `weight_range` (TEXT, optional, e.g. "400-450g") — displayed on listings/documents as "Jackfruit Slices (5pcs, 400-450g)"
- All other sales table IDs are TEXT via `dbNextId()` with prefixes: SC, SP, SO, SI, SY, SR, DN, INV, II, IP, CN
- Customer duplicate prevention: partial unique index on phone WHERE NOT NULL
- **WhatsApp worker notification**: BM message format — "Order Baru", No, Pelanggan, Tarikh Hantar, Senarai. Uses `name_bm` field for product names (falls back to category BM translation map `CATEGORY_BM`)
- **Start Preparing popup**: worker assignment dropdown + WhatsApp message preview + Confirm & Start button
- Photo upload: resize to max 1200px, JPEG 80%, Supabase Storage bucket `sales-photos`
- **Payment slip upload**: optional bank transfer slip on payment records, stored in `sales-photos/payment-slips/`
- **Delivery payment flow**: after Mark Delivered → payment collection popup (CS only, pre-filled balance) → receipt shows PAID/UNPAID accordingly
- **Customer detail page**: click customer name → full profile with overview cards, purchases by month, purchases by product, outstanding CS, payment history, all orders
- **Orders tab**: grouped by status with colored section headers + count badges, status banner on each card
- **Payments tab**: grouped by customer, expandable rows, CS/DO split (DOs → Invoicing, no Pay button), multi-select checkboxes for batch payment
- **Invoicing tab**: billing summary appears on DO selection — aggregated products, Copy + Print buttons
- **Customer tab**: table layout with numbering, not cards
- **Custom calendar picker**: `calOpen()`/`calClose()` — dark theme styled, X button to close, no click-outside-close
- **Sidebar tab order**: Dashboard, Orders, Payments, Invoicing, Manage Customers, Manage Products, Reports
- **Bottom action bar**: `left: var(--sidebar-w)` on desktop (doesn't cover sidebar), full width on mobile
- `delivery.html`: standalone page, imports shared.css/shared.js, shows ALL delivering orders (not filtered by driver)
- `display-sales.html`: standalone page, no shared.css/shared.js dependency, uses Supabase REST API directly, token auth

### Design Spec & Plans
- Spec: `docs/superpowers/specs/2026-03-21-sales-module-design.md`
- Phase 1 plan: `docs/superpowers/plans/2026-03-21-sales-module-phase1.md`
- Phase 2 plan: `docs/superpowers/plans/2026-03-21-sales-module-phase2.md`

## Sub-Projects (same folder, separate deploys)
These live inside this folder but are gitignored. They share the same Supabase database and read from the same tables.

### TG Nanas Growth TV
- **Folder**: `TG Nanas Growth TV/`
- **File**: `index.html` (single-page, read-only TV display for growth data)
- **Netlify site**: nanasgrowth.netlify.app (site ID: `6c4382a2-098b-4c47-b46f-bb37a3ab3542`)
- **Custom domain**: nanasgrowth.tgfarmhub.com
- **Reads from**: `growth_records`, `pnd_blocks`, `crop_varieties` (same Supabase DB)
- **Auth**: No login, read-only, 4K TV optimized
- **Behavior**: Rotates status pages every 30s, auto-splits large groups, data refresh every 5min

### TG Weather Monitoring Website
- **Folder**: `TG Weather Monitoring Website/`
- **Deploy folder**: `TG Weather Monitoring Website/tg-weather-netlify/`
- **Domain**: weather.tgfarmhub.com
- **Reads from**: Same Supabase DB (weather-related tables)
- **Docs**: `USER_GUIDE.html`, `USER_GUIDE.pdf`

### Important: When changing DB schema
If you modify tables that these sub-projects read from (especially `growth_records`, `pnd_blocks`, `crop_varieties`), check and update the sub-project `index.html` files too.

## Blueprint — What's Next
- [x] **Sales Module** (`sales.html` + `delivery.html` + `display-sales.html`) — **DONE** (2026-03-21)
- [x] **Mobile responsiveness** audit across all modules — **DONE** (2026-03-21)
- [ ] **Farm Map Module** (`farmmap.html`) — Google Maps integration, draw block polygons, satellite imagery, area calculation (see details below)
- [ ] **`display-spray.html`** — TV display for Spray Tracker (KIV, needs spec)
- [ ] **Seedlings Module** (`seedlings.html`) — Booking, sales, stock, pricing
- [ ] **Cross-Module Dashboard** — Hub page with at-a-glance metrics
- [ ] **Notification System** — In-app alerts, optional WhatsApp/Telegram push

## Farm Map Module — Plan (Not Started)
- **File**: `farmmap.html` (single HTML file like other modules)
- **API**: Google Maps JavaScript API + Drawing Library + Geometry Library
- **Features**: View blocks on satellite map, draw/edit polygon boundaries, auto area calculation
- **Storage**: `geometry JSONB` column on Farm Config blocks table (stores GeoJSON polygon coordinates)
- **Map center**: Ladang PND coordinates (Waylon has GPS coords)
- **Google Maps API key**: Not yet created — use same Google Cloud project as OAuth
- **Billing safety**: Set daily API quota cap (100-200 loads/day) in Google Cloud Console → APIs & Services → Quotas. Also set $0 budget alert in Billing → Budgets & Alerts. $200/month free credit covers ~28,000 map loads — farm usage is well under this.
- **Prereqs before building**: 1) Enable Maps JavaScript API in Google Cloud Console, 2) Create API key restricted to Maps JS API + tgfarmhub.com domain, 3) Set daily quota cap + budget alert

## Growth Tracker — Parked Items
- Re-induction tracking (failed -> retry with history)
- ~~Full planting cycle management~~ — **DONE** (cycle_migration.sql, New Cycle button, View History)
- Growth measurements / health monitoring
- Harvest logging (actual date, yield, grade)
- ~~Per-cycle historical records~~ — **DONE** (View History in Farm Config)

## Tech Debt
- [x] **Pin Supabase SDK**: Pinned to `@2.49.1` across all 5 modules (2026-03-11)
- [x] **Error handling**: Added `sbQuery()` wrapper in shared.js — try-catch + notify (2026-03-11)
- [x] **Loading states**: Added `showLoading()`/`hideLoading()`/`btnLoading()` in shared.js + CSS (2026-03-11)
- [x] **Accessibility**: Added focus-visible, skip links, `role="main"`, `<nav>` with aria-label, focus trap for modals (2026-03-11)
- [x] **Adopt `sbQuery()`**: Migrated all Supabase calls across all 5 modules (103 total calls) (2026-03-11)
- [x] **`.select()` on mutations**: Added `.select()` to all insert/update/delete/upsert calls in index.html + spraytracker.html (2026-03-13)
- [x] **Google OAuth login**: Admin can login via Google; workers use PIN. RLS policies for `authenticated` role added (2026-03-14)
- [x] **Product packaging fields**: packaging_size, packaging_unit, packaging_type on pnd_products (2026-03-14)
- [x] **Product lock-down expanded**: Dose unit, active ingredients, packaging fields now also locked once set (2026-03-14)
- [x] **WhatsApp job sharing**: BM message format with emojis, popup with Copy Text + WhatsApp buttons (2026-03-14)
- [x] **Block reminder improvements**: Clickable filter for incomplete blocks, excludes inactive blocks (2026-03-14)
- [x] **Default tank size**: Changed to 1000L for new spray jobs (2026-03-14)
- [x] **Multi-product spray log fix**: Edit Job Modal completion path now logs all products in tank mix (not just primary). Backfilled 2 existing completed jobs missing Benocide 50 WP spray logs (2026-03-14)
- [x] **Latest sprays view fix**: Changed `pnd_latest_sprays` to sort by `created_at DESC` instead of `date_completed DESC`. Deleted bad future-dated spray log for N2+Linotyl (2026-03-18)
- [x] **Summary tab overhaul**: Block status/variety/age now from `block_crops`+`crop_statuses` (Farm Config). Added status filter dropdown, variety column, "No Data" card, status grouping with separators, dimmed no-data rows (2026-03-18)
- [x] **Report consolidation**: Removed redundant reports (By Single Block, By Date Range, By Month — 11→8 reports). Added date range to Block/Product/AI reports. Added "Select All" for blocks, "All Products"/"All Ingredients" options (2026-03-18)
- [x] **Report columns enriched**: Added Done By (worker), Water Used (tanks × size), Product Used (per-product for tank mix). Logged By now shows supervisor name. Auto-generated notes hidden. Tank mix rows merged with `rowspan` (2026-03-18)
- [x] **Offline resilience**: Offline banner, sbQuery() onLine check, sbMutate() retry with exponential backoff (2026-03-21)
- [x] **Module CSS extraction**: Extracted 714 lines to index.css, inventory.css, workers.css, spraytracker.css, growthtracker.css (2026-03-21)
- [x] **Optimistic locking**: sbUpdateWithLock() checks updated_at; applied to 8 critical paths in block_crops + pnd_jobs (2026-03-21)
- [x] **Website quality overhaul** (2026-03-21): Standardized green primary buttons across all modules, replaced 15 browser confirm() with styled confirmAction() modals, added Save buttons for Farm Config inline edits (variety days), block deactivation requires confirmation, btnLoading() on 6 key save operations, mobile touch targets min 36-40px, table horizontal scroll on all modules, Growth Tracker hides 8 columns on mobile (15→7), text overflow protection on all tables, fixed 37 missing .select() on mutations, fixed worker name race condition (payroll cascade uses worker_id not worker_name), inventory modal-card→modal-box consistency, spray tracker sort dropdown on Active Jobs, growth tracker clear filters button
- [x] **Sales module** (2026-03-21): Full 8-phase build — DB migration, products, customers, orders, documents (DO/CS), payments, QB invoicing, returns/debit notes, 7 reports, delivery.html (driver page), display-sales.html (TV display)
- [x] **Logo overhaul** (2026-03-22): Replaced all base64 inline logos with `assets/logo.png` across 6 modules. New square 1:1 logo (pineapple + TG overlaid). Removed "Ladang PND" subtitle from workers/growthtracker/sales (kept in spraytracker only). Standardized CSS — no inline style overrides, all logos use shared.css `.sidebar-logo` or index.css `.hub-logo` (both 70x70, `object-fit:contain`). Original logo backed up as `assets/logo_original.png`. Logo designer skill installed for future SVG refinement.
- [x] **Sales module UX overhaul** (2026-03-22): Logo updated to user-provided TG Agro Fruits (cropped, white bg, rounded corners, 84px). Customer search dropdown shows on focus with click-outside-close. Custom calendar picker for date fields. Removed all 13 click-outside-to-close on modals (sales/spray/index). Status labels renamed (Pending→Order Received, Delivering→Ready For Delivery). Orders grouped by status with colored banners. Customer tab switched from cards to table with numbering. Customer detail page (profile, monthly purchases, product breakdown, outstanding, payment history). Payments tab grouped by customer with CS/DO split, multi-select batch payments, bank slip upload. Invoicing billing summary with copy/print. Start Preparing popup with worker assignment + WhatsApp BM message. Delivery payment collection step before receipt. Receipt redesigned: 80mm thermal, B&W, monospace, company logo, "TG AGRO FRUITS SDN BHD". Desktop max-width 1200px + larger fonts. Sidebar redesigned: clickable brand→hub, mobile logout in brand bar, hidden user section on mobile. Bottom action bar offset for sidebar. Sales order data wiped clean for fresh start. Light theme trial created (KIV).
- [x] **Login system overhaul** (2026-04-01): Auto-login on 6th PIN digit, localStorage persistent sessions (replaces sessionStorage), last username remembered, multi-device detection (session_token in users table, polled every 30s), inactivity timeout 60min, numeric-only PIN enforcement on all fields. All 7 modules updated.
- [x] **Workers payslip enhancements** (2026-04-01): Payslip shows long-term loan details (purpose, amount, repaid, balance). "Print All Payslips" button — A5 slips, 2 per A4 landscape, sorted by name. Payroll summary row numbering + total count. Deactivated workers excluded from payroll print.
- [x] **Sales product flexibility** (2026-04-01): Product variety now optional (nullable variety_id) for non-pineapple items. Separate pcs_per_box and weight_range fields. Products without variety handled in dropdown + reports.
- [x] **Sales order editing** (2026-04-01): Edit Order available at all stages (not just pending). Mark Delivered includes driver qty confirmation modal (adjust for damage, recalculates totals). FK constraint fix on delete returns (delete returns before items/order).
- [x] **Sales bank details** (2026-04-01): Public Bank account details + WhatsApp payment slip reminder on 80mm CS receipts and A4 customer statements (when outstanding balance). Clickable doc numbers in Payments tab → order detail.
- [x] **Sales module refinements** (2026-03-23): Audit fixes — spraytracker "Ladang PND" → "TG Agro Fruits Sdn Bhd" in print headers, base64 logos replaced in index/inventory login screens. Desktop font breakpoints added to all 4 module CSS files (inventory/workers/spraytracker/growthtracker). trapFocus memory leak fixed in shared.js (releaseFocus called on Escape/close). confirmAction modals no longer close on outside click. Duplicate CSS removed in sales.css. Z-index standardized (calendar 1050). Mark Prepared now includes qty adjustment popup (actual vs ordered, recalculates totals). Photo modal redesigned with 3 options: Take Photo (camera), From Album (gallery), Skip. Worker assignment reflected in order cards, detail view, dashboard active orders table, and WhatsApp message (👷 Tugasan field). WhatsApp section hidden until worker selected in Start Preparing. Payments tab only shows completed orders. Dashboard outstanding only counts completed CS orders. New "Delivery Order (Uninvoiced)" summary card on dashboard. 5 dashboard cards in single row. Growth tracker table headers shortened + nowrap + 1200px min-width. Sidebar tab order: Dashboard→Orders→Payments→Invoicing→Manage Customers→Manage Products→Reports. Staff guide pages: `guide-sales.html` (EN), `guide-sales-cn.html` (中文), `walkthrough-sales.html` (interactive 14-step walkthrough with mockups).

- [x] **Sales invoicing module** (2026-04-04): Full invoicing system built via /deep-plan + /deep-implement (14 sections). DB migration (5 tables + RLS), invoice creation from DOs, approval workflow, A4 invoice/CN/SOA documents, payment recording with slip upload, credit notes, payments tab split (CS + Invoice), dashboard with 6 financial cards, Invoice Register + Aging reports. QuickBooks references fully removed. Customer fields added (SSM/BRN, TIN, IC, payment_terms_days). Planning docs in `docs/superpowers/specs/`. 15 commits (4fca6ae through fcb131f).
- [x] **Workers module enhancements** (2026-04-04): Expense report generator in Summary tab (multi-select category filter, CSV export). Changelog tab with audit_log viewer (date/type/user filters, CSV export). Responsibility types CRUD in Roles tab (with cascade rename to all linked tables). Worker profile "Monthly Responsibilities" section with auto-populate to payroll. New DB table `worker_default_responsibilities`. Workers table: added Responsibilities, Canteen, Cigarettes, Sal. Advance, Overpayment (hidden), Carried Fwd (hidden), Total Advances columns with tinted backgrounds + totals row. Excel-style show/hide toggle for extra columns. Removed individual advance stat cards. Zero pay fix (workers with 0 net pay can be marked paid). Payslip confidential banner: "SULIT — Dokumen Sulit, Dilarang Berkongsi" on all payslips.
- [x] **Sales dashboard draft invoices** (2026-04-04): Added Draft Invoices card showing count + amount, included in Total Owed calculation.
- [x] **Multi-company architecture** (2026-04-05): Two-company split (TG Agro Fruits + TG Agribusiness). `companies` table, `company_id` on 35 tables, hub page company switcher, module filtering by company, sidebar company context in all modules, `next_id()` company-prefixed document numbering (AF-/AB-), Company Overview report on hub, delivery/TV display hardcoded to Agro Fruits. 15 commits, 3 audit rounds. Design spec + implementation plan in docs/superpowers/.

## Audit Results (2026-03-22 — all issues fixed 2026-03-23)
Full report: `AUDIT-2026-03-22.md` — 12 issues found, 0 critical, all resolved.

## Audit Results (2026-03-11)
| Category | Status | Priority |
|----------|--------|----------|
| Security | Good | — No critical issues, XSS mitigated via `esc()` |
| Libraries | Good | Pin Supabase SDK to exact version |
| Code duplication | Good | shared.js/css properly used |
| Error handling | Partial | Missing try-catch on Supabase queries |
| Performance | Good | Lightweight, lazy-loaded assets |
| Accessibility | Needs work | Minimal ARIA, no semantic buttons, no focus mgmt |
| Mobile | Good | Responsive breakpoints at 768px/400px |
| Dead code | Very good | No unused imports or orphaned code |
| Sub-projects | Good | Isolated, no conflicts |
