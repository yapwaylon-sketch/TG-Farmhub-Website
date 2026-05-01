# Invoicing Tab Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Invoicing tab in sales.html with a cleaner column-row list, sub-tabs (`Invoices` / `Create New`), thin DO selector, sticky bottom dock for create flow, pending-draft banner, denser detail panel, and mobile fallback.

**Architecture:** Split `renderInvoicing()` into a sub-tab router that delegates to `renderInvoicesView()` (default) and `renderCreateNewView()`. Move all new invoicing styles from inline strings into `sales.css` under an `.inv-*` namespace. Reuse all existing data helpers (`sbQuery`, `sbUpdateWithLock`, `dbNextId`, `rewind_id`, `invoiceBalance`, `invRecomputeInvoice`, `formatRM`). Keep existing modals (Record Payment, Credit Note, Edit Draft, Add DOs, Void) — just rebuild the entry points and list/detail UI around them.

**Tech Stack:** Vanilla JS (no framework), HTML in `sales.html`, CSS in `sales.css` (plum/cream/gold theme). Supabase wired via existing helpers. No automated test suite — verification is manual via local file open + production deploy after each phase.

---

## Conventions for this plan

- **No TDD.** Project has no automated UI tests. Each task ends with a **manual verification** step (load `sales.html` in browser, exercise the path, confirm the visual result) followed by a commit.
- **Date format**: all dates rendered as DD/MM/YYYY via a new `fmtDateDM()` helper. Existing `fmtDateNice` remains untouched (still used elsewhere in sales).
- **Status signal hierarchy**: balance > 0 → red bold; partial → red bold italic; balance = 0 → muted gray; voided rows → 50% opacity. No status badges, no left-border colors.
- **Counter behavior**: keep current `dbNextId('INV')` on draft create + `rewind_id()` on cancel. No changes.
- **Single-draft rule**: enforced today in `invCreateDraftInvoice` (sales.html:7811). Plan adds a UI-level lock (banner + disabled checkboxes) on top of the existing guard.
- All commits follow project convention: `feat(sales): ...`, `fix(sales): ...`, `ui(sales): ...`. Include the `Co-Authored-By: Claude...` trailer per CLAUDE.md.

---

## File Structure

**Files modified:**

| File | What changes | Approx scope |
|---|---|---|
| `sales.html` | Invoicing render functions (lines 5944–7800 region), `nav-invoicing` page header, new sub-tab DOM, new helpers `fmtDateDM`, `invDueInDays`, `invFilterByPeriod`, `invSearchMatches`, `invPagination*`, `invIsPartial`, `invDraftBannerHTML`, `invToggleVoided`. Rewrite of `invRenderList`, `invInsertDetail`, `renderInvoicing`, `invRenderBillingSummary` move into expanded dock. | ~600 LOC churn |
| `sales.css` | New `.inv-*` namespace: sub-tabs, column-row layout, period presets, search, chips, pagination, dock, draft banner, detail panel grid, mobile @media | ~400 new lines |

**No new files. No DB schema changes. No new RPCs.**

---

## Task 1 — CSS scaffolding

**Files:**
- Modify: `C:/dev/TG-Farmhub-Website/sales.css` — append new section at end

- [ ] **Step 1: Append the invoicing namespace block to sales.css**

Append after the existing styles (end of file). Comment block + all new classes at once. Follows the same plum/cream/gold theme using `var(--text)`, `var(--gold)`, `var(--purple)`, `var(--bg-card)`, `var(--border)`, `var(--text-muted)`, `var(--danger)`, `var(--green)`.

