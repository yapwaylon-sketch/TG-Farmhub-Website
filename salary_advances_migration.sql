-- Salary Advances Migration
-- Tracks ad-hoc salary advances given mid-month, fully deducted at payroll time

CREATE TABLE IF NOT EXISTS salary_advances (
  id TEXT PRIMARY KEY,
  worker_id TEXT NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  date_given DATE NOT NULL,
  reason TEXT,
  period_id TEXT REFERENCES payroll_periods(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'deducted')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_salary_advances_worker ON salary_advances(worker_id);
CREATE INDEX idx_salary_advances_period ON salary_advances(period_id, status);
CREATE INDEX idx_salary_advances_worker_status ON salary_advances(worker_id, status);

-- RLS
ALTER TABLE salary_advances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for authenticated" ON salary_advances FOR ALL USING (true) WITH CHECK (true);
