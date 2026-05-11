-- 2026-05-11: L3.1 document slot + procurement math fields
-- All columns nullable + defaulted so existing rows are unaffected.

ALTER TABLE oilpalm_batches
  ADD COLUMN IF NOT EXISTS l3_1_url TEXT NULL,
  ADD COLUMN IF NOT EXISTS cash_discount NUMERIC(12,2) NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS seeds_allowance INTEGER NULL DEFAULT 0;

-- Sanity:
-- SELECT id, ordered_qty, unit_cost, total_cost, cash_discount, seeds_allowance, l3_1_url
-- FROM oilpalm_batches LIMIT 5;
