-- =============================================
-- RLS Audit Migration: Enable Row Level Security
-- on all tables that currently lack policies.
-- Migration date: 2026-03-09
-- Run in Supabase SQL Editor (Dashboard > SQL Editor)
--
-- What this migration does:
--   Enables RLS and creates permissive CRUD policies
--   (SELECT, INSERT, UPDATE, DELETE) for anon + authenticated
--   roles on 17 tables across the inventory and workers modules.
--
-- Why open policies (USING true / WITH CHECK true):
--   The app uses Supabase anon key auth with no per-user
--   database-level authentication. All access control is
--   enforced at the application layer. RLS is enabled so
--   Supabase does not silently block requests when the
--   default "deny all" RLS posture is active.
--
-- Idempotency:
--   Every policy creation is wrapped in an IF NOT EXISTS
--   check against pg_policies, so this migration is safe
--   to run multiple times without errors.
--
-- Tables already covered by previous migrations (no changes):
--   crops, crop_varieties, crop_statuses, block_crops (Phase 4)
--   pnd_block_product_overrides, pnd_jobs (Phase 2B)
--   pnd_block_statuses, pnd_blocks, pnd_products, pnd_spray_logs (Phase 1)
-- =============================================


-- =============================================
-- SECTION 1: INVENTORY MODULE TABLES
-- =============================================

-- ----- 1a. users -----
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'Allow public read on users'
  ) THEN
    CREATE POLICY "Allow public read on users"
      ON users FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'Allow anon insert on users'
  ) THEN
    CREATE POLICY "Allow anon insert on users"
      ON users FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'Allow anon update on users'
  ) THEN
    CREATE POLICY "Allow anon update on users"
      ON users FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users' AND policyname = 'Allow anon delete on users'
  ) THEN
    CREATE POLICY "Allow anon delete on users"
      ON users FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 1b. products -----
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'products' AND policyname = 'Allow public read on products'
  ) THEN
    CREATE POLICY "Allow public read on products"
      ON products FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'products' AND policyname = 'Allow anon insert on products'
  ) THEN
    CREATE POLICY "Allow anon insert on products"
      ON products FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'products' AND policyname = 'Allow anon update on products'
  ) THEN
    CREATE POLICY "Allow anon update on products"
      ON products FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'products' AND policyname = 'Allow anon delete on products'
  ) THEN
    CREATE POLICY "Allow anon delete on products"
      ON products FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 1c. suppliers -----
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'suppliers' AND policyname = 'Allow public read on suppliers'
  ) THEN
    CREATE POLICY "Allow public read on suppliers"
      ON suppliers FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'suppliers' AND policyname = 'Allow anon insert on suppliers'
  ) THEN
    CREATE POLICY "Allow anon insert on suppliers"
      ON suppliers FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'suppliers' AND policyname = 'Allow anon update on suppliers'
  ) THEN
    CREATE POLICY "Allow anon update on suppliers"
      ON suppliers FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'suppliers' AND policyname = 'Allow anon delete on suppliers'
  ) THEN
    CREATE POLICY "Allow anon delete on suppliers"
      ON suppliers FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 1d. transactions -----
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Allow public read on transactions'
  ) THEN
    CREATE POLICY "Allow public read on transactions"
      ON transactions FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Allow anon insert on transactions'
  ) THEN
    CREATE POLICY "Allow anon insert on transactions"
      ON transactions FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Allow anon update on transactions'
  ) THEN
    CREATE POLICY "Allow anon update on transactions"
      ON transactions FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'transactions' AND policyname = 'Allow anon delete on transactions'
  ) THEN
    CREATE POLICY "Allow anon delete on transactions"
      ON transactions FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- =============================================
-- SECTION 2: WORKERS MODULE TABLES
-- =============================================

