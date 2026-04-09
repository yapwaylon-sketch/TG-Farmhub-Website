diff --git a/sales.html b/sales.html
index 52e0eb5..4f15e07 100644
--- a/sales.html
+++ b/sales.html
@@ -3611,60 +3611,67 @@ function recalcPaymentStatus(orderId) {
 }
 
 // ==================== PAYMENTS TAB ====================
-var payFilterDocType = '';
 var payFilterDateFrom = '';
 var payFilterDateTo = '';
 var payFilterStatus = 'outstanding'; // 'unpaid', 'partial', 'outstanding', ''
 var payFilterSort = 'oldest';
+var invPayFilterCustomer = '';
+var invPayFilterStatus = 'outstanding';
+var invPayFilterFrom = '';
+var invPayFilterTo = '';
 
 function renderPayments() {
   var body = document.getElementById('page-payments').querySelector('.page-body');
   var html = '';
+  html += renderPaymentsCS();
+  html += renderPaymentsInvoice();
+  body.innerHTML = html;
+}
 
-  // Filter bar
-  html += '<div class="filter-bar" style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;align-items:flex-end;">';
-
-  html += '<div class="form-field" style="min-width:120px;">';
-  html += '<label style="font-size:10px;margin-bottom:2px;">DOC TYPE</label>';
-  html += '<select id="pay-f-doctype" onchange="payFilterDocType=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
-  html += '<option value=""' + (payFilterDocType === '' ? ' selected' : '') + '>All</option>';
-  html += '<option value="cash_sales"' + (payFilterDocType === 'cash_sales' ? ' selected' : '') + '>Cash Sales</option>';
-  html += '<option value="delivery_order"' + (payFilterDocType === 'delivery_order' ? ' selected' : '') + '>Delivery Orders</option>';
-  html += '</select></div>';
+function invoiceAgeDays(inv) {
+  if (!inv.due_date) return 0;
+  var today = new Date(); today.setHours(0,0,0,0);
+  var due = new Date(inv.due_date + 'T00:00:00');
+  return Math.floor((today - due) / 86400000);
+}
 
-  html += '<div class="form-field" style="min-width:120px;">';
-  html += '<label style="font-size:10px;margin-bottom:2px;">FROM</label>';
-  html += '<input type="date" id="pay-f-from" value="' + esc(payFilterDateFrom) + '" onchange="payFilterDateFrom=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
-  html += '</div>';
+function invoiceAgingColor(inv) {
+  var days = invoiceAgeDays(inv);
+  if (days <= 0) return 'var(--green-light)';
+  if (days <= 30) return 'var(--gold)';
+  if (days <= 60) return '#E8A020';
+  return 'var(--red)';
+}
 
