# Pcs-Ordered / Kg-Billed Sales Lines — Design

**Date:** 2026-04-08
**Module:** Sales (sales.html)
**Status:** Approved, ready for implementation plan

## Problem

Some customers order produce by piece count ("give me 50 pineapples") and the
farm prepares the order in pcs, but the invoice must always be in kilograms
because the agreed price is per kg. Today, every product has a single fixed
unit (kg or pcs) and order-item quantity drives both preparation and invoicing,
so this dual-unit case can't be expressed cleanly.

The owner also relies on summing `quantity` across `sales_order_items` to
report monthly kg sold. Any solution must keep that aggregation correct without
report-side changes.

## Goals

- Allow individual order lines to be ordered in pcs while billed in kg
- Capture actual weight at the moment workers mark the order as prepared
- Preserve the meaning of `sales_order_items.quantity` as "kg used for billing"
  so existing reports keep working unchanged
- Mix pcs-ordered and normal kg-ordered lines freely within the same order

## Non-goals

- Changing the product catalog model (products still have one canonical unit)
- Adding a "pcs sold" reporting column (possible follow-up, out of scope here)
- Per-pc pricing — pricing is always per kg

## Data Model

Two new nullable columns on `sales_order_items`:

| Column | Type | Meaning |
|---|---|---|
| `order_pcs` | `int` | Pcs the customer ordered. `NULL` for normal kg lines. |
| `actual_weight_kg` | `numeric` | Weight keyed in at "Mark Prepared". `NULL` until weighed. |

Existing columns keep their semantics:

- `quantity` — kg used for billing. For pcs-ordered lines, equals
  `actual_weight_kg` once weighed; `0` before weighing.
- `unit_price` — RM per kg, unchanged.
- `line_total` — `quantity * unit_price`, unchanged.

A line is "pcs-ordered" iff `order_pcs IS NOT NULL`.
A line is "weighed" iff `actual_weight_kg IS NOT NULL`.

### Why this shape

- All existing reports (monthly kg sold, revenue, customer history, dashboards)
  read `quantity` / `line_total` and need zero changes.
- Legacy code that doesn't know about pcs ordering keeps working — nullable
  columns are invisible to it.
- The pcs context survives in `order_pcs` so the prep doc and invoice can both
  display it.

### Migration

```sql
alter table sales_order_items
  add column order_pcs integer,
  add column actual_weight_kg numeric;
```

No backfill needed — existing rows are normal kg lines, and `NULL` is the
correct default.

## Order Entry UX

In the New Order modal item rows, add a per-line toggle next to the qty input:
**"Order in pcs"**.

The toggle is only shown when the selected product has `unit = 'kg'` (it makes
no sense for products already defined as `pcs` or `box`).

### Toggle OFF (default)

Identical to current behavior. Qty is in kg, line total = kg × price/kg.

### Toggle ON

- Qty input becomes integer-only (`step=1`), placeholder "Pcs"
- Inline unit label shows `pcs` instead of `kg`
- Price label still indicates the kg price (it has not changed)
- Line total displays `— (pending weight)` in muted text
- The order subtotal sums only weighed lines and shows a hint below:
  `+ N items pending weight`

### On Save

For each pcs-ordered line, persist:

- `order_pcs = <input pcs>`
- `quantity = 0`
- `actual_weight_kg = NULL`
- `line_total = 0`
- `unit_price = <kg price>` (unchanged)

The order can be saved with pcs-ordered lines. It cannot be invoiced until all
such lines are weighed (see Documents section).

## Mark Prepared Flow

The existing "Confirm Prepared Quantities" modal (`#so-prep-modal` area, fired
by `soMarkPrepared`) is extended — no new screen.

For each line in the modal:

- **Normal kg line:** unchanged (confirm prepared kg)
- **Pcs-ordered line:** show two adjacent fields
  - `Pcs prepared` (defaults to `order_pcs`, worker can adjust if short)
  - `Actual weight (kg)` (required, integer or decimal)

The modal cannot be confirmed until every pcs-ordered line has a weight > 0.

### On Confirm

For each pcs-ordered line, write:

- `order_pcs = <prepared pcs>` (may differ from original)
- `actual_weight_kg = <entered weight>`
- `quantity = <entered weight>`
- `line_total = quantity * unit_price`

Order status moves to `prepared` exactly as today. After this point, the line
is indistinguishable from a normal kg line for invoicing, payment, returns, and
all reports.

### Editing After Prepared

The actual weight remains editable from the order detail view until the order
is invoiced/completed, mirroring how `quantity` is currently editable. Edits
recompute `line_total` and order totals using the existing edit handlers.

## Documents

### Prep doc / packing list (80mm thermal & A4)

Pcs-ordered line renders as:

```
Pineapple Whole Fruit >1kg     50 pcs
```

Workers see exactly what they need to pick.

### Delivery Order / Invoice (80mm & A4)

Pcs-ordered line renders as a normal kg line, with a small subtitle under the
product name showing the original pcs count:

```
Pineapple Whole Fruit >1kg
  (50 pcs)                   12.40 kg × RM 4.00     RM 49.60
```

Normal kg lines render unchanged.

### Invoice Generation Guard

If invoice generation is attempted on an order that still has un-weighed
pcs-ordered lines, block it with a clear message:

> Cannot invoice — N items pending weight. Mark order as Prepared first.

## Edits, Returns, Reports

### Editing before prepared

Pcs-ordered lines can be edited like normal lines: change pcs count, toggle pcs
mode off, or remove the line entirely. Once the order reaches `prepared`,
existing edit rules apply unchanged.

### Returns

The returns flow already operates on `quantity` (kg). For a pcs-ordered line
that has been weighed, returns work identically — staff enters kg returned. The
`order_pcs` value stays as historical context only.

### Reports & dashboards

No changes. Monthly kg sold, revenue, customer history, and product sales all
read `quantity` and `line_total`, which are populated correctly after weighing.

### Walk-in sales

The walk-in flow uses the same items table, so the toggle is available. In
practice walk-ins are weighed on the spot and rarely need it.

### Cancellation

An order with un-weighed pcs-ordered lines that gets cancelled simply
cancels — no kg recorded, no revenue impact, no special handling.

## Out of Scope (possible follow-ups)

- "Pcs sold" column in product reports (would read `order_pcs`)
- Per-product "average kg per pc" for showing estimated totals before weighing
- Bulk weight entry for many pcs-ordered lines at once
