# Oil Palm Sales → Telegram Notifications — Design

**Date:** 2026-06-13
**Module:** `oilpalmsales.html` (+ new `netlify/functions/telegram-notify.js`)
**Status:** Approved, pending implementation plan

## Goal

Auto-notify a Telegram group when oil palm sales activity happens:

1. **New booking** → send the completed booking form as a **PNG image** to the group.
2. **New collection** (booking collection *and* walk-in sale) → send a **text message** summarizing the pickup.

Both notifications are convenience alerts. They must **never** block, revert, or interfere with the booking/collection save.

## Requirements (confirmed during brainstorming)

- Booking artifact format: **PNG image** (rendered from the existing booking slip; previews inline in Telegram). Not PDF.
- Collection notifications fire for **both** booking collections and walk-in sales.
- Collection message fields:
  - **Collected pokok** = the qty in **this** pickup event (not cumulative).
  - **Balance to collect** = remaining **seedling count** on the booking = `booked_qty − cumulative_collected` (ignores payment status — full booked qty is collectable per "including unpaid balance"). Walk-ins = 0.
- One Telegram group receives **both** booking and collection notifications (single `chat_id`).
- User does not yet have a bot/group — setup steps provided at rollout.

## Architecture — Approach A (chosen)

One Netlify function proxy; both notifications fired from the frontend after the DB commit.

```
Booking save  ─┐                                ┌─ sendPhoto  (booking PNG)
               ├─→ frontend opsTgNotify() ─POST─→ telegram-notify.js ─→ Telegram Bot API
Collection save┘   (fire-and-forget)            └─ sendMessage (collection text)
```

**Why not pg_net DB trigger (Approach B):** the booking PNG can only be rendered by a browser, so booking is inherently frontend-initiated. Routing the collection text through a DB trigger would mean **two** mechanisms and **two** token stores for no gain — bookings/collections are only ever created via the frontend. One mechanism, one token store.

**Why not browser-direct (Approach C):** rejected — would expose the bot token in public source (`oilpalmsales.html`), letting anyone spam the group.

