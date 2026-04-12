// ═══════════════════════════════════════════════════════════════
// TG Agribusiness — Scheduled Weather Logger (every 15 minutes)
// ═══════════════════════════════════════════════════════════════
// 1. Fetches Davis station reading → stores in station_readings
// 2. Fetches current model predictions → stores in model_snapshots
// This builds the dataset needed for bias correction
// ═══════════════════════════════════════════════════════════════

const DAVIS_API_KEY = 'aufrbtqkykcwktihemyipk1e6di6xw7b';
const DAVIS_API_SECRET = 'sqtldzcqjvspovha6vseekw6pr51avpl';
const DAVIS_BASE = 'https://api.weatherlink.com/v2';

const SUPABASE_URL = 'https://qwlagcriiyoflseduvvc.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE';

const OM_BASE = 'https://api.open-meteo.com';
const CENTER = { lat: 4.2723, lon: 113.9495 };

const MODELS = [
  { id: 'ecmwf', label: 'ECMWF', extra: '&models=ecmwf_ifs025' },
  { id: 'gfs',   label: 'GFS',   extra: '&models=gfs_seamless' },
  { id: 'icon',  label: 'ICON',  extra: '&models=icon_seamless' },
];

// Unit conversions
const fToC = (f) => Math.round(((f - 32) * 5 / 9) * 100) / 100;
const inHgToHpa = (inhg) => Math.round(inhg * 33.8639 * 100) / 100;
const mphToKmh = (mph) => Math.round(mph * 1.60934 * 100) / 100;
const inToMm = (inch) => Math.round(inch * 25.4 * 100) / 100;

// ═══════════════════════════════════════════════════════════════
// Davis API
// ═══════════════════════════════════════════════════════════════
async function davisCall(endpoint) {
  const t = Math.floor(Date.now() / 1000);
  const params = { 'api-key': DAVIS_API_KEY, 't': t.toString() };
  const qs = Object.entries(params).map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&');
  const url = `${DAVIS_BASE}${endpoint}?${qs}`;
  const res = await fetch(url, {
    headers: { 'X-Api-Secret': DAVIS_API_SECRET, 'Accept': 'application/json' }
  });
  if (!res.ok) throw new Error(`Davis API ${res.status}: ${await res.text()}`);
  return await res.json();
}

function parseSensorData(data) {
  const sensors = data.sensors || [];
  const result = {
    ts: null, temp_c: null, humidity: null, wind_speed_kmh: null,
    wind_dir: null, bar_hpa: null, rain_rate_mm: null,
    dew_point_c: null, feels_like_c: null,
  };
  for (const sensor of sensors) {
    if (!sensor.data || !sensor.data.length) continue;
    const d = sensor.data[0];
    if (d.temp !== undefined && d.temp !== null) { result.temp_c = fToC(d.temp); result.ts = d.ts; }
    if (d.hum !== undefined && d.hum !== null) result.humidity = d.hum;
    if (d.wind_speed_last !== undefined && d.wind_speed_last !== null) result.wind_speed_kmh = mphToKmh(d.wind_speed_last);
    if (d.wind_speed_avg_last_2_min !== undefined && result.wind_speed_kmh === null) result.wind_speed_kmh = mphToKmh(d.wind_speed_avg_last_2_min);
    if (d.wind_dir_last !== undefined && d.wind_dir_last !== null) result.wind_dir = d.wind_dir_last;
    if (d.rain_rate_last_mm !== undefined && d.rain_rate_last_mm !== null) result.rain_rate_mm = d.rain_rate_last_mm;
    if (d.dew_point !== undefined && d.dew_point !== null) result.dew_point_c = fToC(d.dew_point);
    if (d.heat_index !== undefined && d.heat_index !== null) result.feels_like_c = fToC(d.heat_index);
    if (d.wind_chill !== undefined && d.wind_chill !== null && result.feels_like_c === null) result.feels_like_c = fToC(d.wind_chill);
    if (d.bar_sea_level !== undefined && d.bar_sea_level !== null) result.bar_hpa = inHgToHpa(d.bar_sea_level);
  }
  return result;
}

// ═══════════════════════════════════════════════════════════════
// Open-Meteo: Fetch current + short-range forecast per model
// ═══════════════════════════════════════════════════════════════
async function fetchModelPredictions() {
  const results = [];

  for (const model of MODELS) {
    try {
      const url = `${OM_BASE}/v1/forecast?latitude=${CENTER.lat}&longitude=${CENTER.lon}` +
        `&current=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,weather_code` +
        `&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation_probability,precipitation` +
        `&forecast_hours=168` +
        `&timezone=Asia/Kuching` +
        model.extra;

      const res = await fetch(url);
      if (!res.ok) {
        console.warn(`${model.label} API error: ${res.status}`);
        continue;
      }
      const data = await res.json();

      // Current conditions from model (forecast_hour = 0)
      results.push({
        model: model.id,
        forecast_hour: 0,
        temp_c: data.current?.temperature_2m ?? null,
        humidity: data.current?.relative_humidity_2m ?? null,
        wind_speed_kmh: data.current?.wind_speed_10m ?? null,
        precip_mm: data.current?.precipitation ?? null,
        weather_code: data.current?.weather_code ?? null,
      });

      // Hourly forecasts at key intervals
      const forecastHours = [1, 2, 3, 4, 6, 12, 24, 48, 72, 168];
      const hourly = data.hourly;
      if (hourly && hourly.time) {
        for (const h of forecastHours) {
          if (h < hourly.time.length) {
            results.push({
              model: model.id,
              forecast_hour: h,
              temp_c: hourly.temperature_2m?.[h] ?? null,
              humidity: hourly.relative_humidity_2m?.[h] ?? null,
              wind_speed_kmh: hourly.wind_speed_10m?.[h] ?? null,
              precip_mm: hourly.precipitation?.[h] ?? null,
              weather_code: null,
            });
          }
        }
      }
    } catch (e) {
      console.warn(`${model.label} fetch error:`, e.message);
    }
  }

  return results;
}

