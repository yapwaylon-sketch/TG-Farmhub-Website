DROP VIEW IF EXISTS pnd_latest_sprays_by_ai;

-- View: pnd_latest_sprays_by_ai (v2)
-- Groups by AI COMBO (all ingredients of a product together), not individual ingredient
-- The ai_combo_key is a sorted, comma-separated list of ingredient IDs for the product
-- One row per (block_id, ai_combo_key) — most recent spray across all products with that exact AI combo

CREATE OR REPLACE VIEW pnd_latest_sprays_by_ai AS
SELECT block_id, ai_combo_key, product_id, date_completed, next_spray_date, notes, created_at
FROM (
  SELECT
    sl.block_id,
    pc.ai_combo_key,
    sl.product_id,
    sl.date_completed,
    sl.next_spray_date,
    sl.notes,
    sl.created_at,
    ROW_NUMBER() OVER (
      PARTITION BY sl.block_id, pc.ai_combo_key
      ORDER BY sl.created_at DESC
    ) AS rn
  FROM pnd_spray_logs sl
  JOIN (
    SELECT product_id, string_agg(ingredient_id::text, ',' ORDER BY ingredient_id) AS ai_combo_key
    FROM pnd_product_ingredients
    GROUP BY product_id
  ) pc ON pc.product_id = sl.product_id
  WHERE sl.logged_by NOT LIKE 'intervention:%'
) sub
WHERE rn = 1;