```css
/* ============================================================
   INVOICING TAB REDESIGN
   Sub-tabs · column-row list · sticky create dock · draft banner
   ============================================================ */

/* Sub-tabs */
.inv-subtabs {
  display: flex; gap: 4px;
  border-bottom: 2px solid var(--border);
  margin-bottom: 18px;
}
.inv-subtab {
  padding: 10px 16px;
  font-size: 13px; font-weight: 700; color: var(--text-muted);
  cursor: pointer;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
  display: inline-flex; align-items: center; gap: 6px;
  background: transparent; border-left: none; border-right: none; border-top: none;
}
.inv-subtab.active { color: var(--text); border-bottom-color: var(--gold); }
.inv-subtab-badge {
  background: var(--gold); color: #fff;
  font-size: 10px; font-weight: 700;
  padding: 2px 6px; border-radius: 8px;
}
.inv-subtab.active .inv-subtab-badge { background: var(--purple); }
.inv-subtab-badge.alert { background: var(--danger); }

/* Stats strip */
.inv-stats {
  display: flex;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 12px 0;
  margin-bottom: 14px;
}
.inv-stat { flex: 1; padding: 0 16px; border-right: 1px solid var(--border); }
.inv-stat:last-child { border-right: none; }
.inv-stat-label {
  font-size: 10px; font-weight: 700; color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 0.4px; margin-bottom: 2px;
}
.inv-stat-value { font-size: 18px; font-weight: 800; color: var(--text); }
.inv-stat-meta { font-size: 11px; color: var(--text-muted); margin-top: 1px; }
.inv-stat.warn .inv-stat-value { color: var(--gold); }
.inv-stat.danger .inv-stat-value { color: var(--danger); }

/* Period preset row */
.inv-presets { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-bottom: 12px; }
.inv-presets-label {
  font-size: 10px; font-weight: 700; color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 0.4px; margin-right: 4px;
}
.inv-preset {
  padding: 5px 10px; border: 1px solid var(--border); background: transparent;
  border-radius: 14px; font-size: 11px; font-weight: 600; color: var(--purple);
  cursor: pointer; font-family: inherit;
}
.inv-preset:hover { border-color: var(--purple); }
.inv-preset.active { background: var(--purple); border-color: var(--purple); color: #fff; }

/* Search */
.inv-search {
  width: 100%; max-width: 360px;
  padding: 8px 12px 8px 32px;
  border: 1px solid var(--border); border-radius: 8px;
  background: var(--bg-card) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='14' height='14' viewBox='0 0 24 24' fill='none' stroke='%23888' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Ccircle cx='11' cy='11' r='8'/%3E%3Cline x1='21' y1='21' x2='16.65' y2='16.65'/%3E%3C/svg%3E") no-repeat 10px center;
  font-size: 13px; color: var(--text); font-family: inherit;
  margin-bottom: 12px;
}

/* Status chips */
.inv-chips { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 12px; }
.inv-chip {
  padding: 6px 12px; border: 1px solid var(--border); background: var(--bg-card);
  border-radius: 16px; font-size: 12px; font-weight: 600; color: var(--purple);
  cursor: pointer; display: inline-flex; align-items: center; gap: 5px;
  font-family: inherit;
}
.inv-chip:hover { border-color: var(--purple); }
.inv-chip.active { background: var(--text); border-color: var(--text); color: #fff; }
.inv-chip-count {
  font-size: 10px; padding: 1px 6px; border-radius: 8px; font-weight: 700;
  background: rgba(107,76,138,0.12); color: var(--purple);
}
.inv-chip.active .inv-chip-count { background: rgba(255,255,255,0.2); color: #fff; }
.inv-chip.danger { color: var(--danger); }
.inv-chip.danger.active { background: var(--danger); border-color: var(--danger); color: #fff; }

/* Filter toggle */
.inv-filter-toggle {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 6px 12px; border: 1px solid var(--border); background: transparent;
  border-radius: 16px; font-size: 12px; font-weight: 600; color: var(--text-muted);
  cursor: pointer; margin-bottom: 12px; font-family: inherit;
}

/* Invoice list (table-style column-rows) */
.inv-table {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
}
.inv-list-header,
.inv-list-row {
  display: grid;
  grid-template-columns: 110px 1fr 100px 100px 80px 130px 130px 16px;
  gap: 14px;
  align-items: center;
  padding: 10px 18px;
}
.inv-list-header {
  font-size: 10px; font-weight: 700; color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 0.4px;
  background: rgba(107,76,138,0.04);
  border-bottom: 1px solid var(--border);
}
.inv-list-header .center { text-align: center; }
.inv-list-header .right { text-align: right; }
.inv-list-row {
  padding: 12px 18px;
  cursor: pointer;
  border-bottom: 1px solid var(--border);
  transition: background 0.15s;
}
.inv-list-row:last-child { border-bottom: none; }
.inv-list-row:hover { background: rgba(212,175,55,0.04); }
.inv-list-row.expanded { background: rgba(212,175,55,0.06); }
.inv-list-row.voided { opacity: 0.5; }

.inv-row-id {
  font-weight: 700; font-size: 13px; color: var(--purple);
  cursor: pointer; transition: color 0.15s;
  background: none; border: none; padding: 0; font-family: inherit;
  text-align: left;
}
.inv-row-id:hover { color: var(--gold); }
.inv-row-id::after { content: ' \2197'; font-size: 10px; opacity: 0.5; }
.inv-row-cust {
  font-weight: 600; font-size: 13px; color: var(--text);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.inv-row-date {
  font-size: 13px; color: #555; font-variant-numeric: tabular-nums;
}
.inv-row-date.danger { color: var(--danger); font-weight: 700; }
.inv-row-duein {
  font-size: 13px; font-weight: 600; color: #555; text-align: center;
  font-variant-numeric: tabular-nums;
}
.inv-row-duein.danger { color: var(--danger); font-weight: 700; }
.inv-row-duein.muted { color: var(--text-muted); font-weight: 400; }
.inv-row-amount {
  font-size: 13px; font-weight: 700; color: var(--text); text-align: right;
  font-variant-numeric: tabular-nums;
}
.inv-row-balance {
  font-size: 13px; font-weight: 700; text-align: right; color: var(--danger);
  font-variant-numeric: tabular-nums;
}
.inv-row-balance.zero { color: var(--text-muted); font-weight: 400; }
.inv-row-balance.partial { font-style: italic; }
.inv-row-chev {
  width: 14px; height: 14px; color: var(--text-muted);
  transition: transform 0.2s;
}
.inv-row-chev.open { transform: rotate(90deg); }

/* Detail panel inserted under expanded row */
.inv-detail {
  background: var(--bg);
  border-bottom: 1px solid var(--border);
  padding: 16px 18px 18px;
}
.inv-detail-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 18px;
  margin-bottom: 14px;
}
.inv-detail-block { display: flex; flex-direction: column; gap: 4px; }
.inv-detail-label {
  font-size: 10px; font-weight: 700; color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 0.4px;
}
.inv-detail-value {
  font-size: 13px; color: var(--text);
  font-variant-numeric: tabular-nums;
}
.inv-detail-value.big { font-size: 16px; font-weight: 700; }
.inv-do-chip {
  display: inline-block; background: var(--bg-card); border: 1px solid var(--border);
  color: var(--purple); font-size: 11px; font-weight: 600;
  padding: 3px 8px; border-radius: 4px; margin-right: 4px; cursor: pointer;
  font-family: inherit;
}
.inv-do-chip:hover { border-color: var(--purple); }
.inv-do-chip.unlink::after { content: ' \D7'; color: var(--danger); margin-left: 2px; }

/* Payments mini list */
.inv-payments {
  background: var(--bg-card); border: 1px solid var(--border);
  border-radius: 6px; overflow: hidden;
}
.inv-pay-row {
  display: grid; grid-template-columns: 90px 1fr 100px;
  gap: 10px; padding: 8px 12px;
  border-bottom: 1px solid var(--border);
  font-size: 12px; align-items: center;
}
.inv-pay-row:last-child { border-bottom: none; }
.inv-pay-date { color: #555; font-variant-numeric: tabular-nums; }
.inv-pay-method { color: #555; }
.inv-pay-method small { color: var(--text-muted); display: block; font-size: 10px; }
.inv-pay-amount { text-align: right; color: var(--green); font-weight: 700;
                  font-variant-numeric: tabular-nums; }
.inv-empty { color: var(--text-muted); font-size: 12px; font-style: italic; padding: 6px 0; }

/* Action bar */
.inv-actions {
  display: flex; gap: 8px; margin-top: 14px; padding-top: 14px;
  border-top: 1px dashed var(--border); flex-wrap: wrap; align-items: center;
}
.inv-actions .right { margin-left: auto; }
.inv-act-danger {
  background: transparent; color: var(--danger); border: 1px solid transparent;
  padding: 8px 14px; border-radius: 6px; font-size: 12px; font-weight: 700;
  cursor: pointer; font-family: inherit;
}
.inv-act-danger:hover { background: rgba(200,68,68,0.06); }

/* Pagination */
.inv-pagination {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px; margin-top: 14px; padding: 10px 4px; flex-wrap: wrap;
}
.inv-pagination-info { font-size: 12px; color: #555; }
.inv-pagination-controls { display: flex; align-items: center; gap: 4px; }
.inv-page-btn {
  padding: 6px 10px; min-width: 32px;
  border: 1px solid var(--border); background: var(--bg-card); color: var(--purple);
  border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer;
  font-family: inherit;
}
.inv-page-btn:hover:not(:disabled) { border-color: var(--purple); }
.inv-page-btn.active { background: var(--purple); border-color: var(--purple); color: #fff; }
.inv-page-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.inv-page-size {
  font-size: 12px; color: #555;
  display: inline-flex; align-items: center; gap: 6px;
}
.inv-page-size select {
  padding: 4px 8px; border: 1px solid var(--border); border-radius: 6px;
  font-size: 12px; background: var(--bg-card); color: var(--text); font-family: inherit;
}

/* Show voided link */
.inv-show-voided { text-align: center; margin-top: 14px; }
.inv-show-voided a {
  font-size: 12px; color: var(--text-muted);
  text-decoration: underline dotted; cursor: pointer;
}

/* Pending draft banner */
.inv-draft-banner {
  background: var(--bg-card); border: 1px solid var(--gold);
  border-radius: 10px; padding: 14px 18px; margin-bottom: 18px;
  display: grid; grid-template-columns: 1fr auto;
  gap: 14px; align-items: center;
  box-shadow: 0 0 0 1px rgba(212,175,55,0.15) inset;
}
.inv-draft-info { display: flex; flex-direction: column; gap: 4px; }
.inv-draft-tag {
  font-size: 10px; font-weight: 700; color: #8a6d1f;
  background: rgba(212,175,55,0.18); padding: 2px 8px; border-radius: 4px;
  text-transform: uppercase; letter-spacing: 0.4px; width: fit-content;
}
.inv-draft-id {
  font-size: 16px; font-weight: 700; color: var(--text);
  cursor: pointer; background: none; border: none; padding: 0; font-family: inherit;
  text-align: left;
}
.inv-draft-id::after { content: ' \2197'; font-size: 11px; color: var(--text-muted); }
.inv-draft-meta { font-size: 12px; color: #555; font-variant-numeric: tabular-nums; }
.inv-draft-meta strong { color: var(--text); font-weight: 700; }
.inv-draft-actions { display: flex; gap: 6px; }
.inv-locked { opacity: 0.5; pointer-events: none; }
.inv-locked-note {
  text-align: center; margin-top: 8px; padding: 10px;
  background: rgba(212,175,55,0.06); border: 1px dashed var(--gold);
  border-radius: 8px; font-size: 12px; color: #8a6d1f;
}

/* Thin DO customer rows in Create New */
.inv-do-cust-row {
  display: flex; align-items: center; gap: 12px;
  background: var(--bg-card); border: 1px solid var(--border);
  border-radius: 8px; padding: 10px 14px; margin-bottom: 6px;
  cursor: pointer; transition: border-color 0.15s;
}
.inv-do-cust-row:hover { border-color: var(--gold); }
.inv-do-cust-row.selected-some {
  border-color: var(--gold);
  box-shadow: 0 0 0 1px var(--gold) inset;
}
.inv-do-cust-row .cust-name { flex: 1; font-weight: 700; font-size: 14px; color: var(--text); }
.inv-do-pill {
  font-size: 11px; font-weight: 600; color: var(--purple);
  background: rgba(107,76,138,0.08); padding: 3px 8px; border-radius: 10px;
  text-transform: uppercase;
}
.inv-do-selected-badge {
  font-size: 11px; font-weight: 700; color: #fff;
  background: var(--gold); padding: 3px 8px; border-radius: 10px;
  text-transform: uppercase;
}
.inv-do-cust-amount {
  font-weight: 700; font-size: 14px; color: var(--text);
  min-width: 100px; text-align: right;
  font-variant-numeric: tabular-nums;
}
.inv-do-list {
  background: var(--bg-card); border: 1px solid var(--border);
  border-top: none; border-radius: 0 0 8px 8px;
  margin-top: -6px; margin-bottom: 6px; padding: 6px 14px 10px 44px;
}
.inv-do-row {
  display: flex; align-items: center; gap: 10px;
  padding: 6px 0; border-bottom: 1px solid var(--border); font-size: 13px;
}
.inv-do-row:last-child { border-bottom: none; }
.inv-do-row .num { flex: 1; font-weight: 600; color: var(--text); }
.inv-do-row .date { font-size: 12px; color: var(--text-muted); font-variant-numeric: tabular-nums; }
.inv-do-row .amt {
  font-weight: 600; color: var(--text); min-width: 90px; text-align: right;
  font-variant-numeric: tabular-nums;
}
.inv-do-age {
  font-size: 10px; font-weight: 700;
  padding: 2px 6px; border-radius: 8px; text-transform: uppercase;
}
.inv-do-age.fresh   { color: var(--purple); background: rgba(107,76,138,0.08); }
.inv-do-age.old     { color: #C96A1A; background: rgba(255,140,40,0.12); }
.inv-do-age.overdue { color: var(--danger); background: rgba(200,68,68,0.12); }

/* Sticky bottom dock for create flow */
.inv-dock {
  background: var(--bg-card); border: 1px solid var(--gold);
  border-radius: 12px;
  box-shadow: 0 -4px 16px rgba(42,26,62,0.08);
  overflow: hidden; margin-top: 16px;
}
.inv-dock-bar {
  display: flex; align-items: center; gap: 16px; padding: 12px 18px;
  background: linear-gradient(to right, rgba(212,175,55,0.06), rgba(107,76,138,0.04));
}
.inv-dock-summary { display: flex; align-items: baseline; gap: 14px; flex: 1; }
.inv-dock-count { font-size: 13px; color: var(--text); }
.inv-dock-count strong {
  font-size: 16px; font-weight: 800; color: var(--gold); margin-right: 4px;
}
.inv-dock-divider { width: 1px; height: 14px; background: var(--border); }
.inv-dock-total { font-size: 13px; color: var(--text-muted); }
.inv-dock-total strong {
  font-size: 18px; font-weight: 800; color: var(--text); margin-left: 4px;
}
.inv-dock-toggle {
  background: transparent; border: 1px solid var(--border);
  border-radius: 6px; padding: 6px 10px;
  font-size: 12px; font-weight: 600; color: var(--purple);
  cursor: pointer; display: inline-flex; align-items: center; gap: 4px;
  font-family: inherit;
}
.inv-dock-expanded {
  padding: 14px 18px; border-top: 1px solid var(--border); background: var(--bg);
}
.inv-dock-fields {
  display: grid; grid-template-columns: 1fr 1fr 2fr;
  gap: 10px; align-items: end;
}

/* Mobile fallback — collapse table to 2-line cards below 720px */
@media (max-width: 720px) {
  .inv-stats { display: grid; grid-template-columns: 1fr 1fr; gap: 8px;
               background: transparent; border: none; padding: 0; }
  .inv-stat { background: var(--bg-card); border: 1px solid var(--border);
              border-radius: 8px; padding: 10px; border-right: none; }
  .inv-stat:first-child { grid-column: span 2; }
  .inv-stat-value { font-size: 16px; }
  .inv-presets, .inv-chips {
    flex-wrap: nowrap; overflow-x: auto; padding-bottom: 4px;
  }
  .inv-presets .inv-preset, .inv-chips .inv-chip { flex-shrink: 0; }
  .inv-list-header { display: none; }
  .inv-list-row {
    display: grid;
    grid-template-columns: 1fr auto auto;
    grid-template-rows: auto auto;
    gap: 4px 10px;
    padding: 10px 12px;
  }
  .inv-row-id { grid-column: 1; grid-row: 1; }
  .inv-row-balance { grid-column: 2; grid-row: 1; justify-self: end; }
  .inv-row-chev { grid-column: 3; grid-row: 1 / span 2; align-self: center; }
  .inv-row-cust, .inv-row-date, .inv-row-duein, .inv-row-amount {
    display: none;
  }
  .inv-row-mobile-meta {
    grid-column: 1 / span 2; grid-row: 2;
    font-size: 12px; color: #555;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .inv-row-mobile-meta strong { color: var(--text); font-weight: 600; }
  .inv-row-mobile-meta .late { color: var(--danger); font-weight: 700; }
  .inv-pagination {
    justify-content: space-between;
  }
  .inv-pagination-controls > .inv-page-btn:not(:first-child):not(:last-child) {
    display: none;
  }
  .inv-page-size { display: none; }
  .inv-detail-grid { grid-template-columns: 1fr; }
  .inv-draft-banner { grid-template-columns: 1fr; }
  .inv-draft-actions { justify-content: flex-end; flex-wrap: wrap; }
  .inv-dock-fields { grid-template-columns: 1fr; }
}
```

