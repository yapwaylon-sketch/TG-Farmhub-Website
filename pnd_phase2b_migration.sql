-- =============================================
-- PND Spray Tracker — Phase 2B: Jobs System Database Migration
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- =============================================

-- =============================================
-- CHANGE 1: Add default dosage columns to pnd_products
-- =============================================

ALTER TABLE pnd_products
ADD COLUMN default_dose_amount decimal(10,3) NULL,
ADD COLUMN default_dose_unit text NULL,
ADD COLUMN default_dose_per_litres integer NULL;

-- Add CHECK constraint for allowed dose units
ALTER TABLE pnd_products
ADD CONSTRAINT pnd_products_dose_unit_check
CHECK (default_dose_unit IN ('g', 'ml', 'kg', 'L', NULL));

-- Update existing products with default dosages
UPDATE pnd_products SET default_dose_amount = 250, default_dose_unit = 'g', default_dose_per_litres = 100
WHERE product_name = 'Aluminium Fosetyl (Aliette/Linotyl)';

UPDATE pnd_products SET default_dose_amount = 200, default_dose_unit = 'g', default_dose_per_litres = 100
WHERE product_name = 'Mancozeb';

UPDATE pnd_products SET default_dose_amount = 15, default_dose_unit = 'g', default_dose_per_litres = 15
WHERE product_name = 'Benomyl';

UPDATE pnd_products SET default_dose_amount = 30, default_dose_unit = 'g', default_dose_per_litres = 10
WHERE product_name = 'Copper Hydroxide (CampDP)';

-- =============================================
-- CHANGE 2: Create pnd_block_product_overrides table
-- =============================================

