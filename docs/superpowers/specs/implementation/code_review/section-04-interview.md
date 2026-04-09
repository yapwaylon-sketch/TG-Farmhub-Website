# Section 04 Code Review Interview

## Critical Issue Found
- `invUpdateButtons()` referenced old button ID `inv-mark-btn` and label "Mark as Invoiced"
- Auto-fixed: changed to `inv-create-btn` and "Create Invoice"

## Auto-fixes Applied
1. Updated `invUpdateButtons()` button ID from `inv-mark-btn` to `inv-create-btn`
2. Updated button label from "Mark as Invoiced" to "Create Invoice"

## Items Let Go
None — all other aspects of the cleanup were correct.

## Decision
Proceed to commit with fix applied.
