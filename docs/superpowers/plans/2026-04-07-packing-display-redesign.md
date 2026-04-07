# Packing Display Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `display-sales.html` from generic dark dashboard to Industrial Warehouse visual language — 4-column always-visible grid, Inter typography, orange accent, sharp 90° cards.

**Architecture:** Single static HTML file. CSS rewritten (replaces ~430 lines of legacy variables + layout). JS rendering layer rewritten (`buildPages` + `renderPages` switch from vertically-stacked status sections to a fixed 4-column grid where each column paginates independently). No data layer changes — `loadData()`, `STATUS_CONFIG` keys, Supabase calls, password gate, refresh loop, fullscreen toggle all preserved.

**Tech Stack:** Vanilla HTML/CSS/JS, Inter (Google Fonts CDN), Supabase REST API. No build step. No test framework. Verification is manual browser smoke testing against the live Supabase data.

**Spec:** `docs/superpowers/specs/2026-04-07-packing-display-redesign-design.md`

**File touched:** `display-sales.html` only.

---

## Verification Approach

This project has no automated test framework. Each task ends with **manual browser verification** using a local file open:

```bash
start "" "display-sales.html"   # Windows
```

Password to enter the display: `tgtukau892312` (from `reference_tv_display_password.md`).

Smoke checks for every task are listed inline. If a smoke check fails, fix before committing.

---

## File Structure After Implementation

`display-sales.html` keeps its single-file structure. Logical sections after the rewrite:

1. `<head>` — Inter font load (replaces IBM Plex + JetBrains Mono)
2. `<style>` — Two CSS subsystems:
   - **Gate/loading/auth** — unchanged
   - **Industrial Warehouse layout** — fully replaces current `Layout`/`Status Group Headers`/`Order Cards`/`Footer Bar`/`4K TV Optimization` blocks
3. `<body>` — Password gate + loading + app shell (header bar / column grid / footer bar)
4. `<script>` — Password gate (unchanged), Supabase data layer (unchanged), `STATUS_CONFIG` (emojis removed), `buildPages` (rewritten for per-column pagination), `renderPages` (rewritten for 4-column grid), clock + refresh + init (unchanged signatures)

---

## Task 1: Add Inter font, update CSS variables

**Files:**
- Modify: `display-sales.html:8-9` (Google Fonts link)
- Modify: `display-sales.html:14-32` (`:root` block)

**What this does:** Swaps the font CDN link from IBM Plex Sans + JetBrains Mono to Inter (weights 400/700/900). Replaces the `:root` color tokens with the Industrial Warehouse palette so the rest of the file can reference them.

- [ ] **Step 1: Replace the Google Fonts link**

In `display-sales.html`, replace line 9:

```html
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

with:

```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700;900&display=swap" rel="stylesheet">
```

- [ ] **Step 2: Replace the `:root` block**

Replace lines 14-32 (`:root { ... }`) with:

```css
:root {
  /* Industrial Warehouse palette */
  --bg:           #0E0E0E;   /* page + column body */
  --card:         #1A1A1A;   /* order card + footer bar */
  --divider:      #222;      /* column separators */
  --footer-border:#333;      /* footer top border */
  --text:         #ffffff;
  --text-muted:   #888;      /* footer text */
  --text-items:   #aaa;      /* card items line */

  /* Status accents */
  --c-received:   #FF5722;   /* orange */
  --c-preparing:  #FFC107;   /* amber */
  --c-prepared:   #4CAF50;   /* green */
  --c-delivering: #2196F3;   /* blue */

  /* Legacy tokens still used by gate/loading/auth */
  --bg-subtle:    #1A1A1A;
  --surface:      #1A1A1A;
  --surface-2:    #222;
  --border:       rgba(70, 80, 70, 0.5);
  --border-light: rgba(90, 100, 90, 0.6);
  --text-dim:     #b0b8b0;
  --green:        #4CAF50;
  --red:          #E86060;
  --font:         'Inter', -apple-system, sans-serif;
}
```

The legacy tokens block at the bottom keeps the password gate styles working without rewriting them. `--mono` is intentionally removed (no monospace anywhere in the new design).

- [ ] **Step 3: Smoke check**

Open `display-sales.html` in browser. Enter password `tgtukau892312`.

Expected:
- Page still loads (no CSS errors in DevTools console)
- Password gate text now renders in Inter (not IBM Plex)
- Existing layout will look broken in places (footer dots, header card chrome) — that's expected, we replace it in Task 2

- [ ] **Step 4: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): swap font + palette to Industrial Warehouse tokens"
```

