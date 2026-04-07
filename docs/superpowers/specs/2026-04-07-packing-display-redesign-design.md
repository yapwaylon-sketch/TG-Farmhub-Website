# Packing Station Display Redesign — Design Spec

**Date:** 2026-04-07
**Status:** Approved (design phase)
**File affected:** `display-sales.html`
**Sub-project:** TG Agro Fruits packing station TV display

## Goal

Replace the current generic "AI slop" dashboard look on `display-sales.html` with a deliberate **Industrial Warehouse** visual language — Swiss grid, heavy sans, massive numerals, orange accent. The display must remain legible from 5 metres on a 16:9 TV in the packing station, and must continue to surface live order state for the packing team.

## Why a redesign

The current display works (data is correct after the FIFO + status-key fix) but reads as a generic dark dashboard. The packing team sees this screen all day. We want it to feel like **factory signage** — confident, brutal, instantly readable — not like a Bootstrap admin template.

## Visual Direction

**Industrial Warehouse** — chosen from three explored treatments (Editorial, Industrial Warehouse, Quiet Scandinavian).

- Swiss grid layout
- Heavy sans typography (Inter, weights 700/900)
- Orange accent bar (`#FF5722`)
- Massive numeric counts, tiny labels
- Sharp 90° corners, no rounded cards, no gradients
- No emojis — pure typographic hierarchy

## Layout

**4-column equal-width grid** showing all four active status groups in left-to-right workflow order:

```
RECEIVED  |  PREPARING  |  PREPARED  |  DELIVERING
```

- All four columns always visible (the packing team needs the full pipeline at a glance — this was an explicit user requirement during brainstorming)
- 1px column separators (`#222` on `#0E0E0E` background)
- Min column body height: 380px

### Header bar
- Solid orange (`#FF5722`), ~50px tall, full width
- Left: `TG AGRO FRUITS · PACKING STATION · LIVE` — 13px, weight 900, letter-spacing 2.5px
- Right: live clock `10:42 AM · TUE 7 APR` — 13px, weight 700, tabular numerals

### Column header (per status)
- 48px display weight 900 count number, in column color, tabular numerals
- 11px weight 900 all-caps label next to count, letter-spacing 2px
- 3px solid bottom border in column color, 10px padding-bottom

### Order cards
- Background `#1A1A1A` (dark gray)
- 4px solid left border in column color
- 12px × 14px padding
- 10px gap between cards within a column
- **Customer name:** 13px weight 800 ALL CAPS, letter-spacing 0.3px — primary visual element
- **Items line:** 10px regular, color `#aaa`, line-height 1.5 (e.g. `2× Pineapple · 1× Jackfruit`)
- **Time + ID line:** 9px weight 800 in column color, letter-spacing 0.8px (e.g. `10:30 · AF-SO012`)
- No rounded corners — sharp 90° angles

### Footer bar
- Background `#1A1A1A`, 1px top border `#333`, 11px × 24px padding
- 10px text, color `#888`, weight 600, letter-spacing 1.2px
- Left: `UPDATED 30S AGO · AUTO-REFRESH 60S`
- Right: page indicator (`PAGE 1 · 2`) + `5 COMPLETE TODAY`

## Color System

| Token            | Hex       | Use                                       |
|------------------|-----------|-------------------------------------------|
| Background       | `#0E0E0E` | Page + column body                        |
| Card             | `#1A1A1A` | Order card + footer bar                   |
| Divider          | `#222`    | Column separators                         |
| Footer border    | `#333`    | Footer top border                         |
| Muted text       | `#888`    | Footer text                               |
| Items text       | `#aaa`    | Card items line                           |
| Received (orange)| `#FF5722` | Header bar + Received column accents      |
| Preparing (amber)| `#FFC107` | Preparing column accents                  |
| Prepared (green) | `#4CAF50` | Prepared column accents                   |
| Delivering (blue)| `#2196F3` | Delivering column accents (dimmed)        |

## Typography

- **Family:** Inter (replaces IBM Plex Sans). Load via Google Fonts CDN with weights 400/700/900.
- **No emojis** anywhere on the display.
- All numerals use `font-variant-numeric: tabular-nums` so digits don't jitter on refresh.

## Behavior

### Dimmed delivering column
The DELIVERING column renders at **55% opacity**. Rationale: orders in delivery are no longer the packing team's concern, but the count is still useful context. Dimming pushes the eye to the live workload.

### Empty states
If a status group has 0 orders:
- Show `00` count in column color
- Dim the column body (cards area) to 30% opacity
- No "no orders" placeholder text

### Pagination (overflow)
When a column has more order cards than fit in the column body:
- Auto-rotate pages every **15 seconds**
- Header counts always show the **total across all pages** (not just current page)
- Footer shows current page indicator: `PAGE 1 · 2`
- Each column paginates independently

### Auto-refresh
- Data refresh every **60 seconds** (existing behavior, unchanged)
- Footer "UPDATED Ns AGO" counter ticks live
- Clock in header bar updates every second

### Order sorting
- Existing FIFO sort by `created_at ASC` is preserved
- Oldest orders surface first within each column

### Status grouping
The display continues to read from the same Supabase query but groups by:
- `pending` → RECEIVED
- `preparing` → PREPARING
- `prepared` → PREPARED
- `delivering` → DELIVERING

`completed` orders are excluded from columns but counted in the footer's `N COMPLETE TODAY` (filtered by today's date).

## What stays the same

- Password gate (sessionStorage `tg_tv_auth`, password unchanged)
- Supabase REST API auth via anon key (no shared.js dependency)
- Hardcoded company filter to `tg_agro_fruits`
- 60s data refresh cycle
- The data model — only the rendering layer changes

## What's removed

- All current emoji usage (`⏳ 🔄 ✅ 🚚 🏁`)
- Gradient backgrounds
- Rounded card corners
- IBM Plex Sans (replaced by Inter)
- Generic dashboard chrome

## Open Questions

None. All design decisions were resolved during the brainstorming session.

## Out of Scope

- Sound/audio alerts on new orders (deferred)
- Per-driver delivery sub-grouping (deferred)
- Touch interaction (display is read-only TV)
- A separate `display-spray.html` (separate future project, see CLAUDE.md blueprint)

## Reference

Full visual mockup: `.superpowers/brainstorm/1270-1775550216/content/final-design.html`
