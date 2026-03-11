-- Add target date columns to growth_records
ALTER TABLE growth_records ADD COLUMN IF NOT EXISTS target_induce_date date;
ALTER TABLE growth_records ADD COLUMN IF NOT EXISTS target_harvest_start date;
ALTER TABLE growth_records ADD COLUMN IF NOT EXISTS target_harvest_end date;

-- Backfill target_harvest_start/end for existing records that have induction data
UPDATE growth_records gr
SET target_harvest_start = (gr.date_induced_start::date + gr.harvest_days),
    target_harvest_end = CASE WHEN gr.date_induced_end IS NOT NULL THEN (gr.date_induced_end::date + gr.harvest_days) ELSE NULL END
WHERE gr.date_induced_start IS NOT NULL AND gr.harvest_days IS NOT NULL;

-- Backfill target_induce_date for existing records from block_crops + variety defaults
UPDATE growth_records gr
SET target_induce_date = (bc.date_planted::date + cv.days_to_induce)
FROM block_crops bc
JOIN crop_varieties cv ON cv.id = bc.variety_id
WHERE gr.block_crop_id = bc.id
  AND bc.date_planted IS NOT NULL
  AND cv.days_to_induce IS NOT NULL;

-- Create growth_records for block_crops that don't have one yet but have date_planted
INSERT INTO growth_records (block_crop_id, target_induce_date)
SELECT bc.id, (bc.date_planted::date + cv.days_to_induce)
FROM block_crops bc
JOIN crop_varieties cv ON cv.id = bc.variety_id
WHERE bc.date_planted IS NOT NULL
  AND cv.days_to_induce IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM growth_records gr WHERE gr.block_crop_id = bc.id);
