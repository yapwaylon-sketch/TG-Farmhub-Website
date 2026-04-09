# Review Integration Notes

## Integrating (10 items)

1. **DN/CN relationship** — Add section clarifying existing debit notes coexist with new credit notes. DNs are order-level (returns), CNs are invoice-level. When a return with resolution=debit_note exists for a DO in an invoice, the CN can link to it via return_id.

2. **UNIQUE constraint on invoice_orders.order_id** — Yes, critical. A DO can only belong to one invoice. Also add WHERE invoice_id IS NULL check when updating orders.

3. **updated_at trigger** — Yes, add to migration. Follow existing pattern.

4. **Product aggregation ambiguity** — Fix: use "one line per unique product+price combination". Drop weighted average mention.

5. **CN amount validation** — Add: CN amount cannot exceed invoice outstanding (grand_total - credit_total - amount_paid).

6. **Cancellation cascade** — Add explicit logic: unlink DOs (set invoice_id=null), delete junction records, prevent cancel if payments exist, void/delete CNs if no payments.

7. **Opening balance in Statement** — Add: calculate sum of all transactions before date_from as opening balance row.

8. **Admin approval enforcement** — Add: JS check `currentUser.role === 'admin'` to show/enable Approve button.

9. **Dashboard Total Owed update** — Move early: update uninvoiced DO check to use `!o.invoice_id` instead of `!o.qb_invoice_no` as part of QB cleanup.

10. **Existing QB-invoiced DOs** — Since no QB invoices were ever created (user confirmed), all existing qb_invoice_no values should be null. No migration needed. But add a note to handle the edge case.

## NOT Integrating (5 items)

1. **Recalculate button for stale totals** — Overkill for now. The recalc pattern is consistent with existing codebase (sales_orders.amount_paid works the same way). Can add later if issues arise.

2. **Date-based filtering on loadAllData** — Not yet. Invoice data won't be large for months. Can optimize when needed.

3. **80mm thermal version of invoices** — Invoices are formal A4 documents. No thermal version needed. Explicitly stated in plan.

4. **Bulk approve/batch payment** — Nice to have, not in scope for Phase 1. Can add after core invoicing works.

5. **Guide pages update** — Out of scope. Guides can be updated separately after invoicing is stable.

## Minor fixes applied

- II prefix: use simple `II-{timestamp}` since users never reference these IDs
- MSIC code: add to invoice letterhead
- Credit note document: single copy (not 2 like DO)
- QB-invoiced DOs: all null (confirmed by user), no special handling needed
- Walk-in customers: filter out of invoice creation dropdown (payment_terms_days must be > 0)
