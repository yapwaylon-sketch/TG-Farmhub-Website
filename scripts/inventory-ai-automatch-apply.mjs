// APPLY — mirrors inventory-ai-automatch-dryrun.mjs's logic, then writes
// products.active_ingredient_id for everything in the high/medium-confidence buckets
// (junction, exact, fuzzy-1). Skips ambiguous-fuzzy / no-match / empty.
//
// Re-runnable: only updates rows where active_ingredient_id IS NULL AND we'd write
// a different value. Already-populated rows are left alone.

import pg from 'pg';

const client = new pg.Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 5432,
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

await client.connect();

const products = (await client.query(`
  select id, name, active_ingredient, active_ingredient_id, company_id, archived
    from products
   order by name
`)).rows;

const ingredients = (await client.query(`select id, name, company_id from pnd_ingredients`)).rows;

const junction = (await client.query(`
  select pp.inventory_product_id as inv_id,
         ppi.ingredient_id,
         pi.name as ingredient_name
    from pnd_products pp
    join pnd_product_ingredients ppi on ppi.product_id = pp.id
    join pnd_ingredients pi on pi.id = ppi.ingredient_id
   where pp.inventory_product_id is not null
   order by pp.inventory_product_id, ppi.created_at
`)).rows;

const junctionByProduct = new Map();
for (const j of junction) {
  if (!junctionByProduct.has(j.inv_id)) junctionByProduct.set(j.inv_id, []);
  junctionByProduct.get(j.inv_id).push({ id: j.ingredient_id, name: j.ingredient_name });
}
const ingsByCompany = new Map();
for (const ing of ingredients) {
  const key = ing.company_id || '_';
  if (!ingsByCompany.has(key)) ingsByCompany.set(key, []);
  ingsByCompany.get(key).push(ing);
}
const norm = s => (s || '').trim().toLowerCase().replace(/\s+/g, ' ');
function lev(a, b) {
  if (a === b) return 0;
  if (!a.length) return b.length;
  if (!b.length) return a.length;
  const m = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
  for (let i = 0; i <= a.length; i++) m[i][0] = i;
  for (let j = 0; j <= b.length; j++) m[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      m[i][j] = Math.min(m[i - 1][j] + 1, m[i][j - 1] + 1, m[i - 1][j - 1] + cost);
    }
  }
  return m[a.length][b.length];
}

function matchProduct(p) {
  const j = junctionByProduct.get(p.id);
  if (j && j.length > 0) return { tier: 'junction', id: j[0].id, name: j[0].name };
  const raw = (p.active_ingredient || '').trim();
  if (!raw) return { tier: 'no-ai-text', id: null, name: null };
  const target = norm(raw);
  const pool = ingsByCompany.get(p.company_id) || [];
  const exact = pool.find(i => norm(i.name) === target);
  if (exact) return { tier: 'exact', id: exact.id, name: exact.name };
  const fuzzy = pool.map(i => ({ i, d: lev(target, norm(i.name)) })).filter(x => x.d <= 2).sort((a, b) => a.d - b.d);
  if (fuzzy.length === 1) return { tier: 'fuzzy-1', id: fuzzy[0].i.id, name: fuzzy[0].i.name };
  if (fuzzy.length > 1) return { tier: 'fuzzy-ambiguous', id: null, name: null };
  return { tier: 'no-match', id: null, name: null };
}

const writes = [];
const skips = [];
for (const p of products) {
  const m = matchProduct(p);
  const writable = ['junction', 'exact', 'fuzzy-1'].includes(m.tier);
  if (!writable) { skips.push({ p, m, reason: m.tier }); continue; }
  if (p.active_ingredient_id === m.id) { skips.push({ p, m, reason: 'already-set' }); continue; }
  writes.push({ p, m });
}

console.log(`Total products: ${products.length}`);
console.log(`To write: ${writes.length}`);
console.log(`To skip: ${skips.length}`);

if (writes.length === 0) {
  console.log('Nothing to do.');
  await client.end();
  process.exit(0);
}

// Wrap in a transaction. Either everything or nothing.
await client.query('begin');
let n = 0;
try {
  for (const { p, m } of writes) {
    const r = await client.query(
      `update products set active_ingredient_id = $1 where id = $2 and (active_ingredient_id is null or active_ingredient_id <> $1)`,
      [m.id, p.id]
    );
    if (r.rowCount === 1) n++;
    console.log(`  ✓ ${p.name.padEnd(40)} → ${m.name} (${m.tier})`);
  }
  await client.query('commit');
  console.log(`\nCommitted ${n} updates.`);
} catch (e) {
  await client.query('rollback');
  console.error('Rolled back:', e.message);
  process.exit(1);
}

// Post-write verification.
const post = await client.query(`
  select
    count(*) as total,
    count(active_ingredient_id) as with_fk,
    count(*) filter (where active_ingredient_id is null and active_ingredient is not null and active_ingredient <> '') as unmapped_with_text,
    count(*) filter (where active_ingredient is null or active_ingredient = '') as no_text
  from products
`);
console.log('\nPOST verification:');
console.log(post.rows[0]);

await client.end();
