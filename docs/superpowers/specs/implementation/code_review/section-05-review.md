# Code Review: Section 05 — Create Invoice (Invoicing Tab)

**Reviewer:** Claude Opus 4.6 (Senior Code Reviewer)
**Date:** 2026-04-04
**Files reviewed:** `sales.html` (diff + live code at lines 4095-4576)
**Plan:** `docs/superpowers/specs/sections/section-05-create-invoice.md`

---

## Summary

The implementation faithfully follows the section plan. The DB insert flow is correctly ordered (invoice -> items -> junction -> update orders), product aggregation now groups by `product_id + unit_price`, local array updates match inserts, and error handling with button loading states is properly applied. The code is clean, consistent with existing patterns, and ready for use.

---

## What Was Done Well

1. **DB insert order is correct.** Invoice first (step 5), then items (step 6), then junction (step 7), then order updates (step 8). This ensures FK constraints are satisfied at each step.

2. **Race condition guard is present.** The `sales_orders` update at line 4557 uses `.is('invoice_id', null)` as specified in the plan, preventing double-invoicing if two users create invoices concurrently.

3. **Product aggregation key change is consistent.** All three functions (`invRenderBillingSummary`, `invBuildSummaryText`, `invPrintSummary`) were updated from `product_id`-only grouping to `product_id + '_' + unitPrice.toFixed(2)`. The average-price calculation was correctly replaced with exact unit price display.

4. **Product name snapshot** follows the plan pattern -- variety prefix + product name, frozen at invoice creation time.

5. **Local array updates** (lines 4563-4565) correctly push results from all three insert operations and update the local `orders` array inline during the order update loop.

6. **Button loading states** are applied correctly with `btnLoading(btn, true)` before the async flow and restored in both the success path and the catch block.

7. **Invoice details section** visibility is toggled both in the initial render (line 4117) and in `invUpdateButtons()` (line 4187), keeping UI state in sync with selection.

---

## Issues Found

### Important (should fix)

**I-1: Invoice date input has no `onchange` handler for due date recalculation.**

The payment terms `<select>` has `onchange="invUpdateDueDate()"` (line 4126), but the invoice date `<input type="date">` at line 4120 does not. If the user changes the invoice date, the due date display will not update until they also change the payment terms.

**File:** `sales.html`, line 4120
**Current:**
```html
<input type="date" id="inv-date" value="' + todayStr() + '" style="width:100%;">
```
**Fix:** Add `onchange="invUpdateDueDate()"` to the date input.

---

**I-2: `line_total` aggregation may accumulate floating-point rounding errors.**

At line 4501, `line_total` is summed from `parseFloat(item.line_total)` across multiple order items. Since each `item.line_total` is already `quantity * unit_price` (presumably rounded), summing them is fine. However, the plan states `line_total = quantity * unit_price` for each invoice item. The current code sums the original order-level line totals, which is actually more accurate for aggregation. This is a beneficial deviation -- no fix needed, but worth noting: if a product appears across 3 DOs with qty 5 each at RM 1.23, the aggregated line_total will be the sum of the 3 individual line_totals (which may each be pre-rounded), rather than `15 * 1.23`. The difference is negligible but technically present.

---

### Suggestions (nice to have)

**S-1: Sequential `dbNextId('II')` calls could be batched.**

Lines 4531-4533 call `await dbNextId('II')` in a `for` loop, making N sequential network requests for N product lines. For small N (typically under 10 products), this is fine. If performance becomes a concern, these could be batched into a single call that generates multiple IDs, but this is not worth changing now.

---

**S-2: No validation that all selected DOs belong to the same customer.**

The code derives `customerId` from the first selected DO (line 4476-4477). Since the UI groups DOs by customer and only allows selection within one customer context, this is safe in practice. However, a defensive check confirming all selected DOs share the same `customer_id` would catch any future UI bugs. Low priority.

---

**S-3: The `payment_terms` code format differs slightly from the plan's mapping.**

The plan (section 5, step 3) specifies codes like `'7days'`, `'14days'`, `'30days'`, `'60days'`. The code builds `paymentTermsDays + 'days'` which produces the same strings. This is correct and matches what `calcDueDate()` expects in its `daysMap`. No issue -- just confirming alignment.

---

## Plan Alignment

| Plan Requirement | Status | Notes |
|---|---|---|
| Customer dropdown filters (no walkin, has uninvoiced DOs) | Assumed present from prior code | Not in this diff -- pre-existing |
| DO selection with checkboxes + Select All | Assumed present from prior code | Not in this diff -- pre-existing |
| Billing summary groups by product+price | DONE | All 3 functions updated |
| Invoice details form (date, terms, notes) | DONE | Inline in renderInvoicing() |
| Due date auto-calculated | DONE | Via calcDueDate(), but see I-1 |
| Payment terms defaults from customer | DONE | Lines 4122-4125 |
| Create Draft Invoice button with loading | DONE | btnLoading pattern applied |
| DB insert order: invoice -> items -> junction -> orders | DONE | Steps 5-8 in correct order |
| Race condition guard (WHERE invoice_id IS NULL) | DONE | Line 4557 |
| Product name snapshot | DONE | Variety + name frozen at creation |
| Local array updates | DONE | Lines 4563-4565 |
| Error handling (try/catch, null check on sbQuery) | DONE | Each insert checked, catch block present |
| Clear selection + re-render on success | DONE | Lines 4568-4571 |
| No XSS issues | VERIFIED | All user-visible text uses esc() |

---

## Verdict

**PASS with 1 important fix required.**

The implementation is well-structured, follows the plan accurately, and handles error cases properly. The only actionable issue is I-1 (missing `onchange` on the date input), which is a straightforward one-line fix. The suggestions are minor and can be addressed later if desired.
