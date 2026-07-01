# Block Watchlist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user flag pineapple blocks that need attention (pest/disease/etc.) with severity + photos, monitor them over time with a timeline that auto-pulls Crop Care jobs, and surface flagged blocks loudly across Crop Care, Growth Tracker, and the Hub.

**Architecture:** Two new Supabase tables (`block_issues`, `block_issue_updates`) hang off the shared `pnd_blocks.id`, so flagged state appears in both trackers with no syncing. All UI lives in `spraytracker.html` (Crop Care) as a new "Watchlist" tab + a flag modal + an issue-detail sub-view. Growth Tracker (`growthtracker.html`) and the Hub (`index.html`) get read-only badges. Jobs are NOT tagged to issues — the timeline auto-pulls `pnd_jobs` for the block within the issue's active window.

**Tech Stack:** Static HTML + vanilla JS, Supabase (PostgREST + RLS + Storage), Netlify. **No automated test framework** — verification is `node --check` on the extracted inline script, DB introspection via `pg`, live `curl | grep` after deploy, and a browser smoke test.

---

## Conventions & Gotchas (read before every task)
- **`sbQuery(builder)`** takes the query builder directly. **`sbMutate(() => builder)`** needs a thunk. **`sbUpload(() => uploadFn, msg)`** needs a thunk. Mixing these up is the #1 recurring bug (CLAUDE.md gotcha #8).
- Chain **`.select()`** on every insert/update/delete or Supabase v2 returns empty data.
- **`esc()` does not escape quotes.** For `onclick` handlers that need a row id, use `data-*` attributes + `event.currentTarget.dataset.x` (gotcha #7), never string-interpolate ids into `onclick="fn('${id}')"`.
- **Do NOT filter `pnd_jobs` or `pnd_spray_logs` by `company_id`** — trigger-created rows leave it null (CLAUDE.md). Filter by `block_id` only.
- Modals: set `document.getElementById("modal-container").innerHTML = \`<div class="modal-overlay"><div class="modal-box">…</div></div>\``; close with `closeModal()` (clears `#modal-container`).
- `todayStr()`, `fmtDate()`, `fmtDateShort()`, `esc()`, `notify()`, `confirmAction(title,msg,onConfirm,danger)` (callback form), `showLoading()/hideLoading(el)` are in shared.js.
- New agribusiness tables DO get `company_id` (default `'tg_agribusiness'`).
- `currentUser.displayName` is the logged-in user's name.
- **Verifying the inline script parses:** extract and node-check with:
  ```bash
  node -e "const fs=require('fs'),h=fs.readFileSync('spraytracker.html','utf8');const m=[...h.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(x=>x[1]).join('\n;\n');fs.writeFileSync(process.env.TEMP+'/sp.js',m);" && node --check "$TEMP/sp.js" && echo "PARSE OK"
  ```
  (Inline `</script>` inside strings is already written as `</`+`script>` in this file; if you add such a string, keep that escaping.)
- **Deploy:** `npx netlify-cli deploy --prod --dir=. --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26` (NO `--functions` flag — CLAUDE.md 2026-05-11 lesson).

## File Structure
- `supabase/block_issues_migration.sql` — **create** — DDL for 2 tables + indexes + RLS.
- `scripts/run-block-issues-migration.mjs` — **create** — one-shot `pg` runner + storage bucket creator.
- `spraytracker.html` — **modify** — Watchlist tab, flag modal, issue detail, summary badges, loaders/helpers, back-nav wiring.
- `spraytracker.css` — **modify** — badge/tint/timeline styles.
- `growthtracker.html` — **modify** — read-only badge + banner + loader.
- `index.html` — **modify** — count badge on the Crop Care hub card.

---

## Task 1: Database migration (2 tables + RLS) and storage bucket

**Files:**
- Create: `supabase/block_issues_migration.sql`
- Create: `scripts/run-block-issues-migration.mjs`

- [ ] **Step 1: Write the migration SQL**

Create `supabase/block_issues_migration.sql`:

```sql
-- Block Watchlist: issues + monitoring updates (2026-07-01)
CREATE TABLE IF NOT EXISTS block_issues (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id      uuid NOT NULL REFERENCES pnd_blocks(id) ON DELETE CASCADE,
  title         text NOT NULL,
  description   text,
  category      text NOT NULL DEFAULT 'Other',
  severity      text NOT NULL DEFAULT 'watch' CHECK (severity IN ('critical','watch')),
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','resolved')),
  opened_at     timestamptz NOT NULL DEFAULT now(),
  opened_by     text,
  resolved_at   timestamptz,
  resolved_note text,
  company_id    text NOT NULL DEFAULT 'tg_agribusiness',
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_block_issues_block  ON block_issues(block_id);
CREATE INDEX IF NOT EXISTS idx_block_issues_status ON block_issues(status);

CREATE TABLE IF NOT EXISTS block_issue_updates (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id   uuid NOT NULL REFERENCES block_issues(id) ON DELETE CASCADE,
  note       text NOT NULL DEFAULT '',
  photos     jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text
);
CREATE INDEX IF NOT EXISTS idx_block_issue_updates_issue ON block_issue_updates(issue_id);

ALTER TABLE block_issues        ENABLE ROW LEVEL SECURITY;
ALTER TABLE block_issue_updates ENABLE ROW LEVEL SECURITY;

CREATE POLICY block_issues_anon        ON block_issues        FOR ALL TO anon          USING (true) WITH CHECK (true);
CREATE POLICY block_issues_auth        ON block_issues        FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY block_issue_updates_anon ON block_issue_updates FOR ALL TO anon          USING (true) WITH CHECK (true);
CREATE POLICY block_issue_updates_auth ON block_issue_updates FOR ALL TO authenticated USING (true) WITH CHECK (true);
```

- [ ] **Step 2: Write the runner (DDL + storage bucket + storage RLS)**

Create `scripts/run-block-issues-migration.mjs`:

```js
import { readFileSync } from 'node:fs';
import pg from 'pg';

const CONN = 'postgresql://postgres.qwlagcriiyoflseduvvc:Hlfqdbi6wcM4Omsm@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres';
const SUPA = 'https://qwlagcriiyoflseduvvc.supabase.co';
const SVC  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE';

const client = new pg.Client({ connectionString: CONN });
await client.connect();
await client.query(readFileSync('supabase/block_issues_migration.sql', 'utf8'));
console.log('DDL applied.');

// storage bucket (public read; no MIME allowlist so future PDFs work; 10MB cap)
const bkt = await fetch(`${SUPA}/storage/v1/bucket`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${SVC}`, 'Content-Type': 'application/json', apikey: SVC },
  body: JSON.stringify({ id: 'crop-issue-photos', name: 'crop-issue-photos', public: true, file_size_limit: 10485760 })
});
console.log('bucket:', bkt.status, await bkt.text());

