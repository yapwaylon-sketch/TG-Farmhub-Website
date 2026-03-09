-- =============================================
-- Phase 4: Centralized Crop & Block Management
-- Migration date: 2026-03-09
-- Run in Supabase SQL Editor (Dashboard > SQL Editor)
--
-- What this migration does:
--   1. Creates: crops, crop_varieties, crop_statuses, block_crops
--   2. Adds updated_at triggers on relevant tables
--   3. Enables RLS with anon+authenticated read/write policies
--   4. Seeds Pineapples crop, MD2 variety, and migrated statuses
--   5. Populates block_crops from existing pnd_blocks data
--
-- What this migration does NOT do:
--   - Does NOT drop or alter columns on pnd_blocks (backward compatible)
--   - Does NOT modify pnd_block_statuses (still used by legacy code)
--   - Does NOT touch any spray tracker tables
-- =============================================


-- =============================================
-- SECTION 1: SHARED updated_at TRIGGER FUNCTION
-- =============================================

-- Single reusable trigger function for all updated_at columns.
-- CREATE OR REPLACE is safe to run multiple times.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- SECTION 2: crops TABLE
-- Base crop types (e.g. Pineapples, Banana, etc.)
-- =============================================

CREATE TABLE IF NOT EXISTS crops (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text        NOT NULL UNIQUE,
  archived    boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- updated_at trigger
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'crops_set_updated_at'
      AND tgrelid = 'crops'::regclass
  ) THEN
    CREATE TRIGGER crops_set_updated_at
    BEFORE UPDATE ON crops
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END;
$$;

-- RLS
ALTER TABLE crops ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crops' AND policyname = 'Allow public read on crops'
  ) THEN
    CREATE POLICY "Allow public read on crops"
      ON crops FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crops' AND policyname = 'Allow anon insert on crops'
  ) THEN
    CREATE POLICY "Allow anon insert on crops"
      ON crops FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crops' AND policyname = 'Allow anon update on crops'
  ) THEN
    CREATE POLICY "Allow anon update on crops"
      ON crops FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crops' AND policyname = 'Allow anon delete on crops'
  ) THEN
    CREATE POLICY "Allow anon delete on crops"
      ON crops FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- =============================================
-- SECTION 3: crop_varieties TABLE
-- Varieties per crop (e.g. MD2, Josapine under Pineapples)
-- =============================================

CREATE TABLE IF NOT EXISTS crop_varieties (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  crop_id     uuid        NOT NULL REFERENCES crops(id),
  name        text        NOT NULL,
  archived    boolean     NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(crop_id, name)
);

-- updated_at trigger
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'crop_varieties_set_updated_at'
      AND tgrelid = 'crop_varieties'::regclass
  ) THEN
    CREATE TRIGGER crop_varieties_set_updated_at
    BEFORE UPDATE ON crop_varieties
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END;
$$;

-- RLS
ALTER TABLE crop_varieties ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_varieties' AND policyname = 'Allow public read on crop_varieties'
  ) THEN
    CREATE POLICY "Allow public read on crop_varieties"
      ON crop_varieties FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_varieties' AND policyname = 'Allow anon insert on crop_varieties'
  ) THEN
    CREATE POLICY "Allow anon insert on crop_varieties"
      ON crop_varieties FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_varieties' AND policyname = 'Allow anon update on crop_varieties'
  ) THEN
    CREATE POLICY "Allow anon update on crop_varieties"
      ON crop_varieties FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_varieties' AND policyname = 'Allow anon delete on crop_varieties'
  ) THEN
    CREATE POLICY "Allow anon delete on crop_varieties"
      ON crop_varieties FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- =============================================
-- SECTION 4: crop_statuses TABLE
-- Configurable lifecycle statuses per crop type.
-- Decouples status management from the pineapple-specific
-- pnd_block_statuses table, allowing each crop type to have
-- its own status vocabulary.
-- =============================================

CREATE TABLE IF NOT EXISTS crop_statuses (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  crop_id     uuid        NOT NULL REFERENCES crops(id),
  name        text        NOT NULL,
  sort_order  int         NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(crop_id, name)
);

-- No updated_at column on crop_statuses (name changes are rare;
-- callers should delete + re-insert if a rename is needed).

