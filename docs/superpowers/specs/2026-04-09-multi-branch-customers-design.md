# Multi-Branch Customers & Enriched Customer Profiles

**Date:** 2026-04-09
**Status:** Approved
**Module:** Sales (`sales.html`)

## Problem

Many wholesale customers (e.g., DailyMart) have multiple branch locations. Currently each branch is entered as a separate customer, which splits their order history, payment tracking, invoicing, and financial stats across multiple records. This makes it impossible to get a unified view of a customer's account or generate consolidated invoices.

Additionally, the customer creation form lacks fields needed for a proper accounting-style customer profile (legal name, email, credit limit, etc.).

## Goals

1. Support multiple delivery branches per customer with centralized billing
2. Enrich customer profiles with accounting-grade fields
3. Show Bill To (HQ) + Ship To (branch) on delivery documents
4. Include branch/delivery info in invoice DO Summary so customers know where stock went
5. Merge existing duplicate customers (DailyMart) with zero data loss
6. Manage branches from the Manage Customers section

## Non-Goals

- Per-branch invoicing (treat as separate customers if needed)
- Branch-level financial reporting
- Customer branch codes / internal reference systems
- e-Invoice LHDN integration (future project)

---

## 1. Database Changes

### 1.1 New table: `sales_customer_branches`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | TEXT | PK | Via `dbNextId('SB')` |
| customer_id | TEXT | FK → sales_customers, NOT NULL | Parent customer |
| name | TEXT | NOT NULL | Branch display name, e.g., "MY DAILY MART 01 (Boulevard)" |
| address | TEXT | | Full delivery address |
| contact_person | TEXT | | Branch-level contact (if different from customer) |
| phone | TEXT | | Branch phone |
| is_default | BOOLEAN | DEFAULT false | One default per customer (enforced in app logic) |
| is_active | BOOLEAN | DEFAULT true | Soft delete |
| company_id | TEXT | FK → companies, NOT NULL | Same as parent customer |
| created_at | TIMESTAMPTZ | DEFAULT now() | |
| updated_at | TIMESTAMPTZ | DEFAULT now() | |

**RLS:** Same pattern as other sales tables — anon + authenticated, filtered by company_id.

**Index:** `(customer_id, is_active)` for branch lookups.

### 1.2 New columns on `sales_customers`

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| registration_name | TEXT | NULL | Legal/registered company name (e.g., "MY DAILY MART SDN BHD") |
| email | TEXT | NULL | For statements/invoices |
| secondary_phone | TEXT | NULL | Alternate contact number |
| credit_limit | NUMERIC | NULL | Optional, for future credit control |
| currency | TEXT | 'MYR' | Default MYR |

Existing `name` field = display name (short name used in dropdowns, cards).
Existing `address` field = **billing/HQ address** (used on Bill To).

### 1.3 New column on `sales_orders`

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| branch_id | TEXT | NULL | FK → sales_customer_branches. Nullable for backwards compat. |

---

## 2. Customer Form Changes (Manage Customers)

### 2.1 Enriched customer creation/edit form

Add new fields to the existing customer modal:

**Business Info section:**
- Registration Name (`registration_name`) — placeholder: "Legal company name (optional)"
- Email (`email`) — placeholder: "e.g., accounts@company.com"

**Contact section (existing + new):**
- Phone (existing)
- Secondary Phone (`secondary_phone`) — placeholder: "Alternate contact"

**Financial section (new):**
- Credit Limit (`credit_limit`) — numeric input, placeholder: "RM (optional)"
- Currency (`currency`) — dropdown, default MYR (for now just MYR, extensible)

**Existing fields unchanged:** name, phone, address, type, payment_terms, SSM/BRN, TIN, IC, notes.

### 2.2 Customer detail page — Branches section

Below the existing profile/overview cards, add a **"Delivery Branches"** section:

- Table with columns: #, Branch Name, Address, Contact, Phone, Default, Actions
- **Add Branch** button → inline form or small modal (name, address, contact_person, phone, is_default checkbox)
- **Edit** button per row → same form pre-filled
- **Delete** button per row → confirmAction, soft-delete (is_active = false). Block if branch has linked orders? No — just deactivate, existing orders keep the reference.
- **Set Default** action per row → clears other defaults, sets this one
- Default branch shown with a gold badge
- Deactivated branches hidden by default (show with toggle if needed)

---

## 3. Order Form Changes

### 3.1 Branch selection on new/edit order

After selecting a customer:
- If customer has branches: show a **"Deliver To"** dropdown below the customer field
  - Options: all active branches for that customer
  - Pre-selects the default branch
  - Stores `branch_id` on the order