// storage WRITE RLS (public:true only governs READ — CLAUDE.md gotcha #10)
await client.query(`
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='crop_issue_photos_all') THEN
      CREATE POLICY crop_issue_photos_all ON storage.objects FOR ALL
        USING (bucket_id = 'crop-issue-photos') WITH CHECK (bucket_id = 'crop-issue-photos');
    END IF;
  END $$;`);
console.log('storage policy ensured.');
await client.end();
```

- [ ] **Step 3: Run the migration**

Run: `node scripts/run-block-issues-migration.mjs`
Expected: `DDL applied.` / `bucket: 200 …` (or `400 … already exists` if re-run — fine) / `storage policy ensured.`

- [ ] **Step 4: Verify tables + policies + bucket exist**

Run:
```bash
node -e "import('pg').then(async({default:pg})=>{const c=new pg.Client({connectionString:'postgresql://postgres.qwlagcriiyoflseduvvc:Hlfqdbi6wcM4Omsm@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres'});await c.connect();const t=await c.query(\"select table_name from information_schema.tables where table_name in ('block_issues','block_issue_updates')\");const p=await c.query(\"select policyname from pg_policies where tablename in ('block_issues','block_issue_updates','objects') and policyname like 'block_issue%' or policyname='crop_issue_photos_all'\");console.log('tables',t.rows.map(r=>r.table_name));console.log('policies',p.rows.map(r=>r.policyname));await c.end();})"
```
Expected: both table names + 5 policy names printed.

- [ ] **Step 5: Verify an anon round-trip (the exact path the browser uses)**

Run:
```bash
node -e "import('@supabase/supabase-js').then(async(m)=>{const sb=m.createClient('https://qwlagcriiyoflseduvvc.supabase.co','eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNDgxNDYsImV4cCI6MjA4NzkyNDE0Nn0.OJvzNykb_JjejFlWlEy7QUKJjL7bfiaQI0pPx62P5YA');const {data:blk}=await sb.from('pnd_blocks').select('id').limit(1);const {data,error}=await sb.from('block_issues').insert({block_id:blk[0].id,title:'__smoke__',severity:'watch',category:'Other',opened_by:'test'}).select();console.log('insert',error||data[0].id);const {data:u,error:ue}=await sb.from('block_issue_updates').insert({issue_id:data[0].id,note:'x'}).select();console.log('update',ue||u[0].id);await sb.from('block_issues').delete().eq('id',data[0].id);console.log('cleaned');})"
```
Expected: `insert <uuid>` / `update <uuid>` / `cleaned` (CASCADE removes the update row).

- [ ] **Step 6: Commit**

```bash
git add supabase/block_issues_migration.sql scripts/run-block-issues-migration.mjs
git commit -m "feat(watchlist): DB migration — block_issues + block_issue_updates + storage"
```

---

## Task 2: Data loaders, helpers, and photo upload in Crop Care

**Files:**
- Modify: `spraytracker.html` — add loaders near the other `loadX` functions (after `loadCropStatuses`, ~line 508); add helpers in the HELPERS section (~line 510); register loaders in `loadAll` (line 354) and `startAutoRefresh` (line 369).

- [ ] **Step 1: Add module-scoped state vars**

Find the top-of-script state declarations (search for `let blockCrops` near line 300-340) and add alongside them:

```js
let blockIssues = [];        // active + resolved issues
let issueUpdates = [];       // timeline updates for the open issue-detail
let wlSelectedIssueId = null;// which issue detail is open (null = list view)
let wlFlagPhotos = [];       // staged photo URLs during flag/add-update modal
const ISSUE_CATEGORIES = ['Pest','Disease','Nutrient','Water','Weather','Other'];
```

- [ ] **Step 2: Add loaders**

After `loadCropStatuses()` (line 508) add:

```js
async function loadBlockIssues() {
  const data = await sbQuery(sb.from("block_issues").select("*").order("opened_at", { ascending:false }));
  if(data) blockIssues = data;
}
async function loadIssueUpdates(issueId) {
  const data = await sbQuery(sb.from("block_issue_updates").select("*").eq("issue_id", issueId).order("created_at", { ascending:false }));
  issueUpdates = data || [];
}
```

- [ ] **Step 3: Add helpers**

In the HELPERS section (after line 508, before line 510 comment block) add:

```js
// A block's active issues (severity drives its badge). Critical outranks watch.
function activeIssuesForBlock(blockId) {
  return blockIssues.filter(i => i.block_id === blockId && i.status === 'active');
}
function blockFlagSeverity(blockId) {
  const act = activeIssuesForBlock(blockId);
  if(!act.length) return null;
  return act.some(i => i.severity === 'critical') ? 'critical' : 'watch';
}
function issueBadgeHtml(sev) {
  if(sev === 'critical') return '<span class="wl-badge wl-crit">CRITICAL</span>';
  if(sev === 'watch')    return '<span class="wl-badge wl-watch">WATCH</span>';
  return '';
}
// Jobs auto-pulled for an issue: same block, job date within [opened_at, resolved_at|now]
function jobsForIssue(issue) {
  const start = issue.opened_at;
  const end = issue.resolved_at || new Date().toISOString();
  return jobs.filter(j => {
    if(j.block_id !== issue.block_id) return false;
    const d = j.completion_date || j.planned_date;
    if(!d) return false;
    const iso = d.length <= 10 ? d + 'T00:00:00Z' : d;
    return iso >= start && iso <= end;
  });
}
```

- [ ] **Step 4: Add photo resize + upload helper (bucket `crop-issue-photos`)**

Add in the HELPERS section:

```js
// Resize to max 1200px JPEG q0.8, upload to crop-issue-photos, return public URL.
function ciResizeToBlob(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const maxW = 1200, scale = Math.min(1, maxW / img.width);
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * scale);
      c.height = Math.round(img.height * scale);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      c.toBlob(b => b ? resolve(b) : reject(new Error('toBlob failed')), 'image/jpeg', 0.8);
    };
    img.onerror = reject;
    img.src = URL.createObjectURL(file);
  });
}
async function ciUploadPhoto(issueId, file) {
  const blob = await ciResizeToBlob(file);
  const path = `issues/${issueId}/${Date.now()}.jpg`;
  const res = await sbUpload(() => sb.storage.from('crop-issue-photos').upload(path, blob, { contentType:'image/jpeg', upsert:true }), 'Uploading photo…');
  if(!res) return null;
  return sb.storage.from('crop-issue-photos').getPublicUrl(path).data.publicUrl;
}
```

- [ ] **Step 5: Register loaders in `loadAll` and `startAutoRefresh`**

In `loadAll` (line 354), append `, loadBlockIssues()` to the `Promise.all([...])`.

In `startAutoRefresh` (line 369), change the interval body's `Promise.all` to also include `loadBlockIssues()`, and add `if(currentPage === 'watchlist') renderWatchlist();` after the existing `if(currentPage===...)` lines.

- [ ] **Step 6: Verify parse**

Run the PARSE OK command from Conventions. Expected: `PARSE OK`.

- [ ] **Step 7: Commit**

```bash
git add spraytracker.html
git commit -m "feat(watchlist): loaders, helpers, photo upload in Crop Care"
```

---

## Task 3: Watchlist tab shell (nav item + page + router + back-nav)

**Files:**
- Modify: `spraytracker.html` — sidebar nav (after line 43, the Summary item), page container (after line 82 block / before `page-jobs` at 105), router `renderCurrentPage` (line 387), `navigateTo` back-nav restore (line 379).

- [ ] **Step 1: Add the nav item**

After the Summary `.nav-item` (closes at line 43) insert:

```html
    <div class="nav-item" data-page="watchlist" onclick="navigateTo('watchlist')">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
      <span class="nav-label">Watchlist</span>
    </div>
