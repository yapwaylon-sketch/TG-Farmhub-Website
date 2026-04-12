const https = require('https');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const SITE_ID = 'a0ac5d18-a968-414c-a531-c78ed390e5c2';
const TOKEN = 'nfp_yaBfBRGpgUKcrKrEoZzWS2aY5cC6Ytqm4c26';
const SKIP = ['node_modules', '.git', 'TG Nanas Growth TV', 'TG Weather Monitoring Website', '.claude', '.superpowers', '_deploy.js', 'deploy.tar'];

function walkDir(dir, base) {
  let results = {};
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relPath = (base + '/' + entry.name);
    if (entry.isDirectory()) {
      if (SKIP.includes(entry.name)) continue;
      Object.assign(results, walkDir(fullPath, relPath));
    } else {
      if (SKIP.includes(entry.name)) continue;
      const content = fs.readFileSync(fullPath);
      const hash = crypto.createHash('sha1').update(content).digest('hex');
      results[relPath] = hash;
    }
  }
  return results;
}

function apiRequest(method, apiPath, body) {
  return new Promise((resolve, reject) => {
    const isJSON = typeof body === 'string';
    const opts = {
      hostname: 'api.netlify.com',
      path: apiPath,
      method: method,
      headers: {
        'Authorization': 'Bearer ' + TOKEN,
        'Content-Type': isJSON ? 'application/json' : 'application/octet-stream',
      }
    };
    if (body) opts.headers['Content-Length'] = Buffer.isBuffer(body) ? body.length : Buffer.byteLength(body);
    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch(e) { resolve(data); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function main() {
  const files = walkDir('.', '');
  console.log('Total files:', Object.keys(files).length);

  // Create deploy
  const deploy = await apiRequest('POST', '/api/v1/sites/' + SITE_ID + '/deploys', JSON.stringify({ files }));
  console.log('Deploy ID:', deploy.id, 'State:', deploy.state);

  const required = deploy.required || [];
  console.log('Files to upload:', required.length);

  // Build hash -> path map
  const hashToPath = {};
  for (const [fpath, hash] of Object.entries(files)) {
    hashToPath[hash] = fpath;
  }

  // Upload required files
  for (const hash of required) {
    const filePath = hashToPath[hash];
    if (!filePath) { console.log('Unknown hash:', hash); continue; }
    const content = fs.readFileSync('.' + filePath);
    await apiRequest('PUT', '/api/v1/deploys/' + deploy.id + '/files' + filePath, content);
    console.log('Uploaded:', filePath, '(' + content.length + ' bytes)');
  }

  // Check status
  const status = await apiRequest('GET', '/api/v1/deploys/' + deploy.id);
  console.log('Final state:', status.state, status.ssl_url || status.url);
}

main().catch(e => console.error(e));
