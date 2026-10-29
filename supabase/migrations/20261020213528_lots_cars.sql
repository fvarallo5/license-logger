-- Lots, cars, people helpers, school update, invite accept-on-login.

create or replace function private.can_manage_people(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_members
    where school_id = p_school_id
      and user_id = (select auth.uid())
      and (
        role in ('owner', 'admin')
        or coalesce((access ->> 'people')::boolean, false)
      )
  );
$$;

create table if not exists public.lots (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  lat numeric,
  lng numeric,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists lots_school_id_idx on public.lots (school_id);
create unique index if not exists lots_one_default_idx
  on public.lots (school_id)
  where is_default;

create table if not exists public.cars (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 80),
  plate text not null default '',
  color text not null default '#1156C1',
  model text not null default '',
  dual_control boolean not null default true,
  assigned_user_id uuid references auth.users (id) on delete set null,
  odo_miles numeric(10, 1) not null default 0,
  service_due date,
  inspect_due date,
  reg_due date,
  ins_due date,
  notes text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists cars_school_id_idx on public.cars (school_id);
create index if not exists cars_assigned_user_id_idx on public.cars (assigned_user_id);

insert into public.lots (school_id, name, is_default)
select s.id, 'Main lot', true
from public.schools s
where not exists (select 1 from public.lots l where l.school_id = s.id);

create or replace function public.create_school(p_name text, p_city text default '')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  sid uuid;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false) then
    raise exception 'Create an account first';
  end if;
  if char_length(trim(p_name)) < 1 then
    raise exception 'School name is required';
  end if;

  insert into public.schools (name, city, created_by)
  values (trim(p_name), trim(coalesce(p_city, '')), uid)
  returning id into sid;

  insert into public.school_members (school_id, user_id, role, access)
  values (
    sid,
    uid,
    'owner',
    private.school_normalize_access('owner', '{}'::jsonb)
  );

  perform private.seed_package_catalog(sid);

  insert into public.lots (school_id, name, is_default)
  values (sid, 'Main lot', true);

  return sid;
end;
$$;

revoke all on function private.can_manage_people(uuid) from public, anon;
grant execute on function private.can_manage_people(uuid) to authenticated;
grant execute on function public.create_school(text, text) to authenticated;

alter table public.lots enable row level security;
alter table public.cars enable row level security;
alter table public.lots force row level security;
alter table public.cars force row level security;

create policy lots_select
  on public.lots for select
  to authenticated
  using (school_id in (select private.user_school_ids()));

create policy lots_insert
  on public.lots for insert
  to authenticated
  with check (private.can_manage_people(school_id));

create policy lots_update
  on public.lots for update
  to authenticated
  using (private.can_manage_people(school_id))
  with check (private.can_manage_people(school_id));

create policy lots_delete
  on public.lots for delete
  to authenticated
  using (private.can_manage_people(school_id));

create policy cars_select
  on public.cars for select
  to authenticated
  using (school_id in (select private.user_school_ids()));

create policy cars_insert
  on public.cars for insert
  to authenticated
  with check (private.can_manage_people(school_id));

create policy cars_update
  on public.cars for update
  to authenticated
  using (private.can_manage_people(school_id))
  with check (private.can_manage_people(school_id));

create policy cars_delete
  on public.cars for delete
  to authenticated
  using (private.can_manage_people(school_id));

revoke all on table public.lots from public, anon;
revoke all on table public.cars from public, anon;
grant select, insert, update, delete on table public.lots to authenticated;
grant select, insert, update, delete on table public.cars to authenticated;