---

## Task 2: Replace layout CSS with Industrial Warehouse styles

**Files:**
- Modify: `display-sales.html:140-437` (everything from `/* Layout */` through the end of `4K TV Optimization` media queries)

**What this does:** Removes the old vertical-stacked status section layout, status group header pills, rounded order cards, footer bar with dots, and 4K media queries that target the old grid. Replaces with the Industrial Warehouse layout: orange header bar, 4-column grid, square cards with colored left borders, simple footer.

- [ ] **Step 1: Delete the old layout CSS**

In `display-sales.html`, delete lines 140 through 437 inclusive — this removes the `Layout`, `Status Group Headers`, `Order Cards`, `Footer Bar`, `No data`, and `4K TV Optimization` blocks. Stop just before the `</style>` closing tag.

After deletion, the line that read:
```css
/* ═══════════════════════════════════════════════════════════════
   Layout
   ═══════════════════════════════════════════════════════════════ */
```
should be gone, and `</style>` should follow directly after the auth/gate CSS.

- [ ] **Step 2: Insert the new Industrial Warehouse CSS**

Immediately before the `</style>` tag, insert:

```css
/* ═══════════════════════════════════════════════════════════════
   Industrial Warehouse Layout
   ═══════════════════════════════════════════════════════════════ */
.app {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: var(--bg);
  color: var(--text);
  font-family: var(--font);
}

/* ── Header bar ───────────────────────────────────────────────── */
.iw-header {
  flex-shrink: 0;
  background: var(--c-received);
  color: #fff;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 24px;
  min-height: 50px;
}
.iw-header-title {
  font-size: 13px;
  font-weight: 900;
  letter-spacing: 2.5px;
}
.iw-header-clock {
  font-size: 13px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.iw-fs-btn {
  background: transparent;
  border: 1px solid rgba(255,255,255,0.4);
  color: #fff;
  cursor: pointer;
  padding: 4px 8px;
  margin-left: 16px;
  line-height: 1;
}
.iw-fs-btn:hover { background: rgba(255,255,255,0.15); }
.iw-fs-btn svg { width: 16px; height: 16px; display: block; }

/* ── Column grid ──────────────────────────────────────────────── */
.iw-grid {
  flex: 1;
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 1fr;
  gap: 1px;
  background: var(--divider);
  min-height: 0;
  overflow: hidden;
}
.iw-col {
  background: var(--bg);
  padding: 16px 18px;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}
.iw-col.dimmed { opacity: 0.55; }
.iw-col.empty .iw-col-body { opacity: 0.30; }

/* Column header (count + label) */
.iw-col-head {
  display: flex;
  align-items: baseline;
  gap: 8px;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 3px solid currentColor;
}
.iw-col-count {
  font-size: 48px;
  font-weight: 900;
  line-height: 1;
  font-variant-numeric: tabular-nums;
}
.iw-col-label {
  font-size: 11px;
  font-weight: 900;
  letter-spacing: 2px;
  color: #fff;
}
.iw-col[data-status="received"]   .iw-col-head { color: var(--c-received); }
.iw-col[data-status="preparing"]  .iw-col-head { color: var(--c-preparing); }
.iw-col[data-status="prepared"]   .iw-col-head { color: var(--c-prepared); }
.iw-col[data-status="delivering"] .iw-col-head { color: var(--c-delivering); }

/* Column body — order cards stack */
.iw-col-body {
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
  min-height: 0;
  overflow: hidden;
}

/* ── Order card ───────────────────────────────────────────────── */
.iw-card {
  background: var(--card);
  padding: 12px 14px;
  border-left: 4px solid currentColor;
  flex-shrink: 0;
}
.iw-col[data-status="received"]   .iw-card { color: var(--c-received); }
.iw-col[data-status="preparing"]  .iw-card { color: var(--c-preparing); }
.iw-col[data-status="prepared"]   .iw-card { color: var(--c-prepared); }
.iw-col[data-status="delivering"] .iw-card { color: var(--c-delivering); }

.iw-card-customer {
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.3px;
  text-transform: uppercase;
  color: #fff;
  margin-bottom: 3px;
}
.iw-card-items {
  font-size: 10px;
  color: var(--text-items);
  line-height: 1.5;
}
.iw-card-meta {
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 0.8px;
  margin-top: 6px;
  font-variant-numeric: tabular-nums;
  /* color is inherited from .iw-col[data-status=...] */
}

/* ── Footer bar ───────────────────────────────────────────────── */
.iw-footer {
  flex-shrink: 0;
  background: var(--card);
  border-top: 1px solid var(--footer-border);
  padding: 11px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 10px;
  color: var(--text-muted);
  letter-spacing: 1.2px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.iw-footer-right {
  display: flex;
  gap: 14px;
}

/* ── No-data state (all four columns empty) ───────────────────── */
.iw-no-data {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  color: var(--text-muted);
  letter-spacing: 2px;
}

/* ── 4K TV scaling ─────────────────────────────────────────────── */
@media (min-width: 2560px) {
  .iw-header-title, .iw-header-clock { font-size: 16px; }
  .iw-col-count { font-size: 60px; }
  .iw-col-label { font-size: 13px; }
  .iw-card-customer { font-size: 16px; }
  .iw-card-items { font-size: 12px; }
  .iw-card-meta { font-size: 11px; }
  .iw-footer { font-size: 12px; }
}
@media (min-width: 3840px) {
  .iw-header-title, .iw-header-clock { font-size: 20px; }
  .iw-col-count { font-size: 76px; }
  .iw-col-label { font-size: 16px; }
  .iw-card-customer { font-size: 19px; }
  .iw-card-items { font-size: 14px; }
  .iw-card-meta { font-size: 13px; }
  .iw-footer { font-size: 14px; }
}
```

