diff --git a/sales.html b/sales.html
index 0559a35..1ce72ac 100644
--- a/sales.html
+++ b/sales.html
@@ -956,6 +956,44 @@
   </div>
 </div>
 
+<!-- CREDIT NOTE MODAL -->
+<div id="cn-modal" class="modal-overlay" style="display:none;">
+  <div class="modal-box" style="max-width:440px;" onclick="event.stopPropagation()">
+    <div class="modal-header">
+      <div class="modal-title">Add Credit Note</div>
+      <button class="modal-close" onclick="closeModal('cn-modal')">
+        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
+      </button>
+    </div>
+    <div style="padding:0 16px 16px;">
+      <div id="cn-info" style="background:var(--bg-hover);border-radius:8px;padding:10px 12px;margin-bottom:14px;font-size:13px;color:var(--text-muted);"></div>
+      <input type="hidden" id="cn-invoice-id" value="">
+      <div class="form-field">
+        <label>LINKED RETURN <span style="font-weight:400;color:var(--text-muted);">(optional)</span></label>
+        <select id="cn-return-id" style="width:100%;" onchange="cnReturnChanged()">
+          <option value="">None — manual adjustment</option>
+        </select>
+      </div>
+      <div class="form-field">
+        <label>CREDIT DATE</label>
+        <input type="date" id="cn-date" style="width:100%;">
+      </div>
+      <div class="form-field">
+        <label>AMOUNT (RM)</label>
+        <input type="number" id="cn-amount" step="0.01" min="0.01" style="width:100%;">
+      </div>
+      <div class="form-field">
+        <label>REASON (required)</label>
+        <input type="text" id="cn-reason" placeholder="Reason for credit" style="width:100%;">
+      </div>
+    </div>
+    <div class="modal-actions">
+      <button class="btn btn-outline" onclick="closeModal('cn-modal')">Cancel</button>
+      <button class="btn btn-primary" id="cn-save-btn" onclick="cnSave()">Save Credit Note</button>
+    </div>
+  </div>
+</div>
+
 <!-- RETURN MODAL -->
 <div id="ret-modal" class="modal-overlay" style="display:none;">
   <div class="modal-box" style="max-width:480px;" onclick="event.stopPropagation()">
@@ -4681,7 +4719,10 @@ function invRenderList() {
         html += '<div style="font-size:13px;font-weight:700;color:var(--text);margin-top:12px;margin-bottom:4px;">Credit Notes</div>';
         if (invCNs.length) {
           invCNs.forEach(function(cn) {
-            html += '<div style="font-size:12px;color:var(--text-muted);padding:3px 0;">' + esc(cn.id) + ' &middot; ' + fmtDateNice(cn.cn_date) + ' &middot; ' + formatRM(parseFloat(cn.amount) || 0) + (cn.reason ? ' &middot; ' + esc(cn.reason) : '') + '</div>';
+            html += '<div style="font-size:12px;color:var(--text-muted);padding:3px 0;">';
+            html += '<a href="#" onclick="event.preventDefault();event.stopPropagation();generateCreditNoteA4(\'' + esc(cn.id) + '\')" style="color:var(--gold);font-weight:600;">' + esc(cn.id) + '</a>';
+            html += ' &middot; ' + fmtDateNice(cn.credit_date) + ' &middot; ' + formatRM(parseFloat(cn.amount) || 0) + (cn.reason ? ' &middot; ' + esc(cn.reason) : '');
+            html += '</div>';
           });
         } else {
           html += '<div style="font-size:12px;color:var(--text-muted);">No credit notes</div>';
@@ -4871,7 +4912,190 @@ async function invPayUploadSlip(paymentId) {
     img.src = URL.createObjectURL(file);
   });
 }
