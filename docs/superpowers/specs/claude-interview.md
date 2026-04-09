# Sales Invoicing — Interview Transcript

## Q1: Invoice frequency per customer
**Q:** When a customer has multiple DOs in a month and you create an invoice, should the system prevent adding more DOs to that invoice later? Or should you be able to create multiple invoices per customer per month?

**A:** Flexible — both options. Can create multiple invoices per customer, and can also add DOs to existing draft invoices.

## Q2: Annual revenue (e-Invoice timeline)
**Q:** What is TG Agro Fruits' approximate annual revenue from pineapple sales?

**A:** Below RM 1 million. Currently exempt from e-Invoice mandate.

## Q3: Invoice document appearance
**Q:** Should the invoice show company logo and signature block?

**A:** Logo + signature block. Full professional look with logo header and signature lines.

## Q4: Payment methods for invoices
**Q:** When recording payment against an invoice, what methods are used?

**A:** Same as current — cash, bank transfer, cheque. Mix of methods depending on customer.

## Q5: Statement of Account format
**Q:** How often and what format for statements?

**A:** Monthly with aging breakdown + payment reminder. Include aging + bank details + WhatsApp payment reminder message.

## Q6: Credit note linking
**Q:** Should credit notes link to existing return records or be standalone?

**A:** Both options. Can create CN from an existing return OR directly against an invoice.

## Q7: e-Invoice implementation scope
**Q:** Since exempt from e-Invoice, build full API now or prepare structure only?

**A:** Prepare structure only. Add the fields/columns now, build LHDN API integration later when needed.

## Q8: Cash Sales invoicing
**Q:** Should CS orders also be invoiceable?

**A:** DO only. CS already has receipt/document generation which is sufficient for cash customers.

## Q9: Payments tab with invoicing
**Q:** How should the Payments tab work with invoicing?

**A:** Split view — CS payments + Invoice payments shown as two separate sections.

## Q10: Approval workflow
**Q:** Should there be an approval workflow for invoices?

**A:** Yes — Draft → Approve → Issue. Invoices start as draft, need explicit approval before issuing to customer.

## Q11: Customer address data
**Q:** Do customers already have addresses in the system?

**A:** New data — need to collect. Most customers don't have addresses yet, will need to add gradually.
