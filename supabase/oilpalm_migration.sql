-- ============================================================
-- Oil Palm Modules Migration
-- Date: 2026-05-08
-- Drops: 7 seedling_* tables (empty)
-- Creates: 7 oilpalm_* tables, indexes, triggers, RLS policies
-- ============================================================

-- ============================================================
-- PART 1: DROP OLD TABLES
-- ============================================================

DROP TABLE IF EXISTS seedling_collections CASCADE;
DROP TABLE IF EXISTS seedling_payments CASCADE;
DROP TABLE IF EXISTS seedling_bookings CASCADE;
DROP TABLE IF EXISTS seedling_customers CASCADE;
DROP TABLE IF EXISTS seedling_batch_events CASCADE;
DROP TABLE IF EXISTS seedling_batches CASCADE;
DROP TABLE IF EXISTS seedling_suppliers CASCADE;

-- ============================================================
-- PART 2: CREATE NEW TABLES
-- ============================================================

-- 1. Suppliers
CREATE TABLE oilpalm_suppliers (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Batches (one row per procurement; lifecycle Ordered -> Received -> PN -> MN -> Selling -> Sold Out -> Closed)
CREATE TABLE oilpalm_batches (
  id TEXT PRIMARY KEY,                            -- AB-OB001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  batch_number TEXT NOT NULL,                     -- display: 1-2026, 2-2026, ...
  supplier_id TEXT REFERENCES oilpalm_suppliers(id),
  variety_id UUID REFERENCES crop_varieties(id),  -- shared crop_varieties table

  -- Procurement
  ordered_qty INT NOT NULL DEFAULT 0,
  unit_cost NUMERIC NOT NULL DEFAULT 0,
  total_cost NUMERIC NOT NULL DEFAULT 0,
  order_date DATE,
  estimated_delivery_date DATE,
  actual_delivery_date DATE,                       -- filling this flips Ordered -> Received

  -- Single payment per batch
  payment_amount NUMERIC,
  payment_date DATE,
  payment_method TEXT,                             -- cash | bank | cheque
  payment_reference TEXT,
  payment_slip_url TEXT,
  payment_notes TEXT,

  -- 5 fixed document slots
  proforma_url TEXT,
  k3_chit_url TEXT,
  airwaybill_url TEXT,
  official_invoice_url TEXT,
  phyto_cert_url TEXT,

  -- Planting / counts
  date_planted DATE,
  seeds_received INT NOT NULL DEFAULT 0,           -- arrived from supplier
  seeds_damaged INT NOT NULL DEFAULT 0,            -- damaged on arrival
  qty_planted INT NOT NULL DEFAULT 0,              -- = seeds_received - seeds_damaged
  date_transplanted DATE,
  transplant_culls INT NOT NULL DEFAULT 0,
  transplant_extras INT NOT NULL DEFAULT 0,        -- multi-germination gain
  qty_mn_start INT NOT NULL DEFAULT 0,             -- = qty_planted - transplant_culls + transplant_extras

  -- Selling-side
  default_price NUMERIC,                           -- per-batch default unit price
  bookable_pct INT NOT NULL DEFAULT 50,            -- % of qty_mn_start that's bookable (soft cap)

  -- Lifecycle
  status TEXT NOT NULL DEFAULT 'ordered',          -- ordered | received | pre_nursery | main_nursery | selling | sold_out | closed

  -- Misc
  notes TEXT,
  closed_at TIMESTAMPTZ,
  closed_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Batch events (count adjustments: plant, transplant, cull)
CREATE TABLE oilpalm_batch_events (
  id TEXT PRIMARY KEY,                             -- AB-OE001
  batch_id TEXT NOT NULL REFERENCES oilpalm_batches(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,                        -- plant | transplant | cull
  qty INT NOT NULL DEFAULT 0,                      -- delta (positive for plant/extras, negative meaning depends on event_type)
  reason TEXT,
  event_date DATE NOT NULL,
  logged_by TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Customers (booking + walk-in)
CREATE TABLE oilpalm_customers (
  id TEXT PRIMARY KEY,                             -- AB-OC001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  customer_type TEXT NOT NULL DEFAULT 'booking',   -- booking | walkin
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Bookings
CREATE TABLE oilpalm_bookings (
  id TEXT PRIMARY KEY,                             -- AB-OK001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  customer_id TEXT NOT NULL REFERENCES oilpalm_customers(id),
  batch_id TEXT NOT NULL REFERENCES oilpalm_batches(id),  -- CURRENT batch (changes on reassignment)
  booked_qty INT NOT NULL,                         -- original booking qty
  unit_price NUMERIC NOT NULL,                     -- locked-in at booking creation
  total_amount NUMERIC NOT NULL DEFAULT 0,         -- = booked_qty * unit_price
  booking_date DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'active',           -- active | completed | cancelled
  reassignment_history JSONB DEFAULT '[]'::jsonb,  -- [{from_batch, to_batch, date, by_user, reason, kept_price_or_changed}]
  cancel_reason TEXT,
  cancelled_at TIMESTAMPTZ,
  cancelled_by TEXT,
  refund_status TEXT,                              -- null | pending | paid | forfeited
  refund_owed NUMERIC,                             -- calculated at cancellation time
  refund_amount NUMERIC,                           -- actual amount paid out by finance
  refund_method TEXT,
  refund_reference TEXT,
  refund_slip_url TEXT,
  refund_paid_at TIMESTAMPTZ,
  refund_paid_by TEXT,
  refund_notes TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Payments (booking-tied OR collection-tied; negative = refund-on-the-payments-table)
CREATE TABLE oilpalm_payments (
  id TEXT PRIMARY KEY,                             -- AB-OP001
  booking_id TEXT REFERENCES oilpalm_bookings(id) ON DELETE CASCADE,
  collection_id TEXT,                              -- FK added after collections table exists
  amount NUMERIC NOT NULL,                         -- positive for payment, negative for refund (we use booking.refund_* fields instead, but reserved)
  method TEXT NOT NULL DEFAULT 'cash',             -- cash | bank | cheque
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  reference TEXT,
  slip_url TEXT,
  notes TEXT,
  logged_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  CHECK (booking_id IS NOT NULL OR collection_id IS NOT NULL)
);

-- 7. Collections (every L3.1 issuance — booking-driven OR walk-in)
CREATE TABLE oilpalm_collections (
  id TEXT PRIMARY KEY,                             -- AB-OL001
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  customer_id TEXT NOT NULL REFERENCES oilpalm_customers(id),
  booking_id TEXT REFERENCES oilpalm_bookings(id), -- NULL = walk-in
  batch_id TEXT NOT NULL REFERENCES oilpalm_batches(id),  -- denormalized: locked at collection time
  qty INT NOT NULL,
  unit_price NUMERIC NOT NULL,                     -- locked at collection time
  subtotal NUMERIC NOT NULL,                       -- = qty * unit_price
  l3_form_no TEXT NOT NULL,                        -- pre-printed serial from MPOB booklet
  l3_photo_url TEXT NOT NULL,
  collection_photo_url TEXT NOT NULL,
  plate_no TEXT NOT NULL,
  collection_date DATE NOT NULL DEFAULT CURRENT_DATE,
  logged_by TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Add FK from payments.collection_id after collections exists
ALTER TABLE oilpalm_payments
  ADD CONSTRAINT fk_oilpalm_payments_collection_id
  FOREIGN KEY (collection_id) REFERENCES oilpalm_collections(id);

-- Unique L3.1 form numbers (system-wide block)
CREATE UNIQUE INDEX idx_oilpalm_collections_l3_unique ON oilpalm_collections(l3_form_no);

-- ============================================================
-- PART 3: INDEXES
-- ============================================================

CREATE INDEX idx_oilpalm_batches_status ON oilpalm_batches(status);
CREATE INDEX idx_oilpalm_batches_supplier ON oilpalm_batches(supplier_id);
CREATE INDEX idx_oilpalm_batches_variety ON oilpalm_batches(variety_id);
CREATE INDEX idx_oilpalm_batch_events_batch ON oilpalm_batch_events(batch_id);
CREATE INDEX idx_oilpalm_batch_events_date ON oilpalm_batch_events(event_date);
CREATE INDEX idx_oilpalm_customers_phone ON oilpalm_customers(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_oilpalm_bookings_customer ON oilpalm_bookings(customer_id);
CREATE INDEX idx_oilpalm_bookings_batch ON oilpalm_bookings(batch_id);
CREATE INDEX idx_oilpalm_bookings_status ON oilpalm_bookings(status);
CREATE INDEX idx_oilpalm_payments_booking ON oilpalm_payments(booking_id);
CREATE INDEX idx_oilpalm_payments_collection ON oilpalm_payments(collection_id);
CREATE INDEX idx_oilpalm_collections_batch ON oilpalm_collections(batch_id);
CREATE INDEX idx_oilpalm_collections_booking ON oilpalm_collections(booking_id);
CREATE INDEX idx_oilpalm_collections_customer ON oilpalm_collections(customer_id);
CREATE INDEX idx_oilpalm_collections_date ON oilpalm_collections(collection_date);

-- ============================================================
-- PART 4: TRIGGERS (updated_at)
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_oilpalm_suppliers_updated_at  BEFORE UPDATE ON oilpalm_suppliers  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_oilpalm_batches_updated_at    BEFORE UPDATE ON oilpalm_batches    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_oilpalm_customers_updated_at  BEFORE UPDATE ON oilpalm_customers  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_oilpalm_bookings_updated_at   BEFORE UPDATE ON oilpalm_bookings   FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- PART 5: ROW LEVEL SECURITY (open policies — same as other modules)
-- ============================================================

ALTER TABLE oilpalm_suppliers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_batches       ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_batch_events  ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_customers     ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_bookings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_payments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE oilpalm_collections   ENABLE ROW LEVEL SECURITY;

-- oilpalm_suppliers
CREATE POLICY oilpalm_suppliers_anon_select ON oilpalm_suppliers FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_suppliers_anon_insert ON oilpalm_suppliers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_anon_update ON oilpalm_suppliers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_anon_delete ON oilpalm_suppliers FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_suppliers_auth_select ON oilpalm_suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_suppliers_auth_insert ON oilpalm_suppliers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_auth_update ON oilpalm_suppliers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_suppliers_auth_delete ON oilpalm_suppliers FOR DELETE TO authenticated USING (true);

-- oilpalm_batches
CREATE POLICY oilpalm_batches_anon_select ON oilpalm_batches FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_batches_anon_insert ON oilpalm_batches FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_batches_anon_update ON oilpalm_batches FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_batches_anon_delete ON oilpalm_batches FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_batches_auth_select ON oilpalm_batches FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_batches_auth_insert ON oilpalm_batches FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_batches_auth_update ON oilpalm_batches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_batches_auth_delete ON oilpalm_batches FOR DELETE TO authenticated USING (true);

-- oilpalm_batch_events
CREATE POLICY oilpalm_batch_events_anon_select ON oilpalm_batch_events FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_batch_events_anon_insert ON oilpalm_batch_events FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_batch_events_anon_update ON oilpalm_batch_events FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_batch_events_anon_delete ON oilpalm_batch_events FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_batch_events_auth_select ON oilpalm_batch_events FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_batch_events_auth_insert ON oilpalm_batch_events FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_batch_events_auth_update ON oilpalm_batch_events FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_batch_events_auth_delete ON oilpalm_batch_events FOR DELETE TO authenticated USING (true);

-- oilpalm_customers
CREATE POLICY oilpalm_customers_anon_select ON oilpalm_customers FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_customers_anon_insert ON oilpalm_customers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_customers_anon_update ON oilpalm_customers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_customers_anon_delete ON oilpalm_customers FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_customers_auth_select ON oilpalm_customers FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_customers_auth_insert ON oilpalm_customers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_customers_auth_update ON oilpalm_customers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_customers_auth_delete ON oilpalm_customers FOR DELETE TO authenticated USING (true);

-- oilpalm_bookings
CREATE POLICY oilpalm_bookings_anon_select ON oilpalm_bookings FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_bookings_anon_insert ON oilpalm_bookings FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_bookings_anon_update ON oilpalm_bookings FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_bookings_anon_delete ON oilpalm_bookings FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_bookings_auth_select ON oilpalm_bookings FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_bookings_auth_insert ON oilpalm_bookings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_bookings_auth_update ON oilpalm_bookings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_bookings_auth_delete ON oilpalm_bookings FOR DELETE TO authenticated USING (true);

-- oilpalm_payments
CREATE POLICY oilpalm_payments_anon_select ON oilpalm_payments FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_payments_anon_insert ON oilpalm_payments FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_payments_anon_update ON oilpalm_payments FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_payments_anon_delete ON oilpalm_payments FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_payments_auth_select ON oilpalm_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_payments_auth_insert ON oilpalm_payments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_payments_auth_update ON oilpalm_payments FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_payments_auth_delete ON oilpalm_payments FOR DELETE TO authenticated USING (true);

-- oilpalm_collections
CREATE POLICY oilpalm_collections_anon_select ON oilpalm_collections FOR SELECT TO anon USING (true);
CREATE POLICY oilpalm_collections_anon_insert ON oilpalm_collections FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY oilpalm_collections_anon_update ON oilpalm_collections FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_collections_anon_delete ON oilpalm_collections FOR DELETE TO anon USING (true);
CREATE POLICY oilpalm_collections_auth_select ON oilpalm_collections FOR SELECT TO authenticated USING (true);
CREATE POLICY oilpalm_collections_auth_insert ON oilpalm_collections FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY oilpalm_collections_auth_update ON oilpalm_collections FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY oilpalm_collections_auth_delete ON oilpalm_collections FOR DELETE TO authenticated USING (true);

-- ============================================================
-- PART 6: ID COUNTERS (seed initial counter rows for each new prefix)
-- ============================================================

INSERT INTO id_counters (company_id, prefix, last_number) VALUES
  ('tg_agribusiness', 'OS', 0),
  ('tg_agribusiness', 'OB', 0),
  ('tg_agribusiness', 'OE', 0),
  ('tg_agribusiness', 'OC', 0),
  ('tg_agribusiness', 'OK', 0),
  ('tg_agribusiness', 'OP', 0),
  ('tg_agribusiness', 'OL', 0)
ON CONFLICT (company_id, prefix) DO NOTHING;

-- ============================================================
-- DONE
-- ============================================================
