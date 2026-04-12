# Sales Module — Hands-On Test Checklist (2026-04-12)

Post-audit manual testing to verify code-level findings and catch visual/UX issues.
Test on: **phone (Android Chrome)** + **desktop (Chrome/Edge)**. Note results in the checkbox.

---

## A. Critical Bugs (confirm they exist)

### A1. WhatsApp share download broken
- [ ] Open any completed order → View Document (80mm or A4)
- [ ] Tap Share → WhatsApp
- [ ] **Expected bug:** image does NOT auto-download before WhatsApp opens
- [ ] Open DevTools Console — look for `ReferenceError: soDownloadDocImage is not defined`

### A2. delivery.html incomplete records
- [ ] Login to `tgfarmhub.com/delivery.html` as a driver
- [ ] Mark any delivering order as delivered
- [ ] **Check:** Were you asked for qty confirmation? (expected: NO)
- [ ] **Check:** Were you asked to take a photo? (expected: NO)
- [ ] **Check:** For a Cash Sales order, were you asked to collect payment? (expected: NO)
- [ ] Go to `sales.html` → find that order in Completed
- [ ] **Check:** Does it have a delivery photo? (expected: NO)
- [ ] **Check:** Does it show in the correct completed date group? (expected: may be missing/misplaced due to null `completed_at`)

### A3. Form data loss on navigation
- [ ] Open `sales.html` → Orders → Add New Order
- [ ] Select a customer, add 2-3 line items with quantities, type a note
- [ ] **Press F5 (refresh)** — is all data lost? (expected: YES, no warning)
- [ ] Repeat: fill the form, then **click browser Back button** — same result?
- [ ] Repeat: fill the form, then **click a sidebar tab** (e.g., Dashboard) — same result?

---

## B. High Priority (confirm impact)

### B1. Photo modal bypass
- [ ] Start the Mark Prepared flow on any preparing order
- [ ] When the photo modal appears (mandatory), click the **X button** to close it
- [ ] **Check:** Does the order status change? Does it stay on "preparing"? Or is it stuck in a weird state?
- [ ] Repeat: click "Take Photo", then **cancel the file picker** — same check

### B2. Overpayment
- [ ] Go to Payments tab → find a CS order with e.g. RM 50 balance
- [ ] Click Pay → enter RM 5,000 in the amount field
- [ ] **Check:** Does it let you save? (expected: YES — no guard)
- [ ] **Check:** What does the order show after? (payment_status should be "paid" but RM 4,950 is phantom money)

### B3. delivery.html session
- [ ] Login to delivery.html on phone
- [ ] Close the browser tab completely (swipe away)
- [ ] Reopen delivery.html
- [ ] **Check:** Are you still logged in? (expected: NO — uses sessionStorage)

### B4. delivery.html PIN keyboard
- [ ] Open delivery.html on phone
- [ ] Tap the PIN field
- [ ] **Check:** Does a numeric keypad appear? (expected: NO — full text keyboard)
- [ ] **Check:** Does it auto-submit after 6 digits? (expected: NO — must tap Sign In)

### B5. Pcs-ordered items on delivery page
- [ ] Create an order with a pcs-ordered item (e.g., 30 pcs of something)
- [ ] Move it to delivering status
- [ ] Open delivery.html
- [ ] **Check:** Does the item show "30 pcs" or "0 kg"? (expected: "0 kg" — bug)

### B6. Outstanding report
- [ ] Go to Reports → Outstanding Payments
- [ ] **Check:** Are there any pending/preparing/delivering orders in the list? (expected: YES — bug, should be completed only)

### B7. Document modal Escape key
- [ ] Open any order → View Document
- [ ] Press **Escape** key
- [ ] **Check:** Does the modal close? (expected: NO)

---

## C. Medium Priority (UX friction)

### C1. Loading flash on page load
- [ ] Hard refresh `sales.html` (Ctrl+Shift+R)
- [ ] **Check:** Do you see an empty dashboard briefly before data appears?
- [ ] **Check:** How long is the flash? (note: ___ seconds)

### C2. Order edit race condition
- [ ] Open the same order in two browser tabs
- [ ] Edit it in both tabs (change different fields)
- [ ] Save in Tab A, then save in Tab B
- [ ] **Check:** Does Tab B overwrite Tab A's changes silently? (expected: YES)

### C3. Walk-in pcs order
- [ ] Create a walk-in order with ONLY pcs-ordered items
- [ ] Quick Complete it
- [ ] **Check:** What is the grand total? (expected: RM 0.00 — bug)