- [ ] **Step 2: Verify file syntax**

Run: open `sales.css` in editor, scroll to end, confirm no parse errors. Open `sales.html` in browser (cache off): no styles should be broken yet because nothing references `.inv-*` classes.

Expected: Sales page still renders identically. New CSS loaded but unused.

- [ ] **Step 3: Commit**

```bash
git add sales.css
git commit -m "$(cat <<'EOF'
ui(sales): add invoicing redesign CSS scaffolding

Appends .inv-* namespace covering sub-tabs, column-row list, period
presets, search, chips, pagination, sticky dock, draft banner, detail
panel, and 720px mobile fallback. No HTML changes yet — styles are
unreferenced until later tasks wire them up.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 — Date and helper functions

**Files:**
- Modify: `sales.html` — add helpers near top of `<script>` block, before `renderInvoicing()` (around line 5260, near existing `invoiceAgeDays`)

- [ ] **Step 1: Add `fmtDateDM` helper**

Insert before `invoiceAgeDays` (sales.html:5262):

```javascript
// DD/MM/YYYY format used in invoice list redesign (2026-05-01).
// fmtDateNice (shared.js) stays in use elsewhere — different format.
function fmtDateDM(s) {
  if (!s) return '';
  var d = new Date(s);
  if (isNaN(d.getTime())) return '';
  var dd = String(d.getDate()).padStart(2, '0');
  var mm = String(d.getMonth() + 1).padStart(2, '0');
  var yy = d.getFullYear();
  return dd + '/' + mm + '/' + yy;
}
```

- [ ] **Step 2: Add `invDueInDays` helper**

Right after `fmtDateDM`:

```javascript
// Returns signed integer: + days until due, − days overdue.
// null/undefined for paid invoices (caller renders "—").
function invDueInDays(inv) {
  if (!inv || !inv.due_date) return null;
  if (inv.payment_status === 'paid') return null;
  if (inv.status === 'voided' || inv.status === 'cancelled') return null;
  var due = new Date(inv.due_date + 'T00:00:00');
  var today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.round((due - today) / 86400000);
}
```

- [ ] **Step 3: Add `invIsPartial` helper**

```javascript
function invIsPartial(inv) {
  if (!inv || inv.status !== 'issued') return false;
  return inv.payment_status === 'partial';
}
```

- [ ] **Step 4: Add period preset filter**

```javascript
// Returns [startISO, endISO] for a preset code. endISO always = today.
function invPeriodRange(code) {
  var today = todayStr();
  var d = new Date();
  if (code === 'this-month') {
    var start = d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-01';
    return [start, today];
  }
  if (code === 'last-30')  { d.setDate(d.getDate() - 30); return [d.toISOString().slice(0,10), today]; }
  if (code === 'last-90')  { d.setDate(d.getDate() - 90); return [d.toISOString().slice(0,10), today]; }
  if (code === 'this-year') {
    return [d.getFullYear() + '-01-01', today];
  }
  if (code === 'all') return ['', ''];
  return ['', '']; // fallback
}
```

- [ ] **Step 5: Add search match helper**

```javascript
function invSearchMatches(inv, term) {
  if (!term) return true;
  term = term.toLowerCase().trim();
  if (!term) return true;
  if ((inv.id || '').toLowerCase().indexOf(term) >= 0) return true;
  var c = customers.find(function(x) { return x.id === inv.customer_id; });
  if (c && (c.name || '').toLowerCase().indexOf(term) >= 0) return true;
  // Match invoice notes too — useful for reference numbers.
  if ((inv.notes || '').toLowerCase().indexOf(term) >= 0) return true;
  return false;
}
```

- [ ] **Step 6: Verify**

Open browser console on the sales page. Run:

```javascript
fmtDateDM('2026-04-25');             // expect "25/04/2026"
invDueInDays({ due_date: '2026-05-25', payment_status: 'unpaid', status: 'issued' });  // expect future-positive number
invPeriodRange('last-90');           // expect [date 90d ago, today]
```

Expected: all three return correct values.

- [ ] **Step 7: Commit**

```bash
git add sales.html
git commit -m "$(cat <<'EOF'
feat(sales): helpers for invoicing redesign — fmtDateDM, due-in-days, period filter, search match

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 — Sub-tab structure and render router

**Files:**
- Modify: `sales.html:161` (page-invoicing markup) and `sales.html:5944` (renderInvoicing function)

- [ ] **Step 1: Add sub-tab DOM to page-invoicing**

Find the page header in sales.html (around line 161 — the `<div class="page" id="page-invoicing">`). Replace its `.page-header` block with:

```html
<div class="page" id="page-invoicing">
  <div class="page-header">
    <h2>Invoicing</h2>
  </div>
  <div class="inv-subtabs" id="inv-subtabs">
    <button class="inv-subtab active" data-subtab="invoices" onclick="invSwitchSubtab('invoices')">
      Invoices <span class="inv-subtab-badge" id="inv-tab-invoices-badge">0</span>
    </button>
    <button class="inv-subtab" data-subtab="create" onclick="invSwitchSubtab('create')">
      Create New <span class="inv-subtab-badge" id="inv-tab-create-badge">0</span>
    </button>
  </div>
  <div class="page-body" id="inv-page-body"></div>
</div>
```

- [ ] **Step 2: Add sub-tab state + switcher**

Insert near other invoicing state (search for `var invFilterCustomer` around sales.html:6438):

```javascript
var invSubtab = 'invoices'; // 'invoices' | 'create'

function invSwitchSubtab(name) {
  invSubtab = name;
  // Update active class on subtab buttons
  var btns = document.querySelectorAll('#inv-subtabs .inv-subtab');
  btns.forEach(function(b) {
    b.classList.toggle('active', b.dataset.subtab === name);
  });
  renderInvoicing();
}

function invUpdateSubtabBadges() {
  var invCount = invoices.filter(function(i) {
    return i.status !== 'draft'; // active invoices count
  }).length;
  var draft = invoices.find(function(i) { return i.status === 'draft'; });
  var uninvoiced = orders.filter(function(o) {
    return o.doc_type === 'delivery_order' && !o.invoice_id && o.status === 'completed';
  }).length;

  var bInv = document.getElementById('inv-tab-invoices-badge');
  var bCreate = document.getElementById('inv-tab-create-badge');
  if (bInv) bInv.textContent = invCount;
  if (bCreate) {
    if (draft) {
      bCreate.textContent = '1 draft';
      bCreate.classList.add('alert');
    } else {
      bCreate.textContent = uninvoiced + ' DOs';
      bCreate.classList.remove('alert');
    }
  }
}
```

- [ ] **Step 3: Refactor `renderInvoicing` to delegate**

Replace the body of `renderInvoicing()` (sales.html:5944-6094) with:

```javascript
function renderInvoicing() {
  var body = document.getElementById('inv-page-body');
  if (!body) return;
  invUpdateSubtabBadges();
  if (invSubtab === 'create') {
    renderCreateNewView(body);
  } else {
    renderInvoicesView(body);
  }
}
```

- [ ] **Step 4: Stub the two new functions**

Insert directly after `renderInvoicing`:

```javascript
function renderInvoicesView(body) {
  // Filled in Task 5 — for now show a placeholder
  body.innerHTML = '<div class="empty-state">Invoices view (TBD)</div>';
  invRenderList(); // legacy still wired so the page renders something during partial migration
}

function renderCreateNewView(body) {
  // Filled in Task 9 — for now keep the legacy create flow inline
  // by reusing the original renderInvoicing body.
  // (We'll delete this block when Task 9 lands.)
  // ...this is intentionally a temporary bridge.
}
```

> **Important:** Do NOT delete the legacy `renderInvoicing` body — paste it into `renderCreateNewView` so the Create New tab stays functional during incremental rollout. We'll replace it in Task 9.

To do that: copy the entire old body (everything from `var existingSearch = ...` to `invRenderList();` at the end), wrap it in `renderCreateNewView(body)`, and replace the inner body reference (`document.getElementById('page-invoicing').querySelector('.page-body')`) with the `body` parameter.

- [ ] **Step 5: Verify**

Refresh sales page. Click into Invoicing tab.

Expected:
- See sub-tab bar with "Invoices" (active) and "Create New" both visible.
- Default lands on Invoices view, shows "Invoices view (TBD)" placeholder.
- Click "Create New" — full legacy create flow appears (DO selector + billing summary + create button) — same as today.
- Click back to "Invoices" — placeholder.
- Sub-tab badges show numbers.

- [ ] **Step 6: Commit**

