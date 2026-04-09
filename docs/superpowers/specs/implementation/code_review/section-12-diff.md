diff --git a/sales.html b/sales.html
index 4f15e07..7c013b0 100644
--- a/sales.html
+++ b/sales.html
@@ -488,16 +488,7 @@
           <input type="date" id="stmt-date-to" style="width:100%;">
         </div>
       </div>
-      <div class="form-field">
-        <label>TRANSACTION TYPE</label>
-        <select id="stmt-type" style="width:100%;">
-          <option value="all">All Transactions</option>
-          <option value="outstanding">Outstanding Only</option>
-          <option value="cash_sales">Cash Sales Only</option>
-          <option value="delivery_order">Delivery Orders Only</option>
-          <option value="paid">Paid Only</option>
-        </select>
-      </div>
+      <div style="font-size:11px;color:var(--text-muted);margin-top:4px;">Shows invoices, payments, and credit notes within the selected period.</div>
     </div>
     <div class="modal-actions">
       <button class="btn btn-outline" onclick="closeModal('so-stmt-modal')">Cancel</button>
@@ -7194,13 +7185,11 @@ function soGenerateStatement(customerId) {
 
   document.getElementById('stmt-customer-id').value = customerId;
   document.getElementById('stmt-customer-name').textContent = cust.name;
-  // Default: last 3 months to today
   var today = todayStr();
   var threeMonthsAgo = new Date();
   threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
   document.getElementById('stmt-date-from').value = threeMonthsAgo.toISOString().split('T')[0];
   document.getElementById('stmt-date-to').value = today;
-  document.getElementById('stmt-type').value = 'outstanding';
   document.getElementById('so-stmt-modal').style.display = 'flex';
 }
 
