-- Migration: Support multiple products per spray job (tank mix)
-- pnd_jobs keeps product_id + dose fields for the primary product (backward compat)
-- pnd_job_products stores ALL products in the mix (including primary)

CREATE TABLE IF NOT EXISTS pnd_job_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES pnd_jobs(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES pnd_products(id),
  dose_amount DECIMAL(10,3),
  dose_unit TEXT,
  dose_per_litres INTEGER,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(job_id, product_id)
);

-- Migrate existing single-product jobs into junction table
INSERT INTO pnd_job_products (job_id, product_id, dose_amount, dose_unit, dose_per_litres)
SELECT id, product_id, dose_amount, dose_unit, dose_per_litres
FROM pnd_jobs WHERE product_id IS NOT NULL
ON CONFLICT (job_id, product_id) DO NOTHING;

-- Enable RLS
ALTER TABLE pnd_job_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_read_job_products" ON pnd_job_products;
CREATE POLICY "anon_read_job_products" ON pnd_job_products FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "anon_insert_job_products" ON pnd_job_products;
CREATE POLICY "anon_insert_job_products" ON pnd_job_products FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "anon_update_job_products" ON pnd_job_products;
CREATE POLICY "anon_update_job_products" ON pnd_job_products FOR UPDATE TO anon USING (true);

DROP POLICY IF EXISTS "anon_delete_job_products" ON pnd_job_products;
CREATE POLICY "anon_delete_job_products" ON pnd_job_products FOR DELETE TO anon USING (true);
