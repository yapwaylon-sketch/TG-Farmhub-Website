import { readFileSync } from 'node:fs';
import pg from 'pg';

const CONN = 'postgresql://postgres.qwlagcriiyoflseduvvc:Hlfqdbi6wcM4Omsm@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres';
const SUPA = 'https://qwlagcriiyoflseduvvc.supabase.co';
const SVC  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjM0ODE0NiwiZXhwIjoyMDg3OTI0MTQ2fQ._V00JPWWd2D9SmGv9EbHtjyzUo63cWiH-tVFWzmSbBE';

const client = new pg.Client({ connectionString: CONN });
await client.connect();
await client.query(readFileSync('supabase/block_issues_migration.sql', 'utf8'));
console.log('DDL applied.');

const bkt = await fetch(`${SUPA}/storage/v1/bucket`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${SVC}`, 'Content-Type': 'application/json', apikey: SVC },
  body: JSON.stringify({ id: 'crop-issue-photos', name: 'crop-issue-photos', public: true, file_size_limit: 10485760 })
});
console.log('bucket:', bkt.status, await bkt.text());

await client.query(`
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='crop_issue_photos_all') THEN
      CREATE POLICY crop_issue_photos_all ON storage.objects FOR ALL
        USING (bucket_id = 'crop-issue-photos') WITH CHECK (bucket_id = 'crop-issue-photos');
    END IF;
  END $$;`);
console.log('storage policy ensured.');
await client.end();