```

- [ ] **Step 2: Add the page container**

Immediately after the closing `</div>` of `#page-summary` (just before `<!-- PAGE: JOBS -->` at line 105) insert:

```html
<!-- PAGE: WATCHLIST -->
<div id="page-watchlist" class="page">
  <div id="watchlist-body"></div>
</div>
```

- [ ] **Step 3: Route it in `renderCurrentPage`**

In `renderCurrentPage` (line 387), add a branch before the `else if(currentPage === 'jobs')`:

```js
  else if(currentPage === 'watchlist') { await Promise.all([loadBlockIssues(), loadBlocks(), loadBlockCrops(), loadCropStatuses(), loadJobs(), loadProducts()]); renderWatchlist(); }
```

- [ ] **Step 4: Restore issue-detail on Browser-Back**

In `navigateTo(page, fromHistory)` (line 379), add a 3rd param and restore the detail id. Change the signature and body top:

```js
function navigateTo(page, fromHistory, detail) {
  currentPage = page;
  if(page === 'watchlist') wlSelectedIssueId = detail || null;
  document.querySelectorAll(".nav-item").forEach(n => n.classList.toggle("active", n.dataset.page === page));
  document.querySelectorAll(".page").forEach(p => p.classList.toggle("active", p.id === "page-"+page));
  if(!fromHistory) pushTab(page);
  renderCurrentPage();
}
```

(`initTabHistory(navigateTo, 'summary')` at line 346 already passes `(page, true, detail)` on popstate — no change needed there.)

- [ ] **Step 5: Verify parse + smoke**

Run PARSE OK. Then deploy is deferred; local check only.

- [ ] **Step 6: Commit**

```bash
git add spraytracker.html
git commit -m "feat(watchlist): tab shell, route, back-nav restore"
```

---

## Task 4: Watchlist list view (`renderWatchlist`)

**Files:**
- Modify: `spraytracker.html` — add `renderWatchlist()` + `renderWatchlistList()` in the SUMMARY/WATCHLIST area (after `renderSummary`, ~line 798).

- [ ] **Step 1: Add render functions**

```js
function renderWatchlist() {
  const body = document.getElementById('watchlist-body');
  if(!body) return;
  if(wlSelectedIssueId) { renderIssueDetail(); return; }
  renderWatchlistList(body);
}

function wlBlockLabel(blockId) {
  const b = blocks.find(x => x.id === blockId);
  const bc = getBlockCrop(blockId);
  const v = bc && bc.crop_varieties ? ` (${esc(bc.crop_varieties.name)})` : '';
  return (b ? esc(b.block_name) : '—') + v;
}

function wlIssueCard(i) {
  const jobsN = jobsForIssue(i).length;
  const days = Math.max(0, Math.round((Date.now() - new Date(i.opened_at).getTime())/86400000));
  const sevCls = i.severity === 'critical' ? 'wl-card-crit' : 'wl-card-watch';
  const meta = i.status === 'resolved'
    ? `Resolved ${fmtDate(i.resolved_at)}`
    : `Opened ${fmtDate(i.opened_at)} · ${days}d active · ${jobsN} job(s)`;
  return `<div class="wl-card ${i.status==='resolved'?'wl-card-resolved':sevCls}" data-issue="${i.id}" onclick="wlOpenIssue(event)">
    <div class="wl-card-top">
      ${issueBadgeHtml(i.status==='active'?i.severity:null)}
      <span class="wl-card-title">${esc(i.title)}</span>
      <span class="wl-cat">${esc(i.category)}</span>
    </div>
    <div class="wl-card-meta">${wlBlockLabel(i.block_id)} · ${meta}</div>
  </div>`;
}

function renderWatchlistList(body) {
  const active = blockIssues.filter(i => i.status === 'active');
  const crit = active.filter(i => i.severity === 'critical');
  const watch = active.filter(i => i.severity === 'watch');
  const resolved = blockIssues.filter(i => i.status === 'resolved');

  let html = `<div class="page-header"><h1>Watchlist</h1>
    <button class="btn btn-primary" onclick="openFlagModal()">⚑ Flag a Block</button></div>`;

  if(!active.length) {
    html += `<div class="empty-state" style="padding:32px;text-align:center;color:var(--text-muted);">No blocks flagged. When you spot a problem, hit <b>⚑ Flag a Block</b>.</div>`;
  } else {
    if(crit.length)  html += `<div class="wl-section-h wl-h-crit">🔴 Critical (${crit.length})</div>` + crit.map(wlIssueCard).join('');
    if(watch.length) html += `<div class="wl-section-h wl-h-watch">🟠 Watch (${watch.length})</div>` + watch.map(wlIssueCard).join('');
  }
  if(resolved.length) {
    html += `<div class="wl-section-h wl-h-resolved" onclick="wlToggleResolved()" style="cursor:pointer;">✓ Resolved (${resolved.length}) <span id="wl-resolved-caret">${wlResolvedOpen?'▾':'▸'}</span></div>`;
    html += `<div id="wl-resolved-list" style="display:${wlResolvedOpen?'block':'none'};">` + resolved.map(wlIssueCard).join('') + `</div>`;
  }
  body.innerHTML = html;
}

let wlResolvedOpen = false;
function wlToggleResolved() { wlResolvedOpen = !wlResolvedOpen; renderWatchlist(); }
function wlOpenIssue(ev) {
  const id = ev.currentTarget.dataset.issue;
  wlSelectedIssueId = id;
  pushView('watchlist', id);   // browser-back returns to the list
  renderWatchlist();
}
```

