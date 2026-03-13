-- Migration: Convert 1:1 product→ingredient to many-to-many via junction table
-- This allows products to have 2-3 active ingredients

-- 1. Create junction table
CREATE TABLE IF NOT EXISTS pnd_product_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES pnd_products(id) ON DELETE CASCADE,
  ingredient_id UUID NOT NULL REFERENCES pnd_ingredients(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id, ingredient_id)
);

-- 2. Migrate existing single ingredient_id data into junction table
INSERT INTO pnd_product_ingredients (product_id, ingredient_id)
SELECT id, ingredient_id FROM pnd_products
WHERE ingredient_id IS NOT NULL
ON CONFLICT (product_id, ingredient_id) DO NOTHING;

-- 3. Drop the old single FK column from pnd_products
ALTER TABLE pnd_products DROP COLUMN IF EXISTS ingredient_id;

-- 4. Enable RLS
ALTER TABLE pnd_product_ingredients ENABLE ROW LEVEL SECURITY;

-- 5. RLS policies (same pattern as other pnd_ tables)
DROP POLICY IF EXISTS "anon_read_product_ingredients" ON pnd_product_ingredients;
CREATE POLICY "anon_read_product_ingredients" ON pnd_product_ingredients FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "anon_insert_product_ingredients" ON pnd_product_ingredients;
CREATE POLICY "anon_insert_product_ingredients" ON pnd_product_ingredients FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "anon_delete_product_ingredients" ON pnd_product_ingredients;
CREATE POLICY "anon_delete_product_ingredients" ON pnd_product_ingredients FOR DELETE TO anon USING (true);
