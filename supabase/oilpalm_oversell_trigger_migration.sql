-- Oil Palm Sales — DB-level oversell backstop (2026-06-19)
-- Enforces the one unbreakable invariant inside the database itself, so it holds no matter
-- where the write comes from (the booking form, devtools, a script, or future code paths):
--
--   total committed  =  (all collections handed over for the batch)
--                     +  (outstanding qty of ACTIVE bookings = booked_qty − that booking's collected)
--   committed  <=  physical stock  =  qty_planted − (transplant_culls + cull events) + transplant_extras
--
-- This is the absolute physical ceiling ONLY. The 90% cull buffer, the 50% soft cap, and the
-- per-batch lock are business policy and stay in the client UI (overridable / admin-releasable).
-- The database guards just the hard "can never hand over more plants than exist" rule.
--
-- Mirrors the client opsBatchRemaining() math exactly. Runs AFTER the row is written (so the
-- new/updated row is included in the sums); RAISE EXCEPTION rolls the statement back.
-- Collecting against an existing booking nets to zero (collected +q, that booking's outstanding
-- −q), so normal fulfilment never trips it — only NEW commitments (new booking, new walk-in,
-- raising booked_qty, or moving a row onto a fuller batch) can.

CREATE OR REPLACE FUNCTION oilpalm_check_no_oversell()
RETURNS TRIGGER AS $$
DECLARE
  v_batch_id   TEXT;
  v_stock      NUMERIC;
  v_collected  NUMERIC;
  v_outstanding NUMERIC;
BEGIN
  v_batch_id := NEW.batch_id;            -- both tables have batch_id
  IF v_batch_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Physical living stock for the batch.
  SELECT (COALESCE(b.qty_planted, 0)
          - COALESCE(b.transplant_culls, 0)
          + COALESCE(b.transplant_extras, 0)
          - COALESCE((SELECT SUM(e.qty) FROM oilpalm_batch_events e
                      WHERE e.batch_id = b.id AND e.event_type = 'cull'), 0))
    INTO v_stock
  FROM oilpalm_batches b
  WHERE b.id = v_batch_id;

  IF v_stock IS NULL THEN
    RETURN NEW;                          -- unknown batch — let the FK constraint handle it
  END IF;

  -- All plants already collected/handed over for this batch (walk-in + booking).
  SELECT COALESCE(SUM(c.qty), 0)
    INTO v_collected
  FROM oilpalm_collections c
  WHERE c.batch_id = v_batch_id;

  -- Outstanding reservations from ACTIVE bookings only (booked_qty − that booking's collected).
  SELECT COALESCE(SUM(GREATEST(0, bk.booked_qty - COALESCE(col.collected, 0))), 0)
    INTO v_outstanding
  FROM oilpalm_bookings bk
  LEFT JOIN (
    SELECT booking_id, SUM(qty) AS collected
    FROM oilpalm_collections
    WHERE booking_id IS NOT NULL
    GROUP BY booking_id
  ) col ON col.booking_id = bk.id
  WHERE bk.batch_id = v_batch_id
    AND bk.status = 'active';

  IF (v_collected + v_outstanding) > v_stock THEN
    RAISE EXCEPTION
      'Oversell blocked on batch %: committed % (collected % + outstanding bookings %) exceeds physical stock %',
      v_batch_id, (v_collected + v_outstanding), v_collected, v_outstanding, v_stock
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_oilpalm_bookings_no_oversell ON oilpalm_bookings;
CREATE TRIGGER trg_oilpalm_bookings_no_oversell
  AFTER INSERT OR UPDATE ON oilpalm_bookings
  FOR EACH ROW EXECUTE FUNCTION oilpalm_check_no_oversell();

DROP TRIGGER IF EXISTS trg_oilpalm_collections_no_oversell ON oilpalm_collections;
CREATE TRIGGER trg_oilpalm_collections_no_oversell
  AFTER INSERT OR UPDATE ON oilpalm_collections
  FOR EACH ROW EXECUTE FUNCTION oilpalm_check_no_oversell();