- [ ] **Step 2: Verify parse**

Run PARSE OK. Expected: `PARSE OK`.

- [ ] **Step 3: Commit**

```bash
git add spraytracker.html
git commit -m "feat(watchlist): list view grouped by severity + resolved history"
```

---

## Task 5: Flag modal + save

**Files:**
- Modify: `spraytracker.html` — add `openFlagModal`, `flagSetSeverity`, `flagSetCategory`, `ciStagePhoto`, `wlSaveFlag` after the watchlist render functions.

- [ ] **Step 1: Add the modal + handlers**

```js
let flagSeverity = 'critical', flagCategory = 'Pest';

function openFlagModal(preBlockId) {
  flagSeverity = 'critical'; flagCategory = 'Pest'; wlFlagPhotos = [];
  const opts = blocks.filter(b => b.is_active)
    .sort((a,b)=>(a.block_name||'').localeCompare(b.block_name||'',undefined,{numeric:true}))
    .map(b => `<option value="${b.id}" ${b.id===preBlockId?'selected':''}>${esc(b.block_name)}</option>`).join('');
  const chips = ISSUE_CATEGORIES.map(c => `<span class="wl-chip ${c==='Pest'?'on':''}" data-cat="${c}" onclick="flagSetCategory(event)">${c}</span>`).join('');
  document.getElementById("modal-container").innerHTML = `
    <div class="modal-overlay"><div class="modal-box" style="max-width:460px;">
      <div class="modal-header"><div class="modal-title">⚑ Flag a Block</div><button class="modal-close" onclick="closeModal()">✕</button></div>
      <div class="form-field"><label>Block</label><select id="flag-block" style="width:100%;">${opts}</select></div>
      <div class="form-field"><label>Severity</label>
        <div class="wl-sev-toggle">
          <div class="wl-sev crit on" data-sev="critical" onclick="flagSetSeverity(event)">🔴 Critical</div>
          <div class="wl-sev watch" data-sev="watch" onclick="flagSetSeverity(event)">🟠 Watch</div>
        </div>
      </div>
      <div class="form-field"><label>Category</label><div class="wl-chips" id="flag-cats">${chips}</div></div>
      <div class="form-field"><label>Short title</label><input id="flag-title" style="width:100%;" placeholder="e.g. Mealybug, north corner"></div>
      <div class="form-field"><label>Description (optional)</label><textarea id="flag-desc" style="width:100%;min-height:56px;" placeholder="What did you see?"></textarea></div>
      <div class="form-field"><label>Photos</label>
        <input type="file" id="flag-photo-input" accept="image/*" multiple style="display:none;" onchange="ciStagePhoto(event,'flag-photo-preview')">
        <button class="btn btn-outline" onclick="document.getElementById('flag-photo-input').click()">📷 Add Photo</button>
        <div id="flag-photo-preview" class="wl-photo-preview"></div>
      </div>
      <div class="modal-footer"><button class="btn btn-outline" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" onclick="wlSaveFlag()">⚑ Flag Block</button></div>
    </div></div>`;
}
function flagSetSeverity(ev) {
  flagSeverity = ev.currentTarget.dataset.sev;
  document.querySelectorAll('.wl-sev').forEach(e => e.classList.toggle('on', e.dataset.sev === flagSeverity));
}
function flagSetCategory(ev) {
  flagCategory = ev.currentTarget.dataset.cat;
  document.querySelectorAll('#flag-cats .wl-chip').forEach(e => e.classList.toggle('on', e.dataset.cat === flagCategory));
}
// stage photos: uploads immediately to a temp path, renders thumbnails. Uses a synthetic id until the issue exists.
let ciStageKey = null;
async function ciStagePhoto(ev, previewId) {
  const files = [...ev.target.files]; ev.target.value = '';
  if(!ciStageKey) ciStageKey = 'stage-' + Date.now();
  for(const f of files) {
    const url = await ciUploadPhoto(ciStageKey, f);
    if(url) wlFlagPhotos.push(url);
  }
  const prev = document.getElementById(previewId);
  if(prev) prev.innerHTML = wlFlagPhotos.map(u => `<img src="${u}" class="wl-thumb">`).join('');
}
async function wlSaveFlag() {
  const blockId = document.getElementById('flag-block').value;
  const title = document.getElementById('flag-title').value.trim();
  if(!blockId) { notify('Pick a block','error'); return; }
  if(!title)   { notify('Enter a short title','error'); return; }
  const payload = {
    block_id: blockId, title, description: document.getElementById('flag-desc').value.trim() || null,
    category: flagCategory, severity: flagSeverity, status: 'active',
    opened_by: currentUser.displayName || 'unknown', company_id: 'tg_agribusiness'
  };
  const res = await sbMutate(() => sb.from('block_issues').insert(payload).select());
  if(!res || !res[0]) { notify('Could not save flag','error'); return; }
  const issue = res[0];
  if(wlFlagPhotos.length) {
    await sbMutate(() => sb.from('block_issue_updates').insert({
      issue_id: issue.id, note: 'Issue opened', photos: wlFlagPhotos, created_by: currentUser.displayName || 'unknown'
    }).select());
  }
  wlFlagPhotos = []; ciStageKey = null;
  closeModal();
  await loadBlockIssues();
  notify('Block flagged','success');
  renderCurrentPage();  // refreshes whatever tab you flagged from (watchlist or summary)
}
```

