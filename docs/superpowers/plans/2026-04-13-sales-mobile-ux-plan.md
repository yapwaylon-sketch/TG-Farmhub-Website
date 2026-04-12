# Sales Module — Mobile UX Implementation Plan

**Spec:** `docs/superpowers/specs/2026-04-13-sales-mobile-ux-design.md`
**Revert point:** Git tag `pre-mobile-redesign`
**Files modified:** `sales.html`, `sales.css`, `shared.css`

## Phase 0: Documentation & API Reference

### Existing Patterns to Follow

**Mobile breakpoint:** 768px (consistent across shared.css and sales.css)
**No utility classes** for mobile/desktop visibility — use direct media queries with `!important`
**Modal pattern:** `openModal(id)` / `closeModal(id)` in shared.js (handles trapFocus/releaseFocus)
**Bottom bar pattern:** `.bottom-actions` in sales.css — `position:fixed; bottom:0; left:var(--sidebar-w); right:0` on desktop, `left:0` on mobile

### Key Functions (DO NOT modify these — call them as-is)

| Function | Line | Purpose |
|---|---|---|
| `soShowPrepModal(orderId)` | 2753 | Opens Start Preparing modal |
| `soMarkPrepared(orderId)` | 2830 | Initiates Mark Prepared flow |
| `soMarkDelivered(orderId)` | 3206 | Initiates Mark Delivered flow |
| `soGenerateDoc(orderId)` | ~8640 | Opens document viewer |
| `soSaveOrder()` | 8401 | Saves order (reads soItems, soSelectedCustomer, form fields) |
| `soSelectCustomer(customerId)` | 8157 | Sets customer + auto-sets doc type |
| `soToggleWalkIn()` | 7986 | Toggles walk-in mode |
| `soCalcTotals()` | 8361 | Recalculates order totals |
| `soSearchCustomers()` | 8119 | Filters customer dropdown |
| `calOpen(fieldId, el)` | shared.js | Opens calendar picker |

### Key State Variables

| Variable | Line | Purpose |
|---|---|---|
| `soItems` | 7981 | Array of {id, productId, quantity, unitPrice, unit, indexMin, indexMax, lineTotal, orderInPcs, orderPcs} |
| `soSelectedCustomer` | 7982 | Selected customer object |
| `soIsWalkIn` | 7984 | Walk-in flag |
| `soEditOrderId` | 1281 | Order ID when editing (null for new) |
| `soEditLockTime` | 8020 | Optimistic lock timestamp |
| `salesProducts` | 1272 | All products (has variety_id, category, unit, default_price, is_active) |
| `varieties` | 1273 | All crop varieties (has id, name) |

### Key HTML Element IDs (Desktop Form)

| ID | Purpose |
|---|---|
| `so-modal` | Order modal overlay (line 845) |
| `so-modal-title` | Modal title (line 848) |
| `so-cust-search` | Customer search input (line 869) |
| `so-cust-results` | Customer dropdown (line 870) |
| `so-cust-selected` | Selected customer badge (line 867) |
| `so-cust-section` | Customer section container (line 865) |
| `so-order-date` | Order date hidden input (line 890) |
| `so-delivery-date` | Delivery date hidden input (line 898) |
| `so-delivery-time` | Delivery time input (line 908) |
| `so-fulfillment` | Fulfillment dropdown (line 912) |
| `so-doc-type` | Doc type dropdown (line 921) |
| `so-channel` | Channel dropdown (line 928) |
| `so-items-container` | Items list (line 940) |
| `so-subtotal` | Subtotal display (line 944) |
| `so-notes` | Notes textarea (line 951) |
| `so-save-btn` | Save button (line 957) |
| `so-walkin-btn` | Walk-in toggle (line 857) |

### Anti-Pattern Guards