### C4. Delivery zero qty
- [ ] Move an order to delivering, then Mark Delivered in sales.html
- [ ] In the qty confirmation modal, set ALL quantities to 0
- [ ] **Check:** Does it let you complete? (expected: YES, no warning)

### C5. Invoicing single-draft block
- [ ] Create a draft invoice for Customer A
- [ ] Try to create another draft for Customer B
- [ ] **Check:** Are you blocked? (expected: YES — must cancel/approve A first)

### C6. Products tab usability
- [ ] Go to Manage Products tab
- [ ] **Check:** Is there a search box? (expected: NO)
- [ ] **Check:** Can you filter by category or active/inactive? (expected: NO)
- [ ] **Count:** How many products are listed? Is scrolling practical?

### C7. Invoicing tab search
- [ ] Go to Invoicing tab with multiple customers having uninvoiced DOs
- [ ] **Check:** Is there a search box to find a specific customer or DO? (expected: NO)

### C8. Tab switch scroll
- [ ] Scroll down in Orders tab (past several orders)
- [ ] Switch to Dashboard tab, then back to Orders
- [ ] **Check:** Are you back at the top or at your previous scroll position? (expected: top — scroll lost)

### C9. Batch payment preview
- [ ] Select multiple CS orders for batch payment
- [ ] Enter an amount less than total combined balance
- [ ] **Check:** Can you see which orders get paid first? (expected: NO — silent FIFO)
- [ ] **Check:** Is there a breakdown before you confirm? (expected: NO)

### C10. Calendar popup on mobile
- [ ] Open any date field with the custom calendar picker on phone
- [ ] Scroll the page while calendar is open
- [ ] **Check:** Does the calendar popup stay attached to the field or float away?

---

## D. Visual / Theme Checks (desktop + phone)

### D1. Color/contrast
- [ ] **Check:** Customer name on order cards — readable or washed out?
- [ ] **Check:** Doc number in order detail header — readable or invisible?
- [ ] **Check:** PAID/UNPAID status on CS receipts — green/red as expected?
- [ ] **Check:** Any text that seems invisible or very low contrast?

### D2. Mobile touch targets
- [ ] On phone, try tapping payment checkboxes — easy or frustrating?
- [ ] Try tapping "Replace" / "Remove" links on photos — easy or too small?
- [ ] Try tapping nav items in the sidebar — responsive on first tap?

### D3. Bottom action bar
- [ ] On desktop, **Check:** Does the bottom action bar overlap the sidebar?
- [ ] On phone, **Check:** Does the bottom action bar span full width?

### D4. Large data rendering
- [ ] If you have 50+ completed orders, switch to Orders tab
- [ ] **Check:** Any visible lag or stutter on phone? (note: ___ )

---

## E. TV Display (display-sales.html)

### E1. Stale data awareness
- [ ] Open display-sales.html on a screen
- [ ] Disconnect the network (turn off WiFi)
- [ ] Wait 2+ minutes
- [ ] **Check:** Is there any visual warning that data is stale? (expected: NO — just counter ticking up in tiny text)

### E2. Pcs items
- [ ] Have an active order with pcs-ordered items
- [ ] **Check:** Does the TV display show "0KG" or the correct pcs count?

### E3. Password gate
- [ ] Open display-sales.html → View Page Source
- [ ] **Check:** Can you see the password in the source code? (expected: YES — `tgtukau892312`)

---

## F. Cross-Page Consistency

### F1. Status labels
- [ ] **sales.html:** What does a pending order say? (expected: "Order Received")
- [ ] **delivery.html:** What does the same order say? (note: ___ )
- [ ] **display-sales.html:** What does it say? (expected: "RECEIVED")
- [ ] **Check:** Are these different? Note which ones mismatch.

### F2. Receipt format
- [ ] Generate a receipt from **sales.html** for a completed CS order
- [ ] Generate a receipt from **delivery.html** for the same order
- [ ] **Check:** Do they look the same? Same bank details? Same PAID/UNPAID status? (expected: NO — delivery receipt is outdated)

---

## Results Summary

| Section | Pass | Fail | Notes |
|---------|------|------|-------|
| A. Critical | /3 | /3 | |
| B. High | /7 | /7 | |
| C. Medium | /10 | /10 | |
| D. Visual | /4 | /4 | |
| E. TV Display | /3 | /3 | |
| F. Consistency | /2 | /2 | |
| **TOTAL** | **/29** | **/29** | |

**Tested by:** _______________
**Date:** _______________
**Device (phone):** _______________
**Device (desktop):** _______________
**Browser:** _______________
