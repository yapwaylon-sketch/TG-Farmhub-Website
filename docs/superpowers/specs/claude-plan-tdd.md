# Sales Invoicing — TDD / Verification Plan

## Testing Context

This is a vanilla JS/HTML application with no testing framework (no jest, no mocha, no build tools). All code is inline in `sales.html`. The "tests" here are **manual verification steps** and **database validation queries** to run after each implementation section. These serve as acceptance criteria.

Verification methods:
- **Browser console**: Run JS expressions to validate data/logic
- **Supabase SQL**: Run queries via Supabase SQL Editor to validate schema/data
- **UI checks**: Manual interaction to verify workflows
- **Print preview**: Check document rendering via browser print dialog

---

## 1. Database Migration

### Verify: Tables created correctly
```sql
-- Check all new tables exist with correct columns
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoices' ORDER BY ordinal_position;
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoice_items' ORDER BY ordinal_position;
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoice_orders' ORDER BY ordinal_position;
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_invoice_payments' ORDER BY ordinal_position;
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'sales_credit_notes' ORDER BY ordinal_position;
```

### Verify: Constraints
```sql
-- UNIQUE on invoice_orders.order_id
SELECT constraint_name FROM information_schema.table_constraints WHERE table_name = 'sales_invoice_orders' AND constraint_type = 'UNIQUE';

-- updated_at trigger on sales_invoices
SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'sales_invoices';
```

### Verify: RLS policies
```sql
SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'sales_invoice%' OR tablename = 'sales_credit_notes';
```

### Verify: Customer field migration
```sql
-- payment_terms_days populated correctly
SELECT name, payment_terms, payment_terms_days FROM sales_customers LIMIT 10;
-- credit customers should have 30, cash should have 0
SELECT payment_terms, payment_terms_days, count(*) FROM sales_customers GROUP BY payment_terms, payment_terms_days;
```

### Verify: sales_orders.invoice_id column
```sql
SELECT column_name FROM information_schema.columns WHERE table_name = 'sales_orders' AND column_name = 'invoice_id';
```

---

## 2. Data Loading

### Verify: All new data loads
- Open sales.html, open browser console
- Check: `invoices` array exists and is an array
- Check: `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes` arrays exist
- Check: `console.log(invoices.length, invoiceItems.length)` returns 0 (empty but loaded)

### Verify: Helper functions work
- Console: `typeof invoiceBalance === 'function'` → true
- Console: `typeof recalcInvoicePaymentStatus === 'function'` → true
- Console: `typeof isOrderInvoiced === 'function'` → true
- Console: `typeof getCustomerUninvoicedDOs === 'function'` → true
- Console: `typeof calcDueDate === 'function'` → true

---

## 3. Payment Terms + Customer Fields

### Verify: Customer modal shows new fields
- Open customer edit modal
- Check: Address textarea visible
- Check: SSM/BRN input visible
- Check: TIN input visible
- Check: IC Number input visible
- Check: Payment terms dropdown shows COD, Net 7, Net 14, Net 30, Net 60

### Verify: Save + display
- Edit a customer, set payment_terms_days to 14, add address
- Save → customer list shows "Net 14" badge instead of "Credit"/"Cash"
- Customer detail shows address, new fields

### Verify: Order creation uses new field
- Create order for customer with payment_terms_days=30 → should be delivery_order
- Create order for customer with payment_terms_days=0 → should be cash_sales

---

## 4. QB Cleanup + Dashboard Fix

### Verify: QB references removed
- Invoicing tab does not show "QuickBooks" or "QB" anywhere
- Payments tab DO section does not show "QB Invoice" column
- No modal asking for QB invoice number

### Verify: Dashboard updated
- Dashboard "Uninvoiced DO" card shows correct count (checks invoice_id, not qb_invoice_no)
- Dashboard "Total Owed" calculation includes outstanding invoices

---

## 5. Invoicing Tab — Create Invoice

### Verify: Customer dropdown
- Only shows customers with uninvoiced completed DOs
- Walk-in customers are excluded
- Selecting customer shows their DOs

### Verify: DO selection
- Checkboxes work, Select All works
- Billing summary aggregates products correctly (one line per product+price)
- DO numbers listed as reference

