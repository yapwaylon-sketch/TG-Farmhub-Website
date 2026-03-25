# A4 Delivery Order for Cash Sales — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an A4-sized delivery order document (Customer Copy + Office Copy) for cash sales orders alongside the existing 80mm receipt.

**Architecture:** New `soGenerateDocA4()` function generates A4-formatted HTML into a new `#so-doc-a4-content` container within the existing document modal. A `.a4-mode` class on the modal switches `@page` size for printing. Existing 80mm receipt, share, and print infrastructure remain untouched.

**Tech Stack:** Vanilla JS, HTML/CSS, html2canvas (existing), Web Share API (existing)

**Spec:** `docs/superpowers/specs/2026-03-25-a4-delivery-order-cash-sales-design.md`

---

## File Map

All changes are in a single file:
- **Modify:** `sales.html`
  - Lines 479-520: Add A4 styles alongside existing 80mm styles
  - Lines 512-519: Extend `@media print` block with `.a4-mode` rules
  - Line 540: Add `#so-doc-a4-content` container after `#so-doc-content`
  - Lines 1541-1545: Add "A4 Document" button for cash sales completed orders
  - After line 4740: New `soGenerateDocA4()` function
  - Lines 4772-4776: Update `closeDocModal()` to reset both containers
  - Lines 4783-4833: Update `soShareDoc()` to detect active content element
  - Lines 4835-4846: Update `soDownloadDocImage()` for A4 filename suffix

No new files. No database changes.

---

### Task 1: Add A4 Styles

**Files:**
- Modify: `sales.html:490` (after existing `#so-doc-content` styles, before `@media print`)

- [ ] **Step 1: Add A4 document styles**

Insert after line 511 (after `.doc-footer` style rule), before the `@media print` block at line 512:

```css
/* A4 Document Styles */
#so-doc-a4-content { display:none;background:#fff;color:#000;font-family:Arial,Helvetica,sans-serif;width:210mm;padding:15mm;font-size:12px;line-height:1.5;box-sizing:border-box; }
#so-doc-a4-content .a4-page { min-height:267mm;position:relative;box-sizing:border-box; }
#so-doc-a4-content .a4-page + .a4-page { page-break-before:always;margin-top:20px; }
#so-doc-a4-content .a4-letterhead { display:flex;align-items:flex-start;gap:16px;margin-bottom:12px; }
#so-doc-a4-content .a4-letterhead img { width:80px;height:80px;object-fit:contain; }
#so-doc-a4-content .a4-letterhead-text { font-size:11px;line-height:1.4; }
#so-doc-a4-content .a4-letterhead-text h2 { font-size:16px;margin:0 0 2px;font-weight:800;letter-spacing:0.5px; }
#so-doc-a4-content .a4-letterhead-text p { margin:0;color:#333; }
#so-doc-a4-content .a4-divider { border:none;border-top:2px solid #000;margin:10px 0; }
#so-doc-a4-content .a4-title { text-align:center;font-size:18px;font-weight:800;letter-spacing:2px;margin:10px 0 4px; }
#so-doc-a4-content .a4-doc-number { text-align:center;font-size:14px;font-weight:700;margin-bottom:4px; }
#so-doc-a4-content .a4-copy-label { text-align:center;font-size:12px;font-weight:600;color:#555;margin-bottom:12px;text-transform:uppercase;letter-spacing:1px; }
#so-doc-a4-content .a4-info-grid { display:grid;grid-template-columns:120px 1fr 120px 1fr;gap:4px 10px;font-size:12px;margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid #ccc; }
#so-doc-a4-content .a4-info-label { font-weight:700;color:#333; }
#so-doc-a4-content .a4-info-value { color:#000;word-wrap:break-word; }
#so-doc-a4-content .a4-items-table { width:100%;border-collapse:collapse;margin-bottom:12px; }
#so-doc-a4-content .a4-items-table th { background:#f0f0f0;padding:8px 10px;text-align:left;font-size:11px;font-weight:700;border:1px solid #ccc;text-transform:uppercase; }
#so-doc-a4-content .a4-items-table th:nth-child(3),
#so-doc-a4-content .a4-items-table th:nth-child(5),
#so-doc-a4-content .a4-items-table th:nth-child(6) { text-align:right; }
#so-doc-a4-content .a4-items-table td { padding:6px 10px;border:1px solid #ddd;font-size:12px;vertical-align:top; }
#so-doc-a4-content .a4-items-table td:nth-child(3),
#so-doc-a4-content .a4-items-table td:nth-child(5),
#so-doc-a4-content .a4-items-table td:nth-child(6) { text-align:right; }
#so-doc-a4-content .a4-items-table tr { break-inside:avoid; }
#so-doc-a4-content .a4-totals { text-align:right;margin-bottom:16px; }
#so-doc-a4-content .a4-totals div { font-size:12px;margin-bottom:3px; }
#so-doc-a4-content .a4-grand-total { font-size:16px;font-weight:800;padding-top:6px;border-top:2px solid #000;margin-top:4px; }
#so-doc-a4-content .a4-sig-section { display:flex;justify-content:space-between;margin-top:30px;padding-top:16px; }
#so-doc-a4-content .a4-sig-block { width:45%; }
#so-doc-a4-content .a4-sig-block .sig-label { font-size:11px;font-weight:700;margin-bottom:6px; }
#so-doc-a4-content .a4-sig-block .sig-name { font-size:12px;margin-bottom:4px; }
#so-doc-a4-content .a4-sig-block .sig-line { border-bottom:1px solid #000;height:40px;margin-bottom:4px; }
#so-doc-a4-content .a4-sig-block .sig-field-label { font-size:10px;color:#666; }
#so-doc-a4-content .a4-footer { text-align:center;font-size:10px;color:#666;margin-top:20px;padding-top:10px;border-top:1px solid #ccc; }
/* Mobile: scale down A4 preview to fit screen, full size for print */
@media screen and (max-width: 850px) {
  #so-doc-a4-content { width:100%!important;padding:8mm!important;font-size:10px; }
  #so-doc-a4-content .a4-info-grid { grid-template-columns:100px 1fr;font-size:10px; }
  #so-doc-a4-content .a4-title { font-size:15px; }
  #so-doc-a4-content .a4-items-table th, #so-doc-a4-content .a4-items-table td { padding:4px 6px;font-size:10px; }
}
```

