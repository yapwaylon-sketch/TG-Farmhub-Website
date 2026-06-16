# Fertilizer as a Job Type — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a fertilizer round a first-class job (`pnd_jobs.job_type='Fertilizer'`) with the same Planned→Completed lifecycle as a spray, created from the New Job "Job Type" dropdown, visible in the Jobs list + Job Logs (filterable by Type), and feeding the Crop Care matrix — retiring the separate Fertilizer tab + `pnd_fertilizer_applications` table built earlier today.

**Architecture:** Fertilizer becomes a row in the existing `pnd_jobs` table with spray-only columns left null and three new fertilizer columns (`inventory_product_id`, `fertilizer_quantity`, `fertilizer_quantity_unit`). The spray UI (New Job, Jobs list, Job Logs, completion) branches on `job_type==='Fertilizer'` to a small set of dedicated fertilizer functions/modal, so spray internals stay untouched. Fertilizer jobs carry `triggers_countdown=false` so the auto-spray-log trigger never fires for them (plus a defensive guard in the trigger). The matrix's Fertilizer column reads completed fertilizer jobs instead of the retired table.

**Tech Stack:** Static HTML/CSS/vanilla JS (no build, no test framework). Supabase (PostgREST + RLS). Node `pg` for migrations. Netlify CLI deploy. Verification = `node` pg scripts, inline-script `node --check`, browser DevTools, `curl`-grep live.

**Conventions (from CLAUDE.md):** `sb`/`esc`/`notify`/`fmtDate`/`fmtDateShort`/`fmtNum` from shared.js (never redeclare). Mutations: `sbQuery(sb.from(...).insert(...).select())` (spraytracker uses sbQuery, not sbMutate). `closeModal()` clears `#modal-container`. Modals injected as innerHTML into `#modal-container`. `esc()` doesn't escape quotes → use `data-*` + event delegation. `pnd_jobs`/`pnd_spray_logs` HAVE `company_id`; `pnd_blocks` does NOT. Granular fertilizer products live in inventory `products` (category `Granular Fertilizer`), NOT in `pnd_products`.

**Underlying values vs display labels:** keep `job_type` DB values `'Scheduled'`, `'Intervention'`, `'Fertilizer'`. Display labels are "Scheduled Spray", "Intervention Spray", "Fertilizer Application" (dropdowns) / "Fertilizer" (badge/filter). Do NOT rename the underlying 'Scheduled'/'Intervention' values — lots of code keys on them.

Line numbers drift as edits land — match on quoted code, not numbers.

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `supabase/fertilizer_as_job_migration.sql` | Create | Reference copy of DB migration (job_type widen, nullable spray cols, new cols, trigger guard, drop old table). |
| `spraytracker.html` | Modify | New Job dropdown + fertilizer branch, Jobs/Job Logs fertilizer rows + Type filter, dedicated fertilizer edit/complete modal, matrix source swap, retire Fertilizer tab + fert* code. |

---

## Task 1: DB migration

**Files:** Create `supabase/fertilizer_as_job_migration.sql`; apply via temp Node script.

- [ ] **Step 1: Write the migration SQL**

Create `supabase/fertilizer_as_job_migration.sql`:

```sql
-- Fertilizer as a job type (2026-06-16)

-- 1. Allow 'Fertilizer' job_type
ALTER TABLE public.pnd_jobs DROP CONSTRAINT IF EXISTS pnd_jobs_job_type_check;
ALTER TABLE public.pnd_jobs ADD CONSTRAINT pnd_jobs_job_type_check
  CHECK (job_type = ANY (ARRAY['Scheduled','Intervention','Fertilizer']));

-- 2. Spray-only columns become nullable (fertilizer jobs leave them null;
--    existing spray jobs still populate them). Their >0 / enum CHECKs pass on NULL.
ALTER TABLE public.pnd_jobs ALTER COLUMN tank_size_litres DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN tanks_planned   DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN dose_amount     DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN dose_unit       DROP NOT NULL;
ALTER TABLE public.pnd_jobs ALTER COLUMN dose_per_litres DROP NOT NULL;

-- 3. Fertilizer-specific columns
ALTER TABLE public.pnd_jobs ADD COLUMN IF NOT EXISTS inventory_product_id text REFERENCES public.products(id);
ALTER TABLE public.pnd_jobs ADD COLUMN IF NOT EXISTS fertilizer_quantity numeric;
ALTER TABLE public.pnd_jobs ADD COLUMN IF NOT EXISTS fertilizer_quantity_unit text;

-- 4. Defensive guard: the auto-spray-log trigger must never fire for fertilizer jobs.
--    (They also carry triggers_countdown=false, so this is belt-and-suspenders.)
CREATE OR REPLACE FUNCTION public.pnd_jobs_auto_spray_log()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF COALESCE(NEW.job_type,'') = 'Fertilizer' THEN
    RETURN NEW;
  END IF;
  IF (NEW.status = 'Completed' AND OLD.status != 'Completed' AND NEW.triggers_countdown = true) OR
     (NEW.status = 'Partially Completed' AND NEW.triggers_countdown = true
      AND (OLD.status != 'Partially Completed' OR OLD.triggers_countdown IS DISTINCT FROM true))
  THEN
    IF NOT EXISTS (
      SELECT 1 FROM pnd_spray_logs
      WHERE block_id = NEW.block_id
        AND product_id = NEW.product_id
        AND date_completed = NEW.completion_date
        AND logged_by = 'auto:job:' || NEW.id::text
    ) THEN
      INSERT INTO pnd_spray_logs (
        block_id, product_id, date_completed, next_spray_date, notes, logged_by
      ) VALUES (
        NEW.block_id, NEW.product_id, NEW.completion_date, NEW.next_spray_date,
        'Auto-logged from Job ID: ' || NEW.id::text,
        'auto:job:' || NEW.id::text
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- 5. Retire the separate fertilizer table built earlier today (unused, 0 rows).
DROP TABLE IF EXISTS public.pnd_fertilizer_applications CASCADE;
```

