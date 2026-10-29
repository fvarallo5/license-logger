-- LicenseLogger 014: state rules v2 - every rule type the 51 jurisdictions use.
-- Contract: docs/STATE_RULES_SCHEMA.md. The data itself is in migration 015 (generated).
--
-- Plain words: each state's rule row can now say
--   total / night / bad-weather hours, a daily or weekly cap, how instructor lessons count,
--   stages (IA, MI), alternative totals (OR driver ed...), supervisor age/experience,
--   notary and "app log accepted" flags, the official form and links, and which permit
--   dates it applies to. A student's rule is picked from their state + permit issue date.
-- Additive only: new columns/tables/functions; nothing on live is dropped or renamed.
-- (The 3 relaxed CHECKs below are on state_rule_sets, which is new in migration 006.)

-- ---------------------------------------------------------------------------
-- 1. state_rule_sets: new columns
-- ---------------------------------------------------------------------------
alter table public.state_rule_sets
  alter column total_minutes drop not null,     -- AR/MS have no hours rule, HI is unconfirmed
  alter column night_minutes drop not null,     -- null = "not specified", never 0
  alter column night_minutes drop default;
alter table public.state_rule_sets drop constraint if exists state_rule_sets_total_minutes_check;
alter table public.state_rule_sets drop constraint if exists state_rule_sets_night_rule_check;
alter table public.state_rule_sets drop constraint if exists state_rule_sets_check;   -- night <= total

alter table public.state_rule_sets
  add column if not exists jurisdiction_name text not null default '',
  add column if not exists effective_to date,
  add column if not exists status text not null default 'unconfirmed',
  add column if not exists last_checked date,
  add column if not exists requirement_kind text not null default 'log',
  add column if not exists night_definition text not null default '',
  add column if not exists weather_minutes int,
  add column if not exists weather_counts_night boolean not null default false,
  add column if not exists weekly_cap_minutes int,
  add column if not exists log_unit text not null default 'hours',
  add column if not exists instructor_multiplier numeric(4, 2) not null default 1,
  add column if not exists instructor_max_minutes int,
  add column if not exists stages jsonb not null default '[]'::jsonb,
  add column if not exists alternatives jsonb not null default '[]'::jsonb,
  add column if not exists supervisor_min_age int,
  add column if not exists supervisor_min_years_licensed numeric(4, 1),
  add column if not exists supervisor_parent_exempt boolean not null default false,
  add column if not exists supervisor_rule text not null default '',
  add column if not exists notarization text not null default 'not_stated',
  add column if not exists notarization_note text not null default '',
  add column if not exists digital_log text not null default 'not_stated',
  add column if not exists digital_log_apps text[] not null default '{}',
  add column if not exists digital_log_note text not null default '',
  add column if not exists form_type text not null default 'unconfirmed',
  add column if not exists form_type_detail text not null default '',
  add column if not exists form_name text not null default '',
  add column if not exists form_number text not null default '',
  add column if not exists form_pdf_url text not null default '',
  add column if not exists form_pdf_status text not null default '',
  add column if not exists alt_form_name text not null default '',
  add column if not exists alt_form_pdf_url text not null default '',
  add column if not exists handbook_url text not null default '',
  add column if not exists parent_guide_url text not null default '',
  add column if not exists gdl_page_url text not null default '',
  add column if not exists link_status jsonb not null default '{}'::jsonb,
  add column if not exists other_rules text not null default '',
  add column if not exists field_status jsonb not null default '{}'::jsonb,
  add column if not exists pending_change_on date,
  add column if not exists pending_change_note text not null default '';

-- Existing example rows: keep them valid under the new checks (migration 015 overwrites them).
update public.state_rule_sets
   set status = case when verified then 'verified' else 'unconfirmed' end,
       last_checked = coalesce(last_checked, verified_on);

alter table public.state_rule_sets
  add constraint state_rule_sets_total_v2_check check (total_minutes is null or total_minutes > 0),
  add constraint state_rule_sets_night_v2_check check (night_minutes is null or total_minutes is null or night_minutes <= total_minutes),
  add constraint state_rule_sets_weather_check check (weather_minutes is null or (weather_minutes > 0 and (total_minutes is null or weather_minutes <= total_minutes))),
  add constraint state_rule_sets_weekly_cap_check check (weekly_cap_minutes is null or weekly_cap_minutes > 0),
  add constraint state_rule_sets_instr_check check (instructor_multiplier > 0 and instructor_multiplier <= 10
                                                   and (instructor_max_minutes is null or instructor_max_minutes > 0)),
  add constraint state_rule_sets_night_rule_v2_check check (night_rule in
      ('sunset_sunrise', 'half_hour_after_sunset', 'after_sunset', 'darkness', 'unspecified', 'clock_window')),
  add constraint state_rule_sets_status_check check (status in ('verified', 'partially_verified', 'unconfirmed')),
  add constraint state_rule_sets_kind_check check (requirement_kind in ('log', 'log_any_format', 'certification', 'none', 'unconfirmed')),
  add constraint state_rule_sets_unit_check check (log_unit in ('hours', 'minutes')),
  add constraint state_rule_sets_notary_check check (notarization in ('required', 'if_signer_absent', 'not_stated')),
  add constraint state_rule_sets_digital_check check (digital_log in ('accepted', 'listed_apps', 'not_stated')),
  add constraint state_rule_sets_form_type_check check (form_type in ('full_log', 'certification', 'none', 'unconfirmed')),
  add constraint state_rule_sets_window_check check (effective_to is null or effective_to > effective_from),
  add constraint state_rule_sets_sup_check check ((supervisor_min_age is null or supervisor_min_age between 16 and 99)
                                                 and (supervisor_min_years_licensed is null or supervisor_min_years_licensed >= 0)),
  add constraint state_rule_sets_json_check check (jsonb_typeof(stages) = 'array' and jsonb_typeof(alternatives) = 'array'
                                                  and jsonb_typeof(link_status) = 'object' and jsonb_typeof(field_status) = 'object'),
  add constraint state_rule_sets_verified_v2_check check (verified = (status = 'verified'));