- [ ] **Step 2: Verify parse**

Run PARSE OK. Expected: `PARSE OK`.

- [ ] **Step 3: Commit**

```bash
git add spraytracker.html
git commit -m "feat(watchlist): flag modal + save with photo upload"
```

---

## Task 6: Issue detail + timeline + Add Update + Resolve

**Files:**
- Modify: `spraytracker.html` — add `renderIssueDetail`, `wlBackToList`, `openAddUpdateModal`, `wlSaveUpdate`, `wlResolveIssue`.

- [ ] **Step 1: Add issue-detail render (merges updates + auto-pulled jobs, newest first)**

```js
function renderIssueDetail() {
  const body = document.getElementById('watchlist-body');
  const i = blockIssues.find(x => x.id === wlSelectedIssueId);
  if(!i) { wlSelectedIssueId = null; renderWatchlist(); return; }

  // fetch updates (async) then paint
  loadIssueUpdates(i.id).then(() => paintIssueDetail(i, body));
  body.innerHTML = `<div class="empty-state" style="padding:24px;color:var(--text-muted);">Loading…</div>`;
}

function paintIssueDetail(i, body) {
  const days = Math.max(0, Math.round((Date.now() - new Date(i.opened_at).getTime())/86400000));
  const sevBadge = issueBadgeHtml(i.status==='active'?i.severity:null);
  const statusPill = i.status==='resolved'
    ? `<span class="wl-status-resolved">✓ Resolved</span>`
    : `<span class="wl-status-active">● Active</span>`;

  // build timeline events
  const events = [];
  issueUpdates.forEach(u => events.push({ ts:u.created_at, kind:'note', u }));
  jobsForIssue(i).forEach(j => events.push({ ts:(j.completion_date||j.planned_date), kind:'job', j }));
  events.push({ ts:i.opened_at, kind:'open' });
  events.sort((a,b) => (b.ts>a.ts?1:b.ts<a.ts?-1:0));  // newest first

  const evHtml = events.map(e => {
    if(e.kind === 'note') {
      const photos = (e.u.photos||[]).map(u => `<img src="${u}" class="wl-mini">`).join('');
      return `<div class="wl-ev"><div class="wl-dot wl-dot-note">📝</div><div class="wl-ev-body">
        <div class="wl-ev-top"><span class="wl-ev-title">${esc(e.u.created_by||'—')}</span><span class="wl-ev-date">${fmtDate(e.u.created_at)}</span></div>
        <div class="wl-ev-text">${esc(e.u.note)}</div>${photos?`<div>${photos}</div>`:''}</div></div>`;
    }
    if(e.kind === 'job') {
      const p = getProduct(e.j.product_id);
      const pname = p ? esc(p.product_name) : (e.j.job_type==='Fertilizer' ? 'Fertilizer' : '—');
      const worker = e.j.worker_name ? ` · ${esc(e.j.worker_name)}` : '';
      const done = e.j.completion_date ? 'done' : 'planned';
      return `<div class="wl-ev"><div class="wl-dot wl-dot-job">🌫</div><div class="wl-ev-body">
        <div class="wl-ev-top"><span class="wl-ev-title">${pname}</span><span class="wl-job-tag">Job · from Crop Care</span><span class="wl-ev-date">${fmtDate(e.j.completion_date||e.j.planned_date)}</span></div>
        <div class="wl-ev-sub">${esc(e.j.job_type||'')} · ${done}${worker}</div></div></div>`;
    }
    return `<div class="wl-ev"><div class="wl-dot wl-dot-open">🚩</div><div class="wl-ev-body">
      <div class="wl-ev-top"><span class="wl-ev-title">Issue opened — ${esc(i.opened_by||'—')}</span><span class="wl-ev-date">${fmtDate(i.opened_at)}</span></div>
      <div class="wl-ev-text">${esc(i.title)}${i.description?' — '+esc(i.description):''}</div></div></div>`;
  }).join('');

  const actions = i.status==='active'
    ? `<button class="btn btn-primary" onclick="openAddUpdateModal()">＋ Add Update</button>
       <button class="btn btn-success" onclick="wlResolveIssue()">✓ Mark Resolved</button>`
    : `<div class="wl-resolved-note">Resolved ${fmtDate(i.resolved_at)}${i.resolved_note?': '+esc(i.resolved_note):''}</div>`;

  body.innerHTML = `
    <div class="wl-detail-head ${i.severity==='critical'&&i.status==='active'?'wl-hd-crit':i.status==='active'?'wl-hd-watch':'wl-hd-resolved'}">
      <button class="btn btn-outline btn-sm" onclick="wlBackToList()">← Watchlist</button>
      <div class="wl-detail-top">${sevBadge}<span class="wl-detail-title">${esc(i.title)}</span><span class="wl-cat">${esc(i.category)}</span>${statusPill}</div>
      <div class="wl-detail-meta">Block <b>${wlBlockLabel(i.block_id)}</b> · Opened ${fmtDate(i.opened_at)} by ${esc(i.opened_by||'—')} · ${days}d active</div>
      ${i.description?`<div class="wl-detail-desc">${esc(i.description)}</div>`:''}
    </div>
    <div class="wl-detail-actions">${actions}</div>
    <div class="wl-timeline"><div class="wl-tl-h">Timeline — newest first</div>${evHtml}</div>`;
}

function wlBackToList() { wlSelectedIssueId = null; pushView('watchlist', null); renderWatchlist(); }
```

- [ ] **Step 2: Add Update modal + save**

