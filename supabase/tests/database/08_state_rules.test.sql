-- State rules v2: all 51 jurisdictions, every rule type, version picking by permit date,
-- supervisor checks, resources API. Scenario students are made here (school 1, Green Light).
begin;
\ir 00_helpers.psql
select no_plan();

create or replace function pg_temp.stu(p_code text, p_state text, p_permit date) returns uuid language sql as $$
  insert into public.students (id, school_id, first_name, last_name, state_code, permit_on, join_code)
  values (extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'rules-test:' || p_code),
          '10000000-0000-4000-8000-000000000001', 'Test', p_code, p_state, p_permit, 'R' || p_code)
  returning id;
$$;
create or replace function pg_temp.sid(p_code text) returns uuid language sql immutable as $$
  select extensions.uuid_generate_v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8'::uuid, 'rules-test:' || p_code);
$$;
-- A signed drive starting 15:00 UTC (10:00 in Chicago, so local_date = p_day).
create or replace function pg_temp.add(p_code text, p_day date, p_min int, p_night int default 0, p_weather int default 0,
                                       p_kind text default 'practice', p_status text default 'signed') returns uuid language sql as $$
  insert into public.drives (student_id, kind, source, status, started_at, ended_at, tz, duration_minutes, night_minutes,
                             weather_minutes, locked_at)
  values (pg_temp.sid(p_code), p_kind, case when p_kind = 'lesson' then 'instructor' else 'manual' end, p_status,
          p_day + time '15:00' at time zone 'UTC', p_day + time '15:00' at time zone 'UTC' + make_interval(mins => p_min),
          'America/Chicago', p_min, p_night, p_weather, case when p_status = 'signed' then now() end)
  returning id;
$$;
create or replace function pg_temp.req(p_code text, p_key text, p_field text) returns int language sql as $$
  select (r ->> p_field)::int from jsonb_array_elements(private.rule_progress(pg_temp.sid(p_code)) -> 'requirements') r
   where r ->> 'key' = p_key;
$$;
create or replace function pg_temp.prog(p_code text) returns jsonb language sql as $$
  select private.rule_progress(pg_temp.sid(p_code));
$$;

-- ---------------------------------------------------------------- the data
select is((select count(distinct state_code)::int from state_rule_sets), 51, '51 jurisdictions (50 states + DC)');
select is((select count(*)::int from state_rule_sets), 53, '53 rule sets (NJ and WI have an older version)');
select is((select count(*)::int from state_rule_sets where state_code in ('NJ', 'WI')), 4, 'two versions each for NJ and WI');
select is((select status from state_rule_sets where state_code = 'HI'), 'unconfirmed', 'Hawaii is unconfirmed');
select is((select total_minutes from state_rule_sets where state_code = 'HI'), null, 'Hawaii hours are not invented');
select ok((select field_status ? 'total_minutes' from state_rule_sets where state_code = 'HI'), 'Hawaii explains why');
select is((select array_agg(state_code order by state_code) from state_rule_sets where requirement_kind = 'none'), array['AR', 'MS'], 'AR and MS have no hours rule');
select is((select count(*)::int from state_rule_sets where source_url = ''), 0, 'every rule set has a source page');
select is((select count(*)::int from state_rule_sets where last_checked is null), 0, 'every rule set has last_checked');
select is((select count(*)::int from state_rule_sets where status = 'verified' and verified_on is null), 0, 'verified rows have verified_on');
select is((select array_agg(state_code order by state_code) from state_rule_sets where notarization = 'required'),
          array['AZ', 'FL', 'OH', 'OK', 'RI', 'SD'], 'notary required: AZ FL OH OK RI SD');
select is((select array_agg(state_code order by state_code) from state_rule_sets where notarization = 'if_signer_absent'),
          array['AK', 'IL'], 'notary if the parent is absent: AK IL');
select is((select array_agg(state_code order by state_code) from state_rule_sets where digital_log = 'accepted'),
          array['MI', 'MT', 'NC', 'NH', 'NM'], 'digital logs accepted: MI MT NC NH NM');
