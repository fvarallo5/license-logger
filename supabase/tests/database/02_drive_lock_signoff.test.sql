-- Signed drives are locked; sign-off rules.
begin;
\ir 00_helpers.psql
select no_plan();

-- ---- Maya on her phone ----
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;

select lives_ok($$ update drives set notes = 'Added a note later' where id = pg_temp.drive('D-1013') $$,
                'notes can still be edited on a signed drive');
select throws_ok($$ update drives set duration_minutes = 120 where id = pg_temp.drive('D-1013') $$,
                 '42501', 'This drive is signed and locked', 'signed drive: minutes are locked');
select throws_ok($$ update drives set started_at = started_at - interval '1 hour' where id = pg_temp.drive('D-1013') $$,
                 '42501', 'This drive is signed and locked', 'signed drive: start time is locked');
select throws_ok($$ update drives set route_polyline = 'abc' where id = pg_temp.drive('D-1013') $$,
                 '42501', 'This drive is signed and locked', 'signed drive: route is locked');
select throws_ok($$ update drives set distance_miles = 99 where id = pg_temp.drive('D-1013') $$,
                 '42501', 'This drive is signed and locked', 'signed drive: miles are locked');
select throws_ok($$ update drives set status = 'pending' where id = pg_temp.drive('D-1013') $$,
                 '42501', 'This drive is signed and locked', 'signed drive cannot be un-signed');
delete from drives where id = pg_temp.drive('D-1013');
select is((select count(*)::int from drives where id = pg_temp.drive('D-1013')), 1, 'deleting a signed drive does nothing (RLS)');
select throws_ok($$ insert into drive_route_chunks (drive_id, chunk_no, student_id, polyline, point_count, first_at, last_at)
                   values (pg_temp.drive('D-1013'), 9, '20000000-0000-4000-8000-000000000001', 'abc', 2, now(), now()) $$,
                 '42501', 'This drive is signed and locked', 'no route chunks can be added after signing');
select throws_ok($$ insert into drives (student_id, started_at, ended_at, status, duration_minutes)
                   values ('20000000-0000-4000-8000-000000000001', now() - interval '1 hour', now(), 'signed', 60) $$,
                 '42501', 'Drives are signed with sign_drive()', 'a client cannot insert an already-signed drive');
select throws_ok($$ update drives set status = 'signed' where id = pg_temp.drive('D-1018') $$,
                 '42501', 'Drives are signed with sign_drive()', 'a client cannot flip status to signed');
select throws_ok($$ insert into drives (student_id, started_at) values ('20000000-0000-4000-8000-000000000002', now()) $$,
                 '42501', null, 'student cannot log a drive for her brother');

-- School id is server-owned
insert into drives (id, student_id, school_id, started_at, tz)
values ('70000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000002', timestamptz '2026-10-22 23:30:00+00', 'America/Chicago');
select is((select school_id from drives where id = '70000000-0000-4000-8000-000000000001'),
          '10000000-0000-4000-8000-000000000001'::uuid, 'spoofed school_id is replaced by the student''s school');
select is((select local_date from drives where id = '70000000-0000-4000-8000-000000000001'),
          date '2026-10-22', 'local_date uses the drive time zone (23:30 UTC = 18:30 Chicago)');

-- Batched route upload, idempotent
insert into drive_route_chunks (drive_id, chunk_no, polyline, point_count, first_at, last_at, student_id)
values ('70000000-0000-4000-8000-000000000001', 0, '_p~iF~ps|U_ulLnnqC', 2, now(), now(), '20000000-0000-4000-8000-000000000003');
insert into drive_route_chunks (drive_id, chunk_no, polyline, point_count, first_at, last_at, student_id)
values ('70000000-0000-4000-8000-000000000001', 0, '_p~iF~ps|U_ulLnnqC', 2, now(), now(), '20000000-0000-4000-8000-000000000003')
on conflict do nothing;
select is((select count(*)::int from drive_route_chunks where drive_id = '70000000-0000-4000-8000-000000000001'), 1,
          're-uploading the same chunk is a no-op (offline retry safe)');
select is((select student_id from drive_route_chunks where drive_id = '70000000-0000-4000-8000-000000000001'),
          '20000000-0000-4000-8000-000000000001'::uuid, 'chunk student_id comes from the drive, not the client');

select throws_ok($$ delete from drive_route_chunks where drive_id = '70000000-0000-4000-8000-000000000001' $$,
                 '42501', null, 'apps cannot delete route chunks');

-- Sign-off rules
select throws_ok($$ select sign_drive(pg_temp.drive('D-1018'), 'on_device', '40000000-0000-4000-8000-000000000003', 'JH') $$,
                 '22023', 'Pick a supervisor who can sign', 'an instructor supervisor cannot sign a practice drive');
select throws_ok($$ select sign_drive(pg_temp.drive('D-1018'), 'on_device', '40000000-0000-4000-8000-000000000001', null) $$,
                 '22023', 'Supervisor initials are required', 'initials are required on device');
