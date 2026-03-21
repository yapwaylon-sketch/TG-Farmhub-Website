# Sales Module Phase 2: Orders + Workflow + WhatsApp

> **For agentic workers:** Use superpowers:subagent-driven-development to implement task-by-task.

**Goal:** Build order creation, order detail view with status transitions, and WhatsApp worker notification — the core operational workflow.

**Spec:** `docs/superpowers/specs/2026-03-21-sales-module-design.md`

**Scope:** Phase 2 of 8. Builds on Phase 1 (DB, products, customers, dashboard). Covers Orders tab, order detail, status workflow, WhatsApp sharing.

**Prerequisites:** Phase 1 complete. `sales_customers`, `sales_products`, `sales_orders`, `sales_order_items` tables exist. Products and customers can be added via UI.

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `sales.html` | Modify | Orders tab, order creation modal, order detail view, status actions, WhatsApp sharing |

---

## Task 1: Order Creation Modal

Add a full-screen (on mobile) order creation flow to sales.html:

**Modal structure:**
1. Customer selection — search dropdown that filters customers by name/phone as user types. "Add New Customer" inline option.
2. Order details — delivery date, delivery time (optional), fulfillment type (delivery/collection), doc type (cash_sales/delivery_order), channel (whatsapp/walkin/phone)
3. Line items section — add multiple items:
   - Product dropdown (from active salesProducts, grouped by variety)
   - Quantity (number input)
   - Unit price (pre-filled from product default_price, editable)
   - Index min/max (0-5 dropdowns, optional)
   - Line total (auto-calculated, read-only)
   - Remove button per item
   - "Add Item" button
4. Order notes (textarea)
5. Subtotal display (sum of line totals)
6. Save button

**Functions:**
- `openNewOrderModal()` — replace the placeholder stub
- `soAddItem()` — add a new line item row
- `soRemoveItem(idx)` — remove a line item
- `soCalcTotals()` — recalculate subtotal on any quantity/price change
- `soSaveOrder()` — validate, generate order ID via `dbNextId('SO')`, generate doc_number via `dbNextId('DO')` or `dbNextId('CS')`, insert order + items, update local arrays, close modal

**Validation:**
- Customer required
- At least 1 item required
- Each item: product required, quantity > 0, unit_price >= 0

---

## Task 2: Orders Tab — List View

Replace the Orders tab stub with:

**Filter bar:**
- Status dropdown (All, Pending, Preparing, Prepared, Delivering, Completed, Cancelled)
- Doc type dropdown (All, DO, CS)
- Date range (from/to date inputs)
- Customer search (text input)
- Sort dropdown (Newest, Oldest, Customer A-Z)
- Clear Filters button

**Order list:**
- Mobile: `.sales-card` cards
- Each card shows: doc_number, customer name, order_date, delivery_date, status badge, doc_type badge, payment_status badge, grand_total
- Tap card to open order detail
- Shows items count as subtitle

**Functions:**
- `renderOrders()` — render filtered/sorted order cards
- Filter state variables and filter change handlers

---

## Task 3: Order Detail View

When user taps an order card, show a detail view (replaces the orders list, with back button):

**Header:**
- Back button (← Orders)
- Order number + doc number
- Status badge (large)

**Status Timeline:**
- Horizontal dots: Pending → Preparing → Prepared → Delivering → Completed
- Current step highlighted gold, completed steps green, future gray
- Uses `.status-timeline` CSS from sales.css

**Customer Info Section:**
- Customer name, phone, address
- Doc type badge, fulfillment badge

**Items Table:**
- Product name, variety, index range, quantity, unit, unit_price, line_total
- Subtotal row

**Action Buttons (context-dependent on status):**
- `pending`: "Start Preparing", "Send to Workers (WhatsApp)", "Edit Order", "Cancel Order"
- `preparing`: "Mark Prepared" (prompts for photo)
- `prepared`: "Assign Driver & Deliver" (shows driver dropdown) OR "Mark Collected" (for collection orders)
- `delivering`: "Mark Delivered" (prompts for photo)
- `completed`: no status actions, show document generation buttons
- Any non-completed: "Cancel Order"

**Payments Section (stub for Phase 4):**
- Shows amount_paid vs grand_total
- "Record Payment" button (stub)

**Photos Section:**
- Prep photo thumbnail (if exists)
- Delivery photo thumbnail (if exists)

**Functions:**
- `soOpenDetail(orderId)` — switches view to detail mode
- `soBackToList()` — switches back to order list
- `soRenderDetail(orderId)` — renders all sections
- `soRenderTimeline(status)` — renders status dots

---

## Task 4: Status Transitions

Implement the status change functions:

- `soStartPreparing(orderId)` — update status to 'preparing'
- `soMarkPrepared(orderId)` — prompt for photo (optional), update status to 'prepared'
- `soAssignDriver(orderId)` — show driver selection modal (load workers), set driver_id, update status to 'delivering'
- `soMarkCollected(orderId)` — update status to 'completed' (for collection orders)
- `soMarkDelivered(orderId)` — prompt for photo (optional), update status to 'completed'
- `soCancelOrder(orderId)` — confirmAction, update status to 'cancelled'
- `soEditOrder(orderId)` — open order creation modal pre-filled with existing data (only if status is 'pending')

**Photo capture:**
- Use `<input type="file" accept="image/*" capture="environment">` in a hidden element
- On file selected: resize client-side (max 1200px, JPEG 80%), upload to Supabase Storage bucket `sales-photos` at path `{orderId}/prep.jpg` or `{orderId}/delivery.jpg`
- Update order's `prep_photo_url` or `delivery_photo_url`

**Driver selection:**
- Load workers from `workers` table (active only)
- Simple modal with dropdown + confirm button

**After each status change:**
- Update local `orders` array
- Re-render detail view
- Notify success
- If status becomes 'completed': auto-generate doc number if not set

---

## Task 5: WhatsApp Worker Notification

Add "Send to Workers" button on order detail (when status is pending/preparing):

**Message format (Bahasa Malaysia):**
```
🍍 Pesanan Baru — PND
━━━━━━━━━━━━━━━━━━━━
📋 No: [order_id]
👤 Pelanggan: [customer_name]
📅 Tarikh Hantar: [delivery_date] [delivery_time]
📦 Jenis: [Penghantaran/Pengambilan]

📝 Senarai:
• [variety] [product_name] (Index [min]-[max]) — [qty] [unit]
• [variety] [product_name] — [qty] [unit]

💰 Jumlah: RM [subtotal]
📌 Nota: [notes]
━━━━━━━━━━━━━━━━━━━━
```

**Functions:**
- `soWhatsAppWorkers(orderId)` — generates message text, shows popup with preview + "Copy Text" + "Send WhatsApp" buttons (same pattern as spraytracker.html WhatsApp sharing)

---

## Task 6: Dashboard Integration

Update `renderDashboard()` to properly show today's orders with working links:
- Clicking an order card in dashboard should call `switchTab('orders'); soOpenDetail(orderId)`
- Update order counts to be accurate with real data

Also update bottom action bar: "New Order" button should work now (calls `openNewOrderModal()`).