-- RLS
ALTER TABLE crop_statuses ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_statuses' AND policyname = 'Allow public read on crop_statuses'
  ) THEN
    CREATE POLICY "Allow public read on crop_statuses"
      ON crop_statuses FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_statuses' AND policyname = 'Allow anon insert on crop_statuses'
  ) THEN
    CREATE POLICY "Allow anon insert on crop_statuses"
      ON crop_statuses FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_statuses' AND policyname = 'Allow anon update on crop_statuses'
  ) THEN
    CREATE POLICY "Allow anon update on crop_statuses"
      ON crop_statuses FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'crop_statuses' AND policyname = 'Allow anon delete on crop_statuses'
  ) THEN
    CREATE POLICY "Allow anon delete on crop_statuses"
      ON crop_statuses FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- =============================================
-- SECTION 5: block_crops TABLE
-- Many-to-many: links pnd_blocks to crop_varieties.
-- A block can grow multiple varieties; each pairing tracks its
-- own planted date, quantity, and growth status independently.
-- =============================================

CREATE TABLE IF NOT EXISTS block_crops (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id    uuid        NOT NULL REFERENCES pnd_blocks(id) ON DELETE CASCADE,
  variety_id  uuid        NOT NULL REFERENCES crop_varieties(id),
  date_planted date,                                 -- nullable: fill when known
  quantity    int,                                   -- nullable: fill when known
  status_id   uuid        REFERENCES crop_statuses(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(block_id, variety_id)
);

-- updated_at trigger
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'block_crops_set_updated_at'
      AND tgrelid = 'block_crops'::regclass
  ) THEN
    CREATE TRIGGER block_crops_set_updated_at
    BEFORE UPDATE ON block_crops
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END;
$$;

-- RLS
ALTER TABLE block_crops ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'block_crops' AND policyname = 'Allow public read on block_crops'
  ) THEN
    CREATE POLICY "Allow public read on block_crops"
      ON block_crops FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'block_crops' AND policyname = 'Allow anon insert on block_crops'
  ) THEN
    CREATE POLICY "Allow anon insert on block_crops"
      ON block_crops FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'block_crops' AND policyname = 'Allow anon update on block_crops'
  ) THEN
    CREATE POLICY "Allow anon update on block_crops"
      ON block_crops FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'block_crops' AND policyname = 'Allow anon delete on block_crops'
  ) THEN
    CREATE POLICY "Allow anon delete on block_crops"
      ON block_crops FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- =============================================
-- SECTION 6: DEPRECATED COLUMN NOTICE ON pnd_blocks
-- pnd_blocks.date_planted and pnd_blocks.status_id are now
-- superseded by block_crops.date_planted and block_crops.status_id.
-- They are retained here for backward compatibility while legacy
-- code (spray tracker, jobs system) still reads them directly.
-- Do NOT remove these columns until all consumers are migrated
-- to query via block_crops JOIN crop_statuses.
-- =============================================

COMMENT ON COLUMN pnd_blocks.date_planted IS
  'DEPRECATED (Phase 4): Use block_crops.date_planted instead. '
  'Retained for backward compatibility during transition.';

COMMENT ON COLUMN pnd_blocks.status_id IS
  'DEPRECATED (Phase 4): Use block_crops.status_id (references crop_statuses) instead. '
  'Retained for backward compatibility during transition.';


-- =============================================
-- SECTION 7: SEED DATA
-- Wrapped in a single DO block so all inserts share variables
-- and any failure rolls back the entire seed cleanly.
-- =============================================

DO $$
DECLARE
  v_crop_id       uuid;
  v_variety_id    uuid;

  -- crop_statuses IDs — one variable per status
  v_cs_growing    uuid;
  v_cs_induced    uuid;
  v_cs_suckers    uuid;
  v_cs_replant    uuid;
  v_cs_toinduce   uuid;
  v_cs_tunggu     uuid;
  v_cs_abandoned  uuid;
