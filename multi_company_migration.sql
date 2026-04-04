-- ============================================================
-- MULTI-COMPANY MIGRATION
-- ============================================================

-- 1. Create companies table
CREATE TABLE IF NOT EXISTS companies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  short_name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO companies (id, name, short_name, code) VALUES
  ('tg_agro_fruits', 'TG Agro Fruits Sdn Bhd', 'TG Agro Fruits', 'AF'),
  ('tg_agribusiness', 'TG Agribusiness Sdn Bhd', 'TG Agribusiness', 'AB')
ON CONFLICT (id) DO NOTHING;

-- 2. RLS on companies (read-only for all)
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'companies' AND policyname = 'anon_read_companies') THEN
    CREATE POLICY anon_read_companies ON companies FOR SELECT TO anon USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'companies' AND policyname = 'auth_read_companies') THEN
    CREATE POLICY auth_read_companies ON companies FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- 3. Add company_id to sales tables
ALTER TABLE sales_customers ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_orders ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoices ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_payments ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_returns ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoice_items ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoice_orders ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_invoice_payments ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_credit_notes ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE sales_order_items ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);

-- 4. Add company_id to operations tables
ALTER TABLE workers ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_jobs ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_spray_logs ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE growth_records ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE payroll_periods ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE salary_advances ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE task_types ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE worker_roles ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE responsibility_types ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE worker_default_responsibilities ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE worker_loans ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE loan_repayments ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE employment_stints ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_ingredients ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_formulations ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_product_ingredients ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_job_products ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE pnd_block_product_overrides ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);
ALTER TABLE ai_combo_defaults ADD COLUMN IF NOT EXISTS company_id TEXT REFERENCES companies(id);

-- 5. Backfill existing data — Sales → TG Agro Fruits
UPDATE sales_customers SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_orders SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_order_items SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_products SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoices SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_payments SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_returns SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoice_items SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoice_orders SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_invoice_payments SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;
UPDATE sales_credit_notes SET company_id = 'tg_agro_fruits' WHERE company_id IS NULL;

-- 6. Backfill existing data — Operations → TG Agribusiness
UPDATE workers SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE products SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE suppliers SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE transactions SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_jobs SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_products SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_spray_logs SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE growth_records SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE payroll_periods SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE salary_advances SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE task_types SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE worker_roles SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE responsibility_types SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE worker_default_responsibilities SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE worker_loans SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE loan_repayments SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE employment_stints SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_ingredients SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_formulations SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_product_ingredients SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_job_products SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE pnd_block_product_overrides SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;
UPDATE ai_combo_defaults SET company_id = 'tg_agribusiness' WHERE company_id IS NULL;

-- 7. Set NOT NULL + defaults on key tables
ALTER TABLE sales_customers ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_customers ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_orders ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_orders ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_products ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_products ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE sales_invoices ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE sales_invoices ALTER COLUMN company_id SET DEFAULT 'tg_agro_fruits';
ALTER TABLE workers ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE workers ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';
ALTER TABLE products ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE products ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';
ALTER TABLE pnd_jobs ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE pnd_jobs ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';
ALTER TABLE growth_records ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE growth_records ALTER COLUMN company_id SET DEFAULT 'tg_agribusiness';

-- 8. Update next_id RPC to support optional company code prefix
-- New format: AF-SO001, AB-W028 (company code + dash + original format)
-- Backward compatible: if no company code passed, returns original format (SO001)
CREATE OR REPLACE FUNCTION next_id(p_prefix TEXT, p_company_code TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_full_prefix TEXT;
  v_next INTEGER;
BEGIN
  -- Build the full prefix: either "AF-SO" or just "SO"
  IF p_company_code IS NOT NULL AND p_company_code != '' THEN
    v_full_prefix := p_company_code || '-' || p_prefix;
  ELSE
    v_full_prefix := p_prefix;
  END IF;

  -- Try to increment existing counter
  UPDATE id_counters SET last_number = last_number + 1
  WHERE prefix = v_full_prefix
  RETURNING last_number INTO v_next;

  -- If no row existed, create one
  IF v_next IS NULL THEN
    INSERT INTO id_counters (prefix, last_number) VALUES (v_full_prefix, 1);
    v_next := 1;
  END IF;

  RETURN v_full_prefix || LPAD(v_next::TEXT, 3, '0');
END;
$$;

-- 9. Recreate growth_records_view to include company_id
DROP VIEW IF EXISTS growth_records_view;
CREATE VIEW growth_records_view AS
SELECT
  gr.id,
  gr.block_crop_id,
  gr.date_induced_start,
  gr.date_induced_end,
  gr.harvest_days,
  gr.created_at,
  gr.updated_at,
  gr.target_induce_date,
  gr.target_harvest_start,
  gr.target_harvest_end,
  gr.company_id,
  CASE
    WHEN gr.date_induced_start IS NOT NULL THEN
      (CURRENT_DATE - gr.date_induced_start)
    ELSE NULL::integer
  END AS days_after_induce,
  CASE
    WHEN gr.target_harvest_start IS NOT NULL THEN
      (gr.target_harvest_start - CURRENT_DATE)
    ELSE NULL::integer
  END AS days_to_harvest
FROM growth_records gr
WHERE EXISTS (
  SELECT 1 FROM block_crops bc
  WHERE bc.id = gr.block_crop_id
    AND bc.is_current = true
);
