# Code Review: Section 04 - QB Cleanup + Dashboard Fix

**Reviewer:** Claude Opus 4.6  
**Date:** 2026-04-04  
**Status:** CHANGES REQUIRED (1 critical issue)

---

## What Was Done Well

- All `qb_invoice_no`, `qb_invoiced_at`, and `QuickBooks` string references have been fully removed from active code. Grep confirms zero matches.
- The three deleted functions (`invSaveInvoice`, `invOpenInvoiceModal`, `invToggleHistory`) leave no dangling `onclick` references -- the HTML that called them was also removed.
- The `inv-modal` HTML block is cleanly deleted.
- All 10 reusable helper functions are preserved as specified: `invSelectedDOs`, `invToggleCustomer`, `invToggleDO`, `invSelectAllCustomer`, `invUpdateSelectAll`, `invUpdateButtons`, `invRenderBillingSummary`, `invBuildSummaryText`, `invCopySummary`, `invPrintSummary`.
- Dashboard filter correctly changed from `!o.qb_invoice_no && o.status !== 'cancelled'` to `!o.invoice_id && o.status === 'completed'`.
- Payments tab DO table correctly drops the QB Invoice column and switches the status badge from `o.qb_invoice_number` to `o.invoice_id`.
- `renderInvoicing()` stub correctly filters with `!o.invoice_id && o.status === 'completed'`.
- Section B replaced with clean placeholder ("Invoice list coming soon").
- Invoicing subtitle updated from "QuickBooks invoice management" to "Invoice management".

---

## Critical Issues (Must Fix)

### 1. `invUpdateButtons()` references deleted button ID `inv-mark-btn`

**File:** `sales.html`, line 4157

The `invUpdateButtons()` function still looks for `document.getElementById('inv-mark-btn')` and sets its text to `'Mark as Invoiced (...)'`. However, the button was renamed to `inv-create-btn` in `renderInvoicing()` (line 4115), and the button is now permanently disabled with hardcoded `disabled` attribute.

This means when a user checks/unchecks DO checkboxes, `invUpdateButtons()` silently fails to find the button (returns null, so the `if (btn)` guard prevents a crash), but the button text and disabled state never update. The billing summary still renders via `invRenderBillingSummary()` (called at the end of the function), so selection feedback partially works -- but the button count badge is frozen at whatever was rendered initially.

**Fix required:** Update `invUpdateButtons()` to reference `inv-create-btn` and update the button text to `'Create Invoice (...)'`. The button should become enabled when `selectedCount > 0` (so it is ready for section 05 to wire up the onclick handler).

```javascript
function invUpdateButtons() {
  var selectedCount = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; }).length;
  var btn = document.getElementById('inv-create-btn');
  if (btn) {
    btn.textContent = 'Create Invoice (' + selectedCount + ' selected)';
    btn.disabled = selectedCount === 0;
    btn.style.opacity = selectedCount === 0 ? '0.5' : '';
    btn.style.cursor = selectedCount === 0 ? 'not-allowed' : '';
  }
  invRenderBillingSummary();
}
```

---

## Important Issues (Should Fix)

None.

---

## Suggestions (Nice to Have)

None. The diff is clean and minimal. All changes align with the section plan.

---

## Plan Alignment

| Plan Step | Status | Notes |
|-----------|--------|-------|
| Step 1: Remove QB Modal HTML | Done | Clean removal |
| Step 2: Remove `invSaveInvoice()` | Done | |
| Step 3: Remove `invOpenInvoiceModal()` | Done | |
| Step 4: Remove `invToggleHistory()` | Done | |
| Step 5: Update Invoicing subtitle | Done | |
| Step 6: Rewrite `renderInvoicing()` stub | Done | Uses `invoice_id` and `status === 'completed'` as planned |
| Step 7: Update Payments tab DO section | Done | Column removed, badge updated |
| Step 8: Update Dashboard filter | Done | Both field ref and status filter corrected |
| Step 9: Clean up remaining QB references | Done | Grep confirms zero remaining matches |
| Helper functions preserved | Done | All 10 helpers intact |

**Overall:** The implementation matches the plan precisely. The one critical issue (`invUpdateButtons` stale ID reference) is a missed downstream dependency of renaming the button from `inv-mark-btn` to `inv-create-btn`. Easy fix.

---

## Verdict

**CHANGES REQUIRED** -- Fix the `invUpdateButtons()` function to reference the new button ID `inv-create-btn` and update the button label text. Once that single fix is applied, this section is ready to commit.
