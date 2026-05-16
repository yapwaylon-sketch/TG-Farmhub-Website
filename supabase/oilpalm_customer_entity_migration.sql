-- Oil Palm Customers: add entity_type (individual/company) + company_number + broken-out address (2026-05-15)
-- Existing rows auto-become entity_type='individual'. Legacy free-text `address` column kept
-- as display fallback when broken-out fields are all NULL.

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS entity_type TEXT NOT NULL DEFAULT 'individual'
    CHECK (entity_type IN ('individual', 'company'));

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS company_number TEXT NULL;

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS address_street1 TEXT NULL;

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS address_street2 TEXT NULL;

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS address_postcode TEXT NULL;

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS address_district TEXT NULL;

ALTER TABLE oilpalm_customers
  ADD COLUMN IF NOT EXISTS address_state TEXT NULL;
