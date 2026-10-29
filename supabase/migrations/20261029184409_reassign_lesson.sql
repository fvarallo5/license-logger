-- Applied on live nqfjudwncistygsmcgrq as 20261029184409_reassign_lesson
-- (schema_migrations created_by fvarallo5@gmail.com).
-- Board Reassign: change lessons.instructor_id / car_id via SECURITY DEFINER.
-- Live lessons RLS is SELECT-only; updates go through RPCs.

create or replace function public.reassign_lesson(
  p_lesson_id uuid,
  p_instructor_id uuid,
  p_car_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  rec public.lessons%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;

  select * into rec
  from public.lessons
  where id = p_lesson_id
  for update;

  if rec.id is null then
    raise exception 'Lesson not found' using errcode = 'P0002';
  end if;
  if rec.kind = 'blocked' then
    raise exception 'Blocked time cannot be reassigned';
  end if;
  if rec.status not in ('booked', 'in_lesson') then
    raise exception 'Only open lessons can be reassigned';
  end if;
  if not private.can_schedule_row(rec.school_id, rec.instructor_id) then
    raise exception 'Not allowed to reassign this lesson' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.school_members
    where school_id = rec.school_id and user_id = p_instructor_id
  ) then
    raise exception 'Instructor is not on this school';
  end if;
  if p_car_id is not null and not exists (
    select 1 from public.cars where id = p_car_id and school_id = rec.school_id and active
  ) then
    raise exception 'Car is not on this school';
  end if;

  update public.lessons
  set instructor_id = p_instructor_id,
      car_id = coalesce(p_car_id, rec.car_id),
      updated_at = now()
  where id = rec.id;
end;
$$;

revoke all on function public.reassign_lesson(uuid, uuid, uuid) from public, anon;
grant execute on function public.reassign_lesson(uuid, uuid, uuid) to authenticated;