```js
function openAddUpdateModal() {
  wlFlagPhotos = []; ciStageKey = null;
  document.getElementById("modal-container").innerHTML = `
    <div class="modal-overlay"><div class="modal-box" style="max-width:440px;">
      <div class="modal-header"><div class="modal-title">＋ Add Update</div><button class="modal-close" onclick="closeModal()">✕</button></div>
      <div class="form-field"><label>Observation</label><textarea id="upd-note" style="width:100%;min-height:70px;" placeholder="e.g. Still spreading / responding to treatment"></textarea></div>
      <div class="form-field"><label>Photos</label>
        <input type="file" id="upd-photo-input" accept="image/*" multiple style="display:none;" onchange="ciStagePhoto(event,'upd-photo-preview')">
        <button class="btn btn-outline" onclick="document.getElementById('upd-photo-input').click()">📷 Add Photo</button>
        <div id="upd-photo-preview" class="wl-photo-preview"></div>
      </div>
      <div class="modal-footer"><button class="btn btn-outline" onclick="closeModal()">Cancel</button>
        <button class="btn btn-primary" onclick="wlSaveUpdate()">Save Update</button></div>
    </div></div>`;
}
async function wlSaveUpdate() {
  const note = document.getElementById('upd-note').value.trim();
  if(!note && !wlFlagPhotos.length) { notify('Add a note or photo','error'); return; }
  const res = await sbMutate(() => sb.from('block_issue_updates').insert({
    issue_id: wlSelectedIssueId, note: note || '(photo)', photos: wlFlagPhotos, created_by: currentUser.displayName || 'unknown'
  }).select());
  if(!res) { notify('Could not save update','error'); return; }
  wlFlagPhotos = []; ciStageKey = null;
  closeModal();
  renderWatchlist();  // re-paints detail (loadIssueUpdates re-fetches)
  notify('Update added','success');
}
```

- [ ] **Step 3: Resolve**

```js
function wlResolveIssue() {
  confirmAction('Mark Resolved', 'Close this issue? The block\'s badge clears everywhere; history is kept.', async () => {
    const note = prompt('Closing note (optional):') || null;
    const res = await sbMutate(() => sb.from('block_issues').update({
      status:'resolved', resolved_at: new Date().toISOString(), resolved_note: note
    }).eq('id', wlSelectedIssueId).select());
    if(!res) { notify('Could not resolve','error'); return; }
    await loadBlockIssues();
    notify('Issue resolved','success');
    renderWatchlist();
  }, false);
}
```

- [ ] **Step 4: Verify parse**

Run PARSE OK. Expected: `PARSE OK`.

- [ ] **Step 5: Commit**

```bash
git add spraytracker.html
git commit -m "feat(watchlist): issue detail, timeline, add-update, resolve"
```

---

## Task 7: Summary badges, banner, and ⚑ row shortcut

**Files:**
- Modify: `spraytracker.html` — `renderSummary` block cell (line 761) + banner above table (line 743).

- [ ] **Step 1: Add the attention banner above the matrix**

In `renderSummary`, right before `let html = '<div class="data-table">…'` (line 743), compute the banner:

```js
  const flaggedActive = blockIssues.filter(i => i.status === 'active');
  const critN = flaggedActive.filter(i => i.severity === 'critical').length;
  const watchN = flaggedActive.filter(i => i.severity === 'watch').length;
  let bannerHtml = '';
  if(flaggedActive.length) {
    bannerHtml = `<div class="wl-banner" onclick="navigateTo('watchlist')">⚠ ${flaggedActive.length} block(s) need attention — ${critN} Critical, ${watchN} Watch</div>`;
  }
```

Then change the `let html = '<div class="data-table">…` line to prepend the banner:

```js
  let html = bannerHtml + '<div class="data-table"><div class="table-wrap"><table style="white-space:nowrap;"><thead>';
```

- [ ] **Step 2: Add ⚑ icon + severity badge + tint in the block cell**

Replace the row-open + block-cell. Find (lines 759-762):

```js
    rowBlocks.forEach(({block, statusName, variety}) => {
      html += '<tr>';
      html += `<td style="position:sticky;left:0;background:var(--bg-card);z-index:1;font-weight:600;white-space:nowrap;">${esc(block.block_name)}${variety ? ` <span style="font-weight:400;color:var(--text-dim);">(${esc(variety)})</span>` : ''}` +
              `<div style="font-size:10px;color:var(--text-dim);font-weight:400;">${esc(statusName)}</div></td>`;
```

Replace with:

```js
    rowBlocks.forEach(({block, statusName, variety}) => {
      const sev = blockFlagSeverity(block.id);
      html += `<tr class="${sev==='critical'?'wl-row-crit':sev==='watch'?'wl-row-watch':''}">`;
      const flagIco = `<span class="wl-flag-ico" data-block="${block.id}" title="Flag this block" onclick="wlFlagIcoClick(event)">⚑</span>`;
      html += `<td style="position:sticky;left:0;background:var(--bg-card);z-index:1;font-weight:600;white-space:nowrap;">${flagIco} ${esc(block.block_name)}${variety ? ` <span style="font-weight:400;color:var(--text-dim);">(${esc(variety)})</span>` : ''} ${issueBadgeHtml(sev)}` +
              `<div style="font-size:10px;color:var(--text-dim);font-weight:400;">${esc(statusName)}</div></td>`;
```

- [ ] **Step 3: Add the ⚑ click handler**

Add near the other summary helpers (after `renderSummary`):

```js
function wlFlagIcoClick(ev) {
  ev.stopPropagation();  // don't trigger cell drill-down
  openFlagModal(ev.currentTarget.dataset.block);
}
```

- [ ] **Step 4: Verify parse**

Run PARSE OK. Expected: `PARSE OK`.

- [ ] **Step 5: Commit**

```bash
git add spraytracker.html
git commit -m "feat(watchlist): summary banner, row badges/tint, flag shortcut"
```

---

## Task 8: CSS for Crop Care watchlist styles

**Files:**
- Modify: `spraytracker.css` — append a `WATCHLIST` block.

- [ ] **Step 1: Append styles**

