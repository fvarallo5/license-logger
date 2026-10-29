-- QuickBooks token storage, webhook dedupe, outbox/idempotency, email queue.
begin;
\ir 00_helpers.psql
select no_plan();

-- ---- Edge Function (service_role) stores tokens after OAuth ----
set local role service_role;
select lives_ok($$ select svc_qbo_store_tokens('10000000-0000-4000-8000-000000000001', '9130000000000001',
                    'fake-access-token', 'fake-refresh-token', 3600, 8640000,
                    '00000000-0000-4000-8000-000000000001', 'sandbox', 'Green Light Driving LLC') $$, 'tokens stored');
select is((select access_token from svc_qbo_get_tokens('10000000-0000-4000-8000-000000000001')), 'fake-access-token', 'service can read tokens back');
select lives_ok($$ select svc_qbo_store_tokens('10000000-0000-4000-8000-000000000001', '9130000000000001',
                    'fake-access-2', 'fake-refresh-2', 3600, 8640000) $$, 'refresh rotates tokens in place');
select is((select refresh_token from svc_qbo_get_tokens('10000000-0000-4000-8000-000000000001')), 'fake-refresh-2', 'latest refresh token kept');
select throws_ok($$ select svc_qbo_store_tokens('10000000-0000-4000-8000-000000000002', '9130000000000001', 'a', 'b', 3600, 3600) $$,
                 '23505', null, 'one QuickBooks company cannot be connected to two schools');
reset role;
select is((select count(*)::int from vault.secrets where name like 'qbo_%'), 2, 'exactly 2 vault secrets (access + refresh), updated not duplicated');
select is((select count(*)::int from public.qbo_connections where status = 'connected'), 1, 'connection row');
select is((select count(*)::int from public.qbo_connections c where to_jsonb(c)::text like '%fake-%'), 0, 'no token text in the visible connection row');

-- ---- Owner sees status; front desk (no Pay) does not ----
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select status from qbo_connections), 'connected', 'owner sees connection status');
select is((select status from qbo_sync_status('10000000-0000-4000-8000-000000000001')), 'connected', 'sync status RPC');
select ok((select length(qbo_begin_connect('10000000-0000-4000-8000-000000000001'))) = 48, 'owner can start OAuth (state value)');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000003'); set local role authenticated;
select is((select count(*)::int from qbo_connections), 0, 'front desk without Pay sees nothing');
select throws_ok($$ select qbo_begin_connect('10000000-0000-4000-8000-000000000001') $$, '42501', null, 'front desk cannot connect QuickBooks');
reset role;

-- ---- OAuth state is single-use ----
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
create temporary table st on commit drop as select qbo_begin_connect('10000000-0000-4000-8000-000000000001') as s;
grant select on st to service_role;
reset role;
set local role service_role;
select is((select count(*)::int from svc_qbo_consume_state((select s from st))), 1, 'state consumed once');
select is((select count(*)::int from svc_qbo_consume_state((select s from st))), 0, 'replayed state is rejected');
reset role;

-- ---- App edits queue ONE push (coalesced) ----
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
update invoices set memo = 'Edit 1' where id = '61000000-0000-4000-8000-000000000001';
update invoices set memo = 'Edit 2' where id = '61000000-0000-4000-8000-000000000001';
select is((select sync_status from invoices where id = '61000000-0000-4000-8000-000000000001'), 'pending', 'edited invoice marked pending');
reset role;
select is((select count(*)::int from private.qbo_sync_jobs where direction = 'push' and local_id = '61000000-0000-4000-8000-000000000001'), 1,
          'two edits -> one queued push');

