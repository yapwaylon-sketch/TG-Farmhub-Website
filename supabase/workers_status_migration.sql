-- Migration: richer worker employment status model
--
-- Replaces the binary workers.active flag with employment_status (Active /
-- On Leave / Departed) plus a departure_type sub-classifier and bad-debt
-- write-off tracking. Adds worker_leave_periods for full leave history.
--
-- workers.active is KEPT as a derived column synced via trigger so existing
-- queries across delivery/sales/spray/growth (.eq('active', true)) keep
-- working unchanged.

BEGIN;

-- 1. New columns on workers
ALTER TABLE workers
  ADD COLUMN IF NOT EXISTS employment_status TEXT NOT NULL DEFAULT 'active'
    CHECK (employment_status IN ('active','on_leave','departed')),
  ADD COLUMN IF NOT EXISTS departure_type TEXT NULL
    CHECK (departure_type IN ('resigned','terminated','ran_away','other') OR departure_type IS NULL),
  ADD COLUMN IF NOT EXISTS departure_date DATE NULL,
  ADD COLUMN IF NOT EXISTS departure_notes TEXT NULL,
  ADD COLUMN IF NOT EXISTS bad_debt_writeoff_amount NUMERIC NULL,
  ADD COLUMN IF NOT EXISTS bad_debt_writeoff_at TIMESTAMPTZ NULL;

-- 2. Backfill from existing active flag (idempotent — only touches rows
--    where employment_status hasn't been customised yet)
UPDATE workers
  SET employment_status = 'active'
  WHERE active = true AND employment_status = 'active';

UPDATE workers
  SET employment_status = 'departed',
      departure_type    = COALESCE(departure_type, 'other'),
      departure_date    = COALESCE(departure_date, COALESCE(updated_at::date, CURRENT_DATE))
  WHERE active = false AND employment_status = 'active';

-- 3. Trigger to keep workers.active synced with employment_status
--    Anything that flips employment_status auto-updates active.
CREATE OR REPLACE FUNCTION sync_worker_active_from_status()
RETURNS TRIGGER AS $$
BEGIN
  NEW.active := (NEW.employment_status = 'active');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS workers_sync_active ON workers;
CREATE TRIGGER workers_sync_active
  BEFORE INSERT OR UPDATE OF employment_status ON workers
  FOR EACH ROW EXECUTE FUNCTION sync_worker_active_from_status();

-- 4. Worker leave periods table — full history of leave stretches.
--    end_date NULL means the worker is currently on leave.
CREATE TABLE IF NOT EXISTS worker_leave_periods (
  id          TEXT PRIMARY KEY,
  worker_id   TEXT NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  start_date  DATE NOT NULL,
  end_date    DATE NULL,
  reason      TEXT NULL,
  notes       TEXT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by  TEXT NULL
);

CREATE INDEX IF NOT EXISTS idx_worker_leave_periods_worker
  ON worker_leave_periods (worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_leave_periods_open
  ON worker_leave_periods (worker_id) WHERE end_date IS NULL;

ALTER TABLE worker_leave_periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS worker_leave_periods_anon_all ON worker_leave_periods;
CREATE POLICY worker_leave_periods_anon_all ON worker_leave_periods
  FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS worker_leave_periods_auth_all ON worker_leave_periods;
CREATE POLICY worker_leave_periods_auth_all ON worker_leave_periods
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

COMMIT;