-  html += '<div class="form-field" style="min-width:120px;">';
-  html += '<label style="font-size:10px;margin-bottom:2px;">TO</label>';
-  html += '<input type="date" id="pay-f-to" value="' + esc(payFilterDateTo) + '" onchange="payFilterDateTo=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
-  html += '</div>';
+function renderPaymentsCS() {
+  var html = '';
+  html += '<div style="font-size:16px;font-weight:800;color:var(--text);margin-bottom:12px;">Cash Sales Payments</div>';
 
-  html += '<div class="form-field" style="min-width:130px;">';
-  html += '<label style="font-size:10px;margin-bottom:2px;">SHOW</label>';
-  html += '<select id="pay-f-status" onchange="payFilterStatus=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
+  // Filter bar
+  html += '<div class="filter-bar" style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;align-items:flex-end;">';
+  html += '<div class="form-field" style="min-width:120px;"><label style="font-size:10px;margin-bottom:2px;">FROM</label>';
+  html += '<input type="date" value="' + esc(payFilterDateFrom) + '" onchange="payFilterDateFrom=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;"></div>';
+  html += '<div class="form-field" style="min-width:120px;"><label style="font-size:10px;margin-bottom:2px;">TO</label>';
+  html += '<input type="date" value="' + esc(payFilterDateTo) + '" onchange="payFilterDateTo=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;"></div>';
+  html += '<div class="form-field" style="min-width:130px;"><label style="font-size:10px;margin-bottom:2px;">SHOW</label>';
+  html += '<select onchange="payFilterStatus=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
   html += '<option value="outstanding"' + (payFilterStatus === 'outstanding' ? ' selected' : '') + '>All Outstanding</option>';
   html += '<option value="unpaid"' + (payFilterStatus === 'unpaid' ? ' selected' : '') + '>Unpaid Only</option>';
   html += '<option value="partial"' + (payFilterStatus === 'partial' ? ' selected' : '') + '>Partial Only</option>';
   html += '<option value=""' + (payFilterStatus === '' ? ' selected' : '') + '>All (incl. Paid)</option>';
   html += '</select></div>';
-
-  html += '<div class="form-field" style="min-width:130px;">';
-  html += '<label style="font-size:10px;margin-bottom:2px;">SORT</label>';
-  html += '<select id="pay-f-sort" onchange="payFilterSort=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
+  html += '<div class="form-field" style="min-width:130px;"><label style="font-size:10px;margin-bottom:2px;">SORT</label>';
+  html += '<select onchange="payFilterSort=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
   html += '<option value="oldest"' + (payFilterSort === 'oldest' ? ' selected' : '') + '>Oldest First</option>';
   html += '<option value="newest"' + (payFilterSort === 'newest' ? ' selected' : '') + '>Newest First</option>';
   html += '<option value="amount"' + (payFilterSort === 'amount' ? ' selected' : '') + '>Amount (Highest)</option>';
   html += '</select></div>';
-
   html += '</div>';
 
-  // Filter orders — only completed orders show in payments
+  // Filter CS orders only
   var filtered = orders.filter(function(o) {
     if (o.status !== 'completed') return false;
-    if (payFilterDocType && o.doc_type !== payFilterDocType) return false;
+    if (o.doc_type !== 'cash_sales') return false;
     if (payFilterDateFrom && o.order_date < payFilterDateFrom) return false;
     if (payFilterDateTo && o.order_date > payFilterDateTo) return false;
     if (payFilterStatus === 'outstanding') return o.payment_status !== 'paid';
@@ -3673,60 +3680,44 @@ function renderPayments() {
     return true;
   });
 
-  // Sort
-  if (payFilterSort === 'oldest') {
-    filtered.sort(function(a, b) { return (a.order_date || '').localeCompare(b.order_date || ''); });
-  } else if (payFilterSort === 'newest') {
-    filtered.sort(function(a, b) { return (b.order_date || '').localeCompare(a.order_date || ''); });
-  } else if (payFilterSort === 'amount') {
-    filtered.sort(function(a, b) { return orderBalance(b) - orderBalance(a); });
-  }
+  if (payFilterSort === 'oldest') filtered.sort(function(a, b) { return (a.order_date || '').localeCompare(b.order_date || ''); });
+  else if (payFilterSort === 'newest') filtered.sort(function(a, b) { return (b.order_date || '').localeCompare(a.order_date || ''); });
+  else if (payFilterSort === 'amount') filtered.sort(function(a, b) { return orderBalance(b) - orderBalance(a); });
 
-  // Group by customer — only count CS for outstanding (DOs go through invoicing)
+  // Group by customer
   var custGroups = {};
   var totalOutstanding = 0;
   filtered.forEach(function(o) {
     var cid = o.customer_id || '_unknown';
-    if (!custGroups[cid]) custGroups[cid] = { csOrders: [], doOrders: [], totalOwed: 0, totalPaid: 0, oldestDays: 0 };
+    if (!custGroups[cid]) custGroups[cid] = { csOrders: [], totalOwed: 0, totalPaid: 0, oldestDays: 0 };
     var bal = orderBalance(o);
-    var isDO = o.doc_type === 'delivery_order';
-    if (isDO) {
-      custGroups[cid].doOrders.push(o);
-    } else {
-      custGroups[cid].csOrders.push(o);
-      custGroups[cid].totalOwed += bal;
-      custGroups[cid].totalPaid += parseFloat(o.amount_paid) || 0;
-      var days = daysBetween(o.order_date);
-      if (days > custGroups[cid].oldestDays) custGroups[cid].oldestDays = days;
-      totalOutstanding += bal;
-    }
+    custGroups[cid].csOrders.push(o);
+    custGroups[cid].totalOwed += bal;
+    custGroups[cid].totalPaid += parseFloat(o.amount_paid) || 0;
+    var days = daysBetween(o.order_date);
+    if (days > custGroups[cid].oldestDays) custGroups[cid].oldestDays = days;
+    totalOutstanding += bal;
   });
 
-  // Convert to array and sort by total owed descending
   var custList = Object.keys(custGroups).map(function(cid) {
     var cust = customers.find(function(c) { return c.id === cid; });
     var g = custGroups[cid];
-    return { id: cid, name: cust ? cust.name : '\u2014', group: g, totalOrders: g.csOrders.length + g.doOrders.length };
+    return { id: cid, name: cust ? cust.name : '\u2014', group: g };
   });
   custList.sort(function(a, b) { return b.group.totalOwed - a.group.totalOwed; });
 
-  // Summary cards (CS only — DOs are handled via invoicing)
-  var totalCSOrders = 0;
-  custList.forEach(function(c) { totalCSOrders += c.group.csOrders.length; });
-  var totalDOOrders = 0;
-  custList.forEach(function(c) { totalDOOrders += c.group.doOrders.length; });
+  // Summary cards
   var custWithDebt = custList.filter(function(c) { return c.group.totalOwed > 0; }).length;
   var overdueCount = custList.filter(function(c) { return c.group.oldestDays > 14 && c.group.totalOwed > 0; }).length;
   html += '<div class="cards-grid" style="grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:10px;margin-bottom:16px;">';
   html += '<div class="summary-card"><div class="sc-label">CS Outstanding</div><div class="sc-value" style="color:var(--gold);">' + formatRM(totalOutstanding) + '</div></div>';
   html += '<div class="summary-card"><div class="sc-label">Customers Owing</div><div class="sc-value">' + custWithDebt + '</div></div>';
-  html += '<div class="summary-card"><div class="sc-label">Cash Sales</div><div class="sc-value">' + totalCSOrders + '</div></div>';
-  html += '<div class="summary-card"><div class="sc-label">Delivery Orders</div><div class="sc-value">' + totalDOOrders + '</div></div>';
+  html += '<div class="summary-card"><div class="sc-label">Cash Sales</div><div class="sc-value">' + filtered.length + '</div></div>';
   html += '<div class="summary-card"><div class="sc-label">Overdue (&gt;14d)</div><div class="sc-value" style="color:' + (overdueCount > 0 ? 'var(--red)' : 'var(--green-light)') + ';">' + overdueCount + '</div></div>';
   html += '</div>';
 
   if (!custList.length) {
-    html += '<div class="empty-state">No matching orders</div>';
+    html += '<div class="empty-state">No matching CS orders</div>';
   } else {
     custList.forEach(function(entry, idx) {
       var g = entry.group;
@@ -3734,128 +3725,239 @@ function renderPayments() {
       var borderStyle = g.totalOwed > 0 && g.oldestDays > 7 ? 'border-left:3px solid ' + ageColor + ';' : '';
       var expandId = 'pay-expand-' + idx;
 
-      // Customer row
       html += '<div class="pay-cust-row" style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;margin-bottom:8px;overflow:hidden;' + borderStyle + '">';
       html += '<div class="pay-cust-header" onclick="payToggleExpand(\'' + expandId + '\')" style="display:flex;justify-content:space-between;align-items:center;padding:12px 16px;cursor:pointer;">';
-
-      // Left: name + order count + age
       html += '<div style="flex:1;min-width:0;">';
       html += '<div style="font-weight:700;font-size:15px;color:var(--white);margin-bottom:2px;">' + esc(entry.name) + '</div>';
-      html += '<div style="font-size:12px;color:var(--text-muted);">';
-      var parts = [];
-      if (g.csOrders.length) parts.push(g.csOrders.length + ' CS');
-      if (g.doOrders.length) parts.push(g.doOrders.length + ' DO');
-      html += parts.join(' &middot; ');
+      html += '<div style="font-size:12px;color:var(--text-muted);">' + g.csOrders.length + ' CS';
       if (g.totalOwed > 0 && g.oldestDays > 0) html += ' &middot; <span style="color:' + ageColor + ';font-weight:600;">Oldest: ' + g.oldestDays + 'd</span>';
-      html += '</div>';
-      html += '</div>';
-
-      // Right: amount owed
+      html += '</div></div>';
       html += '<div style="text-align:right;flex-shrink:0;margin-left:12px;">';
       html += '<div style="font-size:18px;font-weight:800;color:' + (g.totalOwed > 0 ? 'var(--gold-light)' : 'var(--green-light)') + ';">' + formatRM(g.totalOwed) + '</div>';
-      html += '<div style="font-size:11px;color:var(--text-muted);">outstanding</div>';
-      html += '</div>';
-
-      // Expand chevron
+      html += '<div style="font-size:11px;color:var(--text-muted);">outstanding</div></div>';
       html += '<div style="margin-left:10px;color:var(--text-muted);flex-shrink:0;">';
-      html += '<svg class="pay-chevron" id="' + expandId + '-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px;transition:transform .2s;"><polyline points="6 9 12 15 18 9"/></svg>';
+      html += '<svg class="pay-chevron" id="' + expandId + '-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px;transition:transform .2s;"><polyline points="6 9 12 15 18 9"/></svg></div>';
       html += '</div>';
 
-      html += '</div>'; // end header
-
-      // Expandable detail
       html += '<div id="' + expandId + '" style="display:none;border-top:1px solid var(--border);">';
       html += '<div style="padding:12px 16px;">';
 
-      // === CASH SALES SECTION ===
-      if (g.csOrders.length) {
-        var csOwed = 0;
-        g.csOrders.forEach(function(o) { csOwed += orderBalance(o); });
+      html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
+      html += '<div style="font-size:13px;font-weight:700;color:var(--text);">Cash Sales</div>';
+      html += '<button class="btn btn-primary btn-sm" id="pay-sel-btn-' + idx + '" onclick="paySelectedOrders(' + idx + ')" style="display:none;gap:4px;">Pay Selected</button>';
+      html += '</div>';
 
-        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
-        html += '<div style="font-size:13px;font-weight:700;color:var(--text);">Cash Sales</div>';
-        html += '<button class="btn btn-primary btn-sm" id="pay-sel-btn-' + idx + '" onclick="paySelectedOrders(' + idx + ')" style="display:none;gap:4px;">Pay Selected</button>';
-        html += '</div>';
+      html += '<div class="table-wrap"><table class="data-table" style="margin:0;">';
+      html += '<thead><tr><th style="width:30px;"><input type="checkbox" onchange="payToggleAll(' + idx + ',this.checked)"></th><th>Doc #</th><th>Date</th><th>Age</th><th>Total</th><th>Paid</th><th>Balance</th><th>Status</th><th></th></tr></thead><tbody>';
+
+      g.csOrders.forEach(function(o, oi) {
+        var bal = orderBalance(o);
+        var days = daysBetween(o.order_date);
+        var dayColor = days <= 7 ? 'var(--green-light)' : (days <= 14 ? 'var(--gold)' : 'var(--red)');
+        var cbId = 'pay-cb-' + idx + '-' + oi;
+
+        html += '<tr>';
+        html += '<td>';
+        if (bal > 0) html += '<input type="checkbox" class="pay-cb pay-cb-' + idx + '" data-order-id="' + esc(o.id) + '" data-balance="' + bal.toFixed(2) + '" id="' + cbId + '" onchange="payUpdateSelection(' + idx + ')">';
+        html += '</td>';
+        html += '<td><a href="javascript:void(0)" onclick="event.stopPropagation();soGoToOrder(\'' + esc(o.id) + '\');" style="font-weight:600;color:var(--purple);text-decoration:none;">' + esc(o.doc_number || o.id) + '</a></td>';
+        html += '<td>' + esc(o.order_date || '\u2014') + '</td>';
+        html += '<td><span style="color:' + dayColor + ';font-weight:600;">' + days + 'd</span></td>';
+        html += '<td style="text-align:right;">' + formatRM(parseFloat(o.grand_total) || 0) + '</td>';
+        html += '<td style="text-align:right;">' + formatRM(parseFloat(o.amount_paid) || 0) + '</td>';
+        html += '<td style="text-align:right;font-weight:700;color:' + (bal > 0 ? 'var(--gold)' : 'var(--green-light)') + ';">' + formatRM(bal) + '</td>';
+        html += '<td><span class="badge badge-' + esc(o.payment_status || 'unpaid') + '">' + soPaymentLabel(o.payment_status) + '</span></td>';
+        html += '<td>';
+        if (bal > 0) html += '<button class="btn btn-primary btn-sm" onclick="payOpenModal(\'' + esc(o.id) + '\')">Pay</button>';
+        html += '</td>';
+        html += '</tr>';
+
+        var orderPayments = payments.filter(function(p) { return p.order_id === o.id; });
+        if (orderPayments.length) {
+          orderPayments.forEach(function(p) {
+            var methodLabel = p.method === 'bank_transfer' ? 'Bank' : (p.method === 'cheque' ? 'Cheque' : 'Cash');
+            html += '<tr style="background:var(--bg-hover);font-size:11px;">';
+            html += '<td></td>';
+            html += '<td colspan="3" style="padding-left:8px;color:var(--text-muted);">' + fmtDateShort(p.payment_date) + ' &middot; ' + methodLabel + (p.reference ? ' (' + esc(p.reference) + ')' : '');
+            html += ' <a href="javascript:void(0)" onclick="soReprintPayment(\'' + esc(p.id) + '\')" style="color:var(--purple);font-size:10px;margin-left:4px;">Reprint</a>';
+            if (p.slip_url) html += ' <a href="' + esc(p.slip_url) + '" target="_blank" style="color:var(--green-light);font-size:10px;margin-left:4px;">Slip</a>';
+            html += '</td>';
+            html += '<td colspan="3" style="text-align:right;color:var(--green-light);font-weight:600;">+' + formatRM(parseFloat(p.amount) || 0) + '</td>';
+            html += '<td colspan="2"></td>';
+            html += '</tr>';
+          });
+        }
+      });
+      html += '</tbody></table></div>';
+      html += '</div></div></div>';
+    });
+  }
 
-        html += '<div class="table-wrap"><table class="data-table" style="margin:0;">';
-        html += '<thead><tr><th style="width:30px;"><input type="checkbox" onchange="payToggleAll(' + idx + ',this.checked)"></th><th>Doc #</th><th>Date</th><th>Age</th><th>Total</th><th>Paid</th><th>Balance</th><th>Status</th><th></th></tr></thead><tbody>';
+  return html;
+}
 
-        g.csOrders.forEach(function(o, oi) {
-          var bal = orderBalance(o);
-          var days = daysBetween(o.order_date);
-          var dayColor = days <= 7 ? 'var(--green-light)' : (days <= 14 ? 'var(--gold)' : 'var(--red)');
-          var cbId = 'pay-cb-' + idx + '-' + oi;
+function renderPaymentsInvoice() {
+  var html = '';
+  html += '<div style="border-top:2px solid var(--border);margin:24px 0 16px;padding-top:16px;">';
+  html += '<div style="font-size:16px;font-weight:800;color:var(--text);margin-bottom:12px;">Invoice Payments</div>';
 
-          html += '<tr>';
-          html += '<td>';
-          if (bal > 0) html += '<input type="checkbox" class="pay-cb pay-cb-' + idx + '" data-order-id="' + esc(o.id) + '" data-balance="' + bal.toFixed(2) + '" id="' + cbId + '" onchange="payUpdateSelection(' + idx + ')">';
-          html += '</td>';
-          html += '<td><a href="javascript:void(0)" onclick="event.stopPropagation();soGoToOrder(\'' + esc(o.id) + '\');" style="font-weight:600;color:var(--purple);text-decoration:none;">' + esc(o.doc_number || o.id) + '</a></td>';
-          html += '<td>' + esc(o.order_date || '\u2014') + '</td>';
-          html += '<td><span style="color:' + dayColor + ';font-weight:600;">' + days + 'd</span></td>';
-          html += '<td style="text-align:right;">' + formatRM(parseFloat(o.grand_total) || 0) + '</td>';
-          html += '<td style="text-align:right;">' + formatRM(parseFloat(o.amount_paid) || 0) + '</td>';
-          html += '<td style="text-align:right;font-weight:700;color:' + (bal > 0 ? 'var(--gold)' : 'var(--green-light)') + ';">' + formatRM(bal) + '</td>';
-          html += '<td><span class="badge badge-' + esc(o.payment_status || 'unpaid') + '">' + soPaymentLabel(o.payment_status) + '</span></td>';
-          html += '<td>';
-          if (bal > 0) html += '<button class="btn btn-primary btn-sm" onclick="payOpenModal(\'' + esc(o.id) + '\')">Pay</button>';
-          html += '</td>';
-          html += '</tr>';
-
-          // Payment history rows
-          var orderPayments = payments.filter(function(p) { return p.order_id === o.id; });
-          if (orderPayments.length) {
-            orderPayments.forEach(function(p) {
-              var methodLabel = p.method === 'bank_transfer' ? 'Bank' : (p.method === 'cheque' ? 'Cheque' : 'Cash');
-              html += '<tr style="background:var(--bg-hover);font-size:11px;">';
-              html += '<td></td>';
-              html += '<td colspan="3" style="padding-left:8px;color:var(--text-muted);">' + fmtDateShort(p.payment_date) + ' &middot; ' + methodLabel + (p.reference ? ' (' + esc(p.reference) + ')' : '');
-              html += ' <a href="javascript:void(0)" onclick="soReprintPayment(\'' + esc(p.id) + '\')" style="color:var(--purple);font-size:10px;margin-left:4px;">Reprint</a>';
-              if (p.slip_url) html += ' <a href="' + esc(p.slip_url) + '" target="_blank" style="color:var(--green-light);font-size:10px;margin-left:4px;">Slip</a>';
-              html += '</td>';
-              html += '<td colspan="3" style="text-align:right;color:var(--green-light);font-weight:600;">+' + formatRM(parseFloat(p.amount) || 0) + '</td>';
-              html += '<td colspan="2"></td>';
-              html += '</tr>';
-            });
-          }
-        });
+  // Filter bar
+  html += '<div class="filter-bar" style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;align-items:flex-end;">';
+  // Customer dropdown
+  var invCusts = {};
+  invoices.forEach(function(inv) { if (inv.status !== 'cancelled') invCusts[inv.customer_id] = true; });
+  html += '<div class="form-field" style="min-width:140px;"><label style="font-size:10px;margin-bottom:2px;">CUSTOMER</label>';
+  html += '<select onchange="invPayFilterCustomer=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
+  html += '<option value="">All Customers</option>';
+  Object.keys(invCusts).forEach(function(cid) {
+    var c = customers.find(function(x) { return x.id === cid; });
+    if (c) html += '<option value="' + esc(cid) + '"' + (invPayFilterCustomer === cid ? ' selected' : '') + '>' + esc(c.name) + '</option>';
+  });
+  html += '</select></div>';
+  // Status dropdown
+  html += '<div class="form-field" style="min-width:130px;"><label style="font-size:10px;margin-bottom:2px;">SHOW</label>';
+  html += '<select onchange="invPayFilterStatus=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;">';
+  html += '<option value="outstanding"' + (invPayFilterStatus === 'outstanding' ? ' selected' : '') + '>Outstanding</option>';
+  html += '<option value="overdue"' + (invPayFilterStatus === 'overdue' ? ' selected' : '') + '>Overdue</option>';
+  html += '<option value=""' + (invPayFilterStatus === '' ? ' selected' : '') + '>All</option>';
+  html += '</select></div>';
+  // Date range
+  html += '<div class="form-field" style="min-width:120px;"><label style="font-size:10px;margin-bottom:2px;">FROM</label>';
+  html += '<input type="date" value="' + esc(invPayFilterFrom) + '" onchange="invPayFilterFrom=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;"></div>';
+  html += '<div class="form-field" style="min-width:120px;"><label style="font-size:10px;margin-bottom:2px;">TO</label>';
+  html += '<input type="date" value="' + esc(invPayFilterTo) + '" onchange="invPayFilterTo=this.value;renderPayments()" style="width:100%;padding:6px 8px;font-size:12px;"></div>';
+  html += '</div>';
 
-        html += '</tbody></table></div>';
-      }
+  // Filter invoices
+  var filtered = invoices.filter(function(inv) {
+    if (inv.status === 'cancelled') return false;
+    if (invPayFilterStatus === 'outstanding') { if (inv.status !== 'issued' || inv.payment_status === 'paid') return false; }
+    else if (invPayFilterStatus === 'overdue') { if (!isInvoiceOverdue(inv)) return false; }
+    else { if (inv.status === 'draft') return false; }
+    if (invPayFilterCustomer && inv.customer_id !== invPayFilterCustomer) return false;
+    if (invPayFilterFrom && inv.invoice_date < invPayFilterFrom) return false;
+    if (invPayFilterTo && inv.invoice_date > invPayFilterTo) return false;
+    return true;
+  });
 
-      // === DELIVERY ORDERS SECTION ===
-      if (g.doOrders.length) {
-        if (g.csOrders.length) html += '<div style="border-top:1px solid var(--border);margin:14px 0;"></div>';
+  // Summary cards
+  var totalOutstanding = 0, overdueTotal = 0, paymentsThisMonth = 0;
+  var now = new Date();
+  var monthStr = now.getFullYear() + '-' + String(now.getMonth() + 1).padStart(2, '0');
+  filtered.forEach(function(inv) {
+    if (inv.payment_status !== 'paid') totalOutstanding += invoiceBalance(inv);
+    if (isInvoiceOverdue(inv)) overdueTotal += invoiceBalance(inv);
+  });
+  invoicePayments.forEach(function(p) {
+    if (p.payment_date && p.payment_date.substring(0, 7) === monthStr) paymentsThisMonth += parseFloat(p.amount) || 0;
+  });
 
-        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
-        html += '<div style="font-size:13px;font-weight:700;color:var(--text);">Delivery Orders <span style="font-weight:400;color:var(--text-muted);font-size:11px;">(paid via Invoice)</span></div>';
-        html += '<button class="btn btn-outline btn-sm" onclick="switchTab(\'invoicing\')" style="gap:4px;font-size:11px;">';
-        html += '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:12px;height:12px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>';
-        html += 'Go to Invoicing</button>';
-        html += '</div>';
+  html += '<div class="cards-grid" style="grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:10px;margin-bottom:16px;">';
+  html += '<div class="summary-card"><div class="sc-label">Total Outstanding</div><div class="sc-value" style="color:var(--gold);">' + formatRM(totalOutstanding) + '</div></div>';
+  html += '<div class="summary-card"><div class="sc-label">Overdue Amount</div><div class="sc-value" style="color:' + (overdueTotal > 0 ? 'var(--red)' : 'var(--green-light)') + ';">' + formatRM(overdueTotal) + '</div></div>';
+  html += '<div class="summary-card"><div class="sc-label">Payments This Month</div><div class="sc-value" style="color:var(--green-light);">' + formatRM(paymentsThisMonth) + '</div></div>';
+  html += '</div>';
 
-        html += '<div class="table-wrap"><table class="data-table" style="margin:0;">';
-        html += '<thead><tr><th>Doc #</th><th>Date</th><th>Total</th><th>Status</th></tr></thead><tbody>';
+  // Group by customer
+  var custGroups = {};
+  filtered.forEach(function(inv) {
+    var cid = inv.customer_id || '_unknown';
+    if (!custGroups[cid]) custGroups[cid] = { invoices: [], totalOwed: 0, totalPaid: 0, oldestOverdueDays: 0 };
+    var bal = invoiceBalance(inv);
+    custGroups[cid].invoices.push(inv);
+    if (inv.payment_status !== 'paid') custGroups[cid].totalOwed += bal;
+    custGroups[cid].totalPaid += parseFloat(inv.amount_paid) || 0;
+    var ageDays = invoiceAgeDays(inv);
+    if (ageDays > custGroups[cid].oldestOverdueDays) custGroups[cid].oldestOverdueDays = ageDays;
+  });
 
-        g.doOrders.forEach(function(o) {
-          html += '<tr>';
-          html += '<td><a href="javascript:void(0)" onclick="event.stopPropagation();soGoToOrder(\'' + esc(o.id) + '\');" style="font-weight:600;color:var(--purple);text-decoration:none;">' + esc(o.doc_number || o.id) + '</a></td>';
-          html += '<td>' + esc(o.order_date || '\u2014') + '</td>';
-          html += '<td style="text-align:right;">' + formatRM(parseFloat(o.grand_total) || 0) + '</td>';
-          html += '<td><span class="badge badge-' + esc(o.payment_status || 'unpaid') + '">' + (o.invoice_id ? 'Invoiced' : 'Uninvoiced') + '</span></td>';
-          html += '</tr>';
-        });
+  var custList = Object.keys(custGroups).map(function(cid) {
+    var c = customers.find(function(x) { return x.id === cid; });
+    return { id: cid, name: c ? c.name : '—', group: custGroups[cid] };
+  });
+  custList.sort(function(a, b) { return b.group.totalOwed - a.group.totalOwed; });
 
-        html += '</tbody></table></div>';
-      }
+  if (!custList.length) {
+    html += '<div class="empty-state">' + (invoices.length ? 'No matching invoices' : 'No invoices yet. Create invoices in the Invoicing tab.') + '</div>';
+  } else {
+    custList.forEach(function(entry, idx) {
+      var g = entry.group;
+      var overdueDays = g.oldestOverdueDays;
+      var ageColor = overdueDays <= 0 ? 'var(--green-light)' : (overdueDays <= 30 ? 'var(--gold)' : (overdueDays <= 60 ? '#E8A020' : 'var(--red)'));
+      var borderStyle = g.totalOwed > 0 && overdueDays > 0 ? 'border-left:3px solid ' + ageColor + ';' : '';
+      var expandId = 'invpay-expand-' + idx;
+
+      html += '<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;margin-bottom:8px;overflow:hidden;' + borderStyle + '">';
+      html += '<div onclick="payToggleExpand(\'' + expandId + '\')" style="display:flex;justify-content:space-between;align-items:center;padding:12px 16px;cursor:pointer;">';
+      html += '<div style="flex:1;min-width:0;">';
+      html += '<div style="font-weight:700;font-size:15px;color:var(--white);margin-bottom:2px;">' + esc(entry.name) + '</div>';
+      html += '<div style="font-size:12px;color:var(--text-muted);">' + g.invoices.length + ' invoice' + (g.invoices.length !== 1 ? 's' : '');
+      if (overdueDays > 0) html += ' &middot; <span style="color:' + ageColor + ';font-weight:600;">' + overdueDays + 'd overdue</span>';
+      html += '</div></div>';
+      html += '<div style="text-align:right;flex-shrink:0;margin-left:12px;">';
+      html += '<div style="font-size:18px;font-weight:800;color:' + (g.totalOwed > 0 ? 'var(--gold-light)' : 'var(--green-light)') + ';">' + formatRM(g.totalOwed) + '</div>';
+      html += '<div style="font-size:11px;color:var(--text-muted);">outstanding</div></div>';
+      html += '<div style="margin-left:10px;color:var(--text-muted);flex-shrink:0;">';
+      html += '<svg id="' + expandId + '-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px;transition:transform .2s;"><polyline points="6 9 12 15 18 9"/></svg></div>';
+      html += '</div>';
 
-      html += '</div>'; // end padding
-      html += '</div>'; // end expandable
-      html += '</div>'; // end customer row
+      // Expanded detail
+      html += '<div id="' + expandId + '" style="display:none;border-top:1px solid var(--border);">';
+      html += '<div style="padding:12px 16px;">';
+      html += '<div class="table-wrap"><table class="data-table" style="margin:0;">';
+      html += '<thead><tr><th>Invoice #</th><th>Date</th><th>Due</th><th>Age</th><th>Total</th><th>Paid</th><th>Credits</th><th>Balance</th><th>Status</th><th></th></tr></thead><tbody>';
+
+      g.invoices.forEach(function(inv) {
+        var bal = invoiceBalance(inv);
+        var ageDays = invoiceAgeDays(inv);
+        var ageLabel = ageDays > 0 ? ageDays + 'd' : (ageDays === 0 ? 'Due' : Math.abs(ageDays) + 'd left');
+        var invAgeColor = invoiceAgingColor(inv);
+
+        html += '<tr>';
+        html += '<td><a href="javascript:void(0)" onclick="event.stopPropagation();switchTab(\'invoicing\')" style="font-weight:600;color:var(--purple);text-decoration:none;">' + esc(inv.id) + '</a></td>';
+        html += '<td>' + fmtDateShort(inv.invoice_date) + '</td>';
+        html += '<td>' + fmtDateShort(inv.due_date) + '</td>';
+        html += '<td><span style="color:' + invAgeColor + ';font-weight:600;">' + ageLabel + '</span></td>';
+        html += '<td style="text-align:right;">' + formatRM(parseFloat(inv.grand_total) || 0) + '</td>';
+        html += '<td style="text-align:right;">' + formatRM(parseFloat(inv.amount_paid) || 0) + '</td>';
+        html += '<td style="text-align:right;">' + (parseFloat(inv.credit_total) > 0 ? formatRM(parseFloat(inv.credit_total)) : '—') + '</td>';
+        html += '<td style="text-align:right;font-weight:700;color:' + (bal > 0 ? 'var(--gold)' : 'var(--green-light)') + ';">' + formatRM(bal) + '</td>';
+        html += '<td><span class="badge badge-' + esc(inv.payment_status || 'unpaid') + '">' + soPaymentLabel(inv.payment_status) + '</span></td>';
+        html += '<td>';
+        if (bal > 0 && inv.status === 'issued') html += '<button class="btn btn-primary btn-sm" onclick="invOpenPaymentModal(\'' + esc(inv.id) + '\')">Pay</button>';
+        html += '</td>';
+        html += '</tr>';
+
+        // Payment history sub-rows
+        var invPays = invoicePayments.filter(function(p) { return p.invoice_id === inv.id; });
+        invPays.forEach(function(p) {
+          var ml = p.method === 'bank_transfer' ? 'Bank Transfer' : p.method === 'cash' ? 'Cash' : p.method === 'cheque' ? 'Cheque' : (p.method || '');
+          html += '<tr style="background:var(--bg-hover);font-size:11px;">';
+          html += '<td></td>';
+          html += '<td colspan="4" style="padding-left:8px;color:var(--text-muted);">' + fmtDateShort(p.payment_date) + ' &middot; ' + ml + (p.reference ? ' (' + esc(p.reference) + ')' : '');
+          if (p.slip_url) html += ' <a href="' + esc(p.slip_url) + '" target="_blank" style="color:var(--gold);font-size:10px;margin-left:4px;">Slip</a>';
+          html += '</td>';
+          html += '<td colspan="3" style="text-align:right;color:var(--green-light);font-weight:600;">+' + formatRM(parseFloat(p.amount) || 0) + '</td>';
+          html += '<td colspan="2"></td></tr>';
+        });
+        // Credit note sub-rows
+        var invCNs = creditNotes.filter(function(cn) { return cn.invoice_id === inv.id; });
+        invCNs.forEach(function(cn) {
+          html += '<tr style="background:var(--bg-hover);font-size:11px;">';
+          html += '<td></td>';
+          html += '<td colspan="4" style="padding-left:8px;color:var(--text-muted);">' + fmtDateShort(cn.credit_date) + ' &middot; Credit Note &middot; ' + esc(cn.id) + (cn.reason ? ' — ' + esc(cn.reason) : '') + '</td>';
+          html += '<td colspan="3" style="text-align:right;color:var(--green-light);font-weight:600;">+' + formatRM(parseFloat(cn.amount) || 0) + '</td>';
+          html += '<td colspan="2"></td></tr>';
+        });
+      });
+
+      html += '</tbody></table></div>';
+      html += '</div></div></div>';
     });
   }
 
-  body.innerHTML = html;
+  html += '</div>';
+  return html;
 }
 
 function payToggleExpand(id) {
