# Section 01: Database Migration

## Overview

This section creates the database schema foundation for the Sales Invoicing module. It adds 5 new tables, alters 2 existing tables, sets up RLS policies, indexes, constraints, and triggers, and runs a data migration for payment terms. Everything in this section is SQL executed against the Supabase PostgreSQL database.

**Dependencies:** None (this is the foundation section).
**Blocks:** All other sections (02 through 14) depend on this migration completing successfully.

---

## Tests First: Verification Queries

After running the migration, execute these SQL queries in the Supabase SQL Editor to verify correctness.

### Verify: All 5 new tables exist with correct columns

```sql
-- sales_invoices
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoices' ORDER BY ordinal_position;

-- sales_invoice_items
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoice_items' ORDER BY ordinal_position;

-- sales_invoice_orders
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoice_orders' ORDER BY ordinal_position;

-- sales_invoice_payments
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoice_payments' ORDER BY ordinal_position;

-- sales_credit_notes
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_credit_notes' ORDER BY ordinal_position;
```

### Verify: Constraints

```sql
-- UNIQUE constraint on sales_invoice_orders.order_id (prevents double-invoicing)
SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'sales_invoice_orders' AND constraint_type = 'UNIQUE';

-- updated_at trigger on sales_invoices
SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'sales_invoices';
```

### Verify: RLS policies exist for all new tables

```sql
SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'sales_invoice%' OR tablename = 'sales_credit_notes';
```

Expected: 8 policies per table (4 operations x 2 roles = `anon` + `authenticated`), totaling 40 policies across 5 tables.

### Verify: Customer field migration

```sql
-- payment_terms_days column exists and is populated correctly
SELECT name, payment_terms, payment_terms_days FROM sales_customers LIMIT 10;

-- Aggregate check: credit customers should have 30, cash should have 0
SELECT payment_terms, payment_terms_days, count(*) FROM sales_customers GROUP BY payment_terms, payment_terms_days;
```

### Verify: sales_orders.invoice_id column added

```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'sales_orders' AND column_name = 'invoice_id';
```

### Verify: Indexes created

```sql
SELECT indexname, tablename FROM pg_indexes WHERE tablename LIKE 'sales_invoice%' OR tablename = 'sales_credit_notes' ORDER BY tablename, indexname;
```

---

## Implementation Details

### Migration Script

Create a single SQL migration file at:

**File path:** `supabase/invoicing_migration.sql`

Execute via the Supabase SQL Editor (Dashboard > SQL Editor > New query) or via Node.js `pg` script using the DB credentials from CLAUDE.md:
- Host: `aws-1-ap-northeast-1.pooler.supabase.com`
- User: `postgres.qwlagcriiyoflseduvvc`
- Password: `Hlfqdbi6wcM4Omsm`

### Part 1: Create New Tables

#### `sales_invoices` — Core invoice entity

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PRIMARY KEY | Format: `INV-YYMMDD-NNN` via `dbNextId('INV')` |
| `customer_id` | TEXT | NOT NULL, FK → `sales_customers(id)` | |
| `invoice_date` | DATE | NOT NULL | |
| `due_date` | DATE | NOT NULL | Calculated: `invoice_date + payment_terms_days` |
| `payment_terms` | TEXT | NOT NULL | One of: cod, 7days, 14days, 30days, 60days |
| `subtotal` | NUMERIC | NOT NULL DEFAULT 0 | Sum of line items |
| `grand_total` | NUMERIC | NOT NULL DEFAULT 0 | Equals subtotal (no SST — fresh produce exempt) |
| `credit_total` | NUMERIC | NOT NULL DEFAULT 0 | Sum of credit notes applied |
| `amount_paid` | NUMERIC | NOT NULL DEFAULT 0 | Sum of payments received |
| `payment_status` | TEXT | NOT NULL DEFAULT 'unpaid' | unpaid / partial / paid |
| `status` | TEXT | NOT NULL DEFAULT 'draft' | draft / issued / cancelled |
| `approved_by` | TEXT | | User ID who approved (draft → issued) |
| `approved_at` | TIMESTAMPTZ | | Timestamp of approval |
| `notes` | TEXT | | |
| `lhdn_uuid` | TEXT | | Reserved for e-Invoice |
| `lhdn_submission_id` | TEXT | | Reserved for e-Invoice |
| `lhdn_qr_url` | TEXT | | Reserved for e-Invoice |
| `created_by` | TEXT | | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | |
| `updated_at` | TIMESTAMPTZ | DEFAULT now() | Auto-updated by trigger |

