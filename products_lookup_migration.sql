-- Create lookup tables for reusable ingredients and formulations
CREATE TABLE IF NOT EXISTS pnd_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pnd_formulations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Migrate any existing text data into lookup tables
INSERT INTO pnd_ingredients (name)
SELECT DISTINCT active_ingredient FROM pnd_products
WHERE active_ingredient IS NOT NULL AND active_ingredient != ''
ON CONFLICT (name) DO NOTHING;

INSERT INTO pnd_formulations (name)
SELECT DISTINCT formulation FROM pnd_products
WHERE formulation IS NOT NULL AND formulation != ''
ON CONFLICT (name) DO NOTHING;

-- Add FK columns
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS ingredient_id UUID REFERENCES pnd_ingredients(id);
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS formulation_id UUID REFERENCES pnd_formulations(id);

-- Backfill FK from existing text data
UPDATE pnd_products p SET ingredient_id = i.id
FROM pnd_ingredients i WHERE p.active_ingredient = i.name AND p.ingredient_id IS NULL;

UPDATE pnd_products p SET formulation_id = f.id
FROM pnd_formulations f WHERE p.formulation = f.name AND p.formulation_id IS NULL;

-- Drop old text columns
ALTER TABLE pnd_products DROP COLUMN IF EXISTS active_ingredient;
ALTER TABLE pnd_products DROP COLUMN IF EXISTS formulation;

-- Enable RLS
ALTER TABLE pnd_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE pnd_formulations ENABLE ROW LEVEL SECURITY;

-- RLS policies (same pattern as other pnd_ tables)
DROP POLICY IF EXISTS "anon_read_ingredients" ON pnd_ingredients;
CREATE POLICY "anon_read_ingredients" ON pnd_ingredients FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "anon_insert_ingredients" ON pnd_ingredients;
CREATE POLICY "anon_insert_ingredients" ON pnd_ingredients FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "anon_read_formulations" ON pnd_formulations;
CREATE POLICY "anon_read_formulations" ON pnd_formulations FOR SELECT TO anon USING (true);
DROP POLICY IF EXISTS "anon_insert_formulations" ON pnd_formulations;
CREATE POLICY "anon_insert_formulations" ON pnd_formulations FOR INSERT TO anon WITH CHECK (true);
