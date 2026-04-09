diff --git a/sales.html b/sales.html
index ee902e8..2edb018 100644
--- a/sales.html
+++ b/sales.html
@@ -316,10 +316,25 @@
     <div class="form-field">
       <label>PAYMENT TERMS</label>
       <select id="sc-payment-terms" style="width:100%;">
-        <option value="cash">Cash</option>
-        <option value="credit">Credit</option>
+        <option value="0">COD (Cash on Delivery)</option>
+        <option value="7">Net 7</option>
+        <option value="14">Net 14</option>
+        <option value="30">Net 30</option>
+        <option value="60">Net 60</option>
       </select>
     </div>
+    <div class="form-field">
+      <label>SSM / BRN</label>
+      <input type="text" id="sc-ssm-brn" placeholder="e.g., 1234567-A" style="width:100%;">
+    </div>
+    <div class="form-field">
+      <label>TIN</label>
+      <input type="text" id="sc-tin" placeholder="e.g., C1234567890" style="width:100%;">
+    </div>
+    <div class="form-field">
+      <label>IC NUMBER</label>
+      <input type="text" id="sc-ic-number" placeholder="e.g., 900101-13-1234" style="width:100%;">
+    </div>
     <div class="form-field">
       <label>NOTES</label>
       <textarea id="sc-notes" rows="2" placeholder="Optional notes" style="width:100%;"></textarea>
