-- NOT APPLIED — Phase 9. Frank must type "push".
-- Family/student requests a reservation window (portal).

create or replace function public.request_slot(
  p_school_id uuid,
  p_student_id uuid,
  p_instructor_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_meet text default 'lot',
  p_note text default '',
  p_car_id uuid default null,
  p_template_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Not authenticated'; end if;
  -- Caller must be desk OR active family/student for this student
  if not (
    private.can_manage_students(p_school_id)
    or private.can_act_for_student(p_student_id)
  ) then
    raise exception 'Not allowed';
  end if;
  if p_end_at <= p_start_at then raise exception 'Invalid window'; end if;

  insert into public.reservations (
    school_id, student_id, instructor_id, car_id, template_id,
    start_at, end_at, meet, kind, status, note
  ) values (
    p_school_id, p_student_id, p_instructor_id, p_car_id, p_template_id,
    p_start_at, p_end_at, coalesce(p_meet, 'lot'), 'btw', 'requested', coalesce(p_note, '')
  ) returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.request_slot(uuid, uuid, uuid, timestamptz, timestamptz, text, text, uuid, uuid) from public, anon;
grant execute on function public.request_slot(uuid, uuid, uuid, timestamptz, timestamptz, text, text, uuid, uuid) to authenticated;
