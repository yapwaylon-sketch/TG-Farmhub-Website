# TG FarmHub Website

## IMPORTANT — Memory Instructions
- **This file (`CLAUDE.md`) is the single source of truth** for project context, conventions, credentials, and roadmap
- This project lives on local disk on each PC (`C:\dev\TG-Farmhub-Website`) and syncs between PCs via git/GitHub — NOT OneDrive (migrated 2026-04-09)
- **Always save new learnings, decisions, and session outcomes back into this file** — it's the only memory mechanism that survives across PCs (Claude's per-PC `~/.claude/projects/.../memory/` folder is keyed by working directory path and does NOT auto-sync)
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
- Project syncs between two Windows PCs (main PC + secondary PC) via git/GitHub — migrated off OneDrive on 2026-04-09
  - Both PCs: `C:\dev\TG-Farmhub-Website` (and `C:\dev\TG-Nanas-Growth-TV` as a sibling)
  - Daily workflow: `git pull --ff-only origin main` when sitting down, `git push origin main` when standing up
  - Shell aliases `gitpull` and `gitpush` set up on both PCs in Git Bash (`~/.bashrc`), PowerShell (`$PROFILE`), and CMD (doskey via `HKCU AutoRun` → `C:\Users\yapwa\cmd-aliases.cmd`). User prefers typing `gitpull`/`gitpush` over the full commands. Claude's Bash tool still uses the full form because it runs in a non-interactive shell that doesn't load user profiles.
  - Never work on both PCs at the same time on the same repo
  - If `git pull --ff-only` errors with "non-fast-forward", you forgot to push from the other PC — push from there first

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
- **Theme**: Warm **light theme** — cream background (`#FAF6EF`), white cards, deep purple text (`#2A1A3E`), gold accent (`#D4AF37`), purple secondary accent (`#6B4C8A`). Font: 'Plus Jakarta Sans'. **Note:** CSS variable names are stale — `--green` actually holds gold `#D4AF37`, `--green-light` holds purple `#6B4C8A`. Use the hex values, not the variable names as semantic hints. This is a change from the previous dark theme; some older docs/notes in this file may still reference the dark palette.

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
| `seedlings.html` | Oil Palm Seedlings module (batches, bookings, collections, L3.1 tracking, reports) |
| `seedlings.css` | Seedlings module styles |
| `tender.html` | Tender Monitoring module (dashboard, local orders, documents, reports, AI LO import) |
| `tender.css` | Tender module styles |
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
- **Main repo**: github.com/yapwaylon-sketch/TG-Farmhub-Website (public, main branch) — local at `C:\dev\TG-Farmhub-Website` on both Windows PCs
- **Nanas TV repo**: github.com/yapwaylon-sketch/TG-Nanas-Growth-TV (public, main branch) — local at `C:\dev\TG-Nanas-Growth-TV` on both Windows PCs (split out 2026-04-09 from being a gitignored sub-folder of the main repo)
- **Weather sub-project**: NOT yet on GitHub. Lives at `C:\Users\yapwa\OneDrive\TG Web and Android Project\TG Projects Deffered\TG Weather Monitoring Website\` (still on OneDrive, deferred to a dedicated future session — needs MET token rotation, repo structure decision, Netlify build source verification before it can be moved off OneDrive)

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
- Netlify token: `nfp_otZ4XU2D5uL9r9Z5g7SEL99asLGWLb997832` (no expiration; rotated 2026-04-09 — previous token `nfp_jQof...414e` was revoked/dead)
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
- **Oil Palm Seedlings Growth** — Monitor oil palm seedling growth stages and nursery health
- **Staff Claims** — Personal expense claims, approvals, and reimbursement tracking

### Recently Built
10. **Oil Palm Seedlings** (`seedlings.html` + `seedlings.css`) — Batch lifecycle management, booking with deposit/payment tracking, collection with L3.1 certificate tracking, walk-in cash sales, printable booking slips, MPOB monthly reports, batch summary, cash flow projection. Under TG Agribusiness. 7 DB tables (`seedling_suppliers`, `seedling_batches`, `seedling_batch_events`, `seedling_customers`, `seedling_bookings`, `seedling_payments`, `seedling_collections`). Supabase storage bucket: `seedling-photos`. Spec: `docs/superpowers/specs/2026-04-09-seedlings-module-design.md`, Plan: `docs/superpowers/plans/2026-04-09-seedlings-module-plan.md`
11. **Tender Monitoring** (`tender.html` + `tender.css`) — Government tender tracking for LPNM pineapple sucker supply contracts. Dashboard with key metrics (qty/value/payment/expiry alerts), Local Order tracking grouped by batch with status workflow (pending→preparing→delivering→delivered→invoiced→paid), document management (SST/contract/bond/LO/submissions grouped by type), 3 reports (summary/batch completion/payment status). AI-powered LO PDF import via Claude API (pdf.js renders → Claude Vision extracts fields → editable preview → batch save). Under TG Agribusiness, Projects Monitoring category. 3 DB tables (`tenders`, `tender_los`, `tender_documents`) + `app_config` for API key storage. Supabase storage bucket: `tender-documents`.

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
Growing → To Induce → Induced → Harvesting → Suckers → To Replant → *(Start New Cycle → Growing)*
- **Harvesting** is a manual marker flipped by supervisor when active harvest begins. Blocks in Harvesting are excluded from the "Approaching Harvest" and "Overdue Harvest" dashboard cards on Growth Tracker (countdown warnings silence once supervisor acknowledges). "Days After Induce" and "Days to Harvest" countdowns are hidden on Harvesting rows in both Growth Tracker and TV Display — the Harvest Window date range remains visible.

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

**Note**: "Abandoned" is handled by deactivating the block in Block Management (not a status).

## SQL Migrations
All migrations have been applied to Supabase. Migration `.sql` files were removed from the repo on 2026-03-22 (historical reference only — schema lives in the database).

## Shared Assets
- **Folder**: `assets/` in project root — deployed to `https://tgfarmhub.com/assets/`
- **Files**: `logo.png` (TG Agro Fruits pineapple, 56KB), `logo.jpg` (460KB), `logo-agribusiness.png` (TG Agribusiness leaf, transparent bg), `logo-agribusiness.jpg` (cropped), `logo-agribusiness-original.jpg` (original with excess whitespace)
- Sub-projects reference `https://tgfarmhub.com/assets/logo.png` (not local copies)
- To update: edit file in `assets/`, redeploy main site, all sub-sites auto-update
- Local `assets/` folder = backup + source of truth, synced via git
- **Per-company logo usage**: Hub page shows both logos side by side (header + login). Sidebar in modules uses company-specific logo: Sales/Delivery → `logo.png` (Agro Fruits), Inventory/Workers/Spray/Growth → `logo-agribusiness.png` (Agribusiness). Company switcher on hub is a segmented pill toggle (text only, no logos — avoids redundancy with header).

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
- **Tables WITHOUT company_id** (never filter/insert): app_config, audit_log, block_crops, companies, crop_statuses, crop_varieties, crops, id_counters, payroll_entries, payroll_responsibilities, pnd_block_statuses, pnd_blocks, sales_drivers, task_entries, task_units, users
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

