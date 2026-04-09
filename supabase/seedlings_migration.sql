-- ============================================================
-- Oil Palm Seedlings Module — Database Migration
-- Date: 2026-04-10
-- Tables: 7 (seedling_suppliers, seedling_batches, seedling_batch_events,
--             seedling_customers, seedling_bookings, seedling_payments, seedling_collections)
-- ============================================================

-- ============================================================
-- PART 1: CREATE TABLES
-- ============================================================

-- 1. Seedling Suppliers
CREATE TABLE IF NOT EXISTS seedling_suppliers (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  license_no TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Seedling Batches
CREATE TABLE IF NOT EXISTS seedling_batches (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  batch_number TEXT NOT NULL,
  supplier_id TEXT REFERENCES seedling_suppliers(id),
  supplier_l31_no TEXT,
  supplier_do_no TEXT,
  variety TEXT NOT NULL,
  seed_source_desc TEXT,
  qty_seeds_received INT NOT NULL DEFAULT 0,
  qty_transplanted INT NOT NULL DEFAULT 0,
  qty_doubletons_gained INT NOT NULL DEFAULT 0,
  qty_culled_total INT NOT NULL DEFAULT 0,
  qty_sold_total INT NOT NULL DEFAULT 0,
  qty_booked INT NOT NULL DEFAULT 0,
  allocation_pct INT NOT NULL DEFAULT 50,
  date_received DATE,
  date_planted DATE,
  date_transplanted DATE,
  date_sellable DATE,
  field_block TEXT,
  price_per_seedling NUMERIC,
  status TEXT NOT NULL DEFAULT 'pre_nursery',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Seedling Batch Events
CREATE TABLE IF NOT EXISTS seedling_batch_events (
  id TEXT PRIMARY KEY,
  batch_id TEXT NOT NULL REFERENCES seedling_batches(id),
  event_type TEXT NOT NULL,
  qty INT NOT NULL DEFAULT 0,
  reason TEXT,
  event_date DATE NOT NULL,
  logged_by TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Seedling Customers
CREATE TABLE IF NOT EXISTS seedling_customers (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  ic_number TEXT,
  company_reg TEXT,
  license_no TEXT,
  planting_location TEXT,
  planting_area_ha NUMERIC,
  customer_type TEXT DEFAULT 'smallholder',
  linked_customer_id TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Seedling Bookings
CREATE TABLE IF NOT EXISTS seedling_bookings (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  customer_id TEXT NOT NULL REFERENCES seedling_customers(id),
  batch_id TEXT NOT NULL REFERENCES seedling_batches(id),
  qty_booked INT NOT NULL,
  price_per_seedling NUMERIC NOT NULL,
  total_amount NUMERIC NOT NULL DEFAULT 0,
  total_paid NUMERIC NOT NULL DEFAULT 0,
  total_collected INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  booking_date DATE NOT NULL,
  expected_ready_date DATE,
  invoice_no TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Seedling Payments
CREATE TABLE IF NOT EXISTS seedling_payments (
  id TEXT PRIMARY KEY,
  booking_id TEXT REFERENCES seedling_bookings(id),
  collection_id TEXT,
  customer_id TEXT NOT NULL REFERENCES seedling_customers(id),
  amount NUMERIC NOT NULL,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  payment_date DATE NOT NULL,
  reference TEXT,
  slip_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Seedling Collections
CREATE TABLE IF NOT EXISTS seedling_collections (
  id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL DEFAULT 'tg_agribusiness',
  customer_id TEXT NOT NULL REFERENCES seedling_customers(id),
  booking_id TEXT REFERENCES seedling_bookings(id),
  batch_id TEXT NOT NULL REFERENCES seedling_batches(id),
  l31_serial_no TEXT,
  qty_collected INT NOT NULL,
  price_per_seedling NUMERIC NOT NULL,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  payment_received NUMERIC NOT NULL DEFAULT 0,
  collection_date DATE NOT NULL,
  collected_by TEXT,
  photo_url TEXT,
  l31_photo_url TEXT,
  invoice_no TEXT,
  transport_fee NUMERIC DEFAULT 0,
  notes TEXT,
  logged_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Add FK from payments.collection_id after collections table exists
ALTER TABLE seedling_payments
  ADD CONSTRAINT fk_seedling_payments_collection_id
  FOREIGN KEY (collection_id) REFERENCES seedling_collections(id);

-- ============================================================
-- PART 2: INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_seedling_batches_company ON seedling_batches(company_id);
CREATE INDEX IF NOT EXISTS idx_seedling_batches_status ON seedling_batches(status);
CREATE INDEX IF NOT EXISTS idx_seedling_batches_supplier ON seedling_batches(supplier_id);

CREATE INDEX IF NOT EXISTS idx_seedling_batch_events_batch ON seedling_batch_events(batch_id);
CREATE INDEX IF NOT EXISTS idx_seedling_batch_events_date ON seedling_batch_events(event_date);

CREATE INDEX IF NOT EXISTS idx_seedling_customers_company ON seedling_customers(company_id);
CREATE INDEX IF NOT EXISTS idx_seedling_customers_phone ON seedling_customers(phone) WHERE phone IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_seedling_bookings_customer ON seedling_bookings(customer_id);
CREATE INDEX IF NOT EXISTS idx_seedling_bookings_batch ON seedling_bookings(batch_id);
CREATE INDEX IF NOT EXISTS idx_seedling_bookings_status ON seedling_bookings(status);

CREATE INDEX IF NOT EXISTS idx_seedling_payments_booking ON seedling_payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_seedling_payments_customer ON seedling_payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_seedling_payments_collection ON seedling_payments(collection_id);

CREATE INDEX IF NOT EXISTS idx_seedling_collections_batch ON seedling_collections(batch_id);
CREATE INDEX IF NOT EXISTS idx_seedling_collections_booking ON seedling_collections(booking_id);
CREATE INDEX IF NOT EXISTS idx_seedling_collections_customer ON seedling_collections(customer_id);
CREATE INDEX IF NOT EXISTS idx_seedling_collections_date ON seedling_collections(collection_date);

-- ============================================================
-- PART 3: TRIGGERS (updated_at)
-- ============================================================

-- Reuse existing set_updated_at() function if it exists
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_seedling_suppliers_updated_at
  BEFORE UPDATE ON seedling_suppliers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_seedling_batches_updated_at
  BEFORE UPDATE ON seedling_batches
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_seedling_customers_updated_at
  BEFORE UPDATE ON seedling_customers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER set_seedling_bookings_updated_at
  BEFORE UPDATE ON seedling_bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- PART 4: ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE seedling_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE seedling_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE seedling_batch_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE seedling_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE seedling_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE seedling_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE seedling_collections ENABLE ROW LEVEL SECURITY;

-- seedling_suppliers
CREATE POLICY seedling_suppliers_anon_select ON seedling_suppliers FOR SELECT TO anon USING (true);
CREATE POLICY seedling_suppliers_anon_insert ON seedling_suppliers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_suppliers_anon_update ON seedling_suppliers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_suppliers_anon_delete ON seedling_suppliers FOR DELETE TO anon USING (true);
CREATE POLICY seedling_suppliers_auth_select ON seedling_suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_suppliers_auth_insert ON seedling_suppliers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_suppliers_auth_update ON seedling_suppliers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_suppliers_auth_delete ON seedling_suppliers FOR DELETE TO authenticated USING (true);

-- seedling_batches
CREATE POLICY seedling_batches_anon_select ON seedling_batches FOR SELECT TO anon USING (true);
CREATE POLICY seedling_batches_anon_insert ON seedling_batches FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_batches_anon_update ON seedling_batches FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_batches_anon_delete ON seedling_batches FOR DELETE TO anon USING (true);
CREATE POLICY seedling_batches_auth_select ON seedling_batches FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_batches_auth_insert ON seedling_batches FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_batches_auth_update ON seedling_batches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_batches_auth_delete ON seedling_batches FOR DELETE TO authenticated USING (true);

-- seedling_batch_events
CREATE POLICY seedling_batch_events_anon_select ON seedling_batch_events FOR SELECT TO anon USING (true);
CREATE POLICY seedling_batch_events_anon_insert ON seedling_batch_events FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_batch_events_anon_update ON seedling_batch_events FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_batch_events_anon_delete ON seedling_batch_events FOR DELETE TO anon USING (true);
CREATE POLICY seedling_batch_events_auth_select ON seedling_batch_events FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_batch_events_auth_insert ON seedling_batch_events FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_batch_events_auth_update ON seedling_batch_events FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_batch_events_auth_delete ON seedling_batch_events FOR DELETE TO authenticated USING (true);

-- seedling_customers
CREATE POLICY seedling_customers_anon_select ON seedling_customers FOR SELECT TO anon USING (true);
CREATE POLICY seedling_customers_anon_insert ON seedling_customers FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_customers_anon_update ON seedling_customers FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_customers_anon_delete ON seedling_customers FOR DELETE TO anon USING (true);
CREATE POLICY seedling_customers_auth_select ON seedling_customers FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_customers_auth_insert ON seedling_customers FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_customers_auth_update ON seedling_customers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_customers_auth_delete ON seedling_customers FOR DELETE TO authenticated USING (true);

-- seedling_bookings
CREATE POLICY seedling_bookings_anon_select ON seedling_bookings FOR SELECT TO anon USING (true);
CREATE POLICY seedling_bookings_anon_insert ON seedling_bookings FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_bookings_anon_update ON seedling_bookings FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_bookings_anon_delete ON seedling_bookings FOR DELETE TO anon USING (true);
CREATE POLICY seedling_bookings_auth_select ON seedling_bookings FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_bookings_auth_insert ON seedling_bookings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_bookings_auth_update ON seedling_bookings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_bookings_auth_delete ON seedling_bookings FOR DELETE TO authenticated USING (true);

-- seedling_payments
CREATE POLICY seedling_payments_anon_select ON seedling_payments FOR SELECT TO anon USING (true);
CREATE POLICY seedling_payments_anon_insert ON seedling_payments FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_payments_anon_update ON seedling_payments FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_payments_anon_delete ON seedling_payments FOR DELETE TO anon USING (true);
CREATE POLICY seedling_payments_auth_select ON seedling_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_payments_auth_insert ON seedling_payments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_payments_auth_update ON seedling_payments FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_payments_auth_delete ON seedling_payments FOR DELETE TO authenticated USING (true);

-- seedling_collections
CREATE POLICY seedling_collections_anon_select ON seedling_collections FOR SELECT TO anon USING (true);
CREATE POLICY seedling_collections_anon_insert ON seedling_collections FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY seedling_collections_anon_update ON seedling_collections FOR UPDATE TO anon USING (true) WITH CHECK (true);
CREATE POLICY seedling_collections_anon_delete ON seedling_collections FOR DELETE TO anon USING (true);
CREATE POLICY seedling_collections_auth_select ON seedling_collections FOR SELECT TO authenticated USING (true);
CREATE POLICY seedling_collections_auth_insert ON seedling_collections FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY seedling_collections_auth_update ON seedling_collections FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY seedling_collections_auth_delete ON seedling_collections FOR DELETE TO authenticated USING (true);

-- ============================================================
-- DONE
-- ============================================================
