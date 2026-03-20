-- Add inventory_product_id to pnd_products (links spray product to inventory product)
ALTER TABLE pnd_products ADD COLUMN IF NOT EXISTS inventory_product_id TEXT REFERENCES products(id) ON DELETE SET NULL;

-- Index for lookups
CREATE INDEX IF NOT EXISTS idx_pnd_products_inv ON pnd_products(inventory_product_id);

-- Drop the ingredient_inventory_link table (replaced by direct product link)
DROP TABLE IF EXISTS ingredient_inventory_link;
