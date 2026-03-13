-- Salary Advance Categories Migration
-- Adds category field to salary_advances and cash_handed to payroll_entries

-- Add category to salary_advances
ALTER TABLE salary_advances ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Salary Advance';
ALTER TABLE salary_advances DROP CONSTRAINT IF EXISTS salary_advances_category_check;
ALTER TABLE salary_advances ADD CONSTRAINT salary_advances_category_check CHECK (category IN ('Canteen', 'Cigarettes', 'Salary Advance', 'Overpayment'));

-- Add cash_handed to payroll_entries (actual cash given to worker)
ALTER TABLE payroll_entries ADD COLUMN IF NOT EXISTS cash_handed NUMERIC DEFAULT 0;

-- Index for category lookups
CREATE INDEX IF NOT EXISTS idx_salary_advances_category ON salary_advances(category, status);
