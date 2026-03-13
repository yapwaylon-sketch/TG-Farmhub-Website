-- Add active_ingredient and formulation columns to pnd_products
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS active_ingredient TEXT;
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS formulation TEXT;
