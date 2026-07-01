# Block Watchlist — Design

**Date:** 2026-07-01
**Module:** Crop Care (`spraytracker.html`), surfaced in Growth Tracker (`growthtracker.html`) + Hub (`index.html`)
**Company:** TG Agribusiness (pineapple)
**Status:** Approved design, pending implementation plan

## Problem
The user (Waylon) regularly spots blocks with problems (pest, disease, nutrient deficiency, etc.) that need extra attention and follow-up jobs, but there is no way to record and surface these — he keeps them in his head. He needs to:
1. Flag a block as needing attention, with a description + photographic evidence.
2. Have flagged blocks stand out loudly across the system so nothing is forgotten.
3. Monitor a flagged block over time (adding dated observations + photos) and see the jobs done about it, **without re-typing job info** — pulled from the existing Crop Care daily job log.
4. Resolve the issue when handled, keeping the history.

This realizes two previously-parked (KIV) CLAUDE.md ideas: **"Pest/disease incident log per block"** and **"Block photos."**

## Key architecture fact
Growth Tracker and Crop Care share the same block tables (`pnd_blocks` + `block_crops`). Storing issues against `pnd_blocks.id` means flagged blocks surface in **both** modules (and the hub) automatically, with no cross-table syncing. There is currently **no** flag/critical/attention concept anywhere; the only per-block note today is `pnd_blocks.remarks` (plain read-only text, Growth Tracker only).

## Where it lives
- **New "Watchlist" tab** inside Crop Care (right after Summary). This is the home for creating and managing issues.
- Growth Tracker stays **read-only** — it only *displays* the alert badge/banner, never manages issues.
- Hub shows a count badge on the Crop Care card.

## Data model

### Table: `block_issues`
One row per problem on a block.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `block_id` | uuid FK → `pnd_blocks.id` | the flagged block |
| `title` | text | short, e.g. "Mealybug, north corner" |
| `description` | text null | optional longer detail entered at flag time |
| `category` | text | Pest / Disease / Nutrient / Water / Weather / Other |
| `severity` | text | `critical` / `watch` — user-set, changeable |
| `status` | text | `active` / `resolved` |
| `opened_at` | timestamptz | |
| `opened_by` | text | user name |
| `resolved_at` | timestamptz null | |
| `resolved_note` | text null | closing note |
| `company_id` | text | `tg_agribusiness` (consistent with other new agribusiness tables) |
| `created_at` | timestamptz default now() | |

- A block is considered **flagged** iff it has ≥1 issue with `status = 'active'`. No redundant boolean on `pnd_blocks`.
- **Severity** (how bad: critical/watch) and **status** (lifecycle: active/resolved) are separate axes. Only two statuses — the "keep watching" idea is covered by the `watch` severity + the timeline (no third "monitoring" state).

### Table: `block_issue_updates`
The monitoring timeline — one row per observation the user adds over time.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `issue_id` | uuid FK → `block_issues.id` ON DELETE CASCADE | |
| `note` | text | the observation |
| `photos` | jsonb | array of public photo URLs (0..n) |
| `created_at` | timestamptz default now() | |
| `created_by` | text | user name |

### Jobs — no schema change
Jobs are **not** tagged to issues (user decision: workers may forget to tag, so no manual linking). Instead, the issue timeline **auto-pulls** every Crop Care job on that block within the issue's active window:

- Source: `pnd_jobs` where `block_id = issue.block_id` AND the job's relevant date (`completion_date`, falling back to `planned_date`) is between `issue.opened_at` and `COALESCE(issue.resolved_at, now())`.
- Includes sprays + fertilizer jobs (both live in `pnd_jobs`).
- **Excludes** Weed Control jobs (`pnd_weed_jobs`) — separate module about drains/roadsides, not plant health. (Revisit only if requested.)
- Displayed per job: product name, category, date, worker, tanks/water, logged-by. No re-typing.

