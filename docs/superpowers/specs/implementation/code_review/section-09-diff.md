diff --git a/sales.html b/sales.html
index 92ede02..6f565fb 100644
--- a/sales.html
+++ b/sales.html
@@ -900,6 +900,62 @@
   </div>
 </div>
 
+<!-- INVOICE PAYMENT MODAL -->
+<div id="inv-pay-modal" class="modal-overlay" style="display:none;">
+  <div class="modal-box" style="max-width:440px;" onclick="event.stopPropagation()">
+    <div class="modal-header">
+      <div class="modal-title">Record Invoice Payment</div>
+      <button class="modal-close" onclick="closeModal('inv-pay-modal')">
+        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
+      </button>
+    </div>
+    <div style="padding:0 16px 16px;">
+      <div id="inv-pay-info" style="background:var(--bg-hover);border-radius:8px;padding:10px 12px;margin-bottom:14px;font-size:13px;color:var(--text-muted);"></div>
+      <input type="hidden" id="inv-pay-invoice-id" value="">
+      <div class="form-field">
+        <label>AMOUNT (RM)</label>
+        <input type="number" id="inv-pay-amount" step="0.01" min="0.01" style="width:100%;">
+      </div>
+      <div class="form-field">
+        <label>METHOD</label>
+        <select id="inv-pay-method" style="width:100%;">
+          <option value="bank_transfer">Bank Transfer</option>
+          <option value="cash">Cash</option>
+          <option value="cheque">Cheque</option>
+        </select>
+      </div>
+      <div class="form-field">
+        <label>REFERENCE <span style="font-weight:400;color:var(--text-muted);">(optional)</span></label>
+        <input type="text" id="inv-pay-reference" placeholder="e.g. cheque number, bank ref" style="width:100%;">
+      </div>
+      <div class="form-field">
+        <label>PAYMENT DATE</label>
+        <input type="date" id="inv-pay-date" style="width:100%;">
+      </div>
+      <div class="form-field">
+        <label>TRANSFER SLIP <span style="font-weight:400;color:var(--text-muted);">(optional)</span></label>
+        <div id="inv-pay-slip-preview" style="display:none;margin-bottom:8px;position:relative;">
+          <img id="inv-pay-slip-img" src="" style="max-width:100%;max-height:200px;border-radius:8px;border:1px solid var(--border);">
+          <button onclick="invPayClearSlip()" style="position:absolute;top:4px;right:4px;background:rgba(0,0,0,0.6);color:#fff;border:none;border-radius:50%;width:24px;height:24px;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center;">&times;</button>
+        </div>
+        <label style="display:inline-flex;align-items:center;gap:6px;padding:8px 14px;background:var(--bg-input);border:1px solid var(--border);border-radius:8px;cursor:pointer;font-size:13px;color:var(--text);font-weight:500;">
+          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:16px;height:16px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
+          <span id="inv-pay-slip-label">Attach slip</span>
+          <input type="file" id="inv-pay-slip-file" accept="image/*" onchange="invPaySlipPreview(this)" style="display:none;">
+        </label>
+      </div>
+      <div class="form-field">
+        <label>NOTES <span style="font-weight:400;color:var(--text-muted);">(optional)</span></label>
+        <textarea id="inv-pay-notes" rows="2" placeholder="Payment notes" style="width:100%;"></textarea>
+      </div>
+    </div>
+    <div class="modal-actions">
+      <button class="btn btn-outline" onclick="closeModal('inv-pay-modal')">Cancel</button>
+      <button class="btn btn-primary" id="inv-pay-save-btn" onclick="invPaySave()">Save Payment</button>
+    </div>
+  </div>
+</div>
+
 <!-- RETURN MODAL -->
 <div id="ret-modal" class="modal-overlay" style="display:none;">
   <div class="modal-box" style="max-width:480px;" onclick="event.stopPropagation()">
