diff --git a/sales.html b/sales.html
index 2edb018..6230602 100644
--- a/sales.html
+++ b/sales.html
@@ -153,7 +153,7 @@
   <div class="page-header">
     <div>
       <div class="page-title">Invoicing</div>
-      <div class="page-subtitle">QuickBooks invoice management</div>
+      <div class="page-subtitle">Invoice management</div>
     </div>
   </div>
   <div class="page-body"></div>
@@ -942,31 +942,6 @@
   </div>
 </div>
 
-<!-- INVOICE MODAL -->
-<div id="inv-modal" class="modal-overlay" style="display:none;">
-  <div class="modal-box" style="max-width:500px;" onclick="event.stopPropagation()">
-    <div class="modal-header">
-      <div class="modal-title">Mark as Invoiced</div>
-      <button class="modal-close" onclick="closeModal('inv-modal')">
-        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
-      </button>
-    </div>
-    <div id="inv-do-list" style="max-height:200px;overflow-y:auto;margin-bottom:14px;font-size:13px;"></div>
-    <div id="inv-total" style="font-size:14px;font-weight:700;color:var(--text);margin-bottom:14px;"></div>
-    <div class="form-field">
-      <label>QB INVOICE NUMBER <span style="color:var(--red);">*</span></label>
-      <input type="text" id="inv-qb-number" placeholder="e.g., INV-2026-001" style="width:100%;">
-    </div>
-    <div class="form-field">
-      <label>INVOICE DATE</label>
-      <input type="date" id="inv-date" style="width:100%;">
-    </div>
-    <div class="modal-actions">
-      <button class="btn btn-outline" onclick="closeModal('inv-modal')">Cancel</button>
-      <button class="btn btn-primary" id="inv-save-btn" onclick="invSaveInvoice()">Save Invoice</button>
-    </div>
-  </div>
-</div>
 
 <script>
 // CONFIG