// ═══════════════════════════════════════════════════════════════
// Bounds validation
// ═══════════════════════════════════════════════════════════════
function validateReading(parsed) {
  if (parsed.ts == null) return 'missing davis_ts';
  if (parsed.temp_c == null) return 'missing temp_c';
  if (parsed.temp_c < 15 || parsed.temp_c > 50) return `temp_c out of range: ${parsed.temp_c}`;
  if (parsed.humidity != null && (parsed.humidity < 0 || parsed.humidity > 100)) return `humidity out of range: ${parsed.humidity}`;
  if (parsed.wind_speed_kmh != null && parsed.wind_speed_kmh > 200) return `wind out of range: ${parsed.wind_speed_kmh}`;
  if (parsed.rain_rate_mm != null && parsed.rain_rate_mm > 500) return `rain rate out of range: ${parsed.rain_rate_mm}`;
  const ageSeconds = Math.floor(Date.now() / 1000) - parsed.ts;
  if (ageSeconds > 3600) return `reading too old: ${Math.round(ageSeconds / 60)} mins`;
  return null;
}

// ═══════════════════════════════════════════════════════════════
// Supabase storage
// ═══════════════════════════════════════════════════════════════
async function supabaseInsert(table, rows) {
  const body = Array.isArray(rows) ? rows : [rows];
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
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
    throw new Error(`Supabase ${table}: ${res.status} ${errText}`);
  }
  return true;
}

// ═══════════════════════════════════════════════════════════════
// Main handler
// ═══════════════════════════════════════════════════════════════
exports.handler = async (event) => {
  const startTime = Date.now();
  console.log('Scheduled logger running at', new Date().toISOString());

  const status = { davis: false, models: false, model_count: 0, errors: [] };

  // ── 1. Fetch and store Davis station reading ──
  try {
    const stations = await davisCall('/stations');
    if (!stations.stations || !stations.stations.length) throw new Error('No stations found');
    const stationId = stations.stations[0].station_id;

    const data = await davisCall(`/current/${stationId}`);
    const parsed = parseSensorData(data);

    // Validate reading before storing
    const invalid = validateReading(parsed);
    if (invalid) {
      console.log('Skipping invalid reading:', invalid);
    } else {
      // Skip if davis_ts already exists (duplicate)
      const lastRes = await fetch(
        `${SUPABASE_URL}/rest/v1/station_readings?select=davis_ts&order=ts.desc&limit=1`,
        { headers: { 'apikey': SUPABASE_SERVICE_KEY, 'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}` } }
      );
      let isDuplicate = false;
      if (lastRes.ok) {
        const lastRows = await lastRes.json();
        if (lastRows.length > 0 && lastRows[0].davis_ts === parsed.ts) {
          isDuplicate = true;
          console.log('Skipping duplicate davis_ts:', parsed.ts);
        }
      }

      if (!isDuplicate) {
        await supabaseInsert('station_readings', {
          davis_ts: parsed.ts,
          temp_c: parsed.temp_c,
          humidity: parsed.humidity,
          wind_speed_kmh: parsed.wind_speed_kmh,
          wind_dir: parsed.wind_dir,
          bar_hpa: parsed.bar_hpa,
          rain_rate_mm: parsed.rain_rate_mm,
          dew_point_c: parsed.dew_point_c,
          feels_like_c: parsed.feels_like_c,
          raw_json: data,
        });
        status.davis = true;
        console.log('Davis stored:', parsed.temp_c + '°C', parsed.humidity + '%');
      }
    }
  } catch (e) {
    console.error('Davis error:', e.message);
    status.errors.push('davis: ' + e.message);
  }

  // ── 2. Fetch and store model predictions ──
  try {
    const predictions = await fetchModelPredictions();

    if (predictions.length > 0) {
      const rows = predictions.map(p => ({
        model: p.model,
        forecast_hour: p.forecast_hour,
        temp_c: p.temp_c,
        humidity: p.humidity,
        wind_speed_kmh: p.wind_speed_kmh,
        precip_mm: p.precip_mm,
        weather_code: p.weather_code,
      }));

      await supabaseInsert('model_snapshots', rows);
      status.models = true;
      status.model_count = rows.length;
      console.log(`Stored ${rows.length} model snapshots`);
    }
  } catch (e) {
    console.error('Model error:', e.message);
    status.errors.push('models: ' + e.message);
  }

  const elapsed = Date.now() - startTime;
  console.log(`Done in ${elapsed}ms. Davis: ${status.davis}, Models: ${status.models} (${status.model_count} rows)`);

  return {
    statusCode: 200,
    body: JSON.stringify({ ...status, elapsed_ms: elapsed }),
  };
};

// Run every 15 minutes
exports.config = {
  schedule: "*/15 * * * *"
};