create index if not exists state_rule_sets_pick_idx on public.state_rule_sets (state_code, effective_from desc, version desc);

comment on column public.state_rule_sets.status is 'verified | partially_verified (see field_status) | unconfirmed';
comment on column public.state_rule_sets.stages is 'Ordered stages; see docs/STATE_RULES_SCHEMA.md section 2';
comment on column public.state_rule_sets.alternatives is 'Alternative totals; see docs/STATE_RULES_SCHEMA.md section 3';

-- ---------------------------------------------------------------------------
-- 2. Per-student inputs
-- ---------------------------------------------------------------------------
alter table public.students add column if not exists rule_alternative text
  check (rule_alternative is null or char_length(rule_alternative) between 1 and 40);
alter table public.drives add column if not exists weather_minutes int not null default 0;
alter table public.drives drop constraint if exists drives_weather_minutes_check;
alter table public.drives add constraint drives_weather_minutes_check
  check (weather_minutes >= 0 and weather_minutes <= duration_minutes);
alter table public.supervisors
  add column if not exists birth_date date,
  add column if not exists licensed_since date;
alter table public.supervisors drop constraint if exists supervisors_dates_check;
alter table public.supervisors add constraint supervisors_dates_check
  check ((birth_date is null or birth_date between date '1900-01-01' and current_date)
     and (licensed_since is null or licensed_since >= coalesce(birth_date, date '1900-01-01')));

-- Signed drives: weather minutes are locked like the other drive facts.
create or replace function private.drives_weather_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.locked_at is not null and new.weather_minutes is distinct from old.weather_minutes then
    raise exception 'This drive is signed and locked' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.drives_weather_lock() from public, anon, authenticated;
drop trigger if exists drives_weather_lock on public.drives;
create trigger drives_weather_lock before update of weather_minutes on public.drives
  for each row execute function private.drives_weather_lock();

-- Stage dates (IA: date of the intermediate license; MI: date Segment 2 was reached).
create table if not exists public.student_rule_milestones (
  student_id uuid not null references public.students (id) on delete cascade,
  milestone_key text not null check (milestone_key ~ '^[a-z0-9_]{1,40}$'),
  reached_on date not null,
  set_by uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (student_id, milestone_key)
);
create index if not exists student_rule_milestones_set_by_idx on public.student_rule_milestones (set_by);
alter table public.student_rule_milestones enable row level security;
alter table public.student_rule_milestones force row level security;
drop policy if exists student_rule_milestones_select on public.student_rule_milestones;
create policy student_rule_milestones_select on public.student_rule_milestones
  for select to authenticated using (private.can_view_student(student_id));
revoke all on table public.student_rule_milestones from public, anon, authenticated;
grant select on table public.student_rule_milestones to authenticated;     -- writes go through set_rule_milestone()
grant select, insert, update, delete on table public.student_rule_milestones to service_role;

-- ---------------------------------------------------------------------------
-- 3. Picking the rule: override, else state + permit date (today if unknown)
-- ---------------------------------------------------------------------------
create or replace function private.rule_for_state(p_state_code text, p_on date)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select r.id from public.state_rule_sets r
   where r.state_code = upper(p_state_code)
     and r.effective_from <= coalesce(p_on, current_date)
     and (r.effective_to is null or r.effective_to > coalesce(p_on, current_date))
   order by r.effective_from desc, r.version desc
   limit 1;
$$;
revoke all on function private.rule_for_state(text, date) from public, anon;
grant execute on function private.rule_for_state(text, date) to authenticated;

