-- LicenseLogger 007: family accounts, invite codes, supervisors, and the
-- "which students can I see" helper every later table uses.

-- ---------------------------------------------------------------------------
-- Shared trigger: copy school_id from the student row (never trust the client).
-- school_id is NULL for independent students (no driving school), see migration 013.
-- SECURITY INVOKER so current_user tells app clients apart from trusted RPCs; the
-- student lookups go through SECURITY DEFINER helpers.
-- ---------------------------------------------------------------------------
create or replace function private.student_exists(p_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.students where id = p_student_id);
$$;

create or replace function private.student_school_id(p_student_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
  select school_id from public.students where id = p_student_id;
$$;
revoke all on function private.student_exists(uuid) from public, anon;
revoke all on function private.student_school_id(uuid) from public, anon;
grant execute on function private.student_exists(uuid) to authenticated;
grant execute on function private.student_school_id(uuid) to authenticated;

create or replace function private.set_school_from_student()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Only trusted code (our SECURITY DEFINER RPCs, e.g. the school-profile merge) may re-point a row.
  if tg_op = 'UPDATE' and new.student_id is distinct from old.student_id
     and current_user in ('authenticated', 'anon') then
    raise exception 'student_id cannot be changed' using errcode = '42501';
  end if;
  if not private.student_exists(new.student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  new.school_id := private.student_school_id(new.student_id);
  return new;
end;
$$;
revoke all on function private.set_school_from_student() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.family_links (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  relationship text not null default 'parent' check (relationship in ('parent', 'guardian', 'other')),
  can_sign boolean not null default true,
  status text not null default 'active' check (status in ('active', 'revoked')),
  invite_id uuid,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (student_id, user_id)
);
create index if not exists family_links_user_idx on public.family_links (user_id) where status = 'active';
create index if not exists family_links_user_id_idx on public.family_links (user_id);
create index if not exists family_links_school_idx on public.family_links (school_id);
create index if not exists family_links_invite_idx on public.family_links (invite_id);

create table if not exists public.family_invites (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  code_hash text not null unique,          -- sha256 of the normalised code; the code itself is never stored
  code_hint text not null,                 -- last 2 characters, for "LL-····-M2" display
  relationship text not null default 'parent' check (relationship in ('parent', 'guardian', 'other')),
  max_uses int not null default 2 check (max_uses between 1 and 5),
  uses int not null default 0 check (uses >= 0),
  sent_to_email text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  revoked_at timestamptz
);
create index if not exists family_invites_student_idx on public.family_invites (student_id);
create index if not exists family_invites_school_idx on public.family_invites (school_id);
create index if not exists family_invites_created_by_idx on public.family_invites (created_by);

alter table public.family_links
  drop constraint if exists family_links_invite_id_fkey,
  add constraint family_links_invite_id_fkey foreign key (invite_id) references public.family_invites (id) on delete set null;

-- Failed/successful code attempts, for rate limiting (10 bad tries per hour).
create table if not exists private.code_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  kind text not null check (kind in ('family_invite', 'student_join', 'school_link')),
  ok boolean not null,
  at timestamptz not null default now()
);
create index if not exists code_attempts_user_at_idx on private.code_attempts (user_id, at desc);
alter table private.code_attempts enable row level security;
alter table private.code_attempts force row level security;
revoke all on table private.code_attempts from public, anon, authenticated;

create table if not exists public.supervisors (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,   -- set when the supervisor has a family account
  name text not null check (char_length(trim(name)) between 1 and 80),
  relationship text not null default 'parent'
    check (relationship in ('parent', 'guardian', 'instructor', 'other')),
  can_sign boolean not null default true,
  meets_requirements boolean not null default false,             -- attested: 21+, licensed 1+ year (state-dependent)
  active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists supervisors_student_idx on public.supervisors (student_id);
create index if not exists supervisors_school_idx on public.supervisors (school_id);
create index if not exists supervisors_user_idx on public.supervisors (user_id);
create index if not exists supervisors_created_by_idx on public.supervisors (created_by);
create unique index if not exists supervisors_one_per_account_idx
  on public.supervisors (student_id, user_id) where user_id is not null;

drop trigger if exists family_links_school on public.family_links;
create trigger family_links_school before insert or update on public.family_links
  for each row execute function private.set_school_from_student();
drop trigger if exists family_invites_school on public.family_invites;
create trigger family_invites_school before insert or update on public.family_invites
  for each row execute function private.set_school_from_student();
drop trigger if exists supervisors_school on public.supervisors;
create trigger supervisors_school before insert or update on public.supervisors
  for each row execute function private.set_school_from_student();
drop trigger if exists supervisors_touch on public.supervisors;
create trigger supervisors_touch before update on public.supervisors
  for each row execute function private.touch_updated_at();
drop trigger if exists family_links_audit on public.family_links;
create trigger family_links_audit after insert or update or delete on public.family_links
  for each row execute function private.audit_row();

-- ---------------------------------------------------------------------------
-- Visibility helpers (SECURITY DEFINER, fixed search_path, private schema)
-- ---------------------------------------------------------------------------
create or replace function private.own_student_ids()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select id from public.students where user_id = (select auth.uid());
$$;

create or replace function private.family_student_ids()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select student_id from public.family_links
  where user_id = (select auth.uid()) and status = 'active';
$$;

-- Everyone a person may see: themselves as a student, linked students (family),
-- every student of a school where they are desk staff, and students assigned
-- to them as instructor. Use as: student_id in (select private.visible_student_ids())
create or replace function private.visible_student_ids()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select id from public.students where user_id = (select auth.uid())
  union
  select student_id from public.family_links where user_id = (select auth.uid()) and status = 'active'
  union
  select s.id from public.students s
   where s.school_id in (
     select m.school_id from public.school_members m
      where m.user_id = (select auth.uid())
        and m.role in ('owner', 'admin', 'front_desk')
        and (m.role in ('owner', 'admin') or coalesce((m.access ->> 'students')::boolean, true)))
  union
  select s.id from public.students s
    join public.school_members m on m.school_id = s.school_id and m.user_id = (select auth.uid())
   where s.instructor_id = (select auth.uid());
$$;

-- Schools of the students I can see as student/family (for school name/phone in the app).
create or replace function private.linked_school_ids()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select s.school_id from public.students s
   where s.school_id is not null
     and (s.user_id = (select auth.uid())
          or s.id in (select student_id from public.family_links
                       where user_id = (select auth.uid()) and status = 'active'));
$$;

create or replace function private.can_view_student(p_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select p_student_id in (select private.visible_student_ids());
$$;

-- Student themself, an active family member, or desk staff of the student's school.
create or replace function private.can_act_for_student(p_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.students s where s.id = p_student_id and s.user_id = (select auth.uid()))
      or exists (select 1 from public.family_links f where f.student_id = p_student_id
                  and f.user_id = (select auth.uid()) and f.status = 'active')
      or exists (select 1 from public.students s where s.id = p_student_id
                  and s.school_id in (select private.desk_school_ids()));
$$;

revoke all on function private.own_student_ids() from public, anon;
revoke all on function private.family_student_ids() from public, anon;
revoke all on function private.visible_student_ids() from public, anon;
revoke all on function private.linked_school_ids() from public, anon;
revoke all on function private.can_view_student(uuid) from public, anon;
revoke all on function private.can_act_for_student(uuid) from public, anon;
grant execute on function private.own_student_ids() to authenticated;
grant execute on function private.family_student_ids() to authenticated;
grant execute on function private.visible_student_ids() to authenticated;
grant execute on function private.linked_school_ids() to authenticated;
grant execute on function private.can_view_student(uuid) to authenticated;
grant execute on function private.can_act_for_student(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.family_links enable row level security;
alter table public.family_links force row level security;
alter table public.family_invites enable row level security;
alter table public.family_invites force row level security;
alter table public.supervisors enable row level security;
alter table public.supervisors force row level security;

-- New, additive policies on the live tables so students/families can read their own rows.
drop policy if exists students_select_self_family on public.students;
create policy students_select_self_family on public.students
  for select to authenticated
  using (id in (select private.own_student_ids()) or id in (select private.family_student_ids()));

drop policy if exists schools_select_student_family on public.schools;
create policy schools_select_student_family on public.schools
  for select to authenticated
  using (id in (select private.linked_school_ids()));

drop policy if exists family_links_select on public.family_links;
create policy family_links_select on public.family_links
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or student_id in (select private.own_student_ids())
    or school_id in (select private.desk_school_ids())
  );

drop policy if exists family_invites_select on public.family_invites;
create policy family_invites_select on public.family_invites
  for select to authenticated
  using (
    created_by = (select auth.uid())
    or student_id in (select private.own_student_ids())
    or school_id in (select private.desk_school_ids())
  );

drop policy if exists supervisors_select on public.supervisors;
create policy supervisors_select on public.supervisors
  for select to authenticated
  using (student_id in (select private.visible_student_ids()));

drop policy if exists supervisors_insert on public.supervisors;
create policy supervisors_insert on public.supervisors
  for insert to authenticated
  with check (private.can_act_for_student(student_id) and not (select private.is_anonymous()));

drop policy if exists supervisors_update on public.supervisors;
create policy supervisors_update on public.supervisors
  for update to authenticated
  using (private.can_act_for_student(student_id))
  with check (private.can_act_for_student(student_id));

revoke all on table public.family_links from public, anon, authenticated;
revoke all on table public.family_invites from public, anon, authenticated;
revoke all on table public.supervisors from public, anon, authenticated;
grant select on table public.family_links to authenticated;
grant select on table public.family_invites to authenticated;
grant select, insert, update on table public.supervisors to authenticated;
grant select, insert, update, delete on table public.family_links, public.family_invites, public.supervisors to service_role;

-- ---------------------------------------------------------------------------
-- Codes
-- ---------------------------------------------------------------------------
-- "ll-7q4k m2" -> "7Q4KM2"
create or replace function private.normalize_code(p_code text)
returns text
language sql immutable set search_path = ''
as $$
  select case
    when char_length(c) = 8 and left(c, 2) = 'LL' then substr(c, 3)
    else c end
  from (select regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g') as c) x;
$$;

create or replace function private.random_code(p_len int)
returns text
language plpgsql volatile set search_path = ''
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';   -- no 0/O, 1/I/L
  b bytea := extensions.gen_random_bytes(p_len);
  out text := '';
  i int;
begin
  for i in 0 .. p_len - 1 loop
    out := out || substr(alphabet, (get_byte(b, i) % 31) + 1, 1);
  end loop;
  return out;
end;
$$;

create or replace function private.code_hash(p_code text)
returns text
language sql immutable set search_path = ''
as $$
  select encode(extensions.digest(private.normalize_code(p_code), 'sha256'), 'hex');
$$;

create or replace function private.too_many_attempts(p_kind text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select count(*) >= 10 from private.code_attempts
   where user_id = (select auth.uid()) and kind = p_kind and not ok
     and at > now() - interval '1 hour';
$$;
revoke all on function private.normalize_code(text) from public, anon;
revoke all on function private.random_code(int) from public, anon;
revoke all on function private.code_hash(text) from public, anon;
revoke all on function private.too_many_attempts(text) from public, anon;
grant execute on function private.normalize_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- RPCs (the app API)
-- ---------------------------------------------------------------------------

-- Student, family member or desk staff creates a code a parent types into the app.
-- Returns the code ONCE; only its hash is stored.
create or replace function public.create_family_invite(
  p_student_id uuid,
  p_relationship text default 'parent',
  p_max_uses int default 2,
  p_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  raw text;
  code text;
  inv public.family_invites;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if private.is_anonymous() then raise exception 'Create an account first' using errcode = '42501'; end if;
  if not private.can_act_for_student(p_student_id) then
    raise exception 'Not allowed for this student' using errcode = '42501';
  end if;
  if (select count(*) from public.family_invites
       where student_id = p_student_id and created_at > now() - interval '1 day') >= 10 then
    raise exception 'Too many invites today' using errcode = '54000';
  end if;

  loop
    raw := private.random_code(6);
    exit when not exists (select 1 from public.family_invites where code_hash = private.code_hash(raw));
  end loop;
  code := 'LL-' || substr(raw, 1, 4) || '-' || substr(raw, 5, 2);

  insert into public.family_invites (student_id, code_hash, code_hint, relationship, max_uses, sent_to_email, created_by)
  values (p_student_id, private.code_hash(raw), substr(raw, 5, 2),
          coalesce(nullif(lower(trim(p_relationship)), ''), 'parent'), coalesce(p_max_uses, 2),
          nullif(lower(trim(coalesce(p_email, ''))), ''), uid)
  returning * into inv;

  return jsonb_build_object('invite_id', inv.id, 'code', code, 'expires_at', inv.expires_at, 'max_uses', inv.max_uses);
end;
$$;

-- A parent/guardian types the code. Never raises for a bad code (so the failed
-- attempt is recorded for rate limiting); returns {status: ok|invalid|expired|rate_limited|...}.
create or replace function public.redeem_family_invite(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  inv public.family_invites;
  link_id uuid;
  v_name text;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if private.is_anonymous() then return jsonb_build_object('status', 'needs_account'); end if;
  if private.too_many_attempts('family_invite') then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  select * into inv from public.family_invites
   where code_hash = private.code_hash(p_code)
   for update;

  if inv.id is null or inv.revoked_at is not null then
    insert into private.code_attempts (user_id, kind, ok) values (uid, 'family_invite', false);
    return jsonb_build_object('status', 'invalid');
  end if;
  if inv.expires_at <= now() or inv.uses >= inv.max_uses then
    insert into private.code_attempts (user_id, kind, ok) values (uid, 'family_invite', false);
    return jsonb_build_object('status', 'expired');
  end if;
  if exists (select 1 from public.students where id = inv.student_id and user_id = uid) then
    return jsonb_build_object('status', 'own_code');
  end if;

  insert into public.family_links (student_id, user_id, relationship, invite_id)
  values (inv.student_id, uid, inv.relationship, inv.id)
  on conflict (student_id, user_id) do update
    set status = 'active', revoked_at = null, invite_id = excluded.invite_id
  returning id into link_id;

  update public.family_invites set uses = uses + 1 where id = inv.id;
  insert into private.code_attempts (user_id, kind, ok) values (uid, 'family_invite', true);

  update public.profiles set account_type = 'family' where id = uid and account_type = 'unset';

  -- Make the parent pickable as a supervisor on the student's phone.
  select nullif(trim(full_name), '') into v_name from public.profiles where id = uid;
  insert into public.supervisors (student_id, user_id, name, relationship, created_by)
  values (inv.student_id, uid,
          coalesce(v_name, 'Family member'), inv.relationship, uid)
  on conflict (student_id, user_id) where user_id is not null do update set active = true;

  return jsonb_build_object('status', 'ok', 'student_id', inv.student_id, 'link_id', link_id);
end;
$$;

create or replace function public.revoke_family_invite(p_invite_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_student uuid;
begin
  select student_id into v_student from public.family_invites where id = p_invite_id;
  if v_student is null or not private.can_act_for_student(v_student) then
    raise exception 'Invite not found' using errcode = 'P0002';
  end if;
  update public.family_invites set revoked_at = coalesce(revoked_at, now()) where id = p_invite_id;
end;
$$;

-- The student, the family member themself, or desk staff can remove a link.
create or replace function public.revoke_family_link(p_link_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  l public.family_links;
begin
  select * into l from public.family_links where id = p_link_id;
  if l.id is null then raise exception 'Link not found' using errcode = 'P0002'; end if;
  if not (l.user_id = (select auth.uid())
          or l.student_id in (select private.own_student_ids())
          or l.school_id in (select private.desk_school_ids())) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  update public.family_links set status = 'revoked', revoked_at = now() where id = p_link_id;
  update public.supervisors set active = false where student_id = l.student_id and user_id = l.user_id;
end;
$$;

-- A student signs in on their phone and types the 6-character code the school gave them
-- (students.join_code, already in the live schema). Links the account to the roster row.
create or replace function public.claim_student_profile(p_join_code text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  s public.students;
  own public.students;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if private.is_anonymous() then return jsonb_build_object('status', 'needs_account'); end if;
  if private.too_many_attempts('student_join') then return jsonb_build_object('status', 'rate_limited'); end if;

  select * into s from public.students
   where join_code = upper(regexp_replace(coalesce(p_join_code, ''), '[^A-Za-z0-9]', '', 'g'))
   for update;

  if s.id is null or (s.user_id is not null and s.user_id <> uid) then
    insert into private.code_attempts (user_id, kind, ok) values (uid, 'student_join', false);
    return jsonb_build_object('status', 'invalid');
  end if;
  if s.user_id = uid then
    return jsonb_build_object('status', 'ok', 'student_id', s.id, 'school_id', s.school_id);
  end if;

  -- Already practising independently? Don't create a second profile: the app asks
  -- "Bring your drive history to <school>?" and calls join_school_with_code().
  if s.school_id is not null then
    select * into own from public.students
     where user_id = uid and school_id is null order by created_at limit 1;
    if own.id is not null then
      return jsonb_build_object('status', 'has_independent_profile', 'student_id', own.id,
        'school_name', (select name from public.schools where id = s.school_id));
    end if;
  end if;

  update public.students set user_id = uid where id = s.id;
  update public.profiles set account_type = 'student' where id = uid and account_type = 'unset';
  insert into private.code_attempts (user_id, kind, ok) values (uid, 'student_join', true);
  return jsonb_build_object('status', 'ok', 'student_id', s.id, 'school_id', s.school_id);
end;
$$;

create or replace function public.set_account_type(p_type text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if (select auth.uid()) is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if p_type not in ('student', 'family', 'staff') then raise exception 'Unknown account type'; end if;
  update public.profiles set account_type = p_type where id = (select auth.uid());
end;
$$;

-- Students I can see as a student or family member (for the family switcher).
create or replace function public.my_students()
returns table (student_id uuid, first_name text, last_name text, school_id uuid, school_name text,
               state_code text, relation text, can_sign boolean)
language sql stable security invoker set search_path = ''
as $$
  -- school_id / school_name are NULL for independent students (practising with family).
  select s.id, s.first_name, s.last_name, s.school_id, sc.name, s.state_code, 'self', false
    from public.students s left join public.schools sc on sc.id = s.school_id
   where s.user_id = (select auth.uid())
  union all
  select s.id, s.first_name, s.last_name, s.school_id, sc.name, s.state_code, f.relationship, f.can_sign
    from public.family_links f
    join public.students s on s.id = f.student_id
    left join public.schools sc on sc.id = s.school_id
   where f.user_id = (select auth.uid()) and f.status = 'active'
  order by 2, 3;
$$;

revoke all on function public.create_family_invite(uuid, text, int, text) from public, anon;
revoke all on function public.redeem_family_invite(text) from public, anon;
revoke all on function public.revoke_family_invite(uuid) from public, anon;
revoke all on function public.revoke_family_link(uuid) from public, anon;
revoke all on function public.claim_student_profile(text) from public, anon;
revoke all on function public.set_account_type(text) from public, anon;
revoke all on function public.my_students() from public, anon;
grant execute on function public.create_family_invite(uuid, text, int, text) to authenticated;
grant execute on function public.redeem_family_invite(text) to authenticated;
grant execute on function public.revoke_family_invite(uuid) to authenticated;
grant execute on function public.revoke_family_link(uuid) to authenticated;
grant execute on function public.claim_student_profile(text) to authenticated;
grant execute on function public.set_account_type(text) to authenticated;
grant execute on function public.my_students() to authenticated;
