# TG FarmHub — Organizational Structure

> Generated 2026-04-10. Reference doc for planning.

---

## 1. Company Structure

```
                        TG Group
                           │
              ┌────────────┴────────────┐
              │                         │
     TG Agro Fruits Sdn Bhd    TG Agribusiness Sdn Bhd
          (Code: AF)                 (Code: AB)
              │                         │
     Pineapple Sales &           Farm Operations &
     Distribution                Crop Management
```

**Intercompany relationship:** TG Agribusiness grows pineapples at Ladang PND. TG Agro Fruits buys from Agribusiness (monthly bulk purchase) and sells to external customers at markup. Intercompany billing is not yet tracked in the system.

---

## 2. Module Ownership by Company

```
┌─────────────────────────────────────────────────────────────────┐
│                        TG AGRO FRUITS (AF)                      │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐                             │
│  │    Sales      │  │   Delivery   │                             │
│  │              │  │   (Mobile)   │                             │
│  │ - Orders     │  │              │                             │
│  │ - Customers  │  │ - Mark       │                             │
│  │ - Products   │  │   Delivered  │                             │
│  │ - Payments   │  │ - Print      │                             │
│  │ - Invoicing  │  │   DO/CS     │                             │
│  │ - Returns    │  │              │                             │
│  │ - 7 Reports  │  │              │                             │
│  └──────────────┘  └──────────────┘                             │
│                                                                 │
│  TV: Sales Packing Station Display                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      TG AGRIBUSINESS (AB)                       │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Inventory    │  │   Workers    │  │ Spray Tracker│          │
│  │              │  │              │  │              │          │
│  │ - Stock In   │  │ - Profiles   │  │ - Spray Jobs │          │
│  │ - Stock Out  │  │ - Payroll    │  │ - Products   │          │
│  │ - Suppliers  │  │ - Tasks      │  │ - AI Combos  │          │
│  │ - Products   │  │ - Loans      │  │ - Watchlist  │          │
│  │ - Reports    │  │ - Expenses   │  │ - Reports    │          │
│  │ - Stock Check│  │ - Changelog  │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐                             │
│  │Growth Tracker│  │  Seedlings   │                             │
│  │  (Read-Only) │  │  (Oil Palm)  │                             │
│  │              │  │              │                             │
│  │ - Block      │  │ - Batches    │                             │
│  │   Growth     │  │ - Bookings   │                             │
│  │ - Harvest    │  │ - Collections│                             │
│  │   Planning   │  │ - L3.1       │                             │
│  │ - Status     │  │ - Customers  │                             │
│  │   Dashboard  │  │ - MPOB Rpts  │                             │
│  └──────────────┘  └──────────────┘                             │
│                                                                 │
│  TV: Growth Tracker Display, Spray Monitoring Display           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         SHARED                                  │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Farm Config  │  │  TV Display  │  │     Hub      │          │
│  │              │  │   (Links)    │  │              │          │
│  │ - Blocks     │  │              │  │ - Login      │          │
│  │ - Crops      │  │ - Growth TV  │  │ - Users      │          │
│  │ - Varieties  │  │ - Weather    │  │ - Company    │          │
│  │ - Statuses   │  │ - Sales TV   │  │   Switcher   │          │
│  │ - Planting   │  │ - Spray TV   │  │ - Overview   │          │
│  │   Cycles     │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. User Roles & Access

```
┌─────────────────────────────────────────────────────────────┐
│                         ADMIN                                │
│                                                             │
│  - Full access to all modules in both companies             │
│  - User management (create/edit/delete users)               │
│  - Farm Configuration (blocks, crops, varieties)            │
│  - Invoice approval                                         │
│  - Google OAuth login (yapwaylon@gmail.com)                  │
│  - PIN login (fallback)                                     │
│  - TV Display configuration                                 │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                       SUPERVISOR                             │
│                                                             │
│  - Access to permitted modules only (per-permission ticks)  │
│  - Can perform operations within granted permissions        │
│  - PIN login only                                           │
│  - Typical permissions:                                     │
│    - Log spray applications                                 │
│    - Record stock in/out                                    │
│    - Create/edit orders                                     │
│    - View reports                                           │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│                         STAFF                                │
│                                                             │
│  - Most restricted access                                   │
│  - Access to permitted modules only (per-permission ticks)  │
│  - PIN login only                                           │
│  - Typical permissions:                                     │
│    - View-only access to specific modules                   │
│    - Delivery operations (drivers)                          │
└─────────────────────────────────────────────────────────────┘
```

### Permission Matrix

Each module has granular permissions that can be toggled per user:

| Module | Permissions |
|--------|-------------|
| **Sales** | View, Create/Edit Orders, Payments, Delivery, Manage Customers, Export |
| **Inventory** | View, Stock In, Stock Out, Stock Check, Edit Products, Manage Suppliers, Edit Transactions, Delete Transactions, Export |
| **Workers** | View, Edit Workers, Payroll, Summary/Reports |
| **Spray Tracker** | View, Log Sprays, Manage Products |
| **Growth Tracker** | View, Manage Growth (induction/harvest dates) |
| **Farm Config** | Manage Farm (blocks/crops/varieties) |
| **TV Display** | View (access TV Display links) |
| **Seedlings** | View, Manage Batches, Manage Bookings, Record Collections, Manage Customers, Manage Suppliers, View Reports |

---

## 4. Operational Workflow

### Agribusiness — Farm Operations

```
                    Farm Configuration
                    (Blocks, Crops, Varieties)
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
    ┌──────────┐    ┌──────────┐    ┌──────────────┐
    │ Planting │    │ Spraying │    │  Inventory   │
    │  Cycle   │    │  Cycle   │    │              │
    │          │    │          │    │  Supplies    │
    │ Growing  │    │ Schedule │    │  Chemicals   │
    │ Induce   │    │ Log Jobs │    │  Fertilizer  │
    │ Harvest  │    │ Track AI │    │  Equipment   │
    │ Suckers  │    │ Intervals│    │              │
    │ Replant  │    │          │    │              │
    └────┬─────┘    └────┬─────┘    └──────────────┘
         │               │
         ▼               ▼
    ┌──────────┐    ┌──────────┐
    │  Growth  │    │  Spray   │
    │  Tracker │    │ Summary  │
    │  (View)  │    │ Watchlist│
    └────┬─────┘    └────┬─────┘
         │               │
         ▼               ▼
    ┌──────────┐    ┌──────────┐
    │Growth TV │    │ Spray TV │
    │ Display  │    │ Display  │
    └──────────┘    └──────────┘

    Workers ──────────────────────────────
    │ Profiles → Tasks → Payroll → Payslips
    └─────────────────────────────────────