```css
/* ===== WATCHLIST ===== */
.wl-banner { background:rgba(192,57,43,.10); border:1px solid rgba(192,57,43,.35); border-left:4px solid #C0392B; border-radius:8px; padding:10px 14px; margin-bottom:14px; font-size:13px; font-weight:600; color:#C0392B; cursor:pointer; }
.wl-flag-ico { display:inline-flex; align-items:center; justify-content:center; width:22px; height:22px; border:1px solid var(--border); border-radius:5px; color:#C9BCD6; cursor:pointer; font-size:12px; vertical-align:middle; }
.wl-flag-ico:hover { color:#C0392B; border-color:#C0392B; background:rgba(192,57,43,.06); }
.wl-badge { font-size:9px; font-weight:700; padding:2px 6px; border-radius:4px; color:#fff; letter-spacing:.03em; }
.wl-crit { background:#C0392B; } .wl-watch { background:#E88A1A; }
.wl-row-crit td { background:rgba(192,57,43,.05) !important; }
.wl-row-watch td { background:rgba(232,138,26,.05) !important; }

.wl-section-h { font-size:13px; font-weight:700; margin:18px 0 8px; }
.wl-h-crit { color:#C0392B; } .wl-h-watch { color:#C77A15; } .wl-h-resolved { color:var(--text-muted); }
.wl-card { background:var(--bg-card); border:1px solid var(--border); border-left:4px solid var(--border); border-radius:9px; padding:12px 14px; margin-bottom:8px; cursor:pointer; }
.wl-card-crit { border-left-color:#C0392B; } .wl-card-watch { border-left-color:#E88A1A; } .wl-card-resolved { opacity:.7; }
.wl-card:hover { box-shadow:0 2px 8px rgba(0,0,0,.08); }
.wl-card-top { display:flex; align-items:center; gap:9px; flex-wrap:wrap; }
.wl-card-title { font-weight:700; font-size:14px; }
.wl-cat { background:var(--bg-input,#F0EAF6); color:var(--text-dim); font-size:11px; font-weight:600; padding:2px 9px; border-radius:20px; }
.wl-card-meta { font-size:12px; color:var(--text-muted); margin-top:5px; }

.wl-sev-toggle { display:flex; gap:10px; }
.wl-sev { flex:1; border:2px solid var(--border); border-radius:9px; padding:9px; text-align:center; cursor:pointer; font-weight:700; font-size:13px; color:var(--text-dim); }
.wl-sev.crit.on { border-color:#C0392B; background:rgba(192,57,43,.08); color:#C0392B; }
.wl-sev.watch.on { border-color:#E88A1A; background:rgba(232,138,26,.10); color:#C77A15; }
.wl-chips { display:flex; flex-wrap:wrap; gap:7px; }
.wl-chip { border:1px solid var(--border); border-radius:20px; padding:6px 13px; font-size:12px; cursor:pointer; color:var(--text-dim); }
.wl-chip.on { background:var(--purple,#6B4C8A); color:#fff; border-color:var(--purple,#6B4C8A); }
.wl-photo-preview { display:flex; gap:8px; flex-wrap:wrap; margin-top:8px; }
.wl-thumb { width:60px; height:60px; object-fit:cover; border-radius:8px; }

.wl-detail-head { padding:16px 18px; border:1px solid var(--border); border-left:5px solid var(--border); border-radius:11px; margin-bottom:12px; }
.wl-hd-crit { border-left-color:#C0392B; } .wl-hd-watch { border-left-color:#E88A1A; } .wl-hd-resolved { border-left-color:#3B7A3B; }
.wl-detail-top { display:flex; align-items:center; gap:9px; flex-wrap:wrap; margin:8px 0 6px; }
.wl-detail-title { font-size:17px; font-weight:700; }
.wl-status-active { background:rgba(232,138,26,.15); color:#C77A15; font-size:11px; font-weight:700; padding:3px 9px; border-radius:20px; }
.wl-status-resolved { background:rgba(59,122,59,.15); color:#3B7A3B; font-size:11px; font-weight:700; padding:3px 9px; border-radius:20px; }
.wl-detail-meta { font-size:12px; color:var(--text-muted); }
.wl-detail-desc { margin-top:9px; font-size:13px; line-height:1.5; }
.wl-detail-actions { display:flex; gap:10px; margin-bottom:14px; }
.wl-resolved-note { font-size:13px; color:#3B7A3B; padding:8px 0; }
.wl-timeline { background:var(--bg-card); border:1px solid var(--border); border-radius:11px; padding:8px 18px 18px; }
.wl-tl-h { font-size:11px; text-transform:uppercase; letter-spacing:.04em; color:var(--text-muted); font-weight:700; margin:14px 0 4px; }
.wl-ev { display:flex; gap:13px; padding:13px 0; border-bottom:1px solid var(--border); }
.wl-ev:last-child { border-bottom:none; }
.wl-dot { flex:0 0 auto; width:32px; height:32px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:14px; }
.wl-dot-note { background:rgba(107,76,138,.14); } .wl-dot-job { background:rgba(59,122,59,.15); } .wl-dot-open { background:rgba(192,57,43,.12); }
.wl-ev-body { flex:1; }
.wl-ev-top { display:flex; align-items:center; gap:8px; margin-bottom:3px; }
.wl-ev-title { font-weight:600; font-size:13.5px; }
.wl-ev-date { font-size:11px; color:var(--text-muted); margin-left:auto; }
.wl-job-tag { background:rgba(59,122,59,.13); color:#3B7A3B; font-size:9.5px; font-weight:700; padding:2px 7px; border-radius:4px; text-transform:uppercase; }
.wl-ev-text { font-size:13px; line-height:1.45; }
.wl-ev-sub { font-size:12px; color:var(--text-muted); margin-top:2px; }
.wl-mini { width:46px; height:46px; object-fit:cover; border-radius:6px; margin:8px 6px 0 0; }
```

- [ ] **Step 2: Deploy + browser smoke test**

Deploy (command in Conventions). Then in the browser (logged in as admin), open Crop Care → Watchlist → Flag a Block → fill N-something, Critical, Pest, title, one photo → Flag Block. Confirm: card appears under Critical, block shows red badge + ⚑ + tint on Summary, banner shows. Open the issue → Add Update with a photo → appears newest-first; a recent job on that block appears as a green "from Crop Care" row. Mark Resolved → badge clears, moves to Resolved history.

- [ ] **Step 3: Commit**

```bash
git add spraytracker.css
git commit -m "feat(watchlist): styles for badges, cards, flag modal, timeline"
```

---

## Task 9: Growth Tracker read-only badge + banner

**Files:**
- Modify: `growthtracker.html` — add a `loadBlockIssues` loader + register in `loadAll` (line 267-294 area); add badge in the Block column render (line 684-697) + banner above the table (line 684 area).

- [ ] **Step 1: Add loader + state**

Near the other `let` state vars add `let blockIssues = [];`. After the `loadAll` sources, add a loader:

```js
async function loadBlockIssues() {
  const data = await sbQuery(sb.from("block_issues").select("block_id,severity,status").eq("status","active"));
  blockIssues = data || [];
}
```

Register `loadBlockIssues()` in the `Promise.all` inside `loadAll()`.