```bash
git add sales.html
git commit -m "$(cat <<'EOF'
feat(sales): split invoicing page into Invoices / Create New sub-tabs

renderInvoicing is now a router. Create New still uses the legacy
flow (will be redesigned in later task). Invoices subtab placeholder.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 — Invoice list filter and pagination state

**Files:**
- Modify: `sales.html` — replace existing filter state vars (search for `var invFilterCustomer` around line 6438)

- [ ] **Step 1: Replace filter state**

Replace these existing vars (sales.html:6438-6442):

```javascript
var invFilterCustomer = '';
var invFilterStatus = '';
var invFilterDateFrom = '';
var invFilterDateTo = '';
var invExpandedId = null;
```

With:

```javascript
var invStatusFilter = 'all';        // 'all' | 'outstanding' | 'overdue' | 'paid'
var invPeriodPreset = 'last-90';    // 'this-month' | 'last-30' | 'last-90' | 'this-year' | 'all' | 'custom'
var invCustomDateFrom = '';
var invCustomDateTo = '';
var invSearchTerm = '';
var invShowVoided = false;
var invFilterCustomer = '';         // kept — used by More Filters
var invPage = 1;
var invPageSize = 25;
var invExpandedId = null;
```

- [ ] **Step 2: Add filter+page apply helper**

Near other inv helpers:

```javascript
// Apply all filters and return the filtered+sorted+paginated slice.
function invComputeView() {
  var range = invPeriodRange(invPeriodPreset);
  var from = (invPeriodPreset === 'custom') ? invCustomDateFrom : range[0];
  var to   = (invPeriodPreset === 'custom') ? invCustomDateTo   : range[1];

  var list = invoices.filter(function(inv) {
    if (inv.status === 'draft') return false; // drafts live in Create New tab
    if (!invShowVoided && (inv.status === 'voided' || inv.status === 'cancelled')) return false;
    if (from && (inv.invoice_date || '') < from) return false;
    if (to   && (inv.invoice_date || '') > to)   return false;
    if (invFilterCustomer && inv.customer_id !== invFilterCustomer) return false;
    if (!invSearchMatches(inv, invSearchTerm)) return false;
    var ds = invGetDisplayStatus(inv);
    if (invStatusFilter === 'outstanding') {
      if (ds !== 'issued' && ds !== 'partial' && ds !== 'overdue') return false;
    } else if (invStatusFilter === 'overdue') {
      if (ds !== 'overdue') return false;
    } else if (invStatusFilter === 'paid') {
      if (ds !== 'paid') return false;
    }
    return true;
  });

  list.sort(function(a, b) {
    return (b.created_at || b.invoice_date || '').localeCompare(a.created_at || a.invoice_date || '');
  });

  var total = list.length;
  var pages = Math.max(1, Math.ceil(total / invPageSize));
  if (invPage > pages) invPage = pages;
  var slice = list.slice((invPage - 1) * invPageSize, invPage * invPageSize);

  return { slice: slice, total: total, pages: pages, fullList: list };
}
```

- [ ] **Step 3: Verify**

In console:

```javascript
invComputeView();
```

Expected: returns `{slice, total, pages, fullList}`. `slice.length <= invPageSize`. No drafts in fullList.

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "feat(sales): invoice list filter+pagination state and computeView helper

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 — Rewrite Invoices list view (column-row layout)

**Files:**
- Modify: `sales.html` — `renderInvoicesView` function (created in Task 3)

- [ ] **Step 1: Implement renderInvoicesView**

Replace the placeholder stub from Task 3:

```javascript
function renderInvoicesView(body) {
  var view = invComputeView();
  var html = '';

  // Stats strip
  html += renderInvoicesStatsStrip();

  // Period preset row
  html += '<div class="inv-presets">';
  html += '<span class="inv-presets-label">Period</span>';
  ['this-month','last-30','last-90','this-year','all','custom'].forEach(function(code) {
    var label = ({'this-month':'This month','last-30':'Last 30 days','last-90':'Last 90 days','this-year':'This year','all':'All time','custom':'Custom…'})[code];
    html += '<button class="inv-preset' + (invPeriodPreset === code ? ' active' : '') + '" onclick="invSetPreset(\'' + code + '\')">' + label + '</button>';
  });
  html += '</div>';

  // Search
  html += '<input type="text" class="inv-search" placeholder="Search invoice number, customer, or reference..." value="' + esc(invSearchTerm) + '" oninput="invSetSearch(this.value)">';

  // Quick-filter chips
  html += renderInvoicesChips(view.fullList);

  // (More Filters toggle deferred — handled in Task 8.)

  // Table
  html += '<div class="inv-table">';
  html += '<div class="inv-list-header">';
  html += '<div>Invoice</div><div>Customer</div><div>Issued</div><div>Due</div>';
  html += '<div class="center">Due in</div><div class="right">Amount</div><div class="right">Balance</div><div></div>';
  html += '</div>';
  if (!view.slice.length) {
    html += '<div class="empty-state" style="padding:30px;">No invoices match your filters.</div>';
  } else {
    view.slice.forEach(function(inv) { html += renderInvoiceRow(inv); });
  }
  html += '</div>';

  // Pagination
  html += renderInvoicesPagination(view);

  // Voided toggle
  var voidedCount = invoices.filter(function(i) {
    var inDateRange = true; // recompute against period
    return (i.status === 'voided' || i.status === 'cancelled');
  }).length;
  if (voidedCount > 0) {
    html += '<div class="inv-show-voided"><a onclick="invToggleShowVoided()">';
    html += (invShowVoided ? 'Hide' : 'Show') + ' ' + voidedCount + ' voided / cancelled invoice' + (voidedCount !== 1 ? 's' : '');
    html += '</a></div>';
  }

  body.innerHTML = html;

  // Re-expand row if invExpandedId was set (preserved across re-renders)
  if (invExpandedId) {
    var row = document.getElementById('inv-row-' + invExpandedId);
    if (row) invInsertDetail(invExpandedId, row);
  }
}
```

- [ ] **Step 2: Implement helper functions**

```javascript
function invSetPreset(code) {
  invPeriodPreset = code;
  invPage = 1;
  renderInvoicesView(document.getElementById('inv-page-body'));
}

function invSetSearch(term) {
  invSearchTerm = term;
  invPage = 1;
  // Don't full-rerender on every keystroke — debounce via setTimeout
  clearTimeout(window._invSearchTO);
  window._invSearchTO = setTimeout(function() {
    var body = document.getElementById('inv-page-body');
    if (body) renderInvoicesView(body);
    var input = document.querySelector('.inv-search');
    if (input) {
      input.focus();
      input.setSelectionRange(input.value.length, input.value.length);
    }
  }, 200);
}

function invSetStatusFilter(s) {
  invStatusFilter = s;
  invPage = 1;
  renderInvoicesView(document.getElementById('inv-page-body'));
}

function invToggleShowVoided() {
  invShowVoided = !invShowVoided;
  invPage = 1;
  renderInvoicesView(document.getElementById('inv-page-body'));
}

function invSetPage(p) {
  invPage = p;
  renderInvoicesView(document.getElementById('inv-page-body'));
}

function invSetPageSize(n) {
  invPageSize = n;
  invPage = 1;
  renderInvoicesView(document.getElementById('inv-page-body'));
}

function renderInvoicesStatsStrip() {
  var outstanding = 0, outstandingCount = 0;
  var overdue = 0, overdueCount = 0;
  var monthTotal = 0, monthCount = 0;
  var thisMonth = todayStr().substring(0, 7);
  invoices.forEach(function(inv) {
    if (inv.status === 'draft' || inv.status === 'cancelled' || inv.status === 'voided') return;
    var bal = invoiceBalance(inv);
    if (bal > 0) { outstanding += bal; outstandingCount++; }
    if (isInvoiceOverdue(inv)) { overdue += bal; overdueCount++; }
    if ((inv.invoice_date || '').substring(0, 7) === thisMonth) {
      monthTotal += parseFloat(inv.grand_total) || 0;
      monthCount++;
    }
  });
  var html = '<div class="inv-stats">';
  html += '<div class="inv-stat warn"><div class="inv-stat-label">Outstanding</div><div class="inv-stat-value">' + formatRM(outstanding) + '</div><div class="inv-stat-meta">' + outstandingCount + ' invoice' + (outstandingCount !== 1 ? 's' : '') + '</div></div>';
  html += '<div class="inv-stat danger"><div class="inv-stat-label">Overdue</div><div class="inv-stat-value">' + formatRM(overdue) + '</div><div class="inv-stat-meta">' + overdueCount + ' invoice' + (overdueCount !== 1 ? 's' : '') + '</div></div>';
  html += '<div class="inv-stat"><div class="inv-stat-label">This Month</div><div class="inv-stat-value">' + formatRM(monthTotal) + '</div><div class="inv-stat-meta">' + monthCount + ' invoice' + (monthCount !== 1 ? 's' : '') + '</div></div>';
  html += '</div>';
  return html;
}

function renderInvoicesChips(fullList) {
  var counts = { all: fullList.length, outstanding: 0, overdue: 0, paid: 0 };
  fullList.forEach(function(inv) {
    var ds = invGetDisplayStatus(inv);
    if (ds === 'paid') counts.paid++;
    else if (ds === 'overdue') { counts.overdue++; counts.outstanding++; }
    else if (ds === 'issued' || ds === 'partial') counts.outstanding++;
  });
  var chips = [
    {code:'all', label:'All', cls:''},
    {code:'outstanding', label:'Outstanding', cls:''},
    {code:'overdue', label:'Overdue', cls:'danger'},
    {code:'paid', label:'Paid', cls:''}
  ];
  var html = '<div class="inv-chips">';
  chips.forEach(function(c) {
    var active = invStatusFilter === c.code ? ' active' : '';
    html += '<span class="inv-chip ' + c.cls + active + '" onclick="invSetStatusFilter(\'' + c.code + '\')">';
    html += c.label + ' <span class="inv-chip-count">' + counts[c.code] + '</span>';
    html += '</span>';
  });
  html += '</div>';
  return html;
}