@@ -7211,27 +7200,66 @@ function soGenerateStatementConfirm() {
 
   var dateFrom = document.getElementById('stmt-date-from').value;
   var dateTo = document.getElementById('stmt-date-to').value;
-  var stmtType = document.getElementById('stmt-type').value;
-
-  var custOrders = orders.filter(function(o) {
-    if (o.customer_id !== customerId || o.status !== 'completed') return false;
-    if (dateFrom && o.order_date < dateFrom) return false;
-    if (dateTo && o.order_date > dateTo) return false;
-    if (stmtType === 'outstanding') return orderBalance(o) > 0;
-    if (stmtType === 'cash_sales') return o.doc_type !== 'delivery_order';
-    if (stmtType === 'delivery_order') return o.doc_type === 'delivery_order';
-    if (stmtType === 'paid') return orderBalance(o) <= 0;
-    return true; // 'all'
+  closeModal('so-stmt-modal');
+
+  // Get customer's invoice IDs
+  var custInvIds = invoices.filter(function(inv) { return inv.customer_id === customerId && inv.status !== 'cancelled'; }).map(function(inv) { return inv.id; });
+
+  // Calculate opening balance (before dateFrom)
+  var openingBalance = 0;
+  invoices.forEach(function(inv) {
+    if (inv.customer_id !== customerId || inv.status === 'cancelled') return;
+    if (inv.invoice_date < dateFrom) openingBalance += parseFloat(inv.grand_total) || 0;
+  });
+  invoicePayments.forEach(function(p) {
+    if (custInvIds.indexOf(p.invoice_id) === -1) return;
+    if (p.payment_date < dateFrom) openingBalance -= parseFloat(p.amount) || 0;
+  });
+  creditNotes.forEach(function(cn) {
+    if (custInvIds.indexOf(cn.invoice_id) === -1) return;
+    if (cn.credit_date < dateFrom) openingBalance -= parseFloat(cn.amount) || 0;
   });
-  custOrders.sort(function(a, b) { return (a.order_date || '').localeCompare(b.order_date || ''); });
 
-  closeModal('so-stmt-modal');
+  // Collect transactions within date range
+  var txns = [];
+  invoices.forEach(function(inv) {
+    if (inv.customer_id !== customerId || inv.status === 'cancelled') return;
+    if (inv.invoice_date >= dateFrom && inv.invoice_date <= dateTo) {
+      txns.push({ date: inv.invoice_date, docNo: inv.id, desc: 'Invoice', debit: parseFloat(inv.grand_total) || 0, credit: 0, sortOrder: 0 });
+    }
+  });
+  invoicePayments.forEach(function(p) {
+    if (custInvIds.indexOf(p.invoice_id) === -1) return;
+    if (p.payment_date >= dateFrom && p.payment_date <= dateTo) {
+      var ml = p.method === 'bank_transfer' ? 'Bank Transfer' : p.method === 'cash' ? 'Cash' : p.method === 'cheque' ? 'Cheque' : (p.method || '');
+      txns.push({ date: p.payment_date, docNo: p.id, desc: 'Payment - ' + ml, debit: 0, credit: parseFloat(p.amount) || 0, sortOrder: 1 });
+    }
+  });
+  creditNotes.forEach(function(cn) {
+    if (custInvIds.indexOf(cn.invoice_id) === -1) return;
+    if (cn.credit_date >= dateFrom && cn.credit_date <= dateTo) {
+      txns.push({ date: cn.credit_date, docNo: cn.id, desc: 'Credit Note' + (cn.reason ? ' - ' + cn.reason : ''), debit: 0, credit: parseFloat(cn.amount) || 0, sortOrder: 1 });
+    }
+  });
+  txns.sort(function(a, b) { return a.date.localeCompare(b.date) || a.sortOrder - b.sortOrder; });
 
-  var typeLabels = { all: 'All Transactions', outstanding: 'Outstanding', cash_sales: 'Cash Sales', delivery_order: 'Delivery Orders', paid: 'Paid' };
-  var stmtLabel = typeLabels[stmtType] || 'All';
-  var periodLabel = (dateFrom ? fmtDate(dateFrom) : 'Start') + ' to ' + (dateTo ? fmtDate(dateTo) : 'Present');
+  // Aging summary (all outstanding invoices, not limited to date range)
+  var aging = { current: 0, d30: 0, d60: 0, d90: 0, d90plus: 0 };
+  invoices.forEach(function(inv) {
+    if (inv.customer_id !== customerId || inv.status !== 'issued') return;
+    var bal = invoiceBalance(inv);
+    if (bal <= 0) return;
+    var days = invoiceAgeDays(inv);
+    if (days <= 0) aging.current += bal;
+    else if (days <= 30) aging.d30 += bal;
+    else if (days <= 60) aging.d60 += bal;
+    else if (days <= 90) aging.d90 += bal;
+    else aging.d90plus += bal;
+  });
+  var agingTotal = aging.current + aging.d30 + aging.d60 + aging.d90 + aging.d90plus;
+
+  var periodLabel = fmtDate(dateFrom) + ' to ' + fmtDate(dateTo);
   var preparedBy = currentUser ? esc(currentUser.displayName) : '—';
-  var totalAmount = 0, totalPaid = 0, totalOutstanding = 0;
 
   var html = '<div class="a4-page">';
 
@@ -7241,6 +7269,7 @@ function soGenerateStatementConfirm() {
   html += '<div class="a4-letterhead-text">';
   html += '<h2>TG AGRO FRUITS SDN. BHD.</h2>';
   html += '<p>(201401034124 / 1110222-T)</p>';
+  html += '<p>TIN: 24302625000 | MSIC: 46909</p>';
   html += '<p>Lot 189, Kampung Riam Jaya, Airport Road,</p>';
   html += '<p>98000 Miri, Sarawak</p>';
   html += '<p>Tel: 012-3286661</p>';
@@ -7249,7 +7278,7 @@ function soGenerateStatementConfirm() {
 
   // Title
   html += '<div class="a4-title">STATEMENT OF ACCOUNT</div>';
-  html += '<div class="a4-copy-label">' + stmtLabel + ' &mdash; ' + periodLabel + '</div>';
+  html += '<div class="a4-copy-label">' + periodLabel + '</div>';
 
   // Customer Info
   html += '<div class="a4-info-grid">';
@@ -7266,50 +7295,58 @@ function soGenerateStatementConfirm() {
   }
   html += '</div>';
 
-  // Orders table
+  // Transaction table
   html += '<table class="a4-items-table">';
-  html += '<thead><tr><th>Doc #</th><th>Type</th><th>Date</th><th>Age</th><th style="text-align:right;">Total (RM)</th><th style="text-align:right;">Paid (RM)</th><th style="text-align:right;">Balance (RM)</th></tr></thead>';
+  html += '<thead><tr><th>Date</th><th>Doc No</th><th>Description</th><th style="text-align:right;">Debit (RM)</th><th style="text-align:right;">Credit (RM)</th><th style="text-align:right;">Balance (RM)</th></tr></thead>';
   html += '<tbody>';
 
-  if (custOrders.length === 0) {
-    html += '<tr><td colspan="7" style="text-align:center;color:#888;padding:20px;">No transactions found for this period</td></tr>';
-  } else {
-    custOrders.forEach(function(o) {
-      var total = parseFloat(o.grand_total) || 0;
-      var paid = parseFloat(o.amount_paid) || 0;
-      var bal = total - paid;
-      totalAmount += total;
-      totalPaid += paid;
-      totalOutstanding += Math.max(0, bal);
-      var days = daysBetween(o.order_date);
-      var typeLabel = o.doc_type === 'delivery_order' ? 'DO' : 'CS';
+  // Opening balance row
+  var runBal = openingBalance;
+  html += '<tr style="background:#f5f5f5;font-weight:700;"><td></td><td></td><td>Brought Forward</td><td></td><td></td><td style="text-align:right;">' + runBal.toFixed(2) + '</td></tr>';
 
+  if (txns.length === 0) {
+    html += '<tr><td colspan="6" style="text-align:center;color:#888;padding:16px;">No transactions in this period</td></tr>';
+  } else {
+    txns.forEach(function(t) {
+      runBal += t.debit - t.credit;
       html += '<tr>';
-      html += '<td style="font-weight:700;">' + esc(o.doc_number || o.id) + '</td>';
-      html += '<td>' + typeLabel + '</td>';
-      html += '<td>' + fmtDate(o.order_date) + '</td>';
-      html += '<td>' + days + 'd</td>';
-      html += '<td style="text-align:right;">' + total.toFixed(2) + '</td>';
-      html += '<td style="text-align:right;">' + paid.toFixed(2) + '</td>';
-      html += '<td style="text-align:right;font-weight:700;">' + (bal > 0 ? bal.toFixed(2) : '<span style="color:#060;">Paid</span>') + '</td>';
+      html += '<td>' + fmtDate(t.date) + '</td>';
+      html += '<td style="font-weight:600;">' + esc(t.docNo) + '</td>';
+      html += '<td>' + esc(t.desc) + '</td>';
+      html += '<td style="text-align:right;">' + (t.debit > 0 ? t.debit.toFixed(2) : '') + '</td>';
+      html += '<td style="text-align:right;">' + (t.credit > 0 ? t.credit.toFixed(2) : '') + '</td>';
+      html += '<td style="text-align:right;font-weight:700;">' + runBal.toFixed(2) + '</td>';
       html += '</tr>';
     });
   }
   html += '</tbody></table>';
 
-  // Summary totals
+  // Closing balance
   html += '<div class="a4-totals">';
-  html += '<div>Total: <strong>RM ' + totalAmount.toFixed(2) + '</strong></div>';
-  html += '<div>Paid: <strong style="color:#060;">RM ' + totalPaid.toFixed(2) + '</strong></div>';
-  html += '<div class="a4-grand-total">TOTAL OUTSTANDING: RM ' + totalOutstanding.toFixed(2) + '</div>';
+  html += '<div class="a4-grand-total">CLOSING BALANCE: RM ' + runBal.toFixed(2) + '</div>';
   html += '</div>';
 
-  // Payment reminder (only if outstanding > 0)
-  if (totalOutstanding > 0) {
-    html += '<div style="margin-top:20px;font-size:12px;color:#555;line-height:1.6;">';
+  // Aging summary (only if outstanding)
+  if (agingTotal > 0) {
+    html += '<div style="margin-top:16px;font-size:12px;font-weight:700;margin-bottom:6px;">Aging Summary</div>';
+    html += '<table class="a4-items-table" style="width:auto;">';
+    html += '<thead><tr><th>Current</th><th>1-30 Days</th><th>31-60 Days</th><th>61-90 Days</th><th>90+ Days</th><th>Total</th></tr></thead>';
+    html += '<tbody><tr>';
+    html += '<td style="text-align:right;">' + aging.current.toFixed(2) + '</td>';
+    html += '<td style="text-align:right;">' + aging.d30.toFixed(2) + '</td>';
+    html += '<td style="text-align:right;color:#E8A020;font-weight:600;">' + aging.d60.toFixed(2) + '</td>';
+    html += '<td style="text-align:right;color:#E8A020;font-weight:600;">' + aging.d90.toFixed(2) + '</td>';
+    html += '<td style="text-align:right;color:#c00;font-weight:600;">' + aging.d90plus.toFixed(2) + '</td>';
+    html += '<td style="text-align:right;font-weight:800;">' + agingTotal.toFixed(2) + '</td>';
+    html += '</tr></tbody></table>';
+  }
+
+  // Payment reminder + bank details (only if outstanding)
+  if (agingTotal > 0) {
+    html += '<div style="margin-top:16px;font-size:12px;color:#555;line-height:1.6;">';
     html += '<strong>Payment Reminder:</strong> Please arrange payment at your earliest convenience.';
     html += '</div>';
-    html += '<div style="margin-top:10px;padding:8px 12px;border:1px solid #999;border-radius:4px;font-size:11px;line-height:1.6;">';
+    html += '<div class="a4-bank-details" style="margin-top:10px;">';
     html += '<strong>Payment via Bank Transfer:</strong><br>';
     html += 'Public Bank Berhad<br>';
     html += 'A/C: 3243036710<br>';
@@ -7318,12 +7355,15 @@ function soGenerateStatementConfirm() {
     html += '</div>';
   }
 
+  // Disclaimer
+  html += '<div style="margin-top:12px;font-size:10px;color:#999;font-style:italic;">If payment has already been made, please disregard this statement.</div>';
+
   // Prepared by
-  html += '<div style="margin-top:30px;font-size:12px;">';
+  html += '<div style="margin-top:24px;font-size:12px;">';
   html += '<strong>Prepared By:</strong> ' + preparedBy;
   html += '</div>';
 
-  html += '<div class="a4-footer">TG Agro Fruits Sdn Bhd<br>Thank you for your business</div>';
+  html += '<div class="a4-footer">TG Agro Fruits Sdn Bhd &mdash; Thank you for your business</div>';
   html += '</div>';
 
   // Show in A4 modal
@@ -7332,6 +7372,7 @@ function soGenerateStatementConfirm() {
   document.getElementById('so-doc-a4-content').style.display = 'block';
   document.getElementById('so-doc-modal').classList.add('a4-mode');
   soDocCurrentOrderId = null;
+  soDocCurrentInvoiceId = null;
   document.getElementById('so-doc-modal').style.display = 'flex';
 }
 