-- ----- 2a. workers -----
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'workers' AND policyname = 'Allow public read on workers'
  ) THEN
    CREATE POLICY "Allow public read on workers"
      ON workers FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'workers' AND policyname = 'Allow anon insert on workers'
  ) THEN
    CREATE POLICY "Allow anon insert on workers"
      ON workers FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'workers' AND policyname = 'Allow anon update on workers'
  ) THEN
    CREATE POLICY "Allow anon update on workers"
      ON workers FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'workers' AND policyname = 'Allow anon delete on workers'
  ) THEN
    CREATE POLICY "Allow anon delete on workers"
      ON workers FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2b. audit_log -----
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_log' AND policyname = 'Allow public read on audit_log'
  ) THEN
    CREATE POLICY "Allow public read on audit_log"
      ON audit_log FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_log' AND policyname = 'Allow anon insert on audit_log'
  ) THEN
    CREATE POLICY "Allow anon insert on audit_log"
      ON audit_log FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_log' AND policyname = 'Allow anon update on audit_log'
  ) THEN
    CREATE POLICY "Allow anon update on audit_log"
      ON audit_log FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'audit_log' AND policyname = 'Allow anon delete on audit_log'
  ) THEN
    CREATE POLICY "Allow anon delete on audit_log"
      ON audit_log FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2c. task_types -----
ALTER TABLE task_types ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_types' AND policyname = 'Allow public read on task_types'
  ) THEN
    CREATE POLICY "Allow public read on task_types"
      ON task_types FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_types' AND policyname = 'Allow anon insert on task_types'
  ) THEN
    CREATE POLICY "Allow anon insert on task_types"
      ON task_types FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_types' AND policyname = 'Allow anon update on task_types'
  ) THEN
    CREATE POLICY "Allow anon update on task_types"
      ON task_types FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_types' AND policyname = 'Allow anon delete on task_types'
  ) THEN
    CREATE POLICY "Allow anon delete on task_types"
      ON task_types FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2d. responsibility_types -----
ALTER TABLE responsibility_types ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'responsibility_types' AND policyname = 'Allow public read on responsibility_types'
  ) THEN
    CREATE POLICY "Allow public read on responsibility_types"
      ON responsibility_types FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'responsibility_types' AND policyname = 'Allow anon insert on responsibility_types'
  ) THEN
    CREATE POLICY "Allow anon insert on responsibility_types"
      ON responsibility_types FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'responsibility_types' AND policyname = 'Allow anon update on responsibility_types'
  ) THEN
    CREATE POLICY "Allow anon update on responsibility_types"
      ON responsibility_types FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'responsibility_types' AND policyname = 'Allow anon delete on responsibility_types'
  ) THEN
    CREATE POLICY "Allow anon delete on responsibility_types"
      ON responsibility_types FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2e. payroll_periods -----
ALTER TABLE payroll_periods ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_periods' AND policyname = 'Allow public read on payroll_periods'
  ) THEN
    CREATE POLICY "Allow public read on payroll_periods"
      ON payroll_periods FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_periods' AND policyname = 'Allow anon insert on payroll_periods'
  ) THEN
    CREATE POLICY "Allow anon insert on payroll_periods"
      ON payroll_periods FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_periods' AND policyname = 'Allow anon update on payroll_periods'
  ) THEN
    CREATE POLICY "Allow anon update on payroll_periods"
      ON payroll_periods FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_periods' AND policyname = 'Allow anon delete on payroll_periods'
  ) THEN
    CREATE POLICY "Allow anon delete on payroll_periods"
      ON payroll_periods FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2f. worker_roles -----
ALTER TABLE worker_roles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_roles' AND policyname = 'Allow public read on worker_roles'
  ) THEN
    CREATE POLICY "Allow public read on worker_roles"
      ON worker_roles FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_roles' AND policyname = 'Allow anon insert on worker_roles'
  ) THEN
    CREATE POLICY "Allow anon insert on worker_roles"
      ON worker_roles FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_roles' AND policyname = 'Allow anon update on worker_roles'
  ) THEN
    CREATE POLICY "Allow anon update on worker_roles"
      ON worker_roles FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_roles' AND policyname = 'Allow anon delete on worker_roles'
  ) THEN
    CREATE POLICY "Allow anon delete on worker_roles"
      ON worker_roles FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2g. task_units -----