```

### Agro Fruits — Sales Operations

```
    ┌──────────────────────────────────────────────┐
    │              Sales Order Lifecycle            │
    │                                              │
    │   Order         Preparing      Prepared      │
    │   Received  ──►  (Worker    ──►  (Ready    ──┤
    │   (New)         assigned)       for pickup)  │
    │                                              │
    │   ┌─────────────────────────────────────┐    │
    │   │  Delivery Path      Collection Path │    │
    │   │                                     │    │
    │   │  Ready For    ──►   Completed       │    │
    │   │  Delivery           (Collected)     │    │
    │   │  (Driver                            │    │
    │   │   assigned)                         │    │
    │   │      │                              │    │
    │   │      ▼                              │    │
    │   │  Completed                          │    │
    │   │  (Delivered)                        │    │
    │   └─────────────────────────────────────┘    │
    │                                              │
    │   Walk-in: Order Received ──► Completed      │
    └──────────────────────────────────────────────┘
              │                    │
              ▼                    ▼
    ┌──────────────┐      ┌──────────────┐
    │  Documents   │      │   Payments   │
    │              │      │              │
    │ DO (Credit)  │      │ CS (Cash)    │
    │ CS (Cash)    │      │ Invoice Pmts │
    │ Invoices     │      │ Credit Notes │
    │ Credit Notes │      │              │
    └──────────────┘      └──────────────┘
              │
              ▼
    ┌──────────────┐      ┌──────────────┐
    │  Packing     │      │   Delivery   │
    │  Station TV  │      │  (Mobile)    │
    │              │      │              │
    │  4-column    │      │  Driver app  │
    │  live grid   │      │  Mark done   │
    └──────────────┘      └──────────────┘
```

### Agribusiness — Seedlings Operations

```
    Supplier ──► Batch Created (Pre-Nursery)
                      │
                      ▼
                 Transplant (Main Nursery, ~4 months)
                      │
                      ▼
                 Selling (10+ months)
                      │
                ┌─────┴─────┐
                ▼           ▼
           Bookings    Walk-in Sales
           (Deposit)   (Cash)
                │
                ▼
           Collections
           (L3.1 Certificate)
                │
                ▼
           Sold Out / Closed
```

---

## 5. Data Flow Between Modules

```
                         ┌──────────────┐
                         │  Farm Config  │
                         │  (Hub Page)   │
                         └───────┬───────┘
                                 │
              Blocks, Crops, Varieties, Statuses
                                 │
         ┌───────────┬───────────┼───────────┐
         ▼           ▼           ▼           ▼
   Growth Tracker  Spray     Inventory   Seedlings
   (reads blocks,  Tracker   (spray      (independent
    varieties,     (reads     product     tables,
    statuses,      blocks,    link via    cross-ref to
    growth_records)statuses)  FK)         sales_customers)
         │           │
         ▼           ▼
   Growth TV      Spray TV

   Workers ─────────────────────────────────────────►  Sales
   (workers table read cross-company                   (driver &
    by Sales for driver/assignment dropdowns)           assignment
                                                       dropdowns)