- [ ] **Step 3: Smoke check**

Open `display-sales.html` in browser. Enter password.

Expected:
- Page loads but the body markup is still the OLD structure (`.app-header`, `.content-area`, `.footer-bar`), so layout will look broken — header card has lost its rounded chrome, content area has no styles. This is expected. We rewrite the body in Task 3.
- No CSS parse errors in DevTools console.

- [ ] **Step 4: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): replace layout CSS with Industrial Warehouse styles"
```

---

## Task 3: Replace body markup with Industrial Warehouse shell

**Files:**
- Modify: `display-sales.html:458-494` (the `<div class="app">...</div>` block)

**What this does:** Replaces the old app shell (rounded header card, generic content area, footer bar with dots) with the new shell: orange header bar, 4-column grid container, simple footer with refresh/page/completed sections.

- [ ] **Step 1: Replace the app shell markup**

Find the block starting `<!-- App -->` (around line 458) and replace from `<div class="app" id="appContainer" style="display:none;">` through its matching closing `</div>` (around line 494) with:

```html
<!-- App -->
<div class="app" id="appContainer" style="display:none;">

  <!-- Orange header bar -->
  <header class="iw-header">
    <div class="iw-header-title">TG AGRO FRUITS · PACKING STATION · LIVE</div>
    <div style="display:flex;align-items:center;">
      <div class="iw-header-clock" id="clockDisplay"></div>
      <button class="iw-fs-btn" id="fsBtn" onclick="toggleFullscreen()" title="Toggle fullscreen">
        <svg id="fsIcon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path id="fsExpand" d="M8 3H5a2 2 0 00-2 2v3m18 0V5a2 2 0 00-2-2h-3m0 18h3a2 2 0 002-2v-3M3 16v3a2 2 0 002 2h3"/>
          <path id="fsShrink" d="M4 14h3a2 2 0 012 2v3m6-9h3a2 2 0 002-2V5m-9 0v3a2 2 0 01-2 2H4m16 4v3a2 2 0 01-2 2h-3" style="display:none"/>
        </svg>
      </button>
    </div>
  </header>

  <!-- 4-column grid (rendered by JS) -->
  <div class="iw-grid" id="contentArea"></div>

  <!-- Footer bar -->
  <div class="iw-footer">
    <span id="refreshInfo">UPDATED 0S AGO · AUTO-REFRESH 60S</span>
    <div class="iw-footer-right">
      <span id="pageInfo"></span>
      <span id="completedInfo">0 COMPLETE TODAY</span>
    </div>
  </div>

</div>
```

Notes:
- `id="contentArea"` is preserved so existing JS rendering hooks still find it
- `id="clockDisplay"`, `id="pageInfo"`, `id="fsBtn"`, `id="fsExpand"`, `id="fsShrink"` preserved — no JS changes needed for those
- `id="refreshInfo"` keeps the existing element but the text format changes (now `UPDATED Ns AGO · AUTO-REFRESH 60S`)
- New `id="completedInfo"` element added for the "N COMPLETE TODAY" footer field
- `id="lastUpdate"` and `id="dataTime"` from the old shell are removed — `dataTime` was the only one written by JS, and we now express the same information via `refreshInfo`. The dead `lastUpdate` reference disappears with the markup.

- [ ] **Step 2: Smoke check**

Open `display-sales.html`, enter password.

Expected:
- Orange header bar appears at the top with title + clock + fullscreen button
- Content area (`.iw-grid`) is empty — this is normal because `renderPages()` still uses the old rendering path. JS will throw on `document.getElementById("dataTime")` being null when refresh fires.
- Take note of any console errors — the next task replaces `renderPages` and the broken references, so errors here are temporary.

- [ ] **Step 3: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): replace app shell with Industrial Warehouse markup"
```