@@ -1205,7 +1180,7 @@ function renderDashboard() {
 
   var uninvoicedDO = 0;
   orders.forEach(function(o) {
-    if (o.doc_type === 'delivery_order' && !o.qb_invoice_no && o.status !== 'cancelled') {
+    if (o.doc_type === 'delivery_order' && !o.invoice_id && o.status === 'completed') {
       uninvoicedDO += parseFloat(o.grand_total) || 0;
     }
   });
@@ -3754,22 +3729,21 @@ function renderPayments() {
         if (g.csOrders.length) html += '<div style="border-top:1px solid var(--border);margin:14px 0;"></div>';
 
         html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
-        html += '<div style="font-size:13px;font-weight:700;color:var(--text);">Delivery Orders <span style="font-weight:400;color:var(--text-muted);font-size:11px;">(paid via QB Invoice)</span></div>';
+        html += '<div style="font-size:13px;font-weight:700;color:var(--text);">Delivery Orders <span style="font-weight:400;color:var(--text-muted);font-size:11px;">(paid via Invoice)</span></div>';
         html += '<button class="btn btn-outline btn-sm" onclick="switchTab(\'invoicing\')" style="gap:4px;font-size:11px;">';
         html += '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:12px;height:12px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>';
         html += 'Go to Invoicing</button>';
         html += '</div>';
 
         html += '<div class="table-wrap"><table class="data-table" style="margin:0;">';
-        html += '<thead><tr><th>Doc #</th><th>Date</th><th>Total</th><th>QB Invoice</th><th>Status</th></tr></thead><tbody>';
+        html += '<thead><tr><th>Doc #</th><th>Date</th><th>Total</th><th>Status</th></tr></thead><tbody>';
 
         g.doOrders.forEach(function(o) {
           html += '<tr>';
           html += '<td><a href="javascript:void(0)" onclick="event.stopPropagation();soGoToOrder(\'' + esc(o.id) + '\');" style="font-weight:600;color:var(--purple);text-decoration:none;">' + esc(o.doc_number || o.id) + '</a></td>';
           html += '<td>' + esc(o.order_date || '\u2014') + '</td>';
           html += '<td style="text-align:right;">' + formatRM(parseFloat(o.grand_total) || 0) + '</td>';
-          html += '<td>' + esc(o.qb_invoice_number || '\u2014') + '</td>';
-          html += '<td><span class="badge badge-' + esc(o.payment_status || 'unpaid') + '">' + (o.qb_invoice_number ? 'Invoiced' : 'Uninvoiced') + '</span></td>';
+          html += '<td><span class="badge badge-' + esc(o.payment_status || 'unpaid') + '">' + (o.invoice_id ? 'Invoiced' : 'Uninvoiced') + '</span></td>';
           html += '</tr>';
         });
 
@@ -4078,10 +4052,10 @@ function renderInvoicing() {
   // ---- Section A: Uninvoiced Delivery Orders ----
   html += '<div style="margin-bottom:32px;">';
   html += '<div style="font-size:15px;font-weight:700;color:var(--text);margin-bottom:4px;">Uninvoiced Delivery Orders</div>';
-  html += '<div style="font-size:12px;color:var(--text-muted);margin-bottom:12px;">Select DOs to batch into a QuickBooks invoice</div>';
+  html += '<div style="font-size:12px;color:var(--text-muted);margin-bottom:12px;">Select DOs to batch into an invoice</div>';
 
   var uninvoicedDOs = orders.filter(function(o) {
-    return o.doc_type === 'delivery_order' && !o.qb_invoice_no && o.status !== 'cancelled';
+    return o.doc_type === 'delivery_order' && !o.invoice_id && o.status === 'completed';
   });
 
   // Group by customer
@@ -4135,11 +4109,11 @@ function renderInvoicing() {
       html += '</div>';
     });
 
-    // Action buttons
+    // Action buttons (placeholder — Create Invoice will be added in section 05)
     var selectedCount = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; }).length;
     html += '<div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap;">';
-    html += '<button class="btn btn-primary" id="inv-mark-btn" onclick="invOpenInvoiceModal()"' + (selectedCount === 0 ? ' disabled style="opacity:0.5;cursor:not-allowed;"' : '') + '>';
-    html += 'Mark as Invoiced (' + selectedCount + ' selected)</button>';
+    html += '<button class="btn btn-primary" id="inv-create-btn" disabled style="opacity:0.5;cursor:not-allowed;">';
+    html += 'Create Invoice (' + selectedCount + ' selected)</button>';
     html += '</div>';
 
     // Billing summary (live, updates on selection)
@@ -4147,64 +4121,10 @@ function renderInvoicing() {
   }
   html += '</div>';
 
-  // ---- Section B: Invoice History ----
+  // ---- Section B: Invoice List (placeholder — built in section 06) ----
   html += '<div>';
-  html += '<div style="font-size:15px;font-weight:700;color:var(--text);margin-bottom:4px;">Invoice History</div>';
-  html += '<div style="font-size:12px;color:var(--text-muted);margin-bottom:12px;">Past QuickBooks invoices</div>';
-
-  var invoicedDOs = orders.filter(function(o) {
-    return o.doc_type === 'delivery_order' && o.qb_invoice_no;
-  });
-
-  // Group by QB invoice number
-  var byInvoice = {};
-  invoicedDOs.forEach(function(o) {
-    var key = o.qb_invoice_no;
-    if (!byInvoice[key]) byInvoice[key] = { orders: [], customer_id: o.customer_id, invoiced_at: o.qb_invoiced_at };
-    byInvoice[key].orders.push(o);
-  });
-
-  var invoiceKeys = Object.keys(byInvoice);
-  // Sort by invoiced date (newest first)
-  invoiceKeys.sort(function(a, b) {
-    return (byInvoice[b].invoiced_at || '').localeCompare(byInvoice[a].invoiced_at || '');
-  });
-
-  if (!invoiceKeys.length) {
-    html += '<div class="empty-state">No invoices yet</div>';
-  } else {
-    invoiceKeys.forEach(function(invNo) {
-      var group = byInvoice[invNo];
-      var cust = customers.find(function(c) { return c.id === group.customer_id; });
-      var custName = cust ? cust.name : '\u2014';
-      var total = 0;
-      group.orders.forEach(function(o) { total += parseFloat(o.grand_total) || 0; });
-
-      html += '<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;margin-bottom:10px;overflow:hidden;">';
-
-      html += '<div style="padding:12px 16px;cursor:pointer;display:flex;justify-content:space-between;align-items:center;" onclick="invToggleHistory(\'' + esc(invNo) + '\')">';
-      html += '<div>';
-      html += '<div style="font-weight:700;font-size:14px;color:var(--text);">' + esc(invNo) + '</div>';
-      html += '<div style="font-size:12px;color:var(--text-muted);">' + esc(custName) + ' &middot; ' + group.orders.length + ' DO' + (group.orders.length !== 1 ? 's' : '') + ' &middot; ' + formatRM(total) + '</div>';
-      html += '</div>';
-      html += '<div style="display:flex;align-items:center;gap:8px;">';
-      html += '<span style="font-size:11px;color:var(--text-muted);">' + fmtDateNice(group.invoiced_at) + '</span>';
-      html += '<svg viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="2" style="width:16px;height:16px;" id="inv-h-chevron-' + esc(invNo) + '"><polyline points="6 9 12 15 18 9"/></svg>';
-      html += '</div></div>';
-
-      html += '<div id="inv-h-dos-' + esc(invNo) + '" style="display:none;border-top:1px solid var(--border);padding:8px 16px;">';
-      group.orders.sort(function(a, b) { return (a.order_date || '').localeCompare(b.order_date || ''); });
-      group.orders.forEach(function(o) {
-        html += '<div style="display:flex;justify-content:space-between;padding:5px 0;border-bottom:1px solid var(--border);font-size:13px;">';
-        html += '<span><span style="font-weight:600;">' + esc(o.doc_number || o.id) + '</span> &middot; ' + fmtDateNice(o.order_date) + '</span>';
-        html += '<span style="font-weight:600;">' + formatRM(parseFloat(o.grand_total) || 0) + '</span>';
-        html += '</div>';
-      });
-      html += '</div>';
-
-      html += '</div>';
-    });
-  }
+  html += '<div style="font-size:15px;font-weight:700;color:var(--text);margin-bottom:4px;">Invoices</div>';
+  html += '<div class="empty-state">Invoice list coming soon</div>';
   html += '</div>';
 
   body.innerHTML = html;
@@ -4224,18 +4144,6 @@ function invToggleCustomer(custId) {
   }
 }
 