### Verify: Create Draft
- Click "Create Draft Invoice" → invoice created in DB
- Invoice appears in Invoice List with "Draft" status
- DOs now have invoice_id set (not null)
- Those DOs no longer appear in "uninvoiced" list
- Invoice number format: INV-YYMMDD-NNN

### Verify: Double-invoicing prevention
- Try to include an already-invoiced DO → should not appear in uninvoiced list
- DB: `SELECT order_id, count(*) FROM sales_invoice_orders GROUP BY order_id HAVING count(*) > 1` → should return 0 rows

---

## 6. Invoicing Tab — Invoice List

### Verify: Filters
- Status filter: Draft, Issued, Overdue, Partial, Paid, All
- Customer filter narrows results
- Date range filter works

### Verify: Status badges
- Draft = grey, Issued = blue, Overdue = red, Partial = gold, Paid = green

### Verify: Detail expansion
- Click invoice → shows items, linked DOs, payments, credit notes, action buttons

### Verify: Cancellation
- Cancel a draft invoice → DOs unlinked (invoice_id = null), junction records deleted
- Try to cancel invoice with payments → should be prevented

---

## 7. Invoice Document Generation

### Verify: A4 layout
- Print preview shows: logo, company name, reg no, TIN, MSIC, address
- Invoice number, date, due date, payment terms displayed
- Customer info shown (name, address if available)
- Items table with product descriptions, qty, unit price, amounts
- Reference line with DO numbers
- Totals section (subtotal, grand total, amount paid, balance due)
- Bank details box
- Signature block
- e-Invoice placeholder space

### Verify: PNG export
- Share button generates PNG
- WhatsApp sharing works (or clipboard fallback)

---

## 8. Invoice Approval Workflow

### Verify: Admin-only
- Login as non-admin → Approve button hidden on draft invoices
- Login as admin → Approve button visible

### Verify: Approval
- Click Approve → status changes to "Issued"
- approved_by and approved_at populated
- Invoice is now locked (no editing, no adding DOs)

---

## 9. Invoice Payment Recording

### Verify: Payment modal
- Shows invoice reference, outstanding balance
- Amount pre-filled with balance
- Method dropdown works (cash, bank, cheque)
- Reference field, slip upload work

### Verify: Payment saves
- Record payment → payment appears in invoice detail
- Invoice amount_paid updated
- Payment status changes: unpaid → partial (if partial) or paid (if full)

### Verify: Overpayment warning
- Enter amount > outstanding → warning shown (but allowed)

---

## 10. Credit Note System

### Verify: CN from return
- Create CN linked to a return → return_id populated, amount auto-filled

### Verify: CN standalone
- Create CN without return → manual amount entry

### Verify: CN validation
- Try CN amount > outstanding balance → should be prevented

### Verify: Balance recalculation
- After CN: invoice credit_total updated, payment_status recalculated
- Outstanding balance reduced by CN amount

### Verify: CN document
- A4 print shows: "CREDIT NOTE", CN number, original invoice reference, reason, amount

---

## 11. Payments Tab Split View

### Verify: Two sections visible
- "Cash Sales Payments" section shows CS orders
- "Invoice Payments" section shows invoices

### Verify: Invoice payments section
- Grouped by customer
- Shows invoice number, total, paid, balance, status
- Aging colors correct (current=green, 30d=gold, 60d=orange, 90d+=red)
- Record Payment button works

---

## 12. Statement of Account

### Verify: Generation
- Select customer + date range → statement generated
- Opening balance row shows correct brought-forward amount
- Transactions: invoices (debit), payments (credit), credit notes (credit)
- Running balance column is correct
- Aging summary at bottom (Current/30/60/90+)

### Verify: Document
- A4 print layout correct
- Bank details shown
- Payment reminder text present
- PNG export works

---

## 13. Dashboard Updates

### Verify: New cards
- "Outstanding Invoices" shows correct total
- "Overdue Invoices" shows correct count + amount (red if > 0)
- "Uninvoiced DOs" shows correct count
- Cards are clickable → navigate to Invoicing tab

---

## 14. Reports

### Verify: Invoice Register
- Shows all invoices with correct columns
- Filters work (date, customer, status)
- Totals row at bottom

### Verify: Aging Report
- Grouped by customer
- Age buckets calculated from due_date
- Color coding correct
- Grand totals at bottom
