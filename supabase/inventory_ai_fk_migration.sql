-- Inventory module — Active Ingredient becomes a normalized FK (no more free text).
-- Adds products.active_ingredient_id pointing into pnd_ingredients(id).
-- The old text column products.active_ingredient stays in place during transition;
-- it gets dropped in a follow-up migration only after the new column is verified.

-- 1) New nullable FK column. Nullable because "Other" category products
--    (tools, packaging, fertilizers without a single named AI) legitimately have no AI.
alter table public.products
  add column if not exists active_ingredient_id uuid null
    references public.pnd_ingredients(id) on delete set null;

-- 2) Index for the rollup queries (dashboard groups products by AI).
create index if not exists idx_products_active_ingredient_id
  on public.products (active_ingredient_id);

-- 3) PostgREST schema reload so the new column shows up immediately in REST.
notify pgrst, 'reload schema';
