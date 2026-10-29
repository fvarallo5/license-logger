-- LicenseLogger: profiles, schools, members, invites, RLS.
-- Own project. Mutations go through SECURITY DEFINER RPCs.

create schema if not exists private;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated, postgres, service_role;

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;
alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  city text not null default '',
  phone text not null default '',
  timezone text not null default 'America/Chicago',
  default_lesson_minutes int not null default 60 check (default_lesson_minutes between 15 and 240),
  cancel_window_hours int not null default 24 check (cancel_window_hours >= 0),
  who_starts text not null default 'either' check (who_starts in ('student', 'instructor', 'either')),
  package_draw text not null default 'accept' check (package_draw in ('accept', 'taught')),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.school_members (
  school_id uuid not null references public.schools (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'front_desk', 'instructor')),
  access jsonb not null default '{}'::jsonb,
  color text,
  license_expires date,
  hourly_rate numeric(10, 2),
  created_at timestamptz not null default now(),
  primary key (school_id, user_id)
);

create index if not exists school_members_user_id_idx
  on public.school_members (user_id);

create table if not exists public.school_invites (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools (id) on delete cascade,
  email text not null,
  role text not null check (role in ('admin', 'front_desk', 'instructor')),
  access jsonb not null default '{}'::jsonb,
  token uuid not null default gen_random_uuid() unique,
  invited_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz
);

create index if not exists school_invites_school_id_idx
  on public.school_invites (school_id);
create index if not exists school_invites_email_idx
  on public.school_invites (lower(email));
create unique index if not exists school_invites_pending_email_idx
  on public.school_invites (school_id, lower(email))
  where accepted_at is null;

create or replace function private.school_role_rank(p_role text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case lower(coalesce(p_role, ''))
    when 'owner' then 4
    when 'admin' then 3
    when 'front_desk' then 2
    when 'instructor' then 1
    else 0
  end;
$$;

create or replace function private.school_normalize_access(p_role text, p_access jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  r text := lower(trim(coalesce(p_role, '')));
  src jsonb := coalesce(p_access, '{}'::jsonb);
  page text;
  allowed text[] := array['board', 'plan', 'students', 'pay'];
  pages jsonb := '{}'::jsonb;
begin
  if r in ('owner', 'admin') then
    return jsonb_build_object(
      'board', true, 'plan', true, 'students', true,
      'pay', true, 'people', true, 'settings', true
    );
  end if;
  if r = 'front_desk' then
    foreach page in array allowed loop
      pages := pages || jsonb_build_object(
        page,
        coalesce((src ->> page)::boolean, page <> 'pay')
      );
    end loop;
    pages := pages || jsonb_build_object('people', false, 'settings', false);
    return pages;
  end if;
  return jsonb_build_object(
    'board', true, 'plan', true, 'students', true,
    'pay', false, 'people', false, 'settings', false
  );
end;
$$;

create or replace function private.user_school_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select school_id
  from public.school_members
  where user_id = (select auth.uid());
$$;

create or replace function private.school_role(p_school_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role
  from public.school_members
  where school_id = p_school_id
    and user_id = (select auth.uid());
$$;

create or replace function private.is_school_manager(p_school_id uuid)
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
      and role in ('owner', 'admin')
  );
$$;

create or replace function private.school_can(p_school_id uuid, p_page text)
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
        or coalesce((access ->> p_page)::boolean, false)
      )
  );
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

revoke all on function private.handle_new_user() from public, anon, authenticated;
grant execute on function private.handle_new_user() to supabase_auth_admin, postgres;

revoke all on function private.school_role_rank(text) from public, anon;
revoke all on function private.school_normalize_access(text, jsonb) from public, anon;
revoke all on function private.user_school_ids() from public, anon;
revoke all on function private.school_role(uuid) from public, anon;
revoke all on function private.is_school_manager(uuid) from public, anon;
revoke all on function private.school_can(uuid, text) from public, anon;

grant execute on function private.school_role_rank(text) to authenticated;
grant execute on function private.school_normalize_access(text, jsonb) to authenticated;
grant execute on function private.user_school_ids() to authenticated;
grant execute on function private.school_role(uuid) to authenticated;
grant execute on function private.is_school_manager(uuid) to authenticated;
grant execute on function private.school_can(uuid, text) to authenticated;

