-- Block Watchlist: add editable remedial-action note (2026-07-01)
ALTER TABLE block_issues ADD COLUMN IF NOT EXISTS remedial_action text;
