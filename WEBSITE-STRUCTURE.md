# TG FarmHub — Website Structure

> Generated 2026-04-10. Reference doc for planning changes.

---

## 1. High-Level Architecture

```
Browser (static HTML/CSS/JS)
    │
    ├── Supabase SDK v2.49.1 (CDN)  ← modules use this
    ├── Supabase REST API (fetch)    ← TV displays use this
    │
    └── Supabase (PostgreSQL + RLS + Storage)
         ├── Region: ap-northeast-1 (Tokyo)
         └── Project: qwlagcriiyoflseduvvc
```

- **No build step** — every page is a self-contained HTML file with inline JS/CSS
- **No framework** — vanilla JS, DOM manipulation, no React/Vue/etc.
- **Hosting**: Netlify at `tgfarmhub.com` (static deploy, `netlify deploy --prod --dir=.`)
- **Auth**: PIN-based for workers/supervisors, Google OAuth for admin. Sessions in localStorage.

---

## 2. File Map

### Core Application Files

| File | Lines | Size | Company | Purpose |
|------|------:|-----:|---------|---------|
| `index.html` | 2,119 | 114 KB | Shared | **Hub** — login, user management, farm config, module launcher, TV display tab |
| `sales.html` | 9,645 | 492 KB | Agro Fruits | **Sales** — orders, customers, products, payments, invoicing, returns, 7 reports |
| `workers.html` | 4,567 | 252 KB | Agribusiness | **Workers** — profiles, payroll, tasks, loans, expenses, changelog |
| `inventory.html` | 3,855 | 204 KB | Agribusiness | **Inventory** — stock in/out, products, suppliers, stock checks, reports |
| `spraytracker.html` | 3,647 | 205 KB | Agribusiness | **Spray Tracker** — spray jobs, products, AI combos, watchlist summary, reports |
| `seedlings.html` | 2,746 | 135 KB | Agribusiness | **Seedlings** — batches, bookings, collections, L3.1 tracking, MPOB reports |
| `growthtracker.html` | 582 | 29 KB | Agribusiness | **Growth Tracker** — read-only dashboard for block growth data |
| `delivery.html` | 749 | 32 KB | Agro Fruits | **Delivery** — mobile driver page, mark delivered, print DO/CS |

### TV Displays (standalone, no shared.js)

| File | Lines | Size | Purpose |
|------|------:|-----:|---------|
| `display-sales.html` | 898 | 33 KB | Packing station display — 4-column order grid, auto-rotate |
| `display-spray.html` | 862 | 34 KB | Spray monitoring display — per-AI pages, auto-rotate |

> Both TV displays use **Supabase REST API directly** (fetch), not the SDK. Password-gated (sessionStorage).

### Shared Infrastructure

| File | Lines | Size | Purpose |
|------|------:|-----:|---------|
| `shared.js` | 585 | 21 KB | Supabase init, session guard, sidebar, `sbQuery()`, `sbMutate()`, `sbUpdateWithLock()`, notifications, modals, `confirmAction()`, calendar picker, offline detection |
| `shared.css` | 743 | 19 KB | Sidebar, layout, variables, modal/notification styles, offline banner, typography |

### Per-Module CSS (extracted from inline)

| File | Lines | Purpose |
|------|------:|---------|
| `index.css` | 293 | Hub page — login form, module cards, farm config, TV display grid, user management |
| `sales.css` | 1,331 | Sales — cards, badges, timeline, aging, invoicing, A4 documents, receipt |
| `inventory.css` | 327 | Inventory — tables, supplier cards, stock check |
| `seedlings.css` | 224 | Seedlings — batch cards, booking slip, collection forms |
| `spraytracker.css` | 98 | Spray — job cards, summary watchlist |
| `growthtracker.css` | 83 | Growth — dashboard cards, table badges |
| `workers.css` | 58 | Workers — payslip, payroll table |
| `trial-theme.css` | 473 | KIV light theme override (used by `sales-trial.html` only) |

### Guides & Docs

| File | Purpose |
|------|---------|
| `guide-sales.html` | Staff workflow guide (English) |
| `guide-sales-cn.html` | Staff workflow guide (中文, interface labels in English) |
| `walkthrough-sales.html` | Interactive 14-step walkthrough with mockup screens |
| `sales-trial.html` | Sales module with trial light theme (KIV) |
| `icon-preview.html` | Module icon set preview page |