---

## Task 4: Strip emojis + add `colKey` to `STATUS_CONFIG`

**Files:**
- Modify: `display-sales.html:561-567` (`STATUS_CONFIG` array)

**What this does:** The new design has no emojis and groups data into 4 visible columns plus a hidden `completed` count. Add a `colKey` field that maps each status to a column id (`received`/`preparing`/`prepared`/`delivering`) or `null` for completed (counted in the footer, not shown in a column).

- [ ] **Step 1: Replace `STATUS_CONFIG`**

Replace the existing `STATUS_CONFIG` array (lines 561-567) with:

```javascript
const STATUS_CONFIG = [
  { key: "pending",    label: "RECEIVED",   colKey: "received",   dimmed: false },
  { key: "preparing",  label: "PREPARING",  colKey: "preparing",  dimmed: false },
  { key: "prepared",   label: "PREPARED",   colKey: "prepared",   dimmed: false },
  { key: "delivering", label: "DELIVERING", colKey: "delivering", dimmed: true  },
  { key: "completed",  label: "COMPLETED",  colKey: null,         dimmed: true  }
];
```

Removed: `emoji`, `cssClass`, `borderClass` (now driven by `data-status="<colKey>"` in CSS).
Added: `colKey` (column slot id, or `null` if not shown as a column).
Renamed: `pending`'s label from `"ORDER RECEIVED"` to `"RECEIVED"` (matches the spec mockup).
Renamed: `delivering`'s label from `"OUT FOR DELIVERY"` to `"DELIVERING"` (matches mockup).

- [ ] **Step 2: Smoke check**

Open browser, enter password. The page will still be visually broken (renderPages not updated yet), but check console:
- No "STATUS_CONFIG is undefined" errors
- The `buildPages()` call inside `init()` may throw because the old code reads `sc.cssClass` etc. — that's fine, we replace `buildPages` and `renderPages` next.

- [ ] **Step 3: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): strip emojis from STATUS_CONFIG, add colKey"
```

---

## Task 5: Rewrite `buildPages()` for per-column pagination

**Files:**
- Modify: `display-sales.html:694-787` (`buildPages` + `calcMaxCards`)

**What this does:** The old `buildPages` flattens all status sections into a vertical list and slices it into pages. The new design needs **per-column pagination**: each column has its own page count, all columns share the same `currentPage` index, and the global page count is `max(column page counts)`. Header counts always show total across all pages of that column. The `completed` status feeds the footer counter only.

- [ ] **Step 1: Replace `buildPages` and `calcMaxCards`**

Replace lines 694-787 (everything from `function buildPages()` through the end of `function calcMaxCards()`) with:

```javascript
// State holding the rendered grid model + completed count
let columns = [];           // [{ colKey, label, dimmed, total, pages: [[order, ...], ...] }, ...]
let completedToday = 0;     // count of orders with status="completed" delivered today

function isToday(dateStr) {
  if (!dateStr) return false;
  const d = new Date(dateStr + "T00:00:00");
  const t = new Date();
  return d.toDateString() === t.toDateString();
}

function buildPages() {
  // 1. Group orders by status key
  const grouped = {};
  STATUS_CONFIG.forEach(s => { grouped[s.key] = []; });

  orders.forEach(order => {
    const status = (order.status || "pending").toLowerCase().replace(/\s+/g, '_');
    if (!grouped[status]) grouped[status] = [];
    const items = orderItems.filter(i => i.order_id === order.id);
    grouped[status].push({ ...order, items });
  });

  // 2. FIFO sort within each group (oldest created_at first)
  Object.keys(grouped).forEach(key => {
    grouped[key].sort((a, b) => {
      const aT = a.created_at || '';
      const bT = b.created_at || '';
      return aT.localeCompare(bT);
    });
  });

  // 3. "Completed today" footer counter
  completedToday = (grouped["completed"] || []).filter(o => isToday(o.delivery_date)).length;

  // 4. Build the four visible columns with per-column pagination
  const cardsPerCol = calcCardsPerColumn();
  columns = STATUS_CONFIG
    .filter(sc => sc.colKey !== null)
    .map(sc => {
      const list = grouped[sc.key] || [];
      const colPages = [];
      if (list.length === 0) {
        colPages.push([]);
      } else {
        for (let i = 0; i < list.length; i += cardsPerCol) {
          colPages.push(list.slice(i, i + cardsPerCol));
        }
      }
      return {
        colKey: sc.colKey,
        label: sc.label,
        dimmed: sc.dimmed,
        total: list.length,
        pages: colPages
      };
    });

  // 5. Global pages = max page count across columns (each column rotates in lock-step)
  const maxPages = Math.max(1, ...columns.map(c => c.pages.length));
  pages = new Array(maxPages).fill(null).map((_, i) => ({ index: i }));
}