- [ ] **Step 2: Add helper + badge in the Block cell**

Add helper:

```js
function gtBlockSeverity(blockId) {
  const a = blockIssues.filter(i => i.block_id === blockId);
  if(!a.length) return null;
  return a.some(i => i.severity === 'critical') ? 'critical' : 'watch';
}
function gtIssueBadge(sev) {
  if(sev==='critical') return ' <span style="background:#C0392B;color:#fff;font-size:9px;font-weight:700;padding:2px 6px;border-radius:4px;">CRITICAL</span>';
  if(sev==='watch')    return ' <span style="background:#E88A1A;color:#fff;font-size:9px;font-weight:700;padding:2px 6px;border-radius:4px;">WATCH</span>';
  return '';
}
```

In the table-body render (line 684-697), find where the Block name cell is emitted and append the badge. The row uses `r.block_id`/`r.block_name`; append `${gtIssueBadge(gtBlockSeverity(r.block_id))}` right after the block name text in that `<td>`.

- [ ] **Step 3: Add banner above the table**

In `renderOverview`, right before the table HTML is assembled, compute:

```js
  const flg = blockIssues.length;
  const critN = blockIssues.filter(i=>i.severity==='critical').length;
  const bannerHtml = flg ? `<div style="background:rgba(192,57,43,.10);border:1px solid rgba(192,57,43,.35);border-left:4px solid #C0392B;border-radius:8px;padding:10px 14px;margin-bottom:14px;font-size:13px;font-weight:600;color:#C0392B;">⚠ ${flg} block(s) flagged in Crop Care — ${critN} Critical. Manage in Crop Care → Watchlist.</div>` : '';
```

Prepend `bannerHtml` to the table's container HTML string.

- [ ] **Step 4: Verify parse (growthtracker) + deploy + smoke**

Run the PARSE OK command with `growthtracker.html` substituted. Deploy. In the browser, open Growth Tracker → confirm the flagged block shows the badge + the banner appears. (Read-only — no flag controls here.)

- [ ] **Step 5: Commit**

```bash
git add growthtracker.html
git commit -m "feat(watchlist): Growth Tracker read-only flag badge + banner"
```

---

## Task 10: Hub count badge on the Crop Care card

**Files:**
- Modify: `index.html` — where module cards render, add an async count of active issues and a badge on the `spraytracker` card.

- [ ] **Step 1: Find the card render + module key**

Search `index.html` for the `spraytracker` MODULES entry and the `renderModuleCards()` function. Identify where a single card's HTML is built (it has the icon + name + desc).

- [ ] **Step 2: Fetch the active-issue count once at load**

Add a global + a fetch in the hub's init (after Supabase is ready, near where other counts/overview load):

```js
let cropCareFlagCount = 0;
async function loadCropCareFlags() {
  const { data } = await sb.from('block_issues').select('id').eq('status','active');
  cropCareFlagCount = (data || []).length;
}
```

Call `await loadCropCareFlags();` in the hub init before `renderModuleCards()`.

- [ ] **Step 3: Render the badge on the Crop Care card**

In the card-building code, when the module key is `spraytracker` and `cropCareFlagCount > 0`, append a red badge to the card HTML:

```js
      const flagBadge = (m.key === 'spraytracker' && cropCareFlagCount > 0)
        ? `<span style="position:absolute;top:10px;right:10px;background:#C0392B;color:#fff;font-size:11px;font-weight:700;padding:2px 8px;border-radius:20px;">⚠ ${cropCareFlagCount}</span>` : '';
```

Insert `${flagBadge}` into the card's inner HTML (the card wrapper needs `position:relative;` — most module cards already are; if not, add it to the card style).

- [ ] **Step 4: Verify parse (index.html) + deploy + smoke**

Run PARSE OK with `index.html`. Deploy. Open the hub as admin → the Crop Care ("Pineapple Crop Care") card shows `⚠ N` when active issues exist. Resolve all → badge disappears on next load.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat(watchlist): hub count badge on Crop Care card"
```

---

## Task 11: Final verification + CLAUDE.md changelog

**Files:**
- Modify: `CLAUDE.md` — add a changelog entry.

- [ ] **Step 1: Full live verification (curl-grep)**

After the final deploy, run:
```bash
curl -s https://tgfarmhub.com/spraytracker.html | grep -c "renderWatchlist\|openFlagModal\|jobsForIssue\|block_issues"
curl -s https://tgfarmhub.com/growthtracker.html | grep -c "gtBlockSeverity\|block_issues"
curl -s https://tgfarmhub.com/index.html | grep -c "cropCareFlagCount"
```
Expected: non-zero counts for each.

- [ ] **Step 2: DB sanity**

Confirm a flag created via the live UI persisted:
```bash
node -e "import('pg').then(async({default:pg})=>{const c=new pg.Client({connectionString:'postgresql://postgres.qwlagcriiyoflseduvvc:Hlfqdbi6wcM4Omsm@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres'});await c.connect();const r=await c.query('select count(*) from block_issues');console.log('issues',r.rows[0].count);await c.end();})"
```

- [ ] **Step 3: Add CLAUDE.md changelog entry**

Add a dated section documenting: the two new tables, the `crop-issue-photos` bucket + RLS, the Watchlist tab, auto-pull-jobs-by-block-and-window (no tagging), read-only surfacing in Growth Tracker + Hub, and the parked Telegram alert. Note the gotchas that bit (if any) during build.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): record Block Watchlist feature"
```

---

## Self-Review Notes (coverage vs spec)
- Flag entry points (button + ⚑ row) → Tasks 4, 5, 7. ✓
- Flag form fields (block/severity/category/title/desc/photos) → Task 5. ✓
- Two tables + no job schema change + auto-pull by block+window → Tasks 1, 2, 6. ✓
- Photo bucket + WRITE RLS → Task 1; resize/upload → Task 2. ✓
- Monitoring timeline newest-first, updates + jobs interleaved → Task 6. ✓
- Active→Resolved lifecycle + history → Tasks 4, 6. ✓
- Attention layer: Summary banner+badge+tint, Growth badge+banner, Hub badge → Tasks 7, 9, 10. ✓
- Back-nav for tab + issue detail → Tasks 3, 4, 6. ✓
- Parked: Telegram, job-tagging, weed jobs, TV, reports → not built (correct). ✓