create or replace function private.rule_for_student(p_student_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select coalesce(s.rule_set_id, private.rule_for_state(s.state_code, s.permit_on))
    from public.students s
   where s.id = p_student_id;
$$;

-- "20 h 36 m" / "45 m" / "3 h"
create or replace function private.fmt_minutes(p int)
returns text
language sql immutable set search_path = ''
as $$
  select case when p is null then null
              when p % 60 = 0 then (p / 60)::text || ' h'
              when p < 60 then p::text || ' m'
              else (p / 60)::text || ' h ' || (p % 60)::text || ' m' end;
$$;
grant execute on function private.fmt_minutes(int) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. The credit math (docs section 5)
-- ---------------------------------------------------------------------------
create or replace function private.rule_credit(
  p_student_id uuid, p_rule_id uuid, p_statuses text[], p_from date default null, p_to date default null
)
returns table (
  total int, night int, weather int, challenging int,
  practice_raw int, practice_credit int,
  lesson_raw int, lesson_counted int, lesson_credit int,
  capped_days int, capped_weeks int, miles numeric
)
language sql stable security definer set search_path = ''
as $$
  with r as (
    select rs.daily_cap_minutes as dcap, rs.weekly_cap_minutes as wcap, coalesce(rs.lessons_count, false) as lc,
           coalesce(rs.instructor_multiplier, 1) as mult, rs.instructor_max_minutes as lmax
      from (select 1) one left join public.state_rule_sets rs on rs.id = p_rule_id
  ),
  src as (
    select dr.* from public.drives dr
     where dr.student_id = p_student_id and dr.status = any (p_statuses)
       and (p_from is null or dr.local_date >= p_from) and (p_to is null or dr.local_date <= p_to)
  ),
  d as (
    select s.local_date, sum(s.duration_minutes)::int as m, sum(s.night_minutes)::int as n,
           sum(s.weather_minutes)::int as w, sum(s.distance_miles) as mi
      from src s where s.kind = 'practice' group by s.local_date
  ),
  dc as (
    select d.*, date_trunc('week', d.local_date)::date as wk, least(d.m, coalesce(r.dcap, d.m)) as c
      from d, r
  ),
  dc2 as (select dc.*, least(dc.n, dc.c) as nc, least(dc.w, dc.c) as wc, least(dc.n + dc.w, dc.c) as cc from dc),
  wk as (
    select wk, sum(c)::int as c, sum(nc)::int as nc, sum(wc)::int as wc, sum(cc)::int as cc from dc2 group by wk
  ),
  wk2 as (
    select wk.*, least(wk.c, coalesce(r.wcap, wk.c)) as wcred, wk.c > coalesce(r.wcap, wk.c) as capped from wk, r
  ),
  pr as (
    select coalesce(sum(wcred), 0)::int as credit,
           coalesce(sum(least(nc, wcred)), 0)::int as night,
           coalesce(sum(least(wc, wcred)), 0)::int as weather,
           coalesce(sum(least(cc, wcred)), 0)::int as chall,
           count(*) filter (where capped)::int as capped_weeks
      from wk2
  ),
  le as (
    select coalesce(sum(s.duration_minutes), 0)::int as m, coalesce(sum(s.night_minutes), 0)::int as n
      from src s where s.kind = 'lesson'
  ),
  lc as (
    select le.m as raw,
           case when r.lc then least(le.m, coalesce(r.lmax, le.m)) else 0 end as counted,
           r.mult, le.n
      from le, r
  )
  select pr.credit + floor(lc.counted * lc.mult)::int,
         pr.night + least(lc.n, lc.counted),
         pr.weather,
         pr.chall + least(lc.n, lc.counted),
         coalesce((select sum(m) from d), 0)::int,
         pr.credit,
         lc.raw, lc.counted, floor(lc.counted * lc.mult)::int,
         (select count(*) from dc where dc.m > dc.c)::int,
         pr.capped_weeks,
         round(coalesce((select sum(mi) from d), 0), 1)
    from pr, lc;
$$;
revoke all on function private.rule_credit(uuid, uuid, text[], date, date) from public, anon, authenticated;

-- First local date on which a cumulative target was reached (daily cap applied; weekly
-- caps ignored here: no state with stages has one). Used to assume a missing milestone date.
create or replace function private.first_date_reaching(p_student_id uuid, p_rule_id uuid, p_total int, p_night int)
returns date
language sql stable security definer set search_path = ''
as $$
  with r as (select rs.daily_cap_minutes as dcap from (select 1) one left join public.state_rule_sets rs on rs.id = p_rule_id),
  d as (
    select dr.local_date, sum(dr.duration_minutes)::int as m, sum(dr.night_minutes)::int as n
      from public.drives dr
     where dr.student_id = p_student_id and dr.status = 'signed' and dr.kind = 'practice'
     group by dr.local_date
  ),
  c as (
    select d.local_date, least(d.m, coalesce(r.dcap, d.m)) as cr, least(d.n, least(d.m, coalesce(r.dcap, d.m))) as nc from d, r
  ),
  run as (
    select local_date, sum(cr) over w as ct, sum(nc) over w as cn
      from c window w as (order by local_date rows between unbounded preceding and current row)
  )
  select min(local_date) from run
   where ct >= coalesce(p_total, 0) and cn >= coalesce(p_night, 0);
$$;
revoke all on function private.first_date_reaching(uuid, uuid, int, int) from public, anon, authenticated;

-- One requirement object (docs section 6).
create or replace function private.req_json(p_key text, p_label text, p_required int, p_credited int, p_with_pending int)
returns jsonb
language sql immutable set search_path = ''
as $$
  select jsonb_build_object(
    'key', p_key, 'label', p_label, 'required_minutes', p_required,
    'credited_minutes', p_credited, 'pending_minutes', greatest(p_with_pending - p_credited, 0),
    'remaining_minutes', greatest(p_required - p_credited, 0), 'met', p_credited >= p_required);
$$;

create or replace function private.still_needed_text(p_req jsonb, p_prefix text default '')
returns text
language sql immutable set search_path = ''
as $$
  select p_prefix || private.fmt_minutes((p_req ->> 'remaining_minutes')::int) || ' more ' ||
         case p_req ->> 'key' when 'total' then 'in total' when 'night' then 'at night'
                              when 'weather' then 'in inclement weather'
                              else 'in challenging conditions (night or bad weather)' end;
$$;

-- Requirement list for a target set (base rule, alternative, or one stage).
create or replace function private.requirements_for(
  p_student_id uuid, p_rule public.state_rule_sets, p_total int, p_night int, p_weather int,
  p_from date default null
)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  s record; p record; out jsonb := '[]'::jsonb;
begin
  select * into s from private.rule_credit(p_student_id, p_rule.id, array['signed'], p_from);
  select * into p from private.rule_credit(p_student_id, p_rule.id, array['signed', 'pending'], p_from);
  if p_total is not null then
    out := out || private.req_json('total', 'Total supervised driving', p_total, s.total, p.total);
  end if;
  if p_night is not null then
    out := out || private.req_json('night', 'At night', p_night, s.night, p.night);
  end if;
  if p_weather is not null then
    if p_rule.weather_counts_night then
      out := out || private.req_json('challenging', 'In challenging conditions (night or bad weather)', p_weather, s.challenging, p.challenging);
    else
      out := out || private.req_json('weather', 'In inclement weather', p_weather, s.weather, p.weather);
    end if;
  end if;
  return out;
end;
$$;
revoke all on function private.requirements_for(uuid, public.state_rule_sets, int, int, int, date) from public, anon, authenticated;

-- Progress without the access check (used by the summary, the roster cache and exports).
create or replace function private.rule_progress(p_student_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  st public.students;
  rs public.state_rule_sets;
  alt jsonb; sg jsonb; prev jsonb;
  c record;
  reqs jsonb := '[]'::jsonb; stages jsonb := '[]'::jsonb; needed text[] := '{}';
  t_total int; t_night int; t_weather int;
  v_from date; v_assumed boolean; v_milestone date; v_met boolean; v_all boolean; sreqs jsonb;
  v_unverified int := 0; r jsonb;
begin
  select * into st from public.students where id = p_student_id;
  if not found then return null; end if;
  select * into rs from public.state_rule_sets where id = private.rule_for_student(p_student_id);
  if rs.id is null then
    return jsonb_build_object('student_id', p_student_id, 'rule', null, 'alternative', null, 'requirements', '[]'::jsonb,
      'stages', '[]'::jsonb, 'all_met', null,
      'still_needed', jsonb_build_array(format('No rule on file for %s for a permit issued %s', st.state_code,
                                               coalesce(st.permit_on::text, 'today'))));
  end if;

  select * into c from private.rule_credit(p_student_id, rs.id, array['signed']);

  if st.rule_alternative is not null then
    select a into alt from jsonb_array_elements(rs.alternatives) a where a ->> 'key' = st.rule_alternative;
  end if;
  t_total := coalesce((alt ->> 'total_minutes')::int, rs.total_minutes);
  t_night := coalesce((alt ->> 'night_minutes')::int, rs.night_minutes);
  t_weather := coalesce((alt ->> 'weather_minutes')::int, rs.weather_minutes);

  if rs.requirement_kind = 'none' then
    needed := array[format('%s has no supervised-hours requirement', rs.jurisdiction_name)];
    v_all := true;
  elsif rs.requirement_kind = 'unconfirmed' or (rs.total_minutes is null and rs.status = 'unconfirmed') then
    needed := array[format('%s''s hours requirement is unconfirmed; check with the state before relying on it', rs.jurisdiction_name)];
    v_all := null;
  elsif coalesce((alt ->> 'replaces_hours')::boolean, false) then
    needed := array[format('No hours target on this path: %s', alt ->> 'label')];
    v_all := null;
  else
    reqs := private.requirements_for(p_student_id, rs, t_total, t_night, t_weather);
    for r in select * from jsonb_array_elements(reqs) loop
      if not (r ->> 'met')::boolean then needed := needed || private.still_needed_text(r); end if;
    end loop;
    v_all := not exists (select 1 from jsonb_array_elements(reqs) x where not (x ->> 'met')::boolean);

    -- Stages
    prev := null;
    for sg in select * from jsonb_array_elements(rs.stages) loop
      v_from := null; v_assumed := false; v_milestone := null;
      if sg ->> 'counting' = 'since_previous_milestone' then
        select m.reached_on into v_milestone from public.student_rule_milestones m
         where m.student_id = p_student_id and m.milestone_key = sg ->> 'milestone';
        if v_milestone is null and prev is not null then
          v_milestone := private.first_date_reaching(p_student_id, rs.id,
                           (prev ->> 'total_minutes')::int, (prev ->> 'night_minutes')::int) + 1;  -- the day after
          v_assumed := v_milestone is not null;
        end if;
        v_from := v_milestone;
      end if;
      if sg ->> 'counting' = 'since_previous_milestone' and v_from is null then
        -- Previous stage not reached yet: nothing counts toward this one.
        select coalesce(jsonb_agg(x || jsonb_build_object('credited_minutes', 0, 'pending_minutes', 0,
                        'remaining_minutes', (x ->> 'required_minutes')::int, 'met', false)), '[]'::jsonb)
          into sreqs
          from jsonb_array_elements(private.requirements_for(p_student_id, rs, (sg ->> 'total_minutes')::int,
                 (sg ->> 'night_minutes')::int, (sg ->> 'weather_minutes')::int)) x;
      else
        sreqs := private.requirements_for(p_student_id, rs, (sg ->> 'total_minutes')::int,
                   (sg ->> 'night_minutes')::int, (sg ->> 'weather_minutes')::int, v_from);
      end if;
      v_met := not exists (select 1 from jsonb_array_elements(sreqs) x where not (x ->> 'met')::boolean);
      if not v_met then
        for r in select * from jsonb_array_elements(sreqs) loop
          if not (r ->> 'met')::boolean then
            needed := needed || private.still_needed_text(r, (sg ->> 'label') || ': ');
          end if;
        end loop;
        v_all := false;
      end if;
      stages := stages || jsonb_build_object('key', sg ->> 'key', 'label', sg ->> 'label', 'counting', sg ->> 'counting',
                  'milestone', sg -> 'milestone', 'window_from', v_from, 'milestone_assumed', v_assumed,
                  'met', v_met, 'requirements', sreqs);
      prev := sg;
    end loop;
  end if;

  -- Signed non-instructor drives whose supervisor's age / license date is unknown
  if rs.supervisor_min_age is not null or rs.supervisor_min_years_licensed is not null then
    select count(*) into v_unverified
      from public.drive_signoffs so
      left join public.supervisors sp on sp.id = so.supervisor_id
     where so.student_id = p_student_id and so.method <> 'instructor'
       and ((rs.supervisor_min_age is not null and sp.birth_date is null
             and not (rs.supervisor_parent_exempt and sp.relationship in ('parent', 'guardian')))
         or (rs.supervisor_min_years_licensed is not null and sp.licensed_since is null));
  end if;

  return jsonb_build_object(
    'student_id', p_student_id,
    'rule', jsonb_build_object('id', rs.id, 'state_code', rs.state_code, 'jurisdiction_name', rs.jurisdiction_name,
              'version', rs.version, 'label', rs.label, 'status', rs.status, 'requirement_kind', rs.requirement_kind,
              'effective_from', rs.effective_from, 'effective_to', rs.effective_to,
              'selected_by', case when st.rule_set_id is not null then 'override'
                                  when st.permit_on is not null then 'permit_date' else 'today' end,
              'permit_on', st.permit_on, 'log_unit', rs.log_unit, 'night_rule', rs.night_rule,
              'field_status', rs.field_status),
    'alternative', case when alt is null then null else jsonb_build_object('key', alt ->> 'key', 'label', alt ->> 'label',
                     'replaces_hours', coalesce((alt ->> 'replaces_hours')::boolean, false)) end,
    'caps', jsonb_build_object('daily_minutes', rs.daily_cap_minutes, 'weekly_minutes', rs.weekly_cap_minutes,
              'capped_days', c.capped_days, 'capped_weeks', c.capped_weeks),
    'instructor', jsonb_build_object('counts', rs.lessons_count, 'multiplier', rs.instructor_multiplier,
              'max_minutes', rs.instructor_max_minutes, 'raw_minutes', c.lesson_raw,
              'counted_minutes', c.lesson_counted, 'credited_minutes', c.lesson_credit),
    'requirements', reqs,
    'stages', stages,
    'all_met', v_all,
    'still_needed', to_jsonb(needed),
    'supervisor', jsonb_build_object('min_age', rs.supervisor_min_age, 'min_years_licensed', rs.supervisor_min_years_licensed,
              'parent_exempt', rs.supervisor_parent_exempt, 'rule', rs.supervisor_rule, 'unverified_drives', v_unverified),
    'paperwork', jsonb_build_object('form_type', rs.form_type, 'form_name', rs.form_name, 'form_number', rs.form_number,
              'form_pdf_url', rs.form_pdf_url, 'notarization', rs.notarization, 'notarization_note', rs.notarization_note,
              'digital_log', rs.digital_log, 'digital_log_apps', to_jsonb(rs.digital_log_apps))
  );
end;
$$;
revoke all on function private.rule_progress(uuid) from public, anon, authenticated;

create or replace function public.student_rule_progress(p_student_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not private.can_view_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  return private.rule_progress(p_student_id);
end;
$$;
revoke all on function public.student_rule_progress(uuid) from public, anon;
grant execute on function public.student_rule_progress(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Older flat RPCs, now on the same math
-- ---------------------------------------------------------------------------
create or replace function public.student_hours_summary(p_student_id uuid)
returns table (
  student_id uuid, rule_set_id uuid, state_code text, rule_label text, rule_verified boolean, form_code text,
  required_minutes int, required_night_minutes int, daily_cap_minutes int,
  credited_minutes int, night_credited_minutes int, day_credited_minutes int, raw_minutes int,
  pending_extra_minutes int, pending_drives int, signed_miles numeric, lesson_minutes int,
  school_goal_minutes int, remaining_minutes int, remaining_night_minutes int, requirement_met boolean
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  rs public.state_rule_sets; s public.students; c record; p record; pend int; prog jsonb;
  t_total int; t_night int; alt jsonb;
begin
  if not private.can_view_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  select * into s from public.students where id = p_student_id;
  select * into rs from public.state_rule_sets where id = private.rule_for_student(p_student_id);
  select * into c from private.rule_credit(p_student_id, rs.id, array['signed']);
  select * into p from private.rule_credit(p_student_id, rs.id, array['signed', 'pending']);
  select count(*) into pend from public.drives where drives.student_id = p_student_id and status = 'pending';
  prog := private.rule_progress(p_student_id);
  if s.rule_alternative is not null then
    select a into alt from jsonb_array_elements(rs.alternatives) a where a ->> 'key' = s.rule_alternative;
  end if;
  t_total := coalesce((alt ->> 'total_minutes')::int, rs.total_minutes);
  t_night := coalesce((alt ->> 'night_minutes')::int, rs.night_minutes);

  return query select
    p_student_id, rs.id, s.state_code, rs.label, coalesce(rs.verified, false), rs.form_code,
    t_total, t_night, rs.daily_cap_minutes,
    c.total, c.night, c.total - c.night,
    c.practice_raw + case when rs.lessons_count then c.lesson_raw else 0 end,
    p.total - c.total, pend, c.miles, c.lesson_raw,
    case when s.school_id is null then null else (s.hour_goal * 60)::int end,
    greatest(coalesce(t_total, 0) - c.total, 0),
    greatest(coalesce(t_night, 0) - c.night, 0),
    coalesce((prog ->> 'all_met')::boolean, false);
end;
$$;

drop function if exists public.student_hours_by_day(uuid, date, date, boolean);
create function public.student_hours_by_day(
  p_student_id uuid, p_from date default null, p_to date default null, p_include_pending boolean default false
)
returns table (
  local_date date, drives int, raw_minutes int, raw_night_minutes int,
  credited_minutes int, night_credited_minutes int, miles numeric, capped boolean,
  raw_weather_minutes int, weather_credited_minutes int, week_start date
)
language plpgsql stable security definer set search_path = ''
as $$
declare v_cap int;
begin
  if not private.can_view_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  select rs.daily_cap_minutes into v_cap from public.state_rule_sets rs where rs.id = private.rule_for_student(p_student_id);
  -- Practice drives per local day with the daily cap (weekly caps are shown in student_rule_progress.caps).
  return query
    with d as (
      select dr.local_date as ld, count(*)::int as n_drives, sum(dr.duration_minutes)::int as m,
             sum(dr.night_minutes)::int as n, sum(dr.weather_minutes)::int as w, sum(dr.distance_miles) as mi
        from public.drives dr
       where dr.student_id = p_student_id and dr.kind = 'practice'
         and dr.status = any (case when p_include_pending then array['signed', 'pending'] else array['signed'] end)
         and (p_from is null or dr.local_date >= p_from) and (p_to is null or dr.local_date <= p_to)
       group by dr.local_date
    )
    select d.ld, d.n_drives, d.m, d.n, least(d.m, coalesce(v_cap, d.m)),
           least(d.n, least(d.m, coalesce(v_cap, d.m))), round(d.mi, 1), d.m > coalesce(v_cap, d.m),
           d.w, least(d.w, least(d.m, coalesce(v_cap, d.m))), date_trunc('week', d.ld)::date
      from d order by d.ld;
end;
$$;
revoke all on function public.student_hours_by_day(uuid, date, date, boolean) from public, anon;
grant execute on function public.student_hours_by_day(uuid, date, date, boolean) to authenticated, service_role;

create or replace function private.refresh_student_hours(p_student_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare c record;
begin
  select * into c from private.rule_credit(p_student_id, private.rule_for_student(p_student_id), array['signed']);
  update public.students
     set practice_hours = round(c.total / 60.0, 1),
         night_hours = round(c.night / 60.0, 1),
         school_hours = round(c.lesson_raw / 60.0, 1)
   where id = p_student_id
     and (practice_hours, night_hours, school_hours)
         is distinct from (round(c.total / 60.0, 1), round(c.night / 60.0, 1), round(c.lesson_raw / 60.0, 1));
end;
$$;
revoke all on function private.refresh_student_hours(uuid) from public, anon, authenticated;

-- Changing state, permit date, override or alternative changes the credited numbers.
create or replace function private.students_rule_refresh()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  -- Only students with signed drives: never overwrite hours a school typed in by hand
  -- on the live dashboard for a student who doesn't log in the app.
  if exists (select 1 from public.drives d where d.student_id = new.id and d.status = 'signed') then
    perform private.refresh_student_hours(new.id);
  end if;
  return null;
end;
$$;
revoke all on function private.students_rule_refresh() from public, anon, authenticated;
drop trigger if exists students_rule_refresh on public.students;
create trigger students_rule_refresh after update of state_code, permit_on, rule_set_id, rule_alternative on public.students
  for each row
  when ((old.state_code, old.permit_on, old.rule_set_id, old.rule_alternative)
        is distinct from (new.state_code, new.permit_on, new.rule_set_id, new.rule_alternative))
  execute function private.students_rule_refresh();

-- ---------------------------------------------------------------------------
-- 6. Supervisor age / experience at sign-off
-- ---------------------------------------------------------------------------
create or replace function private.signoff_supervisor_check()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare rs public.state_rule_sets; sp public.supervisors; v_on date := coalesce(new.signed_at, now())::date;
begin
  if new.method = 'instructor' or new.supervisor_id is null then return new; end if;
  select * into sp from public.supervisors where id = new.supervisor_id;
  select * into rs from public.state_rule_sets where id = private.rule_for_student(new.student_id);
  if rs.id is null then return new; end if;
  if rs.supervisor_min_age is not null and sp.birth_date is not null
     and not (rs.supervisor_parent_exempt and sp.relationship in ('parent', 'guardian'))
     and sp.birth_date + make_interval(years => rs.supervisor_min_age) > v_on then
    raise exception using errcode = '22023', message = format('In %s the supervisor must be at least %s%s',
      rs.state_code, rs.supervisor_min_age,
      case when rs.supervisor_parent_exempt then ' (licensed parents and guardians excepted)' else '' end);
  end if;
  if rs.supervisor_min_years_licensed is not null and sp.licensed_since is not null
     and sp.licensed_since + make_interval(months => (rs.supervisor_min_years_licensed * 12)::int) > v_on then
    raise exception 'In % the supervisor must have been licensed at least % year(s)', rs.state_code,
      rs.supervisor_min_years_licensed::float8 using errcode = '22023';
  end if;
  return new;
end;
$$;
revoke all on function private.signoff_supervisor_check() from public, anon, authenticated;
drop trigger if exists drive_signoffs_supervisor_check on public.drive_signoffs;
create trigger drive_signoffs_supervisor_check before insert on public.drive_signoffs
  for each row execute function private.signoff_supervisor_check();

-- ---------------------------------------------------------------------------
-- 7. Write RPCs
-- ---------------------------------------------------------------------------
create or replace function public.set_rule_alternative(p_student_id uuid, p_key text)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare rs public.state_rule_sets;
begin
  if not private.can_act_for_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  if p_key is not null then
    select * into rs from public.state_rule_sets where id = private.rule_for_student(p_student_id);
    if rs.id is null or not exists (select 1 from jsonb_array_elements(rs.alternatives) a where a ->> 'key' = p_key) then
      raise exception 'That option isn''t available for this state' using errcode = '22023';
    end if;
  end if;
  update public.students set rule_alternative = p_key where id = p_student_id;
  return private.rule_progress(p_student_id);
end;
$$;
revoke all on function public.set_rule_alternative(uuid, text) from public, anon;
grant execute on function public.set_rule_alternative(uuid, text) to authenticated;

create or replace function public.set_rule_milestone(p_student_id uuid, p_key text, p_reached_on date)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare rs public.state_rule_sets;
begin
  if not private.can_act_for_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  select * into rs from public.state_rule_sets where id = private.rule_for_student(p_student_id);
  if rs.id is null or not exists (select 1 from jsonb_array_elements(rs.stages) sg
                                   where sg ->> 'milestone' = p_key or sg ->> 'key' = p_key) then
    raise exception 'That stage isn''t part of this state''s rules' using errcode = '22023';
  end if;
  if p_reached_on is null then
    delete from public.student_rule_milestones where student_id = p_student_id and milestone_key = p_key;
  else
    if p_reached_on > current_date + 1 then
      raise exception 'That date is in the future' using errcode = '22023';
    end if;
    insert into public.student_rule_milestones (student_id, milestone_key, reached_on)
    values (p_student_id, p_key, p_reached_on)
    on conflict (student_id, milestone_key) do update set reached_on = excluded.reached_on, set_by = auth.uid();
  end if;
  return private.rule_progress(p_student_id);
end;
$$;
revoke all on function public.set_rule_milestone(uuid, text, date) from public, anon;
grant execute on function public.set_rule_milestone(uuid, text, date) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Resources API (docs section 7)
-- ---------------------------------------------------------------------------
create or replace function private.rule_resources(p_rule_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  rs public.state_rule_sets; v_summary text; v_how text; steps text[] := '{}'; links jsonb := '[]'::jsonb;
  v_hours text; i int := 0; checklist jsonb := '[]'::jsonb; k text; t text; keys text[] := '{}';
begin
  select * into rs from public.state_rule_sets where id = p_rule_id;
  if not found then return null; end if;

  -- Summary
  if rs.requirement_kind = 'none' then
    v_summary := format('%s has no supervised-driving hours requirement.', rs.jurisdiction_name);
  elsif rs.total_minutes is null then
    v_summary := format('%s''s hours requirement is unconfirmed.', rs.jurisdiction_name);
  else
    v_hours := private.fmt_minutes(rs.total_minutes) || ' of supervised driving'
      || coalesce(', including ' || private.fmt_minutes(rs.night_minutes) || ' at night', '')
      || case when rs.weather_minutes is null then ''
              when rs.weather_counts_night then ' and ' || private.fmt_minutes(rs.weather_minutes) || ' in challenging conditions (night or bad weather)'
              else ' and ' || private.fmt_minutes(rs.weather_minutes) || ' in inclement weather' end;
    v_summary := v_hours || '.'
      || coalesce(' At most ' || private.fmt_minutes(rs.daily_cap_minutes) || ' per day count.', '')
      || coalesce(' At most ' || private.fmt_minutes(rs.weekly_cap_minutes) || ' per week count.', '')
      || case when rs.log_unit = 'minutes' then format(' Logged in minutes (%s / %s).',
                to_char(rs.total_minutes, 'FM999,999'), coalesce(to_char(rs.night_minutes, 'FM999,999'), '-')) else '' end
      || case when jsonb_array_length(rs.stages) > 0 then ' Done in stages.' else '' end
      || case when jsonb_array_length(rs.alternatives) > 0 then ' Other totals apply in some cases.' else '' end;
  end if;

  -- How LicenseLogger's own log can be used (app guidance, not legal advice)
  v_how := case
    when rs.requirement_kind = 'none' then 'none'
    when rs.requirement_kind = 'unconfirmed' or rs.status = 'unconfirmed' then 'unconfirmed'
    when rs.digital_log = 'listed_apps' then 'official_form_only'
    when rs.digital_log = 'accepted' or rs.requirement_kind = 'log_any_format' then 'submit_printout'
    when rs.requirement_kind = 'certification' or rs.form_type = 'certification' then 'records_only'
    when rs.form_type = 'full_log' then 'copy_to_official_form'
    else 'records_only' end;

  -- Checklist
  if rs.requirement_kind not in ('none', 'unconfirmed') and rs.total_minutes is not null then
    keys := keys || 'log_hours'::text; steps := steps || ('Log ' || v_hours || '. Every drive needs an eligible supervisor.');
  end if;
  if rs.daily_cap_minutes is not null or rs.weekly_cap_minutes is not null then
    keys := keys || 'caps'::text; steps := steps || ('Spread drives out: only '
      || concat_ws(' and ', private.fmt_minutes(rs.daily_cap_minutes) || ' per day', private.fmt_minutes(rs.weekly_cap_minutes) || ' per week')
      || ' count.');
  end if;
  if rs.weather_minutes is not null then
    keys := keys || 'weather'::text; steps := steps || 'Tag drives in rain, snow, ice or fog with their bad-weather minutes.'::text;
  end if;
  if jsonb_array_length(rs.stages) > 0 then
    keys := keys || 'stages'::text; steps := steps || ('Record each stage date in the app: '
      || (select string_agg(sg ->> 'label', '; ') from jsonb_array_elements(rs.stages) sg) || '.');
  end if;
  if jsonb_array_length(rs.alternatives) > 0 then
    keys := keys || 'alternatives'::text; steps := steps || ('If one applies, choose it in the app: '
      || (select string_agg(a ->> 'label', '; ') from jsonb_array_elements(rs.alternatives) a) || '.');
  end if;
  if rs.lessons_count then
    keys := keys || 'instructor'::text; steps := steps || ('Instructor lessons count'
      || case when rs.instructor_multiplier <> 1 then ' ' || rs.instructor_multiplier::float8 || 'x' else '' end
      || coalesce(' (up to ' || private.fmt_minutes(rs.instructor_max_minutes) || ' of lessons)', '') || '.');
  end if;
  if rs.supervisor_rule <> '' then
    keys := keys || 'supervisor'::text; steps := steps || ('Supervisor: ' || rs.supervisor_rule || '. Add their birth date and license date in the app.');
  end if;
  if v_how = 'copy_to_official_form' then
    keys := keys || 'official_form'::text; steps := steps || format('Copy your entries onto the state form "%s"%s, then sign it.',
      rs.form_name, coalesce(' (form ' || nullif(rs.form_number, '') || ')', ''));
  elsif v_how = 'official_form_only' then
    keys := keys || 'official_form'::text; steps := steps || format('Use only the state form "%s" or the %s app. Note: %s.',
      coalesce(nullif(rs.form_name, ''), 'official log'), array_to_string(rs.digital_log_apps, ' / '), rs.digital_log_note);
  elsif v_how = 'submit_printout' then
    keys := keys || 'official_form'::text; steps := steps || ('Print or show your LicenseLogger log. Note: ' || rs.digital_log_note || '.');
  elsif v_how = 'records_only' and rs.form_name <> '' then
    keys := keys || 'official_form'::text; steps := steps || format('Sign the state form "%s"%s; keep the LicenseLogger log as backup.',
      rs.form_name, coalesce(' (form ' || nullif(rs.form_number, '') || ')', ''));
  end if;
  if rs.notarization = 'required' then
    keys := keys || 'notary'::text; steps := steps || ('Get the form notarized' || coalesce(' (' || nullif(rs.notarization_note, '') || ')', '') || '.');
  elsif rs.notarization = 'if_signer_absent' then
    keys := keys || 'notary'::text; steps := steps || ('If the signing parent can''t come in person: ' || rs.notarization_note || '.');
  end if;
  if rs.requirement_kind = 'unconfirmed' then
    keys := keys || 'confirm'::text; steps := steps || 'Check the requirement with the state licensing office before your test.'::text;
  end if;
  if rs.pending_change_on is not null then
    keys := keys || 'pending_change'::text; steps := steps || ('Heads up, from ' || rs.pending_change_on || ': ' || rs.pending_change_note);
  end if;
  for i in 1 .. coalesce(array_length(steps, 1), 0) loop
    checklist := checklist || jsonb_build_object('step', i, 'key', keys[i], 'text', steps[i]);
  end loop;

  -- Links (only those that exist)
  foreach k in array array['form_pdf', 'alt_form_pdf', 'handbook', 'parent_guide', 'gdl_page', 'source_page'] loop
    t := case k when 'form_pdf' then rs.form_pdf_url when 'alt_form_pdf' then rs.alt_form_pdf_url
                when 'handbook' then rs.handbook_url when 'parent_guide' then rs.parent_guide_url
                when 'gdl_page' then rs.gdl_page_url else rs.source_url end;
    if coalesce(t, '') <> '' and not (k = 'source_page' and t = rs.gdl_page_url) then
      links := links || jsonb_build_object('kind', k, 'url', t, 'status', rs.link_status ->> k,
        'label', case k when 'form_pdf' then coalesce(nullif(rs.form_name, ''), 'Official form')
                        when 'alt_form_pdf' then coalesce(nullif(rs.alt_form_name, ''), 'Other official form')
                        when 'handbook' then 'Driver handbook' when 'parent_guide' then 'Parent guide'
                        when 'gdl_page' then 'Teen / GDL licensing page' else 'Source page' end);
    end if;
  end loop;

  return jsonb_build_object(
    'state_code', rs.state_code, 'jurisdiction_name', rs.jurisdiction_name, 'rule_set_id', rs.id,
    'version', rs.version, 'status', rs.status, 'effective_from', rs.effective_from, 'effective_to', rs.effective_to,
    'requirement_kind', rs.requirement_kind,
    'summary', v_summary,
    'requirements', jsonb_build_object('total_minutes', rs.total_minutes, 'night_minutes', rs.night_minutes,
        'night_rule', rs.night_rule, 'night_definition', rs.night_definition,
        'weather_minutes', rs.weather_minutes, 'weather_counts_night', rs.weather_counts_night,
        'daily_cap_minutes', rs.daily_cap_minutes, 'weekly_cap_minutes', rs.weekly_cap_minutes, 'log_unit', rs.log_unit,
        'lessons_count', rs.lessons_count, 'instructor_multiplier', rs.instructor_multiplier,
        'instructor_max_minutes', rs.instructor_max_minutes, 'stages', rs.stages, 'alternatives', rs.alternatives),
    'supervisor', jsonb_build_object('min_age', rs.supervisor_min_age, 'min_years_licensed', rs.supervisor_min_years_licensed,
        'parent_exempt', rs.supervisor_parent_exempt, 'rule', rs.supervisor_rule),
    'form', jsonb_build_object('type', rs.form_type, 'type_detail', rs.form_type_detail, 'name', rs.form_name,
        'number', rs.form_number, 'pdf_url', rs.form_pdf_url, 'pdf_status', rs.form_pdf_status,
        'alt_name', rs.alt_form_name, 'alt_pdf_url', rs.alt_form_pdf_url,
        'notarization', rs.notarization, 'notarization_note', rs.notarization_note,
        'digital_log', rs.digital_log, 'digital_log_apps', to_jsonb(rs.digital_log_apps), 'digital_log_note', rs.digital_log_note),
    'links', links,
    'checklist', checklist,
    'how_to_use_licenselogger_log', v_how,
    'other_rules', rs.other_rules, 'notes', rs.notes, 'field_status', rs.field_status, 'last_checked', rs.last_checked,
    'pending_change', case when rs.pending_change_on is null then null
                           else jsonb_build_object('on', rs.pending_change_on, 'note', rs.pending_change_note) end
  );
end;
$$;
revoke all on function private.rule_resources(uuid) from public, anon, authenticated;

create or replace function public.state_resources(p_state_code text, p_permit_on date default null)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v uuid;
begin
  if (select auth.uid()) is null and current_user not in ('postgres', 'service_role') then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  v := private.rule_for_state(p_state_code, p_permit_on);
  if v is null then
    raise exception 'No rule on file for % for a permit issued %', upper(p_state_code), coalesce(p_permit_on::text, 'today')
      using errcode = 'P0002';
  end if;
  return private.rule_resources(v);
end;
$$;
revoke all on function public.state_resources(text, date) from public, anon;
grant execute on function public.state_resources(text, date) to authenticated, service_role;

create or replace function public.my_rule_resources(p_student_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v uuid;
begin
  if not private.can_view_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  v := private.rule_for_student(p_student_id);
  return coalesce(private.rule_resources(v), '{}'::jsonb) || jsonb_build_object('progress', private.rule_progress(p_student_id));
end;
$$;
revoke all on function public.my_rule_resources(uuid) from public, anon;
grant execute on function public.my_rule_resources(uuid) to authenticated, service_role;

-- Helpers called only inside definer functions
revoke all on function private.fmt_minutes(int) from public, anon;
revoke all on function private.req_json(text, text, int, int, int) from public, anon, authenticated;
revoke all on function private.still_needed_text(jsonb, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. list_drives also returns weather_minutes (new last column; old columns unchanged)
-- ---------------------------------------------------------------------------
drop function if exists public.list_drives(uuid, timestamptz, uuid, int);
create function public.list_drives(
  p_student_id uuid,
  p_before_started_at timestamptz default null,
  p_before_id uuid default null,
  p_limit int default 50
)
returns table (
  id uuid, student_id uuid, supervisor_id uuid, supervisor_name text, kind text, source text, status text,
  started_at timestamptz, ended_at timestamptz, tz text, local_date date, duration_minutes int, night_minutes int,
  distance_miles numeric, start_label text, end_label text, conditions text[], skills text[], notes text,
  has_route boolean, locked_at timestamptz, weather_minutes int
)
language sql
stable
security invoker
set search_path = ''
as $$
  select d.id, d.student_id, d.supervisor_id, sp.name, d.kind, d.source, d.status,
         d.started_at, d.ended_at, d.tz, d.local_date, d.duration_minutes, d.night_minutes,
         d.distance_miles, d.start_label, d.end_label, d.conditions, d.skills, d.notes,
         d.route_polyline is not null, d.locked_at, d.weather_minutes
    from public.drives d
    left join public.supervisors sp on sp.id = d.supervisor_id
   where d.student_id = p_student_id
     and (p_before_started_at is null
          or (d.started_at, d.id) < (p_before_started_at, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
   order by d.started_at desc, d.id desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
$$;
revoke all on function public.list_drives(uuid, timestamptz, uuid, int) from public, anon;
grant execute on function public.list_drives(uuid, timestamptz, uuid, int) to authenticated, service_role;
