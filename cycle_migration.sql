-- ============================================================
-- Planting Cycle Migration
-- Adds cycle tracking to block_crops for replanting workflow
-- Safe to run multiple times (idempotent)
-- ============================================================

-- SECTION 1: Add cycle and is_current columns to block_crops
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'block_crops' AND column_name = 'cycle'
  ) THEN
    ALTER TABLE block_crops ADD COLUMN cycle INT NOT NULL DEFAULT 1;
    RAISE NOTICE 'Added cycle column to block_crops';
  ELSE
    RAISE NOTICE 'cycle column already exists on block_crops';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'block_crops' AND column_name = 'is_current'
  ) THEN
    ALTER TABLE block_crops ADD COLUMN is_current BOOLEAN NOT NULL DEFAULT true;
    RAISE NOTICE 'Added is_current column to block_crops';
  ELSE
    RAISE NOTICE 'is_current column already exists on block_crops';
  END IF;
END $$;

-- SECTION 2: Drop old UNIQUE(block_id, variety_id) and add new constraints
-- The old constraint prevents multiple cycles of the same variety on one block
DO $$
BEGIN
  -- Drop the old unique constraint (may have different names depending on creation)
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'block_crops'::regclass
      AND contype = 'u'
      AND array_length(conkey, 1) = 2
      AND conname LIKE '%block_id_variety_id%'
  ) THEN
    EXECUTE 'ALTER TABLE block_crops DROP CONSTRAINT ' ||
      (SELECT conname FROM pg_constraint
       WHERE conrelid = 'block_crops'::regclass
         AND contype = 'u'
         AND conname LIKE '%block_id_variety_id%'
       LIMIT 1);
    RAISE NOTICE 'Dropped old UNIQUE(block_id, variety_id) constraint';
  ELSE
    RAISE NOTICE 'Old UNIQUE(block_id, variety_id) constraint not found (may already be dropped)';
  END IF;
END $$;

-- New unique: one record per block + variety + cycle
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'block_crops'::regclass
      AND conname = 'block_crops_block_variety_cycle_key'
  ) THEN
    ALTER TABLE block_crops ADD CONSTRAINT block_crops_block_variety_cycle_key
      UNIQUE(block_id, variety_id, cycle);
    RAISE NOTICE 'Added UNIQUE(block_id, variety_id, cycle) constraint';
  ELSE
    RAISE NOTICE 'block_crops_block_variety_cycle_key already exists';
  END IF;
END $$;

-- Partial unique index: only one current record per block + variety
CREATE UNIQUE INDEX IF NOT EXISTS block_crops_one_current_per_variety
  ON block_crops(block_id, variety_id) WHERE is_current = true;

-- SECTION 3: Update growth_records_view to only show current cycle records
-- Uses WHERE EXISTS (not JOIN) to preserve PostgREST FK detection through the view
CREATE OR REPLACE VIEW growth_records_view AS
SELECT
  gr.*,
  CASE WHEN gr.date_induced_start IS NOT NULL
    THEN CURRENT_DATE - gr.date_induced_start
    ELSE NULL
  END AS days_after_induce,
  CASE WHEN gr.target_harvest_start IS NOT NULL
    THEN gr.target_harvest_start - CURRENT_DATE
    ELSE NULL
  END AS days_to_harvest
FROM growth_records gr
WHERE EXISTS (
  SELECT 1 FROM block_crops bc
  WHERE bc.id = gr.block_crop_id AND bc.is_current = true
);

-- Re-grant access (CREATE OR REPLACE VIEW may reset permissions)
GRANT SELECT ON growth_records_view TO anon;
GRANT SELECT ON growth_records_view TO authenticated;

-- SECTION 4: Verification (uncomment to test)
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'block_crops' AND column_name IN ('cycle', 'is_current');
-- SELECT conname, contype FROM pg_constraint WHERE conrelid = 'block_crops'::regclass AND contype = 'u';
-- SELECT indexname FROM pg_indexes WHERE tablename = 'block_crops' AND indexname = 'block_crops_one_current_per_variety';
-- SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE is_current) AS current_count FROM block_crops;
