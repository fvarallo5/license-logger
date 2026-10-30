-- Applied 2026-10-30 on nqfjudwncistygsmcgrq.
-- Advisor: unindexed FKs on instructor_pay_runs + multiple permissive SELECT policies.
-- Idempotent. Does not recreate tables from phase 7.

create index if not exists instructor_pay_runs_instructor_id_idx
  on public.instructor_pay_runs (instructor_id);

create index if not exists instructor_pay_runs_created_by_idx
  on public.instructor_pay_runs (created_by);

-- Split ALL policy so SELECT is not evaluated twice (select + write overlap).
drop policy if exists instructor_pay_runs_write on public.instructor_pay_runs;

create policy instructor_pay_runs_insert on public.instructor_pay_runs
  for insert to authenticated
  with check (school_id in (select private.pay_school_ids()));

create policy instructor_pay_runs_update on public.instructor_pay_runs
  for update to authenticated
  using (school_id in (select private.pay_school_ids()))
  with check (school_id in (select private.pay_school_ids()));

create policy instructor_pay_runs_delete on public.instructor_pay_runs
  for delete to authenticated
  using (school_id in (select private.pay_school_ids()));

-- Keep select policy as-is (instructor_pay_runs_select).