BEGIN

  -- ------------------------------------------
  -- 7a. Insert "Pineapples" crop (idempotent)
  -- ------------------------------------------
  INSERT INTO crops (name)
  VALUES ('Pineapples')
  ON CONFLICT (name) DO NOTHING;

  SELECT id INTO v_crop_id
  FROM crops
  WHERE name = 'Pineapples';

  -- ------------------------------------------
  -- 7b. Insert "MD2" variety under Pineapples (idempotent)
  -- All 28 existing blocks grow MD2 — this is the default variety.
  -- ------------------------------------------
  INSERT INTO crop_varieties (crop_id, name)
  VALUES (v_crop_id, 'MD2')
  ON CONFLICT (crop_id, name) DO NOTHING;

  SELECT id INTO v_variety_id
  FROM crop_varieties
  WHERE crop_id = v_crop_id AND name = 'MD2';

  -- ------------------------------------------
  -- 7c. Migrate pnd_block_statuses → crop_statuses (idempotent)
  -- Status names and sort_order are preserved exactly as-is so
  -- that mapped status_ids in block_crops align with the legacy
  -- display values already familiar to users.
  -- ------------------------------------------
  INSERT INTO crop_statuses (crop_id, name, sort_order)
  VALUES
    (v_crop_id, 'Growing',         1),
    (v_crop_id, 'Induced',         2),
    (v_crop_id, 'Suckers',         3),
    (v_crop_id, 'To Replant',      4),
    (v_crop_id, 'To Induce',       5),
    (v_crop_id, 'Tunggu Buah',     6),
    (v_crop_id, 'Abandoned (ATM)', 7)
  ON CONFLICT (crop_id, name) DO NOTHING;

  -- Capture the new crop_statuses IDs for the block_crops migration below
  SELECT id INTO v_cs_growing   FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'Growing';
  SELECT id INTO v_cs_induced   FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'Induced';
  SELECT id INTO v_cs_suckers   FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'Suckers';
  SELECT id INTO v_cs_replant   FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'To Replant';
  SELECT id INTO v_cs_toinduce  FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'To Induce';
  SELECT id INTO v_cs_tunggu    FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'Tunggu Buah';
  SELECT id INTO v_cs_abandoned FROM crop_statuses WHERE crop_id = v_crop_id AND name = 'Abandoned (ATM)';

  -- ------------------------------------------
  -- 7d. Populate block_crops from existing pnd_blocks
  --
  -- Migrates every block that has either a date_planted or a
  -- status_id set (i.e. blocks with any meaningful data).
  -- Blocks with both columns NULL are skipped — they have no
  -- crop-level information worth migrating yet.
  --
  -- Status mapping: joins pnd_blocks → pnd_block_statuses by
  -- status_name, then looks up the matching crop_statuses row.
  -- quantity is left NULL — to be filled by farm staff later.
  -- ON CONFLICT ensures this is safe to re-run.
  -- ------------------------------------------
  INSERT INTO block_crops (block_id, variety_id, date_planted, quantity, status_id)
  SELECT
    b.id                           AS block_id,
    v_variety_id                   AS variety_id,
    b.date_planted,
    NULL::int                      AS quantity,
    CASE pbs.status_name
      WHEN 'Growing'         THEN v_cs_growing
      WHEN 'Induced'         THEN v_cs_induced
      WHEN 'Suckers'         THEN v_cs_suckers
      WHEN 'To Replant'      THEN v_cs_replant
      WHEN 'To Induce'       THEN v_cs_toinduce
      WHEN 'Tunggu Buah'     THEN v_cs_tunggu
      WHEN 'Abandoned (ATM)' THEN v_cs_abandoned
      ELSE NULL
    END                            AS status_id
  FROM pnd_blocks b
  LEFT JOIN pnd_block_statuses pbs ON pbs.id = b.status_id
  WHERE b.date_planted IS NOT NULL
     OR b.status_id    IS NOT NULL
  ON CONFLICT (block_id, variety_id) DO NOTHING;

END;
$$;


-- =============================================
-- SECTION 8: INDEXES
-- Added after seed data so the planner benefits immediately.
-- =============================================

-- Lookup varieties by crop (used by crop config UI dropdowns)
CREATE INDEX IF NOT EXISTS idx_crop_varieties_crop_id
  ON crop_varieties(crop_id);

-- Lookup statuses by crop (used when rendering status dropdowns)
CREATE INDEX IF NOT EXISTS idx_crop_statuses_crop_id
  ON crop_statuses(crop_id);

-- Lookup all crop entries for a block (used on block detail views)
CREATE INDEX IF NOT EXISTS idx_block_crops_block_id
  ON block_crops(block_id);

-- Lookup all blocks growing a given variety (used for variety reports)
CREATE INDEX IF NOT EXISTS idx_block_crops_variety_id
  ON block_crops(variety_id);


-- =============================================
-- VERIFICATION QUERIES
-- Uncomment and run each block individually after migration
-- to confirm correctness before proceeding to Phase 5.
-- =============================================