ALTER TABLE task_units ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_units' AND policyname = 'Allow public read on task_units'
  ) THEN
    CREATE POLICY "Allow public read on task_units"
      ON task_units FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_units' AND policyname = 'Allow anon insert on task_units'
  ) THEN
    CREATE POLICY "Allow anon insert on task_units"
      ON task_units FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_units' AND policyname = 'Allow anon update on task_units'
  ) THEN
    CREATE POLICY "Allow anon update on task_units"
      ON task_units FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_units' AND policyname = 'Allow anon delete on task_units'
  ) THEN
    CREATE POLICY "Allow anon delete on task_units"
      ON task_units FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2h. worker_loans -----
ALTER TABLE worker_loans ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_loans' AND policyname = 'Allow public read on worker_loans'
  ) THEN
    CREATE POLICY "Allow public read on worker_loans"
      ON worker_loans FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_loans' AND policyname = 'Allow anon insert on worker_loans'
  ) THEN
    CREATE POLICY "Allow anon insert on worker_loans"
      ON worker_loans FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_loans' AND policyname = 'Allow anon update on worker_loans'
  ) THEN
    CREATE POLICY "Allow anon update on worker_loans"
      ON worker_loans FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'worker_loans' AND policyname = 'Allow anon delete on worker_loans'
  ) THEN
    CREATE POLICY "Allow anon delete on worker_loans"
      ON worker_loans FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2i. loan_repayments -----
ALTER TABLE loan_repayments ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'loan_repayments' AND policyname = 'Allow public read on loan_repayments'
  ) THEN
    CREATE POLICY "Allow public read on loan_repayments"
      ON loan_repayments FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'loan_repayments' AND policyname = 'Allow anon insert on loan_repayments'
  ) THEN
    CREATE POLICY "Allow anon insert on loan_repayments"
      ON loan_repayments FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'loan_repayments' AND policyname = 'Allow anon update on loan_repayments'
  ) THEN
    CREATE POLICY "Allow anon update on loan_repayments"
      ON loan_repayments FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'loan_repayments' AND policyname = 'Allow anon delete on loan_repayments'
  ) THEN
    CREATE POLICY "Allow anon delete on loan_repayments"
      ON loan_repayments FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2j. payroll_entries -----
ALTER TABLE payroll_entries ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_entries' AND policyname = 'Allow public read on payroll_entries'
  ) THEN
    CREATE POLICY "Allow public read on payroll_entries"
      ON payroll_entries FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_entries' AND policyname = 'Allow anon insert on payroll_entries'
  ) THEN
    CREATE POLICY "Allow anon insert on payroll_entries"
      ON payroll_entries FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_entries' AND policyname = 'Allow anon update on payroll_entries'
  ) THEN
    CREATE POLICY "Allow anon update on payroll_entries"
      ON payroll_entries FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_entries' AND policyname = 'Allow anon delete on payroll_entries'
  ) THEN
    CREATE POLICY "Allow anon delete on payroll_entries"
      ON payroll_entries FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2k. task_entries -----
ALTER TABLE task_entries ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_entries' AND policyname = 'Allow public read on task_entries'
  ) THEN
    CREATE POLICY "Allow public read on task_entries"
      ON task_entries FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_entries' AND policyname = 'Allow anon insert on task_entries'
  ) THEN
    CREATE POLICY "Allow anon insert on task_entries"
      ON task_entries FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_entries' AND policyname = 'Allow anon update on task_entries'
  ) THEN
    CREATE POLICY "Allow anon update on task_entries"
      ON task_entries FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'task_entries' AND policyname = 'Allow anon delete on task_entries'
  ) THEN
    CREATE POLICY "Allow anon delete on task_entries"
      ON task_entries FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2l. payroll_responsibilities -----