select throws_ok($$ select sign_drive(pg_temp.drive('D-1018'), 'family_account') $$,
                 '42501', 'Only a linked family member can sign', 'a student cannot sign as family');
select throws_ok($$ select sign_drive('70000000-0000-4000-8000-000000000001', 'on_device', '40000000-0000-4000-8000-000000000001', 'AL') $$,
                 '22023', null, 'an unfinished (in_progress) drive cannot be signed');
select is((sign_drive(pg_temp.drive('D-1018'), 'on_device', '40000000-0000-4000-8000-000000000001', 'al',
                      '{"model":"test","ip":"1.2.3.4"}') ->> 'status'), 'signed', 'supervisor initials on the phone sign the drive');
select is((select status from drives where id = pg_temp.drive('D-1018')), 'signed', 'drive is now signed');
select ok((select locked_at is not null from drives where id = pg_temp.drive('D-1018')), 'drive is now locked');
select is((select initials from drive_signoffs where drive_id = pg_temp.drive('D-1018')), 'AL', 'initials stored upper-case');
select is((select device ? 'ip' from drive_signoffs where drive_id = pg_temp.drive('D-1018')), false, 'device info never keeps an IP');
select is((select length(snapshot_sha256) from drive_signoffs where drive_id = pg_temp.drive('D-1018')), 64, 'snapshot hash recorded');
select throws_ok($$ select sign_drive(pg_temp.drive('D-1018'), 'on_device', '40000000-0000-4000-8000-000000000001', 'AL') $$,
                 '22023', null, 'a drive cannot be signed twice');
select is((select practice_hours from students where id = '20000000-0000-4000-8000-000000000001'), 10.4::numeric,
          'roster hours refresh on sign (9.4 + 1.0)');
select throws_ok($$ select void_drive(pg_temp.drive('D-1013'), 'Wrong car') $$, 'P0002', null, 'a student cannot void');
reset role;

-- ---- Ana signs Leo's drive from the family app ----
select pg_temp.login('00000000-0000-4000-8000-000000000021'); set local role authenticated;
select is((select count(*)::int from pending_signoffs()), 2, 'family home lists drives waiting for a signature');
select is((sign_drive(pg_temp.drive('D-1019'), 'family_account') ->> 'status'), 'signed', 'parent signs from her own app');
select is((select method from drive_signoffs where drive_id = pg_temp.drive('D-1019')), 'family_account', 'method recorded');
select lives_ok($$ select reject_drive(pg_temp.drive('D-1017'), 'We did not drive 2.5 hours') $$, 'parent can reject a pending drive');
select is((select status from drives where id = pg_temp.drive('D-1017')), 'rejected', 'rejected drive goes back to the student');
reset role;

-- ---- Stranger ----
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;
select throws_ok($$ select sign_drive(pg_temp.drive('D-1017'), 'family_account') $$, 'P0002', null, 'stranger cannot even find the drive');
reset role;

-- ---- Instructor signs a lesson; desk voids ----
select pg_temp.login('00000000-0000-4000-8000-000000000002'); set local role authenticated;
insert into drives (id, student_id, kind, source, status, started_at, ended_at, duration_minutes, tz)
values ('70000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', 'lesson', 'instructor', 'pending',
        timestamptz '2026-10-20 21:00+00', timestamptz '2026-10-20 22:00+00', 60, 'America/Chicago');
select is((sign_drive('70000000-0000-4000-8000-000000000002', 'instructor') ->> 'status'), 'signed', 'instructor signs a lesson');
select throws_ok($$ insert into drives (student_id, kind, started_at) values ('20000000-0000-4000-8000-000000000002', 'lesson', now()) $$,
                 '42501', null, 'instructor cannot log a lesson for an unassigned student');
reset role;

select pg_temp.login('00000000-0000-4000-8000-000000000003'); set local role authenticated;
select lives_ok($$ select void_drive(pg_temp.drive('D-1013'), 'Logged on the wrong student') $$, 'front desk can void a signed drive');
select is((select status from drives where id = pg_temp.drive('D-1013')), 'voided', 'voided');
select is((select practice_hours from students where id = '20000000-0000-4000-8000-000000000001'), 9.4::numeric,
          'voided drive stops counting (10.4 - 1.0)');
reset role;

-- ---- Even the database owner can't rewrite history ----
select throws_ok($$ update drive_signoffs set initials = 'XX' where drive_id = pg_temp.drive('D-1018') $$,
                 '42501', null, 'sign-offs are append-only (even for the owner)');
select throws_ok($$ delete from drives where id = pg_temp.drive('D-1011') $$,
                 '42501', null, 'signed drives cannot be deleted (even by the owner)');
select lives_ok($$ delete from students where id = '20000000-0000-4000-8000-000000000002' $$,
                'deleting a whole student (account deletion) still cascades');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000002'), 0, 'their drives went with them');

select * from finish();
rollback;
