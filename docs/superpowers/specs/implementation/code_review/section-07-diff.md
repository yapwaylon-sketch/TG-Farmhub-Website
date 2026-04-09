diff --git a/sales.html b/sales.html
index 819c601..b02cef4 100644
--- a/sales.html
+++ b/sales.html
@@ -659,6 +659,11 @@
     #so-doc-a4-content .a4-sig-block .sig-line { border-bottom:1px solid #000;height:40px;margin-bottom:4px; }
     #so-doc-a4-content .a4-sig-block .sig-field-label { font-size:10px;color:#666; }
     #so-doc-a4-content .a4-footer { text-align:center;font-size:10px;color:#666;margin-top:20px;padding-top:10px;border-top:1px solid #ccc; }
+    #so-doc-a4-content .a4-bank-details { border:1px solid #999;padding:10px;font-size:11px;margin-bottom:12px;background:#fafafa;border-radius:2px; }
+    #so-doc-a4-content .a4-bank-details strong { display:block;margin-bottom:4px; }
+    #so-doc-a4-content .a4-do-ref { font-size:11px;color:#555;margin:8px 0 14px;font-style:italic; }
+    #so-doc-a4-content .a4-einvoice-placeholder { font-size:10px;color:#999;margin-bottom:16px; }
+    #so-doc-a4-content .a4-balance-due { font-size:14px;font-weight:800;background:#fff3cd;padding:4px 8px;display:inline-block; }
     /* Mobile: scale down A4 preview to fit screen, full size for print */
     @media screen and (max-width: 850px) {
       #so-doc-a4-content { width:100%!important;padding:8mm!important;font-size:10px; }
@@ -4659,7 +4664,180 @@ function invToggleInvoice(invoiceId) {
 function invApproveInvoice(invoiceId) { notify('Approve workflow coming in next update', 'info'); }
 function invOpenPaymentModal(invoiceId) { notify('Invoice payment coming in next update', 'info'); }
 function invOpenCNModal(invoiceId) { notify('Credit notes coming in next update', 'info'); }
-function generateInvoiceA4(invoiceId) { notify('Invoice document coming in next update', 'info'); }
+function generateInvoiceA4(invoiceId) {
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) { notify('Invoice not found', 'warning'); return; }
+
+  soDocCurrentInvoiceId = invoiceId;
+  soDocCurrentOrderId = null;
+  var cust = customers.find(function(c) { return c.id === inv.customer_id; });
+  var items = invoiceItems.filter(function(ii) { return ii.invoice_id === inv.id; });
+  var linkedDOs = invoiceOrders
+    .filter(function(io) { return io.invoice_id === inv.id; })
+    .map(function(io) { return orders.find(function(o) { return o.id === io.order_id; }); })
+    .filter(Boolean);
+  var preparedBy = currentUser ? esc(currentUser.displayName) : '—';
+
+  // Payment terms label
+  var termsLabel = 'Net 30';
+  if (inv.payment_terms === 'cod') termsLabel = 'COD';
+  else if (inv.payment_terms) {
+    var termsDays = parseInt(inv.payment_terms, 10);
+    if (!isNaN(termsDays)) termsLabel = termsDays === 0 ? 'COD' : 'Net ' + termsDays;
+    else {
+      var m = inv.payment_terms.match(/(\d+)/);
+      if (m) termsLabel = 'Net ' + m[1];
+    }
+  }
+
+  var html = '<div class="a4-page">';
+
+  // Letterhead
+  html += '<div class="a4-letterhead">';
+  html += '<img src="assets/logo.png?v=2" alt="TG">';
+  html += '<div class="a4-letterhead-text">';
+  html += '<h2>TG AGRO FRUITS SDN. BHD.</h2>';
+  html += '<p>(201401034124 / 1110222-T)</p>';
+  html += '<p>TIN: 24302625000 | MSIC: 46909</p>';
+  html += '<p>Lot 189, Kampung Riam Jaya, Airport Road,</p>';
+  html += '<p>98000 Miri, Sarawak</p>';
+  html += '<p>Tel: 012-3286661</p>';
+  html += '</div></div>';
+  html += '<hr class="a4-divider">';
+
+  // Title
+  html += '<div class="a4-title">INVOICE</div>';
+  html += '<div class="a4-doc-number">' + esc(inv.id) + '</div>';
+
+  // Info Grid
+  html += '<div class="a4-info-grid">';
+  html += '<div class="a4-info-label">Invoice No:</div><div class="a4-info-value">' + esc(inv.id) + '</div>';
+  html += '<div class="a4-info-label">Customer:</div><div class="a4-info-value">' + esc(cust ? cust.name : '—') + '</div>';
+  html += '<div class="a4-info-label">Invoice Date:</div><div class="a4-info-value">' + fmtDate(inv.invoice_date) + '</div>';
+  if (cust && cust.address) {
+    html += '<div class="a4-info-label">Address:</div><div class="a4-info-value">' + esc(cust.address) + '</div>';
+  } else {
+    html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
+  }
+  html += '<div class="a4-info-label">Due Date:</div><div class="a4-info-value">' + fmtDate(inv.due_date) + '</div>';
+  if (cust && cust.ssm_brn) {
+    html += '<div class="a4-info-label">SSM/BRN:</div><div class="a4-info-value">' + esc(cust.ssm_brn) + '</div>';
+  } else {
+    html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
+  }
+  html += '<div class="a4-info-label">Payment Terms:</div><div class="a4-info-value">' + esc(termsLabel) + '</div>';
+  if (cust && cust.tin) {
+    html += '<div class="a4-info-label">TIN:</div><div class="a4-info-value">' + esc(cust.tin) + '</div>';
+  } else {
+    html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
+  }
+  html += '</div>';
+
+  // Items Table
+  html += '<table class="a4-items-table">';
+  html += '<thead><tr><th style="width:40px;">No.</th><th>Description</th><th style="width:60px;">Qty</th><th style="width:60px;">Unit</th><th style="width:90px;">Unit Price (RM)</th><th style="width:100px;">Amount (RM)</th></tr></thead>';
+  html += '<tbody>';
+  items.forEach(function(item, idx) {
+    var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
+    var prodName = item.product_name || (prod ? prod.name : '—');
+    var prodVariety = soGetProductVariety(item.product_id);
+    var prodUnit = prod ? (prod.unit || '') : '';
+    var fullName = '';
+    if (prodVariety && prodVariety !== '—') fullName += prodVariety + ' ';
+    fullName += prodName;
+    var packInfo = [];
+    if (prod && prod.box_quantity) packInfo.push(prod.box_quantity + 'pcs');
+    if (prod && prod.weight_range) packInfo.push(prod.weight_range);
+    if (packInfo.length) fullName += ' (' + packInfo.join(', ') + ')';
+    var lineTotal = parseFloat(item.line_total) || 0;
+    var unitPrice = (parseFloat(item.unit_price) || 0).toFixed(2);
+
+    html += '<tr>';
+    html += '<td>' + (idx + 1) + '</td>';
+    html += '<td>' + esc(fullName) + '</td>';
+    html += '<td>' + (item.quantity || 0) + '</td>';
+    html += '<td>' + esc(prodUnit) + '</td>';
+    html += '<td>' + unitPrice + '</td>';
+    html += '<td>' + lineTotal.toFixed(2) + '</td>';
+    html += '</tr>';
+  });
+  html += '</tbody></table>';
+
+  // DO Reference Line
+  if (linkedDOs.length) {
+    var doRefs = linkedDOs.map(function(o) {
+      var dn = o.doc_number || o.id;
+      var dt = o.delivery_date || o.order_date;
+      var shortDate = dt ? fmtDateShort(dt).replace(/\/\d{2}$/, '') : '';
+      return dn + (shortDate ? ' (' + shortDate + ')' : '');
+    });
+    html += '<div class="a4-do-ref">Ref: ' + esc(doRefs.join(', ')) + '</div>';
+  }
+
+  // Totals
+  var subtotal = parseFloat(inv.subtotal) || 0;
+  var creditTotal = parseFloat(inv.credit_total) || 0;
+  var grandTotal = parseFloat(inv.grand_total) || 0;
+  var amountPaid = parseFloat(inv.amount_paid) || 0;
+  var balance = invoiceBalance(inv);
+
+  html += '<div class="a4-totals">';
+  html += '<div>Subtotal: <strong>RM ' + subtotal.toFixed(2) + '</strong></div>';
+  if (creditTotal > 0) {
+    html += '<div>Credit Notes: <strong style="color:#c00;">-RM ' + creditTotal.toFixed(2) + '</strong></div>';
+  }
+  html += '<div class="a4-grand-total">TOTAL: RM ' + grandTotal.toFixed(2) + '</div>';
+  if (amountPaid > 0) {
+    html += '<div style="margin-top:4px;">Amount Paid: <strong>RM ' + amountPaid.toFixed(2) + '</strong></div>';
+  }
+  html += '<div style="margin-top:4px;">Balance Due: ';
+  if (balance > 0) {
+    html += '<span class="a4-balance-due">RM ' + balance.toFixed(2) + '</span>';
+  } else {
+    html += '<strong>RM 0.00</strong>';
+  }
+  html += '</div>';
+  html += '</div>';
+
+  // Bank Details
+  html += '<div class="a4-bank-details">';
+  html += '<strong>Payment to:</strong>';
+  html += 'Public Bank Berhad<br>';
+  html += 'A/C: 3243036710<br>';
+  html += 'TG Agro Fruits Sdn. Bhd.';
+  html += '</div>';
+
+  // e-Invoice Placeholder
+  html += '<div class="a4-einvoice-placeholder">e-Invoice: Pending</div>';
+
+  // Signature Block
+  html += '<div class="a4-sig-section">';
+  html += '<div class="a4-sig-block">';
+  html += '<div class="sig-label">Prepared By:</div>';
+  html += '<div class="sig-name">' + preparedBy + '</div>';
+  html += '</div>';
+  html += '<div class="a4-sig-block">';
+  html += '<div class="sig-label">Authorized By:</div>';
+  html += '<div class="sig-line"></div>';
+  html += '<div class="sig-field-label">Name:</div>';
+  html += '<div class="sig-line" style="height:20px;"></div>';
+  html += '<div class="sig-field-label">Date:</div>';
+  html += '<div class="sig-line" style="height:20px;"></div>';
+  html += '<div class="sig-field-label">Signature</div>';
+  html += '</div>';
+  html += '</div>';
+
+  // Footer
+  html += '<div class="a4-footer">Thank you for your business</div>';
+  html += '</div>'; // close a4-page
+
+  // Show in modal
+  document.getElementById('so-doc-content').style.display = 'none';
+  document.getElementById('so-doc-a4-content').innerHTML = html;
+  document.getElementById('so-doc-a4-content').style.display = 'block';
+  document.getElementById('so-doc-modal').classList.add('a4-mode');
+  document.getElementById('so-doc-modal').style.display = 'flex';
+}
 
 async function invAddMoreDOs(invoiceId) {
   var inv = invoices.find(function(i) { return i.id === invoiceId; });
@@ -5846,6 +6024,7 @@ async function soSaveOrder() {
 // DOCUMENT GENERATION (DO/CS)
 // ============================================================
 var soDocCurrentOrderId = null;
+var soDocCurrentInvoiceId = null;
 var soDocImageBlob = null;
 var soDocImageUrl = null;
 
@@ -6159,6 +6338,7 @@ function closeDocModal() {
   document.getElementById('so-doc-a4-content').innerHTML = '';
   document.getElementById('so-doc-a4-content').style.display = 'none';
   soDocCurrentOrderId = null;
+  soDocCurrentInvoiceId = null;
   if (soDocImageUrl) { URL.revokeObjectURL(soDocImageUrl); soDocImageUrl = null; }
   soDocImageBlob = null;
 }
@@ -6228,8 +6408,13 @@ async function soShareDoc() {
 
     // Try Web Share API first (mobile)
     if (navigator.share && navigator.canShare) {
-      var o = orders.find(function(x) { return x.id === soDocCurrentOrderId; });
-      var fileName = (o ? (o.doc_number || o.id) : 'document') + (isA4 ? ' (A4)' : '') + '.png';
+      var fileName;
+      if (soDocCurrentInvoiceId) {
+        fileName = soDocCurrentInvoiceId + '.png';
+      } else {
+        var o = orders.find(function(x) { return x.id === soDocCurrentOrderId; });
+        fileName = (o ? (o.doc_number || o.id) : 'document') + (isA4 ? ' (A4)' : '') + '.png';
+      }
       var file = new File([blob], fileName, { type: 'image/png' });
       var shareData = { files: [file], title: fileName };
 
@@ -6257,9 +6442,14 @@ async function soShareDoc() {
 
 function soDownloadDocImage() {
   if (!soDocImageBlob) { notify('No image to download', 'warning'); return; }
-  var o = orders.find(function(x) { return x.id === soDocCurrentOrderId; });
-  var isA4 = document.getElementById('so-doc-modal').classList.contains('a4-mode');
-  var fileName = (o ? (o.doc_number || o.id) : 'document') + (isA4 ? ' (A4)' : '') + '.png';
+  var fileName;
+  if (soDocCurrentInvoiceId) {
+    fileName = soDocCurrentInvoiceId + '.png';
+  } else {
+    var o = orders.find(function(x) { return x.id === soDocCurrentOrderId; });
+    var isA4 = document.getElementById('so-doc-modal').classList.contains('a4-mode');
+    fileName = (o ? (o.doc_number || o.id) : 'document') + (isA4 ? ' (A4)' : '') + '.png';
+  }
   var a = document.createElement('a');
   a.href = soDocImageUrl;
   a.download = fileName;
@@ -6270,16 +6460,28 @@ function soDownloadDocImage() {
 }
 
 function soOpenWhatsAppDoc() {
-  // Build summary text for WhatsApp
-  var o = orders.find(function(x) { return x.id === soDocCurrentOrderId; });
-  if (!o) return;
-  var cust = customers.find(function(c) { return c.id === o.customer_id; });
-  var isDO = o.doc_type === 'delivery_order';
-  var grandTotal = parseFloat(o.grand_total) || 0;
-  var msg = (isDO ? 'Delivery Order' : 'Cash Sales') + ': ' + (o.doc_number || o.id) + '\n';
-  msg += 'Customer: ' + (cust ? cust.name : '\u2014') + '\n';
-  msg += 'Total: RM ' + grandTotal.toFixed(2) + '\n';
-  msg += 'Date: ' + fmtDate(o.delivery_date || o.order_date);
+  var msg;
+  if (soDocCurrentInvoiceId) {
+    var inv = invoices.find(function(i) { return i.id === soDocCurrentInvoiceId; });
+    if (!inv) return;
+    var cust = customers.find(function(c) { return c.id === inv.customer_id; });
+    var balance = invoiceBalance(inv);
+    msg = 'Invoice: ' + inv.id + '\n';
+    msg += 'Customer: ' + (cust ? cust.name : '\u2014') + '\n';
+    msg += 'Total: RM ' + (parseFloat(inv.grand_total) || 0).toFixed(2) + '\n';
+    msg += 'Balance Due: RM ' + balance.toFixed(2) + '\n';
+    msg += 'Due Date: ' + fmtDate(inv.due_date);
+  } else {
+    var o = orders.find(function(x) { return x.id === soDocCurrentOrderId; });
+    if (!o) return;
+    var cust = customers.find(function(c) { return c.id === o.customer_id; });
+    var isDO = o.doc_type === 'delivery_order';
+    var grandTotal = parseFloat(o.grand_total) || 0;
+    msg = (isDO ? 'Delivery Order' : 'Cash Sales') + ': ' + (o.doc_number || o.id) + '\n';
+    msg += 'Customer: ' + (cust ? cust.name : '\u2014') + '\n';
+    msg += 'Total: RM ' + grandTotal.toFixed(2) + '\n';
+    msg += 'Date: ' + fmtDate(o.delivery_date || o.order_date);
+  }
 
   // Download the image first
   soDownloadDocImage();
