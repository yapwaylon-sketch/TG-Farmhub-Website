diff --git a/sales.html b/sales.html
index a305ee7..4ecf55a 100644
--- a/sales.html
+++ b/sales.html
@@ -4109,15 +4109,37 @@ function renderInvoicing() {
       html += '</div>';
     });
 
-    // Action buttons (placeholder — Create Invoice will be added in section 05)
+    // Billing summary (live, updates on selection)
     var selectedCount = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; }).length;
-    html += '<div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap;">';
-    html += '<button class="btn btn-primary" id="inv-create-btn" disabled style="opacity:0.5;cursor:not-allowed;">';
-    html += 'Create Invoice (' + selectedCount + ' selected)</button>';
+    html += '<div id="inv-billing-summary" style="margin-top:16px;display:' + (selectedCount > 0 ? 'block' : 'none') + ';"></div>';
+
+    // Invoice details (date, terms, notes)
+    html += '<div id="inv-details" style="margin-top:16px;display:' + (selectedCount > 0 ? 'block' : 'none') + ';background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:16px;">';
+    html += '<div style="font-size:14px;font-weight:700;color:var(--text);margin-bottom:12px;">Invoice Details</div>';
+    html += '<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">';
+    html += '<div class="form-field"><label>INVOICE DATE</label><input type="date" id="inv-date" value="' + todayStr() + '" style="width:100%;"></div>';
+    // Auto-detect payment terms from first selected DO's customer
+    var firstSelId = Object.keys(invSelectedDOs).find(function(k) { return invSelectedDOs[k]; });
+    var firstSelOrder = firstSelId ? orders.find(function(o) { return o.id === firstSelId; }) : null;
+    var firstSelCust = firstSelOrder ? customers.find(function(c) { return c.id === firstSelOrder.customer_id; }) : null;
+    var defaultTermsDays = firstSelCust ? (firstSelCust.payment_terms_days || 0) : 30;
+    html += '<div class="form-field"><label>PAYMENT TERMS</label><select id="inv-terms" style="width:100%;" onchange="invUpdateDueDate()">';
+    [0, 7, 14, 30, 60].forEach(function(d) {
+      html += '<option value="' + d + '"' + (d === defaultTermsDays ? ' selected' : '') + '>' + paymentTermsLabel(d) + '</option>';
+    });
+    html += '</select></div>';
+    html += '</div>';
+    // Due date display
+    var dueDate = calcDueDate(todayStr(), defaultTermsDays === 0 ? 'cod' : defaultTermsDays + 'days');
+    html += '<div style="font-size:12px;color:var(--text-muted);margin-top:8px;">Due date: <strong id="inv-due-date" style="color:var(--text);">' + fmtDateNice(dueDate) + '</strong></div>';
+    html += '<div class="form-field" style="margin-top:12px;"><label>NOTES</label><textarea id="inv-notes" rows="2" placeholder="Optional invoice notes" style="width:100%;"></textarea></div>';
     html += '</div>';
 
-    // Billing summary (live, updates on selection)
-    html += '<div id="inv-billing-summary" style="margin-top:16px;display:' + (selectedCount > 0 ? 'block' : 'none') + ';"></div>';
+    // Action button
+    html += '<div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap;">';
+    html += '<button class="btn btn-primary" id="inv-create-btn" onclick="invCreateDraftInvoice()"' + (selectedCount === 0 ? ' disabled style="opacity:0.5;cursor:not-allowed;"' : '') + '>';
+    html += 'Create Draft Invoice (' + selectedCount + ' selected)</button>';
+    html += '</div>';
   }
   html += '</div>';
 
@@ -4156,11 +4178,13 @@ function invUpdateButtons() {
   var selectedCount = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; }).length;
   var btn = document.getElementById('inv-create-btn');
   if (btn) {
-    btn.textContent = 'Create Invoice (' + selectedCount + ' selected)';
+    btn.textContent = 'Create Draft Invoice (' + selectedCount + ' selected)';
     btn.disabled = selectedCount === 0;
     btn.style.opacity = selectedCount === 0 ? '0.5' : '';
     btn.style.cursor = selectedCount === 0 ? 'not-allowed' : '';
   }
