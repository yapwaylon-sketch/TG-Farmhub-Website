-- Oil Palm Sales — booking safeguards (2026-06-19)
-- 1. booking_locked : admin lever to stop ALL new bookings + walk-in sales on a batch.
-- 2. buffer_released: admin lever to lift the 90% hard cap up to 100% physical stock
--    (releases the 10% cull buffer once a batch proves to cull lightly).
-- Neither flag can ever let a sale exceed physical stock — that invariant is enforced
-- in the frontend cap helper regardless of these flags.

ALTER TABLE oilpalm_batches
  ADD COLUMN IF NOT EXISTS booking_locked  BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE oilpalm_batches
  ADD COLUMN IF NOT EXISTS buffer_released BOOLEAN NOT NULL DEFAULT false;
