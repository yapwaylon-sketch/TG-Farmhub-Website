# Section 06 Code Review Interview

## Review Summary
Approved with 2 important fixes applied.

## Auto-fixes Applied
1. Invoice cancellation now uses `sbUpdateWithLock()` to prevent race condition with concurrent approve
2. Approve button now checks `currentUser.role === 'admin'` before rendering

## Items Let Go
- Native date inputs vs calOpen() — consistent with date inputs elsewhere in invoicing section
- Linked DOs doc numbers not escaped — doc numbers are system-generated, safe
- Print button visibility condition simplification — works correctly as-is
- grand_total = subtotal in AddMoreDOs — matches current behavior, future tax/discount can be added later

## Decision
Proceed to commit with fixes applied.
