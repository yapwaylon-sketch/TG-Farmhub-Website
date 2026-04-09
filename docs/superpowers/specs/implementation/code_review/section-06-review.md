# Code Review: Section 06 - Invoice List

**Reviewer:** Code Review Agent
**Date:** 2026-04-04
**Status:** APPROVED with minor issues

---

## Summary

Section 06 implements the invoice list view in the Invoicing tab with filtering, summary cards, expandable invoice cards, cancellation, and add-more-DOs functionality. The implementation is well-structured and closely follows the section plan. Code quality is high overall -- it uses the established project patterns (esc() for XSS, confirmAction for confirmation, sbQuery for mutations, local array sync after DB writes).

---

## What Was Done Well

- **Filter architecture**: `invRenderList()` is correctly extracted as a standalone function that re-renders only the list container, preserving the Create Invoice section state as specified.
- **XSS protection**: All user-supplied values (customer names, invoice IDs, DO numbers, payment references, CN reasons) are consistently passed through `esc()`.
- **Summary card logic**: Correctly excludes cancelled invoices from all three summary metrics.
- **Display status cascade**: `invGetDisplayStatus()` correctly checks cancelled and draft first, then overdue (which depends on `isInvoiceOverdue()`), then paid/partial, falling back to issued. This matches the spec's precedence requirements.
- **Cancellation cascade**: Properly blocks on existing payments, uses `confirmAction()` (not browser confirm), unlinks DOs, deletes junction/items/CNs, and updates local arrays.
- **Add More DOs**: Correctly re-aggregates items by deleting old and re-inserting, uses the same product snapshot logic as invoice creation, and guards against non-draft invoices.
- **event.stopPropagation()**: Correctly prevents card collapse when clicking action buttons.
- **Stub functions**: All four stub functions are properly defined with informative notify messages.

---

## Issues

### Important (should fix)

**1. Missing `sbUpdateWithLock()` on invoice cancellation**

The plan explicitly states: "When cancelling, use `sbUpdateWithLock()` on the invoice record to prevent race conditions with another user approving the same invoice simultaneously." The implementation uses a plain `sbQuery(sb.from('sales_invoices').update(...))` instead.

File: `sales.html` (diff line 360)
```javascript
// Current:
await sbQuery(sb.from('sales_invoices').update({ status: 'cancelled' }).eq('id', invoiceId).select());

// Should be:
await sbUpdateWithLock('sales_invoices', invoiceId, { status: 'cancelled' }, inv.updated_at);
```

This matters because two admins could simultaneously try to cancel and approve the same invoice, leading to an inconsistent state (cancelled with linked DOs partially re-processed).

**2. Approve button not gated by admin role**

The plan states: "Hide for non-admin users (`currentUser.role !== 'admin'`)." The implementation shows the Approve button for all users when status is draft, without checking `currentUser.role`. The rest of the codebase gates admin-only actions with role checks (e.g., lines 1904, 2701 in sales.html).

File: `sales.html` (diff line 211)
```javascript
// Current:
if (inv.status === 'draft') {
  html += '<button ... invApproveInvoice(...)>Approve</button>';

// Should add role check:
if (inv.status === 'draft' && currentUser && currentUser.role === 'admin') {
```

**3. Print/Share button visibility condition is off**

The plan says: "Show for issued/partial/paid invoices." The implementation checks `inv.status === 'issued' || inv.payment_status === 'partial' || inv.payment_status === 'paid'`. This has two problems:
- An issued invoice with `payment_status === 'unpaid'` would show Print only via the `status === 'issued'` branch, which happens to be correct, but the logic is fragile.
- A draft invoice that somehow has `payment_status === 'partial'` (unlikely but defensive) would incorrectly show Print.

A cleaner condition:
```javascript
if (inv.status === 'issued' && inv.payment_status !== undefined) {
```
Or more explicitly:
```javascript
if (inv.status === 'issued' || inv.payment_status === 'paid') {
```
Since only issued invoices can have partial/paid payment status, `inv.status === 'issued'` alone would cover all three cases. The current code works in practice but the intent is muddled.