select is((select digital_log_apps from state_rule_sets where state_code = 'NV'), array['RoadReady'], 'NV: only DLD-130 or RoadReady');
select is((select array_agg(state_code order by state_code) from state_rule_sets where log_unit = 'minutes'), array['MN', 'NV'], 'MN and NV count minutes');
select is((select array_agg(state_code order by state_code) from state_rule_sets where weather_minutes is not null), array['AK', 'PA', 'SD'], 'weather hours: AK PA SD');
select is((select (weather_minutes, weather_counts_night)::text from state_rule_sets where state_code = 'PA'), '(300,f)', 'PA 5 h bad weather');
select is((select weather_minutes from state_rule_sets where state_code = 'SD'), 600, 'SD 10 h bad weather');
select is((select (total_minutes, night_minutes, daily_cap_minutes)::text from state_rule_sets where state_code = 'TX'), '(1800,600,120)', 'TX 30/10, 2 h a day');
select is((select weekly_cap_minutes from state_rule_sets where state_code = 'NC'), 600, 'NC 10 h a week');
select is((select (supervisor_min_age, supervisor_min_years_licensed)::text from state_rule_sets where state_code = 'TX'), '(21,1.0)', 'TX supervisor 21 with 1 yr');
select is((select (supervisor_min_age, supervisor_parent_exempt)::text from state_rule_sets where state_code = 'NH'), '(25,t)', 'NH supervisor 25, parents exempt');
select is((select (instructor_multiplier, instructor_max_minutes)::text from state_rule_sets where state_code = 'WI' and version = 2), '(2.00,300)', 'WI instructor x2 up to 5 h');
select is((select jsonb_array_length(stages) from state_rule_sets where state_code = 'IA'), 2, 'IA has 2 stages');
select is((select array_agg(state_code order by state_code) from state_rule_sets where jsonb_array_length(alternatives) > 0),
          array['AL', 'AZ', 'MA', 'MD', 'MN', 'OR'], 'alternatives: AL AZ MA MD MN OR');
select is((select pending_change_on from state_rule_sets where state_code = 'VA'), date '2027-01-01', 'VA change noted');
select is((select form_number from state_rule_sets where state_code = 'TX'), 'DES150N (TDLR)', 'TX form number');
select is((select count(*)::int from state_rule_sets where night_minutes = 0), 0, 'unknown night is null, never 0');

-- ------------------------------------------------- TX: permit date picks the rule, daily cap
select pg_temp.stu('TX1', 'TX', '2026-05-01');
select pg_temp.add('TX1', '2026-06-01', 150, 30);
select pg_temp.add('TX1', '2026-06-02', 60);
select is(pg_temp.req('TX1', 'total', 'credited_minutes'), 180, 'TX: 150 on one day counts 120, plus 60');
select is(pg_temp.req('TX1', 'night', 'credited_minutes'), 30, 'TX night');
select is((pg_temp.prog('TX1') -> 'caps' ->> 'capped_days')::int, 1, 'TX one capped day');
select is(pg_temp.prog('TX1') -> 'rule' ->> 'selected_by', 'permit_date', 'rule picked by permit date');
select is(pg_temp.prog('TX1') -> 'still_needed' ->> 0, '27 h more in total', 'still needed, in words');

-- ------------------------------------------------- NC: weekly cap (Mon-Sun weeks)
select pg_temp.stu('NC1', 'NC', '2026-05-01');
select pg_temp.add('NC1', d::date, 120, 20) from generate_series(date '2026-09-07', date '2026-09-12', interval '1 day') d;   -- Mon-Sat
select pg_temp.add('NC1', '2026-09-14', 60);                                                                                 -- next Monday
select is(pg_temp.req('NC1', 'total', 'credited_minutes'), 660, 'NC: 720 in one week counts 600, plus 60 the next');
select is(pg_temp.req('NC1', 'night', 'credited_minutes'), 120, 'NC night clipped within the week');
select is((pg_temp.prog('NC1') -> 'caps' ->> 'capped_weeks')::int, 1, 'NC one capped week');
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select is((select count(*)::int from student_hours_by_day(pg_temp.sid('NC1')) where week_start = date '2026-09-07'), 6, 'by-day rows carry week_start');
reset role;

-- ------------------------------------------------- PA: inclement weather
select pg_temp.stu('PA1', 'PA', '2026-05-01');
select pg_temp.add('PA1', '2026-06-01', 200, 0, 100);
select is(pg_temp.req('PA1', 'weather', 'credited_minutes'), 100, 'PA weather credited');
select is(pg_temp.req('PA1', 'weather', 'remaining_minutes'), 200, 'PA 200 weather minutes to go');
select ok(pg_temp.prog('PA1') -> 'still_needed' ? '3 h 20 m more in inclement weather', 'PA still needed mentions weather');
select is((select count(*)::int from jsonb_array_elements(pg_temp.prog('PA1') -> 'requirements')), 3, 'PA: total, night, weather');