- DO NOT modify `soSaveOrder()` — the wizard must populate the same form fields/variables it reads
- DO NOT create separate mobile DB queries — same data, different presentation
- DO NOT use `display:none` in inline JS for mobile/desktop switching — use CSS media queries
- DO NOT break the desktop form — wrap wizard HTML in a container that's `display:none` above 768px

---

## Phase 1: Sticky Action Bar on Order Detail

**Goal:** Fixed bottom bar on mobile showing the next-step action button when viewing order detail.

### Tasks

#### 1.1 Add sticky bar HTML to soRenderDetail()

In `sales.html`, inside the `soRenderDetail()` function (line 2301), after the detail content is built, append a sticky action bar div. The bar contains a single button whose label, color, and onclick change based on `o.status`.

**Status → button mapping:**

```javascript
var actionMap = {
  pending:    { label: 'Start Preparing →', color: '#3A7AC8', fn: 'soShowPrepModal' },
  preparing:  { label: 'Mark Prepared →',   color: '#E8A020', fn: 'soMarkPrepared' },
  delivering: { label: 'Mark Delivered →',  color: '#8C5AD2', fn: 'soMarkDelivered' },
  completed:  { label: 'View Document',     color: '#D4AF37', fn: 'soGenerateDoc' }
};
// 'prepared' status: button is "Assign Driver →" calling soShowDriverModal
// 'cancelled': no bar
```

Note: `prepared` status needs the driver assignment step before delivery. Check the existing detail buttons at lines 2469-2519 for the exact prepared-status logic (it may show "Assign Driver" or "Ready For Delivery" depending on fulfillment type).

**HTML to append (inside soRenderDetail, after main content):**

```html
<div class="so-mobile-action-bar" id="so-mobile-action">
  <button class="btn" style="background:{color};color:#fff;..." onclick="{fn}('{orderId}')">
    {label}
  </button>
</div>
```

#### 1.2 Add CSS for sticky bar

In `sales.css`, add:

```css
/* Mobile sticky action bar — hidden on desktop */
.so-mobile-action-bar {
  display: none;
}

@media (max-width: 768px) {
  .so-mobile-action-bar {
    display: block;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: #fff;
    padding: 10px 14px;
    box-shadow: 0 -4px 12px rgba(0,0,0,0.08);
    z-index: 200;
  }

  .so-mobile-action-bar .btn {
    width: 100%;
    min-height: 48px;
    font-size: 14px;
    font-weight: 700;
    border-radius: 8px;
    border: none;
    color: #fff;
    justify-content: center;
  }

  /* Pad detail content so sticky bar doesn't overlap */
  .so-detail-section:last-of-type {
    padding-bottom: 70px;
  }
}
```

#### 1.3 Verification

- [ ] On mobile (≤768px): sticky bar visible at bottom of order detail with correct button per status
- [ ] On desktop (>768px): sticky bar hidden, existing inline buttons unchanged
- [ ] Tapping button triggers correct function (Start Preparing, Mark Prepared, etc.)
- [ ] Cancelled orders: no bar shown
- [ ] Content not hidden behind the bar (padding-bottom sufficient)

---

## Phase 2: Mobile Wizard — HTML Structure & CSS

**Goal:** Add wizard HTML inside `#so-modal`, hidden on desktop, shown on mobile.

### Tasks

#### 2.1 Add wizard container HTML

Inside the `#so-modal` overlay div (line 845), after the existing `.so-modal-box`, add a new wizard container:

