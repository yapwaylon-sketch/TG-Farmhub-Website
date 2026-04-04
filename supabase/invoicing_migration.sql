-- ============================================================
-- Sales Invoicing Module — Database Migration
-- TG FarmHub / TG Agro Fruits Sdn Bhd
-- 2026-04-04
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- PART 1: CREATE NEW TABLES
-- ────────────────────────────────────────────────────────────

-- 1a. sales_invoices — Core invoice entity
CREATE TABLE IF NOT EXISTS sales_invoices (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES sales_customers(id),
  invoice_date DATE NOT NULL,
  due_date DATE NOT NULL,
  payment_terms TEXT NOT NULL,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  grand_total NUMERIC NOT NULL DEFAULT 0,
  credit_total NUMERIC NOT NULL DEFAULT 0,
  amount_paid NUMERIC NOT NULL DEFAULT 0,
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  status TEXT NOT NULL DEFAULT 'draft',
  approved_by TEXT,
  approved_at TIMESTAMPTZ,
  notes TEXT,
  lhdn_uuid TEXT,
  lhdn_submission_id TEXT,
  lhdn_qr_url TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 1b. sales_invoice_items — Aggregated product lines per invoice
CREATE TABLE IF NOT EXISTS sales_invoice_items (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
  product_id TEXT REFERENCES sales_products(id),
  product_name TEXT NOT NULL,
  quantity NUMERIC NOT NULL,
  unit_price NUMERIC NOT NULL,
  line_total NUMERIC NOT NULL
);

-- 1c. sales_invoice_orders — Junction: invoices ↔ delivery orders
CREATE TABLE IF NOT EXISTS sales_invoice_orders (
  invoice_id TEXT NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
  order_id TEXT NOT NULL REFERENCES sales_orders(id),
  PRIMARY KEY (invoice_id, order_id),
  UNIQUE (order_id)  -- A DO can only belong to one invoice
);

-- 1d. sales_invoice_payments — Payments against invoices
CREATE TABLE IF NOT EXISTS sales_invoice_payments (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL REFERENCES sales_invoices(id),
  amount NUMERIC NOT NULL,
  payment_date DATE NOT NULL,
  method TEXT NOT NULL,
  reference TEXT,
  slip_url TEXT,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1e. sales_credit_notes — Credit adjustments against invoices
CREATE TABLE IF NOT EXISTS sales_credit_notes (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL REFERENCES sales_invoices(id),
  return_id TEXT REFERENCES sales_returns(id),
  credit_date DATE NOT NULL,
  amount NUMERIC NOT NULL,
  reason TEXT NOT NULL,
  lhdn_uuid TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ────────────────────────────────────────────────────────────
-- PART 2: ALTER EXISTING TABLES
-- ────────────────────────────────────────────────────────────

-- 2a. sales_customers — Add invoicing fields
ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS ssm_brn TEXT;
ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS tin TEXT;
ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS ic_number TEXT;
ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS payment_terms_days INT DEFAULT 30;

-- 2b. sales_orders — Add invoice link
ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS invoice_id TEXT;
ALTER TABLE sales_orders
  ADD CONSTRAINT fk_sales_orders_invoice_id
  FOREIGN KEY (invoice_id) REFERENCES sales_invoices(id);

-- ────────────────────────────────────────────────────────────
-- PART 3: DATA MIGRATION — Payment Terms
-- ────────────────────────────────────────────────────────────

UPDATE sales_customers SET payment_terms_days = 0 WHERE payment_terms = 'cash';
UPDATE sales_customers SET payment_terms_days = 30 WHERE payment_terms = 'credit';

-- ────────────────────────────────────────────────────────────
-- PART 4: RLS POLICIES
-- ────────────────────────────────────────────────────────────

-- Enable RLS on all new tables
ALTER TABLE sales_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_invoice_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_invoice_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_credit_notes ENABLE ROW LEVEL SECURITY;

-- sales_invoices policies
CREATE POLICY sales_invoices_anon_select ON sales_invoices FOR SELECT TO anon USING (true);
CREATE POLICY sales_invoices_anon_insert ON sales_invoices FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY sales_invoices_anon_update ON sales_invoices FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sales_invoices_anon_delete ON sales_invoices FOR DELETE TO anon USING (true);
CREATE POLICY sales_invoices_auth_select ON sales_invoices FOR SELECT TO authenticated USING (true);
CREATE POLICY sales_invoices_auth_insert ON sales_invoices FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY sales_invoices_auth_update ON sales_invoices FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sales_invoices_auth_delete ON sales_invoices FOR DELETE TO authenticated USING (true);

-- sales_invoice_items policies
CREATE POLICY sales_invoice_items_anon_select ON sales_invoice_items FOR SELECT TO anon USING (true);
CREATE POLICY sales_invoice_items_anon_insert ON sales_invoice_items FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY sales_invoice_items_anon_update ON sales_invoice_items FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sales_invoice_items_anon_delete ON sales_invoice_items FOR DELETE TO anon USING (true);
CREATE POLICY sales_invoice_items_auth_select ON sales_invoice_items FOR SELECT TO authenticated USING (true);
CREATE POLICY sales_invoice_items_auth_insert ON sales_invoice_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY sales_invoice_items_auth_update ON sales_invoice_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sales_invoice_items_auth_delete ON sales_invoice_items FOR DELETE TO authenticated USING (true);

-- sales_invoice_orders policies
CREATE POLICY sales_invoice_orders_anon_select ON sales_invoice_orders FOR SELECT TO anon USING (true);
CREATE POLICY sales_invoice_orders_anon_insert ON sales_invoice_orders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY sales_invoice_orders_anon_update ON sales_invoice_orders FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sales_invoice_orders_anon_delete ON sales_invoice_orders FOR DELETE TO anon USING (true);
CREATE POLICY sales_invoice_orders_auth_select ON sales_invoice_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY sales_invoice_orders_auth_insert ON sales_invoice_orders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY sales_invoice_orders_auth_update ON sales_invoice_orders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sales_invoice_orders_auth_delete ON sales_invoice_orders FOR DELETE TO authenticated USING (true);

-- sales_invoice_payments policies
CREATE POLICY sales_invoice_payments_anon_select ON sales_invoice_payments FOR SELECT TO anon USING (true);
CREATE POLICY sales_invoice_payments_anon_insert ON sales_invoice_payments FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY sales_invoice_payments_anon_update ON sales_invoice_payments FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sales_invoice_payments_anon_delete ON sales_invoice_payments FOR DELETE TO anon USING (true);
CREATE POLICY sales_invoice_payments_auth_select ON sales_invoice_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY sales_invoice_payments_auth_insert ON sales_invoice_payments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY sales_invoice_payments_auth_update ON sales_invoice_payments FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sales_invoice_payments_auth_delete ON sales_invoice_payments FOR DELETE TO authenticated USING (true);

-- sales_credit_notes policies
CREATE POLICY sales_credit_notes_anon_select ON sales_credit_notes FOR SELECT TO anon USING (true);
CREATE POLICY sales_credit_notes_anon_insert ON sales_credit_notes FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY sales_credit_notes_anon_update ON sales_credit_notes FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY sales_credit_notes_anon_delete ON sales_credit_notes FOR DELETE TO anon USING (true);
CREATE POLICY sales_credit_notes_auth_select ON sales_credit_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY sales_credit_notes_auth_insert ON sales_credit_notes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY sales_credit_notes_auth_update ON sales_credit_notes FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY sales_credit_notes_auth_delete ON sales_credit_notes FOR DELETE TO authenticated USING (true);

-- ────────────────────────────────────────────────────────────
-- PART 5: INDEXES
-- ────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer_id ON sales_invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_status ON sales_invoices(status);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_payment_status ON sales_invoices(payment_status);
CREATE INDEX IF NOT EXISTS idx_sales_invoice_payments_invoice_id ON sales_invoice_payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_sales_credit_notes_invoice_id ON sales_credit_notes(invoice_id);

-- ────────────────────────────────────────────────────────────
-- PART 6: TRIGGER — updated_at on sales_invoices
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_sales_invoices_updated_at
  BEFORE UPDATE ON sales_invoices
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
