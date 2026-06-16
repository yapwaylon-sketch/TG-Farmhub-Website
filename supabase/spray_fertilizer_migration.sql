-- Spray Summary Matrix migration (2026-06-16)

-- 1. Widen pnd_products.product_type CHECK to allow foliar_fertilizer.
--    (Granular fertilizer is NEVER a spray product, so no granular_fertilizer type.)
ALTER TABLE public.pnd_products DROP CONSTRAINT IF EXISTS pnd_products_product_type_check;
ALTER TABLE public.pnd_products ADD CONSTRAINT pnd_products_product_type_check
  CHECK (product_type = ANY (ARRAY['fungicide','pesticide','herbicide','pgr','adjuvant','carbide','foliar_fertilizer']));

-- 2. New table for granular fertilizer applications (broadcast, not sprayed).
CREATE TABLE IF NOT EXISTS public.pnd_fertilizer_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES public.pnd_blocks(id),
  inventory_product_id text NOT NULL REFERENCES public.products(id),
  quantity numeric,
  quantity_unit text,
  worker_name text,
  date_applied date NOT NULL,
  notes text,
  logged_by text,
  company_id text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pnd_fert_apps_block ON public.pnd_fertilizer_applications(block_id);
CREATE INDEX IF NOT EXISTS idx_pnd_fert_apps_company ON public.pnd_fertilizer_applications(company_id);

-- 3. RLS — open for anon (PIN login) + authenticated (Google), matching other pnd_* tables.
ALTER TABLE public.pnd_fertilizer_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pnd_fert_apps_anon ON public.pnd_fertilizer_applications;
CREATE POLICY pnd_fert_apps_anon ON public.pnd_fertilizer_applications
  FOR ALL TO anon USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS pnd_fert_apps_auth ON public.pnd_fertilizer_applications;
CREATE POLICY pnd_fert_apps_auth ON public.pnd_fertilizer_applications
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
