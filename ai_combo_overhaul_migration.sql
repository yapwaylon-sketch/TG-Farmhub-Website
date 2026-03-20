-- ============================================================
-- AI Combo Overhaul Migration
-- ============================================================

-- 1. Create ai_combo_defaults table
CREATE TABLE IF NOT EXISTS ai_combo_defaults (
  ai_combo_key TEXT PRIMARY KEY,
  dose_amount NUMERIC,
  dose_unit TEXT,
  dose_per_litres INTEGER,
  interval_days INTEGER,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS for ai_combo_defaults
ALTER TABLE ai_combo_defaults ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_all_acd" ON ai_combo_defaults FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "auth_all_acd" ON ai_combo_defaults FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. Populate from existing product dose data
-- Fosetyl-Aluminum 80% (from Linotyl 80WG)
INSERT INTO ai_combo_defaults (ai_combo_key, dose_amount, dose_unit, dose_per_litres, interval_days)
VALUES ('39ea257e-9c59-4d7d-ac5e-4237f59456f5', 250, 'g', 100, 30)
ON CONFLICT (ai_combo_key) DO NOTHING;

-- Copper Hydroxide 57.6% (from Camp DP)
INSERT INTO ai_combo_defaults (ai_combo_key, dose_amount, dose_unit, dose_per_litres, interval_days)
VALUES ('92c3f396-d10c-457f-897c-758213f55a17', 200, 'g', 100, 3)
ON CONFLICT (ai_combo_key) DO NOTHING;

-- Benomyl 50% WP (from Benocide / KENLATE)
INSERT INTO ai_combo_defaults (ai_combo_key, dose_amount, dose_unit, dose_per_litres, interval_days)
VALUES ('fa91ebb2-9a59-4506-97cc-9d8897f94f76', 75, 'g', 100, 30)
ON CONFLICT (ai_combo_key) DO NOTHING;

-- Mancozeb 80% (from Manzate 200)
INSERT INTO ai_combo_defaults (ai_combo_key, dose_amount, dose_unit, dose_per_litres, interval_days)
VALUES ('2fbb56cd-6b45-4543-878a-d6b007fcc07d', 200, 'g', 100, 30)
ON CONFLICT (ai_combo_key) DO NOTHING;

-- Acetamiprid 19.47% + Pyriproxyfen 9.7% (from Khoros 300)
INSERT INTO ai_combo_defaults (ai_combo_key, dose_amount, dose_unit, dose_per_litres, interval_days)
VALUES ('b13cba6a-6029-4bf0-b4e8-524fcef88003,c6e8f77c-69ee-401c-9d09-4bf174831526', 50, 'ml', 100, 60)
ON CONFLICT (ai_combo_key) DO NOTHING;

-- Mancozeb (legacy inactive product)
INSERT INTO ai_combo_defaults (ai_combo_key, dose_amount, dose_unit, dose_per_litres, interval_days)
VALUES ('7092c997-0f1e-493f-b078-ad02b60bbd01', 200, 'g', 100, 30)
ON CONFLICT (ai_combo_key) DO NOTHING;

-- 3. Add ai_combo_key to pnd_jobs
ALTER TABLE pnd_jobs ADD COLUMN IF NOT EXISTS ai_combo_key TEXT;

-- 4. Wipe existing jobs, job_products, and spray logs (confirmed by user — early stage)
DELETE FROM pnd_job_products;
DELETE FROM pnd_spray_logs;
DELETE FROM pnd_jobs;
