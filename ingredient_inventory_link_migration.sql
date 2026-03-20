-- ingredient_inventory_link: Maps spray tracker active ingredients to inventory products
-- This enables AI-level stock checking and cost tracking across modules

CREATE TABLE IF NOT EXISTS ingredient_inventory_link (
  id TEXT PRIMARY KEY,
  pnd_ingredient_id UUID NOT NULL REFERENCES pnd_ingredients(id) ON DELETE CASCADE,
  inventory_product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(pnd_ingredient_id, inventory_product_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_iil_ingredient ON ingredient_inventory_link(pnd_ingredient_id);
CREATE INDEX IF NOT EXISTS idx_iil_inventory ON ingredient_inventory_link(inventory_product_id);

-- RLS
ALTER TABLE ingredient_inventory_link ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_select_iil" ON ingredient_inventory_link FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_iil" ON ingredient_inventory_link FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "anon_update_iil" ON ingredient_inventory_link FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY "anon_delete_iil" ON ingredient_inventory_link FOR DELETE TO anon USING (true);

CREATE POLICY "auth_select_iil" ON ingredient_inventory_link FOR SELECT TO authenticated USING (true);
CREATE POLICY "auth_insert_iil" ON ingredient_inventory_link FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "auth_update_iil" ON ingredient_inventory_link FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_delete_iil" ON ingredient_inventory_link FOR DELETE TO authenticated USING (true);