-function invOpenCNModal(invoiceId) { notify('Credit notes coming in next update', 'info'); }
+function invOpenCNModal(invoiceId) {
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) { notify('Invoice not found', 'warning'); return; }
+  if (inv.status !== 'issued') { notify('Only issued invoices can receive credit notes', 'warning'); return; }
+  var balance = invoiceBalance(inv);
+  var cust = customers.find(function(c) { return c.id === inv.customer_id; });
+
+  document.getElementById('cn-invoice-id').value = invoiceId;
+  document.getElementById('cn-info').innerHTML =
+    '<div style="font-weight:700;font-size:14px;color:var(--text);margin-bottom:4px;">' + esc(invoiceId) + '</div>' +
+    '<div>' + esc(cust ? cust.name : '—') + '</div>' +
+    '<div style="font-weight:700;color:var(--gold);margin-top:4px;">Outstanding: ' + formatRM(balance) + '</div>';
+
+  // Populate return dropdown — get eligible returns for this invoice's orders
+  var linkedOrderIds = invoiceOrders
+    .filter(function(io) { return io.invoice_id === invoiceId; })
+    .map(function(io) { return io.order_id; });
+  var usedReturnIds = creditNotes.map(function(cn) { return cn.return_id; }).filter(Boolean);
+  var eligibleReturns = returns.filter(function(r) {
+    return linkedOrderIds.indexOf(r.order_id) !== -1
+      && r.resolution === 'debit_note'
+      && usedReturnIds.indexOf(r.id) === -1;
+  });
+
+  var sel = document.getElementById('cn-return-id');
+  sel.innerHTML = '<option value="">None — manual adjustment</option>';
+  eligibleReturns.forEach(function(r) {
+    var o = orders.find(function(x) { return x.id === r.order_id; });
+    var label = r.id + ' — ' + formatRM(parseFloat(r.amount) || 0) + (r.reason ? ' (' + r.reason + ')' : '') + (o ? ' [' + (o.doc_number || o.id) + ']' : '');
+    sel.innerHTML += '<option value="' + esc(r.id) + '" data-amount="' + (parseFloat(r.amount) || 0) + '" data-reason="' + esc(r.reason || '') + '">' + esc(label) + '</option>';
+  });
+
+  document.getElementById('cn-date').value = todayStr();
+  document.getElementById('cn-amount').value = '';
+  document.getElementById('cn-amount').readOnly = false;
+  document.getElementById('cn-reason').value = '';
+  document.getElementById('cn-modal').style.display = 'flex';
+}
+
+function cnReturnChanged() {
+  var sel = document.getElementById('cn-return-id');
+  var opt = sel.options[sel.selectedIndex];
+  if (sel.value) {
+    var amt = parseFloat(opt.getAttribute('data-amount')) || 0;
+    var reason = opt.getAttribute('data-reason') || '';
+    document.getElementById('cn-amount').value = amt.toFixed(2);
+    document.getElementById('cn-amount').readOnly = true;
+    document.getElementById('cn-reason').value = reason ? 'Return: ' + reason : 'Return credit';
+  } else {
+    document.getElementById('cn-amount').value = '';
+    document.getElementById('cn-amount').readOnly = false;
+    document.getElementById('cn-reason').value = '';
+  }
+}
+
+async function cnSave() {
+  var invoiceId = document.getElementById('cn-invoice-id').value;
+  var returnId = document.getElementById('cn-return-id').value || null;
+  var creditDate = document.getElementById('cn-date').value;
+  var amount = parseFloat(document.getElementById('cn-amount').value);
+  var reason = document.getElementById('cn-reason').value.trim();
+  var btn = document.getElementById('cn-save-btn');
+
+  if (!amount || amount <= 0) { notify('Enter a valid amount', 'warning'); return; }
+  if (!reason) { notify('Reason is required', 'warning'); return; }
+  if (!creditDate) { notify('Credit date is required', 'warning'); return; }
+
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) { notify('Invoice not found', 'warning'); return; }
+  var balance = invoiceBalance(inv);
+  if (amount > balance) { notify('Amount exceeds outstanding balance (' + formatRM(balance) + ')', 'error'); return; }
+
+  btnLoading(btn, true);
+  try {
+    var cnId = await dbNextId('CN');
+    var cnData = {
+      id: cnId,
+      invoice_id: invoiceId,
+      return_id: returnId,
+      credit_date: creditDate,
+      amount: amount,
+      reason: reason,
+      created_by: currentUser ? currentUser.id : null
+    };
+
+    var result = await sbQuery(sb.from('sales_credit_notes').insert(cnData).select());
+    if (result === null) { btnLoading(btn, false, 'Save Credit Note'); return; }
+
+    creditNotes.unshift(result[0] || cnData);
+
+    // Recalc credit_total on invoice
+    var totalCredits = creditNotes
+      .filter(function(cn) { return cn.invoice_id === invoiceId; })
+      .reduce(function(sum, cn) { return sum + (parseFloat(cn.amount) || 0); }, 0);
+    await sbQuery(sb.from('sales_invoices').update({ credit_total: totalCredits }).eq('id', invoiceId).select());
+    inv.credit_total = totalCredits;
+
+    await recalcInvoicePaymentStatus(invoiceId);
+
+    btnLoading(btn, false, 'Save Credit Note');
+    closeModal('cn-modal');
+    notify('Credit note ' + cnId + ' created (' + formatRM(amount) + ')', 'success');
+    invRenderList();
+  } catch(e) {
+    btnLoading(btn, false, 'Save Credit Note');
+    notify('Failed to save credit note: ' + e.message, 'error');
+  }
+}
+
+function generateCreditNoteA4(cnId) {
+  var cn = creditNotes.find(function(c) { return c.id === cnId; });
+  if (!cn) { notify('Credit note not found', 'warning'); return; }
+  var inv = invoices.find(function(i) { return i.id === cn.invoice_id; });
+  var cust = inv ? customers.find(function(c) { return c.id === inv.customer_id; }) : null;
+  var preparedBy = currentUser ? esc(currentUser.displayName) : '—';
+
+  soDocCurrentInvoiceId = cnId;
+  soDocCurrentOrderId = null;
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
+  html += '<div class="a4-title">CREDIT NOTE</div>';
+  html += '<div class="a4-doc-number">' + esc(cn.id) + '</div>';
+
+  // Info Grid
+  html += '<div class="a4-info-grid">';
+  html += '<div class="a4-info-label">CN Number:</div><div class="a4-info-value">' + esc(cn.id) + '</div>';
+  html += '<div class="a4-info-label">Customer:</div><div class="a4-info-value">' + esc(cust ? cust.name : '—') + '</div>';
+  html += '<div class="a4-info-label">Credit Date:</div><div class="a4-info-value">' + fmtDate(cn.credit_date) + '</div>';
+  html += '<div class="a4-info-label">Invoice Ref:</div><div class="a4-info-value">' + esc(cn.invoice_id || '—') + '</div>';
+  html += '</div>';
+
+  // Reason
+  html += '<div style="margin:16px 0;padding:12px 16px;border:1px solid #ccc;border-radius:4px;background:#fafafa;">';
+  html += '<div style="font-size:11px;font-weight:700;color:#333;margin-bottom:4px;">Reason for Credit</div>';
+  html += '<div style="font-size:13px;color:#000;">' + esc(cn.reason || '—') + '</div>';
+  if (cn.return_id) {
+    html += '<div style="font-size:11px;color:#555;margin-top:6px;">Linked Return: ' + esc(cn.return_id) + '</div>';
+  }
+  html += '</div>';
+
+  // Amount
+  html += '<div style="text-align:center;margin:20px 0;font-size:20px;font-weight:800;">Credit Amount: RM ' + (parseFloat(cn.amount) || 0).toFixed(2) + '</div>';
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
+  html += '<div class="sig-field-label">Signature</div>';
+  html += '</div>';
+  html += '</div>';
+
+  // Footer
+  html += '<div class="a4-footer">This credit note reduces the amount due on the referenced invoice.</div>';
+  html += '</div>';
+
+  // Show in modal
+  document.getElementById('so-doc-content').style.display = 'none';
+  document.getElementById('so-doc-a4-content').innerHTML = html;
+  document.getElementById('so-doc-a4-content').style.display = 'block';
+  document.getElementById('so-doc-modal').classList.add('a4-mode');
+  document.getElementById('so-doc-modal').style.display = 'flex';
+}
 function generateInvoiceA4(invoiceId) {
   var inv = invoices.find(function(i) { return i.id === invoiceId; });
   if (!inv) { notify('Invoice not found', 'warning'); return; }
