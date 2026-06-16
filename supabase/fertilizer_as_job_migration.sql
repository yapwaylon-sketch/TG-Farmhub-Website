-- Fertilizer as a job type (2026-06-16)

-- 1. Allow 'Fertilizer' job_type
ALTER TABLE public.pnd_jobs DROP CONSTRAINT IF EXISTS pnd_jobs_job_type_check;
ALTER TABLE public.pnd_jobs ADD CONSTRAINT pnd_jobs_job_type_check
  CHECK (job_type = ANY (ARRAY['Scheduled','Intervention','Fertilizer']));

-- 2. Spray-only columns become nullable (fertilizer jobs leave them null;
--    existing spray jobs still populate them). Their >0 / enum CHECKs pass on NULL.
ALTER TABLE public.pnd_jobs ALTER COLUMN tank_size_litres DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN tanks_planned   DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN dose_amount     DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN dose_unit       DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN dose_per_litres DROP NOT NULL;

-- 3. Fertilizer-specific columns
ALTER TABLE public.pnd_jobs ADD COLUMN IF NOT EXISTS inventory_product_id text REFERENCES public.products(id);
ALTER TABLE public.pnd_jobs ADD COLUMN IF NOT EXISTS fertilizer_quantity numeric;
ALTER TABLE public.pnd_jobs ADD COLUMN IF NOT EXISTS fertilizer_quantity_unit text;

-- 4. Defensive guard: the auto-spray-log trigger must never fire for fertilizer jobs.
--    (They also carry triggers_countdown=false, so this is belt-and-suspenders.)
CREATE OR REPLACE FUNCTION public.pnd_jobs_auto_spray_log()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF COALESCE(NEW.job_type,'') = 'Fertilizer' THEN
    RETURN NEW;
  END IF;
  IF (NEW.status = 'Completed' AND OLD.status != 'Completed' AND NEW.triggers_countdown = true) OR
     (NEW.status = 'Partially Completed' AND NEW.triggers_countdown = true
      AND (OLD.status != 'Partially Completed' OR OLD.triggers_countdown IS DISTINCT FROM true))
  THEN
    IF NOT EXISTS (
      SELECT 1 FROM pnd_spray_logs
      WHERE block_id = NEW.block_id
        AND product_id = NEW.product_id
        AND date_completed = NEW.completion_date
        AND logged_by = 'auto:job:' || NEW.id::text
    ) THEN
      INSERT INTO pnd_spray_logs (
        block_id, product_id, date_completed, next_spray_date, notes, logged_by
      ) VALUES (
        NEW.block_id, NEW.product_id, NEW.completion_date, NEW.next_spray_date,
        'Auto-logged from Job ID: ' || NEW.id::text,
        'auto:job:' || NEW.id::text
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 5. Retire the separate fertilizer table built earlier today (unused, 0 rows).
DROP TABLE IF EXISTS public.pnd_fertilizer_applications CASCADE;