function calcCardsPerColumn() {
  // Each column has: header (~80px) + body
  // Card height ~70px (12+14 padding + 3 lines of text + 6px gap to next)
  const headerH = 50;     // orange header bar
  const footerH = 36;     // footer bar
  const colHeaderH = 80;  // count + label + 3px border + 14px margin
  const colPadding = 32;  // 16px top + 16px bottom
  const cardH = 78;       // card outer height including the 10px gap

  const available = window.innerHeight - headerH - footerH - colHeaderH - colPadding;
  return Math.max(2, Math.floor(available / cardH));
}
```

The old `pages = [...]` array is repurposed as a thin "which page index am I on" list — its only role now is driving `currentPage`/`pages.length` checks elsewhere in the file. The actual content lives in `columns`.

- [ ] **Step 2: Smoke check**

Open browser, enter password. Console may still show errors from the old `renderPages` reading `pg.blocks`. Open DevTools console and run:

```javascript
buildPages(); console.log({ columns, pages, completedToday });
```

Expected:
- `columns` is an array of length 4
- Each column has `colKey`, `label`, `total`, `pages` (array of arrays)
- `completedToday` is a number (likely 0 unless test data exists)
- `pages` is a non-empty array

- [ ] **Step 3: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): per-column pagination model in buildPages"
```

---

## Task 6: Rewrite `renderPages()` for 4-column grid

**Files:**
- Modify: `display-sales.html:792-874` (`renderPages` function)

**What this does:** Renders the four columns side-by-side every frame. Each column shows the slice of orders for the current global page index (or empty if that column has fewer pages than the global total). Updates page indicator + completed footer.

- [ ] **Step 1: Replace `renderPages`**

Replace lines 792-874 (`function renderPages() { ... }`) with:

```javascript
function renderPages() {
  const container = document.getElementById("contentArea");
  const pageInfoEl = document.getElementById("pageInfo");
  const completedEl = document.getElementById("completedInfo");

  // Empty state — all four columns empty
  const allEmpty = columns.every(c => c.total === 0);
  if (allEmpty) {
    container.innerHTML = '<div class="iw-no-data">NO ORDERS FOR TODAY OR TOMORROW</div>';
    pageInfoEl.textContent = '';
    completedEl.textContent = (completedToday || 0) + ' COMPLETE TODAY';
    return;
  }

  // Render four columns
  container.innerHTML = columns.map(col => {
    const pageIdx = currentPage < col.pages.length ? currentPage : -1;
    const slice = pageIdx >= 0 ? col.pages[pageIdx] : [];
    const dimClass = col.dimmed ? ' dimmed' : '';
    const emptyClass = col.total === 0 ? ' empty' : '';
    const countStr = String(col.total).padStart(2, '0');

    let cardsHtml = '';
    if (slice.length === 0 && col.total === 0) {
      cardsHtml = ''; // empty column body, dim handled by .empty
    } else {
      cardsHtml = slice.map(order => renderCard(order)).join('');
    }

    return (
      '<div class="iw-col' + dimClass + emptyClass + '" data-status="' + col.colKey + '">' +
        '<div class="iw-col-head">' +
          '<span class="iw-col-count">' + countStr + '</span>' +
          '<span class="iw-col-label">' + col.label + '</span>' +
        '</div>' +
        '<div class="iw-col-body">' + cardsHtml + '</div>' +
      '</div>'
    );
  }).join('');

  // Footer page indicator (only if any column actually paginates)
  if (pages.length > 1) {
    pageInfoEl.textContent = 'PAGE ' + (currentPage + 1) + ' · ' + pages.length;
  } else {
    pageInfoEl.textContent = '';
  }
  completedEl.textContent = (completedToday || 0) + ' COMPLETE TODAY';
}

function renderCard(order) {
  const custName = customers[order.customer_id] || "Unknown Customer";

  // Items: compact "2× Pineapple · 1× Jackfruit"
  let itemsLine = '';
  if (order.items && order.items.length > 0) {
    itemsLine = order.items.map(item => {
      const display = getItemDisplay(item);
      const qty = display.qty;
      return qty + '\u00D7 ' + display.label;
    }).join(' · ');
  }

  // Meta line: "10:30 · AF-SO012"
  const timeStr = order.delivery_time ? formatTime(order.delivery_time) : '';
  const docNo = order.doc_number || order.id || '';
  let metaLine = '';
  if (timeStr && docNo) metaLine = timeStr + ' · ' + docNo;
  else if (timeStr) metaLine = timeStr;
  else if (docNo) metaLine = docNo;

  return (
    '<div class="iw-card">' +
      '<div class="iw-card-customer">' + esc(custName) + '</div>' +
      (itemsLine ? '<div class="iw-card-items">' + esc(itemsLine) + '</div>' : '') +
      (metaLine ? '<div class="iw-card-meta">' + esc(metaLine) + '</div>' : '') +
    '</div>'
  );
}
```

