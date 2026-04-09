# Section 07 Code Review Interview

## Auto-fixes Applied

### 1. Duplicate `var cust` in `soOpenWhatsAppDoc` (MEDIUM)
- **Issue:** Both `if` and `else` branches declared `var cust`, causing duplicate hoisted declarations
- **Fix:** Hoisted `var cust` to function top, removed `var` keyword from both branch assignments
- **Risk:** None - pure cleanup, no behavior change

## Items Let Go

### 2. Product unit column empty when product deleted (LOW)
- No snapshot for unit field in invoice items table. Acceptable - products rarely deleted.

### 3. DO reference escaping (LOW)
- `esc()` on joined string is safe. Doc numbers don't contain HTML characters.

### 4. All INFO items confirmed correct per spec
- Balance Due always shown (correct)
- fmtDateShort regex for DD/MM format (correct)
- soDocCurrentInvoiceId lifecycle (correct)
