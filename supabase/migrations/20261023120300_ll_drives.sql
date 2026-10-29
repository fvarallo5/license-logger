-- LicenseLogger 008: drives, batched route storage, sign-offs and the lock.
--
-- How a drive flows:
--   1. Phone creates the drive (client-generated uuid, so retries/offline are safe): status 'in_progress'.
--   2. While driving the phone keeps GPS points locally and uploads a compressed
--      polyline chunk every few minutes (or only at the end) -> drive_route_chunks.
--      No per-point writes, no presence pings.
--   3. At the end the phone sets ended_at / minutes / night minutes / miles and a
--      simplified route_polyline, status 'pending'.
--   4. A supervisor signs (initials on the student's phone, or from the family app):
--      sign_drive() -> status 'signed', locked_at set. From then on time, route,
--      miles and supervisor can never change (trigger), and the row can't be deleted.

create table if not exists public.drives (
  id uuid primary key default gen_random_uuid(),
  -- The student's school when the drive was logged; NULL = independent. Signed drives keep
  -- this stamp forever, so a school keeps the records made while the student was enrolled.
  school_id uuid references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  supervisor_id uuid references public.supervisors (id) on delete set null,
  kind text not null default 'practice' check (kind in ('practice', 'lesson')),
  source text not null default 'gps' check (source in ('gps', 'auto_detected', 'manual', 'instructor')),
  status text not null default 'in_progress'
    check (status in ('in_progress', 'pending', 'signed', 'rejected', 'voided')),
  started_at timestamptz not null,
  ended_at timestamptz,
  tz text not null default 'America/Chicago',
  local_date date not null,                       -- set by trigger from started_at + tz (for the daily cap)
  duration_minutes int not null default 0 check (duration_minutes between 0 and 1440),
  night_minutes int not null default 0 check (night_minutes >= 0),
  distance_miles numeric(7, 2) not null default 0 check (distance_miles >= 0 and distance_miles < 2000),
  start_label text not null default '' check (char_length(start_label) <= 120),
  end_label text not null default '' check (char_length(end_label) <= 120),
  conditions text[] not null default '{}' check (cardinality(conditions) <= 20),
  skills text[] not null default '{}' check (cardinality(skills) <= 30),
  notes text not null default '' check (char_length(notes) <= 2000),
  route_polyline text check (route_polyline is null or char_length(route_polyline) <= 200000),
  route_point_count int not null default 0 check (route_point_count >= 0),
  app_version text not null default '',
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  locked_at timestamptz,
  void_reason text,
  check (night_minutes <= duration_minutes),
  check (ended_at is null or ended_at >= started_at),
  check (status = 'in_progress' or ended_at is not null),
  check (ended_at is null or duration_minutes <= ceil(extract(epoch from (ended_at - started_at)) / 60.0) + 1),
  check ((status = 'signed') = (locked_at is not null) or status = 'voided')
);

-- Lists are read newest first with keyset pagination: (student_id, started_at desc, id desc).
create index if not exists drives_student_started_idx on public.drives (student_id, started_at desc, id desc);
create index if not exists drives_student_day_idx on public.drives (student_id, local_date) where status in ('pending', 'signed');
create index if not exists drives_school_day_idx on public.drives (school_id, local_date desc);
create index if not exists drives_pending_idx on public.drives (student_id) where status = 'pending';
create index if not exists drives_supervisor_idx on public.drives (supervisor_id);
create index if not exists drives_created_by_idx on public.drives (created_by);

-- ---------------------------------------------------------------------------
-- Route chunks: compressed (Google encoded polyline, precision 5) batches of GPS
-- points. Hash-partitioned by drive so the table can grow without one huge index;
-- add partitions/archiving later without changing the app.
-- ---------------------------------------------------------------------------
create table if not exists public.drive_route_chunks (
  drive_id uuid not null references public.drives (id) on delete cascade,
  chunk_no int not null check (chunk_no between 0 and 9999),
  student_id uuid not null,
  polyline text not null check (char_length(polyline) between 1 and 100000),
  point_count int not null check (point_count between 1 and 2000),
  first_at timestamptz not null,
  last_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (drive_id, chunk_no),
  check (last_at >= first_at)
) partition by hash (drive_id);

create table if not exists public.drive_route_chunks_p0 partition of public.drive_route_chunks for values with (modulus 4, remainder 0);
create table if not exists public.drive_route_chunks_p1 partition of public.drive_route_chunks for values with (modulus 4, remainder 1);
create table if not exists public.drive_route_chunks_p2 partition of public.drive_route_chunks for values with (modulus 4, remainder 2);
create table if not exists public.drive_route_chunks_p3 partition of public.drive_route_chunks for values with (modulus 4, remainder 3);
create index if not exists drive_route_chunks_student_idx on public.drive_route_chunks (student_id);

-- ---------------------------------------------------------------------------
-- Sign-offs: one per drive, append-only.
-- ---------------------------------------------------------------------------
create table if not exists public.drive_signoffs (
  id uuid primary key default gen_random_uuid(),
  drive_id uuid not null unique references public.drives (id) on delete cascade,
  school_id uuid references public.schools (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  method text not null check (method in ('on_device', 'family_account', 'instructor')),
  supervisor_id uuid references public.supervisors (id) on delete set null,
  supervisor_name text not null,                      -- snapshot, survives supervisor edits
  signer_user_id uuid references auth.users (id) on delete set null,
  initials text check (initials is null or initials ~ '^[A-Za-z]{1,4}$'),
  signed_at timestamptz not null default now(),
  device jsonb not null default '{}'::jsonb check (pg_column_size(device) < 4000),
  snapshot jsonb not null,                            -- the locked values at signing time
  snapshot_sha256 text not null
);
create index if not exists drive_signoffs_student_idx on public.drive_signoffs (student_id);
create index if not exists drive_signoffs_school_idx on public.drive_signoffs (school_id);
create index if not exists drive_signoffs_supervisor_idx on public.drive_signoffs (supervisor_id);
create index if not exists drive_signoffs_signer_idx on public.drive_signoffs (signer_user_id);

-- ---------------------------------------------------------------------------
-- Triggers: server-owned fields + the lock
-- ---------------------------------------------------------------------------
-- (private.student_school_id / student_exists are defined in migration 007.)

-- SECURITY INVOKER on purpose: current_user tells us who is writing.
-- App users reach tables as 'authenticated'. Our RPCs (security definer, owner
-- postgres) and Edge Functions (service_role) are trusted to change status/lock.
create or replace function private.drives_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  client boolean := current_user in ('authenticated', 'anon');
begin
  if tg_op = 'INSERT' then
    if not private.student_exists(new.student_id) then
      raise exception 'Student not found' using errcode = 'P0002';
    end if;
    new.school_id := private.student_school_id(new.student_id);   -- NULL for independent students
    if client then
      new.created_by := (select auth.uid());
      if new.status in ('signed', 'voided') or new.locked_at is not null then
        raise exception 'Drives are signed with sign_drive()' using errcode = '42501';
      end if;
      new.void_reason := null;
    end if;
  else
    -- Unsigned drives follow the student when they join/leave a school (trusted code only).
    if new.school_id is distinct from old.school_id and (client or old.locked_at is not null) then
      raise exception 'Drive owner fields cannot change' using errcode = '42501';
    end if;
    if new.student_id is distinct from old.student_id
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Drive owner fields cannot change' using errcode = '42501';
    end if;

    if old.locked_at is not null then
      if (new.started_at, new.ended_at, new.tz, new.duration_minutes, new.night_minutes,
          new.distance_miles, new.route_polyline, new.route_point_count, new.supervisor_id,
          new.kind, new.source, new.start_label, new.end_label, new.locked_at)
         is distinct from
         (old.started_at, old.ended_at, old.tz, old.duration_minutes, old.night_minutes,
          old.distance_miles, old.route_polyline, old.route_point_count, old.supervisor_id,
          old.kind, old.source, old.start_label, old.end_label, old.locked_at) then
        raise exception 'This drive is signed and locked' using errcode = '42501';
      end if;
      if new.status is distinct from old.status and (client or new.status <> 'voided') then
        raise exception 'This drive is signed and locked' using errcode = '42501';
      end if;
    elsif client and (new.status in ('signed', 'voided') or new.locked_at is not null) then
      raise exception 'Drives are signed with sign_drive()' using errcode = '42501';
    end if;
    new.updated_at := now();
  end if;

  new.local_date := (new.started_at at time zone new.tz)::date;
  if new.status = 'signed' and new.locked_at is null then
    new.locked_at := now();
  end if;
  return new;
end;
$$;

create or replace function private.drives_before_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- pg_trigger_depth() > 1 means we are inside a cascade (student or school deleted).
  if old.locked_at is not null and pg_trigger_depth() <= 1 then
    raise exception 'Signed drives cannot be deleted; ask the school to void it' using errcode = '42501';
  end if;
  return old;
end;
$$;

create or replace function private.route_chunks_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  d record;
begin
  select student_id, locked_at, status into d from public.drives where id = new.drive_id;
  if d.student_id is null then raise exception 'Drive not found' using errcode = 'P0002'; end if;
  if d.locked_at is not null or d.status in ('signed', 'voided') then
    raise exception 'This drive is signed and locked' using errcode = '42501';
  end if;
  new.student_id := d.student_id;
  return new;
end;
$$;

create or replace function private.block_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if pg_trigger_depth() <= 1 then
    raise exception '% rows are append-only', tg_table_name using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

-- Raw route chunks: never editable; deletable only by cascade or by trusted housekeeping
-- (raw-point retention, see svc_housekeeping). The simplified route on the drive row stays forever.
create or replace function private.route_chunks_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'Route chunks are append-only' using errcode = '42501';
  end if;
  if pg_trigger_depth() <= 1 and current_user in ('authenticated', 'anon') then
    raise exception 'Route chunks are append-only' using errcode = '42501';
  end if;
  return old;
end;
$$;
revoke all on function private.route_chunks_guard() from public, anon, authenticated;

revoke all on function private.drives_before_write() from public, anon, authenticated;
revoke all on function private.drives_before_delete() from public, anon, authenticated;
revoke all on function private.route_chunks_before_insert() from public, anon, authenticated;
revoke all on function private.block_change() from public, anon, authenticated;

drop trigger if exists drives_before_write on public.drives;
create trigger drives_before_write before insert or update on public.drives
  for each row execute function private.drives_before_write();
drop trigger if exists drives_before_delete on public.drives;
create trigger drives_before_delete before delete on public.drives
  for each row execute function private.drives_before_delete();
drop trigger if exists drives_audit on public.drives;
create trigger drives_audit after update or delete on public.drives
  for each row execute function private.audit_row();

drop trigger if exists route_chunks_before_insert on public.drive_route_chunks;
create trigger route_chunks_before_insert before insert on public.drive_route_chunks
  for each row execute function private.route_chunks_before_insert();
drop trigger if exists route_chunks_block on public.drive_route_chunks;
create trigger route_chunks_block before update or delete on public.drive_route_chunks
  for each row execute function private.route_chunks_guard();

drop trigger if exists signoffs_block on public.drive_signoffs;
create trigger signoffs_block before update or delete on public.drive_signoffs
  for each row execute function private.block_change();
drop trigger if exists signoffs_audit on public.drive_signoffs;
create trigger signoffs_audit after insert on public.drive_signoffs
  for each row execute function private.audit_row();

-- ---------------------------------------------------------------------------
-- Who may log a drive for a student
-- ---------------------------------------------------------------------------
create or replace function private.can_log_drive(p_student_id uuid, p_kind text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select case
    when p_kind = 'practice' then
         exists (select 1 from public.students s where s.id = p_student_id and s.user_id = (select auth.uid()))
      or exists (select 1 from public.family_links f where f.student_id = p_student_id
                  and f.user_id = (select auth.uid()) and f.status = 'active')
      or exists (select 1 from public.students s where s.id = p_student_id
                  and s.school_id in (select private.desk_school_ids()))
    when p_kind = 'lesson' then
         exists (select 1 from public.students s
                   join public.school_members m on m.school_id = s.school_id and m.user_id = (select auth.uid())
                  where s.id = p_student_id
                    and (s.instructor_id = (select auth.uid()) or m.role in ('owner', 'admin', 'front_desk')))
    else false end;
$$;
revoke all on function private.can_log_drive(uuid, text) from public, anon;
grant execute on function private.can_log_drive(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.drives enable row level security;
alter table public.drives force row level security;
alter table public.drive_route_chunks enable row level security;
alter table public.drive_route_chunks force row level security;
alter table public.drive_signoffs enable row level security;
alter table public.drive_signoffs force row level security;
-- Partitions are separate tables: lock them down so they are only reachable through the parent.
alter table public.drive_route_chunks_p0 enable row level security;
alter table public.drive_route_chunks_p1 enable row level security;
alter table public.drive_route_chunks_p2 enable row level security;
alter table public.drive_route_chunks_p3 enable row level security;
alter table public.drive_route_chunks_p0 force row level security;
alter table public.drive_route_chunks_p1 force row level security;
alter table public.drive_route_chunks_p2 force row level security;
alter table public.drive_route_chunks_p3 force row level security;

drop policy if exists drives_select on public.drives;
create policy drives_select on public.drives
  for select to authenticated
  using (student_id in (select private.visible_student_ids())
         or school_id in (select private.desk_school_ids()));   -- records made while enrolled

drop policy if exists drives_insert on public.drives;
create policy drives_insert on public.drives
  for insert to authenticated
  with check (private.can_log_drive(student_id, kind) and not (select private.is_anonymous()));

drop policy if exists drives_update on public.drives;
create policy drives_update on public.drives
  for update to authenticated
  using (private.can_log_drive(student_id, kind))
  with check (private.can_log_drive(student_id, kind));

drop policy if exists drives_delete on public.drives;
create policy drives_delete on public.drives
  for delete to authenticated
  using (locked_at is null and private.can_log_drive(student_id, kind));

drop policy if exists route_chunks_select on public.drive_route_chunks;
create policy route_chunks_select on public.drive_route_chunks
  for select to authenticated
  using (student_id in (select private.visible_student_ids()));

drop policy if exists route_chunks_insert on public.drive_route_chunks;
create policy route_chunks_insert on public.drive_route_chunks
  for insert to authenticated
  with check (exists (select 1 from public.drives d
                       where d.id = drive_id and private.can_log_drive(d.student_id, d.kind)));

drop policy if exists signoffs_select on public.drive_signoffs;
create policy signoffs_select on public.drive_signoffs
  for select to authenticated
  using (student_id in (select private.visible_student_ids())
         or school_id in (select private.desk_school_ids()));

revoke all on table public.drives, public.drive_route_chunks, public.drive_signoffs from public, anon, authenticated;
revoke all on table public.drive_route_chunks_p0, public.drive_route_chunks_p1,
                    public.drive_route_chunks_p2, public.drive_route_chunks_p3 from public, anon, authenticated;
grant select, insert, update, delete on table public.drives to authenticated;
grant select, insert on table public.drive_route_chunks to authenticated;
grant select on table public.drive_signoffs to authenticated;
grant select, insert, update, delete on table public.drives, public.drive_route_chunks, public.drive_signoffs to service_role;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Sign a finished drive.
--   p_method 'on_device'      : student's phone, supervisor types initials (p_supervisor_id required)
--   p_method 'family_account' : signed from the parent's own app (caller must be linked with can_sign)
--   p_method 'instructor'     : instructor/desk signs an instructor lesson
create or replace function public.sign_drive(
  p_drive_id uuid,
  p_method text,
  p_supervisor_id uuid default null,
  p_initials text default null,
  p_device jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  d public.drives;
  sup public.supervisors;
  v_name text;
  snap jsonb;
  sig_id uuid;
begin
  if uid is null then raise exception 'Not authenticated' using errcode = '42501'; end if;
  if private.is_anonymous() then raise exception 'Create an account first' using errcode = '42501'; end if;

  select * into d from public.drives where id = p_drive_id for update;
  if d.id is null or not private.can_view_student(d.student_id) then
    raise exception 'Drive not found' using errcode = 'P0002';
  end if;
  if d.status <> 'pending' then
    raise exception 'Only finished, unsigned drives can be signed (status is %)', d.status using errcode = '22023';
  end if;

  if p_method = 'on_device' then
    if not exists (select 1 from public.students where id = d.student_id and user_id = uid) then
      raise exception 'On-device sign-off happens on the student''s phone' using errcode = '42501';
    end if;
    if d.kind <> 'practice' then raise exception 'Lessons are signed by the school' using errcode = '42501'; end if;
    select * into sup from public.supervisors
     where id = coalesce(p_supervisor_id, d.supervisor_id) and student_id = d.student_id and active and can_sign;
    if sup.id is null then raise exception 'Pick a supervisor who can sign' using errcode = '22023'; end if;
    if p_initials is null or p_initials !~ '^[A-Za-z]{1,4}$' then
      raise exception 'Supervisor initials are required' using errcode = '22023';
    end if;
    v_name := sup.name;

  elsif p_method = 'family_account' then
    if d.kind <> 'practice' then raise exception 'Lessons are signed by the school' using errcode = '42501'; end if;
    if not exists (select 1 from public.family_links where student_id = d.student_id and user_id = uid
                    and status = 'active' and can_sign) then
      raise exception 'Only a linked family member can sign' using errcode = '42501';
    end if;
    select * into sup from public.supervisors where student_id = d.student_id and user_id = uid;
    select coalesce(nullif(trim(full_name), ''), 'Family member') into v_name from public.profiles where id = uid;
    v_name := coalesce(sup.name, v_name);

  elsif p_method = 'instructor' then
    if d.kind <> 'lesson' or not private.can_log_drive(d.student_id, 'lesson') then
      raise exception 'Only the school can sign lessons' using errcode = '42501';
    end if;
    select coalesce(nullif(trim(full_name), ''), 'Instructor') into v_name from public.profiles where id = uid;
  else
    raise exception 'Unknown sign-off method' using errcode = '22023';
  end if;

  -- Attach the supervisor if the drive didn't have one yet (still unlocked here).
  if d.supervisor_id is null and sup.id is not null then
    update public.drives set supervisor_id = sup.id where id = d.id returning * into d;
  end if;

  snap := jsonb_build_object(
    'drive_id', d.id, 'student_id', d.student_id, 'kind', d.kind, 'source', d.source,
    'started_at', d.started_at, 'ended_at', d.ended_at, 'tz', d.tz, 'local_date', d.local_date,
    'duration_minutes', d.duration_minutes, 'night_minutes', d.night_minutes,
    'distance_miles', d.distance_miles, 'supervisor_id', d.supervisor_id,
    'route_sha256', case when d.route_polyline is null then null
                         else encode(extensions.digest(d.route_polyline, 'sha256'), 'hex') end);

  update public.drives set status = 'signed', locked_at = now() where id = d.id;

  insert into public.drive_signoffs (drive_id, school_id, student_id, method, supervisor_id, supervisor_name,
                                     signer_user_id, initials, device, snapshot, snapshot_sha256)
  values (d.id, d.school_id, d.student_id, p_method, sup.id, v_name, uid, upper(p_initials),
          coalesce(p_device, '{}'::jsonb) - 'ip', snap, encode(extensions.digest(snap::text, 'sha256'), 'hex'))
  returning id into sig_id;

  return jsonb_build_object('status', 'signed', 'signoff_id', sig_id, 'snapshot_sha256',
                            encode(extensions.digest(snap::text, 'sha256'), 'hex'));
end;
$$;

-- Supervisor or family says "this drive is wrong" -> back to the student to fix or delete.
create or replace function public.reject_drive(p_drive_id uuid, p_reason text default '')
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  d public.drives;
begin
  select * into d from public.drives where id = p_drive_id for update;
  if d.id is null or not private.can_act_for_student(d.student_id) then
    raise exception 'Drive not found' using errcode = 'P0002';
  end if;
  if d.status <> 'pending' then raise exception 'Only pending drives can be rejected' using errcode = '22023'; end if;
  update public.drives
     set status = 'rejected',
         notes = left(trim(both from notes || case when coalesce(p_reason, '') <> '' then E'\nRejected: ' || p_reason else '' end), 2000)
   where id = d.id;
end;
$$;

-- School desk staff can void a signed drive (it stays visible, stops counting).
create or replace function public.void_drive(p_drive_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  d public.drives;
begin
  select * into d from public.drives where id = p_drive_id for update;
  -- Only the student's CURRENT school may void (a former school can't touch the record).
  if d.id is null or d.school_id is null or d.school_id not in (select private.desk_school_ids())
     or private.student_school_id(d.student_id) is distinct from d.school_id then
    raise exception 'Drive not found' using errcode = 'P0002';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'A reason is required' using errcode = '22023'; end if;
  update public.drives set status = 'voided', void_reason = trim(p_reason) where id = d.id;
end;
$$;

revoke all on function public.sign_drive(uuid, text, uuid, text, jsonb) from public, anon;
revoke all on function public.reject_drive(uuid, text) from public, anon;
revoke all on function public.void_drive(uuid, text) from public, anon;
grant execute on function public.sign_drive(uuid, text, uuid, text, jsonb) to authenticated;
grant execute on function public.reject_drive(uuid, text) to authenticated;
grant execute on function public.void_drive(uuid, text) to authenticated;
