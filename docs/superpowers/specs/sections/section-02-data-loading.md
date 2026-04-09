# Section 02: Data Loading

## Overview

This section extends the `loadAllData()` function in `sales.html` to fetch the five new invoicing tables, declares the corresponding global arrays, and adds a set of helper functions used throughout the invoicing feature. These helpers calculate balances, determine invoice status, and filter uninvoiced DOs.

**File to modify:** `sales.html`

**Dependencies:** Section 01 (DB Migration) must be completed first -- the five new tables and altered columns must exist in the database before this code can load them.

**Blocks:** Sections 05 through 14 all depend on the global arrays and helper functions defined here.

---

## Tests (Manual Verification)

All verification is done in the browser console after opening `sales.html`.

### Verify: All new data loads

1. Open `sales.html` in the browser, open DevTools console.
2. Check that `invoices` is an array: `Array.isArray(invoices)` must return `true`.
3. Check that `invoiceItems`, `invoiceOrders`, `invoicePayments`, `creditNotes` all exist and are arrays.
4. Run `console.log(invoices.length, invoiceItems.length)` -- should return `0 0` (empty but loaded, since no invoices exist yet).
5. Confirm no errors in the console during page load.

### Verify: Helper functions exist and are callable

Run each of these in the console and confirm the result:

- `typeof invoiceBalance === 'function'` must return `true`
- `typeof recalcInvoicePaymentStatus === 'function'` must return `true`
- `typeof isOrderInvoiced === 'function'` must return `true`
- `typeof getCustomerUninvoicedDOs === 'function'` must return `true`
- `typeof calcDueDate === 'function'` must return `true`
- `typeof isInvoiceOverdue === 'function'` must return `true`
- `typeof getInvoiceDOs === 'function'` must return `true`

### Verify: Helper function logic (once test data exists)

These can be verified after section 05 creates actual invoices, but the functions must be correct now:

- `invoiceBalance({ grand_total: 1000, credit_total: 100, amount_paid: 200 })` should return `700`
- `calcDueDate('2026-04-03', '30days')` should return `'2026-05-03'`
- `calcDueDate('2026-04-03', 'cod')` should return `'2026-04-03'`
- `isOrderInvoiced(someOrderId)` where the order has no `invoice_id` should return `false`

---

## Implementation Details

### Step 1: Declare Global Arrays

In the global variable declarations section (around line 959 of `sales.html`), add five new arrays alongside the existing ones:

```js
var invoices = [], invoiceItems = [], invoiceOrders = [], invoicePayments = [], creditNotes = [];
```

These should be declared on a new line after the existing `var salesDrivers = [];` and `var systemUsers = [];` lines. The exact location is the `// CONFIG` block near the top of the `<script>` section.

### Step 2: Extend `loadAllData()`

The existing `loadAllData()` function (line 1032) uses a `Promise.all()` with 10 queries, storing results by index (results[0] through results[9]).

Add five new queries to the end of the `Promise.all()` array:

```js
sbQuery(sb.from('sales_invoices').select('*').order('created_at', {ascending: false})),
sbQuery(sb.from('sales_invoice_items').select('*')),
sbQuery(sb.from('sales_invoice_orders').select('*')),
sbQuery(sb.from('sales_invoice_payments').select('*').order('created_at', {ascending: false})),
sbQuery(sb.from('sales_credit_notes').select('*').order('created_at', {ascending: false}))
```

Then add the corresponding assignments after the existing `systemUsers = results[9] || [];` line:

```js
invoices = results[10] || [];
invoiceItems = results[11] || [];
invoiceOrders = results[12] || [];
invoicePayments = results[13] || [];
creditNotes = results[14] || [];
```

The indices 10-14 follow from the existing 0-9 entries.

### Step 3: Add Helper Functions

Add the following helper functions after the existing helper functions section (after the `daysBetween` and `getCustomerName` functions, around line 1090). Each function is described by its signature and exact behavior.

#### `invoiceBalance(inv)`

Returns the outstanding balance on an invoice: `grand_total - credit_total - amount_paid`. All three fields are numeric columns on `sales_invoices`.

```js
function invoiceBalance(inv) {
  return (inv.grand_total || 0) - (inv.credit_total || 0) - (inv.amount_paid || 0);
}
```

#### `recalcInvoicePaymentStatus(invoiceId)`

Recalculates the `payment_status` and `amount_paid` for an invoice based on the sum of all its payments and credit notes, then updates both the local `invoices` array and the database.