@@ -4609,8 +4665,12 @@ function invRenderList() {
         var invPays = invoicePayments.filter(function(p) { return p.invoice_id === inv.id; });
         html += '<div style="font-size:13px;font-weight:700;color:var(--text);margin-top:12px;margin-bottom:4px;">Payments</div>';
         if (invPays.length) {
+          invPays.sort(function(a, b) { return (b.payment_date || '').localeCompare(a.payment_date || ''); });
           invPays.forEach(function(p) {
-            html += '<div style="font-size:12px;color:var(--text-muted);padding:3px 0;">' + fmtDateNice(p.payment_date) + ' &middot; ' + formatRM(parseFloat(p.amount) || 0) + ' &middot; ' + esc(p.method || '') + (p.reference ? ' (' + esc(p.reference) + ')' : '') + '</div>';
+            var methodLabel = p.method === 'bank_transfer' ? 'Bank Transfer' : p.method === 'cash' ? 'Cash' : p.method === 'cheque' ? 'Cheque' : (p.method || '');
+            html += '<div style="font-size:12px;color:var(--text-muted);padding:3px 0;">' + fmtDateNice(p.payment_date) + ' &middot; ' + formatRM(parseFloat(p.amount) || 0) + ' &middot; ' + esc(methodLabel) + (p.reference ? ' (' + esc(p.reference) + ')' : '');
+            if (p.slip_url) html += ' &middot; <a href="' + esc(p.slip_url) + '" target="_blank" style="color:var(--gold);">View Slip</a>';
+            html += '</div>';
           });
         } else {
           html += '<div style="font-size:12px;color:var(--text-muted);">No payments yet</div>';
@@ -4634,7 +4694,7 @@ function invRenderList() {
           html += '<button class="btn btn-outline btn-sm" onclick="event.stopPropagation();invAddMoreDOs(\'' + esc(inv.id) + '\')">Add More DOs</button>';
         }
         if (inv.status === 'issued') {
-          html += '<button class="btn btn-primary btn-sm" onclick="event.stopPropagation();invOpenPaymentModal(\'' + esc(inv.id) + '\')">Record Payment</button>';
+          if (invoiceBalance(inv) > 0) html += '<button class="btn btn-primary btn-sm" onclick="event.stopPropagation();invOpenPaymentModal(\'' + esc(inv.id) + '\')">Record Payment</button>';
           html += '<button class="btn btn-outline btn-sm" onclick="event.stopPropagation();invOpenCNModal(\'' + esc(inv.id) + '\')">Add Credit Note</button>';
         }
         if (inv.status === 'issued' || inv.payment_status === 'partial' || inv.payment_status === 'paid') {
@@ -4684,7 +4744,132 @@ async function invApproveInvoice(invoiceId) {
     }
   });
 }