```html
<div class="so-wizard" onclick="event.stopPropagation()">
  <!-- Progress bar -->
  <div class="so-wiz-progress">
    <div class="so-wiz-progress-fill" id="so-wiz-progress-fill"></div>
  </div>

  <!-- Step 1: Customer & Delivery -->
  <div class="so-wiz-step" id="so-wiz-step1">
    <!-- Title -->
    <div class="so-wiz-title" id="so-wiz-title">New Order</div>
    
    <!-- Customer search (full width) -->
    <div class="so-wiz-section" id="so-wiz-cust-section">
      <div class="so-wiz-label">CUSTOMER</div>
      <input type="text" id="so-wiz-cust-search" placeholder="Search customer name or phone..." class="so-wiz-input">
      <div id="so-wiz-cust-results" class="so-wiz-dropdown"></div>
      <div id="so-wiz-cust-selected" class="so-wiz-cust-badge" style="display:none;"></div>
    </div>
    
    <!-- "or" separator + Walk-in button -->
    <div class="so-wiz-separator">— or —</div>
    <button class="so-wiz-walkin-btn" id="so-wiz-walkin-btn" onclick="soWizToggleWalkIn()">Walk-in Customer</button>
    
    <!-- Delivery date + time -->
    <div class="so-wiz-row">
      <div class="so-wiz-field" style="flex:1;">
        <div class="so-wiz-label">DELIVERY DATE</div>
        <div class="so-wiz-date-display" id="so-wiz-delivery-date-display" onclick="calOpen('so-delivery-date', this)"></div>
      </div>
      <div class="so-wiz-field" style="flex:0.7;">
        <div class="so-wiz-label">TIME</div>
        <input type="time" id="so-wiz-delivery-time" class="so-wiz-input">
      </div>
    </div>
    
    <!-- Fulfillment toggle -->
    <div class="so-wiz-section">
      <div class="so-wiz-label">FULFILLMENT</div>
      <div class="so-wiz-toggle" id="so-wiz-fulfillment">
        <button class="so-wiz-toggle-btn active" data-val="delivery" onclick="soWizToggle(this)">Delivery</button>
        <button class="so-wiz-toggle-btn" data-val="collection" onclick="soWizToggle(this)">Collection</button>
      </div>
    </div>
    
    <!-- Doc type toggle -->
    <div class="so-wiz-section">
      <div class="so-wiz-label">DOC TYPE</div>
      <div class="so-wiz-toggle" id="so-wiz-doc-type">
        <button class="so-wiz-toggle-btn active" data-val="cash_sales" onclick="soWizToggle(this)">CS</button>
        <button class="so-wiz-toggle-btn" data-val="delivery_order" onclick="soWizToggle(this)">DO</button>
      </div>
    </div>
    
    <!-- Channel toggle -->
    <div class="so-wiz-section">
      <div class="so-wiz-label">CHANNEL</div>
      <div class="so-wiz-toggle" id="so-wiz-channel">
        <button class="so-wiz-toggle-btn active" data-val="whatsapp" onclick="soWizToggle(this)">WhatsApp</button>
        <button class="so-wiz-toggle-btn" data-val="phone" onclick="soWizToggle(this)">Phone</button>
        <button class="so-wiz-toggle-btn" data-val="walkin" onclick="soWizToggle(this)">Walk-in</button>
      </div>
    </div>
  </div>

  <!-- Step 2: Items -->
  <div class="so-wiz-step" id="so-wiz-step2" style="display:none;">
    <div class="so-wiz-label">ITEMS</div>
    <div id="so-wiz-items-list"></div>
    <div id="so-wiz-picker"></div>
  </div>

  <!-- Step 3: Review -->
  <div class="so-wiz-step" id="so-wiz-step3" style="display:none;">
    <div id="so-wiz-review"></div>
    <div class="so-wiz-section">
      <div class="so-wiz-label">NOTES (OPTIONAL)</div>
      <textarea id="so-wiz-notes" class="so-wiz-input" rows="2" placeholder="Tap to add delivery notes..."></textarea>
    </div>
  </div>

  <!-- Sticky bottom nav -->
  <div class="so-wiz-bottom">
    <button class="btn btn-outline so-wiz-back" id="so-wiz-back" onclick="soWizBack()">← Back</button>
    <button class="btn btn-primary so-wiz-next" id="so-wiz-next" onclick="soWizNext()">Next: Add Items →</button>
  </div>
</div>
```

#### 2.2 Add wizard CSS

In `sales.css`, add wizard styles. Key points:

```css
/* Wizard — hidden on desktop */
.so-wizard { display: none; }

@media (max-width: 768px) {
  /* Hide desktop form, show wizard */
  .so-modal-box { display: none !important; }
  .so-wizard {
    display: flex;
    flex-direction: column;
    background: var(--bg-card);
    width: 100vw;
    height: 100vh;
    overflow-y: auto;
    padding-bottom: 80px; /* space for bottom nav */
  }

  /* Progress bar */
  .so-wiz-progress { height: 3px; background: var(--border); }
  .so-wiz-progress-fill { height: 100%; background: var(--gold); transition: width 0.3s; }

  /* Steps */
  .so-wiz-step { padding: 16px 14px; }
  .so-wiz-title { font-size: 18px; font-weight: 700; color: var(--text); margin-bottom: 16px; }
  .so-wiz-label { font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px; }
  .so-wiz-input { width: 100%; padding: 12px; font-size: 14px; border: 1px solid var(--border); border-radius: 8px; background: var(--bg-input, var(--bg-card)); color: var(--text); font-family: inherit; box-sizing: border-box; }
  .so-wiz-section { margin-bottom: 16px; }
  .so-wiz-row { display: flex; gap: 10px; margin-bottom: 12px; }
  .so-wiz-field { display: flex; flex-direction: column; }

  /* Toggle buttons */
  .so-wiz-toggle { display: flex; border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
  .so-wiz-toggle-btn { flex: 1; text-align: center; padding: 12px 4px; font-size: 13px; font-weight: 600; color: var(--text-muted); background: var(--bg-card); border: none; cursor: pointer; font-family: inherit; }
  .so-wiz-toggle-btn.active { background: var(--gold); color: #fff; font-weight: 700; }

  /* Walk-in */
  .so-wiz-separator { text-align: center; font-size: 11px; color: var(--text-muted); margin: 8px 0; }
  .so-wiz-walkin-btn { width: 100%; padding: 14px; font-size: 14px; font-weight: 600; border: 2px solid var(--border); border-radius: 8px; background: var(--bg-card); color: var(--text); cursor: pointer; font-family: inherit; margin-bottom: 16px; }
  .so-wiz-walkin-btn.active { border-color: var(--gold); background: var(--gold); color: #fff; }

  /* Customer badge */
  .so-wiz-cust-badge { background: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; padding: 12px; display: flex; align-items: center; justify-content: space-between; }
  .so-wiz-dropdown { position: absolute; left: 0; right: 0; background: var(--bg-card); border: 1px solid var(--border); border-radius: 0 0 8px 8px; max-height: 200px; overflow-y: auto; z-index: 10; }

  /* Date display */
  .so-wiz-date-display { background: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; padding: 12px; font-size: 14px; font-weight: 600; color: var(--text); cursor: pointer; }

  /* Variety picker */
  .so-wiz-variety-tabs { display: flex; border-bottom: 1px solid var(--border); }
  .so-wiz-variety-tab { flex: 1; text-align: center; padding: 12px 8px; font-weight: 600; font-size: 13px; color: var(--text-muted); cursor: pointer; border-bottom: 2px solid transparent; }
  .so-wiz-variety-tab.active { color: var(--gold); border-bottom-color: var(--gold); background: rgba(212,175,55,0.06); font-weight: 700; }
  .so-wiz-product-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; padding: 10px; }
  .so-wiz-product-card { background: #FAF6EF; border: 1px solid var(--border); border-radius: 8px; padding: 12px 8px; text-align: center; cursor: pointer; }
  .so-wiz-product-card.selected { border: 2px solid var(--gold); }
  .so-wiz-qty-panel { padding: 10px; border-top: 1px solid var(--border); }
  .so-wiz-qty-input { padding: 14px; font-size: 18px; font-weight: 700; text-align: center; border: 2px solid var(--gold); border-radius: 8px; width: 100%; box-sizing: border-box; }
  .so-wiz-add-btn { background: var(--gold); color: #fff; padding: 14px 16px; border-radius: 8px; font-weight: 700; font-size: 13px; border: none; cursor: pointer; white-space: nowrap; }

  /* Added items */
  .so-wiz-item { background: var(--bg-card); border: 1px solid var(--border); border-radius: 8px; padding: 10px 12px; margin-bottom: 8px; display: flex; align-items: center; justify-content: space-between; }
  .so-wiz-item-remove { width: 28px; height: 28px; border-radius: 50%; border: 1px solid var(--border); display: flex; align-items: center; justify-content: center; color: var(--text-muted); font-size: 14px; cursor: pointer; background: none; }

  /* Review card */
  .so-wiz-review-card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 10px; overflow: hidden; margin-bottom: 12px; }
  .so-wiz-review-row { padding: 12px 14px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
  .so-wiz-review-edit { font-size: 11px; color: var(--gold); font-weight: 600; cursor: pointer; }

  /* Bottom nav */
  .so-wiz-bottom { position: fixed; bottom: 0; left: 0; right: 0; background: #fff; border-top: 2px solid var(--gold); padding: 10px 14px; display: flex; gap: 8px; z-index: 200; }
  .so-wiz-back { flex: 0.4; }
  .so-wiz-next { flex: 1; background: var(--gold); color: #fff; font-weight: 700; font-size: 14px; min-height: 48px; border: none; border-radius: 8px; }
}
```