**4. Record Payment / Credit Note buttons only show for `status === 'issued'`**

If an issued invoice has `payment_status === 'partial'`, users should still be able to record additional payments or credit notes. Since `isInvoiceOverdue()` only returns true for `status === 'issued'`, and `invGetDisplayStatus()` returns 'overdue' in that case, the `inv.status` is still 'issued' in the DB. So this actually works correctly. However, the code does not explicitly handle the case where an invoice is partially paid -- it relies on the fact that `inv.status` remains 'issued' even when partially paid. Worth adding a comment to clarify this implicit dependency.

### Suggestions (nice to have)

**5. Date filter inputs use native `<input type="date">` instead of custom calendar picker**

The plan says to use the project's custom `calOpen()` calendar picker for date inputs. The implementation uses native HTML date inputs. This is a minor visual inconsistency with other date fields in the sales module that use the custom dark-themed calendar. Not a functional issue, but the native date picker will render with the OS's default light-theme styling, which may clash with the dark theme.

**6. Customer filter is rebuilt on every `invRenderList()` call**

The plan states: "Populate on data load, not on every render (per project convention to prevent state reset)." The customer dropdown is rebuilt from the `invoices` array on every render. Because the selected value is tracked in `invFilterCustomer` and explicitly set via the `selected` attribute, there is no state-reset bug here. But it does unnecessary work and deviates from the convention. Low priority since the invoice count will be small.

**7. Linked DOs list does not escape content**

In the Linked DOs section (diff line 178-183), the `doList` entries are built from `o.doc_number` and `fmtDateNice()` output but not wrapped in `esc()`. Doc numbers are system-generated (e.g., "DO-260403-001") so XSS risk is negligible, but for consistency with the rest of the code's defensive approach, wrapping in `esc()` would be prudent.

```javascript
// Current:
return o ? (o.doc_number || o.id) + ' (' + fmtDateNice(o.order_date) + ')' : io.order_id;

// Safer:
return o ? esc(o.doc_number || o.id) + ' (' + fmtDateNice(o.order_date) + ')' : esc(io.order_id);
```

**8. `invAddMoreDOs` total calculation ignores tax/discount**

The re-aggregation sets `grand_total = subtotal` directly. If invoices later support tax or discounts, this will silently drop them. Acceptable for now since the spec does not mention tax, but worth a TODO comment.

**9. No "Cancelled" option in status filter dropdown initially**

The plan says cancelled invoices should show "only when 'All' status filter is selected or a dedicated 'Cancelled' filter option." The implementation does include 'cancelled' in the dropdown array, which is good. This is just a note that it matches the plan's alternative option.

---

## Plan Alignment

| Plan Requirement | Status | Notes |
|---|---|---|
| Filter bar (customer, status, date range) | Done | Date uses native input instead of calOpen() |
| Summary cards (Outstanding, Overdue, This Month) | Done | Correctly excludes cancelled |
| Status badge colors | Done | All 6 statuses covered with correct colors |
| Detail expansion (items, DOs, payments, CNs) | Done | Chevron rotation, toggle pattern matches existing code |
| Action buttons with status gating | Mostly done | Missing admin role check on Approve |
| Cancel with cascade | Done | Missing sbUpdateWithLock |
| Add More DOs with re-aggregation | Done | Clean implementation |
| Stub functions for sections 07-10 | Done | All four defined |
| Empty state | Done | Differentiates "no invoices" from "no matches" |
| Sort newest first | Done | Falls back to invoice_date if no created_at |
| invRenderList() extracted | Done | Correctly only re-renders list section |

---

## Verdict

**APPROVED** -- the implementation is solid and closely follows the plan. The two "Important" issues (sbUpdateWithLock on cancel, admin role gate on Approve) should be fixed before merging. The suggestions are minor and can be addressed later if desired.
