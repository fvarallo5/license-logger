-- Who can see what. Seed ids: see supabase/seed.sql.
begin;
\ir 00_helpers.psql
select no_plan();

-- Maya (student, Green Light)
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
select is((select count(*)::int from students), 1, 'student sees only her own student row');
select is((select count(*)::int from drives), 14, 'student sees her 14 drives');
select is((select count(*)::int from drives where student_id <> '20000000-0000-4000-8000-000000000001'), 0, 'student sees no other student''s drives');
select is((select count(*)::int from drive_signoffs where student_id <> '20000000-0000-4000-8000-000000000001'), 0, 'student sees no other sign-offs');
select is((select count(*)::int from schools), 1, 'student sees her school (name/phone for the app)');
select is((select count(*)::int from invoices), 1, 'student sees her own (non-draft) invoice');
select is((select count(*)::int from audit_log), 0, 'student cannot read the audit log');
select is((select count(*)::int from school_members), 0, 'student does not see staff membership rows');
reset role;

-- Leo (student) cannot see his sister's data
select pg_temp.login('00000000-0000-4000-8000-000000000012'); set local role authenticated;
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000001'), 0, 'sibling cannot see Maya''s drives');
select is((select count(*)::int from invoices), 0, 'sibling cannot see Maya''s invoice');
reset role;

-- Ana (family, linked to Maya + Leo)
select pg_temp.login('00000000-0000-4000-8000-000000000021'); set local role authenticated;
select is((select count(*)::int from students), 2, 'family sees exactly the 2 linked students');
select is((select count(*)::int from my_students()), 2, 'my_students() lists both kids');
select is((select count(*)::int from drives), 16, 'family sees drives of linked students only');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000003'), 0, 'family cannot see another school''s student');
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000004'), 0, 'family cannot see unlinked student at same school');
select is((select count(*)::int from lessons), 2, 'family sees the linked student''s lessons');
select is((select count(*)::int from billing_customers), 0, 'family cannot browse the school''s customer list');
reset role;

-- Stranger (signed in, linked to nobody)
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;
select is((select count(*)::int from students), 0, 'stranger sees no students');
select is((select count(*)::int from drives), 0, 'stranger sees no drives');
select is((select count(*)::int from supervisors), 0, 'stranger sees no supervisors');
select is((select count(*)::int from family_links), 0, 'stranger sees no family links');
select is((select count(*)::int from invoices), 0, 'stranger sees no invoices');
select is((select count(*)::int from drive_route_chunks), 0, 'stranger sees no routes');
select is((select count(*)::int from state_rule_sets) > 0, true, 'everyone signed in can read state rules');
select throws_ok($$ select * from student_hours_summary('20000000-0000-4000-8000-000000000001') $$, 'P0002', null, 'stranger cannot get hours for a student');
select throws_ok($$ insert into drives (student_id, started_at) values ('20000000-0000-4000-8000-000000000001', now()) $$, '42501', null, 'stranger cannot log a drive for Maya');
reset role;

-- Green Light owner sees their school only
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select count(*)::int from students), 3, 'owner sees the 3 Green Light students');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000003'), 0, 'owner cannot see Blue Line drives');
select is((select count(*)::int from schools), 1, 'owner sees only their school');
select ok((select count(*) from audit_log) > 0, 'owner can read their audit log');
select is((select count(*)::int from audit_log where school_id = '10000000-0000-4000-8000-000000000002'), 0, 'owner cannot read another school''s audit log');
select is((select count(*)::int from invoices), 1, 'owner sees school invoices');
select is((select count(*)::int from school_students_progress('10000000-0000-4000-8000-000000000001')), 3, 'roster RPC returns own school');
select is((select count(*)::int from school_students_progress('10000000-0000-4000-8000-000000000002')), 0, 'roster RPC returns nothing for another school');
reset role;

-- Blue Line owner
select pg_temp.login('00000000-0000-4000-8000-000000000031'); set local role authenticated;
select is((select count(*)::int from students), 1, 'other school owner sees only their 1 student');
select is((select count(*)::int from drives where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'other school owner sees no Green Light drives');
select is((select count(*)::int from lessons), 0, 'other school owner sees no Green Light lessons');
reset role;

-- Jordan (instructor) sees assigned students only
select pg_temp.login('00000000-0000-4000-8000-000000000002'); set local role authenticated;
select is((select count(*)::int from students), 1, 'instructor sees only assigned student (Maya)');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000002'), 0, 'instructor cannot see unassigned Leo''s drives');
select is((select count(*)::int from invoices), 0, 'instructor cannot see money');
select is((select count(*)::int from lessons), 2, 'instructor sees own lessons');
reset role;

-- Priya (front desk: students yes, pay no)
select pg_temp.login('00000000-0000-4000-8000-000000000003'); set local role authenticated;
select is((select count(*)::int from students), 3, 'front desk sees school roster');
select is((select count(*)::int from invoices), 0, 'front desk without Pay access sees no invoices');
reset role;

-- Hard walls: partitions, private schema, service-only RPCs, anon
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
select throws_ok($$ select * from drive_route_chunks_p0 $$, '42501', null, 'route partitions are not directly readable');
select throws_ok($$ select * from private.qbo_tokens $$, '42501', null, 'token pointers are not readable');
select throws_ok($$ select * from private.notification_outbox $$, '42501', null, 'email outbox is not readable');
select throws_ok($$ select * from svc_qbo_get_tokens('10000000-0000-4000-8000-000000000001') $$, '42501', null, 'service-only RPCs are not callable by app users');
select throws_ok($$ select svc_housekeeping() $$, '42501', null, 'housekeeping is service-only');
select throws_ok($$ insert into drive_signoffs (drive_id, school_id, student_id, method, supervisor_name, snapshot, snapshot_sha256)
                   values (pg_temp.drive('D-1018'), '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'on_device', 'Me', '{}', 'x') $$,
                 '42501', null, 'sign-offs cannot be inserted directly (only sign_drive)');
reset role;
select pg_temp.logout(); set local role anon;
select throws_ok($$ select * from drives $$, '42501', null, 'signed-out visitors cannot read drives');
select throws_ok($$ select * from students $$, '42501', null, 'signed-out visitors cannot read students');
select throws_ok($$ select * from create_family_invite('20000000-0000-4000-8000-000000000001') $$, '42501', null, 'signed-out visitors cannot call RPCs');
reset role;

select * from finish();
rollback;
