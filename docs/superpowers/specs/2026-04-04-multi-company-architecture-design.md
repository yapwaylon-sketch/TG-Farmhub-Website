# Multi-Company Architecture Design

**Date:** 2026-04-04
**Status:** Draft
**Author:** Waylon + Claude

---

## Why Are We Doing This?

TG FarmHub currently treats everything as one company. In reality, two companies exist:

- **TG Agribusiness** — Runs the farm. Manages workers, supplies, spraying, planting. Also handles oil palm production and seedling sales.
- **TG Agro Fruits** — Sells pineapples and other fruits to customers. Buys pineapples from TG Agribusiness at a transfer price, then sells at a markup.

Both companies share the same workers, same farm, same admin team — but their money needs to be tracked separately for accounting and tax.

As the system grows (oil palm, seedlings, new expenses), every new feature needs a clear home under one company. This change makes that automatic.

---

## What We Want To Achieve

1. **Clear accounting** — Every transaction belongs to one company, no guessing
2. **Future-proof** — New modules automatically fall under a company
3. **Easy to use** — One-click company switching, no re-login needed
4. **No disruption** — Existing data moves over cleanly, nothing breaks
5. **Ready for more** — Intercompany billing, expense tracking, P&L reports can be added later without rebuilding

---

## How It Works

### Logging In & Switching Companies

1. You log in as normal (PIN or Google) — nothing changes here
2. On the hub page, the sidebar has a **company toggle** (two buttons: TG Agro Fruits / TG Agribusiness)
3. Click one — the modules in the sidebar instantly change to show only that company's modules
4. The system remembers your last selection, so next time you open the site it defaults to the same company

**No re-login needed.** Just one tap to switch context.

### Which Modules Go Where?

| Company | What You See |
|---------|-------------|
| **TG Agribusiness** | Workers, Inventory, Spray Tracker, Growth Tracker |
| **TG Agro Fruits** | Sales (pineapple & fruits) |
| **Shared (always visible)** | Farm Config (blocks, crops, varieties) |
| **TV Displays** | No change — they work as they do today |

**Future additions under TG Agribusiness:** Oil Palm Seedling Sales, Intercompany Sales (invoicing Agro Fruits monthly for pineapples), FFB Sales, Oil Palm Spray/Growth Trackers

**Future additions under TG Agro Fruits:** Whatever the company needs as it grows — the system is designed to easily add modules to either side

### What Happens To Existing Data?

All your current data moves automatically:

- **Sales data** (customers, orders, invoices, payments, returns) → tagged as **TG Agro Fruits**
- **Operations data** (workers, inventory, spray jobs, growth records) → tagged as **TG Agribusiness**
- **Farm Config data** (blocks, crops, varieties) → stays **shared**, no company tag

Nothing is deleted. Everything keeps working. You just see it under the right company now.

---

## Document Numbering

Documents get a company prefix so you can instantly tell which company issued them:

| Document | TG Agro Fruits | TG Agribusiness |
|----------|---------------|----------------|
| Delivery Order | AF-DO-260405-001 | AB-DO-260405-001 |
| Cash Sales | AF-CS-260405-001 | AB-CS-260405-001 |
| Invoice | AF-INV-260405-001 | AB-INV-260405-001 |
| Credit Note | AF-CN-260405-001 | AB-CN-260405-001 |
| Debit Note | AF-DN-260405-001 | AB-DN-260405-001 |

**AF** = Agro Fruits, **AB** = Agribusiness

Existing documents keep their current numbering — no retroactive changes to already printed/shared documents.

---

## Basic Reporting

A new "Company Overview" section on the hub page:

- Shows each company's key numbers side by side (orders, revenue, outstanding amounts)
- Filterable by date range
- Quick snapshot of both businesses at a glance

---

## What This Design Does NOT Include (But Is Ready For)

These features are **not being built now**, but the company tagging system makes them easy to add later when you're ready:

| Future Feature | What It Does |
|---------------|-------------|
| Intercompany billing | Agribusiness invoices Agro Fruits monthly for pineapple supply |
| Expense tracking | Track expenses (transport, packaging, office) per company |
| Per-company P&L | Profit & loss report for each company separately |
| Cost allocation | Split shared costs (e.g., fuel, general supplies) between companies |
| User restrictions | Limit certain users to only one company |
| Company branding | Different logos or colors per company |

---

## What Gets Changed

| Area | What Changes |
|------|-------------|
| **Hub page** | Company switcher added to sidebar, module cards show/hide based on selection |
| **All modules** | Each module's data filtered to the selected company |
| **Database** | Every record gets a company tag behind the scenes |
| **Documents** | New documents get AF- or AB- prefix |
| **TV displays** | No change |
| **Login** | No change |

---

## How To Verify It Works

After implementation, we test:

1. Login → hub loads with company switcher, defaults to last used
2. Switch company → sidebar modules change instantly
3. Create a sales order in Agro Fruits → document number starts with AF-
4. Switch to Agribusiness → Sales module disappears, Workers/Inventory/Spray/Growth appear
5. Open Farm Config → works from either company
6. Check existing data → sales shows under Agro Fruits, operations under Agribusiness
7. Company overview report → shows correct numbers per company
8. TV displays → still work normally
9. Mobile → company switcher works on phones
10. Close and reopen browser → remembers your last company selection