- [ ] **Step 2: Apply + verify**

Create `_migrate2.js` (delete after):

```js
const fs=require('fs'); const { Client }=require('pg');
const c=new Client({host:'aws-1-ap-northeast-1.pooler.supabase.com',port:5432,user:'postgres.qwlagcriiyoflseduvvc',password:'Hlfqdbi6wcM4Omsm',database:'postgres',ssl:{rejectUnauthorized:false}});
(async()=>{ await c.connect();
  await c.query(fs.readFileSync('supabase/fertilizer_as_job_migration.sql','utf8'));
  console.log('applied');
  const con=await c.query(`SELECT pg_get_constraintdef(oid) d FROM pg_constraint WHERE conname='pnd_jobs_job_type_check'`);
  console.log('job_type CHECK:', con.rows[0].d);
  const cols=await c.query(`SELECT column_name,is_nullable FROM information_schema.columns WHERE table_name='pnd_jobs' AND column_name IN ('tank_size_litres','tanks_planned','dose_amount','dose_unit','dose_per_litres','inventory_product_id','fertilizer_quantity','fertilizer_quantity_unit') ORDER BY column_name`);
  cols.rows.forEach(r=>console.log(`  ${r.column_name}: nullable=${r.is_nullable}`));
  const t=await c.query(`SELECT to_regclass('public.pnd_fertilizer_applications') x`); console.log('old table dropped:', t.rows[0].x===null);
  await c.end();
})().catch(e=>{console.error('ERR',e.message);process.exit(1);});
```

Run: `cd "C:/dev/TG-Farmhub-Website" && node _migrate2.js && rm -f _migrate2.js`
Expected: `applied`; job_type CHECK includes `Fertilizer`; the 5 spray cols `nullable=YES`; the 3 new cols present `nullable=YES`; `old table dropped: true`.

- [ ] **Step 3: Commit**

```bash
git add supabase/fertilizer_as_job_migration.sql
git commit -m "feat(spray): DB migration — Fertilizer job_type, nullable spray cols, trigger guard, drop old table" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: New Job modal — Job Type dropdown + fertilizer fields

**Files:** Modify `spraytracker.html` (`openNewJobModal` ~line 1487; `njSetJobType` ~line 1730).

- [ ] **Step 1: Replace the job-type toggle block with a dropdown + wrap spray fields**

In `openNewJobModal`, find the Job Type form-field block:

```html
        <div class="form-field">
          <label>Job Type</label>
          <div class="jt-toggle">
            <button type="button" class="jt-btn active-sched" id="nj-jt-sched" onclick="njSetJobType('Scheduled')">Scheduled</button>
            <button type="button" class="jt-btn" id="nj-jt-intv" onclick="njSetJobType('Intervention')">Intervention</button>
          </div>
          <input type="hidden" id="nj-job-type" value="Scheduled">
          <div id="nj-intv-info" style="display:none;margin-top:8px;padding:8px 12px;border-radius:8px;background:rgba(232,160,32,0.1);border:1px solid rgba(232,160,32,0.25);font-size:11px;color:#E8A020;line-height:1.4;">Intervention jobs are unscheduled emergency sprays. They log the application but handle the spray countdown separately on completion.</div>
        </div>
```

Replace with:

```html
        <div class="form-field">
          <label>Job Type</label>
          <select id="nj-job-type" style="width:100%;" onchange="njOnJobTypeChange()">
            <option value="Scheduled">Scheduled Spray</option>
            <option value="Intervention">Intervention Spray</option>
            <option value="Fertilizer">Fertilizer Application</option>
          </select>
          <div id="nj-intv-info" style="display:none;margin-top:8px;padding:8px 12px;border-radius:8px;background:rgba(232,160,32,0.1);border:1px solid rgba(232,160,32,0.25);font-size:11px;color:#E8A020;line-height:1.4;">Intervention jobs are unscheduled emergency sprays. They log the application but handle the spray countdown separately on completion.</div>
          <div id="nj-fert-info" style="display:none;margin-top:8px;padding:8px 12px;border-radius:8px;background:rgba(150,110,70,0.12);border:1px solid rgba(150,110,70,0.3);font-size:11px;color:#b98a5e;line-height:1.4;">Fertilizer applications are broadcast on soil — no tank mix or spray countdown. Plan it, then mark it done when applied.</div>
        </div>
```

- [ ] **Step 2: Wrap the spray-only sections so they can be hidden**

The spray-only sections are: the "Tank Mix — Active Ingredients" header + `#nj-ai-list` + `#nj-add-ai-row`, AND the "Tank & Water" header + tank row + `#nj-water` + `#nj-totals-breakdown`. Wrap BOTH groups in a single container. Find the block starting with the Tank Mix header:

```html
        <div style="margin:12px 0 4px;padding:6px 10px;background:rgba(74,124,63,0.12);border-left:3px solid var(--green);border-radius:0 6px 6px 0;"><span style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--green-light,#8fcf80);">Tank Mix — Active Ingredients</span></div>
        <div id="nj-ai-list"></div>
        <div id="nj-add-ai-row" style="padding:4px 0;">
          <select id="nj-add-ai-sel" style="width:calc(100% - 80px);">${njBuildAIOpts([])}</select>
          <button class="btn btn-primary btn-sm" onclick="njAddAI()" style="margin-left:6px;padding:6px 14px;">+ Add</button>
        </div>
```

Insert `<div id="nj-spray-fields">` immediately BEFORE that Tank Mix header div. Then find the end of the Tank & Water group — the `#nj-totals-breakdown` div:

```html
        <div id="nj-totals-breakdown" style="margin:8px 0;"></div>
```

Insert `</div>` (closing `#nj-spray-fields`) immediately AFTER `#nj-totals-breakdown`. (So `#nj-spray-fields` wraps Tank Mix + Tank & Water + totals. The Worker/Planned Date row stays OUTSIDE — it's shared with fertilizer.)

- [ ] **Step 3: Add the fertilizer fields container** (hidden by default)

Immediately AFTER the closing `</div>` of `#nj-spray-fields` (i.e., right after `#nj-totals-breakdown`'s wrapper close), insert:

```html
        <div id="nj-fert-fields" style="display:none;">
          <div style="margin:12px 0 4px;padding:6px 10px;background:rgba(150,110,70,0.12);border-left:3px solid #966e46;border-radius:0 6px 6px 0;"><span style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:#b98a5e;">Fertilizer</span></div>
          <div class="form-field"><label>Granular Fertilizer</label><select id="nj-fert-product" style="width:100%;" onchange="njFertSyncUnit()"><option value="">— Select —</option></select><div id="nj-fert-noprod" style="display:none;font-size:11px;color:var(--gold);margin-top:6px;">No Granular Fertilizer products in inventory. Add them in the Inventory module (category "Granular Fertilizer").</div></div>
          <div class="form-row">
            <div class="form-field"><label>Quantity</label><input id="nj-fert-qty" type="number" step="any" min="0" style="width:100%;"></div>
            <div class="form-field"><label>Unit</label><input id="nj-fert-unit" type="text" placeholder="kg / bags" style="width:100%;"></div>
          </div>
        </div>
```

- [ ] **Step 4: Add `njOnJobTypeChange`, `njFertProductOptions`, `njFertSyncUnit`; update `njSetJobType`**

Find `function njSetJobType(` (~line 1730). It currently reads the hidden input + toggles button classes. Replace the whole `njSetJobType` function with the new dropdown-driven handlers:

```js
function njFertProductOptions() {
  const prods = inventoryProducts.filter(p => p.category === 'Granular Fertilizer').sort((a,b)=>(a.name||'').localeCompare(b.name||''));
  return prods;
}

function njOnJobTypeChange() {
  const type = document.getElementById("nj-job-type").value;
  const isFert = type === 'Fertilizer';
  document.getElementById("nj-spray-fields").style.display = isFert ? 'none' : 'block';
  document.getElementById("nj-fert-fields").style.display = isFert ? 'block' : 'none';
  document.getElementById("nj-intv-info").style.display = type === 'Intervention' ? 'block' : 'none';
  document.getElementById("nj-fert-info").style.display = isFert ? 'block' : 'none';
  if(isFert) {
    const sel = document.getElementById("nj-fert-product");
    const prods = njFertProductOptions();
    sel.innerHTML = '<option value="">— Select —</option>' + prods.map(p=>`<option value="${p.id}" data-unit="${esc(p.pack_unit||'')}">${esc(p.name)}</option>`).join('');
    document.getElementById("nj-fert-noprod").style.display = prods.length ? 'none' : 'block';
  }
}

function njFertSyncUnit() {
  const sel = document.getElementById("nj-fert-product");
  const unitEl = document.getElementById("nj-fert-unit");
  if(!sel || !unitEl) return;
  if(!unitEl.value) {
    const opt = sel.options[sel.selectedIndex];
    if(opt && opt.dataset.unit) unitEl.value = opt.dataset.unit;
  }
}
```

(If any code elsewhere still calls `njSetJobType(...)`, grep and remove those calls — the only callers were the two toggle buttons we just deleted. Verify: `grep -n "njSetJobType" spraytracker.html` → 0 after this task.)

- [ ] **Step 5: Syntax check + commit**

Run the inline-script syntax check:
```
node -e "const fs=require('fs');const h=fs.readFileSync('spraytracker.html','utf8');const re=/<script>([\s\S]*?)<\/script>/g;let m,f=null;while((m=re.exec(h))){if(m[1].includes('openNewJobModal')){f=m[1];break;}}fs.writeFileSync('_chk.js',f);" && node --check _chk.js && echo SYNTAX_OK && rm -f _chk.js
```
Expected: SYNTAX_OK.

```bash
git add spraytracker.html
git commit -m "feat(spray): New Job — Job Type dropdown (Scheduled/Intervention Spray + Fertilizer) with fertilizer fields" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: submitNewJob — fertilizer branch

**Files:** Modify `spraytracker.html` (`submitNewJob` ~line 1744).

- [ ] **Step 1: Branch at the top of `submitNewJob`**

Find `async function submitNewJob() {` and the line `const jobType = document.getElementById("nj-job-type")?.value || 'Scheduled';`. Immediately AFTER that line, insert the fertilizer branch (it fully handles the fertilizer case and returns, so the existing spray logic below runs only for spray types):

```js
  if(jobType === 'Fertilizer') {
    const block_id = document.getElementById("nj-block").value;
    const inventory_product_id = document.getElementById("nj-fert-product").value;
    const qtyRaw = document.getElementById("nj-fert-qty").value;
    const fertilizer_quantity_unit = document.getElementById("nj-fert-unit").value.trim() || null;
    const worker_name = document.getElementById("nj-worker").value;
    const planned_date = document.getElementById("nj-date").value;
    const notes = document.getElementById("nj-notes").value.trim() || null;
    const logged = document.getElementById("nj-logged").value.trim() || null;
    if(!block_id) { notify("Select a block","warning"); return; }
    if(!inventory_product_id) { notify("Select a fertilizer product","warning"); return; }
    if(!worker_name) { notify("Select a worker","warning"); return; }
    if(!planned_date) { notify("Set a planned date","warning"); return; }
    const fertilizer_quantity = qtyRaw === '' ? null : parseFloat(qtyRaw);
    const btn = document.getElementById("nj-create-btn"); if(btn){ btn.disabled = true; btn.textContent = "Saving…"; }
    const payload = {
      block_id, job_type:'Fertilizer', status:'Planned', triggers_countdown:false,
      inventory_product_id, fertilizer_quantity, fertilizer_quantity_unit,
      worker_name, planned_date, notes, logged_by: logged,
      tanks_completed: 0, company_id: getCompanyId()
    };
    const result = await sbQuery(sb.from('pnd_jobs').insert(payload).select());
    if(result === null) { if(btn){ btn.disabled=false; btn.textContent="Create Job"; } return; }
    closeModal();
    await loadJobs();
    if(currentPage==='jobs') renderJobsTable();
    notify("Fertilizer job created");
    return;
  }
```

- [ ] **Step 2: Syntax check + commit**

Run the same inline-script `node --check` as Task 2 Step 5. Expected SYNTAX_OK.

```bash
git add spraytracker.html
git commit -m "feat(spray): submitNewJob creates Fertilizer jobs (pnd_jobs row, no spray fields)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Jobs list — fertilizer rows + Type filter

**Files:** Modify `spraytracker.html` (jobs toolbar HTML ~line 121; `renderJobsTable` ~line 1253).

- [ ] **Step 1: Add a Type filter to the Jobs toolbar**

Find the jobs status filter `<select id="jobs-filter-status" ...>...</select>` block in `#jobs-toolbar`. Immediately AFTER its closing `</select>`, insert:

```html
      <select id="jobs-filter-type" onchange="renderJobsTable()" style="min-width:150px;">
        <option value="">All Types</option>
        <option value="Scheduled">Scheduled Spray</option>
        <option value="Intervention">Intervention Spray</option>
        <option value="Fertilizer">Fertilizer</option>
      </select>
```

- [ ] **Step 2: Apply the type filter + render fertilizer rows in `renderJobsTable`**

In `renderJobsTable`, find the filter block:

```js
  let filtered = jobs.filter(j => {
    if(statusF === "active" && !activeStatuses.includes(j.status)) return false;
    if(statusF !== "active" && statusF !== "all" && j.status !== statusF) return false;
    if(blockF && j.block_id !== blockF) return false;
    if(fromF && j.planned_date < fromF) return false;
    if(toF && j.planned_date > toF) return false;
    return true;
  });
```

Add a `typeF` read at the top of the function (next to the other filter reads `const statusF = ...`):
```js
  const typeF = document.getElementById("jobs-filter-type")?.value || "";
```
And add this line inside the `.filter(j => {` body, right after the `toF` check:
```js
    if(typeF && j.job_type !== typeF) return false;
```

- [ ] **Step 3: Render fertilizer rows differently**

In `renderJobsTable`'s `tbody.innerHTML = filtered.map(j => { ... })`, the current code builds a spray row. Add a fertilizer branch at the very start of the map callback (right after `const b = getBlock(j.block_id); const bname = b?b.block_name:"?";`):

```js
    if(j.job_type === 'Fertilizer') {
      const inv = getInventoryProduct(j.inventory_product_id);
      const qty = j.fertilizer_quantity != null ? esc(fmtNum(j.fertilizer_quantity) + ' ' + (j.fertilizer_quantity_unit||'')) : '—';
      const checkedF = selectedJobIds.has(j.id) ? 'checked' : '';
      let fertActions = `<button class="btn btn-outline btn-sm" onclick="openFertJobModal('${j.id}')">Edit</button> <button class="btn btn-danger btn-sm" onclick="confirmDeleteJob('${j.id}')" title="Delete job"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:12px;height:12px;"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg> Delete</button>`;
      return `<tr>
        <td style="text-align:center;"><input type="checkbox" class="job-cb" data-id="${j.id}" ${checkedF} onchange="onJobCheckChange()"></td>
        <td>${fmtDateShort(j.planned_date)}</td>
        <td style="font-weight:600;">${esc(bname)}</td>
        <td><span class="badge badge-fert" style="background:rgba(150,110,70,0.2);color:#b98a5e;border:1px solid rgba(150,110,70,0.4);">Fertilizer</span></td>
        <td style="font-size:11px;color:var(--text-dim);">—</td>
        <td style="font-size:11px;">${esc(inv?inv.name:'—')}</td>
        <td>${esc(j.worker_name)}</td>
        <td>—</td>
        <td>—</td>
        <td>${qty}</td>
        <td><span class="badge ${statusBadgeClass(j.status)}">${esc(j.status)}</span></td>
        <td>${fertActions}</td>
      </tr>`;
    }
```

(This row has the same 12 columns as the spray row: checkbox · Planned · Block · Type · AI(—) · Product · Worker · Tank(—) · Tanks(—) · Total(qty) · Status · Actions. `openFertJobModal` is defined in Task 6.)

- [ ] **Step 4: Syntax check + commit**

Inline `node --check` (Task 2 Step 5 pattern). Expected SYNTAX_OK.

```bash
git add spraytracker.html
git commit -m "feat(spray): Jobs list shows Fertilizer jobs + Type filter" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Job Logs — fertilizer rows + Fertilizer type option

**Files:** Modify `spraytracker.html` (jl-filter-type options ~line 225; `renderJobLogs` row map ~line 2200).

- [ ] **Step 1: Add Fertilizer to the Job Logs type filter + relabel**

Find:
```html
      <select id="jl-filter-type" onchange="jlPage=0;renderJobLogs()" style="min-width:110px;">
```
and the two options below it:
```html
        <option value="Scheduled">Scheduled</option>
        <option value="Intervention">Intervention</option>
```
Replace those two option lines with:
```html
        <option value="Scheduled">Scheduled Spray</option>
        <option value="Intervention">Intervention Spray</option>
        <option value="Fertilizer">Fertilizer</option>
```
(Keep the existing "All Types"/empty option that precedes them, whatever its current text.)

- [ ] **Step 2: Render fertilizer rows in `renderJobLogs`**

In `renderJobLogs`, find the `tbody.innerHTML = data.map(j => { ... })`. At the very start of the map callback (right after `const b = getBlock(j.block_id);`), add:

```js
    if(j.job_type === 'Fertilizer') {
      const inv = getInventoryProduct(j.inventory_product_id);
      const qty = j.fertilizer_quantity != null ? esc(fmtNum(j.fertilizer_quantity)+' '+(j.fertilizer_quantity_unit||'')) : '—';
      return `<tr>
        <td>${fmtDateShort(j.planned_date)}</td>
        <td>${fmtDateShort(j.completion_date)}</td>
        <td style="font-weight:600;">${esc(b?.block_name)}</td>
        <td><span class="badge badge-fert" style="background:rgba(150,110,70,0.2);color:#b98a5e;border:1px solid rgba(150,110,70,0.4);">Fertilizer</span></td>
        <td style="font-size:11px;">${esc(inv?inv.name:'—')}</td>
        <td style="font-size:11px;color:var(--text-dim);">—</td>
        <td>${esc(j.worker_name)}</td>
        <td>—</td>
        <td>—</td>
        <td>${qty}</td>
        <td>—</td>
        <td>${jlStatusSelect(j)}</td>
        <td><button class="btn btn-outline btn-sm" onclick="openFertJobModal('${j.id}')">Edit</button></td>
      </tr>`;
    }
```

(Matches the 13-column Job Logs layout: Planned · Completed · Block · Type · Product · AI(—) · Worker · Tank(—) · Tanks(—) · Total(qty) · ProductUsed(—) · Status · Action. `jlStatusSelect(j)` is reused — if it produces a spray-specific dropdown that breaks for fertilizer, replace that cell with `<span class="badge ${statusBadgeClass(j.status)}">${esc(j.status)}</span>` instead. Read `jlStatusSelect` to decide; prefer reuse if it just renders a status dropdown.)

- [ ] **Step 3: Syntax check + commit**

Inline `node --check` (find block containing `renderJobLogs`). Expected SYNTAX_OK.

```bash
git add spraytracker.html
git commit -m "feat(spray): Job Logs shows Fertilizer jobs + Fertilizer type filter" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Dedicated fertilizer edit/complete modal + entry guards

**Files:** Modify `spraytracker.html` (add `openFertJobModal` + `fertJobSave`; guard `openEditJobModal` + `openEditStatusModal`).

- [ ] **Step 1: Add the fertilizer edit/complete modal + save**

Insert this block near the other New Job / job functions (e.g., right after `submitNewJob`'s closing brace):

```js
// Fertilizer job edit / complete (dedicated — bypasses spray completion flow)
function openFertJobModal(jobId) {
  const j = jobs.find(x => x.id === jobId);
  if(!j) { notify("Job not found","error"); return; }
  const blockOpts = blocks.filter(b=>b.is_active).map(b=>`<option value="${b.id}" ${b.id===j.block_id?'selected':''}>${esc(b.block_name)}</option>`).join("");
  const prods = njFertProductOptions();
  const prodOpts = '<option value="">— Select —</option>' + prods.map(p=>`<option value="${p.id}" data-unit="${esc(p.pack_unit||'')}" ${p.id===j.inventory_product_id?'selected':''}>${esc(p.name)}</option>`).join('');
  const workerOpts = '<option value="">— Select —</option>' + workers.map(w=>`<option value="${esc(w.name)}" ${w.name===j.worker_name?'selected':''}>${esc(w.name)}</option>`).join("");
  const statusOpts = ['Planned','In Progress','Completed'].map(s=>`<option value="${s}" ${j.status===s?'selected':''}>${s}</option>`).join('');
  document.getElementById("modal-container").innerHTML = `
    <div class="modal-overlay" style="display:flex;">
      <div class="modal-box" style="max-width:480px;">
        <div class="modal-header"><div class="modal-title">Fertilizer Job</div><button class="modal-close" onclick="closeModal()"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button></div>
        <div class="modal-body">
          <div class="form-field"><label>Block</label><select id="fj-block" style="width:100%;">${blockOpts}</select></div>
          <div class="form-field"><label>Granular Fertilizer</label><select id="fj-product" style="width:100%;" onchange="fjSyncUnit()">${prodOpts}</select></div>
          <div class="form-row">
            <div class="form-field"><label>Quantity</label><input id="fj-qty" type="number" step="any" min="0" value="${j.fertilizer_quantity!=null?j.fertilizer_quantity:''}" style="width:100%;"></div>
            <div class="form-field"><label>Unit</label><input id="fj-unit" type="text" value="${esc(j.fertilizer_quantity_unit||'')}" placeholder="kg / bags" style="width:100%;"></div>
          </div>
          <div class="form-row">
            <div class="form-field"><label>Worker</label><select id="fj-worker" style="width:100%;">${workerOpts}</select></div>
            <div class="form-field"><label>Planned Date</label><input id="fj-planned" type="date" value="${j.planned_date||''}" style="width:100%;"></div>
          </div>
          <div class="form-row">
            <div class="form-field"><label>Status</label><select id="fj-status" style="width:100%;" onchange="fjStatusChange()">${statusOpts}</select></div>
            <div class="form-field" id="fj-compdate-wrap" style="display:${j.status==='Completed'?'block':'none'};"><label>Completed Date</label><input id="fj-compdate" type="date" value="${j.completion_date||todayStr()}" style="width:100%;"></div>
          </div>
          <div class="form-field"><label>Notes</label><textarea id="fj-notes" rows="2" style="width:100%;">${esc(j.notes||'')}</textarea></div>
        </div>
        <div class="modal-actions">
          <button class="btn btn-outline" onclick="closeModal()">Cancel</button>
          <button class="btn btn-primary" onclick="fertJobSave('${j.id}')">Save</button>
        </div>
      </div>
    </div>`;
}

function fjSyncUnit() {
  const sel = document.getElementById("fj-product"); const unitEl = document.getElementById("fj-unit");
  if(!sel || !unitEl) return;
  if(!unitEl.value) { const opt = sel.options[sel.selectedIndex]; if(opt && opt.dataset.unit) unitEl.value = opt.dataset.unit; }
}

function fjStatusChange() {
  const st = document.getElementById("fj-status").value;
  document.getElementById("fj-compdate-wrap").style.display = st === 'Completed' ? 'block' : 'none';
}

async function fertJobSave(jobId) {
  const block_id = document.getElementById("fj-block").value;
  const inventory_product_id = document.getElementById("fj-product").value;
  const qtyRaw = document.getElementById("fj-qty").value;
  const fertilizer_quantity_unit = document.getElementById("fj-unit").value.trim() || null;
  const worker_name = document.getElementById("fj-worker").value;
  const planned_date = document.getElementById("fj-planned").value;
  const status = document.getElementById("fj-status").value;
  const notes = document.getElementById("fj-notes").value.trim() || null;
  if(!block_id || !inventory_product_id || !worker_name || !planned_date) { notify("Block, product, worker and planned date are required","warning"); return; }
  const fertilizer_quantity = qtyRaw === '' ? null : parseFloat(qtyRaw);
  const payload = {
    block_id, inventory_product_id, fertilizer_quantity, fertilizer_quantity_unit,
    worker_name, planned_date, status, notes, triggers_countdown:false,
    completion_date: status === 'Completed' ? (document.getElementById("fj-compdate").value || todayStr()) : null
  };
  const result = await sbQuery(sb.from('pnd_jobs').update(payload).eq('id', jobId).select());
  if(result === null) return;
  closeModal();
  await loadJobs();
  if(currentPage==='jobs') renderJobsTable();
  if(currentPage==='joblogs') renderJobLogs();
  notify("Fertilizer job saved");
}
```

- [ ] **Step 2: Guard the spray edit/status entry points**

`openEditJobModal(jobId)` (active-jobs "Edit") and `openEditStatusModal(jobId)` (job-logs "Edit Status") assume a spray job. Read each, and add this guard as the FIRST line inside each function body (after it resolves the job, or before if it doesn't):

```js
  const _fj = jobs.find(x => x.id === jobId);
  if(_fj && _fj.job_type === 'Fertilizer') { return openFertJobModal(jobId); }
```

(Place it so it runs before any spray-specific DOM/render. If the function already fetches the job into a variable, reuse that variable instead of `_fj`.)

- [ ] **Step 3: Syntax check + commit**

Inline `node --check`. Expected SYNTAX_OK.

```bash
git add spraytracker.html
git commit -m "feat(spray): dedicated Fertilizer job edit/complete modal + spray-modal guards" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Crop Care matrix — read fertilizer from completed jobs

**Files:** Modify `spraytracker.html` (`renderSummary` fertilizer aggregation; `summaryShowPopup` fert branch; the summary load path + `loadFertilizerApplications` references).

- [ ] **Step 1: Swap the fertilizer data source in `renderSummary`**

In `renderSummary`, find:
```js
  const fertLatest = {};
  fertilizerApplications.forEach(fa => {
    const cur = fertLatest[fa.block_id];
    if(!cur || (fa.date_applied||'') > (cur.date_applied||'')) fertLatest[fa.block_id] = fa;
  });
```
Replace with (latest COMPLETED fertilizer job per block, keyed by completion_date):
```js
  const fertLatest = {};
  jobs.forEach(j => {
    if(j.job_type !== 'Fertilizer' || j.status !== 'Completed' || !j.completion_date) return;
    const cur = fertLatest[j.block_id];
    if(!cur || (j.completion_date||'') > (cur.completion_date||'')) fertLatest[j.block_id] = j;
  });
```

Then find the fertilizer cell block in the `SUMMARY_COLS.forEach`:
```js
        if(c.key === 'fertilizer') {
          const fa = fertLatest[block.id];
          if(fa && fa.date_applied) {
            hasData = true;
            dateStr = fmtDateShort(fa.date_applied);
            const d = daysDiff(fa.date_applied, today);
            daysStr = d != null ? d + 'd' : '—';
            summaryCellData[cellId] = { kind:'fert', fa };
          }
        } else {
```
Replace the inner body with completion_date semantics:
```js
        if(c.key === 'fertilizer') {
          const fj = fertLatest[block.id];
          if(fj && fj.completion_date) {
            hasData = true;
            dateStr = fmtDateShort(fj.completion_date);
            const d = daysDiff(fj.completion_date, today);
            daysStr = d != null ? d + 'd' : '—';
            summaryCellData[cellId] = { kind:'fert', job:fj };
          }
        } else {
```

- [ ] **Step 2: Update the fert popup branch in `summaryShowPopup`**

Find the `if(data.kind === 'fert') {` block and replace it with the job-based version:
```js
  if(data.kind === 'fert') {
    const fj = data.job;
    const b = getBlock(fj.block_id);
    const inv = getInventoryProduct(fj.inventory_product_id);
    const d = daysDiff(fj.completion_date, today);
    html =
      `<div style="font-weight:700;color:var(--green-light);">Fertilizer — ${esc(b?b.block_name:'—')}</div>` +
      `<div style="color:var(--text-muted);">Applied ${fmtDate(fj.completion_date)} · ${d!=null?d+' days ago':'—'}</div>` +
      `<hr style="border:none;border-top:1px solid var(--border);margin:8px 0;">` +
      `<div><b>Product:</b> ${esc(inv?inv.name:'—')}</div>` +
      `<div><b>Quantity:</b> ${fj.fertilizer_quantity!=null?esc(fmtNum(fj.fertilizer_quantity)+' '+(fj.fertilizer_quantity_unit||'')):'—'}</div>` +
      `<div style="color:var(--text-muted);margin-top:5px;">Worker: ${esc(fj.worker_name||'—')}</div>`;
  } else {
```
(Leave the spray `else` branch unchanged.)

- [ ] **Step 3: Remove `fertilizerApplications`/`loadFertilizerApplications` usage from the summary load**

In `renderCurrentPage`, find the summary path:
```js
  if(currentPage === 'summary') { await Promise.all([loadSprayLogs(), loadFertilizerApplications(), loadJobs(), loadJobProducts(), loadProducts(), loadBlockCrops(), loadCropStatuses(), loadInventoryProducts()]); renderSummary(); }
```
Replace with (drop `loadFertilizerApplications`, keep `loadJobs` which the matrix now needs):
```js
  if(currentPage === 'summary') { await Promise.all([loadSprayLogs(), loadJobs(), loadJobProducts(), loadProducts(), loadBlockCrops(), loadCropStatuses(), loadInventoryProducts()]); renderSummary(); }
```

- [ ] **Step 4: Syntax check + commit**

Inline `node --check` (block containing `renderSummary`). Expected SYNTAX_OK.

```bash
git add spraytracker.html
git commit -m "feat(spray): Crop Care matrix Fertilizer column reads completed fertilizer jobs" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Retire the Fertilizer tab + dead fertilizer-table code

**Files:** Modify `spraytracker.html` (nav item, page block, fert* functions, loaders, load paths).

- [ ] **Step 1: Remove the Fertilizer nav item**

Delete:
```html
    <div class="nav-item" data-page="fertilizer" onclick="navigateTo('fertilizer')">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2C7 7 7 12 12 22 17 12 17 7 12 2z"/><path d="M5 12c2 1 4 3 7 10"/><path d="M19 12c-2 1-4 3-7 10"/></svg>
      <span class="nav-label">Fertilizer</span>
    </div>
```

- [ ] **Step 2: Remove the Fertilizer page block**

Delete the entire `<!-- PAGE: FERTILIZER -->` block from `<div id="page-fertilizer" class="page">` through its closing `</div>` (the page with `#fert-filter-row` + `#fert-list`).

- [ ] **Step 3: Remove the fertilizer-table functions + loader**

Delete these now-dead functions (from the Task 7 work in the earlier build): `fertGranularProducts`, `renderFertilizerPage`, `fertOpenForm`, `fertSyncUnit`, `fertSave`, `fertEditFromEvent`, `fertDeleteFromEvent`, the `let fertFilterBlock = '';` declaration, the `loadFertilizerApplications` function, and the `let fertilizerApplications=[];` declaration.

NOTE: Task 6's modal uses DIFFERENT names (`openFertJobModal`, `fjSyncUnit`, `fertJobSave`, `fjStatusChange`) — do NOT delete those. Only delete the `fert*`/`renderFertilizerPage`/`fertilizerApplications` items listed above.

- [ ] **Step 4: Remove remaining `fertilizer` page wiring**

In `renderCurrentPage`, delete the line:
```js
  else if(currentPage === 'fertilizer') { await Promise.all([loadFertilizerApplications(), loadBlocks(), loadWorkers(), loadInventoryProducts()]); renderFertilizerPage(); }
```
In `startAutoRefresh`, change:
```js
    await Promise.all([loadLatestSprays(), loadLatestSpraysByAI(), loadJobs(), loadOverrides(), loadSprayLogs(), loadFertilizerApplications()]);
    if(currentPage === 'summary') renderSummary();
    if(currentPage === 'fertilizer') renderFertilizerPage();
```
to:
```js
    await Promise.all([loadLatestSprays(), loadLatestSpraysByAI(), loadJobs(), loadOverrides(), loadSprayLogs()]);
    if(currentPage === 'summary') renderSummary();
```
In `loadAll`, remove `loadFertilizerApplications()` from the `Promise.all([...])` array (leave `loadSprayLogs()`).

- [ ] **Step 5: Verify no dangling references + syntax check**

```
grep -nc "fertilizerApplications\|loadFertilizerApplications\|renderFertilizerPage\|page-fertilizer\|data-page=\"fertilizer\"\|fertOpenForm\|fertGranularProducts\|fertEditFromEvent\|fertDeleteFromEvent" spraytracker.html
```
Expected: 0.
Then inline `node --check`. Expected SYNTAX_OK.

- [ ] **Step 6: Commit**

```bash
git add spraytracker.html
git commit -m "refactor(spray): retire Fertilizer tab + pnd_fertilizer_applications code (now a job type)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Deploy + verify + changelog

**Files:** none (deploy + verification); then CLAUDE.md.

- [ ] **Step 1: Final full syntax check**

```
node -e "const fs=require('fs');const h=fs.readFileSync('spraytracker.html','utf8');const re=/<script>([\s\S]*?)<\/script>/g;let m,f=null;while((m=re.exec(h))){if(m[1].includes('renderSummary')){f=m[1];break;}}fs.writeFileSync('_chk.js',f);" && node --check _chk.js && echo SYNTAX_OK && rm -f _chk.js
```

- [ ] **Step 2: Deploy**

```bash
cd "C:/dev/TG-Farmhub-Website"
npx netlify-cli deploy --prod --dir=. --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26
```
(No `--functions` flag — per the 2026-05-11 lesson.)

- [ ] **Step 3: Live verify**

```bash
cd "C:/dev/TG-Farmhub-Website"
echo "new symbols (expect >=1):"
for s in 'nj-job-type' 'njOnJobTypeChange' 'openFertJobModal' 'fertJobSave' 'jobs-filter-type' 'value="Fertilizer"'; do echo "$s: $(curl -s https://tgfarmhub.com/spraytracker.html | grep -c "$s")"; done
echo "retired (expect 0):"
for d in 'data-page="fertilizer"' 'renderFertilizerPage' 'loadFertilizerApplications'; do echo "$d: $(curl -s https://tgfarmhub.com/spraytracker.html | grep -c "$d")"; done
```
Expected: new symbols ≥1; retired = 0.

- [ ] **Step 4: Manual smoke test (browser, DevTools console open)**

1. Jobs → New Job → Job Type dropdown shows 3 options; switching to **Fertilizer Application** hides tank/AI fields and shows the fertilizer fields; Granular Fertilizer products listed.
2. Create a fertilizer job → appears in the **Jobs** list as Planned with a Fertilizer badge; **Type filter** = Fertilizer shows only it.
3. Edit it → the dedicated fertilizer modal opens (not the spray modal); set Status = Completed + completed date → Save.
4. **Job Logs** → Type filter = Fertilizer shows the completed fertilizer job; no spray-log was created (check Job Logs / no error).
5. **Crop Care Summary** → the block's Fertilizer column shows the completion date + days; hover → product/quantity/worker popup.
6. The **Fertilizer tab is gone** from the sidebar. Spray jobs (Scheduled/Intervention) still create + complete normally.
7. Console clean throughout.

- [ ] **Step 5: CLAUDE.md changelog + commit**

Add a dated entry summarizing: fertilizer is now a `pnd_jobs` job_type (Planned→Completed, no spray fields); New Job Job-Type dropdown (Scheduled Spray/Intervention Spray/Fertilizer Application); Jobs + Job Logs Type filter incl. Fertilizer; dedicated fertilizer edit/complete modal + spray-modal guards; matrix Fertilizer column reads completed fertilizer jobs; Fertilizer tab + `pnd_fertilizer_applications` retired; DB (job_type widen, 5 spray cols nullable, 3 fert cols, trigger guard, table dropped). Note "Active Jobs"→"Jobs" rename shipped alongside.

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): fertilizer as a job type + Jobs rename" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Coverage:** dropdown (T2) · fertilizer create (T3) · Jobs list + Type filter (T4) · Job Logs + filter (T5) · edit/complete + guards (T6) · matrix source (T7) · retire tab/table (T8) · DB (T1) · deploy/verify (T9). ✓
- **Type consistency:** new job functions `njOnJobTypeChange`/`njFertProductOptions`/`njFertSyncUnit`; modal `openFertJobModal`/`fjSyncUnit`/`fjStatusChange`/`fertJobSave`; columns `inventory_product_id`/`fertilizer_quantity`/`fertilizer_quantity_unit`; job_type value `'Fertilizer'`; `triggers_countdown:false` on every fertilizer write. Consistent across tasks. ✓
- **Risk control:** spray paths untouched except (a) job_type filter line, (b) one guard line in two edit entry points, (c) nullable columns (spray jobs still set them). Fertilizer isolated in dedicated functions. Trigger guarded two ways (job_type check + triggers_countdown=false). ✓
- **Dead-code:** T8 removes the earlier-built fertilizer-table code; verified by grep=0. The DB table is dropped in T1. ✓
```
