// One-shot schema verification for the inventory AI FK migration.
// Reads column types of products + pnd_ingredients + pnd_product_ingredients
// so the migration SQL targets the right types. Read-only.

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

const tables = ['products', 'pnd_ingredients', 'pnd_product_ingredients', 'pnd_products'];

for (const t of tables) {
  const r = await client.query(
    `select column_name, data_type, is_nullable, column_default
       from information_schema.columns
      where table_schema = 'public' and table_name = $1
      order by ordinal_position`,
    [t]
  );
  console.log(`\n=== ${t} ===`);
  for (const c of r.rows) {
    console.log(`  ${c.column_name.padEnd(30)} ${c.data_type.padEnd(20)} nullable=${c.is_nullable}  default=${c.column_default ?? ''}`);
  }
}

// Row counts and AI distribution
const counts = await client.query(`
  select
    (select count(*) from products) as products_total,
    (select count(*) from products where archived is not true) as products_active,
    (select count(*) from products where active_ingredient is not null and active_ingredient <> '') as products_with_ai_text,
    (select count(*) from pnd_ingredients) as pnd_ingredients_total,
    (select count(*) from pnd_product_ingredients) as junction_total,
    (select count(*) from pnd_products where inventory_product_id is not null) as pnd_products_linked
`);
console.log('\n=== counts ===');
console.log(counts.rows[0]);

// Sample distinct active_ingredient values
const distincts = await client.query(`
  select active_ingredient, count(*) as n, array_agg(distinct company_id) as companies
    from products
   where active_ingredient is not null and active_ingredient <> ''
   group by active_ingredient
   order by lower(active_ingredient)
`);
console.log(`\n=== distinct products.active_ingredient values (${distincts.rows.length} unique) ===`);
for (const d of distincts.rows) {
  console.log(`  "${d.active_ingredient}".padEnd(40) — count=${d.n}, companies=[${d.companies.join(', ')}]`);
}

// pnd_ingredients per company
const ingByCompany = await client.query(`
  select company_id, count(*) as n, array_agg(name order by name) as names
    from pnd_ingredients
   group by company_id
`);
console.log('\n=== pnd_ingredients per company ===');
for (const r of ingByCompany.rows) {
  console.log(`  ${r.company_id}: ${r.n} ingredients`);
  console.log(`    ${r.names.slice(0, 30).join(' · ')}${r.names.length > 30 ? ` … (+${r.names.length - 30} more)` : ''}`);
}

await client.end();
