# Section 03: Payment Terms + Customer Fields Update

## Overview

This section updates the customer model and UI throughout `sales.html` to replace the binary `payment_terms` (credit/cash) with a numeric `payment_terms_days` field, and adds new customer fields needed for invoicing (SSM/BRN, TIN, IC Number). It also updates the order creation logic so that `doc_type` assignment uses the new numeric field.

**File to modify:** `sales.html`

**Dependencies:**
- **Section 01 (DB Migration)** must be completed first -- the `payment_terms_days`, `ssm_brn`, `tin`, and `ic_number` columns must exist on `sales_customers`, and the data migration (credit -> 30, cash -> 0) must have run.

**Blocks:**
- Section 05 (Create Invoice) depends on `payment_terms_days` being available on the customer model.

---

## Tests / Verification (Manual)

These are the acceptance criteria to verify after implementation.

### Verify: Customer modal shows new fields

1. Open sales.html, navigate to Manage Customers tab.
2. Click "Add Customer" or "Edit" on an existing customer.
3. Confirm the following fields are visible in the modal:
   - Address textarea (already exists, should be present)
   - SSM / BRN text input with placeholder "e.g., 1234567-A"
   - TIN text input with placeholder "e.g., C1234567890"
   - IC Number text input with placeholder "e.g., 900101-13-1234"
   - Payment Terms dropdown showing: COD, Net 7, Net 14, Net 30, Net 60

### Verify: Save + display

1. Edit an existing customer, set payment terms to "Net 14", enter an address and SSM number.
2. Save the customer.
3. In the customer list table, confirm the badge shows "Net 14" (not "Credit" or "Cash").
4. Click the customer name to open the detail view.
5. Confirm the detail view shows:
   - Payment Terms badge as "Net 14"
   - Address displayed
   - SSM/BRN displayed (only if populated)
   - TIN and IC Number displayed (only if populated; hidden when empty)

### Verify: Order creation uses new field

1. Create an order for a customer with `payment_terms_days = 30` -- doc_type should auto-set to `delivery_order`.
2. Create an order for a customer with `payment_terms_days = 0` (COD) -- doc_type should auto-set to `cash_sales`.

### Verify: Customer list filter

1. The payment terms filter dropdown should offer options matching the new terms (COD, Net 7, Net 14, Net 30, Net 60, or "All").
2. Filtering should work correctly with the numeric field.

### Verify: A4 documents

1. Generate an A4 statement or document for a customer with `payment_terms_days = 30`.
2. The "Terms:" line should show "Net 30" (not "Credit").

---

## Implementation Details

### 1. Helper Function: Payment Terms Label

Add a utility function that converts the numeric `payment_terms_days` value to a display label. This will be used throughout the UI.

```javascript
function paymentTermsLabel(days) {
  /** Returns display label for payment_terms_days value.
   *  0 -> "COD", 7 -> "Net 7", 14 -> "Net 14", 30 -> "Net 30", 60 -> "Net 60"
   *  Falls back to "Net X" for any other positive integer.
   */
}
```

Also add a helper for badge styling:

```javascript
function paymentTermsBadgeClass(days) {
  /** Returns CSS badge class: 'cs' for COD (0), 'do' for any credit terms (>0). */
}
```

### 2. Customer Edit Modal HTML Changes

**Location:** The `sc-modal` div starting at approximately line 272 in `sales.html`.

**Changes to make:**

a) **Replace the payment terms dropdown** (currently lines 316-321). The current `<select>` has two options: `cash` and `credit`. Replace with a dropdown that stores numeric values:

```html
<div class="form-field">
  <label>PAYMENT TERMS</label>
  <select id="sc-payment-terms" style="width:100%;">
    <option value="0">COD (Cash on Delivery)</option>
    <option value="7">Net 7</option>
    <option value="14">Net 14</option>
    <option value="30">Net 30</option>
    <option value="60">Net 60</option>
  </select>
</div>
```

b) **Add three new fields** after the Payment Terms field and before the Notes textarea. Insert these new form fields:

- **SSM / BRN** -- text input, id `sc-ssm-brn`, placeholder "e.g., 1234567-A"
- **TIN** -- text input, id `sc-tin`, placeholder "e.g., C1234567890"
- **IC Number** -- text input, id `sc-ic-number`, placeholder "e.g., 900101-13-1234"

These three fields can be placed in a `form-row` div or individually, depending on layout preference. They are all optional.

c) **Address field** already exists (line 294-296). No change needed to the HTML, but consider adding a slightly more descriptive placeholder like "Full address for invoices (optional)".

### 3. Customer Edit Modal JS Changes

**`scOpenModal()` function** (line 2776):

When populating form fields for edit mode, update:
- Change `sc-payment-terms` to read from `c.payment_terms_days` instead of `c.payment_terms`. Convert to string for the select value: `String(c.payment_terms_days || 0)`.
- Add population for the three new fields: `sc-ssm-brn` from `c.ssm_brn`, `sc-tin` from `c.tin`, `sc-ic-number` from `c.ic_number`.

When clearing for add mode:
- Set `sc-payment-terms` default to `'0'` (COD) or `'30'` (Net 30) -- Net 30 is a reasonable default for wholesale customers.
- Clear the three new fields to empty strings.

**`scSaveCustomer()` function** (line 2828):

- Read `payment_terms_days` from the dropdown as an integer: `parseInt(document.getElementById('sc-payment-terms').value, 10)`.
- Read the three new fields: `ssm_brn`, `tin`, `ic_number` from their respective inputs. Store as `null` if empty.
- Update the `data` object to include:
  - `payment_terms_days: paymentTermsDays`
  - `payment_terms: paymentTermsDays > 0 ? 'credit' : 'cash'` (keep backward compat)
  - `ssm_brn: ssmBrn || null`
  - `tin: tin || null`
  - `ic_number: icNumber || null`

Writing both `payment_terms` and `payment_terms_days` ensures backward compatibility during the transition period (the old column is kept in the DB).

### 4. Customer List Table Changes

**`renderCustomerCards()` function** (around line 2680):

a) **Badge display** -- Currently at approximately line 2758:
```javascript
// BEFORE:
html += '<span class="badge badge-' + (c.payment_terms === 'credit' ? 'do' : 'cs') + '">' + (c.payment_terms === 'credit' ? 'Credit' : 'Cash') + '</span>';

// AFTER: Use the helper functions
html += '<span class="badge badge-' + paymentTermsBadgeClass(c.payment_terms_days) + '">' + paymentTermsLabel(c.payment_terms_days) + '</span>';
```

b) **Filter dropdown** -- Currently at approximately lines 2697-2700. The filter uses `scFilterPayment` with values `'credit'` and `'cash'`. Change to use numeric values or a new approach:

Replace the filter variable `scFilterPayment` (string) with a new approach. Options:
- Keep `scFilterPayment` as a string but use values like `'0'`, `'7'`, `'14'`, `'30'`, `'60'`, or `''` for all.
- Alternatively, use a broader filter: `'cod'` (0) vs `'credit'` (>0) vs specific day values.

Recommended approach: Change filter options to:
```html
<option value="">All Payment</option>
<option value="cod">COD</option>
<option value="credit">Credit (Net 7+)</option>
```

The filter check (line 2715) changes from:
```javascript
// BEFORE:
if (scFilterPayment && c.payment_terms !== scFilterPayment) return false;

// AFTER:
if (scFilterPayment === 'cod' && (c.payment_terms_days || 0) > 0) return false;
if (scFilterPayment === 'credit' && (c.payment_terms_days || 0) === 0) return false;
```

### 5. Customer Detail View Changes

**`scRenderDetail()` function** (line 2956):

a) **Payment Terms badge** -- At approximately line 2985, change from:
```javascript
// BEFORE:
'<span class="badge badge-' + (c.payment_terms === 'credit' ? 'do' : 'cs') + '">' + (c.payment_terms === 'credit' ? 'Credit' : 'Cash') + '</span>'

// AFTER:
'<span class="badge badge-' + paymentTermsBadgeClass(c.payment_terms_days) + '">' + paymentTermsLabel(c.payment_terms_days) + '</span>'
```

