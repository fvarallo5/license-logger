-- Independent students (no driving school): isolation, hours, family, joining and leaving a school.
-- Seed: Noah Kim (20..05, school_id NULL, user ..51), mom Grace (..52). Green Light (GL) owner ..01,
-- instructor ..02, desk ..03; Blue Line (BL) owner ..31; stranger ..41; Riley = unclaimed GL roster entry (RILEY4).
begin;
\ir 00_helpers.psql
select no_plan();

create temporary table ids (k text primary key, v uuid) on commit drop;
grant select, insert, update on ids to authenticated;
insert into student_contacts (school_id, student_id, name, email) values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000004', 'Pat Park', 'pat@family.example');
insert into ids values ('noah', '20000000-0000-4000-8000-000000000005'), ('gl', '10000000-0000-4000-8000-000000000001'),
                       ('bl', '10000000-0000-4000-8000-000000000002');

select is((select school_id from students where id = '20000000-0000-4000-8000-000000000005'), null, 'seed: Noah has no school');
select is((select count(*)::int from school_enrollments where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'independent student has no enrollment');
select is((select count(*)::int from school_enrollments where left_at is null), 4, 'every school student got an enrollment row (backfill/trigger)');

-- ---------------------------------------------------------------- Noah, independent
select pg_temp.login('00000000-0000-4000-8000-000000000051'); set local role authenticated;
select is((select count(*)::int from students), 1, 'Noah sees his own profile');
select is((select count(*)::int from drives), 3, 'Noah sees his 3 drives');
select is((select school_name from my_students()), null, 'my_students(): no school for an independent student');
select is((select count(*)::int from my_students()), 1, 'my_students(): one row');
select is((select count(*)::int from schools), 0, 'independent student sees no school');
select is((select credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 180,
          'hours: 150 min day capped to 120 + 60 = 180 credited (TX rules)');
select is((select night_credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 30, 'hours: 30 night minutes');
select is((select required_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 1800, 'hours: Texas 30 h requirement applies');
select is((select school_goal_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), null, 'hours: no school goal for independent');
select is((select pending_extra_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 40, 'hours: 40 min waiting for sign-off');
select is((select count(*)::int from student_hours_by_day('20000000-0000-4000-8000-000000000005') where capped), 1, 'hours: capped day flagged');
select is((select count(*)::int from list_drives('20000000-0000-4000-8000-000000000005')), 3, 'list_drives works');
select lives_ok($$ insert into drives (id, student_id, started_at, ended_at, duration_minutes, status, supervisor_id)
                   values ('77000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000005',
                           '2026-10-22 22:00+00', '2026-10-22 22:30+00', 30, 'pending', '40000000-0000-4000-8000-000000000006') $$,
                'independent student logs a drive');
select is((select school_id from drives where id = '77000000-0000-4000-8000-000000000001'), null, 'drive has no school stamp');
select lives_ok($$ insert into drive_route_chunks (drive_id, chunk_no, polyline, point_count, first_at, last_at)
                   values ('77000000-0000-4000-8000-000000000001', 0, '_p~iF~ps|U', 1, '2026-10-22 22:00+00', '2026-10-22 22:05+00') $$,
                'independent student uploads a route chunk');
select is((sign_drive('77000000-0000-4000-8000-000000000001', 'on_device', '40000000-0000-4000-8000-000000000006', 'GK') ->> 'status'),
          'signed', 'on-device sign-off works without a school');
select throws_ok($$ select sign_drive('77000000-0000-4000-8000-000000000001', 'instructor') $$, null, null, 'no instructor sign-off without a school');
select throws_ok($$ insert into drives (student_id, kind, started_at) values ('20000000-0000-4000-8000-000000000005', 'lesson', now()) $$,
                 '42501', null, 'no school lessons for an independent student');
select lives_ok($$ select update_my_student('20000000-0000-4000-8000-000000000005', p_state_code => 'KS') $$, 'independent student picks a state');
select is((select rule_verified from student_hours_summary('20000000-0000-4000-8000-000000000005')), false, 'Kansas rule is partially verified, so not flagged verified');
select lives_ok($$ select update_my_student('20000000-0000-4000-8000-000000000005', p_state_code => 'TX') $$, 'and back to Texas');
insert into ids values ('inv', null);
update ids set v = (create_family_invite('20000000-0000-4000-8000-000000000005', 'guardian', 1) ->> 'invite_id')::uuid where k = 'inv';
select isnt((select v from ids where k = 'inv'), null, 'independent student can create a family invite');
reset role;
select is((select school_id from family_invites where id = (select v from ids where k = 'inv')), null, 'invite has no school');

-- ---------------------------------------------------------------- Grace (family) signs
select pg_temp.login('00000000-0000-4000-8000-000000000052'); set local role authenticated;
select is((select count(*)::int from students), 1, 'Grace sees Noah');
select is((select count(*)::int from pending_signoffs()), 1, 'Grace sees the pending drive');
select is((sign_drive(pg_temp.drive('N-1021'), 'family_account') ->> 'status'), 'signed', 'family sign-off works without a school');
select is((select practice_hours from students where id = '20000000-0000-4000-8000-000000000005'), 4.2, 'roster cache: 250 credited min = 4.2 h');
reset role;

-- ---------------------------------------------------------------- schools can't see Noah
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;   -- GL owner
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: Noah invisible');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: Noah''s drives invisible');
select is((select count(*)::int from drive_signoffs where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: sign-offs invisible');
select is((select count(*)::int from drive_route_chunks where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: routes invisible');
select is((select count(*)::int from supervisors where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: supervisors invisible');
select is((select count(*)::int from family_links where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: family links invisible');
select is((select count(*)::int from family_invites where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: invites invisible');
select is((select count(*)::int from audit_log where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: audit rows invisible');
select is((select count(*)::int from list_drives('20000000-0000-4000-8000-000000000005')), 0, 'GL owner: list_drives empty');
select throws_ok($$ select * from student_hours_summary('20000000-0000-4000-8000-000000000005') $$, 'P0002', null, 'GL owner: no hours');
select throws_ok($$ select create_family_invite('20000000-0000-4000-8000-000000000005') $$, '42501', null, 'GL owner: no invites for Noah');
select throws_ok($$ insert into drives (student_id, started_at) values ('20000000-0000-4000-8000-000000000005', now()) $$, '42501', null, 'GL owner: cannot log drives');
select throws_ok($$ insert into lessons (student_id, starts_at, ends_at) values ('20000000-0000-4000-8000-000000000005', now() + interval '1 day', now() + interval '25 hours') $$,
                 '22023', null, 'GL owner: cannot book a lesson for an independent student');
select throws_ok($$ insert into billing_customers (school_id, student_id, display_name) values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000005', 'x') $$,
                 '42501', null, 'GL owner: cannot bill an independent student (QuickBooks is school-only)');
update students set school_id = '10000000-0000-4000-8000-000000000001' where id = '20000000-0000-4000-8000-000000000005';
reset role;
select is((select school_id from students where id = '20000000-0000-4000-8000-000000000005'), null, 'GL owner: cannot pull Noah into the school by UPDATE');
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select throws_ok($$ select update_my_student('20000000-0000-4000-8000-000000000005', 'Hacked') $$, 'P0002', null, 'GL owner: cannot edit Noah');
select throws_ok($$ select leave_school('20000000-0000-4000-8000-000000000005') $$, 'P0002', null, 'GL owner: cannot use the student-side RPCs');
select is((select count(*)::int from school_students_progress('10000000-0000-4000-8000-000000000001')), 3, 'roster unchanged (3)');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000002'); set local role authenticated;   -- GL instructor
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL instructor: Noah invisible');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000031'); set local role authenticated;   -- BL owner
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000005'), 0, 'BL owner: Noah invisible');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'BL owner: drives invisible');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;   -- stranger
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'stranger: drives invisible');
reset role;

-- ---------------------------------------------------------------- join a school: school-side request + consent
select pg_temp.login('00000000-0000-4000-8000-000000000003'); set local role authenticated;   -- GL front desk
select is((request_student_link('10000000-0000-4000-8000-000000000001', 'XXXXXX') ->> 'status'), 'invalid', 'wrong code -> invalid');
select is((request_student_link('10000000-0000-4000-8000-000000000001', 'riley4') ->> 'status'), 'invalid', 'code of a profile nobody owns -> invalid');
select is((request_student_link('10000000-0000-4000-8000-000000000001', 'maya01') ->> 'status'), 'already_linked', 'own student -> already linked');
insert into ids values ('req', null);
update ids set v = (request_student_link('10000000-0000-4000-8000-000000000001', 'noah-05') ->> 'request_id')::uuid where k = 'req';
select isnt((select v from ids where k = 'req'), null, 'request created from the student''s code');
select is((request_student_link('10000000-0000-4000-8000-000000000001', 'NOAH05') ->> 'request_id')::uuid, (select v from ids where k = 'req'), 'asking twice returns the same request');
select is((select count(*)::int from school_link_requests), 1, 'desk sees its pending request');
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000005'), 0, 'still nothing visible before consent');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'no drives before consent');
select throws_ok($$ select respond_school_request((select v from ids where k = 'req'), true) $$, 'P0002', null, 'the school cannot accept for the student');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000031'); set local role authenticated;
select is((select count(*)::int from school_link_requests), 0, 'BL cannot see GL''s request');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;
select throws_ok($$ select respond_school_request((select v from ids where k = 'req'), true) $$, 'P0002', null, 'stranger cannot accept');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000051'); set local role authenticated;
select is((select school_name from my_school_requests()), 'Green Light Driving', 'Noah sees the request with the school name');
-- an unsigned practice drive in progress when he joins
insert into drives (id, student_id, started_at) values ('77000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000005', '2026-10-23 15:00+00');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000052'); set local role authenticated;   -- Grace consents
select is((respond_school_request((select v from ids where k = 'req'), true) ->> 'status'), 'accepted', 'family accepts the school request');
reset role;

select is((select school_id from students where id = '20000000-0000-4000-8000-000000000005'), '10000000-0000-4000-8000-000000000001'::uuid, 'Noah is now at GL');
select is((select joined_via from school_enrollments where student_id = '20000000-0000-4000-8000-000000000005' and left_at is null), 'school_request', 'enrollment recorded');
select is((select school_id from drives where id = '77000000-0000-4000-8000-000000000002'), '10000000-0000-4000-8000-000000000001'::uuid, 'unsigned drive follows the student');
select is((select school_id from drives where id = pg_temp.drive('N-1016')), null, 'signed history keeps its original (no school) stamp');
select is((select count(*)::int from family_links where student_id = '20000000-0000-4000-8000-000000000005' and school_id = '10000000-0000-4000-8000-000000000001'), 1, 'family link follows');
select is((select count(*)::int from supervisors where student_id = '20000000-0000-4000-8000-000000000005' and school_id = '10000000-0000-4000-8000-000000000001'), 1, 'supervisor follows');

select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select count(*)::int from students), 4, 'GL owner now sees Noah (4 students)');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 5, 'GL owner sees Noah''s full history (consented)');
select is((select credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 250, 'hours preserved after joining');
select is((select school_goal_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 3000, 'school goal now applies');
select is((select count(*)::int from school_students_progress('10000000-0000-4000-8000-000000000001')), 4, 'roster shows 4');
select lives_ok($$ insert into lessons (id, student_id, starts_at, ends_at) values ('55000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000005',
                   now() + interval '3 days', now() + interval '3 days 1 hour') $$, 'school can book Noah now');
select lives_ok($$ insert into billing_customers (school_id, student_id, display_name) values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000005', 'Grace Kim') $$,
                'school can bill Noah now');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000031'); set local role authenticated;
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'BL still sees nothing');
reset role;

-- a drive signed while enrolled at GL
select pg_temp.login('00000000-0000-4000-8000-000000000051'); set local role authenticated;
update drives set ended_at = '2026-10-23 16:00+00', duration_minutes = 60, status = 'pending' where id = '77000000-0000-4000-8000-000000000002';
select is((sign_drive('77000000-0000-4000-8000-000000000002', 'on_device', '40000000-0000-4000-8000-000000000006', 'GK') ->> 'status'), 'signed', 'drive signed while enrolled');
insert into drives (id, student_id, started_at) values ('77000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000005', '2026-10-24 15:00+00');

-- ---------------------------------------------------------------- leave the school
select is((leave_school('20000000-0000-4000-8000-000000000005') ->> 'status'), 'ok', 'Noah leaves GL');
select is((leave_school('20000000-0000-4000-8000-000000000005') ->> 'status'), 'not_enrolled', 'leaving twice is harmless');
select is((select count(*)::int from drives), 6, 'Noah keeps every drive');
select is((select credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000005')), 310, 'hours preserved after leaving');
reset role;
select is((select school_id from students where id = '20000000-0000-4000-8000-000000000005'), null, 'independent again');
select is((select left_reason from school_enrollments where student_id = '20000000-0000-4000-8000-000000000005'), 'student_left', 'enrollment closed');
select is((select school_id from drives where id = '77000000-0000-4000-8000-000000000003'), null, 'unsigned drive left with the student');
select is((select status from lessons where id = '55000000-0000-4000-8000-000000000001'), 'cancelled', 'future lesson at the old school cancelled');
select is((select school_id from family_links where student_id = '20000000-0000-4000-8000-000000000005' limit 1), null, 'family link no longer tied to GL');

select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: Noah gone from roster');
select is((select count(*)::int from drives where student_id = '20000000-0000-4000-8000-000000000005'), 1, 'GL owner keeps only the drive signed while enrolled');
select is((select count(*)::int from drive_signoffs where student_id = '20000000-0000-4000-8000-000000000005'), 1, '...and its sign-off');
select is((select count(*)::int from drive_route_chunks where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: no raw routes');
select is((select count(*)::int from family_links where student_id = '20000000-0000-4000-8000-000000000005'), 0, 'GL owner: family links gone');
select is((select count(*)::int from lessons where student_id = '20000000-0000-4000-8000-000000000005'), 1, 'GL keeps its lesson record');
select is((select first_name from school_enrollments where student_id = '20000000-0000-4000-8000-000000000005'), 'Noah', 'GL can label the former student');
select throws_ok($$ select void_drive('77000000-0000-4000-8000-000000000002', 'not ours anymore') $$, 'P0002', null, 'former school cannot void');
select throws_ok($$ select * from student_hours_summary('20000000-0000-4000-8000-000000000005') $$, 'P0002', null, 'former school: no hours');
-- school releases a student
select throws_ok($$ select release_student('20000000-0000-4000-8000-000000000004') $$, '22023', null, 'cannot release a roster entry nobody owns');
select is((release_student('20000000-0000-4000-8000-000000000002') ->> 'status'), 'ok', 'GL releases Leo');
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000002'), 0, 'Leo gone from GL');
reset role;
select is((select left_reason from school_enrollments where student_id = '20000000-0000-4000-8000-000000000002'), 'school_released', 'release recorded');
select pg_temp.login('00000000-0000-4000-8000-000000000012'); set local role authenticated;
select is((select count(*)::int from drives), 2, 'Leo still has his drives');
reset role;

-- ---------------------------------------------------------------- join with the school's roster code (merge)
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;   -- stranger starts independent
insert into ids values ('me', null);
update ids set v = (create_independent_student('Riley', 'Park', null, 'TX') ->> 'student_id')::uuid where k = 'me';
select is((create_independent_student('Riley', 'Park') ->> 'status'), 'exists', 'one own independent profile');
select is((select school_id from students where id = (select v from ids where k = 'me')), null, 'new profile is independent');
insert into drives (student_id, started_at, ended_at, duration_minutes, status)
values ((select v from ids where k = 'me'), '2026-10-20 15:00+00', '2026-10-20 16:00+00', 60, 'pending');
select is((claim_student_profile('RILEY4') ->> 'status'), 'has_independent_profile', 'claim notices the existing profile');
select is((join_school_with_code((select v from ids where k = 'me'), 'MAYA01') ->> 'status'), 'invalid', 'cannot merge into a claimed profile');
select is((join_school_with_code((select v from ids where k = 'me'), 'riley-4') ->> 'status'), 'ok', 'merge with the school roster code');
select is((select count(*)::int from drives), 1, 'drive history kept');
reset role;
select is((select school_id from students where id = (select v from ids where k = 'me')), '10000000-0000-4000-8000-000000000001'::uuid, 'profile now at GL');
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000004'), 0, 'empty roster entry removed');
select is((select count(*)::int from student_contacts where student_id = (select v from ids where k = 'me')), 1, 'school''s contact row moved onto the profile');
select is((select joined_via from school_enrollments where student_id = (select v from ids where k = 'me') and left_at is null), 'school_code', 'enrollment via school code');
select is((select school_id from drives where student_id = (select v from ids where k = 'me')), '10000000-0000-4000-8000-000000000001'::uuid, 'pending drive now visible to the school');

-- ---------------------------------------------------------------- parent-first setup
select pg_temp.login('00000000-0000-4000-8000-000000000052'); set local role authenticated;   -- Grace adds a second child
insert into ids values ('ella', null);
update ids set v = (create_independent_student('Ella', 'Kim', null, 'TX', 'family') ->> 'student_id')::uuid where k = 'ella';
select is((select count(*)::int from my_students()), 2, 'Grace now has 2 students');
select is((select count(*)::int from supervisors where student_id = (select v from ids where k = 'ella') and user_id = '00000000-0000-4000-8000-000000000052'), 1,
          'Grace is Ella''s supervisor');
select lives_ok($$ insert into drives (student_id, started_at) values ((select v from ids where k = 'ella'), now()) $$, 'parent logs a drive for the child');
reset role;
select is((select user_id from students where id = (select v from ids where k = 'ella')), null, 'Ella has no account yet (claims later with her join code)');

select * from finish();
rollback;