-- ---- Webhook: CloudEvents, duplicates ignored ----
set local role service_role;
select is(svc_qbo_record_events('[
  {"specversion":"1.0","id":"evt-1","type":"qbo.invoice.updated.v1","intuitentityid":"145","intuitaccountid":"9130000000000001","time":"2026-10-22T17:00:00Z","data":{}},
  {"specversion":"1.0","id":"evt-2","type":"qbo.payment.created.v1","intuitentityid":"77","intuitaccountid":"9130000000000001","time":"2026-10-22T17:00:01Z","data":{}},
  {"specversion":"1.0","id":"evt-3","type":"qbo.invoice.updated.v1","intuitentityid":"145","intuitaccountid":"9130000000000001","time":"2026-10-22T17:00:02Z","data":{}},
  {"specversion":"1.0","id":"evt-4","type":"qbo.account.created.v1","intuitentityid":"9","intuitaccountid":"9130000000000001","time":"2026-10-22T17:00:03Z","data":{}},
  {"specversion":"1.0","id":"evt-5","type":"qbo.invoice.updated.v1","intuitentityid":"5","intuitaccountid":"unknown-realm","data":{}}
]'::jsonb), 5, '5 new events recorded');
select is(svc_qbo_record_events('[{"specversion":"1.0","id":"evt-1","type":"qbo.invoice.updated.v1","intuitentityid":"145","intuitaccountid":"9130000000000001"}]'::jsonb),
          0, 'Intuit retry of the same event is ignored');
reset role;
select is((select count(*)::int from private.qbo_sync_jobs where direction = 'pull'), 2,
          'pulls queued: invoice 145 once (coalesced), payment 77; unknown entity/realm ignored');

-- ---- Worker claims, fails, retries, succeeds ----
set local role service_role;
create temporary table jobs on commit drop as select * from svc_qbo_claim_jobs(10);
select is((select count(*)::int from jobs), 3, 'worker claims 3 due jobs');
select is((select count(*)::int from svc_qbo_claim_jobs(10)), 0, 'claimed jobs are not handed out twice');
select ok((select payload -> 'lines' is not null from jobs where direction = 'push'), 'push payload includes invoice lines');
select lives_ok($$ select svc_qbo_finish_job((select id from jobs where direction = 'push'), false, 'HTTP 503') $$, 'record a failure');
reset role;
select ok((select next_attempt_at > now() from private.qbo_sync_jobs where direction = 'push' and status = 'failed'), 'failure backs off');
set local role service_role;
select lives_ok($$ select svc_qbo_finish_job((select id from jobs where direction = 'push'), true, null, '145', '3', '2026-10-22T17:05:00Z') $$, 'record success');
select is((select sync_status from invoices where id = '61000000-0000-4000-8000-000000000001'), 'synced', 'invoice synced');
select is((select qbo_invoice_id from invoices where id = '61000000-0000-4000-8000-000000000001'), '145', 'QuickBooks id stored');
-- Pull applies newer data, ignores stale data
select ok(svc_qbo_apply_entity('10000000-0000-4000-8000-000000000001', 'invoice',
  '{"Id":"145","SyncToken":"4","DocNumber":"GL-1001","TxnDate":"2026-09-01","TotalAmt":450,"Balance":0,
    "CustomerRef":{"value":"58","name":"Ana Lopez"},"MetaData":{"LastUpdatedTime":"2026-10-22T18:00:00Z"}}') is not null, 'newer QuickBooks data applied');
select is((select status from invoices where id = '61000000-0000-4000-8000-000000000001'), 'paid', 'balance 0 -> paid');
select is(svc_qbo_apply_entity('10000000-0000-4000-8000-000000000001', 'invoice',
  '{"Id":"145","SyncToken":"2","TotalAmt":450,"Balance":450,"CustomerRef":{"value":"58"},"MetaData":{"LastUpdatedTime":"2026-10-01T00:00:00Z"}}'), null,
  'stale (out-of-order) webhook data is ignored');
select is((select status from invoices where id = '61000000-0000-4000-8000-000000000001'), 'paid', 'still paid');
reset role;
select is((select count(*)::int from private.qbo_sync_jobs where direction = 'push' and status in ('queued','failed')), 0,
          'sync writes do not queue a new push (no loop)');

-- ---- Disconnect wipes tokens ----
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select lives_ok($$ select qbo_disconnect('10000000-0000-4000-8000-000000000001') $$, 'owner disconnects');
reset role;
select is((select count(*)::int from vault.secrets where name like 'qbo_%'), 0, 'tokens deleted from vault');

-- ---- Email outbox ----
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
insert into drives (id, student_id, status, started_at, ended_at, duration_minutes, tz)
values ('70000000-0000-4000-8000-000000000009', '20000000-0000-4000-8000-000000000001', 'pending',
        now() - interval '1 hour', now(), 60, 'America/Chicago');
reset role;
select is((select count(*)::int from private.notification_outbox where kind = 'drive_pending'
            and payload ->> 'drive_id' = '70000000-0000-4000-8000-000000000009'), 2, 'both parents queued (once each)');
update private.notification_outbox set next_attempt_at = now() - interval '1 minute';
set local role service_role;
create temporary table mail on commit drop as select * from svc_claim_notifications(50);
select is((select count(*)::int from mail where kind = 'drive_pending'), 2, 'worker gets 2 emails');
select ok((select bool_and(to_email like '%@family.example') from mail where kind = 'drive_pending'), 'addresses resolved from auth.users');
select ok((select bool_and(payload ->> 'student_first_name' = 'Maya') from mail where kind = 'drive_pending'), 'payload has the student name');
select is((select count(*)::int from svc_claim_notifications(50)), 0, 'not handed out twice');
select lives_ok($$ select svc_finish_notification(id, true) from mail $$, 'mark sent');
reset role;

-- Signed on the phone before the 10-minute grace period -> reminder skipped
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
insert into drives (id, student_id, status, started_at, ended_at, duration_minutes, tz)
values ('70000000-0000-4000-8000-000000000010', '20000000-0000-4000-8000-000000000001', 'pending',
        now() - interval '1 hour', now(), 60, 'America/Chicago');
select sign_drive('70000000-0000-4000-8000-000000000010', 'on_device', '40000000-0000-4000-8000-000000000001', 'AL');
reset role;
update private.notification_outbox set next_attempt_at = now() - interval '1 minute' where status = 'queued';
set local role service_role;
select is((select count(*)::int from svc_claim_notifications(50)), 0, 'no email for a drive that is already signed');
reset role;
select is((select count(*)::int from private.notification_outbox where status = 'skipped'), 2, 'reminders marked skipped');

set local role service_role;
select ok((svc_housekeeping() ? 'route_chunks'), 'housekeeping runs (incl. raw route retention)');
reset role;

select * from finish();
rollback;
