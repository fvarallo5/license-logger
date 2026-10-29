-- LicenseLogger 005: foundation for the launch backend.
-- Additive only: nothing here changes or removes what the live project already has.
--  * btree_gist (needed for "no double-booking" rules on lessons)
--  * the 2 foreign-key indexes the performance advisor flagged
--  * profiles.account_type (student / family / staff)
--  * shared helpers: updated_at trigger, audit log, "which schools am I desk staff of"

create extension if not exists btree_gist with schema extensions;

-- Advisor: unindexed_foreign_keys (student_contacts.user_id, student_packages.catalog_id)
create index if not exists student_contacts_user_id_idx on public.student_contacts (user_id);
create index if not exists student_packages_catalog_id_idx on public.student_packages (catalog_id);

-- Which app experience a person picked on first launch. 'unset' = not chosen yet.
alter table public.profiles
  add column if not exists account_type text not null default 'unset'
    check (account_type in ('unset', 'student', 'family', 'staff')),
  add column if not exists notify_email boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

-- ---------------------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------------------
create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

drop trigger if exists students_touch on public.students;
create trigger students_touch before update on public.students
  for each row execute function private.touch_updated_at();

-- Schools where I am "desk" staff (owner/admin, or front desk with Students access).
-- Same rule as the live private.can_manage_students(), but as a set so RLS can
-- evaluate it ONCE per query: `school_id in (select private.desk_school_ids())`.
create or replace function private.desk_school_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select school_id
  from public.school_members
  where user_id = (select auth.uid())
    and role in ('owner', 'admin', 'front_desk')
    and (role in ('owner', 'admin') or coalesce((access ->> 'students')::boolean, true));
$$;

-- Schools where I can see money (owner/admin, or anyone granted the Pay page).
create or replace function private.pay_school_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select school_id
  from public.school_members
  where user_id = (select auth.uid())
    and (role in ('owner', 'admin') or coalesce((access ->> 'pay')::boolean, false));
$$;

-- Schools I manage (owner/admin).
create or replace function private.manager_school_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select school_id
  from public.school_members
  where user_id = (select auth.uid())
    and role in ('owner', 'admin');
$$;

revoke all on function private.desk_school_ids() from public, anon;
revoke all on function private.pay_school_ids() from public, anon;
revoke all on function private.manager_school_ids() from public, anon;
grant execute on function private.desk_school_ids() to authenticated;
grant execute on function private.pay_school_ids() to authenticated;
grant execute on function private.manager_school_ids() to authenticated;

create or replace function private.is_anonymous()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false);
$$;
grant execute on function private.is_anonymous() to authenticated;

-- ---------------------------------------------------------------------------
-- Audit log: who changed what, when. Written only by triggers.
-- ---------------------------------------------------------------------------
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  -- No foreign keys on purpose: the audit trail must outlive the rows it describes.
  school_id uuid,
  student_id uuid,
  actor_id uuid,
  actor_role text not null default current_user,
  action text not null check (action in ('insert', 'update', 'delete')),
  table_name text not null,
  row_pk text not null,
  changed jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
create index if not exists audit_log_school_at_idx on public.audit_log (school_id, at desc);
create index if not exists audit_log_student_idx on public.audit_log (student_id);
create index if not exists audit_log_actor_idx on public.audit_log (actor_id);

alter table public.audit_log enable row level security;
alter table public.audit_log force row level security;

drop policy if exists audit_log_select_manager on public.audit_log;
create policy audit_log_select_manager on public.audit_log
  for select to authenticated
  using (school_id in (select private.manager_school_ids()));

revoke all on table public.audit_log from public, anon, authenticated;
grant select on table public.audit_log to authenticated;
grant select on table public.audit_log to service_role;

-- Records only the columns that changed (update) or the whole row (insert/delete).
-- Expects the audited table to have school_id; student_id is used when present.
create or replace function private.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  o jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  n jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  r jsonb := coalesce(n, o);
  diff jsonb := '{}'::jsonb;
  k text;
begin
  if tg_op = 'UPDATE' then
    for k in select jsonb_object_keys(n) loop
      if k <> 'updated_at' and (o -> k) is distinct from (n -> k) then
        diff := diff || jsonb_build_object(k, jsonb_build_array(o -> k, n -> k));
      end if;
    end loop;
    if diff = '{}'::jsonb then
      return null;
    end if;
  else
    diff := r - 'route_polyline' - 'polyline';
  end if;

  insert into public.audit_log (school_id, student_id, actor_id, action, table_name, row_pk, changed)
  values (
    nullif(r ->> 'school_id', '')::uuid,
    case when tg_table_name = 'students' then nullif(r ->> 'id', '')::uuid
         else nullif(r ->> 'student_id', '')::uuid end,
    (select auth.uid()),
    lower(tg_op),
    tg_table_name,
    coalesce(r ->> 'id', r ->> 'user_id', ''),
    diff
  );
  return null;
end;
$$;
revoke all on function private.audit_row() from public, anon, authenticated;

drop trigger if exists school_members_audit on public.school_members;
create trigger school_members_audit after insert or update or delete on public.school_members
  for each row execute function private.audit_row();

-- ---------------------------------------------------------------------------
-- Privilege hygiene (found on live, Oct 22 2026): the 11 existing tables give the
-- `authenticated` role TRUNCATE / TRIGGER / REFERENCES through Supabase's default
-- grants. The API can't issue TRUNCATE, but TRUNCATE ignores RLS, so take it away
-- (and stop future tables from getting it). Normal select/insert/update/delete stay
-- as they are; RLS still decides those.
-- ---------------------------------------------------------------------------
revoke truncate, trigger, references on table
  public.profiles, public.schools, public.school_members, public.school_invites,
  public.students, public.student_contacts, public.package_catalog, public.student_packages,
  public.student_checklist, public.lots, public.cars
  from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke truncate, trigger, references on tables from anon, authenticated;
