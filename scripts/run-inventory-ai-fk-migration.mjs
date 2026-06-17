// One-shot runner for supabase/inventory_ai_fk_migration.sql.
// Verifies pre + post state. Idempotent (the SQL uses IF NOT EXISTS).

import pg from 'pg';
import { readFileSync } from 'node:fs';

const client = new pg.Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 5432,
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

await client.connect();

const pre = await client.query(`
  select column_name from information_schema.columns
   where table_schema='public' and table_name='products' and column_name='active_ingredient_id'
`);
console.log(`PRE: active_ingredient_id column exists? ${pre.rows.length > 0}`);

const sql = readFileSync('supabase/inventory_ai_fk_migration.sql', 'utf8');
console.log('Running migration SQL...');
await client.query(sql);

const post = await client.query(`
  select column_name, data_type, is_nullable
    from information_schema.columns
   where table_schema='public' and table_name='products' and column_name='active_ingredient_id'
`);
console.log(`POST: ${JSON.stringify(post.rows[0])}`);

const idx = await client.query(`
  select indexname from pg_indexes
   where schemaname='public' and tablename='products' and indexname='idx_products_active_ingredient_id'
`);
console.log(`POST: index exists? ${idx.rows.length > 0}`);

const fk = await client.query(`
  select conname, pg_get_constraintdef(oid) as def
    from pg_constraint
   where conrelid = 'public.products'::regclass and contype = 'f'
     and pg_get_constraintdef(oid) like '%active_ingredient_id%'
`);
console.log(`POST: FK constraint: ${fk.rows.length > 0 ? fk.rows[0].def : 'MISSING'}`);

console.log('\nMigration complete.');
await client.end();