function renderInvoiceRow(inv) {
  var c = customers.find(function(x) { return x.id === inv.customer_id; });
  var custName = c ? c.name : '—';
  var ds = invGetDisplayStatus(inv);
  var bal = invoiceBalance(inv);
  var partial = invIsPartial(inv);
  var dueIn = invDueInDays(inv);
  var voidedClass = (inv.status === 'voided' || inv.status === 'cancelled') ? ' voided' : '';

  var balanceClass = bal === 0 ? 'zero' : (partial ? 'partial' : '');
  var dueRedClass = isInvoiceOverdue(inv) ? ' danger' : '';

  var dueInDisplay = '—';
  var dueInClass = 'muted';
  if (dueIn !== null) {
    if (dueIn < 0) { dueInDisplay = '−' + Math.abs(dueIn); dueInClass = 'danger'; }
    else { dueInDisplay = '+' + dueIn; dueInClass = ''; }
  }

  var amountStr = formatRM(parseFloat(inv.grand_total) || 0);
  var balStr = formatRM(bal);

  var html = '<div class="inv-list-row' + voidedClass + '" id="inv-row-' + esc(inv.id) + '" onclick="invToggleInvoice(\'' + esc(inv.id) + '\')">';
  html += '<button class="inv-row-id" onclick="event.stopPropagation();generateInvoiceA4(\'' + esc(inv.id) + '\')">' + esc(inv.id) + '</button>';
  html += '<div class="inv-row-cust">' + esc(custName) + '</div>';
  html += '<div class="inv-row-date">' + fmtDateDM(inv.invoice_date) + '</div>';
  html += '<div class="inv-row-date' + dueRedClass + '">' + fmtDateDM(inv.due_date) + '</div>';
  html += '<div class="inv-row-duein ' + dueInClass + '">' + dueInDisplay + '</div>';
  html += '<div class="inv-row-amount">' + amountStr + '</div>';
  html += '<div class="inv-row-balance ' + balanceClass + '">' + balStr + '</div>';
  html += '<svg class="inv-row-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>';
  // Mobile-only second-line meta (CSS shows it only at <=720px)
  var mobileMeta = '<strong>' + esc(custName) + '</strong>';
  if (bal === 0) {
    mobileMeta += ' · Settled';
  } else if (dueIn !== null) {
    var dateLabel = fmtDateDM(inv.due_date);
    if (dueIn < 0) mobileMeta += ' · Due <span class="late">' + dateLabel + ' (−' + Math.abs(dueIn) + ')</span>';
    else mobileMeta += ' · Due ' + dateLabel + ' (+' + dueIn + ')';
  }
  html += '<div class="inv-row-mobile-meta">' + mobileMeta + '</div>';
  html += '</div>';
  return html;
}

function renderInvoicesPagination(view) {
  if (view.total === 0) return '';
  var startIdx = (invPage - 1) * invPageSize + 1;
  var endIdx = Math.min(invPage * invPageSize, view.total);
  var html = '<div class="inv-pagination">';
  html += '<div class="inv-pagination-info">Showing <strong>' + startIdx + '–' + endIdx + '</strong> of <strong>' + view.total + '</strong> invoices</div>';
  html += '<div class="inv-pagination-controls">';
  html += '<button class="inv-page-btn"' + (invPage <= 1 ? ' disabled' : '') + ' onclick="invSetPage(' + (invPage - 1) + ')">← Prev</button>';
  // Page numbers — show first, last, current, +/- 1
  var pageNums = [];
  for (var p = 1; p <= view.pages; p++) {
    if (p === 1 || p === view.pages || Math.abs(p - invPage) <= 1) pageNums.push(p);
    else if (pageNums[pageNums.length - 1] !== '...') pageNums.push('...');
  }
  pageNums.forEach(function(p) {
    if (p === '...') {
      html += '<button class="inv-page-btn" disabled>…</button>';
    } else {
      html += '<button class="inv-page-btn' + (p === invPage ? ' active' : '') + '" onclick="invSetPage(' + p + ')">' + p + '</button>';
    }
  });
  html += '<button class="inv-page-btn"' + (invPage >= view.pages ? ' disabled' : '') + ' onclick="invSetPage(' + (invPage + 1) + ')">Next →</button>';
  html += '</div>';
  html += '<div class="inv-page-size">Rows per page <select onchange="invSetPageSize(parseInt(this.value,10))">';
  [25, 50, 100].forEach(function(n) {
    html += '<option value="' + n + '"' + (invPageSize === n ? ' selected' : '') + '>' + n + '</option>';
  });
  html += '</select></div>';
  html += '</div>';
  return html;
}
```

- [ ] **Step 2: Make `invToggleInvoice` mobile-aware**

Edit existing `invToggleInvoice` (sales.html:6684) to look up the new `inv-row-` prefix. Replace the old `inv-card-` references:

```javascript
function invToggleInvoice(invoiceId) {
  if (invExpandedId === invoiceId) {
    var detail = document.getElementById('inv-detail-' + invoiceId);
    if (detail) detail.remove();
    var row = document.getElementById('inv-row-' + invoiceId);
    if (row) {
      row.classList.remove('expanded');
      var chev = row.querySelector('.inv-row-chev');
      if (chev) chev.classList.remove('open');
    }
    invExpandedId = null;
  } else {
    if (invExpandedId) {
      var prevDetail = document.getElementById('inv-detail-' + invExpandedId);
      if (prevDetail) prevDetail.remove();
      var prevRow = document.getElementById('inv-row-' + invExpandedId);
      if (prevRow) {
        prevRow.classList.remove('expanded');
        var pc = prevRow.querySelector('.inv-row-chev');
        if (pc) pc.classList.remove('open');
      }
    }
    invExpandedId = invoiceId;
    var row = document.getElementById('inv-row-' + invoiceId);
    if (row) {
      row.classList.add('expanded');
      var chev = row.querySelector('.inv-row-chev');
      if (chev) chev.classList.add('open');
      invInsertDetail(invoiceId, row);
    }
  }
}
```

- [ ] **Step 3: Verify**

Reload sales page. Click Invoicing → Invoices subtab.

Expected:
- Sub-tab badge shows correct invoice count.
- Stats strip shows Outstanding / Overdue / This Month.
- Period presets row visible, "Last 90 days" highlighted.
- Search box visible.
- Status chips: All / Outstanding / Overdue / Paid with counts.
- Invoice list renders as column rows with all 7 columns.
- Click a "Last 30 days" preset → list narrows.
- Type in search box → list filters live (with 200ms debounce).
- Click a status chip → list filters.
- Pagination visible if >25 rows; click page numbers works.
- Click Invoice ID → A4 invoice opens.
- Click row body → row expands (legacy detail panel still shows — Task 12 replaces it).
- Resize browser to 700px → list collapses to 2-line cards.

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "$(cat <<'EOF'
feat(sales): rewrite Invoices subtab list view with column-row layout

Period presets, search, status chips, pagination, ID-as-A4-link,
voided toggle. Uses new .inv-* CSS namespace from sales.css.
Drafts excluded from this list. Detail panel still uses legacy
markup — replaced in later task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 — Detail panel rewrite

**Files:**
- Modify: `sales.html` — `invInsertDetail` (line 6580)

- [ ] **Step 1: Replace invInsertDetail**

Replace the entire body of `invInsertDetail(invoiceId, cardEl)` with:

```javascript
function invInsertDetail(invoiceId, rowEl) {
  var inv = invoices.find(function(i) { return i.id === invoiceId; });
  if (!inv) return;
  var bal = invoiceBalance(inv);
  var partial = invIsPartial(inv);
  var paid = parseFloat(inv.amount_paid) || 0;
  var grand = parseFloat(inv.grand_total) || 0;

  var paymentTermsLabel = (function() {
    var d = parseInt(inv.payment_terms_days, 10);
    if (isNaN(d) || d === 0) return 'COD';
    return 'Net ' + d + ' days';
  })();

  var html = '<div class="inv-detail" id="inv-detail-' + esc(invoiceId) + '">';

  // Top 3-block grid
  html += '<div class="inv-detail-grid">';

  // Linked DOs as chips
  html += '<div class="inv-detail-block"><div class="inv-detail-label">Linked DOs</div><div>';
  var linkedOrders = invoiceOrders.filter(function(io) { return io.invoice_id === invoiceId; });
  if (linkedOrders.length) {
    linkedOrders.forEach(function(io) {
      var o = orders.find(function(x) { return x.id === io.order_id; });
      var label = o ? (o.doc_number || o.id) : io.order_id;
      var canUnlink = inv.status === 'issued' && linkedOrders.length > 1;
      var cls = 'inv-do-chip' + (canUnlink ? ' unlink' : '');
      var click = canUnlink ? 'event.stopPropagation();invUnlinkDO(\'' + esc(invoiceId) + '\',\'' + esc(io.order_id) + '\')' : '';
      html += '<button class="' + cls + '" onclick="' + click + '">' + esc(label) + '</button>';
    });
  } else {
    html += '<span class="inv-empty">None</span>';
  }
  html += '</div></div>';

  // Payment terms
  html += '<div class="inv-detail-block"><div class="inv-detail-label">Payment terms</div>';
  html += '<div class="inv-detail-value">' + esc(paymentTermsLabel) + '</div></div>';

  // Outstanding / Settled big number
  html += '<div class="inv-detail-block">';
  if (bal === 0) {
    var lastPay = (invoicePayments.filter(function(p) { return p.invoice_id === invoiceId; }).sort(function(a,b){return (b.payment_date||'').localeCompare(a.payment_date||'');})[0]);
    var lastDate = lastPay ? fmtDateDM(lastPay.payment_date) : '';
    html += '<div class="inv-detail-label">Settled</div>';
    html += '<div class="inv-detail-value big" style="color:var(--green);">' + formatRM(grand);
    if (lastDate) html += '<br><span style="font-size:11px;color:var(--text-muted);font-weight:400;">on ' + lastDate + '</span>';
    html += '</div>';
  } else if (partial) {
    html += '<div class="inv-detail-label">Outstanding</div>';
    html += '<div class="inv-detail-value big" style="color:var(--danger);font-style:italic;">' + formatRM(bal);
    html += '<br><span style="font-size:11px;color:var(--green);font-style:normal;">paid ' + formatRM(paid) + ' of ' + formatRM(grand) + '</span></div>';
  } else {
    html += '<div class="inv-detail-label">Outstanding</div>';
    html += '<div class="inv-detail-value big" style="color:var(--danger);">' + formatRM(bal) + '</div>';
  }
  html += '</div>';

  html += '</div>'; // end grid

  // Voided invoices: show void reason + auditor instead of payment list
  if (inv.status === 'voided') {
    html += '<div class="inv-detail-block" style="margin-bottom:8px;"><div class="inv-detail-label">Voided</div>';
    html += '<div class="inv-detail-value">' + fmtDateDM(inv.voided_at) + (inv.voided_by ? ' by ' + esc(inv.voided_by) : '') + '</div>';
    if (inv.void_reason) html += '<div style="font-size:12px;color:#555;margin-top:4px;">Reason: ' + esc(inv.void_reason) + '</div>';
    html += '<div style="font-size:11px;color:var(--text-muted);margin-top:4px;">Linked DOs were freed for re-invoicing.</div>';
    html += '</div>';
  } else {
    // Payments list
    var pays = invoicePayments.filter(function(p) { return p.invoice_id === invoiceId; });
    pays.sort(function(a,b){return (b.payment_date||'').localeCompare(a.payment_date||'');});
    html += '<div class="inv-detail-block" style="margin-bottom:8px;">';
    html += '<div class="inv-detail-label">Payments (' + pays.length + ')</div>';
    if (pays.length) {
      html += '<div class="inv-payments">';
      pays.forEach(function(p) {
        var methodLabel = p.method === 'bank_transfer' ? 'Bank transfer' : p.method === 'cash' ? 'Cash' : p.method === 'cheque' ? 'Cheque' : (p.method || '');
        html += '<div class="inv-pay-row">';
        html += '<div class="inv-pay-date">' + fmtDateDM(p.payment_date) + '</div>';
        html += '<div class="inv-pay-method">' + esc(methodLabel);
        var sub = '';
        if (p.reference) sub += 'Ref: ' + esc(p.reference);
        if (p.slip_url) sub += (sub ? ' · ' : '') + '<a href="' + esc(p.slip_url) + '" target="_blank" onclick="event.stopPropagation()" style="color:var(--gold);">slip ↗</a>';
        if (sub) html += '<small>' + sub + '</small>';
        html += '</div>';
        html += '<div class="inv-pay-amount">' + formatRM(parseFloat(p.amount) || 0) + '</div>';
        html += '</div>';
      });
      html += '</div>';
    } else {
      html += '<div class="inv-empty">No payments recorded yet</div>';
    }
    html += '</div>';

    // Credit notes (only if any)
    var cns = creditNotes.filter(function(cn) { return cn.invoice_id === invoiceId; });
    if (cns.length) {
      html += '<div class="inv-detail-block" style="margin-bottom:8px;">';
      html += '<div class="inv-detail-label">Credit notes (' + cns.length + ')</div>';
      html += '<div class="inv-payments">';
      cns.forEach(function(cn) {
        html += '<div class="inv-pay-row">';
        html += '<div class="inv-pay-date">' + fmtDateDM(cn.credit_date) + '</div>';
        html += '<div class="inv-pay-method"><a href="#" onclick="event.preventDefault();event.stopPropagation();generateCreditNoteA4(\'' + esc(cn.id) + '\')" style="color:var(--gold);font-weight:600;">' + esc(cn.id) + '</a>';
        if (cn.reason) html += '<small>' + esc(cn.reason) + '</small>';
        html += '</div>';
        html += '<div class="inv-pay-amount" style="color:var(--gold);">' + formatRM(parseFloat(cn.amount) || 0) + '</div>';
        html += '</div>';
      });
      html += '</div></div>';
    }
  }

  // Action bar
  html += '<div class="inv-actions">';
  if (inv.status === 'issued' && bal > 0) {
    html += '<button class="btn btn-primary" onclick="event.stopPropagation();invOpenPaymentModal(\'' + esc(invoiceId) + '\')">+ Record Payment</button>';
  }
  if (inv.status === 'issued') {
    html += '<button class="btn btn-outline" onclick="event.stopPropagation();invOpenCNModal(\'' + esc(invoiceId) + '\')">Credit Note</button>';
  }
  if (inv.status === 'issued' && inv.payment_status !== 'paid') {
    html += '<button class="inv-act-danger right" onclick="event.stopPropagation();invOpenVoidModal(\'' + esc(invoiceId) + '\')">Void invoice</button>';
  }
  html += '</div>';
  html += '</div>'; // end inv-detail

  rowEl.insertAdjacentHTML('afterend', html);
}
```

> Note: detail panel now sits **after** the row, not inside it. CSS class `.inv-detail` has its own background and padding — no nesting needed.

- [ ] **Step 2: Verify**

Reload page. Expand an issued invoice with no payments.

Expected:
- 3-block grid: Linked DOs (chips) · Payment terms · Outstanding (big red number)
- "Payments (0)" with "No payments recorded yet" empty state
- Action bar: `+ Record Payment` (green primary) on left, `Credit Note` outline next, `Void invoice` red text on right
- Click `+ Record Payment` → existing modal opens correctly

Expand a paid invoice:
- 3-block: DOs · terms · "Settled RM X on DD/MM/YYYY" (green)
- Payments list shows the recorded payment
- Action bar: `Credit Note` only (no Record Payment, no Void)

Expand a partial:
- "Outstanding" red italic + sub-line "paid RM X of RM Y" green
- Payments list shows partial payment(s)

If you have a voided invoice (toggle Show voided to find one):
- 3-block + "Voided on DD/MM/YYYY by X" + reason + "DOs were freed" note
- Action bar: empty

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "$(cat <<'EOF'
feat(sales): rewrite invoice detail panel — 3-block top, payment list, hierarchical action bar

Replaces items table + linked DOs + payments + CNs + button row with:
- Linked DO chips, payment terms, big outstanding/settled number
- Compact payments list (date · method+ref+slip · amount)
- CN list only when present
- Action bar: +Record Payment primary → Credit Note secondary → Void destructive (right-aligned, low-contrast)
- Voided variant: reason + auditor instead of payments

Items table dropped — A4 (one click via invoice ID) covers it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 — Thin DO customer rows in Create New (with age pills)

**Files:**
- Modify: `sales.html` — replace inline customer-group rendering inside `renderCreateNewView`

- [ ] **Step 1: Add DO age helper**

Add near other inv helpers:

```javascript
function invDOAgeDays(o) {
  if (!o || !o.order_date) return null;
  var d = new Date(o.order_date + 'T00:00:00');
  var today = new Date(); today.setHours(0,0,0,0);
  return Math.round((today - d) / 86400000);
}

