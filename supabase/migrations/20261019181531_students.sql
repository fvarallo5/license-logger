-- Roster: students, contacts, packages, checklist.
-- Instructors see assigned kids only. Desk (owner/admin/front_desk) sees the school.

create or replace function private.can_manage_students(p_school_id uuid)
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
      and role in ('owner', 'admin', 'front_desk')
      and (
        role in ('owner', 'admin')
        or coalesce((access ->> 'students')::boolean, true)
      )
  );
$$;

create or replace function private.new_join_code()
returns text
language plpgsql
set search_path = ''
as $$
declare
  code text;
begin
  loop
    code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (
      select 1 from public.students where join_code = code
    );
  end loop;
  return code;
end;
$$;

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  first_name text not null check (char_length(trim(first_name)) between 1 and 80),
  last_name text not null default '',
  birthday date,
  state_code text not null default 'TX' check (char_length(state_code) = 2),
  phone text not null default '',
  pickup_address text not null default '',
  notes text not null default '',
  seat text not null default 'active'
    check (seat in ('active', 'waitlist', 'graduated', 'inactive')),
  permit_on date,
  hour_goal numeric(6, 1) not null default 50,
  night_goal numeric(6, 1) not null default 10,
  practice_hours numeric(6, 1) not null default 0,
  night_hours numeric(6, 1) not null default 0,
  school_hours numeric(6, 1) not null default 0,
  balance numeric(10, 2) not null default 0,
  instructor_id uuid references auth.users (id) on delete set null,
  user_id uuid references auth.users (id) on delete set null,
  join_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists students_school_id_idx on public.students (school_id);
create index if not exists students_school_name_idx
  on public.students (school_id, last_name, first_name);
create index if not exists students_instructor_id_idx on public.students (instructor_id);
create index if not exists students_user_id_idx on public.students (user_id);

create table if not exists public.student_contacts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  name text not null default '',
  email text not null default '',
  phone text not null default '',
  kind text not null default 'guardian' check (kind in ('guardian', 'self', 'other')),
  user_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists student_contacts_student_id_idx
  on public.student_contacts (student_id);
create index if not exists student_contacts_school_id_idx
  on public.student_contacts (school_id);

create table if not exists public.package_catalog (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  name text not null,
  hours numeric(6, 1) not null check (hours > 0),
  price numeric(10, 2) not null default 0,
  kind text not null default 'btw' check (kind in ('btw', 'observation', 'road_test', 'other')),
  active boolean not null default true
);

create index if not exists package_catalog_school_id_idx
  on public.package_catalog (school_id);

create table if not exists public.student_packages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  catalog_id uuid references public.package_catalog (id) on delete set null,
  hours_total numeric(6, 1) not null,
  hours_left numeric(6, 1) not null,
  status text not null default 'active'
    check (status in ('active', 'exhausted', 'expired', 'void')),
  created_at timestamptz not null default now()
);

create index if not exists student_packages_student_id_idx
  on public.student_packages (student_id);
create index if not exists student_packages_school_id_idx
  on public.student_packages (school_id);
create unique index if not exists student_packages_one_active_idx
  on public.student_packages (student_id)
  where status = 'active';

create table if not exists public.student_checklist (
  student_id uuid not null references public.students (id) on delete cascade,
  item_key text not null,
  label text not null,
  done boolean not null default false,
  source text not null default 'school' check (source in ('school', 'phone', 'derived')),
  primary key (student_id, item_key)
);

create or replace function private.seed_package_catalog(p_school_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.package_catalog (school_id, name, hours, kind)
  select p_school_id, v.name, v.hours, 'btw'
  from (values
    ('6-hour BTW', 6.0),
    ('10-hour BTW', 10.0),
    ('14-hour BTW', 14.0)
  ) as v(name, hours)
  where not exists (
    select 1 from public.package_catalog c
    where c.school_id = p_school_id and c.hours = v.hours and c.kind = 'btw'
  );
end;
$$;

insert into public.package_catalog (school_id, name, hours, kind)
select s.id, v.name, v.hours, 'btw'
from public.schools s
cross join (values
  ('6-hour BTW', 6.0),
  ('10-hour BTW', 10.0),
  ('14-hour BTW', 14.0)
) as v(name, hours)
where not exists (
  select 1 from public.package_catalog c
  where c.school_id = s.id and c.hours = v.hours
);

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
  return sid;
end;
$$;

revoke all on function private.can_manage_students(uuid) from public, anon;
revoke all on function private.new_join_code() from public, anon;
revoke all on function private.seed_package_catalog(uuid) from public, anon;
grant execute on function private.can_manage_students(uuid) to authenticated;
grant execute on function public.create_school(text, text) to authenticated;

alter table public.students enable row level security;
alter table public.student_contacts enable row level security;
alter table public.package_catalog enable row level security;
alter table public.student_packages enable row level security;
alter table public.student_checklist enable row level security;
alter table public.students force row level security;
alter table public.student_contacts force row level security;
alter table public.package_catalog force row level security;
alter table public.student_packages force row level security;
alter table public.student_checklist force row level security;

create policy students_select
  on public.students for select
  to authenticated
  using (
    private.can_manage_students(school_id)
    or (
      instructor_id = (select auth.uid())
      and school_id in (select private.user_school_ids())
    )
  );

create policy students_insert
  on public.students for insert
  to authenticated
  with check (private.can_manage_students(school_id));

create policy students_update
  on public.students for update
  to authenticated
  using (private.can_manage_students(school_id))
  with check (private.can_manage_students(school_id));

create policy students_delete
  on public.students for delete
  to authenticated
  using (private.can_manage_students(school_id));

create policy student_contacts_select
  on public.student_contacts for select
  to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and (
          private.can_manage_students(s.school_id)
          or (
            s.instructor_id = (select auth.uid())
            and s.school_id in (select private.user_school_ids())
          )
        )
    )
  );

