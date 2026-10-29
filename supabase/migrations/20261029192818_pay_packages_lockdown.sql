-- NOT APPLIED — Phase 4. Frank must type "push" before applying.
-- 1) Money lockdown: instructors lose SELECT on package price / member hourly_rate via pay-gated RPCs preferred.
-- 2) assign_student_package + record_invoice_payment SECURITY DEFINER helpers.

-- Narrow package_catalog SELECT so non-pay desk still sees names/hours but price is null via view.
create or replace view public.package_catalog_desk
with (security_invoker = true)
as
select
  c.id,
  c.school_id,
  c.name,
  c.hours,
  case
    when c.school_id in (select private.pay_school_ids()) then c.price
    else null::numeric
  end as price,
  c.kind,
  c.active
from public.package_catalog c;

revoke all on public.package_catalog_desk from public, anon;
grant select on public.package_catalog_desk to authenticated;

comment on view public.package_catalog_desk is
  'Desk-safe package catalog; price only when caller has pay access.';

-- Prefer this RPC for assigns (voids prior active package).
create or replace function public.assign_student_package(
  p_school_id uuid,
  p_student_id uuid,
  p_catalog_id uuid
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hours numeric;
  v_id uuid;
begin
  if not private.can_manage_students(p_school_id) then
    raise exception 'Not allowed';
  end if;
  if not exists (
    select 1 from public.students s where s.id = p_student_id and s.school_id = p_school_id
  ) then
    raise exception 'Student not in school';
  end if;
  select hours into v_hours
  from public.package_catalog
  where id = p_catalog_id and school_id = p_school_id and active;
  if v_hours is null then
    raise exception 'Package not found';
  end if;
  update public.student_packages
    set status = 'void'
    where student_id = p_student_id and status = 'active';
  insert into public.student_packages (school_id, student_id, catalog_id, hours_total, hours_left, status)
  values (p_school_id, p_student_id, p_catalog_id, v_hours, v_hours, 'active')
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.assign_student_package(uuid, uuid, uuid) from public, anon;
grant execute on function public.assign_student_package(uuid, uuid, uuid) to authenticated;

create or replace function public.record_invoice_payment(
  p_school_id uuid,
  p_customer_id uuid,
  p_invoice_id uuid,
  p_student_id uuid,
  p_amount numeric,
  p_method text default 'cash',
  p_reference text default '',
  p_received_on date default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_bal numeric;
begin
  if p_school_id not in (select private.pay_school_ids()) then
    raise exception 'Not allowed';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount required';
  end if;
  insert into public.payments (
    school_id, customer_id, invoice_id, student_id, amount, method, reference, received_on
  ) values (
    p_school_id, p_customer_id, p_invoice_id, p_student_id, p_amount,
    coalesce(nullif(trim(p_method), ''), 'cash'),
    coalesce(p_reference, ''),
    coalesce(p_received_on, current_date)
  ) returning id into v_id;

  if p_invoice_id is not null then
    update public.invoices i
      set balance = greatest(0, i.balance - p_amount),
          status = case
            when greatest(0, i.balance - p_amount) = 0 then 'paid'
            when greatest(0, i.balance - p_amount) < i.total then 'partially_paid'
            else i.status
          end,
          sync_status = case when i.sync_status = 'synced' then 'pending' else i.sync_status end
      where i.id = p_invoice_id and i.school_id = p_school_id
      returning balance into v_bal;
  end if;
  return v_id;
end;
$$;

revoke all on function public.record_invoice_payment(uuid, uuid, uuid, uuid, numeric, text, text, date) from public, anon;
grant execute on function public.record_invoice_payment(uuid, uuid, uuid, uuid, numeric, text, text, date) to authenticated;

-- Hide hourly_rate from non-pay roles: replace SELECT list via column privilege (PG 15+).
-- Authenticated keeps table access; pay roles read rate through RPC below.
revoke select (hourly_rate) on public.school_members from authenticated;
grant select (hourly_rate) on public.school_members to service_role;

create or replace function public.member_hourly_rate(p_school_id uuid, p_user_id uuid)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare r numeric;
begin
  if p_school_id not in (select private.pay_school_ids()) then
    return null;
  end if;
  select hourly_rate into r from public.school_members
  where school_id = p_school_id and user_id = p_user_id;
  return r;
end;
$$;

revoke all on function public.member_hourly_rate(uuid, uuid) from public, anon;
grant execute on function public.member_hourly_rate(uuid, uuid) to authenticated;
