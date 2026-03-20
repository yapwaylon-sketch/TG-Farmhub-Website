-- View: pnd_latest_sprays_by_ai
-- One row per (block_id, ingredient_id) — most recent spray of ANY product containing that AI
-- Uses created_at DESC (same as pnd_latest_sprays) to pick the most recently inserted log

CREATE OR REPLACE VIEW pnd_latest_sprays_by_ai AS
SELECT block_id, ingredient_id, product_id, date_completed, next_spray_date, notes, created_at
FROM (
  SELECT
    sl.block_id,
    pi.ingredient_id,
    sl.product_id,
    sl.date_completed,
    sl.next_spray_date,
    sl.notes,
    sl.created_at,
    ROW_NUMBER() OVER (
      PARTITION BY sl.block_id, pi.ingredient_id
      ORDER BY sl.created_at DESC
    ) AS rn
  FROM pnd_spray_logs sl
  JOIN pnd_product_ingredients pi ON pi.product_id = sl.product_id
  WHERE sl.logged_by NOT LIKE 'intervention:%'
) sub
WHERE rn = 1;
