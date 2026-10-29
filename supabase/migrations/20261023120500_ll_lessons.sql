-- LicenseLogger lessons: on live this became ll_lessons_compat after scheduling.
-- Tables + Board RPCs are created in 20261023222828_scheduling.sql (live order used start_at/end_at).
-- This file intentionally does not recreate public.lessons, so fresh staging matches live shape.
-- School schedule RPC used by the desk:
create or replace function public.school_schedule(p_school_id uuid, p_from timestamptz, p_to timestamptz)
returns setof public.lessons
language sql
stable
set search_path = ''
as $$
  select * from public.lessons
   where school_id = p_school_id and start_at < p_to and end_at > p_from
   order by start_at
   limit 1000;
$$;
revoke all on function public.school_schedule(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.school_schedule(uuid, timestamptz, timestamptz) to authenticated;

-- mark_lesson: live accepts taught | no_show | cancelled | in_lesson | booked
-- Full body exists on production; staging without the full scheduling RPC pack should not
-- rely on this stub for booking. Desk Phase 0 only needs the type alignment.
