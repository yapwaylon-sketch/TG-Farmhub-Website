# Sales Module — Mobile UX Redesign

**Date:** 2026-04-13
**Scope:** Mobile-only (≤768px) changes to `sales.html` and `sales.css`
**Revert point:** Git tag `pre-mobile-redesign`

## Problem

The entire sales order lifecycle runs on phone (create → prepare → deliver → share docs), but the current UI was designed for desktop. Two specific pain points:

1. **Action buttons buried in order detail** — staff must scroll through the detail page to find Start Preparing / Mark Prepared / Mark Delivered
2. **Item picker is clunky on phone** — small dropdown, tiny qty/price inputs crammed in a row, hard to tap accurately with thumbs

## What Changes (Mobile Only)

Desktop layout is **completely unchanged**. All changes are behind `@media (max-width: 768px)` or JS screen-width checks. The same `soSaveOrder()` function is called regardless of layout.

### Change 1: Sticky Action Bar on Order Detail

When viewing an order detail on mobile, a fixed bar at the bottom of the screen shows the next-step action button. The button changes based on order status:

| Order Status | Button Label | Button Color |
|---|---|---|
| pending | Start Preparing → | Blue (#3A7AC8) |
| preparing | Mark Prepared → | Orange (#E8A020) |
| prepared | Ready For Delivery → | Green (#4A7C3F) |
| delivering | Mark Delivered → | Purple (#8C5AD2) |
| completed | View Document | Gold (#D4AF37) |
| cancelled | (no bar) | — |

**Implementation:**
- CSS: `position: fixed; bottom: 0; left: 0; right: 0;` with `z-index` above content
- Only visible on mobile (`display:none` on desktop — desktop already has the button inline)
- Add `padding-bottom` to detail content so the bar doesn't overlap the last item
- Button calls the same existing function as the current inline button (e.g., `soStartPreparing()`, `soShowPrepQtyModal()`, `markDelivered()`)
- On completed orders, button calls `soGenerateDoc(orderId)` to open the document

### Change 2: Mobile Order Creation Wizard

On mobile, the New Order modal is replaced with a 3-step wizard. On desktop, the existing all-in-one modal is unchanged.

#### Step 1: Customer & Delivery Details

**Layout:**
- Customer search input (full width, large text)
- Walk-in Customer button below search (full width, clearly visible, stacked under search with "— or —" separator)
- Delivery date + time (side by side, large tap targets)
- Fulfillment: toggle buttons `[ Delivery ] [ Collection ]` (not dropdown)
- Doc type: toggle buttons `[ CS ] [ DO ]` — auto-selected based on customer `payment_terms` (cash → CS, credit → DO), staff can override
- Channel: toggle buttons `[ WhatsApp ] [ Phone ] [ Walk-in ]`
- Order date: hidden, defaults to today (editable on Step 3 review if needed)

**Walk-in behavior:** Tapping Walk-in auto-sets fulfillment=collection, channel=walk-in, doc_type=cash_sales. Customer search hides. Staff can still override fulfillment/channel.

**Bottom bar:** "Next: Add Items →" button (gold, fixed at bottom)

#### Step 2: Items (Variety-Based Picker)

**Layout:**
- Already-added items shown at top as compact cards (product name, qty × price, total, × to remove)
- Variety tabs: `[ MD2 ] [ SG1 ] [ Other ]` — tabs auto-generated from active varieties in DB
- Product grid: 2-column grid of tappable cards showing product name + default price/unit
- "Other" tab: products with no variety assigned (non-pineapple items)

**Tap-to-add flow:**
1. Tap a variety tab → its products display in the grid
2. Tap a product card → card highlights (gold border), qty input panel slides in below the grid
3. Qty input panel shows: product name, price (tappable to edit with confirmation: "Change price from RM4.50?"), large qty input (18px font, centered), unit label, "Add RM225" button with live total
4. Tap "Add" → item appears in the list above, picker resets (stays on same variety tab)
5. To add another item, tap another product card

**Price editing:** Default price is shown but not directly editable. Staff must tap the price, confirm they want to change it ("Change price from RM4.50?"), then the field becomes editable. Prevents accidental price changes.

**Ripeness index:** Hidden by default. Small "Add index" link on each added item card. Tapping it expands min/max index fields for that item. Rarely used — keeps the UI clean for 99% of orders.

**Bottom bar:** "← Back" (outline) + "Next: Review →" (gold)

#### Step 3: Review & Create

**Layout:**
- Summary card with all order details:
  - Customer name + phone (with "Edit" link → jumps to Step 1)
  - Delivery date/time + fulfillment (with "Edit" link → jumps to Step 1)
  - Doc type + channel badges
  - Items list with quantities and line totals
  - Grand total (prominent, gold)
- Notes textarea (optional, full width, placeholder "Tap to add delivery notes...")
- Order date shown as small text (defaults to today, tappable to change)

**Bottom bar:** "← Back" (outline) + "Create Order" (green #4A7C3F)

#### Wizard Technical Details

- Wizard HTML exists inside the existing `#so-modal` overlay
- Mobile: wizard container is `display:block`, desktop form is `display:none`
- Desktop: wizard container is `display:none`, desktop form is `display:block`
- Detection: CSS media query for layout, JS `window.innerWidth <= 768` for wizard step logic
- Wizard state stored in JS variables (currentStep, step1Data, step2Items)
- On "Create Order", wizard collects all data and calls the same `soSaveOrder()` function
- Back button on Step 1 closes the modal (same as Cancel)
- Progress bar: 3-segment bar at top of modal, gold fill indicates completed steps

## What Does NOT Change

- Desktop layout (all modules, all tabs)
- Sidebar navigation on mobile
- Order card appearance on mobile
- Filter bar on mobile
- All other tabs (Dashboard, Payments, Invoicing, Customers, Products, Reports)
- delivery.html (already phone-optimized in Wave 2)
- display-sales.html (TV display, not phone)
- Database schema (no migrations needed)
- All existing JS functions (soSaveOrder, soStartPreparing, etc.)

## Data Flow

No new data paths. The wizard collects the same fields as the desktop form:
- `customer_id`, `order_date`, `delivery_date`, `delivery_time`
- `fulfillment`, `doc_type`, `channel`, `notes`
- `items[]` with `product_id`, `quantity`, `unit_price`, `index_min`, `index_max`, `order_pcs`

All fields are passed to the existing `soSaveOrder()` which handles both create and edit.

## Edit Order on Mobile

Edit uses the same wizard flow, pre-populated with the order's existing data. Step 1 pre-fills customer + delivery details, Step 2 pre-fills items, Step 3 shows "Save Changes" instead of "Create Order".

## Testing Plan

1. **Phone (Android Chrome):**
   - Create a new order through the wizard (all 3 steps)
   - Edit an existing order through the wizard
   - Walk-in order creation
   - Verify sticky action bar on each order status
   - Test Back/Next navigation between steps
   - Test price editing with confirmation
   - Test ripeness index expand/collapse
2. **Desktop browser:**
   - Verify zero changes to existing layout
   - Create/edit orders with existing form
   - Verify order detail buttons still work inline
3. **Resize test:**
   - Drag browser window between mobile/desktop widths
   - Verify layout switches cleanly at 768px breakpoint

## Mockups

Visual mockups created during brainstorming are at:
`.superpowers/brainstorm/6282-1776013799/content/`
- `sticky-action-bar.html` — Before/after comparison
- `item-picker-v2.html` — Variety-based picker design
- `order-wizard.html` — Full 3-step wizard flow