Logic:
1. Find the invoice in the local `invoices` array by ID.
2. Sum `amount` from all entries in `invoicePayments` where `invoice_id` matches.
3. Read `credit_total` from the invoice (already maintained separately when CNs are added).
4. Determine status: if `totalPaid + creditTotal >= grand_total` then `'paid'`; if `totalPaid + creditTotal > 0` then `'partial'`; else `'unpaid'`.
5. Update the local invoice object's `amount_paid` and `payment_status`.
6. Update the database: `sb.from('sales_invoices').update({ amount_paid: totalPaid, payment_status: status }).eq('id', invoiceId).select()` via `sbQuery()`.

This is an async function since it writes to the database.

#### `isOrderInvoiced(orderId)`

Returns `true` if the order has been included in any invoice. Checks two sources for robustness:
1. The order's own `invoice_id` field is non-null.
2. OR the `invoiceOrders` array contains an entry with this `order_id`.

```js
function isOrderInvoiced(orderId) {
  var order = orders.find(function(o) { return o.id === orderId; });
  if (order && order.invoice_id) return true;
  return invoiceOrders.some(function(io) { return io.order_id === orderId; });
}
```

#### `getInvoiceDOs(invoiceId)`

Returns all order objects linked to a given invoice. Looks up order IDs from `invoiceOrders`, then maps them to full order objects from the `orders` array.

```js
function getInvoiceDOs(invoiceId) {
  var orderIds = invoiceOrders
    .filter(function(io) { return io.invoice_id === invoiceId; })
    .map(function(io) { return io.order_id; });
  return orders.filter(function(o) { return orderIds.indexOf(o.id) !== -1; });
}
```

#### `getCustomerUninvoicedDOs(customerId)`

Returns completed Delivery Orders for a customer that have not been included in any invoice. These are the DOs eligible for invoicing.

Filter criteria:
- `customer_id` matches the given ID
- `doc_type === 'delivery_order'`
- `status === 'completed'`
- `invoice_id` is null/falsy

```js
function getCustomerUninvoicedDOs(customerId) {
  return orders.filter(function(o) {
    return o.customer_id === customerId
      && o.doc_type === 'delivery_order'
      && o.status === 'completed'
      && !o.invoice_id;
  });
}
```

#### `calcDueDate(invoiceDate, paymentTerms)`

Calculates the due date by adding the appropriate number of days to the invoice date based on the payment terms code.

Payment terms mapping:
- `'cod'` or `'0'` -- 0 days (due same day)
- `'7days'` -- 7 days
- `'14days'` -- 14 days
- `'30days'` -- 30 days
- `'60days'` -- 60 days

The function accepts `invoiceDate` as a `YYYY-MM-DD` string and returns a `YYYY-MM-DD` string. It parses the date, adds the days, and formats back.

```js
function calcDueDate(invoiceDate, paymentTerms) {
  var daysMap = { cod: 0, '7days': 7, '14days': 14, '30days': 30, '60days': 60 };
  var days = daysMap[paymentTerms] || 30;
  var d = new Date(invoiceDate + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return d.toISOString().split('T')[0];
}
```

#### `isInvoiceOverdue(inv)`

Returns `true` if the invoice is past its due date and still has an outstanding balance. Specifically:
- `inv.status === 'issued'` (only issued invoices can be overdue; drafts and cancelled cannot)
- `inv.payment_status === 'unpaid'` OR `inv.payment_status === 'partial'`
- `inv.due_date < today` (comparing date strings works since they are `YYYY-MM-DD` format)

```js
function isInvoiceOverdue(inv) {
  if (inv.status !== 'issued') return false;
  if (inv.payment_status !== 'unpaid' && inv.payment_status !== 'partial') return false;
  var today = new Date().toISOString().split('T')[0];
  return inv.due_date < today;
}
```

---

## Key Context for Implementer

- **`sbQuery()` pattern**: All Supabase queries go through the `sbQuery()` wrapper defined in `shared.js`. It handles error notifications and offline detection. The return value is the data array (or null on error).
- **`dbNextId(prefix)`**: Existing function in `sales.html` that generates sequential IDs like `INV-260403-001` using the `id_counters` table. Used by later sections when creating invoices, payments, and credit notes -- not needed in this section.
- **No build step**: All code is inline in `sales.html`. Functions are declared at the module level inside the `<script>` tag.
- **Vanilla JS only**: Use `var`, `function`, `.indexOf()`, `.filter()`, `.find()`, `.some()` -- no arrow functions, no `let`/`const`, no template literals. This matches the existing codebase style throughout `sales.html`.
- **The `orders` array** already contains `invoice_id` as a field (once the DB migration from section 01 adds the column). The existing `loadAllData()` query uses `select('*')`, so the new column is automatically included without query changes.
