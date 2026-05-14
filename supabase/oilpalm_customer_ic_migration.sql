-- Oil Palm Customers: add IC number field (2026-05-14)
-- Customers can now have an IC No recorded, shown on the printable booking slip.
-- Matches the field that existed on the legacy paper booking form (No. 7208 etc).

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS ic_number TEXT NULL;
