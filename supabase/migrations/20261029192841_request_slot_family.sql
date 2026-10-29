-- Keep live 12-arg request_slot. Allow family/student (can_act_for_student) and desk (can_manage_students) in addition to can_schedule_row.
create or replace function public.request_slot(
  p_school_id uuid,
  p_student_id uuid,
  p_instructor_id uuid,
  p_start timestamp with time zone,
  p_end timestamp with time zone,
  p_meet text default 'lot',
  p_kind text default 'btw',
  p_car_id uuid default null,
  p_travel_before_minutes integer default 0,
  p_travel_after_minutes integer default 15,
  p_note text default '',
  p_template_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  rid uuid;
  k text := lower(trim(coalesce(p_kind, 'btw')));
  m text := lower(trim(coalesce(p_meet, 'lot')));
  conflict text;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not (
    private.can_schedule_row(p_school_id, p_instructor_id)
    or private.can_manage_students(p_school_id)
    or private.can_act_for_student(p_student_id)
  ) then
    raise exception 'Not allowed to request a slot';
  end if;
  if k = 'behind-the-wheel' then k := 'btw'; end if;
  if k = 'road-test ride' then k := 'road_test'; end if;
  if k not in ('btw', 'observation', 'classroom', 'road_test') then
    raise exception 'Unknown lesson kind';
  end if;
  if m not in ('lot', 'pickup') then
    raise exception 'Meet must be lot or pickup';
  end if;
  if not exists (
    select 1 from public.students
    where id = p_student_id and school_id = p_school_id
  ) then
    raise exception 'Student is not on this school';
  end if;

  conflict := private.schedule_conflict(
    p_school_id, p_instructor_id, p_car_id,
    p_start, p_end, coalesce(p_travel_before_minutes, 0), coalesce(p_travel_after_minutes, 15)
  );
  if conflict is not null then
    raise exception '%', conflict;
  end if;

  insert into public.reservations (
    school_id, student_id, instructor_id, car_id, template_id,
    start_at, end_at, travel_before_minutes, travel_after_minutes,
    meet, kind, status, note
  ) values (
    p_school_id, p_student_id, p_instructor_id, p_car_id, p_template_id,
    p_start, p_end,
    coalesce(p_travel_before_minutes, 0),
    coalesce(p_travel_after_minutes, 15),
    m, k, 'requested', coalesce(p_note, '')
  )
  returning id into rid;
  return rid;
end;
$$;

revoke all on function public.request_slot(uuid, uuid, uuid, timestamptz, timestamptz, text, text, uuid, integer, integer, text, uuid) from public, anon;
grant execute on function public.request_slot(uuid, uuid, uuid, timestamptz, timestamptz, text, text, uuid, integer, integer, text, uuid) to authenticated;

