-- Add days_to_induce column to crop_varieties
ALTER TABLE crop_varieties ADD COLUMN days_to_induce integer;

-- Set defaults: MD2 = 300 days, SG1 = 210 days
UPDATE crop_varieties SET days_to_induce = 300 WHERE name = 'MD2';
UPDATE crop_varieties SET days_to_induce = 210 WHERE name = 'SG1';
