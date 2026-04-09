# Code Review: Section 03 - Payment Terms + Customer Fields Update

**Reviewer:** Claude Opus 4.6 (automated)
**Date:** 2026-04-04
**File:** `sales.html`
**Verdict:** PASS -- no critical or important issues found.

---

## Plan Alignment

All 8 items from the section plan have been implemented:

| Plan Item | Status | Notes |
|-----------|--------|-------|
| 1. Helper functions (`paymentTermsLabel`, `paymentTermsBadgeClass`) | Done | Implemented at line 2861-2869 |
| 2. Customer modal HTML (dropdown + SSM/BRN/TIN/IC) | Done | Lines 316-340 |
| 3. Customer modal JS (scOpenModal + scSaveCustomer) | Done | Lines 2886-2958 |
| 4. Customer list table badge + filter | Done | Lines 2780-2843 |
| 5. Customer detail view | Done | Lines 3089-3098 |
| 6. Order creation doc_type assignment | Done | Line 5190 |
| 7. A4 document terms display | Done | Line 6169 |
| 8. Walk-in customer auto-create | Done | Line 5034 |

No planned items are missing. No unplanned changes were introduced.

---

## Code Quality Assessment

### Old References Eliminated -- VERIFIED

A full grep of `sales.html` for `payment_terms === 'credit'` and `payment_terms === 'cash'` returns zero matches. All string comparisons have been replaced with numeric `payment_terms_days` checks. The companion files (`delivery.html`, `display-sales.html`, `guide-sales.html`, `guide-sales-cn.html`) have no payment_terms references to update.

### Backward Compatibility -- VERIFIED

The `scSaveCustomer()` function writes both fields:
- `payment_terms: paymentTermsDays > 0 ? 'credit' : 'cash'` (old column, backward compat)
- `payment_terms_days: paymentTermsDays` (new column)

The walk-in auto-create also writes both: `payment_terms: 'cash', payment_terms_days: 0`.

### XSS Safety -- VERIFIED

- `paymentTermsLabel(days)` returns either the hardcoded string `'COD'` or `'Net ' + d` where `d` is the output of `parseInt(..., 10)`. An integer concatenation cannot produce HTML injection. Safe.
- `paymentTermsBadgeClass(days)` returns either `'do'` or `'cs'`. Safe.
- New customer detail fields (`ssm_brn`, `tin`, `ic_number`) are all wrapped in `esc()` calls at lines 3095-3097. Safe.
- The customer modal reads values via `.value` from `<input>` elements and writes them to the database. On display, they pass through `esc()`. Safe.

### Null Handling -- VERIFIED

- `scSaveCustomer()` stores `ssmBrn || null`, `tin || null`, `icNumber || null` -- empty strings become null in the DB.
- `scOpenModal()` reads with `c.ssm_brn || ''` fallback for edit mode, and clears to `''` for add mode.
- `scRenderDetail()` uses `if (c.ssm_brn)` guards -- null/empty fields are hidden. Correct.

### Filter Logic -- VERIFIED

The filter uses two-way categorical filtering (COD vs Credit) rather than individual day values, matching the plan's recommended approach. The logic is correct:
- `scFilterPayment === 'cod'` hides customers where `payment_terms_days > 0`
- `scFilterPayment === 'credit'` hides customers where `payment_terms_days === 0`

### Default Value -- NOTED

The add-mode default is `'30'` (Net 30), which differs from the plan's suggestion of either `'0'` (COD) or `'30'`. Net 30 is a sensible default for a wholesale-focused business. This is a reasonable design choice.

---

## Suggestions (Nice to Have)

1. **`paymentTermsLabel` handles unexpected values gracefully** -- If a customer has a non-standard value like `payment_terms_days = 45`, the function returns "Net 45" which is readable. Good defensive design.

2. **No input validation on new text fields** -- The SSM/BRN, TIN, and IC fields accept freeform text with no format validation. This is acceptable for now since Malaysian business registration formats vary, and the plan does not specify validation. Could be added later if needed.

---

## Summary

Clean implementation that faithfully follows the section plan. All old string-based payment_terms comparisons have been replaced. New fields are properly read, written, and escaped. Backward compatibility is maintained. No issues requiring changes before merge.
