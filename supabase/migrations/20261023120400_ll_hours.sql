-- LicenseLogger 009: hours math (day / night / daily-cap aware) and paged lists.
--
-- The math, in plain words:
--   * Only practice drives count (instructor lessons too, if the state rule says so).
--   * Drives are grouped by the LOCAL calendar day they started on.
--   * Each day counts at most the state's daily cap (Texas: 120 minutes).
--   * Night minutes that day count up to that day's credited total.
--   * "Signed" totals use signed drives only; "pending" shows what is waiting for a signature.

create or replace function private.day_totals(p_student_id uuid, p_statuses text[])
returns table (
  local_date date,
  drives int,
  raw_minutes int,
  raw_night_minutes int,
  credited_minutes int,
  night_credited_minutes int,
  miles numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with r as (
    select rs.daily_cap_minutes as cap, coalesce(rs.lessons_count, false) as lessons_count
      from (select private.rule_for_student(p_student_id) as id) x
      left join public.state_rule_sets rs on rs.id = x.id
  ),
  d as (
    select dr.local_date,
           count(*)::int as drives,
           sum(dr.duration_minutes)::int as mins,
           sum(dr.night_minutes)::int as night,
           sum(dr.distance_miles) as miles
      from public.drives dr, r
     where dr.student_id = p_student_id
       and dr.status = any (p_statuses)
       and (dr.kind = 'practice' or (dr.kind = 'lesson' and r.lessons_count))
     group by dr.local_date
  )
  select d.local_date, d.drives, d.mins, d.night,
         least(d.mins, coalesce(r.cap, d.mins)),
         least(d.night, least(d.mins, coalesce(r.cap, d.mins))),
         d.miles
    from d, r
   order by d.local_date;
$$;
revoke all on function private.day_totals(uuid, text[]) from public, anon, authenticated;

create or replace function public.student_hours_summary(p_student_id uuid)
returns table (
  student_id uuid,
  rule_set_id uuid,
  state_code text,
  rule_label text,
  rule_verified boolean,
  form_code text,
  required_minutes int,
  required_night_minutes int,
  daily_cap_minutes int,
  credited_minutes int,
  night_credited_minutes int,
  day_credited_minutes int,
  raw_minutes int,
  pending_extra_minutes int,
  pending_drives int,
  signed_miles numeric,
  lesson_minutes int,
  school_goal_minutes int,
  remaining_minutes int,
  remaining_night_minutes int,
  requirement_met boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  rs public.state_rule_sets;
  s public.students;
  c int; cn int; rawm int; miles numeric; withp int; pend int; lessons int;
begin
  if not private.can_view_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  select * into s from public.students where id = p_student_id;
  select * into rs from public.state_rule_sets where id = private.rule_for_student(p_student_id);

  select coalesce(sum(t.credited_minutes), 0), coalesce(sum(t.night_credited_minutes), 0),
         coalesce(sum(t.raw_minutes), 0), coalesce(sum(t.miles), 0)
    into c, cn, rawm, miles
    from private.day_totals(p_student_id, array['signed']) t;

  select coalesce(sum(t.credited_minutes), 0) into withp
    from private.day_totals(p_student_id, array['signed', 'pending']) t;

  select count(*) into pend from public.drives where drives.student_id = p_student_id and status = 'pending';
  select coalesce(sum(duration_minutes), 0) into lessons
    from public.drives where drives.student_id = p_student_id and kind = 'lesson' and status = 'signed';

  return query select
    p_student_id, rs.id, s.state_code, rs.label, coalesce(rs.verified, false), rs.form_code,
    rs.total_minutes, rs.night_minutes, rs.daily_cap_minutes,
    c, cn, c - cn, rawm, withp - c, pend, round(miles, 1), lessons,
    case when s.school_id is null then null else (s.hour_goal * 60)::int end,   -- school goal only for school students
    greatest(coalesce(rs.total_minutes, 0) - c, 0),
    greatest(coalesce(rs.night_minutes, 0) - cn, 0),
    rs.id is not null and c >= rs.total_minutes and cn >= rs.night_minutes;
end;
$$;

-- Day-by-day breakdown for reports (the Texas form is one line per day).
create or replace function public.student_hours_by_day(
  p_student_id uuid,
  p_from date default null,
  p_to date default null,
  p_include_pending boolean default false
)
returns table (
  local_date date, drives int, raw_minutes int, raw_night_minutes int,
  credited_minutes int, night_credited_minutes int, miles numeric, capped boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.can_view_student(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  return query
    select t.local_date, t.drives, t.raw_minutes, t.raw_night_minutes, t.credited_minutes,
           t.night_credited_minutes, round(t.miles, 1), t.credited_minutes < t.raw_minutes
      from private.day_totals(p_student_id,
             case when p_include_pending then array['signed', 'pending'] else array['signed'] end) t
     where (p_from is null or t.local_date >= p_from)
       and (p_to is null or t.local_date <= p_to)
     order by t.local_date;
end;
$$;

-- Keep the live roster columns (students.practice_hours / night_hours / school_hours)
-- in step with signed drives so the dashboard's student list stays one cheap query.
create or replace function private.refresh_student_hours(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c int; cn int; l int;
begin
  select coalesce(sum(credited_minutes), 0), coalesce(sum(night_credited_minutes), 0)
    into c, cn from private.day_totals(p_student_id, array['signed']);
  select coalesce(sum(duration_minutes), 0) into l
    from public.drives where student_id = p_student_id and kind = 'lesson' and status = 'signed';
  update public.students
     set practice_hours = round(c / 60.0, 1),
         night_hours = round(cn / 60.0, 1),
         school_hours = round(l / 60.0, 1)
   where id = p_student_id
     and (practice_hours, night_hours, school_hours)
         is distinct from (round(c / 60.0, 1), round(cn / 60.0, 1), round(l / 60.0, 1));
end;
$$;

create or replace function private.drives_refresh_hours()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform private.refresh_student_hours(old.student_id);
    return old;
  end if;
  perform private.refresh_student_hours(new.student_id);
  return new;
end;
$$;
revoke all on function private.refresh_student_hours(uuid) from public, anon, authenticated;
revoke all on function private.drives_refresh_hours() from public, anon, authenticated;

drop trigger if exists drives_refresh_hours_ins on public.drives;
create trigger drives_refresh_hours_ins after insert on public.drives
  for each row when (new.status = 'signed') execute function private.drives_refresh_hours();
drop trigger if exists drives_refresh_hours_upd on public.drives;
create trigger drives_refresh_hours_upd after update on public.drives
  for each row when (old.status is distinct from new.status and 'signed' in (old.status, new.status))
  execute function private.drives_refresh_hours();
-- No delete trigger needed: signed drives can't be deleted except by cascade (student gone).

-- ---------------------------------------------------------------------------
-- Paged lists (never rely on the API's 1,000-row cap)
-- ---------------------------------------------------------------------------

-- Newest first. Pass the last row's started_at + id to get the next page.
create or replace function public.list_drives(
  p_student_id uuid,
  p_before_started_at timestamptz default null,
  p_before_id uuid default null,
  p_limit int default 50
)
returns table (
  id uuid, student_id uuid, supervisor_id uuid, supervisor_name text, kind text, source text, status text,
  started_at timestamptz, ended_at timestamptz, tz text, local_date date, duration_minutes int, night_minutes int,
  distance_miles numeric, start_label text, end_label text, conditions text[], skills text[], notes text,
  has_route boolean, locked_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select d.id, d.student_id, d.supervisor_id, sp.name, d.kind, d.source, d.status,
         d.started_at, d.ended_at, d.tz, d.local_date, d.duration_minutes, d.night_minutes,
         d.distance_miles, d.start_label, d.end_label, d.conditions, d.skills, d.notes,
         d.route_polyline is not null, d.locked_at
    from public.drives d
    left join public.supervisors sp on sp.id = d.supervisor_id
   where d.student_id = p_student_id
     and (p_before_started_at is null
          or (d.started_at, d.id) < (p_before_started_at, coalesce(p_before_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
   order by d.started_at desc, d.id desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
$$;

-- Drives waiting for MY signature (family app home screen).
create or replace function public.pending_signoffs(p_limit int default 50)
returns table (drive_id uuid, student_id uuid, first_name text, started_at timestamptz,
               duration_minutes int, night_minutes int, distance_miles numeric, supervisor_name text)
language sql
stable
security invoker
set search_path = ''
as $$
  select d.id, d.student_id, s.first_name, d.started_at, d.duration_minutes, d.night_minutes,
         d.distance_miles, sp.name
    from public.drives d
    join public.students s on s.id = d.student_id
    join public.family_links f on f.student_id = d.student_id
         and f.user_id = (select auth.uid()) and f.status = 'active' and f.can_sign
    left join public.supervisors sp on sp.id = d.supervisor_id
   where d.status = 'pending' and d.kind = 'practice'
   order by d.started_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200);
$$;

-- Dashboard roster with progress, paged by name (keyset: last_name, first_name, id).
create or replace function public.school_students_progress(
  p_school_id uuid,
  p_after_last text default null,
  p_after_first text default null,
  p_after_id uuid default null,
  p_limit int default 100
)
returns table (student_id uuid, first_name text, last_name text, seat text, instructor_id uuid,
               practice_hours numeric, night_hours numeric, school_hours numeric, hour_goal numeric,
               night_goal numeric, pending_drives bigint, last_drive_at timestamptz)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.id, s.first_name, s.last_name, s.seat, s.instructor_id, s.practice_hours, s.night_hours,
         s.school_hours, s.hour_goal, s.night_goal,
         (select count(*) from public.drives d where d.student_id = s.id and d.status = 'pending'),
         (select max(d.started_at) from public.drives d where d.student_id = s.id)
    from public.students s
   where s.school_id = p_school_id
     and (p_after_id is null
          or (s.last_name, s.first_name, s.id) > (coalesce(p_after_last, ''), coalesce(p_after_first, ''), p_after_id))
   order by s.last_name, s.first_name, s.id
   limit least(greatest(coalesce(p_limit, 100), 1), 500);
$$;

revoke all on function public.student_hours_summary(uuid) from public, anon;
revoke all on function public.student_hours_by_day(uuid, date, date, boolean) from public, anon;
revoke all on function public.list_drives(uuid, timestamptz, uuid, int) from public, anon;
revoke all on function public.pending_signoffs(int) from public, anon;
revoke all on function public.school_students_progress(uuid, text, text, uuid, int) from public, anon;
grant execute on function public.student_hours_summary(uuid) to authenticated, service_role;
grant execute on function public.student_hours_by_day(uuid, date, date, boolean) to authenticated, service_role;
grant execute on function public.list_drives(uuid, timestamptz, uuid, int) to authenticated, service_role;
grant execute on function public.pending_signoffs(int) to authenticated;
grant execute on function public.school_students_progress(uuid, text, text, uuid, int) to authenticated;