ALTER TABLE payroll_responsibilities ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_responsibilities' AND policyname = 'Allow public read on payroll_responsibilities'
  ) THEN
    CREATE POLICY "Allow public read on payroll_responsibilities"
      ON payroll_responsibilities FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_responsibilities' AND policyname = 'Allow anon insert on payroll_responsibilities'
  ) THEN
    CREATE POLICY "Allow anon insert on payroll_responsibilities"
      ON payroll_responsibilities FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_responsibilities' AND policyname = 'Allow anon update on payroll_responsibilities'
  ) THEN
    CREATE POLICY "Allow anon update on payroll_responsibilities"
      ON payroll_responsibilities FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'payroll_responsibilities' AND policyname = 'Allow anon delete on payroll_responsibilities'
  ) THEN
    CREATE POLICY "Allow anon delete on payroll_responsibilities"
      ON payroll_responsibilities FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- ----- 2m. employment_stints -----
ALTER TABLE employment_stints ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'employment_stints' AND policyname = 'Allow public read on employment_stints'
  ) THEN
    CREATE POLICY "Allow public read on employment_stints"
      ON employment_stints FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'employment_stints' AND policyname = 'Allow anon insert on employment_stints'
  ) THEN
    CREATE POLICY "Allow anon insert on employment_stints"
      ON employment_stints FOR INSERT
      TO anon, authenticated
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'employment_stints' AND policyname = 'Allow anon update on employment_stints'
  ) THEN
    CREATE POLICY "Allow anon update on employment_stints"
      ON employment_stints FOR UPDATE
      TO anon, authenticated
      USING (true)
      WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'employment_stints' AND policyname = 'Allow anon delete on employment_stints'
  ) THEN
    CREATE POLICY "Allow anon delete on employment_stints"
      ON employment_stints FOR DELETE
      TO anon, authenticated
      USING (true);
  END IF;
END;
$$;


-- =============================================
-- VERIFICATION QUERIES
-- Uncomment and run after migration to confirm.
-- =============================================

-- 1. Confirm RLS is enabled on all 17 tables
-- SELECT tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
--   AND tablename IN (
--     'users', 'products', 'suppliers', 'transactions',
--     'workers', 'audit_log', 'task_types', 'responsibility_types',
--     'payroll_periods', 'worker_roles', 'task_units',
--     'worker_loans', 'loan_repayments', 'payroll_entries',
--     'task_entries', 'payroll_responsibilities', 'employment_stints'
--   )
-- ORDER BY tablename;
-- Expected: rowsecurity = true for all 17

-- 2. Confirm 4 policies per table (SELECT, INSERT, UPDATE, DELETE)
-- SELECT tablename, COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE tablename IN (
--     'users', 'products', 'suppliers', 'transactions',
--     'workers', 'audit_log', 'task_types', 'responsibility_types',
--     'payroll_periods', 'worker_roles', 'task_units',
--     'worker_loans', 'loan_repayments', 'payroll_entries',
--     'task_entries', 'payroll_responsibilities', 'employment_stints'
--   )
-- GROUP BY tablename
-- ORDER BY tablename;
-- Expected: 4 policies each

-- 3. Full policy detail
-- SELECT tablename, policyname, cmd, roles
-- FROM pg_policies
-- WHERE tablename IN (
--     'users', 'products', 'suppliers', 'transactions',
--     'workers', 'audit_log', 'task_types', 'responsibility_types',
--     'payroll_periods', 'worker_roles', 'task_units',
--     'worker_loans', 'loan_repayments', 'payroll_entries',
--     'task_entries', 'payroll_responsibilities', 'employment_stints'
--   )
-- ORDER BY tablename, cmd;
