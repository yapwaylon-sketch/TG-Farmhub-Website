-- ============================================================
-- Growth Tracker Migration
-- Adds harvest preset to crop_varieties + growth_records table
-- Safe to run multiple times (idempotent)
-- ============================================================

-- ============================================================
-- SECTION 1: Add harvest_days_from_induction to crop_varieties
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'crop_varieties' AND column_name = 'harvest_days_from_induction'
  ) THEN
    ALTER TABLE crop_varieties ADD COLUMN harvest_days_from_induction INT;
    RAISE NOTICE 'Added harvest_days_from_induction to crop_varieties';
  ELSE
    RAISE NOTICE 'harvest_days_from_induction already exists on crop_varieties';
  END IF;
END $$;

-- Seed defaults for existing varieties
UPDATE crop_varieties SET harvest_days_from_induction = 140 WHERE name = 'MD2' AND harvest_days_from_induction IS NULL;
UPDATE crop_varieties SET harvest_days_from_induction = 120 WHERE name = 'SG1' AND harvest_days_from_induction IS NULL;

-- ============================================================
-- SECTION 2: Create growth_records table
-- ============================================================
CREATE TABLE IF NOT EXISTS growth_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  block_crop_id UUID NOT NULL REFERENCES block_crops(id) ON DELETE CASCADE,
  date_induced_start DATE,
  date_induced_end DATE,
  harvest_days INT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(block_crop_id)
);

-- Trigger for updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'set_growth_records_updated_at'
  ) THEN
    CREATE TRIGGER set_growth_records_updated_at
      BEFORE UPDATE ON growth_records
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
    RAISE NOTICE 'Created updated_at trigger for growth_records';
  END IF;
END $$;

-- Index on FK
CREATE INDEX IF NOT EXISTS idx_growth_records_block_crop_id ON growth_records(block_crop_id);

-- ============================================================
-- SECTION 3: RLS for growth_records
-- ============================================================
ALTER TABLE growth_records ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'growth_records' AND policyname = 'Allow public read on growth_records') THEN
    CREATE POLICY "Allow public read on growth_records" ON growth_records FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'growth_records' AND policyname = 'Allow anon insert on growth_records') THEN
    CREATE POLICY "Allow anon insert on growth_records" ON growth_records FOR INSERT TO anon, authenticated WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'growth_records' AND policyname = 'Allow anon update on growth_records') THEN
    CREATE POLICY "Allow anon update on growth_records" ON growth_records FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'growth_records' AND policyname = 'Allow anon delete on growth_records') THEN
    CREATE POLICY "Allow anon delete on growth_records" ON growth_records FOR DELETE TO anon, authenticated USING (true);
  END IF;
END $$;

-- ============================================================
-- SECTION 4: Verification (commented out — uncomment to test)
-- ============================================================
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'crop_varieties' AND column_name = 'harvest_days_from_induction';
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'growth_records' ORDER BY ordinal_position;
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE tablename = 'growth_records';
-- SELECT name, harvest_days_from_induction FROM crop_varieties;
