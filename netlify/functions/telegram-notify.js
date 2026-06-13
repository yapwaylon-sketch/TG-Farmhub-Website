// ═══════════════════════════════════════════════════════════════
// Telegram Notify — Netlify Serverless Function
// ═══════════════════════════════════════════════════════════════
// Proxies oil palm sales notifications to a Telegram group.
// Bot token + chat_id live in Netlify env vars (NOT in source) —
// the repo is public, and a leaked bot token would let anyone spam
// the group.
//
// Accepts POST JSON:
//   { kind: 'message', text }                  -> sendMessage
//   { kind: 'photo', imageBase64, caption? }   -> sendPhoto
//
// Runtime: Netlify Node 18+ (global fetch / FormData / Blob / Buffer).
// ═══════════════════════════════════════════════════════════════

// Lock CORS to the production site so other origins can't drive a visitor's
// browser into POSTing here. (Doesn't stop a raw curl — but the blast radius
// is bounded: this proxy can only ever send to our single fixed chat_id, and
// never exposes the bot token. Ultimate backstop is rotating the token.)
const ALLOWED_ORIGIN = 'https://tgfarmhub.com';
const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

// Telegram hard limits — also bound payload-abuse.
const MAX_TEXT = 4096;        // sendMessage text
const MAX_CAPTION = 1024;     // sendPhoto caption
const MAX_IMAGE_B64 = 14000000; // ~10 MB photo as base64

function json(statusCode, obj) {
  return { statusCode, headers: { ...corsHeaders, 'Content-Type': 'application/json' }, body: JSON.stringify(obj) };
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 200, headers: corsHeaders, body: '' };
  if (event.httpMethod !== 'POST')    return json(405, { ok: false, error: 'method not allowed' });

  const token  = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!token || !chatId) return json(500, { ok: false, error: 'not configured' });

  let payload;
  try {
    payload = JSON.parse(event.body || '{}');
  } catch (e) {
    return json(400, { ok: false, error: 'invalid json body' });
  }

  const kind = payload.kind;

  try {
    let tgRes;

    if (kind === 'message') {
      const text = (payload.text || '').toString();
      if (!text.trim()) return json(400, { ok: false, error: 'text required' });
      if (text.length > MAX_TEXT) return json(413, { ok: false, error: 'text too long' });
      tgRes = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: chatId, text }),
      });

    } else if (kind === 'photo') {
      const b64 = (payload.imageBase64 || '').toString();
      if (!b64) return json(400, { ok: false, error: 'imageBase64 required' });
      if (b64.length > MAX_IMAGE_B64) return json(413, { ok: false, error: 'image too large' });
      const caption = payload.caption ? payload.caption.toString() : '';
      if (caption.length > MAX_CAPTION) return json(413, { ok: false, error: 'caption too long' });
      const buffer = Buffer.from(b64, 'base64');
      const form = new FormData();
      form.append('chat_id', chatId);
      if (caption) form.append('caption', caption);
      form.append('photo', new Blob([buffer], { type: 'image/png' }), 'booking.png');
      // Do NOT set Content-Type manually — fetch adds the multipart boundary.
      tgRes = await fetch(`https://api.telegram.org/bot${token}/sendPhoto`, { method: 'POST', body: form });

    } else {
      return json(400, { ok: false, error: 'unknown kind' });
    }

    if (!tgRes.ok) {
      const errText = await tgRes.text();
      // errText is Telegram's error description — does NOT contain the token.
      return json(502, { ok: false, error: `telegram ${tgRes.status}: ${errText}` });
    }

    return json(200, { ok: true });
  } catch (e) {
    return json(502, { ok: false, error: 'send failed: ' + (e && e.message ? e.message : String(e)) });
  }
};
