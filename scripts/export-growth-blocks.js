const { Client } = require('pg');
const XLSX = require('xlsx');
const path = require('path');

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

  const sql = `
    SELECT
      b.block_name                                     AS "Block",
      v.name                                           AS "Variety",
      to_char(bc.date_planted, 'YYYY-MM-DD')           AS "Date Planted",
      bc.quantity                                      AS "Plants",
      s.name                                           AS "Status",
      bc.cycle                                         AS "Cycle",
      CASE WHEN b.is_active THEN 'Yes' ELSE 'No' END   AS "Active"
    FROM pnd_blocks b
    LEFT JOIN block_crops bc ON bc.block_id = b.id AND bc.is_current = TRUE
    LEFT JOIN crop_varieties v ON v.id = bc.variety_id
    LEFT JOIN crop_statuses s ON s.id = bc.status_id
    ORDER BY b.is_active DESC, b.sort_order NULLS LAST, b.block_name;
  `;

  const { rows } = await client.query(sql);
  console.log(`Pulled ${rows.length} block rows.`);

  const ws = XLSX.utils.json_to_sheet(rows, {
    header: ['Block', 'Variety', 'Date Planted', 'Plants', 'Status', 'Cycle', 'Active'],
  });

  ws['!cols'] = [
    { wch: 14 }, // Block
    { wch: 12 }, // Variety
    { wch: 14 }, // Date Planted
    { wch: 10 }, // Plants
    { wch: 14 }, // Status
    { wch: 8 },  // Cycle
    { wch: 8 },  // Active
  ];

  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Growth Blocks');

  const out = path.join(__dirname, '..', 'growth-blocks-export.xlsx');
  XLSX.writeFile(wb, out);
  console.log(`Wrote ${out}`);

  await client.end();
})().catch(e => { console.error(e); process.exit(1); });
