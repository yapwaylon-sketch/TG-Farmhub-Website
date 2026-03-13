-- Wipe all PND Spray Tracker data (tables only, preserves structure)
-- Run in FK-safe order: children first, then parents

DELETE FROM pnd_spray_logs;
DELETE FROM pnd_job_products;
DELETE FROM pnd_jobs;
DELETE FROM pnd_product_ingredients;
DELETE FROM pnd_block_product_overrides;
DELETE FROM pnd_products;
DELETE FROM pnd_ingredients;
DELETE FROM pnd_formulations;
DELETE FROM pnd_blocks;
DELETE FROM pnd_block_statuses;