+  var details = document.getElementById('inv-details');
+  if (details) details.style.display = selectedCount > 0 ? 'block' : 'none';
   invRenderBillingSummary();
 }
 
@@ -4206,24 +4230,26 @@ function invRenderBillingSummary() {
     }
   });
 
-  // Aggregate items: group by product_id, sum quantities and line totals
+  // Aggregate items: group by product_id + unit_price (different prices = separate lines)
   var productAgg = {};
   selectedOrders.forEach(function(o) {
     var items = orderItems.filter(function(i) { return i.order_id === o.id; });
     items.forEach(function(item) {
-      var key = item.product_id;
+      var unitPrice = parseFloat(item.unit_price) || 0;
+      var key = item.product_id + '_' + unitPrice.toFixed(2);
       if (!productAgg[key]) {
         var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
         var variety = soGetProductVariety(item.product_id);
         var catLabel = prod ? spCategoryLabel(prod.category) : '';
         productAgg[key] = {
+          product_id: item.product_id,
           name: prod ? prod.name : '\u2014',
           variety: variety !== '\u2014' ? variety : '',
           category: catLabel,
           unit: prod ? (prod.unit || '') : '',
           quantity: 0,
           totalAmount: 0,
-          unitPrice: parseFloat(item.unit_price) || 0
+          unitPrice: unitPrice
         };
       }
       productAgg[key].quantity += (item.quantity || 0);
@@ -4260,14 +4286,12 @@ function invRenderBillingSummary() {
     var desc = '';
     if (p.variety) desc += p.variety + ' ';
     desc += p.name;
-    var avgPrice = p.quantity > 0 ? p.totalAmount / p.quantity : p.unitPrice;
-
     html += '<tr>';
     html += '<td>' + (i + 1) + '</td>';
     html += '<td>' + esc(desc) + '</td>';
     html += '<td style="text-align:right;">' + p.quantity + '</td>';
     html += '<td>' + esc(p.unit) + '</td>';
-    html += '<td style="text-align:right;">' + formatRM(avgPrice) + '</td>';
+    html += '<td style="text-align:right;">' + formatRM(p.unitPrice) + '</td>';
     html += '<td style="text-align:right;font-weight:600;">' + formatRM(p.totalAmount) + '</td>';
     html += '</tr>';
   });
@@ -4300,7 +4324,8 @@ function invBuildSummaryText() {
   selectedOrders.forEach(function(o) {
     var items = orderItems.filter(function(i) { return i.order_id === o.id; });
     items.forEach(function(item) {
-      var key = item.product_id;
+      var unitPrice = parseFloat(item.unit_price) || 0;
+      var key = item.product_id + '_' + unitPrice.toFixed(2);
       if (!productAgg[key]) {
         var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
         var variety = soGetProductVariety(item.product_id);
@@ -4309,7 +4334,8 @@ function invBuildSummaryText() {
           variety: variety !== '\u2014' ? variety : '',
           unit: prod ? (prod.unit || '') : '',
           quantity: 0,
-          totalAmount: 0
+          totalAmount: 0,
+          unitPrice: unitPrice
         };
       }
       productAgg[key].quantity += (item.quantity || 0);
@@ -4328,8 +4354,7 @@ function invBuildSummaryText() {
     var desc = '';
     if (p.variety) desc += p.variety + ' ';
     desc += p.name;
-    var avgPrice = p.quantity > 0 ? p.totalAmount / p.quantity : 0;
-    text += (i + 1) + ') ' + desc + ' ' + p.quantity + p.unit + ' x RM ' + avgPrice.toFixed(2) + ' = ' + formatRM(p.totalAmount) + '\n';
+    text += (i + 1) + ') ' + desc + ' ' + p.quantity + p.unit + ' x RM ' + p.unitPrice.toFixed(2) + ' = ' + formatRM(p.totalAmount) + '\n';
   });
 
   text += '\nTotal This Invoice = ' + formatRM(grandTotal);
@@ -4365,7 +4390,8 @@ function invPrintSummary() {
   selectedOrders.forEach(function(o) {
     var items = orderItems.filter(function(i) { return i.order_id === o.id; });
     items.forEach(function(item) {
-      var key = item.product_id;
+      var unitPrice = parseFloat(item.unit_price) || 0;
+      var key = item.product_id + '_' + unitPrice.toFixed(2);
       if (!productAgg[key]) {
         var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
         var variety = soGetProductVariety(item.product_id);
@@ -4374,7 +4400,8 @@ function invPrintSummary() {
           variety: variety !== '\u2014' ? variety : '',
           unit: prod ? (prod.unit || '') : '',
           quantity: 0,
-          totalAmount: 0
+          totalAmount: 0,
+          unitPrice: unitPrice
         };
       }
       productAgg[key].quantity += (item.quantity || 0);
@@ -4402,8 +4429,7 @@ function invPrintSummary() {
     var desc = '';
     if (p.variety) desc += p.variety + ' ';
     desc += p.name;
-    var avgPrice = p.quantity > 0 ? p.totalAmount / p.quantity : 0;
-    h += '<tr><td>' + (i + 1) + '</td><td>' + esc(desc) + '</td><td class="right">' + p.quantity + '</td><td>' + esc(p.unit) + '</td><td class="right">' + avgPrice.toFixed(2) + '</td><td class="right">' + p.totalAmount.toFixed(2) + '</td></tr>';
+    h += '<tr><td>' + (i + 1) + '</td><td>' + esc(desc) + '</td><td class="right">' + p.quantity + '</td><td>' + esc(p.unit) + '</td><td class="right">' + p.unitPrice.toFixed(2) + '</td><td class="right">' + p.totalAmount.toFixed(2) + '</td></tr>';
   });
 
   h += '</tbody><tfoot><tr><td colspan="5" class="right total">Total This Invoice</td><td class="right total">' + grandTotal.toFixed(2) + '</td></tr></tfoot></table>';
@@ -4416,6 +4442,139 @@ function invPrintSummary() {
   w.document.close();
 }
 
+function invUpdateDueDate() {
+  var dateInput = document.getElementById('inv-date');
+  var termsSelect = document.getElementById('inv-terms');
+  var dueDateEl = document.getElementById('inv-due-date');
+  if (!dateInput || !termsSelect || !dueDateEl) return;
+  var days = parseInt(termsSelect.value, 10) || 0;
+  var termsCode = days === 0 ? 'cod' : days + 'days';
+  var due = calcDueDate(dateInput.value || todayStr(), termsCode);
+  dueDateEl.textContent = fmtDateNice(due);
+}
+
+async function invCreateDraftInvoice() {
+  var selectedIds = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; });
+  if (!selectedIds.length) { notify('Select at least one DO', 'warning'); return; }
+
+  var invoiceDateVal = (document.getElementById('inv-date') || {}).value || todayStr();
+  var paymentTermsDays = parseInt((document.getElementById('inv-terms') || {}).value, 10) || 0;
+  var notesVal = ((document.getElementById('inv-notes') || {}).value || '').trim();
+
+  var btn = document.getElementById('inv-create-btn');
+  btnLoading(btn, true);
+
+  try {
+    // 1. Generate invoice ID
+    var invoiceId = await dbNextId('INV');
+
+    // 2. Calculate fields
+    var termsCode = paymentTermsDays === 0 ? 'cod' : paymentTermsDays + 'days';
+    var dueDate = calcDueDate(invoiceDateVal, termsCode);
+
+    // 3. Get customer from first selected DO
+    var firstOrder = orders.find(function(o) { return o.id === selectedIds[0]; });
+    var customerId = firstOrder ? firstOrder.customer_id : null;
+
+    // 4. Aggregate items by product+price
+    var productAgg = {};
+    selectedIds.forEach(function(orderId) {
+      var items = orderItems.filter(function(i) { return i.order_id === orderId; });
+      items.forEach(function(item) {
+        var unitPrice = parseFloat(item.unit_price) || 0;
+        var key = item.product_id + '_' + unitPrice.toFixed(2);
+        if (!productAgg[key]) {
+          var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
+          var variety = soGetProductVariety(item.product_id);
+          var snapshot = '';
+          if (variety && variety !== '\u2014') snapshot += variety + ' ';
+          snapshot += prod ? prod.name : 'Unknown';
+          productAgg[key] = {
+            product_id: item.product_id,
+            product_name: snapshot,
+            quantity: 0,
+            unit_price: unitPrice,
+            line_total: 0
+          };
+        }
+        productAgg[key].quantity += (item.quantity || 0);
+        productAgg[key].line_total += parseFloat(item.line_total) || 0;
+      });
+    });
+
+    var subtotal = 0;
+    var productLines = Object.values(productAgg);
+    productLines.forEach(function(p) { subtotal += p.line_total; });
+    var grandTotal = subtotal;
+
+    // 5. Insert sales_invoices
+    var invData = {
+      id: invoiceId,
+      customer_id: customerId,
+      invoice_date: invoiceDateVal,
+      due_date: dueDate,
+      payment_terms: termsCode,
+      subtotal: subtotal,
+      grand_total: grandTotal,
+      credit_total: 0,
+      amount_paid: 0,
+      payment_status: 'unpaid',
+      status: 'draft',
+      notes: notesVal || null,
+      created_by: currentUser ? currentUser.id : null
+    };
+    var invResult = await sbQuery(sb.from('sales_invoices').insert(invData).select());
+    if (invResult === null) { btnLoading(btn, false, 'Create Draft Invoice'); return; }
+
+    // 6. Insert invoice items
+    var itemsArray = [];
+    for (var i = 0; i < productLines.length; i++) {
+      var p = productLines[i];
+      var itemId = await dbNextId('II');
+      itemsArray.push({
+        id: itemId,
+        invoice_id: invoiceId,
+        product_id: p.product_id,
+        product_name: p.product_name,
+        quantity: p.quantity,
+        unit_price: p.unit_price,
+        line_total: p.line_total
+      });
+    }
+    var itemsResult = await sbQuery(sb.from('sales_invoice_items').insert(itemsArray).select());
+    if (itemsResult === null) { btnLoading(btn, false, 'Create Draft Invoice'); return; }
+
+    // 7. Insert invoice-orders junction
+    var junctionArray = selectedIds.map(function(orderId) {
+      return { invoice_id: invoiceId, order_id: orderId };
+    });
+    var juncResult = await sbQuery(sb.from('sales_invoice_orders').insert(junctionArray).select());
+    if (juncResult === null) { btnLoading(btn, false, 'Create Draft Invoice'); return; }
+
+    // 8. Update sales_orders.invoice_id
+    for (var j = 0; j < selectedIds.length; j++) {
+      var oid = selectedIds[j];
+      await sbQuery(sb.from('sales_orders').update({ invoice_id: invoiceId }).eq('id', oid).is('invoice_id', null).select());
+      var idx = orders.findIndex(function(x) { return x.id === oid; });
+      if (idx >= 0) orders[idx].invoice_id = invoiceId;
+    }
+
+    // 9. Update local arrays
+    invoices.push(invResult[0] || invData);
+    (itemsResult || []).forEach(function(item) { invoiceItems.push(item); });
+    (juncResult || []).forEach(function(junc) { invoiceOrders.push(junc); });
+
+    // 10. Clear and re-render
+    btnLoading(btn, false, 'Create Draft Invoice');
+    invSelectedDOs = {};
+    notify('Invoice ' + invoiceId + ' created', 'success');
+    renderInvoicing();
+  } catch(e) {
+    btnLoading(btn, false, 'Create Draft Invoice');
+    notify('Failed to create invoice: ' + e.message, 'error');
+  }
+}
+
 // ============================================================
 // REPORTS
 // ============================================================
