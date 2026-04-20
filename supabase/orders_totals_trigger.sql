-- Bulletproof invariant: sales_orders.subtotal = SUM(sales_order_items.line_total)
-- and sales_orders.grand_total = GREATEST(0, subtotal - return_total)
--
-- Two triggers enforce this no matter what the frontend does:
--
-- 1. AFTER INSERT/UPDATE/DELETE on sales_order_items → recompute the parent order's totals.
-- 2. BEFORE UPDATE on sales_orders → if anything but totals+return_total changes, recompute
--    subtotal/grand_total from items before the row is written.
--
-- Applied 2026-04-20 after AF-CS047 incident (subtotal got zeroed when delivery flow ran
-- with empty in-memory items cache). Frontend guards are now also in place (commit 618da68)
-- but these triggers are the last line of defence.

-- ─── Helper: recompute and write totals for a single order ────────────────────
CREATE OR REPLACE FUNCTION recalc_order_totals_for(p_order_id TEXT)
RETURNS VOID AS $$
DECLARE
  v_subtotal NUMERIC;
  v_return_total NUMERIC;
BEGIN
  SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
  FROM sales_order_items
  WHERE order_id = p_order_id;

  SELECT COALESCE(return_total, 0) INTO v_return_total
  FROM sales_orders
  WHERE id = p_order_id;

  UPDATE sales_orders
  SET subtotal = v_subtotal,
      grand_total = GREATEST(0, v_subtotal - v_return_total)
  WHERE id = p_order_id
    AND (subtotal IS DISTINCT FROM v_subtotal
         OR grand_total IS DISTINCT FROM GREATEST(0, v_subtotal - v_return_total));
END;
$$ LANGUAGE plpgsql;

-- ─── Trigger 1: item change → recompute order totals ──────────────────────────
CREATE OR REPLACE FUNCTION trg_items_sync_order_totals()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM recalc_order_totals_for(OLD.order_id);
    RETURN OLD;
  ELSE
    PERFORM recalc_order_totals_for(NEW.order_id);
    -- If the item moved between orders (rare), also recompute the old order
    IF TG_OP = 'UPDATE' AND OLD.order_id IS DISTINCT FROM NEW.order_id THEN
      PERFORM recalc_order_totals_for(OLD.order_id);
    END IF;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS items_sync_order_totals ON sales_order_items;
CREATE TRIGGER items_sync_order_totals
AFTER INSERT OR UPDATE OR DELETE ON sales_order_items
FOR EACH ROW EXECUTE FUNCTION trg_items_sync_order_totals();

-- ─── Trigger 2: order update → force totals from items ────────────────────────
-- Fires BEFORE UPDATE. If frontend writes subtotal/grand_total, we overwrite
-- with the correct values computed from items. return_total is honoured if set.
-- Does NOT fire on INSERT (new orders create empty-item set then items are added,
-- at which point Trigger 1 takes over).
CREATE OR REPLACE FUNCTION trg_orders_enforce_totals()
RETURNS TRIGGER AS $$
DECLARE
  v_subtotal NUMERIC;
BEGIN
  SELECT COALESCE(SUM(line_total), 0) INTO v_subtotal
  FROM sales_order_items
  WHERE order_id = NEW.id;

  -- If there are no items yet (rare — right after insert, before items are inserted),
  -- leave whatever the frontend sent alone. Once items are inserted, Trigger 1 fixes it.
  IF v_subtotal > 0 THEN
    NEW.subtotal := v_subtotal;
    NEW.grand_total := GREATEST(0, v_subtotal - COALESCE(NEW.return_total, 0));
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS orders_enforce_totals ON sales_orders;
CREATE TRIGGER orders_enforce_totals
BEFORE UPDATE ON sales_orders
FOR EACH ROW EXECUTE FUNCTION trg_orders_enforce_totals();
