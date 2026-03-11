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
- **Auth**: PIN-based login with session IDs, role-based permissions (admin / supervisor / user)
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
| `shared.css` | Shared styles (sidebar, layout, variables) |
| `shared.js` | Shared JS (session guard, Supabase init, sidebar logic) |
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
- All tables use RLS policies scoped to authenticated sessions

## Netlify Deployment
- Site ID: `a0ac5d18-a968-414c-a531-c78ed390e5c2`
- Netlify token: `nfp_jQof4DyVHjPEN4xRxHU6WxxjKhPM3Aav414e`
- Domain: `tgfarmhub.com`
- Deploy: `netlify deploy --prod --dir=.` (or zip upload via Netlify API)

## Modules — Status

### Active (Built)
1. **Inventory Management** — Stock in/out, suppliers, reports, stock checks
2. **Worker Management** — Profiles, monthly payroll, task-based pay, deductions
3. **PND Spray Tracker** — Spray job system, product management, logs, intervention logic
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
- Filter dropdowns: populate on data load only, NOT on every render (prevents state reset)
- TV displays: same Netlify site, URL token auth (`?token=pnd2026`), read-only

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
- [ ] **`display-spray.html`** — TV display for Spray Tracker (KIV, needs spec)
- [ ] **Seedlings Module** (`seedlings.html`) — Booking, sales, stock, pricing
- [ ] **Cross-Module Dashboard** — Hub page with at-a-glance metrics
- [ ] **Notification System** — In-app alerts, optional WhatsApp/Telegram push
- [ ] **Mobile responsiveness** audit across all modules

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
- [ ] **Offline resilience** / retry logic with exponential backoff
- [ ] **Module CSS extraction**: Extract inline CSS to `.inventory.css`, `.workers.css`, etc. for caching
- [ ] Optimistic locking for concurrent edits

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
