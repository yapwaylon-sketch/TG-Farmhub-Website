diff --git a/sales.html b/sales.html
index 1602711..0288410 100644
--- a/sales.html
+++ b/sales.html
@@ -4143,13 +4143,11 @@ function renderInvoicing() {
   }
   html += '</div>';
 
-  // ---- Section B: Invoice List (placeholder — built in section 06) ----
-  html += '<div>';
-  html += '<div style="font-size:15px;font-weight:700;color:var(--text);margin-bottom:4px;">Invoices</div>';
-  html += '<div class="empty-state">Invoice list coming soon</div>';
-  html += '</div>';
+  // ---- Section B: Invoice List ----
+  html += '<div id="inv-list-container"></div>';
 
   body.innerHTML = html;
+  invRenderList();
 }
 
 // Invoicing helpers
@@ -4442,6 +4440,352 @@ function invPrintSummary() {
   w.document.close();
 }
 
+// ── Invoice List ──
+var invFilterCustomer = '';
+var invFilterStatus = '';
+var invFilterDateFrom = '';
+var invFilterDateTo = '';
+var invExpandedId = null;
+
+function invGetDisplayStatus(inv) {
+  if (inv.status === 'cancelled') return 'cancelled';
+  if (inv.status === 'draft') return 'draft';
+  if (isInvoiceOverdue(inv)) return 'overdue';
+  if (inv.payment_status === 'paid') return 'paid';
+  if (inv.payment_status === 'partial') return 'partial';
+  return 'issued';
+}
+
+function invStatusBadge(status) {
+  var styles = {
+    draft: 'background:#666;color:#fff;',
+    issued: 'background:var(--info);color:#fff;',
+    overdue: 'background:var(--danger);color:#fff;',
+    partial: 'background:var(--gold);color:#000;',
+    paid: 'background:var(--green);color:#fff;',
+    cancelled: 'background:var(--border);color:var(--text-muted);'
+  };
+  var labels = { draft:'Draft', issued:'Issued', overdue:'Overdue', partial:'Partial', paid:'Paid', cancelled:'Cancelled' };
+  return '<span style="display:inline-block;padding:2px 8px;border-radius:4px;font-size:11px;font-weight:700;' + (styles[status] || '') + '">' + (labels[status] || status) + '</span>';
+}
+
+function invRenderList() {
+  var container = document.getElementById('inv-list-container');
+  if (!container) return;
+
+  var html = '';
+  html += '<div style="font-size:15px;font-weight:700;color:var(--text);margin-bottom:12px;margin-top:8px;">Invoices</div>';
+
+  // Filter bar
+  html += '<div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px;">';
+  html += '<select onchange="invFilterStatus=this.value;invRenderList()" style="min-width:120px;">';
+  ['', 'draft', 'issued', 'overdue', 'partial', 'paid', 'cancelled'].forEach(function(s) {
+    var label = s ? (s.charAt(0).toUpperCase() + s.slice(1)) : 'All Status';
+    html += '<option value="' + s + '"' + (invFilterStatus === s ? ' selected' : '') + '>' + label + '</option>';
+  });
+  html += '</select>';
+
+  // Customer filter
+  var invCustIds = {};
+  invoices.forEach(function(inv) { if (inv.customer_id) invCustIds[inv.customer_id] = true; });
+  html += '<select onchange="invFilterCustomer=this.value;invRenderList()" style="min-width:140px;">';
+  html += '<option value=""' + (invFilterCustomer === '' ? ' selected' : '') + '>All Customers</option>';
+  Object.keys(invCustIds).forEach(function(cid) {
+    var c = customers.find(function(x) { return x.id === cid; });
+    var cname = c ? c.name : cid;
+    html += '<option value="' + esc(cid) + '"' + (invFilterCustomer === cid ? ' selected' : '') + '>' + esc(cname) + '</option>';
+  });
+  html += '</select>';
+
+  html += '<input type="date" value="' + esc(invFilterDateFrom) + '" onchange="invFilterDateFrom=this.value;invRenderList()" placeholder="From" style="min-width:130px;">';
+  html += '<input type="date" value="' + esc(invFilterDateTo) + '" onchange="invFilterDateTo=this.value;invRenderList()" placeholder="To" style="min-width:130px;">';
+  html += '</div>';
+
+  // Apply filters
+  var filtered = invoices.filter(function(inv) {
+    if (invFilterCustomer && inv.customer_id !== invFilterCustomer) return false;
+    if (invFilterStatus) {
+      var ds = invGetDisplayStatus(inv);
+      if (invFilterStatus !== ds) return false;
+    }
+    if (invFilterDateFrom && inv.invoice_date < invFilterDateFrom) return false;
+    if (invFilterDateTo && inv.invoice_date > invFilterDateTo) return false;
+    return true;
+  });
+
+  // Summary cards (exclude cancelled from summaries)
+  var activeInvs = invoices.filter(function(inv) { return inv.status !== 'cancelled'; });
+  var totalOutstanding = 0, overdueCount = 0, overdueTotal = 0, monthCount = 0, monthTotal = 0;
+  var thisMonth = todayStr().substring(0, 7);
+  activeInvs.forEach(function(inv) {
+    if (inv.status === 'issued' && inv.payment_status !== 'paid') totalOutstanding += invoiceBalance(inv);
+    if (isInvoiceOverdue(inv)) { overdueCount++; overdueTotal += invoiceBalance(inv); }
+    if ((inv.invoice_date || '').substring(0, 7) === thisMonth) { monthCount++; monthTotal += parseFloat(inv.grand_total) || 0; }
+  });
+
+  html += '<div style="display:flex;flex-wrap:wrap;gap:10px;margin-bottom:16px;">';
+  html += '<div style="flex:1;min-width:150px;background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:12px;">';
+  html += '<div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Outstanding</div>';
+  html += '<div style="font-size:18px;font-weight:700;color:var(--gold-light);">' + formatRM(totalOutstanding) + '</div></div>';
+  html += '<div style="flex:1;min-width:150px;background:var(--bg-card);border:1px solid ' + (overdueCount > 0 ? 'var(--danger)' : 'var(--border)') + ';border-radius:10px;padding:12px;">';
+  html += '<div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Overdue</div>';
+  html += '<div style="font-size:18px;font-weight:700;color:' + (overdueCount > 0 ? 'var(--danger)' : 'var(--text)') + ';">' + overdueCount + ' &middot; ' + formatRM(overdueTotal) + '</div></div>';
+  html += '<div style="flex:1;min-width:150px;background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:12px;">';
+  html += '<div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">This Month</div>';
+  html += '<div style="font-size:18px;font-weight:700;color:var(--text);">' + monthCount + ' &middot; ' + formatRM(monthTotal) + '</div></div>';
+  html += '</div>';
+
+  // Invoice cards
+  if (!filtered.length) {
+    html += '<div class="empty-state">' + (invoices.length ? 'No invoices match your filters.' : 'No invoices yet. Create one above.') + '</div>';
+  } else {
+    // Sort newest first
+    filtered.sort(function(a, b) { return (b.created_at || b.invoice_date || '').localeCompare(a.created_at || a.invoice_date || ''); });
+
+    filtered.forEach(function(inv) {
+      var c = customers.find(function(x) { return x.id === inv.customer_id; });
+      var custName = c ? c.name : '\u2014';
+      var ds = invGetDisplayStatus(inv);
+      var balance = invoiceBalance(inv);
+      var dimStyle = inv.status === 'cancelled' ? 'opacity:0.5;' : '';
+      var isExpanded = invExpandedId === inv.id;
+
+      html += '<div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;margin-bottom:10px;overflow:hidden;' + dimStyle + '">';
+
+      // Card header
+      html += '<div style="padding:12px 16px;cursor:pointer;display:flex;justify-content:space-between;align-items:center;" onclick="invToggleInvoice(\'' + esc(inv.id) + '\')">';
+      html += '<div style="flex:1;">';
+      html += '<div style="font-weight:700;font-size:14px;color:var(--text);">' + esc(inv.id) + ' ' + invStatusBadge(ds) + '</div>';
+      html += '<div style="font-size:12px;color:var(--text-muted);margin-top:2px;">' + esc(custName) + ' &middot; ' + fmtDateNice(inv.invoice_date) + ' &middot; Due ' + fmtDateNice(inv.due_date) + '</div>';
+      if (ds === 'overdue') {
+        var overdueDays = Math.floor((new Date() - new Date(inv.due_date + 'T00:00:00')) / 86400000);
+        html += '<div style="font-size:11px;color:var(--danger);margin-top:2px;">Overdue ' + overdueDays + ' days</div>';
+      }
+      html += '</div>';
+      html += '<div style="text-align:right;">';
+      html += '<div style="font-weight:700;color:var(--text);">' + formatRM(parseFloat(inv.grand_total) || 0) + '</div>';
+      if (balance > 0 && inv.status !== 'cancelled') html += '<div style="font-size:11px;color:var(--gold);">Balance: ' + formatRM(balance) + '</div>';
+      html += '</div>';
+      html += '<svg viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="2" style="width:16px;height:16px;margin-left:8px;transition:transform 0.2s;' + (isExpanded ? 'transform:rotate(180deg);' : '') + '"><polyline points="6 9 12 15 18 9"/></svg>';
+      html += '</div>';
+
+      // Expanded detail
+      if (isExpanded) {
+        html += '<div style="border-top:1px solid var(--border);padding:16px;">';
+
+        // Items table
+        var invItems = invoiceItems.filter(function(ii) { return ii.invoice_id === inv.id; });
+        if (invItems.length) {
+          html += '<div style="font-size:13px;font-weight:700;color:var(--text);margin-bottom:8px;">Items</div>';
+          html += '<div class="table-wrap"><table class="data-table" style="margin:0;"><thead><tr><th>#</th><th>Product</th><th style="text-align:right;">Qty</th><th style="text-align:right;">Price</th><th style="text-align:right;">Amount</th></tr></thead><tbody>';
+          invItems.forEach(function(ii, idx) {
+            html += '<tr><td>' + (idx + 1) + '</td><td>' + esc(ii.product_name || '\u2014') + '</td>';
+            html += '<td style="text-align:right;">' + (ii.quantity || 0) + '</td>';
+            html += '<td style="text-align:right;">' + formatRM(parseFloat(ii.unit_price) || 0) + '</td>';
+            html += '<td style="text-align:right;font-weight:600;">' + formatRM(parseFloat(ii.line_total) || 0) + '</td></tr>';
+          });
+          html += '</tbody></table></div>';
+        }
+
+        // Linked DOs
+        var linkedOrders = invoiceOrders.filter(function(io) { return io.invoice_id === inv.id; });
+        if (linkedOrders.length) {
+          html += '<div style="font-size:13px;font-weight:700;color:var(--text);margin-top:12px;margin-bottom:4px;">Linked DOs</div>';
+          html += '<div style="font-size:12px;color:var(--text-muted);">';
+          var doList = linkedOrders.map(function(io) {
+            var o = orders.find(function(x) { return x.id === io.order_id; });
+            return o ? (o.doc_number || o.id) + ' (' + fmtDateNice(o.order_date) + ')' : io.order_id;
+          });
+          html += doList.join(', ');
+          html += '</div>';
+        }
+
+        // Payment history
+        var invPays = invoicePayments.filter(function(p) { return p.invoice_id === inv.id; });
+        html += '<div style="font-size:13px;font-weight:700;color:var(--text);margin-top:12px;margin-bottom:4px;">Payments</div>';
+        if (invPays.length) {
+          invPays.forEach(function(p) {
+            html += '<div style="font-size:12px;color:var(--text-muted);padding:3px 0;">' + fmtDateNice(p.payment_date) + ' &middot; ' + formatRM(parseFloat(p.amount) || 0) + ' &middot; ' + esc(p.method || '') + (p.reference ? ' (' + esc(p.reference) + ')' : '') + '</div>';
+          });
+        } else {
+          html += '<div style="font-size:12px;color:var(--text-muted);">No payments yet</div>';
+        }
+
+        // Credit notes
+        var invCNs = creditNotes.filter(function(cn) { return cn.invoice_id === inv.id; });
+        html += '<div style="font-size:13px;font-weight:700;color:var(--text);margin-top:12px;margin-bottom:4px;">Credit Notes</div>';
+        if (invCNs.length) {
+          invCNs.forEach(function(cn) {
+            html += '<div style="font-size:12px;color:var(--text-muted);padding:3px 0;">' + esc(cn.id) + ' &middot; ' + fmtDateNice(cn.cn_date) + ' &middot; ' + formatRM(parseFloat(cn.amount) || 0) + (cn.reason ? ' &middot; ' + esc(cn.reason) : '') + '</div>';
+          });
+        } else {
+          html += '<div style="font-size:12px;color:var(--text-muted);">No credit notes</div>';
+        }
+
+        // Action buttons
+        html += '<div style="margin-top:14px;display:flex;flex-wrap:wrap;gap:6px;">';
+        if (inv.status === 'draft') {
+          html += '<button class="btn btn-primary btn-sm" onclick="event.stopPropagation();invApproveInvoice(\'' + esc(inv.id) + '\')">Approve</button>';
+          html += '<button class="btn btn-outline btn-sm" onclick="event.stopPropagation();invAddMoreDOs(\'' + esc(inv.id) + '\')">Add More DOs</button>';
+        }
+        if (inv.status === 'issued') {
+          html += '<button class="btn btn-primary btn-sm" onclick="event.stopPropagation();invOpenPaymentModal(\'' + esc(inv.id) + '\')">Record Payment</button>';
+          html += '<button class="btn btn-outline btn-sm" onclick="event.stopPropagation();invOpenCNModal(\'' + esc(inv.id) + '\')">Add Credit Note</button>';
+        }
+        if (inv.status === 'issued' || inv.payment_status === 'partial' || inv.payment_status === 'paid') {
+          html += '<button class="btn btn-outline btn-sm" onclick="event.stopPropagation();generateInvoiceA4(\'' + esc(inv.id) + '\')" style="gap:4px;border-color:var(--gold);color:var(--gold);">Print</button>';
+        }
+        if (inv.status !== 'cancelled' && inv.status !== 'paid' && inv.payment_status !== 'paid') {
+          html += '<button class="btn btn-outline btn-sm" onclick="event.stopPropagation();invCancelInvoice(\'' + esc(inv.id) + '\')" style="border-color:var(--danger);color:var(--danger);">Cancel</button>';
+        }
+        html += '</div>';
+
+        html += '</div>'; // end detail
+      }
+
+      html += '</div>'; // end card
+    });
+  }
+
+  container.innerHTML = html;
+}
+
+function invToggleInvoice(invoiceId) {
+  invExpandedId = invExpandedId === invoiceId ? null : invoiceId;
+  invRenderList();
+}
+
+// Stub functions for future sections
+function invApproveInvoice(invoiceId) { notify('Approve workflow coming in next update', 'info'); }
+function invOpenPaymentModal(invoiceId) { notify('Invoice payment coming in next update', 'info'); }
+function invOpenCNModal(invoiceId) { notify('Credit notes coming in next update', 'info'); }
+function generateInvoiceA4(invoiceId) { notify('Invoice document coming in next update', 'info'); }
+
+async function invAddMoreDOs(invoiceId) {
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv || inv.status !== 'draft') { notify('Can only add DOs to draft invoices', 'warning'); return; }
+
+  var moreDOs = getCustomerUninvoicedDOs(inv.customer_id);
+  if (!moreDOs.length) { notify('No more uninvoiced DOs for this customer', 'info'); return; }
+
+  // Build selection HTML
+  var selHtml = '<div style="max-height:300px;overflow-y:auto;">';
+  moreDOs.forEach(function(o) {
+    selHtml += '<label style="display:flex;align-items:center;gap:10px;padding:6px 0;border-bottom:1px solid var(--border);cursor:pointer;font-size:13px;">';
+    selHtml += '<input type="checkbox" data-oid="' + esc(o.id) + '">';
+    selHtml += '<span style="flex:1;"><span style="font-weight:600;">' + esc(o.doc_number || o.id) + '</span> &middot; ' + fmtDateNice(o.order_date) + '</span>';
+    selHtml += '<span style="font-weight:600;">' + formatRM(parseFloat(o.grand_total) || 0) + '</span>';
+    selHtml += '</label>';
+  });
+  selHtml += '</div>';
+
+  confirmAction('Add DOs to ' + invoiceId, selHtml, async function() {
+    var modal = document.getElementById('tg-confirm-modal');
+    var checks = modal ? modal.querySelectorAll('input[type="checkbox"]:checked') : [];
+    var addIds = [];
+    checks.forEach(function(cb) { addIds.push(cb.getAttribute('data-oid')); });
+    if (!addIds.length) { notify('No DOs selected', 'warning'); return; }
+
+    try {
+      // Insert junction records
+      var juncArr = addIds.map(function(oid) { return { invoice_id: invoiceId, order_id: oid }; });
+      var jResult = await sbQuery(sb.from('sales_invoice_orders').insert(juncArr).select());
+      if (jResult === null) return;
+      (jResult || []).forEach(function(j) { invoiceOrders.push(j); });
+
+      // Update orders
+      for (var i = 0; i < addIds.length; i++) {
+        await sbQuery(sb.from('sales_orders').update({ invoice_id: invoiceId }).eq('id', addIds[i]).is('invoice_id', null).select());
+        var idx = orders.findIndex(function(x) { return x.id === addIds[i]; });
+        if (idx >= 0) orders[idx].invoice_id = invoiceId;
+      }
+
+      // Re-aggregate items: delete old, re-insert
+      await sbQuery(sb.from('sales_invoice_items').delete().eq('invoice_id', invoiceId));
+      invoiceItems = invoiceItems.filter(function(ii) { return ii.invoice_id !== invoiceId; });
+
+      var allOrderIds = invoiceOrders.filter(function(io) { return io.invoice_id === invoiceId; }).map(function(io) { return io.order_id; });
+      var productAgg = {};
+      allOrderIds.forEach(function(oid) {
+        orderItems.filter(function(it) { return it.order_id === oid; }).forEach(function(item) {
+          var up = parseFloat(item.unit_price) || 0;
+          var key = item.product_id + '_' + up.toFixed(2);
+          if (!productAgg[key]) {
+            var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
+            var variety = soGetProductVariety(item.product_id);
+            var snapshot = (variety && variety !== '\u2014' ? variety + ' ' : '') + (prod ? prod.name : 'Unknown');
+            productAgg[key] = { product_id: item.product_id, product_name: snapshot, quantity: 0, unit_price: up, line_total: 0 };
+          }
+          productAgg[key].quantity += (item.quantity || 0);
+          productAgg[key].line_total += parseFloat(item.line_total) || 0;
+        });
+      });
+
+      var newItems = [];
+      var subtotal = 0;
+      var pLines = Object.values(productAgg);
+      for (var j = 0; j < pLines.length; j++) {
+        var p = pLines[j];
+        subtotal += p.line_total;
+        var iid = await dbNextId('II');
+        newItems.push({ id: iid, invoice_id: invoiceId, product_id: p.product_id, product_name: p.product_name, quantity: p.quantity, unit_price: p.unit_price, line_total: p.line_total });
+      }
+      var iResult = await sbQuery(sb.from('sales_invoice_items').insert(newItems).select());
+      if (iResult) (iResult || []).forEach(function(ii) { invoiceItems.push(ii); });
+
+      // Update invoice totals
+      await sbQuery(sb.from('sales_invoices').update({ subtotal: subtotal, grand_total: subtotal }).eq('id', invoiceId).select());
+      inv.subtotal = subtotal;
+      inv.grand_total = subtotal;
+
+      notify(addIds.length + ' DO(s) added to ' + invoiceId, 'success');
+      renderInvoicing();
+    } catch(e) {
+      notify('Failed to add DOs: ' + e.message, 'error');
+    }
+  });
+}
+
+async function invCancelInvoice(invoiceId) {
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) return;
+
+  // Block if payments exist
+  var hasPayments = invoicePayments.some(function(p) { return p.invoice_id === invoiceId; });
+  if (hasPayments) { notify('Cannot cancel invoice with recorded payments. Remove payments first.', 'error'); return; }
+
+  confirmAction('Cancel Invoice', 'This will unlink all DOs and cancel invoice ' + invoiceId + '. Continue?', async function() {
+    try {
+      // Unlink DOs
+      var linkedOrders = invoiceOrders.filter(function(io) { return io.invoice_id === invoiceId; });
+      for (var i = 0; i < linkedOrders.length; i++) {
+        var oid = linkedOrders[i].order_id;
+        await sbQuery(sb.from('sales_orders').update({ invoice_id: null }).eq('id', oid).select());
+        var idx = orders.findIndex(function(x) { return x.id === oid; });
+        if (idx >= 0) orders[idx].invoice_id = null;
+      }
+
+      // Delete credit notes, items, junction
+      await sbQuery(sb.from('sales_credit_notes').delete().eq('invoice_id', invoiceId));
+      creditNotes = creditNotes.filter(function(cn) { return cn.invoice_id !== invoiceId; });
+      await sbQuery(sb.from('sales_invoice_items').delete().eq('invoice_id', invoiceId));
+      invoiceItems = invoiceItems.filter(function(ii) { return ii.invoice_id !== invoiceId; });
+      await sbQuery(sb.from('sales_invoice_orders').delete().eq('invoice_id', invoiceId));
+      invoiceOrders = invoiceOrders.filter(function(io) { return io.invoice_id !== invoiceId; });
+
+      // Set status to cancelled
+      await sbQuery(sb.from('sales_invoices').update({ status: 'cancelled' }).eq('id', invoiceId).select());
+      inv.status = 'cancelled';
+
+      invExpandedId = null;
+      notify('Invoice ' + invoiceId + ' cancelled', 'success');
+      renderInvoicing();
+    } catch(e) {
+      notify('Failed to cancel: ' + e.message, 'error');
+    }
+  }, true);
+}
+
 function invUpdateDueDate() {
   var dateInput = document.getElementById('inv-date');
   var termsSelect = document.getElementById('inv-terms');