#### 2.3 Verification

- [ ] Desktop (>768px): `.so-modal-box` visible, `.so-wizard` hidden — desktop form works as before
- [ ] Mobile (≤768px): `.so-modal-box` hidden, `.so-wizard` visible — wizard takes full screen
- [ ] Wizard progress bar renders correctly
- [ ] All three step containers exist, only step 1 visible initially

---

## Phase 3: Wizard JavaScript — Step Navigation & Customer Selection

**Goal:** Wire up step transitions, progress bar, customer search/selection, walk-in toggle.

### Tasks

#### 3.1 Wizard state management

Add new JS variables and navigation functions:

```javascript
var soWizStep = 1;
var soWizIsMobile = function() { return window.innerWidth <= 768; };
```

#### 3.2 Hook into openNewOrderModal()

Modify `openNewOrderModal()` (line 8022) to initialize wizard on mobile:
- After existing reset logic, if `soWizIsMobile()`, call `soWizInit(isEdit)` which:
  - Sets `soWizStep = 1`
  - Shows step 1, hides steps 2 & 3
  - Updates progress bar (33%)
  - Populates delivery date display from `so-delivery-date` value
  - Syncs delivery time from `so-delivery-time`
  - Sets toggle button states from dropdown values
  - If editing, pre-populates wizard fields from order data

#### 3.3 Step navigation (soWizBack, soWizNext)

```javascript
function soWizNext() {
  if (soWizStep === 1) {
    // Validate: customer selected or walk-in
    // Sync wizard fields → desktop form hidden inputs
    soWizStep = 2;
  } else if (soWizStep === 2) {
    // Validate: at least one item
    soWizStep = 3;
    soWizRenderReview();
  }
  soWizShowStep();
}

function soWizBack() {
  if (soWizStep === 1) {
    closeModal('so-modal');
    return;
  }
  soWizStep--;
  soWizShowStep();
}

function soWizShowStep() {
  // Hide all steps, show current
  // Update progress bar width (33% / 66% / 100%)
  // Update bottom bar button labels
  // Scroll to top of wizard
}
```

#### 3.4 Customer search in wizard

The wizard customer search mirrors the desktop search but uses wizard-specific element IDs. On selection, it calls the existing `soSelectCustomer(id)` which sets `soSelectedCustomer` and auto-sets doc type. The wizard then:
- Updates its own badge display
- Syncs doc type toggle to match what `soSelectCustomer` set

#### 3.5 Walk-in toggle in wizard

