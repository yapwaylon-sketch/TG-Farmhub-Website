-- Sales Module Migration
-- 6 tables: sales_customers, sales_products, sales_orders, sales_order_items, sales_payments, sales_returns

-- ============================================================
-- 1. sales_customers
-- ============================================================
CREATE TABLE IF NOT EXISTS sales_customers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  address TEXT,
  type TEXT DEFAULT 'retail',
  channel TEXT DEFAULT 'whatsapp_delivery',
  payment_terms TEXT NOT NULL DEFAULT 'cash',
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Partial unique index on phone (only when phone is not null)
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_customers_phone
  ON sales_customers (phone) WHERE phone IS NOT NULL;

-- ============================================================
-- 2. sales_products
-- ============================================================
CREATE TABLE IF NOT EXISTS sales_products (
  id TEXT PRIMARY KEY,
  variety_id UUID REFERENCES crop_varieties(id),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT 'kg',
  default_price NUMERIC NOT NULL DEFAULT 0,
  box_quantity INT,
  is_active BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. sales_orders
-- ============================================================
CREATE TABLE IF NOT EXISTS sales_orders (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES sales_customers(id),
  order_date DATE NOT NULL DEFAULT CURRENT_DATE,
  delivery_date DATE,
  delivery_time TEXT,
  channel TEXT,
  fulfillment TEXT NOT NULL DEFAULT 'delivery',
  status TEXT NOT NULL DEFAULT 'pending',
  doc_type TEXT NOT NULL DEFAULT 'cash_sales',
  doc_number TEXT UNIQUE,
  driver_id TEXT REFERENCES workers(id),
  qb_invoice_no TEXT,
  qb_invoiced_at DATE,
  subtotal NUMERIC DEFAULT 0,
  return_total NUMERIC DEFAULT 0,
  grand_total NUMERIC DEFAULT 0,
  amount_paid NUMERIC DEFAULT 0,
  payment_status TEXT DEFAULT 'unpaid',
  prep_photo_url TEXT,
  delivery_photo_url TEXT,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_orders_customer_id ON sales_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_orders_status ON sales_orders(status);
CREATE INDEX IF NOT EXISTS idx_sales_orders_order_date ON sales_orders(order_date);
CREATE INDEX IF NOT EXISTS idx_sales_orders_delivery_date ON sales_orders(delivery_date);
CREATE INDEX IF NOT EXISTS idx_sales_orders_doc_type ON sales_orders(doc_type);
CREATE INDEX IF NOT EXISTS idx_sales_orders_payment_status ON sales_orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_sales_orders_driver_id ON sales_orders(driver_id);

-- ============================================================
-- 4. sales_order_items
-- ============================================================
CREATE TABLE IF NOT EXISTS sales_order_items (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES sales_products(id),
  index_min INT CHECK (index_min >= 0 AND index_min <= 5),
  index_max INT CHECK (index_max >= 0 AND index_max <= 5),
  quantity NUMERIC NOT NULL,
  unit_price NUMERIC NOT NULL,
  line_total NUMERIC NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_order_items_order_id ON sales_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_sales_order_items_product_id ON sales_order_items(product_id);

-- ============================================================
-- 5. sales_payments
-- ============================================================
CREATE TABLE IF NOT EXISTS sales_payments (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES sales_orders(id),
  amount NUMERIC NOT NULL,
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  method TEXT NOT NULL DEFAULT 'cash',
  reference TEXT,
  notes TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_payments_order_id ON sales_payments(order_id);

-- ============================================================
-- 6. sales_returns
-- ============================================================
CREATE TABLE IF NOT EXISTS sales_returns (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES sales_orders(id),
  item_id TEXT REFERENCES sales_order_items(id),
  quantity NUMERIC NOT NULL,
  amount NUMERIC NOT NULL,
  reason TEXT,
  resolution TEXT NOT NULL CHECK (resolution IN ('deduct', 'refund', 'debit_note')),
  debit_note_no TEXT,
  debit_note_used_on TEXT REFERENCES sales_orders(id),
  photo_url TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_returns_order_id ON sales_returns(order_id);

-- ============================================================
-- RLS Policies (idempotent)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE sales_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_returns ENABLE ROW LEVEL SECURITY;

-- Helper: create policy if not exists
DO $$
DECLARE
  tbl TEXT;
  op TEXT;
  role_name TEXT;
  pol_name TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY[
    'sales_customers','sales_products','sales_orders',
    'sales_order_items','sales_payments','sales_returns'
  ]) LOOP
    FOR op IN SELECT unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) LOOP
      FOR role_name IN SELECT unnest(ARRAY['anon','authenticated']) LOOP
        pol_name := tbl || '_' || lower(op) || '_' || role_name;
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE schemaname = 'public' AND tablename = tbl AND policyname = pol_name
        ) THEN
          IF op = 'SELECT' THEN
            EXECUTE format(
              'CREATE POLICY %I ON %I FOR SELECT TO %I USING (true)',
              pol_name, tbl, role_name
            );
          ELSIF op = 'INSERT' THEN
            EXECUTE format(
              'CREATE POLICY %I ON %I FOR INSERT TO %I WITH CHECK (true)',
              pol_name, tbl, role_name
            );
          ELSIF op = 'UPDATE' THEN
            EXECUTE format(
              'CREATE POLICY %I ON %I FOR UPDATE TO %I USING (true) WITH CHECK (true)',
              pol_name, tbl, role_name
            );
          ELSIF op = 'DELETE' THEN
            EXECUTE format(
              'CREATE POLICY %I ON %I FOR DELETE TO %I USING (true)',
              pol_name, tbl, role_name
            );
          END IF;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- Triggers: updated_at (idempotent)
-- ============================================================

DO $$
DECLARE
  tbl TEXT;
  trig_name TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY['sales_customers','sales_products','sales_orders']) LOOP
    trig_name := 'tr_' || tbl || '_updated_at';
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = trig_name
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
        trig_name, tbl
      );
    END IF;
  END LOOP;
END $$;