```

### Cross-Module Data Dependencies

| Source | Consumer | What's Shared |
|--------|----------|---------------|
| Farm Config → Growth Tracker | Blocks, varieties, statuses, growth_records | Block lifecycle data |
| Farm Config → Spray Tracker | Blocks, statuses, varieties | Block info for spray logging |
| Inventory → Spray Tracker | `pnd_products.inventory_product_id` FK | Product stock levels |
| Workers → Sales, Delivery | `workers` table (no company filter) | Driver names, worker assignments |
| Sales Customers → Seedlings | `sales_customers` (by phone match) | Cross-company customer link |
| Farm Config → Growth TV | growth_records, pnd_blocks, crop_varieties | TV display data |
| Hub → Spray TV | `pnd_tv_config` (watched AIs) | TV display configuration |

---

## 6. Physical Locations

| Location | Address | Used For |
|----------|---------|----------|
| **Office** | Lot 1609, Kpg. Riam Jaya, 98000 Miri, Sarawak | Business address, booking slips |
| **Farm / MPOB License** | Lot 174, Block 9, Lambir Land District, 98000 Miri, Sarawak | L3.1 certificates, farm operations |
| MPOB License No. | 522231011000 | Seedlings compliance |

---

## 7. External Integrations

| System | Integration | Status |
|--------|-------------|--------|
| **Supabase** | Database, Auth, Storage | Active |
| **Google OAuth** | Admin login | Active |
| **WhatsApp** | Message sharing (orders, spray jobs, documents) | Active (via Web Share API) |
| **Netlify** | Hosting & deploy | Active |
| **MPOB** | Monthly seedling reports (manual/printable) | Active |
| **QuickBooks** | Removed (replaced by in-house invoicing) | N/A |

---

## 8. TV Display Network

```
    Hub Page (TV Display Tab)
         │
         ├── Growth Tracker TV ──► nanasgrowth.tgfarmhub.com
         │   (Separate repo)       Auto-rotate by crop status
         │
         ├── Weather TV ──────────► weather.tgfarmhub.com
         │   (Separate deploy)     Weather monitoring
         │
         ├── Sales Packing TV ───► tgfarmhub.com/display-sales.html
         │   (Same repo)           4-column order grid
         │
         └── Spray Tracker TV ──► tgfarmhub.com/display-spray.html
             (Same repo)           Per-AI spray monitoring

    All TVs: Password-gated, read-only, auto-refresh
```

---

## 9. Document Types Generated

| Document | Format | Module | Delivery |
|----------|--------|--------|----------|
| Delivery Order (DO) | 80mm receipt + A4 | Sales | Print / WhatsApp PNG |
| Cash Sales (CS) | 80mm receipt + A4 | Sales | Print / WhatsApp PNG |
| Invoice | A4 (multi-page with DO summary) | Sales | Print / WhatsApp PNG |
| Credit Note | A4 | Sales | Print / WhatsApp PNG |
| Statement of Account | A4 | Sales | Print / WhatsApp PNG |
| Debit Note | Numbered reference | Sales | — |
| Booking Slip | Printable | Seedlings | Print / WhatsApp |
| Payslip | A5 (2 per A4 landscape) | Workers | Print |
| MPOB Monthly Report | Printable table | Seedlings | Print / CSV |
| Batch Summary | Printable table | Seedlings | Print / CSV |
| Spray Reports (8 types) | Printable table | Spray Tracker | Print |

---

## 10. Authentication Flow Summary

```
    ┌─────────┐     PIN (6 digits)      ┌──────────┐
    │  Staff   │ ──────────────────────► │          │
    │  Worker  │   Auto-login on 6th    │          │
    └─────────┘   digit, no click       │   Hub    │
                                        │  Page    │
    ┌─────────┐     PIN or Google       │          │
    │  Super-  │ ──────────────────────► │ index    │
    │  visor   │                        │  .html   │
    └─────────┘                         │          │
                                        │          │
    ┌─────────┐     Google OAuth or PIN │          │
    │  Admin   │ ──────────────────────► │          │
    │ (Waylon) │   yapwaylon@gmail.com  │          │
    └─────────┘                         └────┬─────┘
                                             │
                                    Session stored in
                                    localStorage
                                             │
                         ┌──────────┬────────┼────────┬──────────┐
                         ▼          ▼        ▼        ▼          ▼
                      Sales    Inventory  Workers   Spray    Seedlings
                                                   Tracker

    Security:
    ├── Multi-device: login elsewhere logs out previous (polled 30s)
    ├── Inactivity timeout: 60 minutes
    ├── RLS on all tables (anon + authenticated roles)
    └── Permissions: per-module granular toggles
```
