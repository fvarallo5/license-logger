-- LicenseLogger 013: independent students (parent-taught / permit drivers with no school).
--
-- Approach: students.school_id becomes NULLABLE. NULL = independent.
--   * Every school-side rule already reads "school_id in (my schools)", and NULL never
--     matches, so staff can't see independent students without new policy code.
--   * Students and families already reach their own rows through own/family helpers
--     (user_id / family_links), which don't depend on a school.
--   * No fake "personal schools": nothing new for the dashboard, billing or QuickBooks
--     to filter out, and no student ever gets owner/staff powers.
-- This is the only change to a live object, and it only relaxes a constraint: it
-- drops nothing, renames nothing, and changes no existing row.
--
-- Joining a school later (history preserved: it's the SAME student row):
--   a) The student/family types the student code the school gave them (roster join code)
--      -> join_school_with_code() merges the school's roster entry into the existing profile.
--   b) The school types the student's own LicenseLogger code -> request_student_link();
--      the student or family accepts in the app -> respond_school_request().
-- Leaving: leave_school() (student/family) or release_student() (school).
-- A school keeps what it created (lessons, packages, invoices) and the drives that were
-- signed while the student was enrolled. It loses access to everything else.

alter table public.students alter column school_id drop not null;
comment on column public.students.school_id is 'NULL = independent student (no driving school).';

-- ---------------------------------------------------------------------------
-- Enrollment history (who was at which school, when). Written only by triggers.
-- ---------------------------------------------------------------------------
create table if not exists public.school_enrollments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  joined_at timestamptz not null default now(),
  joined_via text not null default 'school_created'
    check (joined_via in ('school_created', 'school_code', 'school_request', 'school_moved')),
  left_at timestamptz,
  left_reason text check (left_reason in ('student_left', 'school_released', 'moved')),
  first_name text not null default '',       -- name snapshot, so a school can still label a former student
  last_name text not null default ''
);
create unique index if not exists school_enrollments_one_open_idx on public.school_enrollments (student_id) where left_at is null;
create index if not exists school_enrollments_student_idx on public.school_enrollments (student_id);
create index if not exists school_enrollments_school_idx on public.school_enrollments (school_id, left_at desc);

insert into public.school_enrollments (student_id, school_id, joined_at, joined_via, first_name, last_name)
select s.id, s.school_id, s.created_at, 'school_created', s.first_name, s.last_name
  from public.students s
 where s.school_id is not null
   and not exists (select 1 from public.school_enrollments e where e.student_id = s.id and e.left_at is null);

alter table public.school_enrollments enable row level security;
alter table public.school_enrollments force row level security;
drop policy if exists school_enrollments_select on public.school_enrollments;
create policy school_enrollments_select on public.school_enrollments
  for select to authenticated
  using (school_id in (select private.desk_school_ids())
         or student_id in (select private.own_student_ids())
         or student_id in (select private.family_student_ids()));
revoke all on table public.school_enrollments from public, anon, authenticated;
grant select on table public.school_enrollments to authenticated;
grant select, insert, update, delete on table public.school_enrollments to service_role;

