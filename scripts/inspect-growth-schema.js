const { Client } = require('pg');

const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 5432,
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  database: 'postgres',
  ssl: { rejectUnauthorized: false },
});

(async () => {
  await client.connect();
  const tables = ['pnd_blocks', 'block_crops', 'crop_statuses', 'crop_varieties', 'growth_records'];
  for (const t of tables) {
    const r = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema='public' AND table_name=$1
      ORDER BY ordinal_position
    `, [t]);
    console.log(`\n== ${t} ==`);
    r.rows.forEach(c => console.log(`  ${c.column_name}: ${c.data_type}`));
  }
  await client.end();
})().catch(e => { console.error(e); process.exit(1); });