`soWizToggleWalkIn()` calls the existing `soToggleWalkIn()` and then syncs wizard UI:
- Highlights walk-in button
- Hides customer search section
- Sets fulfillment toggle to Collection
- Sets channel toggle to Walk-in
- Sets doc type toggle to CS

#### 3.6 Toggle buttons

Generic toggle handler:
```javascript
function soWizToggle(btn) {
  var parent = btn.parentElement;
  parent.querySelectorAll('.so-wiz-toggle-btn').forEach(function(b) { b.classList.remove('active'); });
  btn.classList.add('active');
  // Sync value to corresponding desktop dropdown
  var val = btn.getAttribute('data-val');
  // Map parent id to form field and set it
}
```

#### 3.7 Sync wizard → desktop form fields

Before `soSaveOrder()` is called, sync all wizard state to the desktop form fields that `soSaveOrder()` reads. This means:
- Wizard delivery date → `so-delivery-date` input value
- Wizard delivery time → `so-delivery-time` input value
- Wizard fulfillment toggle → `so-fulfillment` dropdown value
- Wizard doc type toggle → `so-doc-type` dropdown value
- Wizard channel toggle → `so-channel` dropdown value
- Wizard notes → `so-notes` textarea value
- `soItems` and `soSelectedCustomer` are already shared — no sync needed

#### 3.8 Verification

- [ ] Wizard opens on mobile with step 1 visible
- [ ] Customer search works — selecting a customer shows badge, auto-sets doc type toggle
- [ ] Walk-in toggle works — sets fulfillment, channel, doc type correctly
- [ ] Next validates customer selected before advancing
- [ ] Back on step 1 closes modal
- [ ] Progress bar updates on each step
- [ ] Edit mode pre-populates all wizard fields

---

## Phase 4: Wizard JavaScript — Variety-Based Item Picker

**Goal:** Build the item picker UI for Step 2 with variety tabs, product grid, qty input.

### Tasks

#### 4.1 Build variety tabs

On entering Step 2, render variety tabs from `varieties` array + "Other" for null variety:

```javascript
function soWizRenderPicker() {
  // Group active products by variety_id
  var grouped = {};
  salesProducts.filter(function(p) { return p.is_active !== false; }).forEach(function(p) {
    var vid = p.variety_id || 'other';
    if (!grouped[vid]) grouped[vid] = [];
    grouped[vid].push(p);
  });
  
  // Build tabs from varieties that have products
  var tabs = [];
  varieties.forEach(function(v) {
    if (grouped[v.id]) tabs.push({ id: v.id, name: v.name });
  });
  if (grouped['other']) tabs.push({ id: 'other', name: 'Other' });
  
  // Render tabs + product grid for first/active tab
}
```

#### 4.2 Product grid rendering

When a variety tab is tapped, render its products as 2-column cards:

```javascript
function soWizRenderProducts(varietyId) {
  // Filter products for this variety
  // Render 2-column grid of product cards
  // Each card shows: product name + "RM{price}/{unit}"
  // onclick: soWizSelectProduct(productId)
}
```

#### 4.3 Qty input panel

When a product is tapped:
1. Highlight the card (gold border)
2. Slide in qty panel below grid: product name, locked price (tappable to edit), large qty input, unit label, "Add RM{total}" button

```javascript
function soWizSelectProduct(productId) {
  // Highlight card
  // Show qty panel with product defaults
  // Price is display-only; tap triggers confirmAction: "Change price from RM{x}?"
  // Qty input: oninput recalculates add button label
}

function soWizAddItem() {
  // Push to soItems array (same structure as soAddItem)
  // Re-render items list above picker
  // Clear qty panel, deselect product card
  // Stay on same variety tab
}
```

#### 4.4 Added items list

Above the picker, render compact cards for items already in `soItems`:

```javascript
function soWizRenderItems() {
  // For each item in soItems:
  // Show: product name, qty × price, line total, × remove button
  // "Add index" link (collapsed) — expands min/max index inputs
  // Subtotal at bottom
}
```

