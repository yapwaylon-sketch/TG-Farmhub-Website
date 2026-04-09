const { Client } = require('pg');

const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false },
});

async function migrate() {
  await client.connect();
  console.log('Connected to database.');

  try {
    // 1. Create sales_customer_branches table
    await client.query(`
      CREATE TABLE IF NOT EXISTS sales_customer_branches (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL REFERENCES sales_customers(id),
        name TEXT NOT NULL,
        address TEXT,
        contact_person TEXT,
        phone TEXT,
        is_default BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        company_id TEXT NOT NULL REFERENCES companies(id),
        created_at TIMESTAMPTZ DEFAULT now(),
        updated_at TIMESTAMPTZ DEFAULT now()
      );
    `);
    console.log('✓ Created table: sales_customer_branches');

    // 2. Index on (customer_id, is_active)
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_sales_customer_branches_customer_active
        ON sales_customer_branches (customer_id, is_active);
    `);
    console.log('✓ Created index: idx_sales_customer_branches_customer_active');

    // 3. Enable RLS
    await client.query(`ALTER TABLE sales_customer_branches ENABLE ROW LEVEL SECURITY;`);
    console.log('✓ Enabled RLS on sales_customer_branches');

    // Permissive policies for anon role
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'anon_select_sales_customer_branches'
        ) THEN
          CREATE POLICY anon_select_sales_customer_branches
            ON sales_customer_branches FOR SELECT TO anon USING (true);
        END IF;
      END$$;
    `);
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'anon_insert_sales_customer_branches'
        ) THEN
          CREATE POLICY anon_insert_sales_customer_branches
            ON sales_customer_branches FOR INSERT TO anon WITH CHECK (true);
        END IF;
      END$$;
    `);
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'anon_update_sales_customer_branches'
        ) THEN
          CREATE POLICY anon_update_sales_customer_branches
            ON sales_customer_branches FOR UPDATE TO anon USING (true) WITH CHECK (true);
        END IF;
      END$$;
    `);
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'anon_delete_sales_customer_branches'
        ) THEN
          CREATE POLICY anon_delete_sales_customer_branches
            ON sales_customer_branches FOR DELETE TO anon USING (true);
        END IF;
      END$$;
    `);
    console.log('✓ Created RLS policies for anon role');

    // Permissive policies for authenticated role
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'authenticated_select_sales_customer_branches'
        ) THEN
          CREATE POLICY authenticated_select_sales_customer_branches
            ON sales_customer_branches FOR SELECT TO authenticated USING (true);
        END IF;
      END$$;
    `);
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'authenticated_insert_sales_customer_branches'
        ) THEN
          CREATE POLICY authenticated_insert_sales_customer_branches
            ON sales_customer_branches FOR INSERT TO authenticated WITH CHECK (true);
        END IF;
      END$$;
    `);
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'authenticated_update_sales_customer_branches'
        ) THEN
          CREATE POLICY authenticated_update_sales_customer_branches
            ON sales_customer_branches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
        END IF;
      END$$;
    `);
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies
          WHERE tablename = 'sales_customer_branches' AND policyname = 'authenticated_delete_sales_customer_branches'
        ) THEN
          CREATE POLICY authenticated_delete_sales_customer_branches
            ON sales_customer_branches FOR DELETE TO authenticated USING (true);
        END IF;
      END$$;
    `);
    console.log('✓ Created RLS policies for authenticated role');

    // 4. Add new columns to sales_customers
    const customerColumns = [
      { name: 'registration_name', def: 'TEXT' },
      { name: 'email',             def: 'TEXT' },
      { name: 'secondary_phone',   def: 'TEXT' },
      { name: 'credit_limit',      def: 'NUMERIC' },
      { name: 'currency',          def: "TEXT DEFAULT 'MYR'" },
    ];

    for (const col of customerColumns) {
      await client.query(`
        DO $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'sales_customers' AND column_name = '${col.name}'
          ) THEN
            ALTER TABLE sales_customers ADD COLUMN ${col.name} ${col.def};
          END IF;
        END$$;
      `);
      console.log(`✓ Column sales_customers.${col.name} ensured`);
    }

    // 5. Add branch_id to sales_orders
    await client.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'sales_orders' AND column_name = 'branch_id'
        ) THEN
          ALTER TABLE sales_orders
            ADD COLUMN branch_id TEXT REFERENCES sales_customer_branches(id);
        END IF;
      END$$;
    `);
    console.log('✓ Column sales_orders.branch_id ensured');

    console.log('\nMigration complete — all steps succeeded.');
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

migrate();
