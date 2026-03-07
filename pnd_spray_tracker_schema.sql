-- =============================================
-- PND Spray Tracker — Phase 1: Database Schema
-- =============================================

-- TABLE 1: pnd_block_statuses
CREATE TABLE pnd_block_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status_name text NOT NULL UNIQUE,
  sort_order integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- TABLE 2: pnd_blocks
CREATE TABLE pnd_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_name text NOT NULL,
  date_planted date,
  status_id uuid REFERENCES pnd_block_statuses(id),
  remarks text,
  sort_order integer NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- TABLE 3: pnd_products
CREATE TABLE pnd_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_name text NOT NULL,
  product_type text NOT NULL CHECK (product_type IN ('fungicide', 'pesticide')),
  default_interval_days integer,
  sort_order integer NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- TABLE 4: pnd_spray_logs
CREATE TABLE pnd_spray_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id uuid NOT NULL REFERENCES pnd_blocks(id),
  product_id uuid NOT NULL REFERENCES pnd_products(id),
  date_completed date NOT NULL,
  next_spray_date date,
  notes text,
  logged_by text,
  created_at timestamptz DEFAULT now()
);

-- =============================================
-- VIEW: pnd_latest_sprays
-- Returns the single most recent spray log per block per product
-- =============================================
CREATE VIEW pnd_latest_sprays AS
SELECT
  block_id,
  product_id,
  date_completed,
  next_spray_date,
  notes,
  created_at
FROM (
  SELECT
    block_id,
    product_id,
    date_completed,
    next_spray_date,
    notes,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY block_id, product_id
      ORDER BY date_completed DESC, created_at DESC
    ) AS rn
  FROM pnd_spray_logs
) sub
WHERE rn = 1;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

-- pnd_block_statuses: public read
ALTER TABLE pnd_block_statuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read on pnd_block_statuses"
  ON pnd_block_statuses FOR SELECT
  TO anon, authenticated
  USING (true);

-- pnd_blocks: public read, authenticated update
ALTER TABLE pnd_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read on pnd_blocks"
  ON pnd_blocks FOR SELECT
  TO anon, authenticated
  USING (true);
CREATE POLICY "Allow authenticated update on pnd_blocks"
  ON pnd_blocks FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- pnd_products: public read
ALTER TABLE pnd_products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read on pnd_products"
  ON pnd_products FOR SELECT
  TO anon, authenticated
  USING (true);

-- pnd_spray_logs: public read, authenticated insert
ALTER TABLE pnd_spray_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read on pnd_spray_logs"
  ON pnd_spray_logs FOR SELECT
  TO anon, authenticated
  USING (true);
CREATE POLICY "Allow authenticated insert on pnd_spray_logs"
  ON pnd_spray_logs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- =============================================
-- SEED DATA
-- =============================================

-- Seed pnd_block_statuses
INSERT INTO pnd_block_statuses (status_name, sort_order) VALUES
  ('Growing', 1),
  ('Induced', 2),
  ('Suckers', 3),
  ('To Replant', 4),
  ('To Induce', 5),
  ('Tunggu Buah', 6),
  ('Abandoned (ATM)', 7);

-- Seed pnd_blocks
INSERT INTO pnd_blocks (block_name, date_planted, status_id, remarks, sort_order) VALUES
  ('A (Polibag)',  '2025-04-04', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 1),
  ('B (Polibag)',  '2025-04-04', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         NULL, 2),
  ('N1',           '2025-07-01', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 3),
  ('N2',           '2025-06-19', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 4),
  ('N3',           '2025-05-24', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 5),
  ('N4',           '2025-08-27', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 6),
  ('N5',           '2024-02-01', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Suckers'),         NULL, 7),
  ('N6',           '2025-01-07', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         NULL, 8),
  ('N7',           '2025-03-03', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         NULL, 9),
  ('N8',           NULL,         (SELECT id FROM pnd_block_statuses WHERE status_name = 'To Replant'),      NULL, 10),
  ('N9(a)',        '2025-01-17', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         NULL, 11),
  ('N9(b)',        '2025-01-18', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         'satu block lagi belum', 12),
  ('N10',          '2025-03-03', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         NULL, 13),
  ('N11',          '2025-04-22', (SELECT id FROM pnd_block_statuses WHERE status_name = 'To Induce'),       NULL, 14),
  ('N12',          '2023-03-15', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Abandoned (ATM)'), NULL, 15),
  ('N13',          '2023-03-15', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Suckers'),         NULL, 16),
  ('N14',          '2025-04-20', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Induced'),         NULL, 17),
  ('N15',          NULL,         (SELECT id FROM pnd_block_statuses WHERE status_name = 'To Replant'),      NULL, 18),
  ('N16',          '2024-02-19', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Suckers'),         NULL, 19),
  ('N18(a)',       '2025-08-15', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 20),
  ('N18(b)',       '2025-06-28', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 21),
  ('WLN1',         '2024-07-23', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Suckers'),         NULL, 22),
  ('WLN2',         '2024-09-09', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Suckers'),         NULL, 23),
  ('WLN 3(bb)',    '2024-10-09', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Suckers'),         NULL, 24),
  ('WLN 3(ab)',    '2024-10-12', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Tunggu Buah'),     NULL, 25),
  ('NGU 1',        '2025-09-30', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 26),
  ('NGU 2',        '2025-10-15', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 27),
  ('NGU 3',        '2025-12-09', (SELECT id FROM pnd_block_statuses WHERE status_name = 'Growing'),         NULL, 28);

-- Seed pnd_products
INSERT INTO pnd_products (product_name, product_type, default_interval_days, sort_order) VALUES
  ('Aluminium Fosetyl (Aliette/Linotyl)', 'fungicide', 120, 1),
  ('Mancozeb',                            'fungicide', 21,  2),
  ('Benomyl',                             'fungicide', NULL, 3),
  ('Copper Hydroxide (CampDP)',            'fungicide', NULL, 4);
