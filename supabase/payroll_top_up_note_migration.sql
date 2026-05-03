-- Migration: add top_up_note column to payroll_entries
-- Purpose: append-only audit text on each entry capturing rate-change top-ups
-- Format: "+RM <amount> on DD/MM/YYYY (rate <old> → <new>)" — multiple lines if entry is bumped more than once
-- Nullable. NULL = no top-up has ever been applied. UI hides the surface entirely when NULL.

ALTER TABLE payroll_entries
  ADD COLUMN IF NOT EXISTS top_up_note TEXT NULL;