-function invToggleHistory(invNo) {
-  var el = document.getElementById('inv-h-dos-' + invNo);
-  var chevron = document.getElementById('inv-h-chevron-' + invNo);
-  if (!el) return;
-  if (el.style.display === 'none') {
-    el.style.display = 'block';
-    if (chevron) chevron.style.transform = 'rotate(180deg)';
-  } else {
-    el.style.display = 'none';
-    if (chevron) chevron.style.transform = '';
-  }
-}
 
 function invToggleDO(orderId, custId, checked) {
   if (checked) invSelectedDOs[orderId] = true;
@@ -4508,70 +4416,6 @@ function invPrintSummary() {
   w.document.close();
 }
 
-function invOpenInvoiceModal() {
-  var selectedIds = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; });
-  if (!selectedIds.length) { notify('Select at least one DO', 'warning'); return; }
-
-  var listHtml = '';
-  var total = 0;
-  selectedIds.forEach(function(id) {
-    var o = orders.find(function(x) { return x.id === id; });
-    if (!o) return;
-    total += parseFloat(o.grand_total) || 0;
-    listHtml += '<div style="display:flex;justify-content:space-between;padding:4px 0;border-bottom:1px solid var(--border);font-size:13px;">';
-    listHtml += '<span>' + esc(o.doc_number || o.id) + ' &middot; ' + fmtDateNice(o.order_date) + '</span>';
-    listHtml += '<span style="font-weight:600;">' + formatRM(parseFloat(o.grand_total) || 0) + '</span>';
-    listHtml += '</div>';
-  });
-
-  document.getElementById('inv-do-list').innerHTML = listHtml;
-  document.getElementById('inv-total').innerHTML = 'Total: ' + formatRM(total) + ' (' + selectedIds.length + ' DO' + (selectedIds.length !== 1 ? 's' : '') + ')';
-  document.getElementById('inv-qb-number').value = '';
-  document.getElementById('inv-date').value = todayStr();
-  document.getElementById('inv-modal').style.display = 'flex';
-}
-
-async function invSaveInvoice() {
-  var qbNumber = document.getElementById('inv-qb-number').value.trim();
-  var invDate = document.getElementById('inv-date').value;
-
-  if (!qbNumber) { notify('QB Invoice Number is required', 'warning'); document.getElementById('inv-qb-number').focus(); return; }
-  if (!invDate) { notify('Select invoice date', 'warning'); return; }
-
-  var selectedIds = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; });
-  if (!selectedIds.length) { notify('No DOs selected', 'warning'); return; }
-
-  var btn = document.getElementById('inv-save-btn');
-  btnLoading(btn, true);
-
-  try {
-    // Update each selected order
-    for (var i = 0; i < selectedIds.length; i++) {
-      var orderId = selectedIds[i];
-      var result = await sbQuery(sb.from('sales_orders').update({
-        qb_invoice_no: qbNumber,
-        qb_invoiced_at: invDate
-      }).eq('id', orderId).select());
-      if (result === null) { btnLoading(btn, false, 'Save Invoice'); return; }
-
-      // Update local array
-      var idx = orders.findIndex(function(x) { return x.id === orderId; });
-      if (idx >= 0) {
-        orders[idx].qb_invoice_no = qbNumber;
-        orders[idx].qb_invoiced_at = invDate;
-      }
-    }
-
-    btnLoading(btn, false, 'Save Invoice');
-    closeModal('inv-modal');
-    invSelectedDOs = {};
-    notify(selectedIds.length + ' DO' + (selectedIds.length !== 1 ? 's' : '') + ' invoiced as ' + qbNumber, 'success');
-    renderInvoicing();
-  } catch(e) {
-    btnLoading(btn, false, 'Save Invoice');
-    notify('Failed to save invoice: ' + e.message, 'error');
-  }
-}
 // ============================================================
 // REPORTS
 // ============================================================