Notes:
- `renderPages` no longer manipulates `.page-dot` elements (the new footer has no dots)
- `showPage()` (next task) becomes a simple re-render — no per-page DOM transitions
- `iw-card-meta` colour comes from CSS via `data-status` parent — no inline color
- Old `getFulfillmentBadge()` and `formatDeliveryDate()` are NOT called in the new card. They stay defined in the file (still referenced by nothing — leave them, removing is out of scope and risks regression).

- [ ] **Step 2: Smoke check**

Open browser, enter password.

Expected:
- Four columns visible side-by-side: RECEIVED, PREPARING, PREPARED, DELIVERING
- Each column shows its count number in the column color (orange/amber/green/blue)
- DELIVERING column dimmed
- Order cards (if any data exists) show CUSTOMER NAME / items / time + doc number
- Footer shows "0 COMPLETE TODAY" (or actual count)
- No console errors

If columns have 0 orders, the column body should be at 30% opacity and the count should read `00`.

- [ ] **Step 3: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): render 4-column Industrial Warehouse grid"
```

---

## Task 7: Simplify `showPage()` and refresh footer text

**Files:**
- Modify: `display-sales.html:876-899` (`showPage` + `nextPage`)
- Modify: `display-sales.html:921-925` (`updateLastRefresh`)

**What this does:** The old `showPage()` toggled `.active` class on absolutely-positioned `.sales-page` siblings for cross-fade. The new design just re-renders. Also rewires `updateLastRefresh()` to update the new footer "UPDATED Ns AGO · AUTO-REFRESH 60S" text (and ticks the seconds counter live).

- [ ] **Step 1: Replace `showPage` and `nextPage`**

Replace lines 876-899 with:

```javascript
function showPage(idx) {
  if (pages.length === 0) return;
  currentPage = ((idx % pages.length) + pages.length) % pages.length;
  renderPages();
}

function nextPage() {
  if (pages.length <= 1) return;
  showPage(currentPage + 1);
}
```

- [ ] **Step 2: Replace `updateLastRefresh` and add a live ticker**

Replace lines 921-925 (`function updateLastRefresh() { ... }`) with:

```javascript
let lastRefreshAt = Date.now();

function updateLastRefresh() {
  lastRefreshAt = Date.now();
  tickRefreshLabel();
}

function tickRefreshLabel() {
  const el = document.getElementById("refreshInfo");
  if (!el) return;
  const secs = Math.max(0, Math.floor((Date.now() - lastRefreshAt) / 1000));
  el.textContent = 'UPDATED ' + secs + 'S AGO · AUTO-REFRESH 60S';
}
```

- [ ] **Step 3: Wire the ticker into `init()`**

Find line 945 in `init()`:

```javascript
    setInterval(updateClock, 1000);
```

Add directly after it:

```javascript
    setInterval(tickRefreshLabel, 1000);
