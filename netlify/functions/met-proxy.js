// ═══════════════════════════════════════════════════════════════
// MET Malaysia API Proxy — Netlify Serverless Function
// ═══════════════════════════════════════════════════════════════
// Bypasses CORS issues with api.met.gov.my
// ═══════════════════════════════════════════════════════════════

const MET_TOKEN = '31db1e47c66be6f654799689fc0c5cb10365e6f1';
const MET_BASE = 'https://api.met.gov.my/v2.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  const params = event.queryStringParameters || {};
  const action = params.action || 'forecast';

  try {
    if (action === 'forecast') {
      const locationid = params.locationid || 'LOCATION:586';
      const today = new Date().toISOString().split('T')[0];
      const end = new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0];
      const url = `${MET_BASE}/data?datasetid=FORECAST&datacategoryid=GENERAL&locationid=${locationid}&start_date=${today}&end_date=${end}`;

      const res = await fetch(url, {
        headers: { 'Authorization': `METToken ${MET_TOKEN}` },
      });

      if (!res.ok) {
        const text = await res.text();
        throw new Error(`MET API ${res.status}: ${text}`);
      }

      const data = await res.json();
      return {
        statusCode: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      };
    }

    if (action === 'warning') {
      const url = `${MET_BASE}/data?datasetid=WARNING&datacategoryid=THUNDERSTORM,RAIN`;
      const res = await fetch(url, {
        headers: { 'Authorization': `METToken ${MET_TOKEN}` },
      });

      if (!res.ok) {
        const text = await res.text();
        throw new Error(`MET API ${res.status}: ${text}`);
      }

      const data = await res.json();
      return {
        statusCode: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      };
    }

    return {
      statusCode: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Unknown action. Use: forecast, warning' }),
    };

  } catch (err) {
    console.error('MET proxy error:', err);
    return {
      statusCode: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: err.message }),
    };
  }
};