-- AK: "challenging conditions" = night or bad weather
select pg_temp.stu('AK1', 'AK', '2026-05-01');
select pg_temp.add('AK1', '2026-06-01', 60, 30, 40);
select is(pg_temp.req('AK1', 'challenging', 'credited_minutes'), 60, 'AK: night + weather, up to the drive');
select is(pg_temp.req('AK1', 'night', 'credited_minutes'), null, 'AK has no separate night target');

-- Weather minutes: checked and locked
select throws_ok($$ select pg_temp.add('AK1', '2026-06-02', 30, 0, 31) $$, '23514', null, 'weather cannot exceed the drive');
select throws_ok($$ update drives set weather_minutes = 0 where student_id = pg_temp.sid('PA1') $$, '42501', null, 'weather minutes lock at signing');
create temporary table pa_pending on commit drop as select pg_temp.add('PA1', '2026-06-03', 30, 0, 0, 'practice', 'pending') as id;
select lives_ok($$ update drives set weather_minutes = 10 where id = (select id from pa_pending) $$, 'pending drive can be tagged');
select is(pg_temp.req('PA1', 'weather', 'pending_minutes'), 10, 'pending weather shown separately');

-- ------------------------------------------------- WI: instructor x2 (max 5 h), and the 2021 version switch
select pg_temp.stu('WI2', 'WI', '2022-01-01');
select pg_temp.add('WI2', '2026-06-01', 200, 0, 0, 'lesson');
select pg_temp.add('WI2', '2026-06-02', 200, 0, 0, 'lesson');
select pg_temp.add('WI2', '2026-06-03', 100);
select is(pg_temp.req('WI2', 'total', 'credited_minutes'), 700, 'WI: 400 lesson min -> 300 counted x2 = 600, plus 100');
select is(pg_temp.prog('WI2') -> 'instructor', '{"counts": true, "raw_minutes": 400, "multiplier": 2.00, "max_minutes": 300, "counted_minutes": 300, "credited_minutes": 600}'::jsonb, 'WI instructor block');
select is((select practice_hours from students where id = pg_temp.sid('WI2')), 11.7::numeric, 'roster cache uses the same math');
update students set permit_on = '2021-07-10' where id = pg_temp.sid('WI2');
select is((pg_temp.prog('WI2') -> 'rule' ->> 'version')::int, 1, 'WI permit before 2021-07-11 -> version 1');
select is(pg_temp.req('WI2', 'total', 'required_minutes'), 1800, 'WI v1 30 h');
select is(pg_temp.req('WI2', 'total', 'credited_minutes'), 100, 'WI v1: instructor time not counted');
select is(pg_temp.req('WI2', 'night', 'required_minutes'), null, 'WI v1 night unknown -> no night target');
select is((select practice_hours from students where id = pg_temp.sid('WI2')), 1.7::numeric, 'permit change refreshes the roster cache');

-- A school's hand-typed hours are kept when a student with no drives changes state
select pg_temp.stu('HAND', 'TX', null);
update students set practice_hours = 12.5 where id = pg_temp.sid('HAND');
update students set state_code = 'NC' where id = pg_temp.sid('HAND');
select is((select practice_hours from students where id = pg_temp.sid('HAND')), 12.5::numeric, 'no drives -> typed hours untouched');

-- CO: instructor time counts 1:1 up to 6 h
select pg_temp.stu('CO1', 'CO', '2026-05-01');
select pg_temp.add('CO1', '2026-06-01', 400, 0, 0, 'lesson');
select is(pg_temp.req('CO1', 'total', 'credited_minutes'), 360, 'CO lessons capped at 6 h');

