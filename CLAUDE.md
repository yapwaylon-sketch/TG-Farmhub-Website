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
| `shared.css` | Shared styles (sidebar, layout, variables, offline banner) |
| `shared.js` | Shared JS (session guard, Supabase init, sidebar logic, sbMutate, sbUpdateWithLock) |
| `{module}.css` | Per-module styles (index.css, inventory.css, workers.css, spraytracker.css, growthtracker.css) |
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
6. **TV Display (Growth)** — `display-growth.html`, read-only, token auth (`?token=pnd2026`)

### Coming Soon (Not Built)
7. **Oil Palm Seedlings** — Booking management, sales tracking, seedling stock

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
| File | Purpose |
|------|---------|
| `phase4_farm_config_migration.sql` | crops, varieties, statuses, block_crops |
| `growth_tracker_migration.sql` | growth_records + harvest_days_from_induction |
| `rls_audit_migration.sql` | RLS for 17 tables |
| `days_to_induce_migration.sql` | Added days_to_induce to crop_varieties |
| `target_dates_migration.sql` | Added target_induce_date, target_harvest_start, target_harvest_end to growth_records |
| `growth_view_migration.sql` | **DEPRECATED** — superseded by cycle_migration.sql. DO NOT RUN. |
| `cycle_migration.sql` | Added `cycle`, `is_current` to block_crops; updated view with WHERE EXISTS filter for current cycle |
| `products_lookup_migration.sql` | Created `pnd_ingredients` and `pnd_formulations` lookup tables, migrated text columns to FK |
| `products_fields_migration.sql` | Added fields to `pnd_products` (type, registration_no, group_no, default doses, interval) |
| `product_ingredients_junction_migration.sql` | Many-to-many `pnd_product_ingredients` junction table; products can have 2-3 active ingredients |
| `job_products_migration.sql` | Many-to-many `pnd_job_products` junction table; jobs can have multiple products (tank mix) |
| `pnd_wipe_data.sql` | Utility: wipes all PND Spray Tracker data (preserves table structure), FK-safe order |
| `salary_advances_migration.sql` | Created `salary_advances` table for tracking mid-month salary advances, with indexes and RLS |
| `salary_advance_categories_migration.sql` | Added `category` column to salary_advances (Canteen/Cigarettes/Salary Advance/Overpayment), `cash_handed` to payroll_entries |
| `google_auth_migration.sql` | Added `email` column to `public.users`, set admin email for Google OAuth |
| `packaging_fields_migration.sql` | Added `packaging_size`, `packaging_unit`, `packaging_type` to `pnd_products` |
| `ingredient_inventory_link_migration.sql` | **DEPRECATED** — superseded by spray_inventory_link_migration.sql. DO NOT RUN. |
| `spray_inventory_link_migration.sql` | Added `inventory_product_id` to `pnd_products`, dropped `ingredient_inventory_link` table |
| `latest_sprays_by_ai_migration.sql` | **DEPRECATED** — superseded by latest_sprays_by_ai_v2_migration.sql. DO NOT RUN. |
| `latest_sprays_by_ai_v2_migration.sql` | View `pnd_latest_sprays_by_ai` with `ai_combo_key` grouping (sorted ingredient IDs) |
| `ai_combo_overhaul_migration.sql` | Created `ai_combo_defaults` table, added `ai_combo_key` to `pnd_jobs`, wiped existing jobs/logs |

### How to run SQL migrations
```bash
cd "C:/Users/yapwa/OneDrive/TG Web and Android Project/TG Farmhub Website"
npm install pg
node -e "
const fs = require('fs');
const { Client } = require('pg');
const sql = fs.readFileSync('MIGRATION_FILE.sql', 'utf8');
const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 5432, database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false }
});
(async () => {
  await client.connect();
  await client.query(sql);
  console.log('Done');
  await client.end();
})().catch(e => { console.error(e); });
"
rm -rf node_modules package-lock.json package.json
```

## Shared Assets
- **Folder**: `assets/` in project root — deployed to `https://tgfarmhub.com/assets/`
- **Files**: `logo.png` (56KB), `logo.jpg` (460KB)
- Sub-projects reference `https://tgfarmhub.com/assets/logo.png` (not local copies)
- To update: edit file in `assets/`, redeploy main site, all sub-sites auto-update
- Local `assets/` folder = backup + source of truth, synced via OneDrive

## Conventions
- Each module is a single self-contained HTML file (styles + JS inline)
- Shared sidebar/layout uses shared.css + shared.js
- All DB migrations stored as `.sql` files in root
- Session passed via `?session=<user_id>` query param between pages
- Supabase anon key is embedded in frontend (RLS provides security)
- Sidebar logo: TG base64 PNG image (consistent across all modules)

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
- TV displays: same Netlify site, URL token auth (`?token=pnd2026`), read-only
- **Spray-Inventory Link**: `pnd_products.inventory_product_id` FK links each spray product directly to `products` (inventory). Products are managed in Inventory module; Spray Tracker only configures spray-specific fields (interval, dose). Products page has "Enable for Spraying" to activate inventory products, and "Link to Inventory" banner for legacy unlinked products. Active Jobs page shows product-level stock check cards (need vs have + cost).
- **Multiple jobs per block**: Scheduled jobs no longer blocked by existing active jobs for same block+product. Shows info warning instead.

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
- [ ] **Farm Map Module** (`farmmap.html`) — Google Maps integration, draw block polygons, satellite imagery, area calculation (see details below)
- [ ] **`display-spray.html`** — TV display for Spray Tracker (KIV, needs spec)
- [ ] **Seedlings Module** (`seedlings.html`) — Booking, sales, stock, pricing
- [ ] **Cross-Module Dashboard** — Hub page with at-a-glance metrics
- [ ] **Notification System** — In-app alerts, optional WhatsApp/Telegram push
- [ ] **Mobile responsiveness** audit across all modules

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