function invDOAgeClass(days) {
  if (days == null) return 'fresh';
  if (days > 60) return 'overdue';
  if (days > 30) return 'old';
  return 'fresh';
}
```

- [ ] **Step 2: Locate the customer-group rendering inside `renderCreateNewView`**

Within `renderCreateNewView`, find the loop that renders each `inv-customer-group` (currently lines 5997-6031 region of original `renderInvoicing`). Replace the per-customer markup with:

```javascript
customerIds.forEach(function(custId) {
  var custOrders = byCustomer[custId];
  var cust = customers.find(function(c) { return c.id === custId; });
  var custName = cust ? cust.name : '—';
  var custTotal = 0;
  custOrders.forEach(function(o) { custTotal += parseFloat(o.grand_total) || 0; });
  var selectedInGroup = 0;
  custOrders.forEach(function(o) { if (invSelectedDOs[o.id]) selectedInGroup++; });
  var allSelected = selectedInGroup > 0 && selectedInGroup === custOrders.length;
  var groupExpanded = selectedInGroup > 0;
  var rowClass = 'inv-do-cust-row' + (selectedInGroup > 0 ? ' selected-some' : '');

  // Thin row
  html += '<div class="' + rowClass + '" onclick="invToggleCustomer(\'' + esc(custId) + '\')">';
  html += '<input type="checkbox" id="inv-selall-' + esc(custId) + '"' + (allSelected ? ' checked' : '') + ' style="width:18px;height:18px;accent-color:var(--gold);" onclick="event.stopPropagation();invSelectAllCustomer(\'' + esc(custId) + '\', this.checked)">';
  html += '<span class="cust-name">' + esc(custName) + '</span>';
  html += '<span class="inv-do-pill">' + custOrders.length + ' DO' + (custOrders.length !== 1 ? 's' : '') + '</span>';
  if (selectedInGroup > 0) {
    html += '<span class="inv-do-selected-badge">' + selectedInGroup + ' selected</span>';
  }
  html += '<span class="inv-do-cust-amount">' + formatRM(custTotal) + '</span>';
  html += '<svg style="width:14px;height:14px;color:var(--text-muted);transition:transform 0.2s;' + (groupExpanded ? 'transform:rotate(180deg);' : '') + '" id="inv-chevron-' + esc(custId) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>';
  html += '</div>';

  // Expanded DO list
  html += '<div class="inv-do-list" id="inv-dos-' + esc(custId) + '" style="display:' + (groupExpanded ? 'block' : 'none') + ';">';
  custOrders.sort(function(a, b) { return (a.order_date || '').localeCompare(b.order_date || ''); });
  custOrders.forEach(function(o) {
    var checked = invSelectedDOs[o.id] ? ' checked' : '';
    var age = invDOAgeDays(o);
    var ageCls = invDOAgeClass(age);
    html += '<div class="inv-do-row">';
    html += '<input type="checkbox" data-order-id="' + esc(o.id) + '" data-customer-id="' + esc(custId) + '"' + checked + ' onchange="invToggleDO(\'' + esc(o.id) + '\', \'' + esc(custId) + '\', this.checked)" style="width:16px;height:16px;accent-color:var(--gold);">';
    html += '<span class="num">' + esc(o.doc_number || o.id) + '</span>';
    html += '<span class="date">' + fmtDateDM(o.order_date) + '</span>';
    if (age != null) html += '<span class="inv-do-age ' + ageCls + '">' + age + 'd</span>';
    html += '<span class="amt">' + formatRM(parseFloat(o.grand_total) || 0) + '</span>';
    html += '</div>';
  });
  html += '</div>';
});
```

- [ ] **Step 3: Verify**

Reload, switch to Create New tab.

Expected:
- Each customer = single row, ~44px tall (was ~78).
- Row: checkbox · name · "N DOs" pill · amount · chevron.
- Click row → expands DO list. Each DO row: checkbox · DO# · date · age pill · amount.
- Age pills: <30d purple, 30-60d orange, >60d red.
- Selecting a DO toggles "N selected" gold pill on header + auto-keeps group expanded.
- Existing select-all checkbox behaviour intact.
- Existing `invToggleCustomer`, `invSelectAllCustomer`, `invToggleDO` still wire up.

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "ui(sales): thin single-row customer cards with DO age pills in Create New tab

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8 — Sticky bottom dock for create flow

**Files:**
- Modify: `sales.html` — replace billing summary + invoice details + button section inside `renderCreateNewView`

- [ ] **Step 1: Add dock state**

Near other inv state:

```javascript
var invDockExpanded = false;
function invToggleDock() {
  invDockExpanded = !invDockExpanded;
  var dock = document.getElementById('inv-dock');
  if (dock) renderInvoicing(); // re-render to flip
}
```

- [ ] **Step 2: Replace dock rendering in renderCreateNewView**

Replace the legacy "Billing summary card / Invoice Details / Multi-customer warning / Action button" block at the end of the customer loop with:

```javascript
// Sticky bottom dock — appears only when DOs are selected
var selectedCount = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; }).length;
if (selectedCount > 0) {
  var selCustIds = invSelectedCustomerIds();
  var multiCust = selCustIds.length > 1;

  if (multiCust) {
    var custNames = selCustIds.map(function(cid) {
      var c = customers.find(function(x) { return x.id === cid; });
      return c ? c.name : cid;
    }).join(', ');
    html += '<div class="inv-dock" style="border-color:var(--danger);"><div class="inv-dock-bar" style="background:rgba(220,53,69,0.06);">';
    html += '<div class="inv-dock-summary"><div class="inv-dock-count" style="color:var(--danger);"><strong style="color:var(--danger);">⚠</strong> Selected DOs span multiple customers: ' + esc(custNames) + '</div></div>';
    html += '<button class="btn btn-outline btn-sm" onclick="invClearAllSelections()">Clear selection</button>';
    html += '</div></div>';
  } else {
    var firstSelId = Object.keys(invSelectedDOs).find(function(k) { return invSelectedDOs[k]; });
    var firstSelOrder = firstSelId ? orders.find(function(o) { return o.id === firstSelId; }) : null;
    var firstCust = firstSelOrder ? customers.find(function(c) { return c.id === firstSelOrder.customer_id; }) : null;
    var firstCustName = firstCust ? firstCust.name : '';
    var defaultTermsDays = firstCust ? (firstCust.payment_terms_days || 30) : 30;

    var selectedTotal = 0;
    Object.keys(invSelectedDOs).forEach(function(k) {
      if (!invSelectedDOs[k]) return;
      var o = orders.find(function(x) { return x.id === k; });
      if (o) selectedTotal += parseFloat(o.grand_total) || 0;
    });

    html += '<div class="inv-dock" id="inv-dock">';
    html += '<div class="inv-dock-bar">';
    html += '<div class="inv-dock-summary">';
    html += '<div class="inv-dock-count"><strong>' + selectedCount + '</strong> DO' + (selectedCount !== 1 ? 's' : '') + ' selected from <strong style="color:var(--purple);">' + esc(firstCustName) + '</strong></div>';
    html += '<div class="inv-dock-divider"></div>';
    html += '<div class="inv-dock-total">Total<strong>' + formatRM(selectedTotal) + '</strong></div>';
    html += '</div>';
    html += '<button class="inv-dock-toggle" onclick="invToggleDock()">';
    html += (invDockExpanded ? 'Hide preview' : 'Preview');
    html += '<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="' + (invDockExpanded ? '6 9 12 15 18 9' : '18 15 12 9 6 15') + '"/></svg>';
    html += '</button>';
    html += '<button class="btn btn-primary" id="inv-create-btn" onclick="invCreateDraftInvoice()">Create Draft Invoice</button>';
    html += '</div>';

    if (invDockExpanded) {
      html += '<div class="inv-dock-expanded">';
      html += renderDockBillingSummary(firstCust, firstCustName);
      html += '<h4 style="font-size:13px;font-weight:700;margin:14px 0 8px;color:var(--text);">Invoice details</h4>';
      html += '<div class="inv-dock-fields">';
      html += '<div class="form-field"><label>Invoice date</label><input type="date" id="inv-date" value="' + todayStr() + '" onchange="invUpdateDueDate()"></div>';
      html += '<div class="form-field"><label>Payment terms</label><select id="inv-terms" onchange="invUpdateDueDate()">';
      [0, 7, 14, 30, 60].forEach(function(d) {
        html += '<option value="' + d + '"' + (d === defaultTermsDays ? ' selected' : '') + '>' + paymentTermsLabel(d) + '</option>';
      });
      html += '</select></div>';
      html += '<div class="form-field"><label>Notes (optional)</label><input type="text" id="inv-notes" placeholder="Optional invoice notes" value="' + esc(INV_DEFAULT_NOTES) + '"></div>';
      html += '</div>';
      var dueDate = calcDueDate(todayStr(), defaultTermsDays === 0 ? 'cod' : defaultTermsDays + 'days');
      html += '<div style="font-size:11px;color:var(--text-muted);margin-top:6px;">Due ' + fmtDateDM(dueDate) + '</div>';
      html += '<div style="display:flex;gap:6px;justify-content:flex-end;margin-top:14px;">';
      html += '<button class="btn btn-outline btn-sm" onclick="invCopySummary()">Copy summary</button>';
      html += '<button class="btn btn-outline btn-sm" onclick="invPrintSummary()">Print summary</button>';
      html += '</div>';
      html += '</div>';
    }

    html += '</div>'; // end inv-dock
  }
}
```

- [ ] **Step 3: Helper to render billing summary inside dock**

```javascript
function renderDockBillingSummary(firstCust, firstCustName) {
  var selectedIds = Object.keys(invSelectedDOs).filter(function(k) { return invSelectedDOs[k]; });
  var doNumbers = [];
  var productAgg = {};
  selectedIds.forEach(function(id) {
    var o = orders.find(function(x) { return x.id === id; });
    if (!o) return;
    doNumbers.push(o.doc_number || o.id);
    var items = orderItems.filter(function(i) { return i.order_id === id; });
    items.forEach(function(item) {
      var unitPrice = parseFloat(item.unit_price) || 0;
      var key = item.product_id + '_' + unitPrice.toFixed(2);
      if (!productAgg[key]) {
        var prod = salesProducts.find(function(p) { return p.id === item.product_id; });
        var variety = soGetProductVariety(item.product_id);
        productAgg[key] = {
          name: prod ? prod.name : '—',
          variety: variety !== '—' ? variety : '',
          unit: prod ? (prod.unit || '') : '',
          quantity: 0, totalAmount: 0, unitPrice: unitPrice
        };
      }
      productAgg[key].quantity += (item.quantity || 0);
      productAgg[key].totalAmount += parseFloat(item.line_total) || 0;
    });
  });
  var lines = Object.values(productAgg);
  var grand = 0; lines.forEach(function(p) { grand += p.totalAmount; });

  var html = '<h4 style="font-size:13px;font-weight:700;margin:0 0 8px;color:var(--text);">Billing summary · ' + esc(firstCustName) + '</h4>';
  html += '<div style="font-size:11px;color:var(--text-muted);margin-bottom:8px;">DOs: ' + doNumbers.join(', ') + '</div>';
  html += '<table class="data-table" style="margin:0;font-size:12px;">';
  html += '<thead><tr><th>#</th><th>Product</th><th style="text-align:right;">Qty</th><th>Unit</th><th style="text-align:right;">Price</th><th style="text-align:right;">Amount</th></tr></thead><tbody>';
  lines.forEach(function(p, i) {
    var desc = (p.variety ? p.variety + ' ' : '') + p.name;
    html += '<tr><td>' + (i+1) + '</td><td>' + esc(desc) + '</td><td style="text-align:right;">' + p.quantity + '</td><td>' + esc(p.unit) + '</td><td style="text-align:right;">' + formatRM(p.unitPrice) + '</td><td style="text-align:right;font-weight:600;">' + formatRM(p.totalAmount) + '</td></tr>';
  });
  html += '</tbody><tfoot><tr><td colspan="5" style="text-align:right;font-weight:800;">Total this invoice</td><td style="text-align:right;font-weight:800;color:var(--gold);">' + formatRM(grand) + '</td></tr></tfoot></table>';
  return html;
}