- [ ] **Step 2: Extend @media print block for A4 mode**

Replace the existing `@media print` block (lines 512-519) with:

```css
@media print {
  body > *:not(#so-doc-modal) { display:none!important; }
  #so-doc-modal { position:static!important;background:#fff!important;overflow:visible!important;padding:0!important; }
  #so-doc-modal .doc-modal-wrap { box-shadow:none!important;border-radius:0!important;max-height:none!important; }
  #so-doc-modal .doc-toolbar { display:none!important; }
  #so-doc-content { padding:2mm!important;width:80mm!important; }
  @page { size:80mm auto;margin:0; }
  /* A4 mode: hide 80mm, show A4, ensure page breaks */
  #so-doc-modal.a4-mode #so-doc-content { display:none!important; }
  #so-doc-modal.a4-mode #so-doc-a4-content { display:block!important;width:210mm!important;padding:10mm!important; }
  #so-doc-modal.a4-mode .a4-page + .a4-page { page-break-before:always; }
}
```

Note: `@page` size cannot be scoped with a CSS selector, so the A4 `@page` override is handled dynamically in `soPrintDoc()` (see Task 6).

- [ ] **Step 3: Verify styles don't break existing 80mm document**

Open any completed order → View Document → confirm the 80mm receipt renders identically to before.

---

### Task 2: Add A4 Content Container to Modal HTML

**Files:**
- Modify: `sales.html:540-541` (inside the document modal)

- [ ] **Step 1: Add the A4 content div**

At line 540, after `<div id="so-doc-content"></div>` and before the closing `</div>` of `doc-modal-wrap`, add the new container:

Change line 540:
```html
    <div id="so-doc-content"></div>
```

To:
```html
    <div id="so-doc-content"></div>
    <div id="so-doc-a4-content"></div>
```

The `#so-doc-a4-content` starts with `display:none` from CSS (set in Task 1).

---

### Task 3: Add "A4 Document" Button for Cash Sales Orders

**Files:**
- Modify: `sales.html:1541-1545` (order detail action buttons)

- [ ] **Step 1: Add conditional A4 button inside the completed block**

Replace lines 1541-1545:
```javascript
  if (o.status === 'completed') {
    html += '<button class="btn btn-primary" onclick="soGenerateDoc(\'' + esc(o.id) + '\')" style="gap:6px;">';
    html += '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:14px;height:14px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>';
    html += 'View Document</button>';
  }
```

