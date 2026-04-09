diff --git a/sales.html b/sales.html
index b9dad7a..92ede02 100644
--- a/sales.html
+++ b/sales.html
@@ -4661,7 +4661,29 @@ function invToggleInvoice(invoiceId) {
 }
 
 // Stub functions for future sections
-function invApproveInvoice(invoiceId) { notify('Approve workflow coming in next update', 'info'); }
+async function invApproveInvoice(invoiceId) {
+  if (!currentUser || currentUser.role !== 'admin') { notify('Admin access required', 'warning'); return; }
+  var inv = invoices.find(function(i) { return i.id === invoiceId; });
+  if (!inv) { notify('Invoice not found', 'warning'); return; }
+  if (inv.status !== 'draft') { notify('Only draft invoices can be approved', 'warning'); return; }
+
+  confirmAction('Approve Invoice', 'Approve ' + invoiceId + ' and issue to customer? This locks the invoice for editing.', async function() {
+    try {
+      var now = new Date().toISOString();
+      var updates = { status: 'issued', approved_by: currentUser.id, approved_at: now };
+      var result = await sbUpdateWithLock('sales_invoices', invoiceId, updates, inv.updated_at);
+      if (result === null) return;
+      inv.status = 'issued';
+      inv.approved_by = currentUser.id;
+      inv.approved_at = now;
+      if (result[0] && result[0].updated_at) inv.updated_at = result[0].updated_at;
+      notify('Invoice ' + invoiceId + ' approved and issued', 'success');
+      invRenderList();
+    } catch(e) {
+      notify('Failed to approve: ' + e.message, 'error');
+    }
+  });
+}
 function invOpenPaymentModal(invoiceId) { notify('Invoice payment coming in next update', 'info'); }
 function invOpenCNModal(invoiceId) { notify('Credit notes coming in next update', 'info'); }
 function generateInvoiceA4(invoiceId) {