-- ------------------------------------------------- IA: two stages, second counts after the milestone
select pg_temp.stu('IA1', 'IA', '2026-01-01');
select pg_temp.add('IA1', d::date, 120, 12) from generate_series(date '2026-03-01', date '2026-03-10', interval '1 day') d;
select pg_temp.add('IA1', '2026-03-12', 300, 60);
select is((pg_temp.prog('IA1') -> 'stages' -> 0 ->> 'met')::boolean, true, 'IA stage 1 met (20 h / 2 night)');
select is(pg_temp.prog('IA1') -> 'stages' -> 1 ->> 'window_from', '2026-03-11', 'IA stage 2 assumed to start the day after stage 1');
select is((pg_temp.prog('IA1') -> 'stages' -> 1 ->> 'milestone_assumed')::boolean, true, 'flagged as assumed');
select is((pg_temp.prog('IA1') -> 'stages' -> 1 -> 'requirements' -> 0 ->> 'credited_minutes')::int, 300, 'IA stage 2 counts only later drives');
select is((pg_temp.prog('IA1') -> 'stages' -> 1 -> 'requirements' -> 0 ->> 'remaining_minutes')::int, 300, 'IA stage 2: 5 h to go');
select is(pg_temp.req('IA1', 'total', 'credited_minutes'), 1500, 'IA overall');
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;    -- school owner
select lives_ok($$ select set_rule_milestone(pg_temp.sid('IA1'), 'intermediate', '2026-03-13') $$, 'desk records the intermediate license date');
select is((select count(*)::int from student_rule_milestones where student_id = pg_temp.sid('IA1')), 1, 'milestone readable');
select throws_ok($$ insert into student_rule_milestones (student_id, milestone_key, reached_on) values (pg_temp.sid('IA1'), 'x', current_date) $$,
                 '42501', null, 'no direct writes to milestones');
select throws_ok($$ select set_rule_milestone(pg_temp.sid('IA1'), 'segment_9', '2026-03-13') $$, '22023', null, 'unknown stage key rejected');
reset role;
select is((pg_temp.prog('IA1') -> 'stages' -> 1 ->> 'milestone_assumed')::boolean, false, 'recorded date replaces the assumption');
select is((pg_temp.prog('IA1') -> 'stages' -> 1 -> 'requirements' -> 0 ->> 'credited_minutes')::int, 0, 'nothing after 2026-03-13 yet');

-- MI: cumulative stage before Segment 2
select pg_temp.stu('MI1', 'MI', '2026-01-01');
select pg_temp.add('MI1', '2026-03-01', 1000, 60);
select is((pg_temp.prog('MI1') -> 'stages' -> 0 -> 'requirements' -> 0 ->> 'remaining_minutes')::int, 800, 'MI: 800 more min before Segment 2');
select ok(pg_temp.prog('MI1') -> 'still_needed' ? 'Before Segment 2: 13 h 20 m more in total', 'MI stage shows in still_needed');
select is(pg_temp.req('MI1', 'total', 'required_minutes'), 3000, 'MI overall 50 h');

-- ------------------------------------------------- OR / MN / AL: alternatives
select pg_temp.stu('OR1', 'OR', '2026-01-01');
select pg_temp.add('OR1', '2026-03-01', 600);
select is(pg_temp.req('OR1', 'total', 'required_minutes'), 6000, 'OR 100 h by default');
select pg_temp.login('00000000-0000-4000-8000-000000000001'); set local role authenticated;
select lives_ok($$ select set_rule_alternative(pg_temp.sid('OR1'), 'driver_ed') $$, 'pick the driver-ed path');
select is((select required_minutes from student_hours_summary(pg_temp.sid('OR1'))), 3000, 'OR 50 h with approved driver ed');
select throws_ok($$ select set_rule_alternative(pg_temp.sid('OR1'), 'age_25_plus') $$, '22023', null, 'only this state''s options');
reset role;
select is(pg_temp.prog('OR1') -> 'alternative' ->> 'key', 'driver_ed', 'progress names the path');
select pg_temp.stu('MN1', 'MN', '2026-01-01');
update students set rule_alternative = 'parent_class' where id = pg_temp.sid('MN1');
select is(pg_temp.req('MN1', 'total', 'required_minutes'), 2400, 'MN parent class 40 h');
select is(pg_temp.req('MN1', 'night', 'required_minutes'), 900, 'MN alternative keeps the 15 h night');
select is(pg_temp.prog('MN1') -> 'rule' ->> 'log_unit', 'minutes', 'MN log unit minutes');
select pg_temp.stu('AL1', 'AL', '2026-01-01');
update students set rule_alternative = 'driver_ed' where id = pg_temp.sid('AL1');
select is(pg_temp.prog('AL1') -> 'requirements', '[]'::jsonb, 'AL driver-ed path has no hours target');
select is(pg_temp.prog('AL1') -> 'all_met', 'null'::jsonb, 'not "met" by hours either');