#### `sales_invoice_items` — Aggregated product lines per invoice

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PRIMARY KEY | Format: `II-*` via `dbNextId('II')` |
| `invoice_id` | TEXT | NOT NULL, FK → `sales_invoices(id)` ON DELETE CASCADE | |
| `product_id` | TEXT | FK → `sales_products(id)` | |
| `product_name` | TEXT | NOT NULL | Snapshot at invoice creation time |
| `quantity` | NUMERIC | NOT NULL | |
| `unit_price` | NUMERIC | NOT NULL | |
| `line_total` | NUMERIC | NOT NULL | quantity * unit_price |

#### `sales_invoice_orders` — Junction: invoices ↔ delivery orders

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `invoice_id` | TEXT | NOT NULL, FK → `sales_invoices(id)` ON DELETE CASCADE | |
| `order_id` | TEXT | NOT NULL, FK → `sales_orders(id)`, **UNIQUE** | A DO can only belong to one invoice |

Composite primary key on `(invoice_id, order_id)`.

The UNIQUE constraint on `order_id` is critical — it prevents a delivery order from being included in multiple invoices (double-invoicing race condition).

#### `sales_invoice_payments` — Payments against invoices

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PRIMARY KEY | Format: `IP-*` via `dbNextId('IP')` |
| `invoice_id` | TEXT | NOT NULL, FK → `sales_invoices(id)` | |
| `amount` | NUMERIC | NOT NULL | |
| `payment_date` | DATE | NOT NULL | |
| `method` | TEXT | NOT NULL | cash / bank_transfer / cheque |
| `reference` | TEXT | | Bank ref or cheque number |
| `slip_url` | TEXT | | Supabase Storage path for bank slip |
| `notes` | TEXT | | |
| `created_by` | TEXT | | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | |

#### `sales_credit_notes` — Credit adjustments against invoices

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | TEXT | PRIMARY KEY | Format: `CN-YYMMDD-NNN` via `dbNextId('CN')` |
| `invoice_id` | TEXT | NOT NULL, FK → `sales_invoices(id)` | |
| `return_id` | TEXT | FK → `sales_returns(id)`, nullable | Links to existing return if applicable |
| `credit_date` | DATE | NOT NULL | |
| `amount` | NUMERIC | NOT NULL | |
| `reason` | TEXT | NOT NULL | |
| `lhdn_uuid` | TEXT | | Reserved for e-Invoice |
| `created_by` | TEXT | | |
| `created_at` | TIMESTAMPTZ | DEFAULT now() | |

### Part 2: Alter Existing Tables

#### `sales_customers` — Add invoicing fields

Add 4 new columns:
- `ssm_brn` TEXT — company registration number (e.g., "1234567-A")
- `tin` TEXT — tax identification number (e.g., "C1234567890")
- `ic_number` TEXT — IC for individual customers (e.g., "900101-13-1234")
- `payment_terms_days` INT DEFAULT 30

These are all optional fields. Most customers will not have SSM/TIN initially.

#### `sales_orders` — Add invoice link

Add 1 new column:
- `invoice_id` TEXT, nullable, FK → `sales_invoices(id)`

When a DO is included in an invoice, this field gets set. This replaces the old `qb_invoice_no` check for determining if a DO is invoiced.

### Part 3: Data Migration — Payment Terms

After adding `payment_terms_days`, run this data migration to populate it from the existing `payment_terms` column:

```sql
UPDATE sales_customers SET payment_terms_days = 0 WHERE payment_terms = 'cash';
UPDATE sales_customers SET payment_terms_days = 30 WHERE payment_terms = 'credit';
```

The old `payment_terms` column (TEXT: 'credit'/'cash') stays in the database for backward compatibility. The UI will switch to reading `payment_terms_days` in Section 03.

### Part 4: RLS Policies

All 5 new tables need RLS policies for both `anon` and `authenticated` roles. This follows the exact same pattern used on existing sales tables (`sales_orders`, `sales_payments`, etc.):