- If customer has no branches: no dropdown shown, `branch_id` = null

### 3.2 Order display

- Order cards and detail view show the branch name (if set) below the customer name
- Format: "DailyMart — MY DAILY MART 01 (Boulevard)"

---

## 4. Document Changes

### 4.1 DO and CS — Bill To + Ship To

Current layout has a single Bill To block. Change to two-column:

**Bill To (left):**
- registration_name (falls back to name if null)
- HQ address (customer.address)
- SSM/BRN, TIN, IC (as applicable)
- Phone

**Ship To (right):**
- Branch name
- Branch address
- Branch contact person + phone (if set)
- If no branch on order: show customer's main address (or omit Ship To box)

### 4.2 Invoice page 1

- **Bill To** only (left side, as today but using registration_name)
- No Ship To — invoices can cover multiple branches
- Invoice Details (right side) unchanged

### 4.3 Invoice DO Summary (page 2+)

Each DO block header currently shows: doc_number, date, driver.

**Add:** branch name + branch address after the date/driver line.

Format:
```
AF-DO260401-001                    DO Date: 01/04/2026 | Delivery: 02/04/2026 | Driver: Ahmad
Ship To: MY DAILY MART 08 (Times Square) — Lot 2251, Blk 9, Times Square, 98000 Miri
```

This tells the customer exactly where each DO's stock went.

### 4.4 A4 DO document

Add Ship To box to the right of Bill To in the header area (same two-column layout as described in 4.1).

---

## 5. DailyMart Data Merge

### 5.1 Target state

One customer record:
- **name:** "My DailyMart"
- **registration_name:** "MY DAILY MART SDN BHD"
- **address:** Lot 2495-2496, Ground Floor, Boulevard Commercial Centre, 98000 Miri Sarawak Malaysia
- **phone:** 011-18707757
- **ssm_brn:** 201401022362 (1098448-U)
- **tin:** C23627748000
- **payment_terms, type, etc.:** preserve from whichever record has the most complete data

Two branches:
1. **MY DAILY MART 01 (Boulevard)** — Lot 2496, Ground Floor, Boulevard Commercial Centre, 98000 Miri Sarawak Malaysia — Tel: 6085 427 229 — `is_default: true`
2. **MY DAILY MART 08 (Times Square)** — Lot 2251, Blk 9, Prcel No: B1-G15 & B1-G16, Times Square, 98000 Miri Sarawak — `is_default: false`

### 5.2 Merge procedure

1. Identify the two customer IDs (query DB)
2. Pick one as the "keep" record (update with merged HQ data)
3. **Reassign all foreign keys** from the "lose" record to the "keep" record:
   - `sales_orders.customer_id`
   - `sales_payments` (via orders, no direct customer FK — verify)
   - `sales_returns` (via orders)
   - `sales_invoices.customer_id`
   - `sales_invoice_orders` (via invoices/orders — verify if direct FK)
   - `sales_invoice_payments` (via invoices)
   - `sales_credit_notes` (via invoices)
4. Create the two branch records under the "keep" customer
5. **Assign branch_id** on existing orders where possible (based on which customer they originally belonged to — orders from "DailyMart (Times Square)" get the Times Square branch, orders from "DailyMart (Boulevard)" get the Boulevard branch)
6. Deactivate the "lose" customer (is_active = false) — do NOT delete
7. **Verify counts** before and after: total orders, payments, returns, invoices must match

### 5.3 Migration script

Run as a Node.js pg script (same pattern as other migrations). Script will:
- Print before-counts
- Execute all reassignments in a transaction
- Print after-counts
- Abort if counts don't match

---

## 6. UI Summary

| Location | Change |
|----------|--------|
| Customer form (create/edit) | Add registration_name, email, secondary_phone, credit_limit, currency fields |
| Customer detail page | Add "Delivery Branches" section with CRUD |
| Order form (new/edit) | Add "Deliver To" branch dropdown after customer selection |
| Order cards + detail | Show branch name |
| DO/CS receipt (80mm) | Add Ship To line if branch set |
| DO/CS A4 document | Bill To + Ship To two-column header |
| Invoice A4 page 1 | Bill To uses registration_name; no Ship To |
| Invoice DO Summary | Each DO block shows branch name + address |
| Customer table (list) | No change needed (branches managed in detail page) |

---

## 7. Data scoping

- `sales_customer_branches` gets `company_id` column, filtered like all other sales tables
- Branch dropdown on order form loads branches for the selected customer + current company
- All existing queries on `sales_customers` unchanged (new columns are additive)
- Orders without `branch_id` continue to work (nullable, backwards compatible)