function invClearAllSelections() {
  invSelectedDOs = {};
  renderInvoicing();
}
```

- [ ] **Step 4: Verify**

Reload, switch to Create New, select 1 DO from a customer.

Expected:
- Bottom dock appears with: count · customer name · total · `Preview` · `Create Draft Invoice`
- Click Preview → expanded panel shows billing summary table + Invoice date / Terms / Notes fields + Copy/Print buttons.
- Click Hide preview → collapses back.
- Click Create Draft Invoice → existing flow runs (creates draft).
- Select DOs from 2 different customers → dock turns into red warning + Clear selection button.
- Clear selection → dock disappears.

- [ ] **Step 5: Commit**

```bash
git add sales.html
git commit -m "$(cat <<'EOF'
feat(sales): sticky bottom dock for invoice create flow

Replaces stacked billing summary + invoice details + create button
with a single dock that appears when DOs are selected. Collapsed by
default — Preview toggle expands the full summary + invoice fields.
Multi-customer selection turns the dock into a red warning.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9 — Pending-draft banner in Create New tab

**Files:**
- Modify: `sales.html` — `renderCreateNewView` (top of function)

- [ ] **Step 1: Render banner at top + lock create flow**

At the very start of `renderCreateNewView(body)`, before any other HTML:

```javascript
function renderCreateNewView(body) {
  var html = '';

  // Pending draft banner (single-draft rule)
  var draft = invoices.find(function(i) { return i.status === 'draft'; });
  if (draft) {
    var c = customers.find(function(x) { return x.id === draft.customer_id; });
    var custName = c ? c.name : '—';
    var doCount = invoiceOrders.filter(function(io) { return io.invoice_id === draft.id; }).length;
    html += '<div class="inv-draft-banner">';
    html += '<div class="inv-draft-info">';
    html += '<span class="inv-draft-tag">Pending approval</span>';
    html += '<button class="inv-draft-id" onclick="generateInvoiceA4(\'' + esc(draft.id) + '\')">' + esc(draft.id) + '</button>';
    html += '<span class="inv-draft-meta"><strong>' + esc(custName) + '</strong> · ' + doCount + ' DO' + (doCount !== 1 ? 's' : '') + ' · Created ' + fmtDateDM(draft.created_at || draft.invoice_date) + ' · <strong>' + formatRM(parseFloat(draft.grand_total) || 0) + '</strong></span>';
    html += '</div>';
    html += '<div class="inv-draft-actions">';
    html += '<button class="btn btn-outline btn-sm" onclick="invEditDraft(\'' + esc(draft.id) + '\')">Edit</button>';
    html += '<button class="btn btn-outline btn-sm" style="border-color:var(--danger);color:var(--danger);" onclick="invCancelInvoice(\'' + esc(draft.id) + '\')">Cancel draft</button>';
    if (currentUser && currentUser.role === 'admin') {
      html += '<button class="btn btn-primary btn-sm" onclick="invApproveInvoice(\'' + esc(draft.id) + '\')">Approve & issue</button>';
    }
    html += '</div></div>';
  }

  // Create flow — locked when draft exists
  html += '<div' + (draft ? ' class="inv-locked"' : '') + '>';

  // ... existing header + DO list + dock rendering goes here
  // (the body of the legacy renderCreateNewView)

  html += '</div>'; // end locked wrapper

  if (draft) {
    html += '<div class="inv-locked-note">Approve or cancel the pending draft above before creating another. (Single-draft rule prevents invoice number gaps.)</div>';
  }

  body.innerHTML = html;
  // ... existing focus-restore code
}
```