```

- [ ] **Step 4: Update the clock format**

Find `updateClock` at lines 915-919 and replace with:

```javascript
function updateClock() {
  const now = new Date();
  // "10:42 AM · TUE 7 APR"
  let h = now.getHours();
  const m = String(now.getMinutes()).padStart(2, '0');
  const ampm = h >= 12 ? 'PM' : 'AM';
  if (h > 12) h -= 12;
  if (h === 0) h = 12;
  const days = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
  const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
  const dow = days[now.getDay()];
  const day = now.getDate();
  const mon = months[now.getMonth()];
  const text = h + ':' + m + ' ' + ampm + ' \u00B7 ' + dow + ' ' + day + ' ' + mon;
  const el = document.getElementById("clockDisplay");
  if (el) el.textContent = text;
}
```

- [ ] **Step 5: Smoke check**

Open browser, enter password.

Expected:
- Header clock reads in format: `10:42 AM · TUE 7 APR` (use current real time)
- Footer left reads `UPDATED 0S AGO · AUTO-REFRESH 60S` and increments every second
- After ~60 seconds, refresh fires, the seconds counter resets to 0
- If multiple pages exist, page rotation still happens every 15s (rotateTimer is unchanged)
- If only one page, no `PAGE n · m` text shows in the footer
- No console errors

- [ ] **Step 6: Commit**

```bash
git add display-sales.html
git commit -m "refactor(display-sales): simplify showPage, live refresh ticker, new clock format"
```

---

## Task 8: Remove dead `lastUpdate`/`dataTime` references and unused CSS hooks

**Files:**
- Modify: `display-sales.html` — search for any leftover references to `dataTime`, `lastUpdate`, `page-dot`, `pageDots`

**What this does:** The shell rewrite (Task 3) removed the DOM elements for `lastUpdate`, `dataTime`, and `pageDots`, but JS code may still reference them. Clean up to avoid silent `null` reads. Also remove the now-unused `.no-data` and `.sales-page` references from any leftover code.

- [ ] **Step 1: Audit**

Run searches in DevTools / your editor for these strings:

```
getElementById("dataTime")
getElementById("lastUpdate")
getElementById("pageDots")
.sales-page
.page-dot
```

- [ ] **Step 2: Remove orphan references**

For each match, delete the line if it's a dead reference (no longer has a backing DOM element).

Expected matches and fixes:
- `document.getElementById("dataTime")` inside the OLD `updateLastRefresh` — already replaced in Task 7, should be gone. Verify.
- `document.getElementById("pageDots")` and `dotsEl.innerHTML = ...` lines in `renderPages` — already replaced in Task 6, should be gone. Verify.
- The old `setInterval(refreshData, 60000)` call in `init()` is still valid (refresh logic unchanged) — leave it.
- `getFulfillmentBadge()` and `formatDeliveryDate()` are now unused but keep them in place — they're harmless and removing them is YAGNI cleanup outside the redesign scope.

- [ ] **Step 3: Smoke check**

Hard refresh browser (Ctrl+Shift+R) and watch console for ~70 seconds (long enough for one auto-refresh).

Expected:
- No `Cannot read property of null` errors
- No `getElementById(...) is null` errors
- Display continues rendering after the 60s refresh

- [ ] **Step 4: Commit**

```bash
git add display-sales.html
git commit -m "chore(display-sales): remove dead references to old shell elements"
```

---

## Task 9: End-to-end visual verification

**Files:** none (verification only)

**What this does:** Walk through every spec requirement against the live display to confirm nothing was missed.

- [ ] **Step 1: Open the display in a real browser window at full size**

```bash
start "" "display-sales.html"
```

Enter password `tgtukau892312`.

- [ ] **Step 2: Spec checklist**

Verify each item from `docs/superpowers/specs/2026-04-07-packing-display-redesign-design.md`:

| Spec requirement | How to verify |
|---|---|
| Solid orange header bar #FF5722 | Inspect element `.iw-header`, computed `background-color` is `rgb(255, 87, 34)` |
| Header title `TG AGRO FRUITS · PACKING STATION · LIVE` | Visual |
| Live clock format `10:42 AM · TUE 7 APR` | Visual |
| 4 columns equal width | Inspect `.iw-grid`, computed `grid-template-columns` shows four `1fr` |
| 1px column separators #222 | Inspect `.iw-grid`, computed `gap: 1px`, `background-color: rgb(34, 34, 34)` |
| Min column body height 380px | Resize window vertically — columns should not collapse to nothing |
| 48px count numerals in column color | Inspect `.iw-col-count`, computed `font-size: 48px`, color matches column |
| 11px label, weight 900, letter-spacing 2px | Inspect `.iw-col-label` |
| 3px column-color bottom border on header | Visual + inspect `.iw-col-head` `border-bottom` |
| Card background #1A1A1A | Inspect `.iw-card`, `background-color: rgb(26, 26, 26)` |
| 4px column-color left border on card | Inspect `.iw-card`, `border-left-width: 4px` |
| Customer name 13px weight 800 ALL CAPS | Inspect `.iw-card-customer` |
| Items 10px gray | Inspect `.iw-card-items`, `color: rgb(170, 170, 170)` |
| Time + ID 9px weight 800 in column color | Inspect `.iw-card-meta` |
| DELIVERING column dimmed to 55% | Inspect `.iw-col[data-status="delivering"]`, `opacity: 0.55` |
| Empty column count `00` + body 30% opacity | Force one status to be empty (filter test data); column shows `00`; body opacity 0.30 |
| Footer `UPDATED Ns AGO · AUTO-REFRESH 60S` | Visual |
| Footer page indicator `PAGE 1 · 2` (only when multi-page) | Resize window small to force overflow, verify indicator appears |
| Footer `N COMPLETE TODAY` count | Visual |
| Inter font everywhere | Inspect any text, computed `font-family` starts with `"Inter"` |
| No emojis anywhere | Visual + grep file: `grep -P '[\x{1F300}-\x{1FAFF}]' display-sales.html` should match nothing in render output |
| No rounded corners on cards | Inspect `.iw-card`, `border-radius: 0px` |
| FIFO sort within each column | Cross-check Sales module orders by `created_at` against display order |
| Auto-rotate every 15s when multi-page | Wait 15s with multi-page state |
| Auto-refresh every 60s | Wait 60s, watch the "UPDATED" counter reset |
| Password gate still works | Open in fresh InPrivate window |

- [ ] **Step 3: 16:9 sanity check**

Resize the browser to 1920×1080 (or use DevTools device emulation set to "Responsive" 1920×1080). The whole display must fit without scrollbars on the main `.app` container.

- [ ] **Step 4: Console clean check**

Open DevTools console. Hard refresh. Watch for 70 seconds. Expected: zero red errors. Yellow font-decoder warnings from Google Fonts are fine.

- [ ] **Step 5: If anything fails**

Fix inline (don't make a new task) and commit with `fix(display-sales): <what>`.

- [ ] **Step 6: Final commit if anything was fixed**

```bash
git add display-sales.html
git commit -m "fix(display-sales): address E2E verification findings"
```

If nothing was fixed, no commit needed for this task.

---

## Task 10: Deploy to Netlify

**Files:** none (deploy only)

**What this does:** Pushes the redesigned display to production. The user has standing approval for auto-deploy after agreed changes (`feedback_auto_deploy.md`).

- [ ] **Step 1: Push to GitHub**

```bash
git push origin main
```

- [ ] **Step 2: Deploy to Netlify**

```bash
netlify deploy --prod --dir=.
```

- [ ] **Step 3: Verify production**

Open `https://tgfarmhub.com/display-sales.html` in a browser, enter password, confirm the new design renders.

