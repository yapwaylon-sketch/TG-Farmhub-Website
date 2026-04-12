// ═══════════════════════════════════════════════════════════════
// Davis WeatherLink v2 API Proxy — Netlify Serverless Function
// ═══════════════════════════════════════════════════════════════
// Handles CORS, proxies to Davis API, stores readings in Supabase
// ═══════════════════════════════════════════════════════════════

const DAVIS_API_KEY = 'aufrbtqkykcwktihemyipk1e6di6xw7b';
const DAVIS_API_SECRET = 'sqtldzcqjvspovha6vseekw6pr51avpl';
const DAVIS_BASE = 'https://api.weatherlink.com/v2';

const SUPABASE_URL = 'https://qwlagcriiyoflseduvvc.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE';

// Unit conversions
const fToC = (f) => Math.round(((f - 32) * 5 / 9) * 100) / 100;
const inHgToHpa = (inhg) => Math.round(inhg * 33.8639 * 100) / 100;
const mphToKmh = (mph) => Math.round(mph * 1.60934 * 100) / 100;
const inToMm = (inch) => Math.round(inch * 25.4 * 100) / 100;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

async function davisCall(endpoint) {
  const t = Math.floor(Date.now() / 1000);
  const params = { 'api-key': DAVIS_API_KEY, 't': t.toString() };
  const qs = Object.entries(params).map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
  const url = `${DAVIS_BASE}${endpoint}?${qs}`;

  const res = await fetch(url, {
    headers: {
      'X-Api-Secret': DAVIS_API_SECRET,
      'Accept': 'application/json',
    }
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Davis API ${res.status}: ${text}`);
  }
  return await res.json();
}

function parseSensorData(data) {
  const sensors = data.sensors || [];
  const result = {
    ts: null, temp_c: null, humidity: null, wind_speed_kmh: null,
    wind_dir: null, bar_hpa: null, bar_trend_hpa: null, rain_rate_mm: null,
    dew_point_c: null, feels_like_c: null,
  };

  for (const sensor of sensors) {
    if (!sensor.data || !sensor.data.length) continue;
    const d = sensor.data[0];

    if (d.temp !== undefined && d.temp !== null) {
      result.temp_c = fToC(d.temp);
      result.ts = d.ts;
    }
    if (d.hum !== undefined && d.hum !== null) result.humidity = d.hum;
    if (d.wind_speed_last !== undefined && d.wind_speed_last !== null) result.wind_speed_kmh = mphToKmh(d.wind_speed_last);
    if (d.wind_speed_avg_last_2_min !== undefined && result.wind_speed_kmh === null) result.wind_speed_kmh = mphToKmh(d.wind_speed_avg_last_2_min);
    if (d.wind_dir_last !== undefined && d.wind_dir_last !== null) result.wind_dir = d.wind_dir_last;
    if (d.rain_rate_last_mm !== undefined && d.rain_rate_last_mm !== null) result.rain_rate_mm = d.rain_rate_last_mm;
    if (d.dew_point !== undefined && d.dew_point !== null) result.dew_point_c = fToC(d.dew_point);
    if (d.heat_index !== undefined && d.heat_index !== null) result.feels_like_c = fToC(d.heat_index);
    if (d.wind_chill !== undefined && d.wind_chill !== null && result.feels_like_c === null) result.feels_like_c = fToC(d.wind_chill);
    if (d.bar_sea_level !== undefined && d.bar_sea_level !== null) result.bar_hpa = inHgToHpa(d.bar_sea_level);
    if (d.bar_trend !== undefined && d.bar_trend !== null) result.bar_trend_hpa = inHgToHpa(d.bar_trend);
  }

  return result;
}

// Bounds check: reject readings outside physical range for Sarawak
function validateReading(parsed) {
  if (parsed.ts == null) return 'missing davis_ts';
  if (parsed.temp_c == null) return 'missing temp_c';
  if (parsed.temp_c < 15 || parsed.temp_c > 50) return `temp_c out of range: ${parsed.temp_c}`;
  if (parsed.humidity != null && (parsed.humidity < 0 || parsed.humidity > 100)) return `humidity out of range: ${parsed.humidity}`;
  if (parsed.wind_speed_kmh != null && parsed.wind_speed_kmh > 200) return `wind out of range: ${parsed.wind_speed_kmh}`;
  if (parsed.rain_rate_mm != null && parsed.rain_rate_mm > 500) return `rain rate out of range: ${parsed.rain_rate_mm}`;
  // Reject readings older than 1 hour (stale data from cloud)
  const ageSeconds = Math.floor(Date.now() / 1000) - parsed.ts;
  if (ageSeconds > 3600) return `reading too old: ${Math.round(ageSeconds / 60)} mins`;
  return null;
}

async function storeReading(parsed, raw) {
  if (!SUPABASE_SERVICE_KEY) {
    console.log('No SUPABASE_SERVICE_KEY set, skipping DB storage');
    return { stored: false, reason: 'no_key' };
  }
  try {
    // Validate before storing
    const invalid = validateReading(parsed);
    if (invalid) {
      console.log('Skipping invalid reading:', invalid);
      return { stored: false, reason: invalid };
    }

    // Skip if davis_ts already exists (duplicate reading)
    const lastRes = await fetch(
      `${SUPABASE_URL}/rest/v1/station_readings?select=davis_ts&order=ts.desc&limit=1`,
      { headers: { 'apikey': SUPABASE_SERVICE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}` } }
    );
    if (lastRes.ok) {
      const lastRows = await lastRes.json();
      if (lastRows.length > 0 && lastRows[0].davis_ts === parsed.ts) {
        console.log('Skipping duplicate davis_ts:', parsed.ts);
        return { stored: false, reason: 'duplicate_davis_ts' };
      }
    }

    const body = {
      davis_ts: parsed.ts,
      temp_c: parsed.temp_c,
      humidity: parsed.humidity,
      wind_speed_kmh: parsed.wind_speed_kmh,
      wind_dir: parsed.wind_dir,
      bar_hpa: parsed.bar_hpa,
      rain_rate_mm: parsed.rain_rate_mm,
      dew_point_c: parsed.dew_point_c,
      feels_like_c: parsed.feels_like_c,
      raw_json: raw,
    };
    console.log('Storing reading to Supabase:', JSON.stringify(body).substring(0, 200));
    const res = await fetch(`${SUPABASE_URL}/rest/v1/station_readings`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const errText = await res.text();
      console.error('DB insert error:', res.status, errText);
      return { stored: false, reason: `${res.status}: ${errText}` };
    }
    console.log('Reading stored successfully');
    return { stored: true };
  } catch (e) {
    console.error('Store reading exception:', e.message);
    return { stored: false, reason: e.message };
  }
}

