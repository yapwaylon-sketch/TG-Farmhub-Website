-- Migration: support cash-back-on-departure + extend category CHECK
--
-- Two unrelated fixes bundled because they're both small and ship in the
-- same UI overhaul:
--
-- 1. Extend salary_advances.category CHECK to include 'Carried Forward'
--    (referenced by createCarryForward in workers.html — would 400-fail the
--    moment any May-2026 negative-final_pay worker is paid) and 'Reinstated
--    Debt' (used by the Reverse Write-Off helper shipped 2026-05-10).
--
-- 2. Add workers.repayment_amount + repayment_at to record cash repaid at
--    departure. Together with bad_debt_writeoff_amount, these break down
--    how the original outstanding hutang at departure was handled.

BEGIN;

-- Extend category CHECK
ALTER TABLE salary_advances
  DROP CONSTRAINT IF EXISTS salary_advances_category_check;

ALTER TABLE salary_advances
  ADD CONSTRAINT salary_advances_category_check
  CHECK (category IN ('Canteen','Cigarettes','Salary Advance','Overpayment','Carried Forward','Reinstated Debt'));

-- New columns on workers
ALTER TABLE workers
  ADD COLUMN IF NOT EXISTS repayment_amount NUMERIC NULL,
  ADD COLUMN IF NOT EXISTS repayment_at TIMESTAMPTZ NULL;

COMMIT;