### Storage
- New bucket **`crop-issue-photos`** (public read), with explicit `storage.objects` RLS policy `crop_issue_photos_all FOR ALL USING (bucket_id = 'crop-issue-photos')` — the `public:true` flag governs READ only; WRITE needs the policy (per CLAUDE.md gotcha #10).
- Reuse the standard resize-to-JPEG-1200px-q0.8 upload pattern (from `sales.html` `soResizeAndUpload`/`soUploadPhotoBlob`).
- Paths: `issues/{issue_id}/{timestamp}.jpg` for both opening photos and update photos.

### RLS
Both new tables: anon + authenticated `FOR ALL` policies (matching the module's existing pattern, e.g. `pnd_weed_jobs`).

## Workflow
1. **Flag** — Crop Care → Watchlist → "＋ Flag a Block" (or the ⚑ icon on a Summary/Growth row) → modal: block, severity (Critical/Watch), category, title, description, photos → creates a `block_issues` row (`status=active`) + optional first photos.
2. **Surface** — block instantly shows a red (critical) / amber (watch) badge + tint everywhere.
3. **Monitor** — open the issue → "＋ Add Update" → note + photos → creates a `block_issue_updates` row. Timeline shows updates interleaved with auto-pulled jobs, **newest first**.
4. **Resolve** — "✓ Mark Resolved" + closing note → `status=resolved`, `resolved_at/by/note` set. Badge clears everywhere; issue moves to Resolved history (still viewable).

## UI

### Flag entry points (two)
1. **Primary:** "＋ Flag a Block" button at top of Watchlist tab → form with block dropdown.
2. **Shortcut:** small ⚑ icon on each block row in Crop Care Summary (sticky Block cell) and Growth Tracker Block column → same form, block pre-filled.

### Flag modal (module-local `showModal` pattern, unique overlay id)
Block (dropdown or pre-filled) · Severity toggle (🔴 Critical / 🟠 Watch) · Category chips · short title · description (optional) · Photos (Take Photo / From Album, 0..n) · [Flag Block].

### Issue detail
Header (title, severity badge, category pill, active/resolved status, block, opened by/at, days active, description, opening photos) · actions (＋ Add Update, ✓ Mark Resolved) · timeline (newest first) mixing 📝 observations (note + photos) and 🌫 auto-pulled jobs (green "from Crop Care" tag), plus a 🚩 "issue opened" anchor at the bottom.

### Watchlist tab
Critical section (red) on top → Watch section (amber) → Resolved history (collapsed at bottom).

### Attention-grabbing layer
- **Crop Care Summary & Growth Tracker:** red ⚠ / amber badge on the block name cell, flagged rows tinted + floated to top, and a red banner above the table: "⚠ N blocks need attention — X Critical, Y Watch".
- **Hub:** count badge on the Crop Care module card.

## Out of scope (parked)
- **Telegram alert** when a block is flagged — infra exists (oil-palm bot) but deferred to a future to-do.
- **Tagging jobs to issues** manually — rejected (worker-forget risk); auto-pull by block+window instead.
- **Weed Control jobs** in the timeline — excluded unless requested.
- **Crop Care TV display** (`display-spray.html`) integration — not now.
- **Severity/category reporting** views — the data supports it later; no report built now.

## Notes / gotchas to respect during build
- `pnd_blocks` and the Summary block cell already carry variety + status metadata — badge slots into the existing sticky Block cell.
- `sbMutate` needs a thunk; `sbQuery` takes the builder directly (CLAUDE.md gotcha #8).
- `esc()` doesn't escape quotes — use data-attrs + event delegation for onclick, not string interpolation (gotcha #7).
- New tables DO get `company_id`; but never filter `pnd_jobs`/`pnd_spray_logs` by `company_id` unreliably — follow existing Crop Care query patterns.
- Both dashboards are currently read-only for block data; the flag modal is the only new write interaction there — keep the ⚑ shortcut visually subtle so it doesn't clutter the tables.
