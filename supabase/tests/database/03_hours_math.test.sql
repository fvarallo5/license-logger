-- Hours math: day vs night, Texas 2-hour daily cap, pending vs signed, unverified states, paging.
begin;
\ir 00_helpers.psql
select no_plan();

-- ---- Maya from the seed (Texas) ----
select pg_temp.login('00000000-0000-4000-8000-000000000021'); set local role authenticated;   -- as her mom
create temporary table m on commit drop as select * from student_hours_summary('20000000-0000-4000-8000-000000000001');
select is((select rule_verified from m), true, 'Texas rule is verified');
select is((select form_code from m), 'DES150N (TDLR)', 'form code (from the TDLR form)');
select is((select required_minutes from m), 1800, 'Texas requires 30 h');
select is((select required_night_minutes from m), 600, 'Texas requires 10 h at night');
select is((select daily_cap_minutes from m), 120, 'Texas counts max 2 h per day');
select is((select credited_minutes from m), 564, 'signed credited = 9.4 h (matches roster)');
select is((select night_credited_minutes from m), 120, 'signed night = 2.0 h');
select is((select day_credited_minutes from m), 444, 'day = credited - night');
select is((select pending_extra_minutes from m), 180, 'pending adds 3.0 h (60 + 150 capped to 120)');
select is((select pending_drives from m), 2, '2 drives waiting for a signature');
select is((select lesson_minutes from m), 120, 'instructor lessons tracked separately (2 h)');
select is((select remaining_minutes from m), 1236, 'remaining = 1800 - 564');
select is((select requirement_met from m), false, 'not done yet');
select is((select school_goal_minutes from m), 3000, 'school goal 50 h is separate from the state rule');
reset role;

-- ---- Daily cap scenarios on Riley (Green Light, no app account) ----
-- Inserted as the database owner with status 'signed' (trusted path, like the seed).
insert into drives (student_id, kind, status, started_at, ended_at, tz, duration_minutes, night_minutes) values
  -- Day 1: 90 + 60 = 150 raw -> 120 credited
  ('20000000-0000-4000-8000-000000000004', 'practice', 'signed', timestamptz '2026-10-01 14:00+00', timestamptz '2026-10-01 15:30+00', 'America/Chicago', 90, 0),
  ('20000000-0000-4000-8000-000000000004', 'practice', 'signed', timestamptz '2026-10-01 18:00+00', timestamptz '2026-10-01 19:00+00', 'America/Chicago', 60, 0),
  -- Day 2: 100 day + 60 night = 160 raw -> 120 credited, 60 of it night
  ('20000000-0000-4000-8000-000000000004', 'practice', 'signed', timestamptz '2026-10-02 14:00+00', timestamptz '2026-10-02 15:40+00', 'America/Chicago', 100, 0),
  ('20000000-0000-4000-8000-000000000004', 'practice', 'signed', timestamptz '2026-10-03 01:00+00', timestamptz '2026-10-03 02:00+00', 'America/Chicago', 60, 60),
  -- Day 3: one 3 h drive with 150 night minutes -> 120 credited, all 120 night
  ('20000000-0000-4000-8000-000000000004', 'practice', 'signed', timestamptz '2026-10-04 23:30+00', timestamptz '2026-10-05 02:30+00', 'America/Chicago', 180, 150),
  -- Day 4: 45 min, under the cap
  ('20000000-0000-4000-8000-000000000004', 'practice', 'signed', timestamptz '2026-10-06 14:00+00', timestamptz '2026-10-06 14:45+00', 'America/Chicago', 45, 0),
  -- A voided drive and an in-progress drive never count
  ('20000000-0000-4000-8000-000000000004', 'practice', 'voided', timestamptz '2026-10-07 14:00+00', timestamptz '2026-10-07 15:00+00', 'America/Chicago', 60, 0),
  ('20000000-0000-4000-8000-000000000004', 'practice', 'in_progress', timestamptz '2026-10-08 14:00+00', null, 'America/Chicago', 0, 0);

select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;   -- school owner
select results_eq(
  $$ select local_date, raw_minutes, credited_minutes, night_credited_minutes, capped
       from student_hours_by_day('20000000-0000-4000-8000-000000000004') $$,
  $$ values (date '2026-10-01', 150, 120, 0, true),
            (date '2026-10-02', 160, 120, 60, true),
            (date '2026-10-04', 180, 120, 120, true),
            (date '2026-10-06', 45, 45, 0, false) $$,
  'per-day credit: cap at 120, night limited to the credited total, local date (01:00 UTC Oct 3 = Oct 2 in Austin)');
select is((select credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000004')), 405, 'total credited = 120+120+120+45');
select is((select night_credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000004')), 180, 'night credited = 60+120');
select is((select raw_minutes from student_hours_summary('20000000-0000-4000-8000-000000000004')), 535, 'raw minutes before the cap');
select is((select practice_hours from students where id = '20000000-0000-4000-8000-000000000004'), 6.8::numeric, 'roster cache = 405 min = 6.8 h');
select is((select count(*)::int from student_hours_by_day('20000000-0000-4000-8000-000000000004', date '2026-10-02', date '2026-10-04')), 2, 'date range filter');
reset role;

-- ---- A state whose requirement is unconfirmed (Hawaii, no daily cap) ----
update students set state_code = 'HI' where id = '20000000-0000-4000-8000-000000000004';
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select rule_verified from student_hours_summary('20000000-0000-4000-8000-000000000004')), false, 'Hawaii rule is flagged (unconfirmed)');
select is((select credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000004')), 535, 'no daily cap -> everything counts');
reset role;

-- ---- A place with no rule at all (Puerto Rico is not in the 51) ----
update students set state_code = 'PR' where id = '20000000-0000-4000-8000-000000000004';
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select rule_set_id from student_hours_summary('20000000-0000-4000-8000-000000000004')), null, 'no rule for PR');
select is((select requirement_met from student_hours_summary('20000000-0000-4000-8000-000000000004')), false, 'never "met" without a rule');
reset role;

-- ---- Per-student override pins a rule ----
update students set rule_set_id = (select id from state_rule_sets where state_code = 'TX' and version = 1)
 where id = '20000000-0000-4000-8000-000000000004';
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select credited_minutes from student_hours_summary('20000000-0000-4000-8000-000000000004')), 405, 'override applies the Texas cap again');
reset role;

-- ---- Paging (keyset) ----
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
create temporary table p1 on commit drop as select * from list_drives('20000000-0000-4000-8000-000000000001', null, null, 5);
select is((select count(*)::int from p1), 5, 'page 1 has 5 drives');
create temporary table p2 on commit drop as
  select * from list_drives('20000000-0000-4000-8000-000000000001',
                            (select started_at from p1 order by started_at asc, id asc limit 1),
                            (select id from p1 order by started_at asc, id asc limit 1), 5);
select is((select count(*)::int from p2), 5, 'page 2 has 5 drives');
select is((select count(*)::int from p1 join p2 using (id)), 0, 'pages do not overlap');
select ok((select max(started_at) from p2) < (select min(started_at) from p1), 'page 2 is older than page 1');
select is((select count(*)::int from list_drives('20000000-0000-4000-8000-000000000001', null, null, 100000)), 14, 'limit is capped (and all 14 fit)');
select is((select count(*)::int from list_drives('20000000-0000-4000-8000-000000000002')), 0, 'list_drives obeys RLS for other students');
reset role;

select * from finish();
rollback;