**Token storage:** Netlify **environment variables** (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`), not hardcoded in the function source. Reason: the GitHub repo is **public**, and a leaked bot token allows group spam. (Note: the existing `met-proxy.js` hardcodes its token in source — we deliberately do **not** copy that pattern here.)

## Components

### 1. `netlify/functions/telegram-notify.js` (new)

- CommonJS `exports.handler = async (event) => {…}` (matches existing functions). Global `fetch`, `FormData`, `Blob` available on Netlify's Node 18+ runtime.
- Reads `process.env.TELEGRAM_BOT_TOKEN` and `process.env.TELEGRAM_CHAT_ID`. If either is missing → return `500 { ok:false, error:'not configured' }` (never echo the token).
- Method guard: `OPTIONS` → 200 (CORS preflight); non-`POST` → 405.
- CORS headers matching other functions (`Access-Control-Allow-Origin: *`, `POST, OPTIONS`, `Content-Type`).
- Request body JSON:
  - `{ kind: 'message', text }` → `POST https://api.telegram.org/bot<token>/sendMessage` with `{ chat_id, text }`.
  - `{ kind: 'photo', imageBase64, caption }` → decode base64 to a `Buffer`/`Blob`, build multipart `FormData` (`chat_id`, `caption`, `photo`=blob filename e.g. `booking.png`), `POST .../sendPhoto`.
- On Telegram non-OK: return the error body with a 502 (frontend only warns).
- Returns `{ ok:true }` on success.
- Input validation: reject unknown `kind`, empty `text`, empty `imageBase64`.
- Never logs the token.

### 2. `opsTgNotify(payload)` — frontend helper in `oilpalmsales.html`

- `fetch('/.netlify/functions/telegram-notify', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload) })`.
- Fully defensive: wrapped so it **never throws** to the caller. On non-OK response or network error → `console.warn(...)` + soft `notify('Telegram notification failed — record still saved', 'warning')`.
- Not awaited in a way that blocks the save flow.
- Shared by both booking and collection hooks.

### 3. Booking notification (PNG)

- **Refactor:** extract the slip inner-HTML builder out of `opsOpenBookingSlip(bookingId)` into a reusable `opsBuildSlipHtml(bookingId)` returning the `#slip-content` markup (+ reuse the existing `SLIP_CSS`). Both the Print/Share popup and the silent-capture path call it — no duplicated markup.
- Add **html2canvas** CDN to the main page `<head>`, pinned to `1.4.1` (same version the popup already uses).
- New `opsCaptureSlipPng(bookingId)`:
  - Inject the slip markup into a hidden offscreen container (e.g. `position:fixed; left:-10000px; top:0; width:794px;` = A4 @ 96dpi; apply `SLIP_CSS` scoped).
  - `html2canvas(el, { scale:2, backgroundColor:'#ffffff' })` → `canvas.toDataURL('image/png')` → strip the `data:image/png;base64,` prefix → return base64.
  - Remove the container in a `finally`.
- **Hook:** at the end of `opsSaveNewBooking`'s `doSave()` (after the success toast + state reload), inside `try/catch` that only warns:
  ```js
  const png = await opsCaptureSlipPng(bookingId);
  opsTgNotify({ kind:'photo', imageBase64: png, caption: <summary> });
  ```
- **Caption** = one-line summary: Booking #, customer name, batch (number + variety), qty, total, paid, balance.

### 4. Collection notification (text)

- Hooked at the end of **both** `opsSaveCollection(bookingId)` and `opsSaveWalkIn()`, after each path commits its collection row and reloads state. Inside `try/catch` that only warns.
- Message format:
  ```
  🌴 New Collection — <collectionId>

  Booking No: <bk.id | "Walk-in">
  Batch: <batch.batch_number> (<variety.name>)
  Name: <customer.name>
  Collected pokok: <this pickup qty>
  Balance to collect: <booked_qty − (collected_so_far + this qty)>   (0 for walk-ins)
  ```
- Field sources:
  - **Booking No:** `bk.id` for booking collections; the literal `Walk-in` for walk-in sales (`booking_id` is null).
  - **Batch:** look up the collection's `batch_id` in `batches` → `batch_number` + variety name from `varieties`.
  - **Name:** customer name from `customers` (booking) or the just-created/looked-up walk-in customer.
  - **Collected pokok:** the `qty` of this collection event.
  - **Balance to collect:** booking collections → `booked_qty − cumulative_collected_including_this`; walk-ins → `0`.
- Numbers formatted with thousands separators (`toLocaleString()` / existing `fmtNum`).

### 5. Non-blocking guarantee

Both hooks run **after** the DB row is committed and in-memory state reloaded. Each is wrapped in `try/catch`; a function or Telegram failure produces only a `console.warn` + soft toast and never reverts or blocks the save. This matches the codebase's existing best-effort side-effect pattern (e.g. `opsAutoFlipBatchSoldOut`).

## Setup (3 manual user steps, given at rollout)

1. Create a bot via **@BotFather** → copy the bot token.
2. Create a Telegram group, add the bot, send one message in it, then fetch the **chat_id** via `https://api.telegram.org/bot<token>/getUpdates` (read `chat.id` from the JSON — will be a negative number for a group).
3. In Netlify → Site settings → Environment variables, add `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. (Not committed to git.)

## Deploy & verification

- Deploy: `npx netlify-cli deploy --prod --dir=. --site=a0ac5d18-a968-414c-a531-c78ed390e5c2 --auth=$TOKEN` — **no** `--functions` flag (per the 2026-05-11 lesson: `netlify.toml` already declares the functions dir; passing `--functions` triggers the 403 extensions code path).
- Verify (no "try it" hand-off):
  1. `curl -X POST .../.netlify/functions/telegram-notify` with a sample `{kind:'message', text:'test'}` → confirm it lands in the group.
  2. Create a test booking → confirm the PNG appears inline in the group.
  3. Record a test collection (and a walk-in) → confirm the text message format.

## Out of scope (YAGNI)

- Status-change / cancellation / refund notifications.
- Per-user DMs (per-worker chat_id).
- Mute hours.
- In-DB notification log / retry UI.
- The separate sales-orders pg_net Telegram project (previously designed, still deferred).

## Codebase facts relied on

- `oilpalmsales.html`: `opsSaveNewBooking` (≈L1080, inner `doSave` ≈L1113), `opsSaveCollection` (≈L1940), `opsSaveWalkIn` (≈L575), `opsOpenBookingSlip` + `SLIP_CSS` (≈L1199–1349).
- Walk-in inserts an `oilpalm_collections` row with `booking_id = null` and a `qty`.
- `oilpalm_payments` and `oilpalm_batch_events` have **no** `company_id`; `oilpalm_bookings`/`oilpalm_collections`/`oilpalm_customers`/`oilpalm_batches` **do**.
- Netlify functions are CommonJS, esbuild-bundled, auto-discovered via `netlify.toml` (`functions = "netlify/functions"`).
- Module gotchas apply (see CLAUDE.md "Module Build Gotchas"): `sbMutate` needs a thunk; `closeModal`/`hideLoading` need their arg; `esc()` doesn't escape quotes.