-- 1. Confirm all 4 new tables exist with correct column counts
-- SELECT table_name, COUNT(*) AS col_count
-- FROM information_schema.columns
-- WHERE table_name IN ('crops', 'crop_varieties', 'crop_statuses', 'block_crops')
--   AND table_schema = 'public'
-- GROUP BY table_name
-- ORDER BY table_name;
-- Expected: block_crops=8, crop_statuses=5, crop_varieties=7, crops=5

-- 2. Confirm seed: 1 crop, 1 variety, 7 statuses
-- SELECT 'crops'         AS tbl, COUNT(*) FROM crops
-- UNION ALL
-- SELECT 'crop_varieties',        COUNT(*) FROM crop_varieties
-- UNION ALL
-- SELECT 'crop_statuses',         COUNT(*) FROM crop_statuses;
-- Expected: crops=1, crop_varieties=1, crop_statuses=7

-- 3. Confirm crop_statuses names and sort order
-- SELECT cs.name, cs.sort_order
-- FROM crop_statuses cs
-- JOIN crops c ON c.id = cs.crop_id
-- WHERE c.name = 'Pineapples'
-- ORDER BY cs.sort_order;
-- Expected: Growing(1) .. Abandoned (ATM)(7)

-- 4. Confirm block_crops row count matches migrated blocks
-- (Should equal number of pnd_blocks where date_planted IS NOT NULL OR status_id IS NOT NULL)
-- SELECT COUNT(*) AS migrated_block_crops FROM block_crops;
-- Cross-check:
-- SELECT COUNT(*) AS source_blocks
-- FROM pnd_blocks
-- WHERE date_planted IS NOT NULL OR status_id IS NOT NULL;
-- Both counts should match.

-- 5. Spot-check a known block: N1 should be MD2, Growing, planted 2025-07-01
-- SELECT
--   b.block_name,
--   cv.name  AS variety,
--   cs.name  AS status,
--   bc.date_planted,
--   bc.quantity
-- FROM block_crops bc
-- JOIN pnd_blocks      b  ON b.id  = bc.block_id
-- JOIN crop_varieties  cv ON cv.id = bc.variety_id
-- LEFT JOIN crop_statuses cs ON cs.id = bc.status_id
-- WHERE b.block_name = 'N1';
-- Expected: N1 | MD2 | Growing | 2025-07-01 | NULL

-- 6. Full migration audit — all migrated blocks with their new statuses
-- SELECT
--   b.block_name,
--   cv.name          AS variety,
--   bc.date_planted  AS new_date_planted,
--   b.date_planted   AS old_date_planted,
--   cs.name          AS new_status,
--   pbs.status_name  AS old_status,
--   bc.quantity
-- FROM block_crops bc
-- JOIN pnd_blocks        b   ON b.id   = bc.block_id
-- JOIN crop_varieties    cv  ON cv.id  = bc.variety_id
-- LEFT JOIN crop_statuses    cs  ON cs.id  = bc.status_id
-- LEFT JOIN pnd_block_statuses pbs ON pbs.id = b.status_id
-- ORDER BY b.sort_order;

-- 7. Confirm RLS is enabled on all 4 tables
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE tablename IN ('crops', 'crop_varieties', 'crop_statuses', 'block_crops')
--   AND schemaname = 'public';
-- Expected: rowsecurity = true for all 4

-- 8. Confirm policies exist (should see 4 policies per table for anon+authenticated)
-- SELECT tablename, policyname, cmd, roles
-- FROM pg_policies
-- WHERE tablename IN ('crops', 'crop_varieties', 'crop_statuses', 'block_crops')
-- ORDER BY tablename, cmd;

-- 9. Confirm updated_at triggers are attached
-- SELECT tgname, tgrelid::regclass AS table_name
-- FROM pg_trigger
-- WHERE tgname IN (
--   'crops_set_updated_at',
--   'crop_varieties_set_updated_at',
--   'block_crops_set_updated_at'
-- )
-- ORDER BY table_name;

-- 10. Confirm deprecated column comments on pnd_blocks
-- SELECT column_name, col_description(
--   (SELECT oid FROM pg_class WHERE relname = 'pnd_blocks'),
--   ordinal_position
-- ) AS comment
-- FROM information_schema.columns
-- WHERE table_name = 'pnd_blocks'
--   AND column_name IN ('date_planted', 'status_id');