With:
```javascript
  if (o.status === 'completed') {
    html += '<button class="btn btn-primary" onclick="soGenerateDoc(\'' + esc(o.id) + '\')" style="gap:6px;">';
    html += '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:14px;height:14px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>';
    html += 'View Document</button>';
    if (o.doc_type !== 'delivery_order') {
      html += '<button class="btn btn-outline" onclick="soGenerateDocA4(\'' + esc(o.id) + '\')" style="gap:6px;border-color:var(--gold);color:var(--gold);">';
      html += '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:14px;height:14px;"><rect x="3" y="3" width="18" height="18" rx="2"/><line x1="7" y1="8" x2="17" y2="8"/><line x1="7" y1="12" x2="17" y2="12"/><line x1="7" y1="16" x2="13" y2="16"/></svg>';
      html += 'A4 Document</button>';
    }
  }
```

This adds the A4 button only for cash sales (non-DO) completed orders, styled as an outline button with gold color to visually distinguish it from the primary "View Document" button.

---

### Task 4: Create `soGenerateDocA4()` Function

**Files:**
- Modify: `sales.html` — insert after line 4740 (after `soGenerateDoc()` closing brace)

- [ ] **Step 1: Add the A4 document generation function**

Insert this function after line 4740:

```javascript
function soGenerateDocA4(orderId) {
  var o = orders.find(function(x) { return x.id === orderId; });
  if (!o) { notify('Order not found', 'warning'); return; }

  soDocCurrentOrderId = orderId;
  var cust = customers.find(function(c) { return c.id === o.customer_id; });
  var items = orderItems.filter(function(i) { return i.order_id === o.id; });
  var docNumber = esc(o.doc_number || o.id) + ' (A4)';
  var preparedBy = currentUser ? esc(currentUser.displayName) : '—';

  // Build single page content (reused for both copies)
  function buildPage(copyLabel) {
    var html = '<div class="a4-page">';

    // Letterhead
    html += '<div class="a4-letterhead">';
    html += '<img src="assets/logo.png?v=2" alt="TG">';
    html += '<div class="a4-letterhead-text">';
    html += '<h2>TG AGRO FRUITS SDN. BHD.</h2>';
    html += '<p>(201401034124 / 1110222-T)</p>';
    html += '<p>Lot 189, Kampung Riam Jaya, Airport Road,</p>';
    html += '<p>98000 Miri, Sarawak</p>';
    html += '<p>Tel: 012-3286661</p>';
    html += '</div></div>';
    html += '<hr class="a4-divider">';

    // Title
    html += '<div class="a4-title">DELIVERY ORDER</div>';
    html += '<div class="a4-doc-number">' + docNumber + '</div>';
    html += '<div class="a4-copy-label">' + copyLabel + '</div>';

    // Customer Info (4-column grid)
    html += '<div class="a4-info-grid">';
    html += '<div class="a4-info-label">Customer:</div><div class="a4-info-value">' + esc(cust ? cust.name : '—') + '</div>';
    html += '<div class="a4-info-label">Date:</div><div class="a4-info-value">' + fmtDate(o.delivery_date || o.order_date) + '</div>';
    if (cust && cust.phone) {
      html += '<div class="a4-info-label">Phone:</div><div class="a4-info-value">' + esc(cust.phone) + '</div>';
    } else {
      html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
    }
    html += '<div class="a4-info-label">Order Date:</div><div class="a4-info-value">' + fmtDate(o.order_date) + '</div>';
    if (cust && cust.address) {
      html += '<div class="a4-info-label">Address:</div><div class="a4-info-value">' + esc(cust.address) + '</div>';
    } else {
      html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
    }
    if (o.fulfillment === 'delivery' && o.driver_id) {
      var driver = allWorkers.find(function(w) { return w.id === o.driver_id; });
      html += '<div class="a4-info-label">Driver:</div><div class="a4-info-value">' + esc(driver ? driver.name : '—') + '</div>';
    } else {
      html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
    }
    html += '</div>';

    // Items Table
    var subtotal = 0;
    html += '<table class="a4-items-table">';
    html += '<thead><tr><th style="width:40px;">No.</th><th>Description</th><th style="width:60px;">Qty</th><th style="width:60px;">Unit</th><th style="width:90px;">Price (RM)</th><th style="width:100px;">Amount (RM)</th></tr></thead>';
    html += '<tbody>';
    items.forEach(function(item, idx) {
      var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
      var prodName = prod ? prod.name : '—';
      var prodVariety = soGetProductVariety(item.product_id);
      var prodUnit = prod ? (prod.unit || '') : '';
      var fullName = '';
      if (prodVariety && prodVariety !== '—') fullName += prodVariety + ' ';
      fullName += prodName;
      var lineTotal = parseFloat(item.line_total) || 0;
      subtotal += lineTotal;
      var qty = item.quantity || 0;
      var unitPrice = (parseFloat(item.unit_price) || 0).toFixed(2);

      html += '<tr>';
      html += '<td>' + (idx + 1) + '</td>';
      html += '<td>' + esc(fullName) + '</td>';
      html += '<td>' + qty + '</td>';
      html += '<td>' + esc(prodUnit) + '</td>';
      html += '<td>' + unitPrice + '</td>';
      html += '<td>' + lineTotal.toFixed(2) + '</td>';
      html += '</tr>';
    });
    html += '</tbody></table>';

    // Totals
    var returnsTotal = parseFloat(o.returns_total) || 0;
    var grandTotal = parseFloat(o.grand_total) || 0;
    html += '<div class="a4-totals">';
    html += '<div>Subtotal: <strong>RM ' + subtotal.toFixed(2) + '</strong></div>';
    if (returnsTotal > 0) {
      html += '<div>Returns: <strong style="color:#c00;">-RM ' + returnsTotal.toFixed(2) + '</strong></div>';
    }
    html += '<div class="a4-grand-total">TOTAL: RM ' + grandTotal.toFixed(2) + '</div>';
    html += '</div>';

    // Payment
    var payStatus = o.payment_status || 'unpaid';
    var payLabel = payStatus === 'paid' ? 'PAID' : (payStatus === 'partial' ? 'PARTIAL' : 'UNPAID');
    html += '<div style="font-size:12px;margin-bottom:8px;">';
    html += '<strong>Payment:</strong> CASH &nbsp;&nbsp;&nbsp; <strong>Status:</strong> ' + payLabel;
    html += '</div>';

    // Signature Section
    html += '<div class="a4-sig-section">';
    // Prepared By (no signature line — auto from system)
    html += '<div class="a4-sig-block">';
    html += '<div class="sig-label">Prepared By:</div>';
    html += '<div class="sig-name">' + preparedBy + '</div>';
    html += '</div>';
    // Received By (with signature line)
    html += '<div class="a4-sig-block">';
    html += '<div class="sig-label">Received By:</div>';
    html += '<div class="sig-line"></div>';
    html += '<div class="sig-field-label">Name:</div>';
    html += '<div class="sig-line" style="height:20px;"></div>';
    html += '<div class="sig-field-label">Date:</div>';
    html += '<div class="sig-line" style="height:20px;"></div>';
    html += '<div class="sig-field-label">Signature</div>';
    html += '</div>';
    html += '</div>';

    // Footer
    html += '<div class="a4-footer">Thank you for your business</div>';
    html += '</div>'; // close a4-page
    return html;
  }

  // Build both copies
  var fullHtml = buildPage('CUSTOMER COPY') + buildPage('OFFICE COPY');

  // Switch containers: hide 80mm, show A4
  document.getElementById('so-doc-content').style.display = 'none';
  document.getElementById('so-doc-a4-content').innerHTML = fullHtml;
  document.getElementById('so-doc-a4-content').style.display = 'block';
  document.getElementById('so-doc-modal').classList.add('a4-mode');
  document.getElementById('so-doc-modal').style.display = 'flex';
}
```