async function fetchHistory(hours) {
  if (!SUPABASE_SERVICE_KEY) {
    return { readings: [], count: 0, error: 'No service key configured' };
  }
  const since = new Date(Date.now() - hours * 3600000).toISOString();
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/station_readings?ts=gte.${since}&order=ts.asc`,
    {
      headers: {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      }
    }
  );
  if (!res.ok) throw new Error(`Supabase ${res.status}`);
  const data = await res.json();
  return { readings: data, count: data.length };
}

exports.handler = async (event) => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders, body: '' };
  }

  const params = event.queryStringParameters || {};
  const action = params.action || 'current';

  try {
    if (action === 'stations') {
      const data = await davisCall('/stations');
      return {
        statusCode: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      };
    }

    if (action === 'current') {
      let stationId = params.station_id;

      if (!stationId) {
        const stations = await davisCall('/stations');
        if (!stations.stations || !stations.stations.length) {
          return {
            statusCode: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'No stations found' }),
          };
        }
        stationId = stations.stations[0].station_id;
      }

      const data = await davisCall(`/current/${stationId}`);
      const parsed = parseSensorData(data);
      
      // Store in Supabase (must await — Netlify kills function after response)
      const storeResult = await storeReading(parsed, data);

      return {
        statusCode: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          station_id: stationId,
          ...parsed,
          _storage: storeResult,
          raw: data,
        }),
      };
    }

    if (action === 'history') {
      const hours = parseInt(params.hours || '24');
      const result = await fetchHistory(hours);
      return {
        statusCode: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        body: JSON.stringify(result),
      };
    }

    return {
      statusCode: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Unknown action. Use: current, stations, history' }),
    };

  } catch (err) {
    console.error('Function error:', err);
    return {
      statusCode: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: err.message }),
    };
  }
};
