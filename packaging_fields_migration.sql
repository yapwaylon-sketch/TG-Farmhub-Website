-- Add packaging fields to pnd_products
-- Run date: 2026-03-14

ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS packaging_size NUMERIC;
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS packaging_unit TEXT;
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS packaging_type TEXT;
-- packaging_type values: packet, box, bottle, drum, bag, can