---

### Task 5: Update `closeDocModal()` to Reset Both Containers

**Files:**
- Modify: `sales.html:4772-4776`

- [ ] **Step 1: Update closeDocModal**

Replace lines 4772-4776:
```javascript
function closeDocModal() {
  document.getElementById('so-doc-modal').style.display = 'none';
  soDocCurrentOrderId = null;
  if (soDocImageUrl) { URL.revokeObjectURL(soDocImageUrl); soDocImageUrl = null; }
  soDocImageBlob = null;
}
```

With:
```javascript
function closeDocModal() {
  var modal = document.getElementById('so-doc-modal');
  modal.style.display = 'none';
  modal.classList.remove('a4-mode');
  document.getElementById('so-doc-content').innerHTML = '';
  document.getElementById('so-doc-content').style.display = '';
  document.getElementById('so-doc-a4-content').innerHTML = '';
  document.getElementById('so-doc-a4-content').style.display = 'none';
  soDocCurrentOrderId = null;
  if (soDocImageUrl) { URL.revokeObjectURL(soDocImageUrl); soDocImageUrl = null; }
  soDocImageBlob = null;
}
```

- [ ] **Step 2: Update `soGenerateDoc()` to reset A4 state**

In the existing `soGenerateDoc()` function, after line 4644 (`soDocCurrentOrderId = orderId;`), add these two lines to ensure the A4 container is hidden when opening the 80mm view:

```javascript
  document.getElementById('so-doc-a4-content').style.display = 'none';
  document.getElementById('so-doc-modal').classList.remove('a4-mode');
  document.getElementById('so-doc-content').style.display = '';
```