### Static Assets

```
assets/
├── logo.png                     (828 KB) — TG Agro Fruits (pineapple)
├── logo.jpg                     (460 KB) — same, JPEG
├── logo_original.png            (56 KB)  — original smaller logo
├── logo-agribusiness.png        (279 KB) — TG Agribusiness (leaf, transparent bg)
├── logo-agribusiness.jpg        (59 KB)  — same, cropped JPEG
└── logo-agribusiness-original.jpg (148 KB) — original with excess whitespace

icons/modules/
├── farm-config.png              — 3D clay cog with pineapple
├── growth-tracker.png           — 3D clay pineapple plant
├── inventory.png                — 3D clay crate with fertilizer
├── sales.png                    — 3D clay basket of pineapples
├── seedlings.png                — 3D clay sapling in polybag
├── spray-tracker.png            — 3D clay spray bottle
├── tv-display.png               — 3D clay retro TV
└── workers.png                  — 3D clay farmer with pineapple
```

### Planning & Design Docs

```
docs/superpowers/
├── specs/                       — Design specs (sales, invoicing, multi-company, packing display, seedlings)
│   ├── sections/                — 14 invoicing section plans
│   └── implementation/          — Code reviews per section
└── plans/                       — Implementation plans (sales phases, multi-company, packing, pcs-order)
```

---

## 3. Module → Database Table Map

### Hub (`index.html`) — Farm Config + User Management
| Table | Access |
|-------|--------|
| `users` | R/W — login, user CRUD, permissions |
| `crops` | R/W — crop types |
| `crop_varieties` | R/W — variety config (days to induce, harvest days) |
| `crop_statuses` | R — status list |
| `pnd_blocks` | R/W — physical blocks |
| `block_crops` | R/W — block-crop assignments, lifecycle, planting cycles |
| `growth_records` | R/W — target dates (auto-created on block config) |
| `pnd_blocks` | R — for spray summary |
| `pnd_jobs` | R — active job counts |
| `pnd_spray_logs` | R — spray history |
| `pnd_ingredients` | R — for TV display config modal |
| `pnd_tv_config` | R/W — watched AIs for spray TV |
| `sales_orders` | R — order counts for company overview |
| `workers` | R — worker counts for company overview |
| `companies` | R — company list |

### Sales (`sales.html`)
| Table | Access |
|-------|--------|
| `sales_customers` | R/W |
| `sales_customer_branches` | R/W |
| `sales_products` | R/W |
| `sales_orders` | R/W |
| `sales_order_items` | R/W |
| `sales_payments` | R/W |
| `sales_returns` | R/W |
| `sales_drivers` | R/W |
| `sales_invoices` | R/W |
| `sales_invoice_items` | R/W |
| `sales_invoice_orders` | R/W |
| `sales_invoice_payments` | R/W |
| `sales_credit_notes` | R/W |
| `crop_varieties` | R — for product variety links |
| `workers` | R — driver/assignment dropdowns (cross-company) |
| `users` | R — for logged-by names |

### Workers (`workers.html`)
| Table | Access |
|-------|--------|
| `workers` | R/W |
| `worker_roles` | R/W |
| `worker_loans` | R/W |
| `loan_repayments` | R/W |
| `worker_default_responsibilities` | R/W |
| `responsibility_types` | R/W |
| `payroll_periods` | R/W |
| `payroll_entries` | R/W |
| `payroll_responsibilities` | R/W |
| `salary_advances` | R/W |
| `task_entries` | R/W |
| `task_types` | R/W |
| `task_units` | R |
| `employment_stints` | R/W |
| `audit_log` | R/W |
| `users` | R |

### Inventory (`inventory.html`)
| Table | Access |
|-------|--------|
| `products` | R/W — inventory products |
| `pnd_products` | R/W — spray product link |
| `pnd_formulations` | R |
| `pnd_ingredients` | R |
| `pnd_product_ingredients` | R |