CREATE TABLE pnd_block_product_overrides (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES pnd_blocks(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES pnd_products(id) ON DELETE CASCADE,
  dose_amount decimal(10,3) NOT NULL,
  dose_unit text NOT NULL CHECK (dose_unit IN ('g', 'ml', 'kg', 'L')),
  dose_per_litres integer NOT NULL,
  notes text NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(block_id, product_id)
);

-- RLS for pnd_block_product_overrides
ALTER TABLE pnd_block_product_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on pnd_block_product_overrides"
  ON pnd_block_product_overrides FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Allow anon insert on pnd_block_product_overrides"
  ON pnd_block_product_overrides FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Allow anon update on pnd_block_product_overrides"
  ON pnd_block_product_overrides FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow anon delete on pnd_block_product_overrides"
  ON pnd_block_product_overrides FOR DELETE
  TO anon, authenticated
  USING (true);

-- =============================================
-- CHANGE 3: Create pnd_jobs table
-- =============================================

CREATE TABLE pnd_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES pnd_blocks(id),
  product_id uuid NOT NULL REFERENCES pnd_products(id),
  worker_name text NOT NULL,
  planned_date date NOT NULL,
  tank_size_litres integer NOT NULL,
  tanks_planned integer NOT NULL CHECK (tanks_planned > 0),
  tanks_completed integer NOT NULL DEFAULT 0 CHECK (tanks_completed >= 0),
  dose_amount decimal(10,3) NOT NULL,
  dose_unit text NOT NULL CHECK (dose_unit IN ('g', 'ml', 'kg', 'L')),
  dose_per_litres integer NOT NULL CHECK (dose_per_litres > 0),
  total_product_required decimal(10,3) GENERATED ALWAYS AS (
    (tank_size_litres::decimal * tanks_planned / dose_per_litres) * dose_amount
  ) STORED,
  actual_product_used decimal(10,3) NULL,
  status text NOT NULL DEFAULT 'Planned' CHECK (status IN (
    'Planned', 'In Progress', 'Partially Completed',
    'Suspended', 'Cancelled', 'Completed', 'Verified'
  )),
  suspension_reason text NULL CHECK (suspension_reason IN (
    'Weather', 'Machine Breakdown', 'Worker Unavailable', NULL
  )),
  completion_date date NULL,
  triggers_countdown boolean NULL,
  next_spray_date date NULL,
  verified_by text NULL,
  verified_at timestamptz NULL,
  notes text NULL,
  logged_by text NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_pnd_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pnd_jobs_updated_at_trigger
BEFORE UPDATE ON pnd_jobs
FOR EACH ROW EXECUTE FUNCTION update_pnd_jobs_updated_at();

-- RLS for pnd_jobs (no delete — jobs are cancelled, never deleted)
ALTER TABLE pnd_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on pnd_jobs"
  ON pnd_jobs FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Allow anon insert on pnd_jobs"
  ON pnd_jobs FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Allow anon update on pnd_jobs"
  ON pnd_jobs FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- =============================================
-- CHANGE 4: Auto-write trigger to pnd_spray_logs
-- =============================================

-- Also need to allow the trigger (running as postgres) to insert into pnd_spray_logs
-- Add anon insert policy if not already present
CREATE POLICY "Allow anon insert on pnd_spray_logs"
  ON pnd_spray_logs FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION pnd_jobs_auto_spray_log()
RETURNS TRIGGER AS $$
BEGIN
  -- Only fire when status changes to Completed
  -- OR status changes to Partially Completed with triggers_countdown = true
  IF (NEW.status = 'Completed' AND OLD.status != 'Completed') OR
     (NEW.status = 'Partially Completed' AND NEW.triggers_countdown = true
      AND (OLD.status != 'Partially Completed' OR OLD.triggers_countdown IS DISTINCT FROM true))
  THEN
    -- Avoid duplicate entries
    IF NOT EXISTS (
      SELECT 1 FROM pnd_spray_logs
      WHERE block_id = NEW.block_id
        AND product_id = NEW.product_id
        AND date_completed = NEW.completion_date
        AND logged_by = 'auto:job:' || NEW.id::text
    ) THEN
      INSERT INTO pnd_spray_logs (
        block_id,
        product_id,
        date_completed,
        next_spray_date,
        notes,
        logged_by
      ) VALUES (
        NEW.block_id,
        NEW.product_id,
        NEW.completion_date,
        NEW.next_spray_date,
        'Auto-logged from Job ID: ' || NEW.id::text,
        'auto:job:' || NEW.id::text
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pnd_jobs_spray_log_trigger
AFTER UPDATE ON pnd_jobs
FOR EACH ROW EXECUTE FUNCTION pnd_jobs_auto_spray_log();

-- =============================================
-- CHANGE 5: pnd_latest_sprays view — no changes needed
-- The view reads from pnd_spray_logs which will now be populated
-- by both manual entries and the auto-trigger from jobs.
-- =============================================

-- =============================================
-- VERIFICATION QUERIES (run after migration)
-- =============================================

-- 1. Verify pnd_products schema has new columns
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'pnd_products'
-- ORDER BY ordinal_position;

-- 2. Verify dosage values
-- SELECT product_name, default_dose_amount, default_dose_unit, default_dose_per_litres
-- FROM pnd_products ORDER BY sort_order;

-- 3. Verify pnd_block_product_overrides exists
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'pnd_block_product_overrides'
-- ORDER BY ordinal_position;

-- 4. Verify pnd_jobs exists with generated column
-- SELECT column_name, data_type, is_nullable, generation_expression
-- FROM information_schema.columns
-- WHERE table_name = 'pnd_jobs'
-- ORDER BY ordinal_position;

-- 5. Test the auto-spray-log trigger:
-- INSERT INTO pnd_jobs (block_id, product_id, worker_name, planned_date,
--   tank_size_litres, tanks_planned, dose_amount, dose_unit, dose_per_litres)
-- VALUES (
--   (SELECT id FROM pnd_blocks WHERE block_name = 'N1' LIMIT 1),
--   (SELECT id FROM pnd_products WHERE product_name = 'Mancozeb' LIMIT 1),
--   'Test Worker', '2026-03-08', 100, 2, 200, 'g', 100
-- );
-- Then update to Completed:
-- UPDATE pnd_jobs SET status = 'Completed', completion_date = '2026-03-08',
--   next_spray_date = '2026-03-29', triggers_countdown = true
-- WHERE worker_name = 'Test Worker' AND planned_date = '2026-03-08';
-- Then check pnd_spray_logs for the auto-logged entry:
-- SELECT * FROM pnd_spray_logs WHERE logged_by LIKE 'auto:job:%' ORDER BY created_at DESC LIMIT 5;
-- And check pnd_latest_sprays:
-- SELECT * FROM pnd_latest_sprays;
