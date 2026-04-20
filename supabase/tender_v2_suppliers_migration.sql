-- ============================================================
-- Tender Module v2 — Suppliers + Margin Tracking
-- Date: 2026-04-20
-- Tables: 2 new (tender_suppliers, tender_supplier_purchases)
-- No changes to existing tender tables.
-- Standalone data — no FKs to sales_customers, seedling_*, or any
-- non-tender table. Duplicate records intentionally if planter
-- already exists elsewhere.
-- ============================================================

-- ============================================================
-- PART 1: CREATE TABLES
-- ============================================================

-- 1. Tender Suppliers (standalone planter directory)
CREATE TABLE IF NOT EXISTS tender_suppliers (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  contact_phone TEXT,
  address TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Tender Supplier Purchases (one purchase attached to one LO)
CREATE TABLE IF NOT EXISTS tender_supplier_purchases (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  supplier_id TEXT NOT NULL REFERENCES tender_suppliers(id),
  lo_id TEXT NOT NULL REFERENCES tender_los(id),
  qty INT NOT NULL CHECK (qty > 0),
  unit_cost NUMERIC NOT NULL CHECK (unit_cost >= 0),
  total_cost NUMERIC NOT NULL CHECK (total_cost >= 0),
  purchase_date DATE NOT NULL,
  receipt_status TEXT NOT NULL DEFAULT 'pending' CHECK (receipt_status IN ('pending', 'received')),
  received_date DATE,
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid')),
  payment_date DATE,
  payment_amount NUMERIC,
  payment_ref TEXT,
  payment_bank TEXT,
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- PART 2: INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_tender_suppliers_company ON tender_suppliers(company_id);
CREATE INDEX IF NOT EXISTS idx_tender_suppliers_status ON tender_suppliers(status);

CREATE INDEX IF NOT EXISTS idx_tsp_company ON tender_supplier_purchases(company_id);
CREATE INDEX IF NOT EXISTS idx_tsp_lo ON tender_supplier_purchases(lo_id);
CREATE INDEX IF NOT EXISTS idx_tsp_supplier ON tender_supplier_purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_tsp_payment_status ON tender_supplier_purchases(payment_status);
CREATE INDEX IF NOT EXISTS idx_tsp_purchase_date ON tender_supplier_purchases(purchase_date);

-- ============================================================
-- PART 3: TRIGGERS (reuse existing set_updated_at function)
-- ============================================================

DROP TRIGGER IF EXISTS set_tender_suppliers_updated_at ON tender_suppliers;
CREATE TRIGGER set_tender_suppliers_updated_at
  BEFORE UPDATE ON tender_suppliers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_tsp_updated_at ON tender_supplier_purchases;
CREATE TRIGGER set_tsp_updated_at
  BEFORE UPDATE ON tender_supplier_purchases
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- PART 4: ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE tender_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE tender_supplier_purchases ENABLE ROW LEVEL SECURITY;

-- tender_suppliers
CREATE POLICY tender_suppliers_anon_select ON tender_suppliers FOR SELECT TO anon USING (true);
CREATE POLICY tender_suppliers_anon_insert ON tender_suppliers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY tender_suppliers_anon_update ON tender_suppliers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY tender_suppliers_anon_delete ON tender_suppliers FOR DELETE TO anon USING (true);
CREATE POLICY tender_suppliers_auth_select ON tender_suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY tender_suppliers_auth_insert ON tender_suppliers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY tender_suppliers_auth_update ON tender_suppliers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY tender_suppliers_auth_delete ON tender_suppliers FOR DELETE TO authenticated USING (true);

-- tender_supplier_purchases
CREATE POLICY tsp_anon_select ON tender_supplier_purchases FOR SELECT TO anon USING (true);
CREATE POLICY tsp_anon_insert ON tender_supplier_purchases FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY tsp_anon_update ON tender_supplier_purchases FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY tsp_anon_delete ON tender_supplier_purchases FOR DELETE TO anon USING (true);
CREATE POLICY tsp_auth_select ON tender_supplier_purchases FOR SELECT TO authenticated USING (true);
CREATE POLICY tsp_auth_insert ON tender_supplier_purchases FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY tsp_auth_update ON tender_supplier_purchases FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY tsp_auth_delete ON tender_supplier_purchases FOR DELETE TO authenticated USING (true);

-- ============================================================
-- DONE
-- ID prefixes used: TS (supplier), TP (purchase). next_id() auto-extends.
-- ============================================================
