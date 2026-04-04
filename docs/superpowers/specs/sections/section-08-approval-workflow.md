# Section 08: Invoice Approval Workflow

## Overview

This section implements the Draft to Issued transition for invoices. When an invoice is created (section 05), it starts as a "draft". An admin user must explicitly approve it, changing the status to "issued". Once issued, the invoice is locked -- no editing, no adding/removing DOs. Only issued invoices can receive payments (section 09) or credit notes (section 10).

**File to modify:** `sales.html`

**Depends on:**
- Section 01 (DB migration -- `sales_invoices` table with `status`, `approved_by`, `approved_at` columns)
- Section 02 (data loading -- `invoices` array loaded, `recalcInvoicePaymentStatus()` helper)
- Section 06 (invoice list -- detail expansion with action buttons, stub `invApproveInvoice()` function to replace)

**Blocks:** Section 09 (invoice payments -- only issued invoices can receive payments)

---

## Tests / Verification Steps

Run these after implementation to confirm correctness.

### Verify: Admin-only Approve Button

1. Log in as a **non-admin** user (supervisor or staff role).
2. Navigate to the Invoicing tab.
3. Expand a **draft** invoice's detail view.
4. The "Approve" button should **not be visible** in the action buttons row.
5. Log in as **admin** (Waylon / yapwaylon@gmail.com).
6. Expand the same draft invoice.
7. The "Approve" button **should be visible**.

### Verify: Approval Flow

1. As admin, click the "Approve" button on a draft invoice.
2. A confirmation modal appears (styled `confirmAction()`, not browser `confirm()`).
3. After confirming:
   - Invoice status changes from `draft` to `issued`.
   - The status badge on the invoice card updates to blue ("Issued").
   - `approved_by` is populated with the current user's ID.
   - `approved_at` is populated with the current timestamp.
4. SQL validation:
   ```sql
   SELECT id, status, approved_by, approved_at 
   FROM sales_invoices 
   WHERE status = 'issued';
   -- approved_by and approved_at should be non-null
   ```

### Verify: Invoice Locking After Approval

1. After approving an invoice, expand its detail view.
2. The "Approve" button should no longer appear (not draft anymore).
3. The "Add More DOs" button should no longer appear (only shown for drafts).
4. The invoice date, payment terms, and notes should not be editable.
5. The "Record Payment" and "Add Credit Note" buttons should now be visible (they are only shown for issued invoices, as defined in section 06).

### Verify: Non-Draft Invoice Cannot Be Approved

1. Expand an already-issued invoice -- no "Approve" button should appear.
2. Expand a cancelled invoice -- no "Approve" button should appear.
3. Expand a paid invoice -- no "Approve" button should appear.

---

## Implementation Details

### The `invApproveInvoice(invoiceId)` Function

Section 06 created a stub for `invApproveInvoice(invoiceId)`. Replace the stub with the full implementation.

**Logic flow:**

1. **Role check**: Verify `currentUser && currentUser.role === 'admin'`. If not admin, show `notify('Admin access required', 'warning')` and return. This is the same pattern used elsewhere in `sales.html` (e.g., order deletion at line 2642).

2. **Find invoice**: Look up the invoice in the `invoices` array by `invoiceId`. If not found, show error and return.

3. **Status check**: Verify `inv.status === 'draft'`. If the invoice is not a draft, show `notify('Only draft invoices can be approved', 'warning')` and return.

4. **Confirmation**: Use `confirmAction('Approve Invoice', 'Approve ' + invoiceId + ' and issue to customer? This locks the invoice for editing.')`. Wait for user confirmation.

5. **Database update**: Use `sbUpdateWithLock()` on the `sales_invoices` table to set:
   - `status`: `'issued'`
   - `approved_by`: `currentUser.id`
   - `approved_at`: `new Date().toISOString()`

   The `sbUpdateWithLock()` pattern is used (defined in `shared.js`) because approval is a critical state transition that must guard against concurrent modifications (e.g., another user cancelling the same draft simultaneously). It checks `updated_at` to detect conflicts.

6. **Update local state**: Update the invoice object in the `invoices` array with the new status, `approved_by`, and `approved_at` values.

7. **Re-render**: Call `invRenderList()` (from section 06) to refresh the invoice list with the updated status badge and action buttons.

8. **Notification**: Show `notify('Invoice ' + invoiceId + ' approved and issued', 'success')`.

**Function signature:**

