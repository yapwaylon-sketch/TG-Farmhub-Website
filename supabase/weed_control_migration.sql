-- Weed Control module — 3 dedicated tables (2026-06-17)
-- Isolated from Crop Care (pnd_jobs) so weed/herbicide sprays don't pollute pineapple
-- plant-health analysis. Products are NOT duplicated — Manage Products reuses the
-- existing pnd_products herbicide rows (inventory remains the single source of truth).
-- Areas table is created now (schema-ready) but has no management UI yet; V1 jobs are
-- block-only. block_id/area_id are nullable with a CHECK that exactly one is set.

-- ── 1. Areas (drains / roadsides / fallow) — created now, UI deferred ───────────
CREATE TABLE IF NOT EXISTS pnd_weed_areas (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  description text,
  active      boolean NOT NULL DEFAULT true,
  company_id  text NOT NULL DEFAULT 'tg_agribusiness',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ── 2. Weed-spray jobs ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pnd_weed_jobs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id          uuid REFERENCES pnd_blocks(id),
  area_id           uuid REFERENCES pnd_weed_areas(id),
  job_type          text NOT NULL DEFAULT 'Scheduled'
                      CHECK (job_type IN ('Scheduled','Intervention')),
  worker_name       text,
  planned_date      date,
  completion_date   date,
  tank_size_litres  numeric,
  tanks_planned     numeric,
  tanks_completed   numeric,
  product_id        uuid REFERENCES pnd_products(id),  -- primary product (first in mix)
  status            text NOT NULL DEFAULT 'Planned'
                      CHECK (status IN ('Planned','In Progress','Partially Completed','Suspended','Completed')),
  notes             text,
  logged_by         text,
  company_id        text NOT NULL DEFAULT 'tg_agribusiness',
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  -- exactly one location: a block OR an area (V1 always uses block_id)
  CONSTRAINT pnd_weed_jobs_one_location
    CHECK ( (block_id IS NOT NULL)::int + (area_id IS NOT NULL)::int = 1 )
);

-- ── 3. Tank-mix junction (one row per herbicide in the job) ──────────────────────
CREATE TABLE IF NOT EXISTS pnd_weed_job_products (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  weed_job_id     uuid NOT NULL REFERENCES pnd_weed_jobs(id) ON DELETE CASCADE,
  product_id      uuid REFERENCES pnd_products(id),
  dose_amount     numeric,
  dose_unit       text,
  dose_per_litres numeric,
  ai_snapshot     text,   -- active ingredient name(s) captured at save time
  company_id      text NOT NULL DEFAULT 'tg_agribusiness'
);

-- ── Indexes ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_weed_jobs_block      ON pnd_weed_jobs(block_id);
CREATE INDEX IF NOT EXISTS idx_weed_jobs_area       ON pnd_weed_jobs(area_id);
CREATE INDEX IF NOT EXISTS idx_weed_jobs_status     ON pnd_weed_jobs(status);
CREATE INDEX IF NOT EXISTS idx_weed_jobs_planned    ON pnd_weed_jobs(planned_date);
CREATE INDEX IF NOT EXISTS idx_weed_jobs_completion ON pnd_weed_jobs(completion_date);
CREATE INDEX IF NOT EXISTS idx_weed_jp_job          ON pnd_weed_job_products(weed_job_id);
CREATE INDEX IF NOT EXISTS idx_weed_jp_product      ON pnd_weed_job_products(product_id);

-- ── updated_at trigger on jobs ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION pnd_weed_jobs_set_updated_at()
RETURNS trigger AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS tr_pnd_weed_jobs_updated_at ON pnd_weed_jobs;
CREATE TRIGGER tr_pnd_weed_jobs_updated_at
  BEFORE UPDATE ON pnd_weed_jobs
  FOR EACH ROW EXECUTE FUNCTION pnd_weed_jobs_set_updated_at();

-- ── RLS (anon for PIN login + authenticated for Google OAuth) ────────────────────
ALTER TABLE pnd_weed_areas        ENABLE ROW LEVEL SECURITY;
ALTER TABLE pnd_weed_jobs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pnd_weed_job_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS pnd_weed_areas_anon        ON pnd_weed_areas;
DROP POLICY IF EXISTS pnd_weed_areas_auth        ON pnd_weed_areas;
DROP POLICY IF EXISTS pnd_weed_jobs_anon         ON pnd_weed_jobs;
DROP POLICY IF EXISTS pnd_weed_jobs_auth         ON pnd_weed_jobs;
DROP POLICY IF EXISTS pnd_weed_job_products_anon ON pnd_weed_job_products;
DROP POLICY IF EXISTS pnd_weed_job_products_auth ON pnd_weed_job_products;

CREATE POLICY pnd_weed_areas_anon        ON pnd_weed_areas        FOR ALL TO anon          USING (true) WITH CHECK (true);
CREATE POLICY pnd_weed_areas_auth        ON pnd_weed_areas        FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY pnd_weed_jobs_anon         ON pnd_weed_jobs         FOR ALL TO anon          USING (true) WITH CHECK (true);
CREATE POLICY pnd_weed_jobs_auth         ON pnd_weed_jobs         FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY pnd_weed_job_products_anon ON pnd_weed_job_products FOR ALL TO anon          USING (true) WITH CHECK (true);
CREATE POLICY pnd_weed_job_products_auth ON pnd_weed_job_products FOR ALL TO authenticated USING (true) WITH CHECK (true);
