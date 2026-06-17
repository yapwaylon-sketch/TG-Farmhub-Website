// DRY-RUN. No writes. Computes the proposed active_ingredient_id for every product
// using a 3-tier match strategy and prints the result for human eyeball before any
// production write.
//
// Match priority per product:
//   1. SPRAY JUNCTION — if products.id is linked to a pnd_products row that has rows
//      in pnd_product_ingredients, use the first ingredient_id from that junction.
//      Highest confidence: this is the existing spray-system truth.
//   2. EXACT NAME — case-insensitive, whitespace-collapsed match of
//      products.active_ingredient against pnd_ingredients.name within the same
//      company_id.
//   3. FUZZY — Levenshtein distance ≤ 2 against pnd_ingredients.name, only if
//      exactly ONE candidate qualifies (multi-candidate fuzzy = "needs review").
//
// Anything that doesn't match any of the above is left for manual review.

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

// Load all data we need in one pass.
const products = (await client.query(`
  select id, name, active_ingredient, company_id, archived
    from products
   order by archived nulls first, name
`)).rows;

const ingredients = (await client.query(`
  select id, name, company_id from pnd_ingredients
`)).rows;

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

// Build lookup maps for speed.
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

// Levenshtein distance — small inputs, simple O(n*m) is fine.
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
  // Tier 1 — spray junction.
  const j = junctionByProduct.get(p.id);
  if (j && j.length > 0) {
    return {
      tier: 'junction',
      confidence: 'high',
      matched_id: j[0].id,
      matched_name: j[0].name,
      note: j.length > 1 ? `(${j.length} AIs in junction — using first: ${j.map(x => x.name).join(', ')})` : '',
    };
  }
  const raw = (p.active_ingredient || '').trim();
  if (!raw) {
    return { tier: 'no-ai-text', confidence: 'none', matched_id: null, matched_name: null, note: 'products.active_ingredient is empty — leave NULL' };
  }
  const target = norm(raw);
  const pool = ingsByCompany.get(p.company_id) || [];

  // Tier 2 — exact case-insensitive name match within the same company.
  const exact = pool.find(i => norm(i.name) === target);
  if (exact) {
    return { tier: 'exact', confidence: 'high', matched_id: exact.id, matched_name: exact.name, note: '' };
  }

  // Tier 3 — fuzzy Levenshtein ≤ 2, only if exactly one candidate.
  const fuzzy = pool
    .map(i => ({ i, d: lev(target, norm(i.name)) }))
    .filter(x => x.d <= 2)
    .sort((a, b) => a.d - b.d);
  if (fuzzy.length === 1) {
    return { tier: 'fuzzy-1', confidence: 'medium', matched_id: fuzzy[0].i.id, matched_name: fuzzy[0].i.name, note: `Levenshtein=${fuzzy[0].d}` };
  }
  if (fuzzy.length > 1) {
    return { tier: 'fuzzy-ambiguous', confidence: 'low', matched_id: null, matched_name: null, note: `${fuzzy.length} candidates within Lev≤2: ${fuzzy.slice(0, 3).map(x => `${x.i.name}(d=${x.d})`).join(', ')}` };
  }

  return { tier: 'no-match', confidence: 'none', matched_id: null, matched_name: null, note: `no pnd_ingredients row within Lev≤2 of "${raw}"` };
}

const buckets = { junction: [], exact: [], 'fuzzy-1': [], 'fuzzy-ambiguous': [], 'no-match': [], 'no-ai-text': [] };

for (const p of products) {
  const m = matchProduct(p);
  buckets[m.tier].push({ p, m });
}

console.log('\n=== AUTO-MATCH DRY-RUN ===');
console.log(`Total products: ${products.length}`);
for (const tier of ['junction', 'exact', 'fuzzy-1', 'fuzzy-ambiguous', 'no-match', 'no-ai-text']) {
  console.log(`  ${tier.padEnd(20)} ${buckets[tier].length}`);
}

function printBucket(tier, label) {
  if (buckets[tier].length === 0) return;
  console.log(`\n--- ${label} (${buckets[tier].length}) ---`);
  for (const { p, m } of buckets[tier]) {
    const prodLabel = `${p.name}${p.archived ? ' [archived]' : ''}`;
    console.log(`  • ${prodLabel}`);
    console.log(`      products.active_ingredient: "${p.active_ingredient || '(empty)'}"`);
    if (m.matched_name) console.log(`      → ${m.matched_name}  (id=${m.matched_id})`);
    if (m.note) console.log(`      note: ${m.note}`);
  }
}

printBucket('junction', 'Tier 1 — matched via spray junction (HIGHEST confidence)');
printBucket('exact', 'Tier 2 — matched via exact name (within company, case-insensitive)');
printBucket('fuzzy-1', 'Tier 3 — fuzzy match, single candidate (medium confidence — review me)');
printBucket('fuzzy-ambiguous', 'NEEDS REVIEW — multiple fuzzy candidates');
printBucket('no-match', 'NEEDS REVIEW — no match within Levenshtein ≤ 2');
printBucket('no-ai-text', 'NO AI TEXT — products.active_ingredient was empty (leave NULL)');

const writable = buckets.junction.length + buckets.exact.length + buckets['fuzzy-1'].length;
const review = buckets['fuzzy-ambiguous'].length + buckets['no-match'].length;
const skipped = buckets['no-ai-text'].length;

console.log('\n=== SUMMARY ===');
console.log(`Would write ${writable} active_ingredient_id values:`);
console.log(`  ${buckets.junction.length} via spray junction (highest confidence)`);
console.log(`  ${buckets.exact.length} via exact name match`);
console.log(`  ${buckets['fuzzy-1'].length} via single fuzzy candidate (Lev≤2)`);
console.log(`Would NOT write ${review + skipped} (need manual review or genuinely no AI):`);
console.log(`  ${buckets['fuzzy-ambiguous'].length} ambiguous fuzzy`);
console.log(`  ${buckets['no-match'].length} no match found`);
console.log(`  ${buckets['no-ai-text'].length} no AI text (legitimately empty)`);
console.log('\n*** DRY-RUN COMPLETE — NOTHING WAS WRITTEN ***\n');

await client.end();