-- ---------------------------------------------------------------------------
-- School -> student link requests (the student/family must accept).
-- ---------------------------------------------------------------------------
create table if not exists public.school_link_requests (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  requested_by uuid references auth.users (id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '14 days',
  responded_at timestamptz,
  responded_by uuid references auth.users (id) on delete set null
);
create unique index if not exists school_link_requests_one_pending_idx
  on public.school_link_requests (school_id, student_id) where status = 'pending';
create index if not exists school_link_requests_student_idx on public.school_link_requests (student_id) where status = 'pending';
create index if not exists school_link_requests_student_id_idx on public.school_link_requests (student_id);
create index if not exists school_link_requests_school_idx on public.school_link_requests (school_id, created_at desc);
create index if not exists school_link_requests_requested_by_idx on public.school_link_requests (requested_by);
create index if not exists school_link_requests_responded_by_idx on public.school_link_requests (responded_by);

alter table public.school_link_requests enable row level security;
alter table public.school_link_requests force row level security;
-- Staff see their own school's requests (student id + status only: no student data until accepted).
drop policy if exists school_link_requests_select on public.school_link_requests;
create policy school_link_requests_select on public.school_link_requests
  for select to authenticated
  using (school_id in (select private.desk_school_ids())
         or student_id in (select private.own_student_ids())
         or student_id in (select private.family_student_ids()));
revoke all on table public.school_link_requests from public, anon, authenticated;
grant select on table public.school_link_requests to authenticated;
grant select, insert, update, delete on table public.school_link_requests to service_role;

-- ---------------------------------------------------------------------------
-- Triggers on the live students table (additive): keep everything consistent
-- whenever a student's school changes, however it happens.
-- ---------------------------------------------------------------------------
create or replace function private.students_before_school_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.school_id is distinct from old.school_id and new.instructor_id is not null
     and (new.school_id is null or not exists (
           select 1 from public.school_members m where m.school_id = new.school_id and m.user_id = new.instructor_id)) then
    new.instructor_id := null;     -- an instructor of the old school isn't theirs any more
  end if;
  return new;
end;
$$;

create or replace function private.students_after_school_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_via text := coalesce(nullif(current_setting('ll.join_via', true), ''), case when tg_op = 'INSERT' then 'school_created' else 'school_moved' end);
  v_reason text := coalesce(nullif(current_setting('ll.leave_reason', true), ''), 'moved');
begin
  if tg_op = 'UPDATE' then
    if new.school_id is not distinct from old.school_id then return null; end if;
    update public.school_enrollments
       set left_at = now(), left_reason = v_reason, first_name = new.first_name, last_name = new.last_name
     where student_id = new.id and left_at is null;
    -- The old school's future lessons for this student are cancelled (history stays with the school).
    if old.school_id is not null then
      update public.lessons set status = 'cancelled', cancelled_at = now()
       where student_id = new.id and school_id = old.school_id and status = 'booked' and starts_at > now();
    end if;
    -- Student-owned rows follow the student (their triggers re-read the student's school).
    update public.supervisors   set school_id = new.school_id where student_id = new.id;
    update public.family_links  set school_id = new.school_id where student_id = new.id;
    update public.family_invites set school_id = new.school_id where student_id = new.id;
    -- Unsigned practice drives follow too; signed drives keep their stamp (the school's record).
    update public.drives set school_id = new.school_id
     where student_id = new.id and kind = 'practice' and locked_at is null and status not in ('signed', 'voided');
    update public.school_link_requests set status = 'cancelled', responded_at = now()
     where student_id = new.id and status = 'pending' and school_id is not distinct from new.school_id;
  end if;
  if new.school_id is not null then
    insert into public.school_enrollments (student_id, school_id, joined_via, first_name, last_name)
    values (new.id, new.school_id, v_via, new.first_name, new.last_name);
  end if;
  return null;
end;
$$;
revoke all on function private.students_before_school_change() from public, anon, authenticated;
revoke all on function private.students_after_school_change() from public, anon, authenticated;

drop trigger if exists students_before_school_change on public.students;
create trigger students_before_school_change before update of school_id on public.students
  for each row execute function private.students_before_school_change();
drop trigger if exists students_after_school_change on public.students;
create trigger students_after_school_change after insert or update of school_id on public.students
  for each row execute function private.students_after_school_change();

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- The student themself or an active family member (NOT school staff): the people who consent.
create or replace function private.is_student_or_family(p_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.students s where s.id = p_student_id and s.user_id = (select auth.uid()))
      or exists (select 1 from public.family_links f where f.student_id = p_student_id
                  and f.user_id = (select auth.uid()) and f.status = 'active');
$$;
revoke all on function private.is_student_or_family(uuid) from public, anon;
grant execute on function private.is_student_or_family(uuid) to authenticated;

create or replace function private.has_app_owner(p_student_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.students s where s.id = p_student_id and s.user_id is not null)
      or exists (select 1 from public.family_links f where f.student_id = p_student_id and f.status = 'active');
$$;
revoke all on function private.has_app_owner(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RPCs: independent profile
-- ---------------------------------------------------------------------------
-- "No, I'm practising with family". p_for = 'self' (the student's own account) or
-- 'family' (a parent sets it up; the teen can claim it later with the returned join_code).
create or replace function public.create_independent_student(
  p_first_name text,
  p_last_name text default '',
  p_birthday date default null,
  p_state_code text default 'TX',
  p_for text default 'self',
  p_relationship text default 'parent'
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  v_state text := upper(trim(coalesce(p_state_code, '')));
  s public.students;
  v_name text;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if private.is_anonymous() then raise exception 'Create an account first' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_first_name, ''))) < 1 then raise exception 'First name is required' using errcode = '22023'; end if;
  if v_state !~ '^[A-Z]{2}$' then raise exception 'Pick a state' using errcode = '22023'; end if;
  if p_for not in ('self', 'family') then raise exception 'Unknown option' using errcode = '22023'; end if;

  if p_for = 'self' then
    select * into s from public.students where user_id = uid and school_id is null order by created_at limit 1;
    if s.id is not null then
      return jsonb_build_object('status', 'exists', 'student_id', s.id, 'join_code', s.join_code);
    end if;
    insert into public.students (school_id, first_name, last_name, birthday, state_code, user_id, join_code)
    values (null, trim(p_first_name), trim(coalesce(p_last_name, '')), p_birthday, v_state, uid, private.new_join_code())
    returning * into s;
    update public.profiles set account_type = 'student' where id = uid and account_type = 'unset';
  else
    if (select count(*) from public.family_links where user_id = uid and status = 'active') >= 10 then
      raise exception 'Too many linked students' using errcode = '54000';
    end if;
    insert into public.students (school_id, first_name, last_name, birthday, state_code, user_id, join_code)
    values (null, trim(p_first_name), trim(coalesce(p_last_name, '')), p_birthday, v_state, null, private.new_join_code())
    returning * into s;
    insert into public.family_links (student_id, user_id, relationship, can_sign)
    values (s.id, uid, coalesce(nullif(lower(trim(p_relationship)), ''), 'parent'), true);
    select nullif(trim(full_name), '') into v_name from public.profiles where id = uid;
    insert into public.supervisors (student_id, user_id, name, relationship, created_by)
    values (s.id, uid, coalesce(v_name, 'Family member'), coalesce(nullif(lower(trim(p_relationship)), ''), 'parent'), uid);
    update public.profiles set account_type = 'family' where id = uid and account_type = 'unset';
  end if;
  return jsonb_build_object('status', 'ok', 'student_id', s.id, 'join_code', s.join_code);
end;
$$;

-- Independent students (and their family) edit their own profile. Once at a school,
-- the school manages the roster entry.
create or replace function public.update_my_student(
  p_student_id uuid,
  p_first_name text default null,
  p_last_name text default null,
  p_birthday date default null,
  p_state_code text default null,
  p_permit_on date default null
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  s public.students;
  v_state text := upper(trim(coalesce(p_state_code, '')));
begin
  if not private.is_student_or_family(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  select * into s from public.students where id = p_student_id for update;
  if s.school_id is not null then
    raise exception 'Your school manages this profile' using errcode = '42501';
  end if;
  if p_state_code is not null and v_state !~ '^[A-Z]{2}$' then raise exception 'Pick a state' using errcode = '22023'; end if;
  if p_first_name is not null and char_length(trim(p_first_name)) < 1 then
    raise exception 'First name is required' using errcode = '22023';
  end if;
  update public.students set
    first_name = coalesce(nullif(trim(p_first_name), ''), first_name),
    last_name  = coalesce(trim(p_last_name), last_name),
    birthday   = coalesce(p_birthday, birthday),
    permit_on  = coalesce(p_permit_on, permit_on),
    state_code = case when p_state_code is null then state_code else v_state end,
    rule_set_id = case when p_state_code is null or v_state = state_code then rule_set_id else null end,
    updated_at = now()
  where id = p_student_id;
  if p_state_code is not null then perform private.refresh_student_hours(p_student_id); end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPCs: joining a school
-- ---------------------------------------------------------------------------
-- (a) Student/family has the roster code the school gave them and already has an
--     independent profile: merge the school's (unclaimed, drive-less) roster entry INTO the
--     existing profile, then delete the roster entry. Drives, sign-offs and family links stay.
create or replace function public.join_school_with_code(p_student_id uuid, p_join_code text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  me public.students;
  ph public.students;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if not private.is_student_or_family(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  if private.too_many_attempts('student_join') then return jsonb_build_object('status', 'rate_limited'); end if;

  select * into me from public.students where id = p_student_id for update;
  select * into ph from public.students
   where join_code = upper(regexp_replace(coalesce(p_join_code, ''), '[^A-Za-z0-9]', '', 'g'))
   for update;

  if ph.id is null or ph.school_id is null or ph.user_id is not null or ph.id = me.id then
    insert into private.code_attempts (user_id, kind, ok) values (uid, 'student_join', false);
    return jsonb_build_object('status', 'invalid');
  end if;
  insert into private.code_attempts (user_id, kind, ok) values (uid, 'student_join', true);
  if me.school_id is not distinct from ph.school_id then
    return jsonb_build_object('status', 'already_linked', 'school_id', me.school_id);
  end if;
  if exists (select 1 from public.drives where student_id = ph.id) then
    -- The school already logged drives on its entry; a school-side link avoids splitting records.
    return jsonb_build_object('status', 'needs_school_link', 'your_code', me.join_code);
  end if;

  -- Move what the school prepared onto the student's existing profile.
  -- (Only one active package per student: a package left over from a previous school ends.)
  if exists (select 1 from public.student_packages where student_id = ph.id and status = 'active') then
    update public.student_packages set status = 'expired' where student_id = me.id and status = 'active';
  end if;
  update public.student_contacts  set student_id = me.id where student_id = ph.id;
  update public.student_packages  set student_id = me.id where student_id = ph.id;
  update public.student_checklist c set student_id = me.id
   where c.student_id = ph.id
     and not exists (select 1 from public.student_checklist x where x.student_id = me.id and x.item_key = c.item_key);
  update public.lessons           set student_id = me.id where student_id = ph.id;
  update public.billing_customers set student_id = me.id where student_id = ph.id;
  update public.invoices          set student_id = me.id where student_id = ph.id;
  update public.payments          set student_id = me.id where student_id = ph.id;
  update public.family_invites    set student_id = me.id where student_id = ph.id;
  update public.family_links f    set student_id = me.id
   where f.student_id = ph.id and not exists (select 1 from public.family_links x where x.student_id = me.id and x.user_id = f.user_id);
  update public.supervisors sp    set student_id = me.id
   where sp.student_id = ph.id
     and (sp.user_id is null or not exists (select 1 from public.supervisors x where x.student_id = me.id and x.user_id = sp.user_id));

  delete from public.students where id = ph.id;   -- the now-empty roster entry (cascades the leftovers)

  perform set_config('ll.join_via', 'school_code', true);
  update public.students set
    school_id = ph.school_id,
    instructor_id = ph.instructor_id,
    seat = ph.seat,
    permit_on = coalesce(me.permit_on, ph.permit_on),
    hour_goal = ph.hour_goal, night_goal = ph.night_goal,
    phone = case when me.phone = '' then ph.phone else me.phone end,
    pickup_address = case when me.pickup_address = '' then ph.pickup_address else me.pickup_address end,
    notes = ph.notes, balance = ph.balance,
    birthday = coalesce(me.birthday, ph.birthday),
    updated_at = now()
  where id = me.id;
  perform set_config('ll.join_via', '', true);

  return jsonb_build_object('status', 'ok', 'student_id', me.id, 'school_id', ph.school_id,
                            'school_name', (select name from public.schools where id = ph.school_id));
end;
$$;

-- (b) The school types the student's LicenseLogger code (shown in the app). Nothing is
--     shared until the student or family accepts. Answers never include student details.
create or replace function public.request_student_link(p_school_id uuid, p_student_code text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  s public.students;
  r public.school_link_requests;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if not private.can_manage_students(p_school_id) then
    raise exception 'Not allowed to add students' using errcode = '42501';
  end if;
  if private.too_many_attempts('school_link') then return jsonb_build_object('status', 'rate_limited'); end if;

  select * into s from public.students
   where join_code = upper(regexp_replace(coalesce(p_student_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if s.id is null or not private.has_app_owner(s.id) then
    insert into private.code_attempts (user_id, kind, ok) values (uid, 'school_link', false);
    return jsonb_build_object('status', 'invalid');
  end if;
  insert into private.code_attempts (user_id, kind, ok) values (uid, 'school_link', true);
  if s.school_id is not distinct from p_school_id then
    return jsonb_build_object('status', 'already_linked');
  end if;

  select * into r from public.school_link_requests
   where school_id = p_school_id and student_id = s.id and status = 'pending';
  if r.id is not null and r.expires_at > now() then
    return jsonb_build_object('status', 'requested', 'request_id', r.id, 'expires_at', r.expires_at);
  end if;
  update public.school_link_requests set status = 'cancelled', responded_at = now() where id = r.id;
  insert into public.school_link_requests (school_id, student_id, requested_by)
  values (p_school_id, s.id, uid) returning * into r;
  return jsonb_build_object('status', 'requested', 'request_id', r.id, 'expires_at', r.expires_at);
end;
$$;

create or replace function public.cancel_student_link_request(p_request_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update public.school_link_requests set status = 'cancelled', responded_at = now()
   where id = p_request_id and status = 'pending' and school_id in (select private.desk_school_ids());
  if not found then raise exception 'Request not found' using errcode = 'P0002'; end if;
end;
$$;

-- For the app: pending school requests for my students (with the school's name).
create or replace function public.my_school_requests()
returns table (request_id uuid, student_id uuid, student_first_name text, school_id uuid,
               school_name text, school_city text, created_at timestamptz, expires_at timestamptz,
               currently_at_school text)
language sql stable security definer set search_path = ''
as $$
  select r.id, r.student_id, s.first_name, r.school_id, sc.name, sc.city, r.created_at, r.expires_at,
         (select name from public.schools where id = s.school_id)
    from public.school_link_requests r
    join public.students s on s.id = r.student_id
    join public.schools sc on sc.id = r.school_id
   where r.status = 'pending' and r.expires_at > now()
     and (r.student_id in (select private.own_student_ids()) or r.student_id in (select private.family_student_ids()))
   order by r.created_at desc
   limit 20;
$$;

-- The student or a family member accepts (consent: the school will see the full drive
-- history while enrolled) or declines.
create or replace function public.respond_school_request(p_request_id uuid, p_accept boolean)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  r public.school_link_requests;
begin
  select * into r from public.school_link_requests where id = p_request_id for update;
  if r.id is null or not private.is_student_or_family(r.student_id) then
    raise exception 'Request not found' using errcode = 'P0002';
  end if;
  if r.status <> 'pending' then return jsonb_build_object('status', r.status); end if;
  if r.expires_at <= now() then
    update public.school_link_requests set status = 'cancelled', responded_at = now() where id = r.id;
    return jsonb_build_object('status', 'expired');
  end if;

  update public.school_link_requests
     set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now(), responded_by = uid
   where id = r.id;
  if p_accept then
    perform set_config('ll.join_via', 'school_request', true);
    perform set_config('ll.leave_reason', 'moved', true);
    update public.students set school_id = r.school_id, updated_at = now() where id = r.student_id;
    perform set_config('ll.join_via', '', true);
    perform set_config('ll.leave_reason', '', true);
    return jsonb_build_object('status', 'accepted', 'student_id', r.student_id, 'school_id', r.school_id);
  end if;
  return jsonb_build_object('status', 'declined');
end;
$$;

-- ---------------------------------------------------------------------------
-- RPCs: leaving a school
-- ---------------------------------------------------------------------------
create or replace function private.detach_student(p_student_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform set_config('ll.leave_reason', p_reason, true);
  update public.students set school_id = null, instructor_id = null, updated_at = now() where id = p_student_id;
  perform set_config('ll.leave_reason', '', true);
end;
$$;
revoke all on function private.detach_student(uuid, text) from public, anon, authenticated;

-- Student or family: "Leave <school>". The profile becomes independent again; all drives stay.
create or replace function public.leave_school(p_student_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_school uuid;
begin
  if not private.is_student_or_family(p_student_id) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  v_school := private.student_school_id(p_student_id);
  if v_school is null then return jsonb_build_object('status', 'not_enrolled'); end if;
  perform private.detach_student(p_student_id, 'student_left');
  return jsonb_build_object('status', 'ok', 'left_school_id', v_school);
end;
$$;

-- School: "Release" a student (finished, moved away). Only for students who use the app,
-- otherwise the profile would belong to nobody: mark those inactive instead.
create or replace function public.release_student(p_student_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_school uuid := private.student_school_id(p_student_id);
begin
  if v_school is null or not private.can_manage_students(v_school) then
    raise exception 'Student not found' using errcode = 'P0002';
  end if;
  if not private.has_app_owner(p_student_id) then
    raise exception 'This student has no app account yet. Mark them inactive instead.' using errcode = '22023';
  end if;
  perform private.detach_student(p_student_id, 'school_released');
  return jsonb_build_object('status', 'ok');
end;
$$;

revoke all on function public.create_independent_student(text, text, date, text, text, text) from public, anon;
revoke all on function public.update_my_student(uuid, text, text, date, text, date) from public, anon;
revoke all on function public.join_school_with_code(uuid, text) from public, anon;
revoke all on function public.request_student_link(uuid, text) from public, anon;
revoke all on function public.cancel_student_link_request(uuid) from public, anon;
revoke all on function public.my_school_requests() from public, anon;
revoke all on function public.respond_school_request(uuid, boolean) from public, anon;
revoke all on function public.leave_school(uuid) from public, anon;
revoke all on function public.release_student(uuid) from public, anon;
grant execute on function public.create_independent_student(text, text, date, text, text, text) to authenticated;
grant execute on function public.update_my_student(uuid, text, text, date, text, date) to authenticated;
grant execute on function public.join_school_with_code(uuid, text) to authenticated;
grant execute on function public.request_student_link(uuid, text) to authenticated;
grant execute on function public.cancel_student_link_request(uuid) to authenticated;
grant execute on function public.my_school_requests() to authenticated;
grant execute on function public.respond_school_request(uuid, boolean) to authenticated;
grant execute on function public.leave_school(uuid) to authenticated;
grant execute on function public.release_student(uuid) to authenticated;
