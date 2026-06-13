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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

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
      tgRes = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chat_id: chatId, text }),
      });

    } else if (kind === 'photo') {
      const b64 = (payload.imageBase64 || '').toString();
      if (!b64) return json(400, { ok: false, error: 'imageBase64 required' });
      const buffer = Buffer.from(b64, 'base64');
      const form = new FormData();
      form.append('chat_id', chatId);
      if (payload.caption) form.append('caption', payload.caption.toString());
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
