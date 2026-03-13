-- Google OAuth: Add email column to users table
-- Run date: 2026-03-14

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE public.users SET email = 'yapwaylon@gmail.com' WHERE id = 'U001';