```javascript
async function invApproveInvoice(invoiceId) {
  // 1. Admin role check
  // 2. Find invoice in local array
  // 3. Verify status === 'draft'
  // 4. confirmAction() for user confirmation
  // 5. sbUpdateWithLock() to set status='issued', approved_by, approved_at
  // 6. Update local invoices array
  // 7. invRenderList()
  // 8. notify success
}
```

### Approve Button Visibility in Section 06 Detail View

Section 06 already defines the visibility rule for the Approve button in the action buttons row of the expanded invoice detail. Confirm that this rule is correctly implemented:

- The Approve button HTML should only be rendered when **both** conditions are true:
  1. `inv.status === 'draft'`
  2. `currentUser && currentUser.role === 'admin'`

The conditional rendering in the detail expansion template should look like:

```javascript
// Inside the action buttons row of the expanded detail
(inv.status === 'draft' && currentUser && currentUser.role === 'admin'
  ? '<button onclick="invApproveInvoice(\'' + esc(inv.id) + '\')" class="btn btn-green">Approve</button>'
  : '')
```

If section 06 used a different pattern for the stub, update it to match this logic.

### Locking Behavior for Issued Invoices

The locking behavior is enforced at the UI level. After approval, the following buttons/actions are hidden or disabled for issued (non-draft) invoices. This is already partially handled by section 06's conditional rendering of action buttons:

- **"Add More DOs" button**: Only rendered when `inv.status === 'draft'`. After approval, it disappears.
- **"Cancel" button**: Section 06's `invCancelInvoice()` already blocks cancellation if payments exist. For issued invoices without payments, cancellation is still allowed (status check allows both draft and issued). No change needed here.
- **Edit fields**: If section 06 included any inline editing for invoice date, payment terms, or notes, those should be disabled/hidden when `inv.status !== 'draft'`.

The positive side: once issued, the "Record Payment" and "Add Credit Note" buttons become visible (sections 09 and 10 check for `inv.status === 'issued'` or `payment_status !== 'paid'`).

### Button Styling

The Approve button should use the green button style consistent with the project's primary action buttons:

- Use class `btn btn-green` or equivalent inline style: `background:var(--green); color:#fff; border:none; padding:8px 16px; border-radius:6px; cursor:pointer; font-weight:600;`
- The button label should be "Approve" (simple, concise).
- On hover, standard hover effect (slight brightness increase).

### Error Handling

- If the `sbUpdateWithLock()` call fails due to a conflict (another user modified the invoice), it will show its built-in conflict notification. The function should handle the error gracefully and not update local state.
- If the database call fails for any other reason, `sbQuery`/`sbMutate` will handle the error notification via the shared error handling pattern. Ensure the function uses try/catch or checks the result.

### Interaction with `currentUser` Variable

The `currentUser` variable is declared at the module level in `sales.html` (around line 958 as `var currentUser = null;`). It is populated during the session initialization flow. The role check pattern `currentUser.role === 'admin'` is already used in two other places in `sales.html`:
- Line 1845: Admin-only delete button for cancelled/completed orders
- Line 2642: Admin access check for another operation

Follow the same pattern for consistency.

---

## Key Files

- **`sales.html`** -- Replace the `invApproveInvoice()` stub (created in section 06) with the full implementation. Verify the Approve button visibility condition in the invoice detail expansion template.

## Actual Implementation Notes

- **Stub replaced:** 1-line stub → 22-line async function with all 8 steps from plan
- **Optimistic locking:** Uses `sbUpdateWithLock()` with `inv.updated_at` check, syncs updated_at after success
- **Button wiring confirmed:** Section 06 already has correct visibility conditions (draft + admin)
- **No additional files modified** — purely a function replacement in sales.html
- **Code review:** Clean pass, no actionable issues found

## Edge Cases

- **Non-admin clicks Approve somehow** (e.g., DOM manipulation): The JS role check at the top of `invApproveInvoice()` prevents the action. Server-side checks are not available (RLS allows all writes), so the JS check is the security boundary. This is acceptable for this project's trust model (PIN-based auth, farm internal use).
- **Concurrent approval and cancellation**: `sbUpdateWithLock()` guards against this by checking `updated_at`. If another user cancelled the invoice between page load and approval click, the lock check fails and the user is notified.
- **Invoice already approved**: If a user somehow triggers approval on an already-issued invoice (stale UI), the status check at step 3 prevents the update and shows a warning.
- **No currentUser**: If session has expired, `currentUser` will be null. The role check `currentUser && currentUser.role === 'admin'` safely handles this, and the session guard in `shared.js` would have already redirected to login.