-- ------------------------------------------------- NJ: version by permit date
select pg_temp.stu('NJ1', 'NJ', '2025-01-31');
select is(pg_temp.prog('NJ1') -> 'rule' ->> 'status', 'unconfirmed', 'NJ permit before 2025-02-01 -> unconfirmed v1');
select is(pg_temp.prog('NJ1') -> 'requirements', '[]'::jsonb, 'no invented target for old NJ permits');
update students set permit_on = '2025-02-01' where id = pg_temp.sid('NJ1');
select is((pg_temp.prog('NJ1') -> 'rule' ->> 'version')::int, 2, 'NJ permit on 2025-02-01 -> v2');
select is(pg_temp.req('NJ1', 'total', 'required_minutes'), 3000, 'NJ v2 50 h');
update students set permit_on = null where id = pg_temp.sid('NJ1');
select is(pg_temp.prog('NJ1') -> 'rule' ->> 'selected_by', 'today', 'unknown permit date -> today''s rule');
select is((pg_temp.prog('NJ1') -> 'rule' ->> 'version')::int, 2, 'today is NJ v2');

-- ------------------------------------------------- NV: minutes
select pg_temp.stu('NV1', 'NV', '2026-01-01');
select pg_temp.add('NV1', '2026-03-01', 47, 13);
select is(pg_temp.req('NV1', 'total', 'credited_minutes'), 47, 'NV exact minutes');
select is(pg_temp.req('NV1', 'total', 'remaining_minutes'), 2953, 'NV 2,953 minutes to go');
select is(pg_temp.prog('NV1') -> 'paperwork' ->> 'digital_log', 'listed_apps', 'NV paperwork: listed apps only');

-- ------------------------------------------------- Supervisor age / experience
select pg_temp.stu('NH1', 'NH', '2026-01-01');
insert into supervisors (id, student_id, name, relationship, birth_date) values
  ('49000000-0000-4000-8000-000000000001', pg_temp.sid('NH1'), 'Young Aunt', 'other', current_date - interval '24 years'),
  ('49000000-0000-4000-8000-000000000002', pg_temp.sid('NH1'), 'Young Dad', 'parent', current_date - interval '24 years'),
  ('49000000-0000-4000-8000-000000000003', pg_temp.sid('NH1'), 'Older Friend', 'other', current_date - interval '30 years'),
  ('49000000-0000-4000-8000-000000000004', pg_temp.sid('NH1'), 'Unknown Age', 'other', null);
create or replace function pg_temp.signoff(p_code text, p_sup uuid) returns void language sql as $$
  insert into public.drive_signoffs (drive_id, school_id, student_id, method, supervisor_id, supervisor_name, snapshot, snapshot_sha256)
  values (pg_temp.add(p_code, current_date - 1, 30, 0, 0, 'practice', 'pending'), '10000000-0000-4000-8000-000000000001',
          pg_temp.sid(p_code), 'on_device', p_sup, 'x', '{}', 'x');
$$;
select throws_ok($$ select pg_temp.signoff('NH1', '49000000-0000-4000-8000-000000000001') $$, '22023',
                 'In NH the supervisor must be at least 25 (licensed parents and guardians excepted)', 'NH: 24-year-old non-parent blocked');
select lives_ok($$ select pg_temp.signoff('NH1', '49000000-0000-4000-8000-000000000002') $$, 'NH: licensed parent of any age OK');
select lives_ok($$ select pg_temp.signoff('NH1', '49000000-0000-4000-8000-000000000003') $$, 'NH: 30-year-old OK');
select lives_ok($$ select pg_temp.signoff('NH1', '49000000-0000-4000-8000-000000000004') $$, 'NH: unknown age does not block');
select is((pg_temp.prog('NH1') -> 'supervisor' ->> 'unverified_drives')::int, 1, 'unknown age is counted');

-- TX through the real sign_drive(): Maya's mom with a too-recent license
update supervisors set birth_date = '1985-01-01', licensed_since = current_date - interval '6 months'
 where id = '40000000-0000-4000-8000-000000000001';
insert into drives (id, student_id, status, started_at, ended_at, tz, duration_minutes, source)
values ('49100000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'pending',
        now() - interval '2 hours', now() - interval '1 hour', 'America/Chicago', 60, 'manual');
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;   -- Maya
select throws_ok($$ select sign_drive('49100000-0000-4000-8000-000000000001', 'on_device', '40000000-0000-4000-8000-000000000001', 'AL') $$,
                 '22023', 'In TX the supervisor must have been licensed at least 1 year(s)', 'TX: licensed under 1 year blocked');