### Invoicing System (built 2026-04-04, overhauled 2026-04-09)
- **Tables**: `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, `sales_invoice_payments`, `sales_credit_notes`
- **Invoice statuses**: `draft` → `issued` → `paid`. Also `voided` (keeps items/junction for audit) and `cancelled` (draft-only, deletes items/junction)
- **Single-draft rule**: Only one draft invoice can exist at a time. Must approve or cancel before creating another. Prevents numbering gaps on cancel.
- **Invoice workflow**: Create draft from completed DOs → Admin approves (draft→issued) → Record payments → Fully paid
- **Edit Draft**: Modal to change date, terms, notes, remove individual DOs (min 1). Available before approval only.
- **Invoice creation**: Select credit customer → pick uninvoiced DOs (cross-customer blocked with warning) → "N selected" badge on customer headers → product aggregation billing summary → Create Draft Invoice. Select-all per customer auto-expands group.
- **Add More DOs**: Dedicated modal (#inv-adddos-modal) with running count/total, select all/clear, live button label. Replaces old confirmAction popup.
- **Void Invoice** (issued only): Keeps items + junction intact for audit. Auto-generates zeroing CN for full grand_total. Nulls DO invoice_ids (frees for re-invoicing). Stores `voided_at`, `voided_by`, `void_reason`. Blocked if payments exist.
- **Unlink Single DO** (issued only, >1 DO): Removes one DO from invoice, auto-generates CN for the difference, recomputes remaining items/totals.
- **Counter rewind**: `rewind_id()` Postgres RPC decrements `id_counters.last_number` on draft cancel only if the cancelled ID was the latest in sequence. No gap for common "oops cancel" case.
- **invRecomputeInvoice()**: Shared helper for item re-aggregation (delete items → rebuild from linked DOs → update totals). Called from Add DOs, Edit Draft, Unlink DO.
- **Invoice A4 document**: Two-column Bill To (customer name/SSM/TIN/IC/address/phone) + Invoice Details (number/date/due/terms). Items table, DO references, notes (contenteditable inline), totals, amount in words ("Ringgit Malaysia ... Only"), bank details (Public Bank 3243036710). Prepared By + "This is a computer-generated document. No signature is required." Footer: "Thank you for your business. For enquiries: 012-3286661"
- **DO Summary attachment** (page 2+): Auto-generated when invoice has linked DOs. Same letterhead, each DO as separate block (number, date, driver, items table, subtotal). `page-break-inside:avoid` per DO block. Grand total at bottom.
- **Credit Note A4**: Same Bill To layout. Amount in words. Prepared By + electronic doc note.
- **DO A4 signature**: Issued By (name + signature line) + Received By (Name, IC No, Signature, Company Stamp dashed box).
- **Document export**: Print → browser print window (CSS page breaks, multi-page native). Download → same print window, user "Save as PDF". Share → html2canvas captures each .a4-page as separate image (scrollIntoView + modal constraint removal), multi-file Web Share API for WhatsApp, fallback popup with thumbnails + Download All.
- **INV_DEFAULT_NOTES**: Variable for default notes pre-fill on new drafts (currently empty, ready for use).
- **`amountInWords()`**: Converts number to Malaysian ringgit words format, used on Invoice + CN A4.
- **Invoice list performance**: Card headers render once; detail section built on click via `invInsertDetail()` and removed on collapse. No full re-render on toggle.
- **Approval**: Admin-only, uses `sbUpdateWithLock()` for optimistic locking, sets `approved_by`/`approved_at`
- **Invoice payments**: Modal with amount, method (cash/bank/cheque), reference, bank slip upload. `recalcInvoicePaymentStatus()` auto-updates status
- **Credit notes**: CN modal with linked return dropdown or manual entry. Amount cannot exceed balance.
- **Payments tab**: Split into CS Payments (existing) + Invoice Payments (new). Invoice section: customer-grouped, aging colors (green/gold/orange/red), filters, summary cards
- **Statement of Account**: Invoice-based SOA with opening balance, transaction table (invoices=debit, payments/CNs=credit), running balance, aging summary (Current/30/60/90+), bank details
- **Dashboard**: 7 cards — Unpaid CS, Draft Invoices, Outstanding Invoices, Overdue Invoices, Uninvoiced DOs, Total Owed (includes drafts), Today. Excludes voided invoices.
- **Reports**: Invoice Register (filterable by date/customer/status with totals) + Aging Report (customer-grouped 30/60/90 buckets)
- **ID formats**: `AF-INV001`, `AF-IP001`, `AF-CN001` via `dbNextId()` (company-prefixed, no date component, LPAD 3 digits, auto-extends to 4+ at 1000)
- **Customer detail page**: All financial stats (Total Orders, Purchases, Paid, Outstanding, CS/DO count, Purchases by Month, Purchases by Product, Outstanding CS) use completed orders only — pending/preparing/delivering excluded. "All Orders" table still shows all statuses.
- **Customer fields**: `ssm_brn`, `tin`, `ic_number`, `payment_terms_days` on `sales_customers`; `invoice_id` on `sales_orders`
- **DB columns added (2026-04-09)**: `voided_at` (TIMESTAMPTZ), `voided_by` (TEXT), `void_reason` (TEXT) on `sales_invoices`
- **DB RPC added (2026-04-09)**: `rewind_id(p_id TEXT)` — decrements `id_counters.last_number` if the ID's sequence matches the current counter
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
- **Order sorting**: active orders sorted by `delivery_date` ASC + `delivery_time` ASC (most urgent first, no date = bottom); completed/cancelled grouped by `completed_at` (not `order_date`)
- **`completed_at`** column on `sales_orders`: set once when status changes to `completed`, never updated by subsequent edits. Used for completed order grouping and date filtering.
- **`cancel_reason`** column on `sales_orders`: required text when cancelling an order. Shown on order card (red banner) and detail view (red box below cancelled timeline step).
- **Delivery time**: `type="time"` input (HH:MM 24h), displayed via `fmtTime12()` as 12h ("2:00 PM"). Stored as HH:MM in `delivery_time` column.
- **Pcs-ordered items**: `order_pcs != null` means item was ordered by pieces. Display shows `order_pcs + " pcs"` everywhere (cards, detail, dashboard). `quantity` = 0 until weighed at Mark Prepared, then = `actual_weight_kg`. All display locations check `item.order_pcs != null` to decide format.
- **Mandatory photos**: Mark Prepared and Mark Delivered require a photo (Skip button hidden via `soShowPhotoModal(..., true)`). Walk-in quick complete photo is optional.
- **`confirmAction` renders HTML body** (not escaped) — callers can pass form fields, `<strong>` tags, etc.

### Design Spec & Plans
- Spec: `docs/superpowers/specs/2026-03-21-sales-module-design.md`
- Phase 1 plan: `docs/superpowers/plans/2026-03-21-sales-module-phase1.md`
- Phase 2 plan: `docs/superpowers/plans/2026-03-21-sales-module-phase2.md`

## Seedlings Module — Architecture

### Tables (7)
| Table | Purpose |
|-------|---------|
| `seedling_suppliers` | Seed producers (IOI, FELDA, Sawit Kinabalu, etc.) |
| `seedling_batches` | Seed batches — lifecycle from planting to sold out, allocation tracking |
| `seedling_batch_events` | Inventory events: transplant, cull, doubleton gain, adjustment |
| `seedling_customers` | Seedling buyers — estates, smallholders, agents. Cross-company link to `sales_customers` |
| `seedling_bookings` | Customer reservations with deposit/payment/collection tracking |
| `seedling_payments` | Payment records for deposits, top-ups, collection payments |
| `seedling_collections` | Collection events — each = one L3.1 certificate issued |

### Batch Lifecycle
`pre_nursery` → `main_nursery` (transplant at ~4 months) → `selling` (manual, 10+ months) → `sold_out` (auto when available = 0) → `closed` (manual)

### Key Business Rules
- **Allocation**: default 50% of seeds = bookable cap (configurable per batch)
- **Payment-controlled collection**: customer can only collect `floor(total_paid / price) - total_collected`
- **L3.1**: one per collection, pre-printed serial from MPOB booklet, system tracks usage
- **Doubletons/tripletons**: split and kept, increase count above seeds planted
- **MN only**: no pre-nursery sales, minimum 10 months
- **Pricing**: default per batch, overridable per booking

### Company Addresses
- **Office** (booking slips): Lot 1609, Kpg. Riam Jaya, 98000 Miri, Sarawak
- **Farm/License** (L3.1): Lot 174, Block 9, Lambir Land District, 98000 Miri, Sarawak
- MPOB License: 522231011000

### ID Prefixes (company code AB-)
| Entity | Prefix | Example |
|--------|--------|---------|
| Supplier | SS | AB-SS001 |
| Batch | SB | AB-SB001 |
| Batch Event | SE | AB-SE001 |
| Customer | SC | AB-SC001 |
| Booking | BK | AB-BK001 |
| Payment | SP | AB-SP001 |
| Collection | CL | AB-CL001 |

Batch display number is separate: `1-2026`, `2-2026` (sequential within year).

### Sidebar Tabs (6)
Batches, Bookings, Collections, Customers, Suppliers, Reports

### Reports (3)
1. **MPOB Monthly**: seeds planted, transplanted, culled, doubletons, sold (with L3.1), balance
2. **Batch Summary**: all batches with full qty breakdown + totals
3. **Cash Flow Projection**: monthly booking payments + cash sales + projected due

### Booking Slip
Printable/shareable document — office address header, items table, deposit/balance, customer contact, batch/variety, expected ready date, T&C (3 terms), signature lines. Print + WhatsApp share.

### Design Docs
- Spec: `docs/superpowers/specs/2026-04-09-seedlings-module-design.md`
- Plan: `docs/superpowers/plans/2026-04-09-seedlings-module-plan.md`

## Tender Monitoring Module — Architecture

### Tables (3 + 1 config)
| Table | Purpose |
|-------|---------|
| `tenders` | Master tender records — tender_no, variety, dates, qty, price, value, bond, status |
| `tender_los` | Local Orders — per-LO tracking with status workflow, delivery/invoice/payment fields |
| `tender_documents` | File attachments per tender or LO — SST, contracts, bonds, submissions |
| `app_config` | Key-value config store — holds Anthropic API key for AI import |

### LO Status Workflow
`pending` → `preparing` → `delivering` → `delivered` → `invoiced` → `paid`

Each transition prompts for relevant fields: delivering/delivered→DO number+date, invoiced→invoice no+date, paid→amount+ref+bank.

### Hub Category Banners (TG Agribusiness)
Modules grouped under 3 banners via `MODULE_CATEGORIES` in index.html:
- **Operations**: Pineapple Spray, Pineapple Growth, Oil Palm Sales, Oil Palm Growth (coming soon), Inventory
- **Management**: Worker Management, Staff Claims (coming soon)
- **Projects Monitoring**: Tender

### AI LO PDF Import
Upload LO PDF → pdf.js (CDN 3.11.174) renders pages to canvas → base64 JPEG → Claude API (Sonnet, vision) extracts fields (lo_number, dates, recipient, area, officer, qty) → editable preview table → batch save. API key stored in `app_config` table, loaded automatically on modal open. Requires `anthropic-dangerous-direct-browser-access` header for browser CORS.

### Sidebar Tabs (4)
Local Orders, Documents, Dashboard, Reports

### ID Prefixes (company code AB-)
| Entity | Prefix | Example |
|--------|--------|---------|
| Tender | TD | AB-TD001 |
| Local Order | LO | AB-LO001 |
| Document | TF | AB-TF001 |

### Supabase Storage
Bucket: `tender-documents` (public). Path: `{tender_id}/{timestamp}.{ext}`

### Current Tenders
- **AB-TD003**: LPNM.400-5/8/24 (MD2) — 1,500,000 sulur, RM1.78, RM2,670,000, 2-year contract (Mar 2026 – Mar 2028), bond RM66,750

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
- [x] **Seedlings Module** (`seedlings.html`) — Batch lifecycle, booking/collection, L3.1 tracking, MPOB monthly reports, cash flow projection, booking slips (2026-04-10)
- [x] **Tender Monitoring** (`tender.html`) — Government tender tracking, LO workflow, document management, AI PDF import (2026-04-10)
- [ ] **Oil Palm Seedlings Growth** — Monitor seedling growth stages and nursery health (coming soon)
- [ ] **Staff Claims** — Personal expense claims, approvals, reimbursement tracking (coming soon)
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
- [x] **Packing display redesign** (2026-04-07/08): `display-sales.html` rebuilt in Industrial Warehouse style — 4-column always-visible grid (Received/Preparing/Prepared/Delivering), Inter typography, orange `#FF5722` header bar, sharp 90° dark gray cards with colored left borders, 48px count numerals, no emojis. Per-column pagination, FIFO sort, live "UPDATED Ns AGO" footer ticker, "N COMPLETE TODAY" counter. **Data filter changed:** now shows ALL active orders (pending/preparing/prepared/delivering) regardless of delivery_date, plus today's completed for the footer — previously filtered to today+tomorrow, which hid overdue work. **Card format:** customer name (white CAPS, 14px) / `ITEMS:` row (`1000KG - MD2 Whole Fruit (1KG+)` per item, uses `item.unit` from order — kg/pcs/box work automatically) / `DELIVERY:` row (15px, DD/M/YYYY in column color) / `ORDER NO:` row. 13 commits via subagent-driven workflow with two-stage review per task. Spec at `docs/superpowers/specs/2026-04-07-packing-display-redesign-design.md`, plan at `docs/superpowers/plans/2026-04-07-packing-display-redesign.md`.
- [x] **TV Display hub tab** (2026-04-08): New `TV Display` nav tab on hub between Farm Configuration and User Management. Shows card grid linking to Growth Tracker (nanasgrowth.tgfarmhub.com), Weather (weather.tgfarmhub.com), Sales Packing Station (display-sales.html), and PND Spray Tracker (Coming Soon, disabled). Each card opens in new tab; password gates on target displays unchanged. Permission-gated via new `tvdisplay` MODULES entry with `view` permission — admin always sees; non-admin needs the tick. CSS in index.css under `.tv-display-grid` / `.tv-display-card`.
- [x] **Harvesting crop status** (2026-04-08): New lifecycle status between Induced and Suckers. Inserted via Node pg script into `crop_statuses` (Pineapples crop, sort_order 40). Cleanly renumbered: Growing=10, To Induce=20, Induced=30, Harvesting=40, Suckers=50, To Replant=60. **Supervisor flips manually** — no modal trigger, no auto-migration. **Growth Tracker:** orange `.badge-harvesting` (rgba(255,140,40,0.2) / #FF8C28); dashboard cards "Approaching Harvest" and "Overdue Harvest" now exclude Harvesting blocks (once supervisor marks it, the warning silences); row tinting (overdue/approaching) skipped on Harvesting rows; "Days After Induce" and "Days to Harvest" countdown cells display "—" on Harvesting rows; Harvest Window date range still shown. **TV Display (TG Nanas Growth TV):** `STATUS_ORDER` now includes `harvesting` between induced and suckers; `DEFAULT_SORT` for harvesting = `date_induced_start asc`; new `isHarvesting` page flag; Harvesting page layout shows only Induced date + Harvest Window columns (no countdown columns); same orange badge. **Spray Tracker:** `.badge-harvesting` recolored to same orange for cross-module consistency. Deployed to both tgfarmhub.com and nanasgrowth.tgfarmhub.com.
- [x] **Inventory supplier permission + mapUserFromDb fix** (2026-04-08): Added `manageSuppliers` permission to Inventory MODULES entry in index.html (sits between `editProducts` and `editTransactions`). Removed `"suppliers"` from inventory's hardcoded staffHiddenPages list; gated Suppliers nav, "Add Supplier" button, and per-row Edit/Delete via new `hasPermission()` helper in inventory.html (admin always true, else reads `currentUser.permissions.inventory[permKey]`). Server-side-style guards added to `saveSupplier()` and `deleteSupplier()`. **Critical bug found + fixed:** inventory's `mapUserFromDb()` was dropping the `permissions` column entirely, so all permission ticks had zero effect on non-admin users in inventory. Added `permissions: row.permissions || {}`. Audited all other modules: index.html ✓, workers.html ✓ (inline map line 960), sales/growth/spray/delivery all read from localStorage (hub writes permissions on login) ✓, delivery uses raw rows (column name matches) ✓. Only inventory was broken. **Staleness note:** modules reading from localStorage will show stale permissions until user logs out + back in from hub; user declined a periodic refresh poller as unnecessary.
- [x] **Spray Tracker Summary redesign — monitoring watchlist + drill-down** (2026-04-08): Summary tab rewritten around a per-company watchlist model. No products show by default — user must explicitly add products to a monitoring list. **Watchlist bar:** "Monitoring N products" count + removable chips + `+ Add to Monitoring` + `Clear All`. **Add to Monitoring modal:** products grouped by `pnd_products.product_type` (Fungicide/Pesticide/Herbicide/PGR/Adjuvant/Carbide/Other), search box, checkboxes, pre-ticked if already watched. **Type filter pills** (display-only, not a mode): `All · Fungicide · Pesticide · ...`; persists per company. **Two-level drill-down:** Level 1 = simplified per-block table (Block · Status · Last Sprayed ↕ · Days Ago · Product Sprayed (AI + Name) · Type column only when "All" pill), sortable by Last Sprayed (default oldest first = neglected blocks float up), blocks with no history sink to bottom regardless. When a specific type pill is selected, a sub-pill row appears below (`All Fungicides · Benocide 50 WP · ...`) for Level 2 drill-in. Level 2 = existing 9-column detailed table for that one product's AI combo. Drill-in NOT persisted (always lands on Level 1 on reload — big picture first). **Auto-prune:** archived/deleted monitored products silently removed on next render with one-time notify. **localStorage keys:** `tg_spray_watchlist_<companyId>` and `tg_spray_type_filter_<companyId>`. Agribusiness is the only company that uses spray tracking. Status filter still applies across all levels.
- [x] **PnD Spray Tracker TV display** (2026-04-09): New `display-spray.html` at root (deployed to `tgfarmhub.com/display-spray.html`). Standalone, Supabase REST direct, password gate (shared TV password), Agribusiness-only. **Layout (mix-A — static header + rotating body):** top strip has title "Ladang Pest and Disease Spray Monitoring" + logo + stats (Active Blocks, Watched AIs, Overdue >21d) + live clock + fullscreen button. **Rotating body** — one page per watched active ingredient (Mancozeb, Benomyl, Aluminium fosetyl, etc.), 30s cadence. Each AI page shows: big AI name pill + product list + counts (overdue/due-soon/ok/no-data) + table (Block · Status · Variety · Last Sprayed · Days Elapsed · Product Used) grouped by crop status, sorted by days elapsed desc within group (most neglected first), nulls at bottom. Auto-splits into sub-pages by viewport height (Growth TV style). **Interactive controls:** fullscreen button (header), pause/play button (footer), clickable page dots to jump directly to any page (restarts timer). Color thresholds on Days Elapsed: green <14d, gold 14–21d, red >21d. **Colored status group headers** matching the rest of the system (Growing green, To Induce gold, Induced blue, Harvesting orange, Suckers brown, To Replant red) with 4px left border, tinted background, matching text color. **Refresh:** 5min. **Empty state** when no AIs configured: "Open Hub → TV Display → Configure". **Config:** new `pnd_tv_config` table with `company_id` PK, `watched_ai_ids` JSONB, `updated_at`; RLS open for anon + authenticated. Seeded empty row for `tg_agribusiness`. **Configure button** is attached directly below the PND Spray Tracker card on the hub TV Display tab (wrapped in a `.tv-display-cell` so card + config block sit in one column), admin-only, gold top border on the config block to visually tie to the card. Modal shows alphabetical list of all `pnd_ingredients`, search box, checkboxes, pre-ticked from current config. Data-fetch logic: for each watched AI, find products containing it via `pnd_product_ingredients`, filter `pnd_latest_sprays_by_ai` rows by product_id set, aggregate per block for the most recent spray date. **Key lesson — `pnd_blocks` has NO `company_id` column** (CLAUDE.md explicitly lists it under "Tables WITHOUT company_id"); my first TV display query tried to filter by it and caused "Failed to load data" until the filter was removed. **Separately:** during the Summary redesign I had deleted `getAICombos()` and replaced it with `getAICombosForProducts(productIds)`, but `getAICombos()` was called in 12 other places across the spray tracker module (jobs, joblogs, edit modal, completion flow, reports). Restored it as a one-line wrapper calling `getAICombosForProducts(products.filter(p => p.is_active).map(p => p.id))` — fixed broken job logs / add job.
- [x] **Hub module icons — 3D clay pineapple set** (2026-04-09): Replaced all 8 module emojis with custom 3D clay-rendered PNG icons (180px source, 84px rendered on hub cards). Generated via Gemini 2.5 Flash Image with a locked style anchor: "3D clay-rendered icon, chunky rounded friendly shapes, soft studio lighting, matte finish, cream background #FAF6EF, Pixar Disney style, warm palette gold #D4AF37 + green #4A7C3F + brown #8B6F47 + cream, NO purple/violet, NO text". Pineapple motif woven throughout as a unifier: **Sales** (basket of pineapples), **Inventory** (wood crate with burlap fertilizer sacks + chemical bottles + clipboard — explicitly NOT pineapples, contextually accurate), **Workers** (farmer with straw hat hugging a pineapple), **PND Spray Tracker** (gold spray bottle with pineapple-leaf crown on cap + green droplets), **Growth Tracker** (pineapple plant with soil base), **Farm Configuration** (gold cog with pineapple in center), **TV Display** (retro brown boxy TV with pineapple on screen and warm glow — user's explicit example), **Oil Palm Seedlings** (sapling in black nursery polybag, not terracotta pot — user-corrected). Files at `icons/modules/*.png`. **Integration:** added `iconImg` field to each MODULES entry, original emoji kept as `icon` fallback. Render updated in three places: `.module-icon` on hub cards (84px), `.access-icon` in User Management table row per user (22px), `.perm-module-icon` in Edit User perm panel headers (28px). TV Display tab cards (Growth Tracker, Sales Packing, PND Spray Tracker) also switched to matching module icons (64px); Weather card still on ⛅ emoji (no matching icon in set). CSS added in index.css for `img` children of all four icon slots with `object-fit:contain` + `border-radius`. **Process lesson:** user rejected first attempts (generic line icons, then 3D icons with purple accents). Phase 1 generated 2 test icons with locked prompt before committing to batch; style approved, Phase 2 generated the remaining 6 in parallel; Phase 3 did contextual corrections (Inventory fertilizer-not-pineapples, Seedlings polybag-not-pot). **Preview page:** `icon-preview.html` at root shows the full set in real hub mockup.
- [x] **Theme note — hub is light mode** (2026-04-09): Confirmed during icon design — `shared.css` now uses a warm light theme: `--bg: #FAF6EF` (cream), `--bg-card: #FFFFFF`, `--text: #2A1A3E` (deep plum), `--gold: #D4AF37`, font 'Plus Jakarta Sans'. **CSS variable names are stale** — `--green` actually holds gold `#D4AF37`, `--green-light` holds purple `#6B4C8A`. Use hex values, not semantic variable names. Updated the "Tech Stack" section at the top of this file to reflect the current palette. Prior notes referring to "dark mode" and "green #4A7C3F accents" are stale — that was the previous theme.
- [x] **Cross-PC skills/agents sync** (2026-04-09): Committed project-scoped copies of 24 skills + 4 agents to `.claude/skills/` and `.claude/agents/` (commit `22b4d7e`) so both PCs share them via git. `.gitignore` whitelists those two dirs (`!.claude/skills/`, `!.claude/agents/`) but keeps everything else under `.claude/` per-PC (settings, sessions, cache). **Skills copied (24):** 14 superpowers (brainstorming, writing-plans, executing-plans, subagent-driven-development, dispatching-parallel-agents, test-driven-development, systematic-debugging, verification-before-completion, requesting-code-review, receiving-code-review, finishing-a-development-branch, using-git-worktrees, using-superpowers, writing-skills) + deep-plan + deep-implement + deep-project + frontend-design + logo-designer + 5 claude-mem (do, make-plan, mem-search, smart-explore, timeline-report). **Agents copied (4):** superpowers `code-reviewer.md`, deep-plan `opus-plan-reviewer.md` + `section-writer.md`, deep-implement code-reviewer (renamed to `deep-implement-code-reviewer.md` to avoid collision with superpowers one). **NOT copied:** code-review plugin (slash-command-only, no skill), security-guidance (hooks-only — must be plugin-installed). **Secondary PC plugin install verified same day:** 8 plugins at user scope matching main PC — superpowers 5.0.7, frontend-design/code-review/security-guidance (version "unknown"), claude-mem **12.1.0** (ahead of main PC's 10.6.1), deep-project 0.2.1, deep-plan 0.3.2, deep-implement 0.2.1. Marketplaces added: `thedotmack` (from `thedotmack/claude-mem` repo) and `piercelamb-plugins` (from `piercelamb/deep-implement` repo) — marketplace names derive from each repo's `.claude-plugin/marketplace.json`, NOT from the repo name. Both PCs now have two independent paths to the same skills: plugin path (slash commands like `/deep-plan`, auto-updates, plugin-prefixed names like `superpowers:brainstorming`) and project-scoped path (bare names like `brainstorming`, frozen at today's versions, survives fresh clones with zero setup). **Follow-up:** bump main PC's `claude-mem` to 12.1.0 via `/plugin update claude-mem@thedotmack` for parity (low-risk, deferred).
- [x] **Sales invoicing overhaul + sales UX fixes** (2026-04-09): 25 commits across invoicing, orders, documents, and export. **Invoicing UX:** select-all checkbox enlarged with "Select all N DOs" label + "N selected" badge in customer headers, auto-expand on selection; cross-customer selection blocked with red warning banner + disabled Create button; Add More DOs replaced confirmAction with dedicated modal (#inv-adddos-modal) with running count/total; Edit Draft modal for date/terms/notes/remove DOs; single-draft rule (block creation while draft exists). **Invoice lifecycle:** voided status (keeps items/junction for audit, auto-CN, frees DOs); unlink single DO from issued invoice (auto-CN for difference); draft cancel rewinds counter via `rewind_id()` RPC; cancel restricted to drafts only, issued uses Void. **A4 documents:** two-column Bill To + Invoice Details layout (Invoice + CN); amount in words ("Ringgit Malaysia ... Only"); notes box with contenteditable + `INV_DEFAULT_NOTES` variable; DO Summary attachment (page 2+, per-DO items tables, page-break-inside:avoid); e-Invoice placeholder removed; Invoice/CN signature → Prepared By + "computer-generated, no signature required"; DO signature → Issued By + Received By (Name/IC/Signature/Stamp); footer with enquiry number. **Document export:** Print → browser print window with CSS page breaks (`soOpenA4Window` + `soA4PrintStyles` shared helpers); Download → same print window (Save as PDF); Share → multi-image capture (scrollIntoView per page, modal constraint removal, multi-file Web Share API); html2pdf.js attempted then removed (html2canvas can't render clipped/hidden elements). Descriptive filenames: `AF-INV001_20260409_Customer_Name.png`. **Order sorting:** active orders sorted by delivery_date + delivery_time (most urgent first, no date sinks to bottom); completed/cancelled grouped by `completed_at` (new column) instead of order_date. **Order cancel:** requires reason text input (stored in `cancel_reason` column); shown on card (red banner) + detail view (red bordered box). **Delivery time:** input changed from `type="text"` to `type="time"` (native picker); `fmtTime12()` helper for 12h display ("2:00 PM"); existing DB values normalized to HH:MM; sorting includes delivery_time as secondary sort. **Pcs orders display:** order cards, detail view, dashboard "To Prepare"/"Ready" cards, and active orders all now show `order_pcs` for pcs-ordered items instead of `quantity` (which is 0 until weighed). Shows "30 pcs" before weighing, "30 pcs (15.5kg)" after. Total shows "Pending weight" when unweighed. **Mandatory photos:** Mark Prepared and Mark Delivered now require a photo (Skip button hidden); walk-in quick complete remains optional. **Fixes:** double variety name on A4 (snapshot already contains variety), customer detail completed-only stats, invRecomputeInvoice captures updated_at (prevents stale lock), confirmAction renders HTML body (was escaping it). **Invoice list perf:** headers-only render, detail built on click via invInsertDetail(), no full re-render on toggle. **DB changes:** `voided_at`, `voided_by`, `void_reason` on `sales_invoices`; `completed_at` on `sales_orders`; `cancel_reason` on `sales_orders`; `rewind_id(p_id)` RPC. **Infra:** Netlify token rotated (`nfp_otZ4...7832`, no expiration); old cancelled invoices (INV001/INV002) deleted, INV counter reset. **Deferred:** e-Invoice LHDN (future project), "invoice sent" tracking (revisit later), SST/tax lines (no registration yet).
- [x] **OneDrive → git/GitHub migration** (2026-04-09): Project relocated off OneDrive onto pure git+GitHub sync between the two Windows PCs. **Why:** OneDrive was corrupting the `.git` folder via partial sync — under-syncing loose objects, racing on `FETCH_HEAD` writes, surfacing git internals as sync errors. Symptoms had been silent until they weren't. **Audit (Step 1):** repo had 66 tracked files but ~30 untracked-yet-important files (specs, plans, guides, audit report, package.json, icons/modules/, .superpowers/brainstorm/) plus 2 unpushed commits and ~10 modified files sitting in the working tree from prior un-committed work. **Step 3 commits (7 new):** `8a57d24` gitignore expansion (node_modules, supabase/.temp/, .superpowers/, icons/test/), `426967e` legacy migration .sql files removed, `35d2950` spray+growth (summary watchlist, TV display, harvesting status), `62c552a` hub+inventory (TV display tab, module icons, multi-company wiring, supplier perm fix), `a0ff41b` sales guides + trial theme + audit report + package.json, `e3c3ce7` superpowers specs and plans, `6004d3c` CLAUDE.md changelog sync. Tracked file count 66 → 97. **Sub-project decision:** Nanas split out into its own dedicated public repo `yapwaylon-sketch/TG-Nanas-Growth-TV` (Option B in plan — three Netlify deploys = three repos). Weather deferred (Option C4) — has unresolved unknowns (MET token rotation, pre-existing nested private `tg-weather-netlify` repo, Netlify build source unclear, possible second Supabase ref). Weather moved to OneDrive sibling location `TG Projects Deffered\TG Weather Monitoring Website\` to survive the project folder delete. **Cloudflare token in old `.claude/settings.local.json`:** verified DEAD via `/user/tokens/verify` API call (returned `Invalid API Token`); was a 40-char Bearer token, already deleted/rolled at some point in the past — nothing to revoke. `.claude/` is gitignored on the new Nanas repo from first commit. **Migration execution:** Phase 0 verified secondary PC clean → Phase A1+A4 closed editors and paused OneDrive on both PCs → Phase B `git clone` into `C:\dev\` on secondary PC (resulted in packed .git: 11.43 MiB pack with 0 loose objects, vs the 692 loose objects on the OneDrive copy — proof of OneDrive thrash) → Phase C verified clones (logo.png ~810 KB confirms new TG Agro Fruits logo) → Phase D3 manually moved Weather out of project folder on both PCs while OneDrive paused (avoided having OneDrive sync a folder containing a nested .git) → Phase D zip backup skipped (724 of 1143 files were cloud-only placeholders making backup impractical, and four other safety nets existed: fresh clones verified, GitHub, Recycle Bin 30d, main PC's OneDrive copy until sync propagates delete) → Phase D1 OneDrive resumed on both PCs → Phase D1.5 sanity recheck clean → Phase D4 manual Explorer delete → Phase E `git clone` on main PC → Phase F deferred (last hygiene step: remove `TG Nanas Growth TV/` from main repo `.gitignore` once both PCs migrated and OneDrive folder gone). **Daily workflow going forward** documented in the User Preferences section above. **Lessons:** (1) OneDrive + `.git` is fundamentally incompatible — git's internal database needs atomic writes that OneDrive can't guarantee. (2) The `~/.claude/projects/.../memory/` folder is keyed by working directory path and is per-PC — it does NOT carry across PCs or across path changes; CLAUDE.md is the only durable memory mechanism for this project. (3) Cut+paste a folder while OneDrive is paused is local-only; resuming sync afterward verifies state matches rather than performs the move (avoids OneDrive race conditions on nested .git folders). (4) Bash subprocess holding cwd inside a folder prevents Explorer from deleting that folder on Windows — Claude Code session must be closed before D4. (5) Recycle Bin is the silent safety net for the whole migration (30 days).

- [x] **Company logos on hub + sidebars** (2026-04-10): Hub page shows both company logos side by side (header + login). Sidebar in modules uses company-specific logo: Sales/Delivery → `logo.png` (Agro Fruits), Inventory/Workers/Spray/Growth → `logo-agribusiness.png` (Agribusiness, cropped + transparent bg). Company switcher redesigned as segmented pill toggle (text only). Assets: `logo-agribusiness.png` (transparent), `logo-agribusiness.jpg` (cropped), `logo-agribusiness-original.jpg` (original with excess whitespace).
- [x] **Oil Palm Seedlings module** (2026-04-10): Full 8-phase build. 7 DB tables + RLS + triggers. 6 sidebar tabs (Batches, Bookings, Collections, Customers, Suppliers, Reports). Batch lifecycle (pre_nursery→main_nursery→selling→sold_out→closed), transplant with doubleton tracking, culling logs. Booking with deposit/payment tracking + payment-controlled collections (can't collect more than paid for). L3.1 certificate tracking per collection. Walk-in cash sales. Cross-company customer detection (links to Agro Fruits customers by phone). Printable booking slip with T&C. 3 reports: MPOB Monthly, Batch Summary, Cash Flow Projection (all with print + CSV export). Photo upload for collections (seedlings + L3.1 page). Allocation % per batch (default 50%). Two company addresses: office (Lot 1609) for slips, farm (Lot 174) for L3.1. Migration: `supabase/seedlings_migration.sql`. Supabase storage: `seedling-photos` bucket.
- [x] **Hub category banners** (2026-04-10): TG Agribusiness modules on hub page now grouped under 3 category banners — Operations (Pineapple Spray, Pineapple Growth, Oil Palm Sales, Oil Palm Growth, Inventory), Management (Worker Management, Staff Claims), Projects Monitoring (Tender). Flat grid preserved for Agro Fruits (just Sales). `MODULE_CATEGORIES` config in index.html, `category` field on each module, `renderModuleCards()` renders banners with inner grids. Coming-soon modules shown as disabled cards. Module renames: "PND Spray Tracker"→"Pineapple Spray", "Growth Tracker"→"Pineapple Growth", "Oil Palm Seedlings"→"Oil Palm Sales", "Inventory Management"→"Inventory". New coming-soon entries: `seedlinggrowth`, `staffclaims`, `tender`.
- [x] **Tender Monitoring module** (2026-04-10): Full build — `tender.html` + `tender.css`. 4 sidebar tabs (Dashboard, Local Orders, Documents, Reports). Tender selector pills in sidebar to switch between tenders. Dashboard: 8 metric cards (qty/delivered/remaining/%/contract value/invoiced/paid/outstanding), expiry alerts (overdue red, expiring-soon gold), batch progress bars. Local Orders: table grouped by batch with status filter + search, add/edit modal, status transitions with field prompts (delivering→DO+date, invoiced→invoice no+date, paid→amount+ref+bank), expiry row highlighting, running balance. Documents: file upload to `tender-documents` Supabase bucket, grouped by doc type (SST/contract/bond/LO/submission/invoice/report/extension/other), optional LO linking, view/delete. Reports: Tender Summary, Batch Completion, Payment Status (all printable). AI LO PDF import: pdf.js CDN renders pages → Claude API (Sonnet) vision extracts fields → editable preview table → batch save. API key stored in `app_config` DB table, loaded automatically. DB: 3 tables (`tenders`, `tender_los`, `tender_documents`) + `app_config` table + `tender-documents` storage bucket. Migration: `supabase/tender_migration.sql`. LO status workflow: pending→preparing→delivering→delivered→invoiced→paid. First tender seeded from SST: LPNM.400-5/8/24 (MD2), 1,500,000 sulur, RM1.78/sulur, RM2,670,000, 2-year contract, bond RM66,750.
- [x] **Full-site audit + fixes** (2026-04-10): 28 issues found across 8 modules (usability + DB linking focus). Fixed: 23 missing `.select()` on deletes (Supabase v2), undefined `--card-bg` CSS var, duplicate `startSessionCheck()`/`closeModal()` in index.html (interval leak + lost focus cleanup), added "Change PIN" button to hub, replaced `prompt()` with styled modals for crop/variety rename, Escape key on Farm Config modals, `for=` on 67 sales labels, `calClose()` cleanup in `closeModal()`, XSS escape in inventory alert. 3 low P3 remaining (workers XSS on internal data, TV interval IDs, overview counts cancelled orders).

## Audit Results (2026-04-10 — all P1/P2 fixed, 3 low-priority P3 remaining)
Full-site audit covering hub (index.html), sales, inventory, workers, spraytracker, growthtracker, delivery, display-sales, display-spray. Focus: usability + database linking.
- **28 issues found** across 8 modules (0 critical, 16 high/medium, 12 low)
- **P1 fixes (commit 6c084a3):** undefined `--card-bg` CSS var → `--bg-card` (3 places); removed duplicate `startSessionCheck()` from index.html (interval leak on logout); removed duplicate `closeModal()` (lost `releaseFocus` cleanup); added `.select()` to 23 delete operations in workers/inventory/sales (Supabase v2); fixed stale error check on order delete; added `.select()` on session_token update; XSS escape in inventory alert banner
- **P2 fixes (same commit):** added "Change PIN" button to hub header; replaced `prompt()` with styled modals for crop/variety rename; added Escape key handler for all Farm Config modals; added `calClose()` cleanup to shared `closeModal()`; added `for=` attributes to 67 form labels in sales.html
- **P3 remaining (low risk):** XSS in workers.html template literals (internal DB data only); TV display `setInterval` without stored IDs (dedicated screens, never navigate); Company Overview counts cancelled orders in totals (cosmetic)

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