create policy student_contacts_write
  on public.student_contacts for insert
  to authenticated
  with check (private.can_manage_students(school_id));

create policy student_contacts_update
  on public.student_contacts for update
  to authenticated
  using (private.can_manage_students(school_id))
  with check (private.can_manage_students(school_id));

create policy student_contacts_delete
  on public.student_contacts for delete
  to authenticated
  using (private.can_manage_students(school_id));

create policy package_catalog_select
  on public.package_catalog for select
  to authenticated
  using (school_id in (select private.user_school_ids()));

create policy package_catalog_insert
  on public.package_catalog for insert
  to authenticated
  with check (private.can_manage_students(school_id));

create policy package_catalog_update
  on public.package_catalog for update
  to authenticated
  using (private.can_manage_students(school_id))
  with check (private.can_manage_students(school_id));

create policy package_catalog_delete
  on public.package_catalog for delete
  to authenticated
  using (private.can_manage_students(school_id));

create policy student_packages_select
  on public.student_packages for select
  to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and (
          private.can_manage_students(s.school_id)
          or (
            s.instructor_id = (select auth.uid())
            and s.school_id in (select private.user_school_ids())
          )
        )
    )
  );

create policy student_packages_write
  on public.student_packages for insert
  to authenticated
  with check (private.can_manage_students(school_id));

create policy student_packages_update
  on public.student_packages for update
  to authenticated
  using (private.can_manage_students(school_id))
  with check (private.can_manage_students(school_id));

create policy student_checklist_select
  on public.student_checklist for select
  to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and (
          private.can_manage_students(s.school_id)
          or (
            s.instructor_id = (select auth.uid())
            and s.school_id in (select private.user_school_ids())
          )
        )
    )
  );

create policy student_checklist_write
  on public.student_checklist for insert
  to authenticated
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and private.can_manage_students(s.school_id)
    )
  );

create policy student_checklist_update
  on public.student_checklist for update
  to authenticated
  using (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and private.can_manage_students(s.school_id)
    )
  )
  with check (
    exists (
      select 1 from public.students s
      where s.id = student_id
        and private.can_manage_students(s.school_id)
    )
  );

revoke all on table public.students from public, anon;
revoke all on table public.student_contacts from public, anon;
revoke all on table public.package_catalog from public, anon;
revoke all on table public.student_packages from public, anon;
revoke all on table public.student_checklist from public, anon;

grant select, insert, update, delete on table public.students to authenticated;
grant select, insert, update, delete on table public.student_contacts to authenticated;
grant select, insert, update, delete on table public.package_catalog to authenticated;
grant select, insert, update on table public.student_packages to authenticated;
grant select, insert, update, delete on table public.student_checklist to authenticated;

create or replace function public.add_student(
  p_school_id uuid,
  p_first_name text,
  p_last_name text default '',
  p_birthday date default null,
  p_parent_name text default '',
  p_parent_email text default '',
  p_instructor_id uuid default null,
  p_package_hours numeric default 10
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  sid uuid;
  pkg_id uuid;
  v_hours numeric := coalesce(p_package_hours, 10);
  age_years int;
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  if not private.can_manage_students(p_school_id) then
    raise exception 'Not allowed to add students';
  end if;
  if char_length(trim(p_first_name)) < 1 then
    raise exception 'Student name is required';
  end if;
  if p_instructor_id is not null and not exists (
    select 1 from public.school_members
    where school_id = p_school_id and user_id = p_instructor_id
  ) then
    raise exception 'Instructor is not on this school';
  end if;

  insert into public.students (
    school_id, first_name, last_name, birthday, instructor_id, join_code
  ) values (
    p_school_id,
    trim(p_first_name),
    trim(coalesce(p_last_name, '')),
    p_birthday,
    p_instructor_id,
    private.new_join_code()
  )
  returning id into sid;

  if trim(coalesce(p_parent_name, '')) <> '' or trim(coalesce(p_parent_email, '')) <> '' then
    insert into public.student_contacts (school_id, student_id, name, email, kind)
    values (
      p_school_id,
      sid,
      trim(coalesce(p_parent_name, '')),
      lower(trim(coalesce(p_parent_email, ''))),
      'guardian'
    );
  end if;

  select id into pkg_id
  from public.package_catalog
  where school_id = p_school_id and active and public.package_catalog.hours = v_hours
  order by name
  limit 1;

  insert into public.student_packages (
    school_id, student_id, catalog_id, hours_total, hours_left, status
  ) values (
    p_school_id, sid, pkg_id, v_hours, v_hours, 'active'
  );

  age_years := case
    when p_birthday is null then null
    else (extract(year from age(current_date, p_birthday)))::int
  end;

  insert into public.student_checklist (student_id, item_key, label, done, source)
  values
    (sid, 'age', 'Age 16', coalesce(age_years, 0) >= 16, 'derived'),
    (sid, 'hold', 'Permit hold', false, 'derived'),
    (sid, 'practice', 'Practice hours', false, 'derived'),
    (sid, 'night', 'Night hours', false, 'derived'),
    (sid, 'ed', 'Driver ed', false, 'school'),
    (sid, 'written', 'Written test', false, 'school'),
    (sid, 'docs', 'Documents', false, 'school');

  return sid;
end;
$$;

revoke all on function public.add_student(uuid, text, text, date, text, text, uuid, numeric)
  from public, anon;
grant execute on function public.add_student(uuid, text, text, date, text, text, uuid, numeric)
  to authenticated;
