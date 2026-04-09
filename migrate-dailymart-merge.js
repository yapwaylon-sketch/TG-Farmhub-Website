const { Client } = require('pg');

const client = new Client({
  host: 'aws-1-ap-northeast-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: 'postgres.qwlagcriiyoflseduvvc',
  password: 'Hlfqdbi6wcM4Omsm',
  ssl: { rejectUnauthorized: false },
});

async function migrate() {
  await client.connect();
  console.log('Connected to database.\n');

  try {
    // ─── 1. Find DailyMart customers ─────────────────────────────────────────
    const { rows: customers } = await client.query(`
      SELECT id, name, registration_name, phone, address, type, channel,
             payment_terms, payment_terms_days, notes, is_active, company_id,
             ssm_brn, tin, ic_number, credit_limit, currency
      FROM sales_customers
      WHERE name ILIKE '%dailymart%' OR name ILIKE '%daily mart%'
      ORDER BY id
    `);

    if (customers.length !== 2) {
      throw new Error(`Expected exactly 2 DailyMart customers, found ${customers.length}: ${customers.map(c => `${c.id} ${c.name}`).join(', ')}`);
    }

    console.log('Found customers:');
    customers.forEach(c => console.log(`  ${c.id}: ${c.name}`));
    console.log();

    // Determine keep vs lose based on name (Boulevard = keep, Times Square = lose)
    const boulevard = customers.find(c =>
      c.name.toLowerCase().includes('boulevard') ||
      (!c.name.toLowerCase().includes('times') && !c.name.toLowerCase().includes('square'))
    );
    const timesSquare = customers.find(c =>
      c.name.toLowerCase().includes('times') || c.name.toLowerCase().includes('square')
    );

    if (!boulevard || !timesSquare) {
      throw new Error(`Could not identify Boulevard vs Times Square from names: ${customers.map(c => c.name).join(', ')}`);
    }

    const KEEP = boulevard;   // will become the merged HQ record
    const LOSE = timesSquare; // will be deactivated

    console.log(`KEEP (Boulevard → HQ): ${KEEP.id} "${KEEP.name}"`);
    console.log(`LOSE (Times Square → merge into keep): ${LOSE.id} "${LOSE.name}"\n`);

    // ─── 2. Before-counts ────────────────────────────────────────────────────
    const { rows: beforeOrders } = await client.query(`
      SELECT customer_id, COUNT(*) AS cnt
      FROM sales_orders
      WHERE customer_id = ANY($1)
      GROUP BY customer_id
    `, [[KEEP.id, LOSE.id]]);

    const { rows: beforeInvoices } = await client.query(`
      SELECT customer_id, COUNT(*) AS cnt
      FROM sales_invoices
      WHERE customer_id = ANY($1)
      GROUP BY customer_id
    `, [[KEEP.id, LOSE.id]]);

    const beforeOrderTotal = beforeOrders.reduce((s, r) => s + parseInt(r.cnt), 0);
    const beforeInvoiceTotal = beforeInvoices.reduce((s, r) => s + parseInt(r.cnt), 0);

    console.log('── BEFORE ──────────────────────────────────────');
    console.log(`Orders:   ${beforeOrderTotal} total`);
    beforeOrders.forEach(r => console.log(`  ${r.customer_id}: ${r.cnt}`));
    console.log(`Invoices: ${beforeInvoiceTotal} total`);
    beforeInvoices.forEach(r => console.log(`  ${r.customer_id}: ${r.cnt}`));
    console.log();

    // ─── 3. Transaction ──────────────────────────────────────────────────────
    await client.query('BEGIN');

    // ── 3a. Update KEEP with merged HQ data ──
    const mergedPaymentTerms = KEEP.payment_terms || LOSE.payment_terms || 'credit';
    const mergedType         = KEEP.type          || LOSE.type          || 'wholesale';
    const mergedChannel      = KEEP.channel       || LOSE.channel       || null;
    const mergedNotes        = `Merged from two records on 2026-04-09. Original IDs: ${KEEP.id} (Boulevard), ${LOSE.id} (Times Square).`;

    await client.query(`
      UPDATE sales_customers SET
        name              = 'My DailyMart',
        registration_name = 'MY DAILY MART SDN BHD',
        address           = 'Lot 2495-2496, Ground Floor, Boulevard Commercial Centre, 98000 Miri Sarawak Malaysia',
        phone             = '011-18707757',
        ssm_brn           = '201401022362 (1098448-U)',
        tin               = 'C23627748000',
        payment_terms     = $1,
        type              = $2,
        channel           = $3,
        notes             = $4,
        updated_at        = now()
      WHERE id = $5
    `, [mergedPaymentTerms, mergedType, mergedChannel, mergedNotes, KEEP.id]);
    console.log(`✓ Updated KEEP (${KEEP.id}) with merged HQ data`);

    // ── 3b. Generate branch IDs via next_id() RPC ──
    const { rows: [b1Row] } = await client.query(`SELECT next_id('SB', $1) AS id`, [KEEP.company_id]);
    const { rows: [b2Row] } = await client.query(`SELECT next_id('SB', $1) AS id`, [KEEP.company_id]);
    const branch1Id = b1Row.id;
    const branch2Id = b2Row.id;
    console.log(`✓ Generated branch IDs: ${branch1Id}, ${branch2Id}`);

    // ── 3c. Create Branch 1 — Boulevard (default) ──
    await client.query(`
      INSERT INTO sales_customer_branches
        (id, customer_id, name, address, phone, is_default, is_active, company_id)
      VALUES ($1, $2, $3, $4, $5, true, true, $6)
    `, [
      branch1Id,
      KEEP.id,
      'MY DAILY MART 01 (Boulevard)',
      'Lot 2496, Ground Floor, Boulevard Commercial Centre, 98000 Miri Sarawak Malaysia',
      '6085 427 229',
      KEEP.company_id,
    ]);
    console.log(`✓ Created Branch 1 (${branch1Id}): MY DAILY MART 01 (Boulevard)`);

    // ── 3d. Create Branch 2 — Times Square ──
    await client.query(`
      INSERT INTO sales_customer_branches
        (id, customer_id, name, address, phone, is_default, is_active, company_id)
      VALUES ($1, $2, $3, $4, $5, false, true, $6)
    `, [
      branch2Id,
      KEEP.id,
      'MY DAILY MART 08 (Times Square)',
      'Lot 2251, Blk 9, Prcel No: B1-G15 & B1-G16, Times Square, 98000 Miri Sarawak',
      null,
      KEEP.company_id,
    ]);
    console.log(`✓ Created Branch 2 (${branch2Id}): MY DAILY MART 08 (Times Square)`);

    // ── 3e. Reassign orders — set customer_id AND branch_id ──
    // Orders originally from KEEP (Boulevard) → branch1Id
    const { rowCount: keepOrdersUpdated } = await client.query(`
      UPDATE sales_orders
      SET branch_id  = $1,
          updated_at = now()
      WHERE customer_id = $2
    `, [branch1Id, KEEP.id]);
    console.log(`✓ Assigned ${keepOrdersUpdated} Boulevard orders → branch ${branch1Id}`);

    // Orders originally from LOSE (Times Square) → reassign customer + set branch2Id
    const { rowCount: loseOrdersUpdated } = await client.query(`
      UPDATE sales_orders
      SET customer_id = $1,
          branch_id   = $2,
          updated_at  = now()
      WHERE customer_id = $3
    `, [KEEP.id, branch2Id, LOSE.id]);
    console.log(`✓ Reassigned ${loseOrdersUpdated} Times Square orders → customer ${KEEP.id}, branch ${branch2Id}`);

    // ── 3f. Reassign invoices from LOSE → KEEP ──
    const { rowCount: invoicesUpdated } = await client.query(`
      UPDATE sales_invoices
      SET customer_id = $1,
          updated_at  = now()
      WHERE customer_id = $2
    `, [KEEP.id, LOSE.id]);
    console.log(`✓ Reassigned ${invoicesUpdated} invoices from ${LOSE.id} → ${KEEP.id}`);

    // ── 3g. Deactivate LOSE customer ──
    await client.query(`
      UPDATE sales_customers
      SET is_active  = false,
          notes      = $1,
          updated_at = now()
      WHERE id = $2
    `, [`MERGED into ${KEEP.id} (My DailyMart) on 2026-04-09. All orders and invoices reassigned.`, LOSE.id]);
    console.log(`✓ Deactivated LOSE customer (${LOSE.id})\n`);

    // ─── 4. After-counts ─────────────────────────────────────────────────────
    const { rows: afterOrders } = await client.query(`
      SELECT customer_id, COUNT(*) AS cnt
      FROM sales_orders
      WHERE customer_id = $1
      GROUP BY customer_id
    `, [KEEP.id]);

    const { rows: afterInvoices } = await client.query(`
      SELECT customer_id, COUNT(*) AS cnt
      FROM sales_invoices
      WHERE customer_id = $1
      GROUP BY customer_id
    `, [KEEP.id]);

    const afterOrderTotal   = afterOrders.reduce((s, r) => s + parseInt(r.cnt), 0);
    const afterInvoiceTotal = afterInvoices.reduce((s, r) => s + parseInt(r.cnt), 0);

    console.log('── AFTER ───────────────────────────────────────');
    console.log(`Orders:   ${afterOrderTotal} total under ${KEEP.id}`);
    console.log(`Invoices: ${afterInvoiceTotal} total under ${KEEP.id}`);
    console.log();

    // ─── 5. Verify no data loss ───────────────────────────────────────────────
    if (afterOrderTotal < beforeOrderTotal) {
      throw new Error(`ORDER COUNT DECREASED: before=${beforeOrderTotal}, after=${afterOrderTotal} — ROLLING BACK`);
    }
    if (afterInvoiceTotal < beforeInvoiceTotal) {
      throw new Error(`INVOICE COUNT DECREASED: before=${beforeInvoiceTotal}, after=${afterInvoiceTotal} — ROLLING BACK`);
    }

    // ─── 6. Commit ────────────────────────────────────────────────────────────
    await client.query('COMMIT');
    console.log('✓ COMMITTED successfully.\n');

    // Final summary
    console.log('── SUMMARY ─────────────────────────────────────────────────────────────');
    console.log(`Merged customer: ${KEEP.id} → "My DailyMart" (MY DAILY MART SDN BHD)`);
    console.log(`  Branch 1 (${branch1Id}): MY DAILY MART 01 (Boulevard) [default]`);
    console.log(`  Branch 2 (${branch2Id}): MY DAILY MART 08 (Times Square)`);
    console.log(`Deactivated:     ${LOSE.id} (${LOSE.name})`);
    console.log(`Orders:   ${beforeOrderTotal} → ${afterOrderTotal} (no loss)`);
    console.log(`Invoices: ${beforeInvoiceTotal} → ${afterInvoiceTotal} (no loss)`);

  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('\nERROR — rolled back transaction:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

migrate();
