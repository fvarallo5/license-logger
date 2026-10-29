-- NOT APPLIED — Phase 7. Frank must type "push".
-- Lesson-based instructor pay runs (not TrekTrack job pay_rules).

create table if not exists public.instructor_pay_runs (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  instructor_id uuid not null references auth.users (id) on delete cascade,
  period_start date not null,
  period_end date not null,
  hours numeric(8, 2) not null default 0,
  rate numeric(10, 2) not null default 0,
  amount numeric(12, 2) not null default 0,
  status text not null default 'draft' check (status in ('draft', 'approved', 'paid', 'void')),
  note text not null default '',
  created_by uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  unique (school_id, instructor_id, period_start, period_end)
);

create index if not exists instructor_pay_runs_school_idx
  on public.instructor_pay_runs (school_id, period_start desc);

alter table public.instructor_pay_runs enable row level security;
alter table public.instructor_pay_runs force row level security;
revoke all on table public.instructor_pay_runs from public, anon;

create policy instructor_pay_runs_select on public.instructor_pay_runs
  for select to authenticated
  using (school_id in (select private.pay_school_ids()));
create policy instructor_pay_runs_write on public.instructor_pay_runs
  for all to authenticated
  using (school_id in (select private.pay_school_ids()))
  with check (school_id in (select private.pay_school_ids()));

grant select, insert, update on table public.instructor_pay_runs to authenticated;
grant all on table public.instructor_pay_runs to service_role;

-- Aggregate taught lesson minutes × member hourly_rate for a period.
create or replace function public.compute_instructor_pay(
  p_school_id uuid,
  p_period_start date,
  p_period_end date
) returns table (
  instructor_id uuid,
  hours numeric,
  rate numeric,
  amount numeric
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_school_id not in (select private.pay_school_ids()) then
    raise exception 'Not allowed';
  end if;
  return query
  select
    l.instructor_id,
    round((sum(extract(epoch from (l.end_at - l.start_at)) / 3600.0))::numeric, 2) as hours,
    coalesce(m.hourly_rate, 0)::numeric as rate,
    round(
      (sum(extract(epoch from (l.end_at - l.start_at)) / 3600.0) * coalesce(m.hourly_rate, 0))::numeric,
      2
    ) as amount
  from public.lessons l
  join public.school_members m
    on m.school_id = l.school_id and m.user_id = l.instructor_id
  where l.school_id = p_school_id
    and l.status = 'taught'
    and l.start_at::date >= p_period_start
    and l.start_at::date <= p_period_end
  group by l.instructor_id, m.hourly_rate;
end;
$$;

revoke all on function public.compute_instructor_pay(uuid, date, date) from public, anon;
grant execute on function public.compute_instructor_pay(uuid, date, date) to authenticated;
