-- Block Watchlist: issues + monitoring updates (2026-07-01)
CREATE TABLE IF NOT EXISTS block_issues (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id      uuid NOT NULL REFERENCES pnd_blocks(id) ON DELETE CASCADE,
  title         text NOT NULL,
  description   text,
  category      text NOT NULL DEFAULT 'Other',
  severity      text NOT NULL DEFAULT 'watch' CHECK (severity IN ('critical','watch')),
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','resolved')),
  opened_at     timestamptz NOT NULL DEFAULT now(),
  opened_by     text,
  resolved_at   timestamptz,
  resolved_note text,
  company_id    text NOT NULL DEFAULT 'tg_agribusiness',
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_block_issues_block  ON block_issues(block_id);
CREATE INDEX IF NOT EXISTS idx_block_issues_status ON block_issues(status);

CREATE TABLE IF NOT EXISTS block_issue_updates (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id   uuid NOT NULL REFERENCES block_issues(id) ON DELETE CASCADE,
  note       text NOT NULL DEFAULT '',
  photos     jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text
);
CREATE INDEX IF NOT EXISTS idx_block_issue_updates_issue ON block_issue_updates(issue_id);

ALTER TABLE block_issues        ENABLE ROW LEVEL SECURITY;
ALTER TABLE block_issue_updates ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY block_issues_anon        ON block_issues        FOR ALL TO anon          USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY block_issues_auth        ON block_issues        FOR ALL TO authenticated USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY block_issue_updates_anon ON block_issue_updates FOR ALL TO anon          USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY block_issue_updates_auth ON block_issue_updates FOR ALL TO authenticated USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