@@ -2765,8 +2780,8 @@ function renderCustomers() {
   filterHtml += '</select>';
   filterHtml += '<select onchange="scFilterPayment=this.value;renderCustomerCards()" style="min-width:130px;">';
   filterHtml += '<option value=""' + (scFilterPayment === '' ? ' selected' : '') + '>All Payment</option>';
-  filterHtml += '<option value="credit"' + (scFilterPayment === 'credit' ? ' selected' : '') + '>Credit</option>';
-  filterHtml += '<option value="cash"' + (scFilterPayment === 'cash' ? ' selected' : '') + '>Cash</option>';
+  filterHtml += '<option value="cod"' + (scFilterPayment === 'cod' ? ' selected' : '') + '>COD</option>';
+  filterHtml += '<option value="credit"' + (scFilterPayment === 'credit' ? ' selected' : '') + '>Credit (Net 7+)</option>';
   filterHtml += '</select>';
   filterHtml += '</div>';
   filterHtml += '<div id="sc-cards-container"></div>';
@@ -2781,7 +2796,8 @@ function renderCustomerCards() {
 
   var filtered = customers.filter(function(c) {
     if (scFilterType && c.type !== scFilterType) return false;
-    if (scFilterPayment && c.payment_terms !== scFilterPayment) return false;
+    if (scFilterPayment === 'cod' && (c.payment_terms_days || 0) > 0) return false;
+    if (scFilterPayment === 'credit' && (c.payment_terms_days || 0) === 0) return false;
     if (scSearchTerm) {
       var term = scSearchTerm.toLowerCase();
       var nameMatch = (c.name || '').toLowerCase().indexOf(term) >= 0;
@@ -2824,7 +2840,7 @@ function renderCustomerCards() {
     html += '<td>' + esc(c.contact_person || '\u2014') + '</td>';
     html += '<td>' + esc(c.phone || '\u2014') + '</td>';
     html += '<td><span class="badge badge-outline">' + scTypeLabel(c.type) + '</span></td>';
-    html += '<td><span class="badge badge-' + (c.payment_terms === 'credit' ? 'do' : 'cs') + '">' + (c.payment_terms === 'credit' ? 'Credit' : 'Cash') + '</span></td>';
+    html += '<td><span class="badge badge-' + paymentTermsBadgeClass(c.payment_terms_days) + '">' + paymentTermsLabel(c.payment_terms_days) + '</span></td>';
     html += '<td>' + rrHtml + '</td>';
     html += '<td><div style="display:flex;gap:4px;">';
     html += '<button class="btn btn-outline btn-sm" onclick="scOpenModal(\'' + c.id + '\')">Edit</button>';
@@ -2842,6 +2858,16 @@ function scTypeLabel(type) {
   return labels[type] || type || '\u2014';
 }
 
+function paymentTermsLabel(days) {
+  var d = parseInt(days, 10) || 0;
+  if (d === 0) return 'COD';
+  return 'Net ' + d;
+}
+
+function paymentTermsBadgeClass(days) {
+  return (parseInt(days, 10) || 0) > 0 ? 'do' : 'cs';
+}
+
 function scOpenModal(editId) {
   var modal = document.getElementById('sc-modal');
   var title = document.getElementById('sc-modal-title');
@@ -2860,7 +2886,10 @@ function scOpenModal(editId) {
       document.getElementById('sc-address').value = c.address || '';
       document.getElementById('sc-type').value = c.type || 'wholesale';
       document.getElementById('sc-channel').value = c.channel || 'whatsapp_delivery';
-      document.getElementById('sc-payment-terms').value = c.payment_terms || 'cash';
+      document.getElementById('sc-payment-terms').value = String(c.payment_terms_days || 0);
+      document.getElementById('sc-ssm-brn').value = c.ssm_brn || '';
+      document.getElementById('sc-tin').value = c.tin || '';
+      document.getElementById('sc-ic-number').value = c.ic_number || '';
       document.getElementById('sc-notes').value = c.notes || '';
     }
   } else {
@@ -2872,7 +2901,10 @@ function scOpenModal(editId) {
     document.getElementById('sc-address').value = '';
     document.getElementById('sc-type').value = 'wholesale';
     document.getElementById('sc-channel').value = 'whatsapp_delivery';
-    document.getElementById('sc-payment-terms').value = 'cash';
+    document.getElementById('sc-payment-terms').value = '30';
+    document.getElementById('sc-ssm-brn').value = '';
+    document.getElementById('sc-tin').value = '';
+    document.getElementById('sc-ic-number').value = '';
     document.getElementById('sc-notes').value = '';
   }
 
@@ -2902,7 +2934,10 @@ async function scSaveCustomer() {
   var address = document.getElementById('sc-address').value.trim();
   var type = document.getElementById('sc-type').value;
   var channel = document.getElementById('sc-channel').value;
-  var paymentTerms = document.getElementById('sc-payment-terms').value;
+  var paymentTermsDays = parseInt(document.getElementById('sc-payment-terms').value, 10) || 0;
+  var ssmBrn = document.getElementById('sc-ssm-brn').value.trim();
+  var tin = document.getElementById('sc-tin').value.trim();
+  var icNumber = document.getElementById('sc-ic-number').value.trim();
   var notes = document.getElementById('sc-notes').value.trim();
 
   if (!name) { notify('Customer name is required', 'warning'); return; }
@@ -2919,7 +2954,10 @@ async function scSaveCustomer() {
   var data = {
     name: name, phone: phone || null, contact_person: contactPerson || null,
     address: address || null, type: type, channel: channel,
-    payment_terms: paymentTerms, notes: notes || null
+    payment_terms: paymentTermsDays > 0 ? 'credit' : 'cash',
+    payment_terms_days: paymentTermsDays,
+    ssm_brn: ssmBrn || null, tin: tin || null, ic_number: icNumber || null,
+    notes: notes || null
   };
 
   if (editId) {
@@ -3051,13 +3089,16 @@ function scRenderDetail() {
   html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Name</div><div style="font-weight:700;color:var(--white);font-size:15px;">' + esc(c.name) + '</div></div>';
   html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Phone</div><div style="color:var(--text);">' + esc(c.phone || '\u2014') + '</div></div>';
   html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Type</div><div><span class="badge badge-outline">' + scTypeLabel(c.type) + '</span></div></div>';
-  html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Payment Terms</div><div><span class="badge badge-' + (c.payment_terms === 'credit' ? 'do' : 'cs') + '">' + (c.payment_terms === 'credit' ? 'Credit' : 'Cash') + '</span></div></div>';
+  html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Payment Terms</div><div><span class="badge badge-' + paymentTermsBadgeClass(c.payment_terms_days) + '">' + paymentTermsLabel(c.payment_terms_days) + '</span></div></div>';
   if (c.contact_person) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Contact Person</div><div style="color:var(--text);">' + esc(c.contact_person) + '</div></div>';
   if (c.channel) {
     var channelLabels = { whatsapp_delivery: 'WhatsApp Delivery', whatsapp_group: 'WhatsApp Group', phone_call: 'Phone Call', walk_in: 'Walk-in' };
     html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Channel</div><div style="color:var(--text);">' + esc(channelLabels[c.channel] || c.channel) + '</div></div>';
   }
   if (c.address) html += '<div style="grid-column:1/-1;"><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Address</div><div style="color:var(--text);">' + esc(c.address) + '</div></div>';
+  if (c.ssm_brn) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">SSM / BRN</div><div style="color:var(--text);">' + esc(c.ssm_brn) + '</div></div>';
+  if (c.tin) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">TIN</div><div style="color:var(--text);">' + esc(c.tin) + '</div></div>';
+  if (c.ic_number) html += '<div><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">IC Number</div><div style="color:var(--text);">' + esc(c.ic_number) + '</div></div>';
   if (c.notes) html += '<div style="grid-column:1/-1;"><div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;">Notes</div><div style="color:var(--text);">' + esc(c.notes) + '</div></div>';
   html += '</div>';
   html += '<div style="margin-top:10px;display:flex;gap:8px;">';
@@ -4990,7 +5031,7 @@ async function soToggleWalkIn() {
     var walkIn = customers.find(function(c) { return c.name === 'Walk-In Customer'; });
     if (!walkIn) {
       var wId = await dbNextId('SC');
-      var wData = { id: wId, name: 'Walk-In Customer', phone: null, contact_person: null, address: null, type: 'individual', channel: 'walkin', payment_terms: 'cash', notes: 'Auto-created for walk-in sales', is_active: true };
+      var wData = { id: wId, name: 'Walk-In Customer', phone: null, contact_person: null, address: null, type: 'individual', channel: 'walkin', payment_terms: 'cash', payment_terms_days: 0, notes: 'Auto-created for walk-in sales', is_active: true };
       var wResult = await sbQuery(sb.from('sales_customers').insert(wData).select());
       if (wResult) { walkIn = wResult[0] || wData; customers.push(walkIn); }
     }
@@ -5146,7 +5187,7 @@ function soSelectCustomer(customerId) {
   document.getElementById('so-cust-results').style.display = 'none';
 
   // Auto-set doc type based on payment terms
-  if (soSelectedCustomer.payment_terms === 'credit') {
+  if ((soSelectedCustomer.payment_terms_days || 0) > 0) {
     document.getElementById('so-doc-type').value = 'delivery_order';
   } else {
     document.getElementById('so-doc-type').value = 'cash_sales';
@@ -6125,7 +6166,7 @@ function soGenerateStatementConfirm() {
   } else {
     html += '<div class="a4-info-label"></div><div class="a4-info-value"></div>';
   }
-  html += '<div class="a4-info-label">Terms:</div><div class="a4-info-value">' + (cust.payment_terms === 'credit' ? 'Credit' : 'Cash') + '</div>';
+  html += '<div class="a4-info-label">Terms:</div><div class="a4-info-value">' + paymentTermsLabel(cust.payment_terms_days) + '</div>';
   if (cust.address) {
     html += '<div class="a4-info-label">Address:</div><div class="a4-info-value" style="grid-column:span 3;">' + esc(cust.address) + '</div>';
   }