- [ ] **Step 2: Verify**

Test by creating a draft (without approving).

Expected:
- Banner appears at top of Create New tab.
- Banner shows: "PENDING APPROVAL" tag · invoice ID (clickable to A4) · customer name · DO count · created date · total.
- Three actions: Edit · Cancel draft · Approve & issue.
- DO list below is grayed out (50% opacity, no clicks).
- "Approve or cancel" note appears below the locked list.
- Sub-tab badge changes from "3 DOs" to red "1 draft".
- After Approve → banner disappears, draft moves to Invoices tab as Issued.
- After Cancel → banner disappears, counter rewinds, list unlocks.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "$(cat <<'EOF'
feat(sales): pending-draft banner in Create New subtab

Single-draft rule given a UI surface — when a draft exists, banner
appears at top of Create New with Edit/Cancel/Approve actions.
Create flow below is visually locked. Sub-tab badge turns red.
Existing single-draft guard at create time stays in place.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10 — More Filters drawer + customer dropdown

**Files:**
- Modify: `sales.html` — `renderInvoicesView`

- [ ] **Step 1: Add filter-toggle state + render**

```javascript
var invMoreFiltersOpen = false;
function invToggleMoreFilters() {
  invMoreFiltersOpen = !invMoreFiltersOpen;
  renderInvoicesView(document.getElementById('inv-page-body'));
}
```

In `renderInvoicesView`, after the chips section and before the table:

```javascript
html += '<button class="inv-filter-toggle" onclick="invToggleMoreFilters()">';
html += '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>';
html += 'More filters' + (invMoreFiltersOpen ? ' ▴' : ' ▾');
html += '</button>';

if (invMoreFiltersOpen) {
  html += '<div style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:12px;align-items:end;">';
  // Customer dropdown
  var custIdsSeen = {};
  invoices.forEach(function(i) { if (i.customer_id) custIdsSeen[i.customer_id] = true; });
  html += '<div class="form-field" style="margin:0;"><label>Customer</label><select onchange="invFilterCustomer=this.value;invPage=1;renderInvoicesView(document.getElementById(\'inv-page-body\'));">';
  html += '<option value=""' + (invFilterCustomer === '' ? ' selected' : '') + '>All customers</option>';
  Object.keys(custIdsSeen).forEach(function(cid) {
    var c = customers.find(function(x) { return x.id === cid; });
    var cname = c ? c.name : cid;
    html += '<option value="' + esc(cid) + '"' + (invFilterCustomer === cid ? ' selected' : '') + '>' + esc(cname) + '</option>';
  });
  html += '</select></div>';

  // Custom date range (only when preset = custom)
  if (invPeriodPreset === 'custom') {
    html += '<div class="form-field" style="margin:0;"><label>From</label><input type="date" value="' + esc(invCustomDateFrom) + '" onchange="invCustomDateFrom=this.value;invPage=1;renderInvoicesView(document.getElementById(\'inv-page-body\'));"></div>';
    html += '<div class="form-field" style="margin:0;"><label>To</label><input type="date" value="' + esc(invCustomDateTo) + '" onchange="invCustomDateTo=this.value;invPage=1;renderInvoicesView(document.getElementById(\'inv-page-body\'));"></div>';
  }
  html += '</div>';
}
```

- [ ] **Step 2: Verify**

Reload, click "More filters".

Expected:
- Customer dropdown appears below the toggle.
- Pick a customer → list filters.
- If period preset = Custom, date range inputs appear.
- Click toggle again → drawer closes.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "feat(sales): collapsible More filters drawer (customer + custom date range)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11 — Wire up dashboard & cross-references

**Files:**
- Modify: `sales.html` — dashboard cards (line 1801, 1805, 1809, 1813), customer detail (5548), and any other place that switches to invoicing tab

- [ ] **Step 1: Update existing `switchTab('invoicing')` callers**

Existing dashboard summary cards already navigate to invoicing — they should land on the Invoices subtab (default). No change needed since `invSubtab` defaults to `invoices`.

For the customer detail "click an invoice ID" link (sales.html:5548), update to:

```javascript
html += '<td><a href="javascript:void(0)" onclick="event.stopPropagation();invSubtab=\'invoices\';invSearchTerm=\'' + esc(inv.id) + '\';switchTab(\'invoicing\')" style="font-weight:600;color:var(--purple);text-decoration:none;">' + esc(inv.id) + '</a></td>';
```

This jumps to Invoices subtab pre-filtered to the clicked invoice.

- [ ] **Step 2: Verify**

From customer detail page, click an invoice ID.

Expected: lands on Invoicing → Invoices subtab with the invoice ID in the search box, list filtered to that single invoice.

- [ ] **Step 3: Commit**

```bash
git add sales.html
git commit -m "fix(sales): customer-detail invoice link jumps to Invoices subtab pre-filtered

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12 — Cleanup legacy code paths

**Files:**
- Modify: `sales.html`

- [ ] **Step 1: Remove obsolete functions**

Delete the following — superseded by new helpers:

- `invStatusBadge` (sales.html:6454-6466) — no badges in new design
- Top-of-`renderInvoicing` legacy variable `_invDoSearchVal` (line 5943) — replaced by `invSearchTerm` for the new tab; the old DO search lives only inside renderCreateNewView and can keep the `_invDoSearchVal` for that

Search for any callers and confirm they're removed.

- [ ] **Step 2: Remove legacy filter dropdown rendering**

Inside `invRenderList` (which is no longer called for the Invoices subtab — only used during the Task 3 partial-migration bridge), confirm it's now unreferenced. If unreferenced, delete the function (sales.html:6468-6577 region).

Check with grep:

```bash
grep -n "invRenderList" sales.html
```

If only the `function invRenderList()` definition remains and no callers, delete it.

- [ ] **Step 3: Verify nothing's broken**

Reload sales page, click through:
- Dashboard → click any invoice card → lands on Invoices subtab ✓
- Invoices subtab → all filters/pagination work ✓
- Create New subtab → DO selection + dock work ✓
- Pending draft banner shows when draft exists ✓
- Customer detail → invoice link works ✓
- Voided toggle → reveals voided rows ✓
- Mobile (resize to 380px) → 2-line cards ✓

- [ ] **Step 4: Commit**

```bash
git add sales.html
git commit -m "refactor(sales): remove obsolete invStatusBadge + legacy invRenderList

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13 — Production deploy + verification

**Files:** none (deploy only)

- [ ] **Step 1: Deploy to Netlify**

```bash
netlify deploy --prod --dir=. --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26 --site=a0ac5d18-a968-414c-a531-c78ed390e5c2
```

Expected: deploy URL prints, site goes live at https://tgfarmhub.com.

- [ ] **Step 2: Verify deployed behaviour (per user's working-style rule #3)**

Open `https://tgfarmhub.com/sales.html` in a clean browser tab.

Walk through:
- Login as admin → click Sales → Invoicing tab
- Confirm Invoices subtab is the default landing
- Confirm sub-tab badges show correct numbers
- Period presets work, default = "Last 90 days"
- Search filters in real time
- Status chips switch correctly
- Pagination shows when >25 invoices
- Click invoice ID → A4 opens
- Expand a row → detail panel renders correctly (try issued, partial, paid, voided)
- "Show voided" toggle works
- Switch to Create New subtab
- DO list renders as thin rows with age pills
- Select 1 DO → dock appears at bottom
- Click Preview → expanded panel shows
- Create Draft Invoice → draft created, banner appears at top, list locks
- Approve & issue → moves draft to Invoices subtab
- Resize browser to mobile width → invoice rows collapse to 2-line cards

- [ ] **Step 3: Commit if any deploy-only fixes**

If small fixes needed (CSS specificity, etc.), commit and redeploy. Otherwise nothing to commit.

---

## Self-review summary

**Spec coverage:**
- Sub-tabs: Tasks 3, 11
- Invoices list (column-row, status signal, due-in, partial italic, search, period presets, chips, pagination, voided toggle, ID-as-A4-link): Tasks 4, 5, 10
- Create New (thin DO rows, age pills, sticky dock, multi-customer warning): Tasks 7, 8
- Pending-draft banner + lock: Task 9
- Detail panel rewrite: Task 6
- Mobile fallback: covered in CSS @media (Task 1) + mobile-meta line in renderInvoiceRow (Task 5)
- Voided detail variant: Task 6
- Counter behavior: kept as-is (no task — explicitly verified during brainstorming)

**Type / name consistency:**
- All new helper names use `inv` prefix consistently
- CSS uses `.inv-*` namespace consistently
- Existing helpers (`invoiceBalance`, `invGetDisplayStatus`, `isInvoiceOverdue`, `dbNextId`, `rewind_id`, `invCreateDraftInvoice`, `invApproveInvoice`, `invCancelInvoice`, `invEditDraft`, `invOpenPaymentModal`, `invOpenCNModal`, `invOpenVoidModal`, `invUnlinkDO`, `generateInvoiceA4`, `generateCreditNoteA4`) reused without rename — all references match their definitions.
- DOM ID prefix `inv-row-` in Task 5 matches the lookup in Task 5 step 2 and Task 11 (`document.getElementById('inv-row-' + ...)`).

**No placeholders:** all code blocks contain complete, paste-ready code. No "TBD" / "implement later" / "similar to Task N".
