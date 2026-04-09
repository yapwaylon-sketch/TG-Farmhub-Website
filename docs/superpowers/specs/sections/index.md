<!-- PROJECT_CONFIG
runtime: javascript-vanilla
test_command: echo "Manual verification - see claude-plan-tdd.md"
END_PROJECT_CONFIG -->

<!-- SECTION_MANIFEST
section-01-db-migration
section-02-data-loading
section-03-payment-terms-customer
section-04-qb-cleanup
section-05-create-invoice
section-06-invoice-list
section-07-invoice-document
section-08-approval-workflow
section-09-invoice-payments
section-10-credit-notes
section-11-payments-tab
section-12-statement-of-account
section-13-dashboard
section-14-reports
END_MANIFEST -->

# Implementation Sections Index

## Dependency Graph

| Section | Depends On | Blocks | Parallelizable |
|---------|------------|--------|----------------|
| section-01-db-migration | - | all | No |
| section-02-data-loading | 01 | 05-14 | No |
| section-03-payment-terms-customer | 01 | 05 | Yes (with 02) |
| section-04-qb-cleanup | 01 | 05 | Yes (with 02, 03) |
| section-05-create-invoice | 02, 03, 04 | 06-14 | No |
| section-06-invoice-list | 05 | 07, 08, 09, 10 | No |
| section-07-invoice-document | 06 | - | Yes (with 08) |
| section-08-approval-workflow | 06 | 09 | Yes (with 07) |
| section-09-invoice-payments | 08 | 11 | No |
| section-10-credit-notes | 06 | 11, 12 | Yes (with 09) |
| section-11-payments-tab | 09, 10 | - | No |
| section-12-statement-of-account | 09, 10 | - | Yes (with 11) |
| section-13-dashboard | 05 | - | Yes (with 11, 12) |
| section-14-reports | 09, 10 | - | Yes (with 11, 12, 13) |

## Execution Order

1. **Batch 1:** section-01-db-migration (foundation — must be first)
2. **Batch 2:** section-02-data-loading, section-03-payment-terms-customer, section-04-qb-cleanup (parallel after 01)
3. **Batch 3:** section-05-create-invoice (requires 02, 03, 04)
4. **Batch 4:** section-06-invoice-list (requires 05)
5. **Batch 5:** section-07-invoice-document, section-08-approval-workflow (parallel after 06)
6. **Batch 6:** section-09-invoice-payments, section-10-credit-notes (parallel after 08/06)
7. **Batch 7:** section-11-payments-tab, section-12-statement-of-account, section-13-dashboard, section-14-reports (parallel — final batch)

## Section Summaries

### section-01-db-migration
SQL migration script: create 5 new tables (sales_invoices, sales_invoice_items, sales_invoice_orders, sales_invoice_payments, sales_credit_notes), alter sales_customers (add ssm_brn, tin, ic_number, payment_terms_days), alter sales_orders (add invoice_id), add RLS policies, triggers, constraints, indexes. Run payment_terms data migration.

### section-02-data-loading
Extend loadAllData() in sales.html to load 5 new tables. Add global arrays (invoices, invoiceItems, invoiceOrders, invoicePayments, creditNotes). Add helper functions: invoiceBalance(), recalcInvoicePaymentStatus(), isOrderInvoiced(), getCustomerUninvoicedDOs(), calcDueDate(), isInvoiceOverdue().

### section-03-payment-terms-customer
Update customer edit modal with new fields (address prominence, SSM/BRN, TIN, IC, payment terms dropdown). Update customer list badges (Net 30/COD instead of Credit/Cash). Update customer detail view. Change doc_type assignment to use payment_terms_days > 0 for DO.

### section-04-qb-cleanup
Remove QB modal HTML, invSaveInvoice(), QB-related variables. Remove QB column from payments tab. Update dashboard uninvoiced DO check from qb_invoice_no to invoice_id. Update Total Owed calculation. Stub invoicing tab with placeholder.

### section-05-create-invoice
Build invoice creation UI in the Invoicing tab. Customer dropdown (filtered — no walk-ins, only those with uninvoiced DOs). DO selection with checkboxes. Product aggregation preview (one line per product+price). Invoice date, payment terms, notes fields. Create Draft Invoice button with full DB insert flow.

### section-06-invoice-list
Invoice list in Invoicing tab. Filter bar (customer, status, date range). Summary cards (Outstanding, Overdue, This Month). Invoice cards with status badges. Click to expand detail (items, DOs, payments, CNs). Action buttons. Cancellation logic with cascade.

### section-07-invoice-document
A4 invoice document generation (generateInvoiceA4). Company letterhead with logo, reg no, TIN, MSIC, address. Customer info, items table, DO references, totals, bank details, e-Invoice placeholder, signature block. Print + PNG export.

### section-08-approval-workflow
Draft → Issued transition. Admin-only Approve button (JS role check). Sets approved_by, approved_at. Locks invoice after approval. Only issued invoices can receive payments.

### section-09-invoice-payments
Invoice payment modal. Pre-filled outstanding balance. Method dropdown (cash/bank/cheque). Bank slip upload. Save → update amount_paid, recalc payment_status. Payment history in invoice detail.

### section-10-credit-notes
CN modal (from return or standalone). Amount validation (cannot exceed outstanding). Save → update credit_total, recalc payment_status. CN/DN relationship (coexist). A4 credit note document generation. Print + PNG export.

### section-11-payments-tab
Split renderPayments() into two sections: CS Payments (existing, unchanged) + Invoice Payments (new). Invoice payments grouped by customer, expandable, with filters, summaries, aging colors.

### section-12-statement-of-account
A4 statement generation. Company letterhead, customer info, date range selector. Opening balance calculation. Transaction table (invoices=debit, payments=credit, CNs=credit) with running balance. Aging summary (Current/30/60/90+). Bank details + payment reminder. Print + PNG export.

### section-13-dashboard
Replace QB-related dashboard cards. Add: Outstanding Invoices (total amount), Overdue Invoices (count+amount, red), Uninvoiced DOs (count). Update Total Owed to include outstanding invoices. Clickable cards → navigate to Invoicing tab.

### section-14-reports
Invoice Register report (all invoices, filterable, with totals). Aging Report (by customer, 30/60/90 buckets, color coded). Update payment summary report to include invoice payments.