#### 4.5 Verification

- [ ] Variety tabs render from DB data (not hardcoded)
- [ ] Tapping tab shows correct products
- [ ] Tapping product shows qty input with correct price/unit
- [ ] Typing qty updates "Add RM{x}" button live
- [ ] Adding item: appears in list, picker resets
- [ ] Removing item: removed from list and soItems
- [ ] Price edit: requires confirmation tap before editable
- [ ] Ripeness index: hidden by default, expandable per item
- [ ] At least one item required to proceed to Step 3

---

## Phase 5: Wizard JavaScript — Review & Submit

**Goal:** Build Step 3 review screen and wire up final submission.

### Tasks

#### 5.1 Review rendering

```javascript
function soWizRenderReview() {
  // Build summary card:
  // - Customer name + phone (Edit link → soWizStep=1, soWizShowStep())
  // - Delivery date + time + fulfillment (Edit link → step 1)
  // - Doc type + channel badges
  // - Items list with line totals
  // - Grand total
  // Order date small text (tappable to change via calOpen)
}
```

#### 5.2 Submit (Create / Save Changes)

The "Create Order" / "Save Changes" button:

```javascript
function soWizSubmit() {
  // 1. Sync all wizard state → desktop form fields
  soWizSyncToForm();
  // 2. Set notes from wizard textarea
  document.getElementById('so-notes').value = document.getElementById('so-wiz-notes').value;
  // 3. Call existing save function
  soSaveOrder();
}
```

`soWizSyncToForm()` writes wizard toggle values to the hidden desktop dropdowns that `soSaveOrder()` reads.

#### 5.3 Bottom bar button states per step

| Step | Back Button | Next Button |
|---|---|---|
| 1 | "← Back" (closes modal) | "Next: Add Items →" (gold) |
| 2 | "← Back" | "Next: Review →" (gold) |
| 3 | "← Back" | "Create Order" (green #4A7C3F) or "Save Changes" (green) |

Step 3 next button calls `soWizSubmit()` instead of `soWizNext()`.

#### 5.4 After successful save

`soSaveOrder()` already closes the modal and renders the order list. The wizard state resets on next `openNewOrderModal()` call. No additional cleanup needed.

#### 5.5 Verification

- [ ] Review shows all order details correctly
- [ ] Edit links jump to correct step and back
- [ ] Notes transfer correctly
- [ ] Create Order calls soSaveOrder() and succeeds
- [ ] Edit order: Save Changes works with optimistic locking
- [ ] Walk-in order: flows through all 3 steps correctly
- [ ] After save: modal closes, order appears in list

---

## Phase 6: Final Testing & Polish

### Tasks

#### 6.1 Cross-device testing

- [ ] Android Chrome: full wizard flow (create + edit + walk-in)
- [ ] Android Chrome: sticky action bar on each order status
- [ ] Desktop Chrome: zero visual changes (resize window to verify breakpoint)
- [ ] Desktop: create/edit orders with existing form — no regressions

#### 6.2 Edge cases

- [ ] Resize browser mid-wizard (768px boundary) — should not break
- [ ] Open wizard on mobile, rotate to landscape — still works
- [ ] Order with pcs items (order_pcs field) — handles in wizard picker
- [ ] Product with no variety — appears under "Other" tab
- [ ] Customer with branches — branch selection works in wizard
- [ ] beforeunload warning still fires on wizard (salesFormDirty)

#### 6.3 Commit and deploy

- Commit with descriptive message
- Deploy to Netlify
- Push to GitHub
- Update CLAUDE.md with mobile UX entry in Tech Debt / changelog

#### 6.4 Revert plan

If issues found:
```bash
git revert HEAD          # revert last commit
# or for full revert:
git checkout pre-mobile-redesign -- sales.html sales.css shared.css
git commit -m "revert: mobile UX changes"
```