### Spray Tracker (`spraytracker.html`)
| Table | Access |
|-------|--------|
| `pnd_products` | R/W |
| `pnd_product_ingredients` | R/W |
| `pnd_jobs` | R/W |
| `pnd_spray_logs` | R/W |
| `ai_combo_defaults` | R/W |
| `products` | R/W — inventory link |
| `ingredient_inventory_link` | R/W |
| Views: `pnd_latest_sprays`, `pnd_latest_sprays_by_ai` | R |

> Also reads from shared.js: `pnd_blocks`, `block_crops`, `crop_statuses`, `crop_varieties`, `pnd_ingredients`, `pnd_formulations`

### Growth Tracker (`growthtracker.html`)
| Table | Access |
|-------|--------|
| `pnd_blocks` | R |
| `block_crops` | R |
| `crop_varieties` | R |
| `crop_statuses` | R |
| `growth_records_view` | R — computed view (days_after_induce, days_to_harvest) |

### Seedlings (`seedlings.html`)
| Table | Access |
|-------|--------|
| `seedling_suppliers` | R/W |
| `seedling_batches` | R/W |
| `seedling_batch_events` | R/W |
| `seedling_customers` | R/W |
| `seedling_bookings` | R/W |
| `seedling_payments` | R/W |
| `seedling_collections` | R/W |
| `sales_customers` | R — cross-company customer link |

### Delivery (`delivery.html`)
| Table | Access |
|-------|--------|
| `sales_orders` | R/W |
| `sales_order_items` | R/W |
| `sales_customers` | R |
| `sales_products` | R |
| `crop_varieties` | R |
| `workers` | R |
| `users` | R |

### TV Displays (REST API, read-only)
| Display | Tables Read |
|---------|-------------|
| `display-sales.html` | `sales_orders`, `sales_order_items`, `sales_customers`, `sales_products`, `workers` |
| `display-spray.html` | `pnd_tv_config`, `pnd_ingredients`, `pnd_product_ingredients`, `pnd_products`, `pnd_latest_sprays_by_ai`, `pnd_blocks`, `block_crops`, `crop_statuses` |

---

## 4. Two-Company Structure

| Company | Code | ID | Modules |
|---------|------|----|---------|
| TG Agro Fruits | AF | `tg_agro_fruits` | Sales, Delivery |
| TG Agribusiness | AB | `tg_agribusiness` | Inventory, Workers, Spray Tracker, Growth Tracker, Seedlings |

- **Farm Config** is shared (both companies)
- **Hub page** has a company switcher (segmented pill toggle)
- **35 tables** have `company_id` column — all queries filter by it
- **Document numbering**: company-prefixed via `next_id()` RPC (e.g. `AF-SO001`, `AB-W028`)
- **Workers exception**: loaded without company filter in Sales/Delivery (Agro Fruits needs Agribusiness workers for driver dropdowns)

---

## 5. Dependency Graph

```
                        ┌─────────────┐
                        │  shared.js  │ ← Supabase init, session, sidebar, utilities
                        │  shared.css │ ← Layout, sidebar, variables, modals
                        └──────┬──────┘
                               │ imported by all modules except TV displays
               ┌───────┬───────┼───────┬──────────┬──────────┬──────────┐
               ▼       ▼       ▼       ▼          ▼          ▼          ▼
          index.html sales.html workers inventory spray    growth   seedlings
          index.css  sales.css  workers  inventory spray    growth   seedlings
                                .css     .css      .css     .css     .css
               │
               │ (links to all modules via sidebar nav)
               │
               ├── delivery.html  (imports shared.js/css, standalone page)
               │
               └── TV displays (NO shared.js/css — fully standalone)
                   ├── display-sales.html
                   └── display-spray.html
```

### External Dependencies (CDN)
- **Supabase JS SDK** `@supabase/supabase-js@2.49.1` — all modules except TV displays
- **html2canvas** — Sales module (document PNG export for WhatsApp sharing)
- **Google Fonts** — Plus Jakarta Sans (shared.css), Inter (TV displays)

---

## 6. Supabase Storage Buckets

| Bucket | Used By | Content |
|--------|---------|---------|
| `sales-photos` | Sales, Delivery | Prep photos, delivery photos, payment slips (`orders/{id}/`, `payment-slips/`) |
| `seedling-photos` | Seedlings | Collection photos, L3.1 certificate photos |

---

