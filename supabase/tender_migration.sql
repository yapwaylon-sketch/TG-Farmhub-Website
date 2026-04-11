-- ============================================================
-- Tender Monitoring Module — Database Migration
-- Date: 2026-04-10
-- Tables: 3 (tenders, tender_los, tender_documents)
-- Storage: tender-documents bucket (create via Supabase Dashboard)
-- ============================================================

-- ============================================================
-- PART 1: CREATE TABLES
-- ============================================================

-- 1. Tenders
CREATE TABLE IF NOT EXISTS tenders (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  tender_no TEXT NOT NULL,
  title TEXT,
  variety TEXT NOT NULL,
  issuer TEXT NOT NULL DEFAULT 'LPNM',
  start_date DATE,
  end_date DATE,
  total_qty INT NOT NULL DEFAULT 0,
  unit_price NUMERIC,
  total_value NUMERIC,
  bond_amount NUMERIC,
  bond_provider TEXT,
  bond_policy_no TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'expired')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Tender Letter Orders (LOs)
CREATE TABLE IF NOT EXISTS tender_los (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  tender_id TEXT NOT NULL REFERENCES tenders(id),
  batch_no INT NOT NULL DEFAULT 1,
  seq_no INT NOT NULL DEFAULT 1,
  lo_number TEXT,
  lo_date DATE,
  lo_expiry DATE,
  recipient_name TEXT,
  area TEXT,
  officer_name TEXT,
  officer_phone TEXT,
  qty INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'preparing', 'delivering', 'delivered', 'invoiced', 'paid')),
  do_number TEXT,
  delivery_date DATE,
  invoice_no TEXT,
  invoice_date DATE,
  payment_date DATE,
  payment_amount NUMERIC,
  payment_ref TEXT,
  payment_bank TEXT,
  remarks TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Tender Documents
CREATE TABLE IF NOT EXISTS tender_documents (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  tender_id TEXT NOT NULL REFERENCES tenders(id),
  lo_id TEXT REFERENCES tender_los(id),
  doc_type TEXT NOT NULL CHECK (doc_type IN ('sst', 'contract', 'bond', 'lo_letter', 'submission', 'invoice', 'report', 'extension', 'other')),
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ DEFAULT now(),
  uploaded_by TEXT
);

-- ============================================================
-- PART 2: INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_tenders_company ON tenders(company_id);
CREATE INDEX IF NOT EXISTS idx_tenders_status ON tenders(status);

CREATE INDEX IF NOT EXISTS idx_tender_los_tender ON tender_los(tender_id);
CREATE INDEX IF NOT EXISTS idx_tender_los_status ON tender_los(status);
CREATE INDEX IF NOT EXISTS idx_tender_los_company ON tender_los(company_id);
CREATE INDEX IF NOT EXISTS idx_tender_los_expiry ON tender_los(lo_expiry);
CREATE INDEX IF NOT EXISTS idx_tender_los_batch ON tender_los(tender_id, batch_no);

CREATE INDEX IF NOT EXISTS idx_tender_documents_tender ON tender_documents(tender_id);
CREATE INDEX IF NOT EXISTS idx_tender_documents_lo ON tender_documents(lo_id) WHERE lo_id IS NOT NULL;

-- ============================================================
-- PART 3: TRIGGERS (reuse existing set_updated_at function)
-- ============================================================

CREATE TRIGGER set_tenders_updated_at
  BEFORE UPDATE ON tenders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_tender_los_updated_at
  BEFORE UPDATE ON tender_los
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- PART 4: ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE tenders ENABLE ROW LEVEL SECURITY;
ALTER TABLE tender_los ENABLE ROW LEVEL SECURITY;
ALTER TABLE tender_documents ENABLE ROW LEVEL SECURITY;

-- tenders
CREATE POLICY tenders_anon_select ON tenders FOR SELECT TO anon USING (true);
CREATE POLICY tenders_anon_insert ON tenders FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY tenders_anon_update ON tenders FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY tenders_anon_delete ON tenders FOR DELETE TO anon USING (true);
CREATE POLICY tenders_auth_select ON tenders FOR SELECT TO authenticated USING (true);
CREATE POLICY tenders_auth_insert ON tenders FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY tenders_auth_update ON tenders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY tenders_auth_delete ON tenders FOR DELETE TO authenticated USING (true);

-- tender_los
CREATE POLICY tender_los_anon_select ON tender_los FOR SELECT TO anon USING (true);
CREATE POLICY tender_los_anon_insert ON tender_los FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY tender_los_anon_update ON tender_los FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY tender_los_anon_delete ON tender_los FOR DELETE TO anon USING (true);
CREATE POLICY tender_los_auth_select ON tender_los FOR SELECT TO authenticated USING (true);
CREATE POLICY tender_los_auth_insert ON tender_los FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY tender_los_auth_update ON tender_los FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY tender_los_auth_delete ON tender_los FOR DELETE TO authenticated USING (true);

-- tender_documents
CREATE POLICY tender_documents_anon_select ON tender_documents FOR SELECT TO anon USING (true);
CREATE POLICY tender_documents_anon_insert ON tender_documents FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY tender_documents_anon_update ON tender_documents FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY tender_documents_anon_delete ON tender_documents FOR DELETE TO anon USING (true);
CREATE POLICY tender_documents_auth_select ON tender_documents FOR SELECT TO authenticated USING (true);
CREATE POLICY tender_documents_auth_insert ON tender_documents FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY tender_documents_auth_update ON tender_documents FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY tender_documents_auth_delete ON tender_documents FOR DELETE TO authenticated USING (true);

-- ============================================================
-- DONE
-- Note: Create 'tender-documents' storage bucket via Supabase Dashboard
-- ============================================================