-function invOpenPaymentModal(invoiceId) { notify('Invoice payment coming in next update', 'info'); }
+function invOpenPaymentModal(invoiceId) {
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) { notify('Invoice not found', 'warning'); return; }
+  if (inv.status !== 'issued') { notify('Only issued invoices can receive payments', 'warning'); return; }
+  var balance = invoiceBalance(inv);
+  var cust = customers.find(function(c) { return c.id === inv.customer_id; });
+
+  document.getElementById('inv-pay-invoice-id').value = invoiceId;
+  document.getElementById('inv-pay-info').innerHTML =
+    '<div style="font-weight:700;font-size:14px;color:var(--text);margin-bottom:4px;">' + esc(invoiceId) + '</div>' +
+    '<div>' + esc(cust ? cust.name : '—') + '</div>' +
+    '<div>Total: ' + formatRM(parseFloat(inv.grand_total) || 0) +
+    (parseFloat(inv.credit_total) > 0 ? ' &middot; Credits: ' + formatRM(parseFloat(inv.credit_total)) : '') +
+    ' &middot; Paid: ' + formatRM(parseFloat(inv.amount_paid) || 0) + '</div>' +
+    '<div style="font-weight:700;font-size:15px;color:var(--gold);margin-top:4px;">Outstanding: ' + formatRM(balance) + '</div>';
+  document.getElementById('inv-pay-amount').value = balance > 0 ? balance.toFixed(2) : '';
+  document.getElementById('inv-pay-method').value = 'bank_transfer';
+  document.getElementById('inv-pay-reference').value = '';
+  document.getElementById('inv-pay-date').value = todayStr();
+  document.getElementById('inv-pay-notes').value = '';
+  invPayClearSlip();
+  document.getElementById('inv-pay-modal').style.display = 'flex';
+}
+
+async function invPaySave() {
+  var invoiceId = document.getElementById('inv-pay-invoice-id').value;
+  var amount = parseFloat(document.getElementById('inv-pay-amount').value);
+  var method = document.getElementById('inv-pay-method').value;
+  var reference = document.getElementById('inv-pay-reference').value.trim();
+  var payDate = document.getElementById('inv-pay-date').value;
+  var notes = document.getElementById('inv-pay-notes').value.trim();
+  var btn = document.getElementById('inv-pay-save-btn');
+
+  if (!amount || amount <= 0) { notify('Enter a valid amount', 'warning'); return; }
+  if (!payDate) { notify('Payment date is required', 'warning'); return; }
+
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) { notify('Invoice not found', 'warning'); return; }
+  var balance = invoiceBalance(inv);
+  if (amount > balance && balance > 0) {
+    notify('Amount exceeds outstanding balance (' + formatRM(balance) + ')', 'warning');
+  }
+
+  btnLoading(btn, true);
+  try {
+    var paymentId = await dbNextId('IP');
+
+    // Upload slip if attached
+    var slipUrl = null;
+    var fileInput = document.getElementById('inv-pay-slip-file');
+    if (fileInput && fileInput.files && fileInput.files[0]) {
+      slipUrl = await invPayUploadSlip(paymentId);
+    }
+
+    var payData = {
+      id: paymentId,
+      invoice_id: invoiceId,
+      amount: amount,
+      payment_date: payDate,
+      method: method,
+      reference: reference || null,
+      slip_url: slipUrl,
+      notes: notes || null,
+      created_by: currentUser ? currentUser.id : null
+    };
+
+    var result = await sbQuery(sb.from('sales_invoice_payments').insert(payData).select());
+    if (result === null) { btnLoading(btn, false, 'Save Payment'); return; }
+
+    invoicePayments.unshift(result[0] || payData);
+    await recalcInvoicePaymentStatus(invoiceId);
+
+    btnLoading(btn, false, 'Save Payment');
+    closeModal('inv-pay-modal');
+    notify('Payment ' + paymentId + ' recorded (' + formatRM(amount) + ')', 'success');
+    invRenderList();
+  } catch(e) {
+    btnLoading(btn, false, 'Save Payment');
+    notify('Failed to save payment: ' + e.message, 'error');
+  }
+}
+
+function invPaySlipPreview(input) {
+  if (!input.files || !input.files[0]) return;
+  var file = input.files[0];
+  var reader = new FileReader();
+  reader.onload = function(e) {
+    document.getElementById('inv-pay-slip-img').src = e.target.result;
+    document.getElementById('inv-pay-slip-preview').style.display = 'block';
+    document.getElementById('inv-pay-slip-label').textContent = file.name;
+  };
+  reader.readAsDataURL(file);
+}
+
+function invPayClearSlip() {
+  document.getElementById('inv-pay-slip-preview').style.display = 'none';
+  document.getElementById('inv-pay-slip-img').src = '';
+  document.getElementById('inv-pay-slip-label').textContent = 'Attach slip';
+  var fileInput = document.getElementById('inv-pay-slip-file');
+  if (fileInput) fileInput.value = '';
+}
+
+async function invPayUploadSlip(paymentId) {
+  var fileInput = document.getElementById('inv-pay-slip-file');
+  if (!fileInput || !fileInput.files || !fileInput.files[0]) return null;
+  var file = fileInput.files[0];
+  var canvas = document.createElement('canvas');
+  var img = new Image();
+  return new Promise(function(resolve) {
+    img.onload = async function() {
+      var maxW = 1200;
+      var w = img.width, h = img.height;
+      if (w > maxW) { h = Math.round(h * maxW / w); w = maxW; }
+      canvas.width = w; canvas.height = h;
+      canvas.getContext('2d').drawImage(img, 0, 0, w, h);
+      canvas.toBlob(async function(blob) {
+        var path = 'payment-slips/' + paymentId + '.jpg';
+        var result = await sb.storage.from('sales-photos').upload(path, blob, { contentType: 'image/jpeg', upsert: true });
+        if (result.error) { console.error('Slip upload error:', result.error); resolve(null); return; }
+        var urlResult = sb.storage.from('sales-photos').getPublicUrl(path);
+        resolve(urlResult.data.publicUrl);
+      }, 'image/jpeg', 0.8);
+    };
+    img.src = URL.createObjectURL(file);
+  });
+}
 function invOpenCNModal(invoiceId) { notify('Credit notes coming in next update', 'info'); }
 function generateInvoiceA4(invoiceId) {
   var inv = invoices.find(function(i) { return i.id === invoiceId; });
