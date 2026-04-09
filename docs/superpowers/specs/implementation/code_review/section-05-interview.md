# Section 05 Code Review Interview

## Review Summary
Code review passed. 1 important fix found and applied.

## Auto-fixes Applied
1. Added `onchange="invUpdateDueDate()"` to invoice date input — due date now recalculates when either date or terms change

## Items Let Go
- S-1: Sequential dbNextId calls — N is small, no performance concern
- S-2: No cross-customer DO guard — UI already constrains this

## Decision
Proceed to commit with fix applied.