## 7. Auth & Session Flow

```
Hub (index.html)
├── PIN login → lookup users table → store session in localStorage
├── Google OAuth → Supabase Auth → match email to users table → store session
│
├── localStorage keys:
│   ├── tg_session          — user_id
│   ├── tg_user             — full user object (name, role, permissions)
│   ├── tgfarmhub_company   — selected company (defaults to tg_agro_fruits)
│   └── tg_last_user        — last username (for convenience)
│
└── Session guard (shared.js):
    ├── Checks localStorage on every page load
    ├── Multi-device: session_token polled every 30s
    ├── Inactivity timeout: 60 minutes
    └── Redirects to index.html if invalid

TV Displays:
└── Password gate → sessionStorage (re-prompts on browser restart)
```

---

## 8. Page Navigation

```
index.html (Hub)
├── Sidebar modules:
│   ├── sales.html?session={id}
│   ├── inventory.html?session={id}
│   ├── workers.html?session={id}
│   ├── spraytracker.html?session={id}
│   ├── growthtracker.html?session={id}
│   └── seedlings.html?session={id}
│
├── TV Display tab (opens in new tabs):
│   ├── nanasgrowth.tgfarmhub.com  (separate repo/deploy)
│   ├── weather.tgfarmhub.com      (separate deploy)
│   ├── display-sales.html
│   └── display-spray.html
│
├── delivery.html (linked from Sales, standalone for drivers)
│
└── Guides (linked from Sales):
    ├── guide-sales.html
    ├── guide-sales-cn.html
    └── walkthrough-sales.html
```

---

## 9. Theme & Design Tokens

```css
--bg:          #FAF6EF   /* cream background */
--bg-card:     #FFFFFF   /* white cards */
--text:        #2A1A3E   /* deep purple/plum */
--green:       #D4AF37   /* ⚠ STALE NAME — actually gold accent */
--green-light: #6B4C8A   /* ⚠ STALE NAME — actually purple secondary */
Font:          'Plus Jakarta Sans' (Google Fonts)
```

- Module icons: 3D clay Pixar-style PNGs (180px source, 84px on cards)
- Company logos: Agro Fruits = pineapple, Agribusiness = leaf
- Sidebar logos are company-specific per module

---

## 10. Size Summary

| Category | Count | Total Lines | Total Size |
|----------|------:|------------:|-----------:|
| Application modules | 8 | 24,910 | 1.46 MB |
| TV displays | 2 | 1,760 | 67 KB |
| Shared JS/CSS | 2 | 1,328 | 41 KB |
| Module CSS | 8 | 2,887 | 90 KB |
| Guides/previews | 4 | 1,478 | 67 KB |
| **Total deployed code** | **24** | **32,363** | **1.73 MB** |

Largest files by code: `sales.html` (9,645 lines), `sales-trial.html` (4,893), `workers.html` (4,567), `inventory.html` (3,855), `spraytracker.html` (3,647), `seedlings.html` (2,746).

---

## 11. Sub-Projects (Separate Repos/Deploys, Same Supabase)

| Project | Domain | Repo | Reads From |
|---------|--------|------|------------|
| TG Nanas Growth TV | nanasgrowth.tgfarmhub.com | `yapwaylon-sketch/TG-Nanas-Growth-TV` | `growth_records`, `pnd_blocks`, `crop_varieties` |
| TG Weather | weather.tgfarmhub.com | Not on GitHub (deferred) | Weather tables |

---

## 12. Key Shared Patterns

- **`sbQuery()`** — wraps all Supabase SDK calls (try-catch + notify + offline check)
- **`sbMutate()`** — mutation wrapper with retry + exponential backoff
- **`sbUpdateWithLock()`** — optimistic locking via `updated_at` check
- **`confirmAction()`** — styled modal replacement for `confirm()` (renders HTML body)
- **`dbNextId()`** → calls `next_id()` RPC — company-prefixed sequential IDs
- **`calOpen()`/`calClose()`** — custom calendar date picker
- **`getCompanyId()`** — reads from localStorage, used in every query filter
- **`soProcessPhotoFile()`** — resize to 1200px, JPEG 80%, upload to Supabase Storage
- All `.select()` chained on mutations (Supabase v2 returns empty without it)