For each new table, create 8 policies (4 operations x 2 roles):
- `{table}_anon_select` — SELECT for `anon` role, using `true` as the check
- `{table}_anon_insert` — INSERT for `anon` role, using `true` as the check
- `{table}_anon_update` — UPDATE for `anon` role, using `true` as the check
- `{table}_anon_delete` — DELETE for `anon` role, using `true` as the check
- `{table}_auth_select` — SELECT for `authenticated` role, using `true` as the check
- `{table}_auth_insert` — INSERT for `authenticated` role, using `true` as the check
- `{table}_auth_update` — UPDATE for `authenticated` role, using `true` as the check
- `{table}_auth_delete` — DELETE for `authenticated` role, using `true` as the check

Enable RLS on each table with `ALTER TABLE {table} ENABLE ROW LEVEL SECURITY`.

The tables requiring policies: `sales_invoices`, `sales_invoice_items`, `sales_invoice_orders`, `sales_invoice_payments`, `sales_credit_notes`.

### Part 5: Indexes

Create the following indexes for query performance:

```sql
CREATE INDEX idx_sales_invoices_customer_id ON sales_invoices(customer_id);
CREATE INDEX idx_sales_invoices_status ON sales_invoices(status);
CREATE INDEX idx_sales_invoices_payment_status ON sales_invoices(payment_status);
CREATE INDEX idx_sales_invoice_payments_invoice_id ON sales_invoice_payments(invoice_id);
CREATE INDEX idx_sales_credit_notes_invoice_id ON sales_credit_notes(invoice_id);
```

Note: `sales_invoice_orders.order_id` already gets an index from the UNIQUE constraint, so no separate index is needed.

### Part 6: Trigger — `updated_at` on `sales_invoices`

Create a trigger that auto-sets `updated_at = now()` on every UPDATE to `sales_invoices`. This is required for the `sbUpdateWithLock()` optimistic locking pattern used elsewhere in the application.

The trigger function may already exist in the database (check for a function named `set_updated_at` or `update_updated_at_column` or similar). If it exists, reuse it. If not, create one:

```sql
-- Create trigger function (if not already present)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to sales_invoices
CREATE TRIGGER set_sales_invoices_updated_at
  BEFORE UPDATE ON sales_invoices
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
```

### Part 7: Foreign Key on `sales_orders.invoice_id`

```sql
ALTER TABLE sales_orders
  ADD CONSTRAINT fk_sales_orders_invoice_id
  FOREIGN KEY (invoice_id) REFERENCES sales_invoices(id);
```

This FK is nullable — most orders (cash sales, uninvoiced DOs) will have `invoice_id = NULL`.

---

## Migration Execution Checklist

1. Back up the database (or at minimum, verify you can re-run the migration idempotently)
2. Run the full migration SQL in Supabase SQL Editor
3. Execute all verification queries from the "Tests First" section above
4. Confirm `payment_terms_days` data migration results match expectations
5. Confirm RLS policies are in place (40 total across 5 tables)
6. Confirm the `updated_at` trigger fires (test with a manual insert + update on `sales_invoices`)

---

## Key Design Decisions

- **Text IDs (not UUIDs):** All new tables use TEXT primary keys with human-readable prefixes (`INV-`, `II-`, `IP-`, `CN-`), matching the existing pattern in `sales_orders`, `sales_customers`, etc. IDs are generated client-side via `dbNextId()`.
- **ON DELETE CASCADE** on `sales_invoice_items` and `sales_invoice_orders` FK to `sales_invoices` — when an invoice is deleted, its items and DO links are automatically removed.
- **No CASCADE** on `sales_invoice_payments` and `sales_credit_notes` FK to `sales_invoices` — payments and credit notes should not be silently deleted. Invoice cancellation logic (Section 06) handles these explicitly.
- **UNIQUE on `order_id`** in `sales_invoice_orders` — the single most important constraint. Prevents a DO from appearing in two different invoices.
- **`payment_terms` column kept** in `sales_customers` — backward compatibility. The new `payment_terms_days` INT column is the source of truth going forward.
- **e-Invoice columns reserved** (`lhdn_uuid`, `lhdn_submission_id`, `lhdn_qr_url`) — empty for now, ready for future LHDN MyInvois API integration.