create or replace function public.update_school(
  p_school_id uuid,
  p_name text default null,
  p_city text default null,
  p_phone text default null,
  p_timezone text default null,
  p_default_lesson_minutes int default null,
  p_cancel_window_hours int default null,
  p_who_starts text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not private.is_school_manager(p_school_id) then
    raise exception 'Not a school manager';
  end if;
  if p_who_starts is not null and p_who_starts not in ('student', 'instructor', 'either') then
    raise exception 'who_starts must be student, instructor, or either';
  end if;

  update public.schools
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    city = coalesce(p_city, city),
    phone = coalesce(p_phone, phone),
    timezone = coalesce(nullif(trim(p_timezone), ''), timezone),
    default_lesson_minutes = coalesce(p_default_lesson_minutes, default_lesson_minutes),
    cancel_window_hours = coalesce(p_cancel_window_hours, cancel_window_hours),
    who_starts = coalesce(p_who_starts, who_starts)
  where id = p_school_id;
end;
$$;

create or replace function public.add_lot(p_school_id uuid, p_name text, p_is_default boolean default false)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  lid uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not private.can_manage_people(p_school_id) then
    raise exception 'Not allowed to add lots';
  end if;
  if char_length(trim(p_name)) < 1 then
    raise exception 'Lot name is required';
  end if;

  if p_is_default then
    update public.lots set is_default = false where school_id = p_school_id;
  end if;

  insert into public.lots (school_id, name, is_default)
  values (p_school_id, trim(p_name), coalesce(p_is_default, false))
  returning id into lid;
  return lid;
end;
$$;

create or replace function public.add_car(
  p_school_id uuid,
  p_name text,
  p_plate text default '',
  p_color text default '#1156C1',
  p_model text default '',
  p_assigned_user_id uuid default null,
  p_odo_miles numeric default 0
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  cid uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;
  if not private.can_manage_people(p_school_id) then
    raise exception 'Not allowed to add cars';
  end if;
  if char_length(trim(p_name)) < 1 then
    raise exception 'Car name is required';
  end if;
  if p_assigned_user_id is not null and not exists (
    select 1 from public.school_members
    where school_id = p_school_id and user_id = p_assigned_user_id
  ) then
    raise exception 'Assignee is not on this school';
  end if;

  insert into public.cars (
    school_id, name, plate, color, model, assigned_user_id, odo_miles
  ) values (
    p_school_id,
    trim(p_name),
    trim(coalesce(p_plate, '')),
    coalesce(nullif(trim(p_color), ''), '#1156C1'),
    trim(coalesce(p_model, '')),
    p_assigned_user_id,
    coalesce(p_odo_miles, 0)
  )
  returning id into cid;
  return cid;
end;
$$;

create or replace function public.revoke_invite(p_invite_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Not authenticated';
  end if;

  select school_id into sid
  from public.school_invites
  where id = p_invite_id and accepted_at is null;

  if sid is null then
    raise exception 'Invite not found';
  end if;
  if not private.is_school_manager(sid) then
    raise exception 'Not a school manager';
  end if;

  delete from public.school_invites where id = p_invite_id and accepted_at is null;
end;
$$;

create or replace function public.accept_my_invites()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  em text;
  n int := 0;
  rec record;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  select lower(coalesce((select auth.jwt()) ->> 'email', '')) into em;
  if em = '' then
    return 0;
  end if;

  for rec in
    select id, school_id, role, access
    from public.school_invites
    where accepted_at is null
      and expires_at > now()
      and lower(email) = em
  loop
    insert into public.school_members (school_id, user_id, role, access)
    values (
      rec.school_id,
      uid,
      rec.role,
      private.school_normalize_access(rec.role, rec.access)
    )
    on conflict (school_id, user_id) do nothing;

    update public.school_invites
    set accepted_at = now()
    where id = rec.id;

    n := n + 1;
  end loop;

  return n;
end;
$$;

revoke all on function public.update_school(uuid, text, text, text, text, int, int, text) from public, anon;
revoke all on function public.add_lot(uuid, text, boolean) from public, anon;
revoke all on function public.add_car(uuid, text, text, text, text, uuid, numeric) from public, anon;
revoke all on function public.revoke_invite(bigint) from public, anon;
revoke all on function public.accept_my_invites() from public, anon;

grant execute on function public.update_school(uuid, text, text, text, text, int, int, text) to authenticated;
grant execute on function public.add_lot(uuid, text, boolean) to authenticated;
grant execute on function public.add_car(uuid, text, text, text, text, uuid, numeric) to authenticated;
grant execute on function public.revoke_invite(bigint) to authenticated;
grant execute on function public.accept_my_invites() to authenticated;