- [ ] **Step 4: Update CLAUDE.md**

Add this line under the Tech Debt section:

```markdown
- [x] **Packing display redesign** (2026-04-07): display-sales.html rebuilt in Industrial Warehouse style — 4-column grid, Inter typography, orange accent header, sharp 90deg cards, no emojis. Spec at `docs/superpowers/specs/2026-04-07-packing-display-redesign-design.md`, plan at `docs/superpowers/plans/2026-04-07-packing-display-redesign.md`.
```

- [ ] **Step 5: Commit CLAUDE.md update**

```bash
git add CLAUDE.md
git commit -m "docs: log packing display redesign in tech debt"
git push origin main
```

---

## Self-Review Notes

**Spec coverage:** Every item in the spec maps to a task —
- Visual direction (Inter font, palette) → Task 1
- Layout CSS (header bar, 4-col grid, columns, cards, footer) → Task 2
- Body markup → Task 3
- Status keys + emoji removal → Task 4
- Per-column pagination model → Task 5
- 4-column rendering → Task 6
- Page rotation simplification + clock format + refresh ticker → Task 7
- Dead reference cleanup → Task 8
- Spec verification → Task 9
- Deploy → Task 10

**Type consistency:** `colKey` used in `STATUS_CONFIG` (Task 4), `columns[].colKey` (Task 5), `data-status="<colKey>"` (Task 6, CSS Task 2). `currentPage` and `pages` are used by `showPage()` (Task 7) and rebuilt by `buildPages()` (Task 5) — `pages` is now a thin array of `{ index }` placeholders, only its `length` matters; the resize handler in `init()` already does `currentPage = Math.min(prevPage, Math.max(0, pages.length - 1))` which still works.

**No placeholders:** Every code step has the actual code. Every smoke check has the actual condition to verify.