alter table public.profiles enable row level security;
alter table public.schools enable row level security;
alter table public.school_members enable row level security;
alter table public.school_invites enable row level security;
alter table public.profiles force row level security;
alter table public.schools force row level security;
alter table public.school_members force row level security;
alter table public.school_invites force row level security;

create policy profiles_select_own
  on public.profiles for select
  to authenticated
  using (id = (select auth.uid()));

create policy profiles_select_schoolmates
  on public.profiles for select
  to authenticated
  using (
    exists (
      select 1
      from public.school_members mine
      join public.school_members theirs
        on theirs.school_id = mine.school_id
      where mine.user_id = (select auth.uid())
        and theirs.user_id = profiles.id
    )
  );

create policy profiles_update_own
  on public.profiles for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy schools_select_member
  on public.schools for select
  to authenticated
  using (id in (select private.user_school_ids()));

create policy schools_update_manager
  on public.schools for update
  to authenticated
  using (private.is_school_manager(id))
  with check (private.is_school_manager(id));

create policy school_members_select
  on public.school_members for select
  to authenticated
  using (school_id in (select private.user_school_ids()));

create policy school_invites_select_manager
  on public.school_invites for select
  to authenticated
  using (private.is_school_manager(school_id));

create policy school_invites_insert_manager
  on public.school_invites for insert
  to authenticated
  with check (private.is_school_manager(school_id));

create policy school_invites_delete_manager
  on public.school_invites for delete
  to authenticated
  using (private.is_school_manager(school_id));

revoke all on table public.profiles from public, anon;
revoke all on table public.schools from public, anon;
revoke all on table public.school_members from public, anon;
revoke all on table public.school_invites from public, anon;

grant select, update on table public.profiles to authenticated;
grant select, update on table public.schools to authenticated;
grant select on table public.school_members to authenticated;
grant select, insert, delete on table public.school_invites to authenticated;
grant usage, select on sequence public.school_invites_id_seq to authenticated;

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

  return sid;
end;
$$;

create or replace function public.invite_to_school(
  p_school_id uuid,
  p_email text,
  p_role text default 'instructor',
  p_access jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  tok uuid;
  r text := lower(trim(p_role));
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if not private.is_school_manager(p_school_id) then
    raise exception 'Not a school manager';
  end if;
  if r not in ('admin', 'front_desk', 'instructor') then
    raise exception 'Role must be admin, front_desk, or instructor';
  end if;
  if position('@' in lower(trim(p_email))) = 0 then
    raise exception 'Enter a valid email';
  end if;

  insert into public.school_invites (school_id, email, role, access, invited_by)
  values (
    p_school_id,
    lower(trim(p_email)),
    r,
    private.school_normalize_access(r, p_access),
    uid
  )
  returning token into tok;

  return tok;
end;
$$;

create or replace function public.accept_school_invite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  em text;
  v_id bigint;
  v_school_id uuid;
  v_email text;
  v_role text;
  v_access jsonb;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  select lower(coalesce((select auth.jwt()) ->> 'email', '')) into em;

  select id, school_id, email, role, access
    into v_id, v_school_id, v_email, v_role, v_access
  from public.school_invites
  where token = p_token
    and accepted_at is null
    and expires_at > now();

  if v_id is null then
    raise exception 'Invite not found or expired';
  end if;
  if em = '' or lower(v_email) <> em then
    raise exception 'Invite email does not match this account';
  end if;

  insert into public.school_members (school_id, user_id, role, access)
  values (
    v_school_id,
    uid,
    v_role,
    private.school_normalize_access(v_role, v_access)
  )
  on conflict (school_id, user_id) do nothing;

  update public.school_invites
  set accepted_at = now()
  where id = v_id;

  return v_school_id;
end;
$$;

revoke all on function public.create_school(text, text) from public, anon;
revoke all on function public.invite_to_school(uuid, text, text, jsonb) from public, anon;
revoke all on function public.accept_school_invite(uuid) from public, anon;
grant execute on function public.create_school(text, text) to authenticated;
grant execute on function public.invite_to_school(uuid, text, text, jsonb) to authenticated;
grant execute on function public.accept_school_invite(uuid) to authenticated;