This prevents the A4 content from remaining visible if the user switches from A4 to 80mm view without closing the modal.

---

### Task 6: Update `soPrintDoc()` for A4 Support

**Files:**
- Modify: `sales.html:4779-4781`

- [ ] **Step 1: Update print function to handle A4 page size**

Replace lines 4779-4781:
```javascript
function soPrintDoc() {
  window.print();
}
```

With:
```javascript
function soPrintDoc() {
  var isA4 = document.getElementById('so-doc-modal').classList.contains('a4-mode');
  if (isA4) {
    // Dynamically inject A4 @page rule (CSS cannot scope @page to a selector)
    var style = document.createElement('style');
    style.id = 'a4-print-override';
    style.textContent = '@media print { @page { size: A4; margin: 10mm; } }';
    document.head.appendChild(style);
    window.print();
    document.head.removeChild(style);
  } else {
    window.print();
  }
}
```

This temporarily injects an A4 `@page` rule wrapped in `@media print` before printing, then removes it. The injected rule overrides the static 80mm `@page` due to cascade source order.

---

### Task 7: Update `soShareDoc()` and `soDownloadDocImage()` for A4 Support

**Files:**
- Modify: `sales.html:4783-4846`

- [ ] **Step 1: Update soShareDoc to detect active content**

At line 4784, replace:
```javascript
  var docEl = document.getElementById('so-doc-content');
```

With:
```javascript
  var isA4 = document.getElementById('so-doc-modal').classList.contains('a4-mode');
  var docEl = isA4
    ? document.getElementById('so-doc-a4-content').querySelector('.a4-page')
    : document.getElementById('so-doc-content');
```

This shares only the **first `.a4-page`** (Customer Copy) when in A4 mode, avoiding the tall two-page image issue.

At line 4809, replace:
```javascript
      var fileName = (o ? (o.doc_number || o.id) : 'document') + '.png';
```

With:
```javascript
      var fileName = (o ? (o.doc_number || o.id) : 'document') + (isA4 ? ' (A4)' : '') + '.png';
```

- [ ] **Step 2: Update soDownloadDocImage for A4 filename**

At line 4838, replace:
```javascript
  var fileName = (o ? (o.doc_number || o.id) : 'document') + '.png';
```

With:
```javascript
  var isA4 = document.getElementById('so-doc-modal').classList.contains('a4-mode');
  var fileName = (o ? (o.doc_number || o.id) : 'document') + (isA4 ? ' (A4)' : '') + '.png';
```

---

### Task 8: Manual Testing

- [ ] **Step 1: Test 80mm receipt (regression)**

1. Open any completed DO (credit) order
2. Click "View Document" → verify 80mm receipt renders correctly
3. Click Print → verify `@page` is 80mm
4. Click Share → verify image generates and WhatsApp flow works
5. Confirm no "A4 Document" button appears for DO orders

- [ ] **Step 2: Test A4 document for cash sales**

1. Open any completed CS (cash sales) order
2. Verify both "View Document" and "A4 Document" buttons appear
3. Click "A4 Document" → verify:
   - Letterhead with logo, company name, reg number, address, phone
   - Title "DELIVERY ORDER" with doc number + "(A4)"
   - "CUSTOMER COPY" label on first page
   - Customer info grid with all available fields
   - Items table with No., Description, Qty, Unit, Price, Amount columns
   - Totals section with subtotal, returns (if any), grand total
   - Payment: CASH with correct status
   - Prepared By: shows logged-in user name (no signature line)
   - Received By: has signature line, name field, date field

- [ ] **Step 3: Test two-page output**

1. Click Print from A4 view → verify:
   - Page 1: Customer Copy
   - Page 2: Office Copy
   - Both are full A4 pages
   - Page break between them

- [ ] **Step 4: Test sharing**

1. Click Share from A4 view → verify:
   - Only Customer Copy is captured as image
   - Filename includes "(A4)" suffix
   - WhatsApp sharing works

- [ ] **Step 5: Test container switching**

1. Open A4 Document → close modal
2. Open View Document (80mm) → confirm it shows correctly (no A4 remnants)
3. Open View Document → close → open A4 Document → confirm it shows correctly

- [ ] **Step 6: Commit**

```bash
git add sales.html
git commit -m "feat(sales): add A4 delivery order document for cash sales customers

Two-page A4 document (Customer Copy + Office Copy) with full company
letterhead, items table, payment info, and signature block. Available
alongside existing 80mm receipt for completed cash sales orders."
```