b) **New fields display** -- After the existing detail fields (channel, address, notes), add conditional display for the three new fields. Only show if populated (do not show empty fields):

```javascript
if (c.ssm_brn) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">SSM / BRN</div><div style="color:var(--text);">' + esc(c.ssm_brn) + '</div></div>';
if (c.tin) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">TIN</div><div style="color:var(--text);">' + esc(c.tin) + '</div></div>';
if (c.ic_number) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">IC Number</div><div style="color:var(--text);">' + esc(c.ic_number) + '</div></div>';
```

### 6. Order Creation -- doc_type Assignment

**`soSelectCustomer()` function** (around line 5080):

Change the doc_type auto-assignment from:
```javascript
// BEFORE:
if (soSelectedCustomer.payment_terms === 'credit') {
    document.getElementById('so-doc-type').value = 'delivery_order';
} else {
    document.getElementById('so-doc-type').value = 'cash_sales';
}

// AFTER:
if ((soSelectedCustomer.payment_terms_days || 0) > 0) {
    document.getElementById('so-doc-type').value = 'delivery_order';
} else {
    document.getElementById('so-doc-type').value = 'cash_sales';
}
```

### 7. A4 Document Terms Display

**`soGenerateStatement()` and other A4 generation functions** -- At approximately line 6059:

```javascript
// BEFORE:
html += '<div class="a4-info-label">Terms:</div><div class="a4-info-value">' + (cust.payment_terms === 'credit' ? 'Credit' : 'Cash') + '</div>';

// AFTER:
html += '<div class="a4-info-label">Terms:</div><div class="a4-info-value">' + paymentTermsLabel(cust.payment_terms_days) + '</div>';
```

Search for all other occurrences of `cust.payment_terms === 'credit'` in A4 generation code and replace with the `paymentTermsLabel()` helper.

### 8. Walk-in Customer Auto-Create

**Walk-in shortcut** (around line 4924): When auto-creating a walk-in customer, set `payment_terms_days: 0` in addition to `payment_terms: 'cash'`:

```javascript
var wData = { 
  id: wId, name: 'Walk-In Customer', phone: null, contact_person: null, 
  address: null, type: 'individual', channel: 'walkin', 
  payment_terms: 'cash', payment_terms_days: 0,
  notes: 'Auto-created for walk-in sales', is_active: true 
};
```

---

## Summary of All Locations Modified

All changes in `sales.html` (55 insertions, 14 deletions):

| Location | What Changed |
|----------|-------------|
| line 316 (sc-modal HTML) | Replaced payment terms dropdown: cash/credit → COD/Net 7/14/30/60. Added SSM/BRN, TIN, IC Number fields. |
| line 2780 (filter dropdown) | Filter options changed to COD / Credit (Net 7+) |
| line 2796 (filter check) | Uses `payment_terms_days` numeric check instead of string comparison |
| line 2840 (customer list badge) | Uses `paymentTermsLabel()` and `paymentTermsBadgeClass()` helpers |
| line 2858 (new helpers) | Added `paymentTermsLabel(days)` and `paymentTermsBadgeClass(days)` after scTypeLabel |
| line 2886 (scOpenModal edit) | Reads `payment_terms_days`, `ssm_brn`, `tin`, `ic_number` |
| line 2901 (scOpenModal add) | Default payment terms set to Net 30 for new customers |
| line 2934 (scSaveCustomer) | Reads new fields, writes both `payment_terms` + `payment_terms_days` for backward compat |
| line 3089 (scRenderDetail badge) | Uses helpers for payment terms display |
| line 3092 (scRenderDetail fields) | Conditionally shows SSM/BRN, TIN, IC Number when populated |
| line 5031 (walk-in auto-create) | Added `payment_terms_days: 0` alongside existing `payment_terms: 'cash'` |
| line 5187 (soSelectCustomer) | doc_type check uses `payment_terms_days > 0` |
| line 6166 (A4 statement terms) | Uses `paymentTermsLabel()` |

## Deviations from Plan
- None. All planned changes implemented as specified.
- Default payment terms for new customers: Net 30 (reasonable for wholesale-focused business).