reset role;
update supervisors set licensed_since = '2003-06-01' where id = '40000000-0000-4000-8000-000000000001';
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
select lives_ok($$ select sign_drive('49100000-0000-4000-8000-000000000001', 'on_device', '40000000-0000-4000-8000-000000000001', 'AL') $$,
                'TX: 21+ and licensed 1+ year signs');
select ok(student_rule_progress('20000000-0000-4000-8000-000000000001') ? 'requirements', 'student reads her own progress');
reset role;

-- ------------------------------------------------- Resources API
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
select is(state_resources('nv') ->> 'summary',
          '50 h of supervised driving, including 10 h at night. Logged in minutes (3,000 / 600).', 'NV summary');
select is(state_resources('NV') ->> 'how_to_use_licenselogger_log', 'official_form_only', 'NV: official form or RoadReady only');
select is(state_resources('NC') ->> 'how_to_use_licenselogger_log', 'submit_printout', 'NC: printout accepted');
select is(state_resources('TX') ->> 'how_to_use_licenselogger_log', 'copy_to_official_form', 'TX: copy to DES150N');
select is(state_resources('CA') ->> 'how_to_use_licenselogger_log', 'records_only', 'CA: certification only');
select is(state_resources('AR') ->> 'how_to_use_licenselogger_log', 'none', 'AR: no hours rule');
select is(state_resources('HI') ->> 'how_to_use_licenselogger_log', 'unconfirmed', 'HI: unconfirmed');
select ok((select bool_or(c ->> 'key' = 'notary') from jsonb_array_elements(state_resources('AZ') -> 'checklist') c), 'AZ checklist has the notary step');
select ok((select bool_or(c ->> 'key' = 'caps') from jsonb_array_elements(state_resources('TX') -> 'checklist') c), 'TX checklist mentions the daily cap');
select is(state_resources('TX') -> 'checklist' -> 0 ->> 'step', '1', 'steps are numbered');
select ok((select count(*) from jsonb_array_elements(state_resources('TX') -> 'links')) >= 3, 'TX has form, handbook and GDL links');
select is(state_resources('TX') -> 'form' ->> 'number', 'DES150N (TDLR)', 'form metadata');
select is(state_resources('VA') -> 'pending_change' ->> 'on', '2027-01-01', 'VA pending change');
select is((state_resources('NJ', '2024-06-01') ->> 'version')::int, 1, 'state_resources honours the permit date');
select throws_ok($$ select state_resources('PR') $$, 'P0002', null, 'unknown place -> not found');
select ok(my_rule_resources('20000000-0000-4000-8000-000000000001') ? 'progress', 'my_rule_resources includes progress');
select throws_ok($$ select my_rule_resources(pg_temp.sid('OR1')) $$, 'P0002', null, 'cannot read another student''s resources');
reset role;
set local role anon;
select throws_ok($$ select state_resources('TX') $$, '42501', null, 'anon cannot call state_resources');
reset role;

-- ------------------------------------------------- App paths: weather tag + supervisor dates as the student
insert into drives (id, student_id, status, started_at, ended_at, tz, duration_minutes, source)
values ('49100000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', 'pending',
        now() - interval '3 hours', now() - interval '150 minutes', 'America/Chicago', 30, 'manual');
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;   -- Maya
select lives_ok($$ update drives set weather_minutes = 15, conditions = '{Rain}' where id = '49100000-0000-4000-8000-000000000002' $$, 'student tags bad-weather minutes');
select is((select weather_minutes from drives where id = '49100000-0000-4000-8000-000000000002'), 15, 'weather saved');
select lives_ok($$ insert into supervisors (student_id, name, relationship, birth_date, licensed_since)
                   values ('20000000-0000-4000-8000-000000000001', 'Grandpa Lopez', 'other', '1955-03-01', '1972-06-01') $$, 'student adds a supervisor with dates');
select throws_ok($$ insert into supervisors (student_id, name, birth_date, licensed_since)
                    values ('20000000-0000-4000-8000-000000000001', 'Bad Dates', '1990-01-01', '1980-01-01') $$, '23514', null, 'licensed before birth rejected');
reset role;

select * from finish();
rollback;
