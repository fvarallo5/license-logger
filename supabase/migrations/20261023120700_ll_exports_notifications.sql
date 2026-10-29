-- LicenseLogger 012: report exports, outgoing email queue, private storage bucket.

-- ---------------------------------------------------------------------------
-- Exports: a record of every PDF/CSV produced. Files live in the PRIVATE
-- 'exports' bucket and are only ever handed out as short-lived signed URLs.
-- ---------------------------------------------------------------------------
create table if not exists public.exports (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete cascade,      -- NULL for independent students
  student_id uuid not null references public.students (id) on delete cascade,
  drive_id uuid references public.drives (id) on delete set null,
  requested_by uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('hours_pdf', 'hours_csv', 'drive_pdf')),
  status text not null default 'ready' check (status in ('ready', 'failed', 'expired')),
  storage_path text,
  byte_size int,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);
create index if not exists exports_requested_by_idx on public.exports (requested_by, created_at desc);
create index if not exists exports_student_idx on public.exports (student_id);
create index if not exists exports_school_idx on public.exports (school_id);
create index if not exists exports_drive_idx on public.exports (drive_id);
create index if not exists exports_expires_idx on public.exports (expires_at) where status = 'ready';

drop trigger if exists exports_school on public.exports;
create trigger exports_school before insert or update on public.exports
  for each row execute function private.set_school_from_student();

alter table public.exports enable row level security;
alter table public.exports force row level security;
drop policy if exists exports_select_own on public.exports;
create policy exports_select_own on public.exports for select to authenticated
  using (requested_by = (select auth.uid()));
revoke all on table public.exports from public, anon, authenticated;
grant select on table public.exports to authenticated;
grant select, insert, update, delete on table public.exports to service_role;

-- Bucket (only when the Storage schema exists; it always does on Supabase).
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage')
     and exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                  where n.nspname = 'storage' and c.relname = 'buckets') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('exports', 'exports', false, 20971520, array['application/pdf', 'text/csv'])
    on conflict (id) do update set public = false;
  end if;
end $$;
-- No storage.objects policies on purpose: apps never touch the bucket directly.
-- The export-report Edge Function uploads with service_role and returns a signed URL.

-- ---------------------------------------------------------------------------
-- Email outbox. Rows are added by triggers/RPCs; the send-notifications Edge
-- Function drains it through Resend with an Idempotency-Key, so a retry never
-- sends the same email twice.
-- ---------------------------------------------------------------------------
create table if not exists private.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  kind text not null check (kind in ('drive_pending', 'family_invite', 'family_linked')),
  to_user_id uuid references auth.users (id) on delete cascade,
  to_email text,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued', 'sending', 'sent', 'failed', 'dead', 'skipped')),
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  check (to_user_id is not null or to_email is not null)
);
create index if not exists notification_outbox_due_idx on private.notification_outbox (next_attempt_at)
  where status in ('queued', 'failed');
create index if not exists notification_outbox_user_idx on private.notification_outbox (to_user_id);
alter table private.notification_outbox enable row level security;
alter table private.notification_outbox force row level security;
revoke all on table private.notification_outbox from public, anon, authenticated;

-- When a practice drive is finished (pending), tell linked family members who can sign.
create or replace function private.notify_drive_pending()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status = 'pending' and new.kind = 'practice'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    insert into private.notification_outbox (idempotency_key, kind, to_user_id, payload, next_attempt_at)
    select 'drive_pending:' || new.id || ':' || f.user_id, 'drive_pending', f.user_id,
           jsonb_build_object('drive_id', new.id, 'student_id', new.student_id,
                              'minutes', new.duration_minutes, 'night_minutes', new.night_minutes,
                              'local_date', new.local_date),
           now() + interval '10 minutes'            -- grace period: skipped if signed on the phone meanwhile
      from public.family_links f
      join public.profiles p on p.id = f.user_id and p.notify_email
     where f.student_id = new.student_id and f.status = 'active' and f.can_sign
    on conflict (idempotency_key) do nothing;
  end if;
  return null;
end;
$$;
revoke all on function private.notify_drive_pending() from public, anon, authenticated;
drop trigger if exists drives_notify_pending on public.drives;
create trigger drives_notify_pending after insert or update of status on public.drives
  for each row execute function private.notify_drive_pending();

-- Family invite emails are NOT queued here: the outbox never sees the code (only its hash
-- is stored). The family-invite Edge Function sends that email directly, once, with an
-- Idempotency-Key, right after create_family_invite() returns the code.

-- ---------------------------------------------------------------------------
-- Service-only RPCs for the email worker and housekeeping
-- ---------------------------------------------------------------------------
create or replace function public.svc_claim_notifications(p_limit int default 50)
returns table (id uuid, kind text, to_email text, payload jsonb, attempts int, idempotency_key text)
language plpgsql security definer set search_path = ''
as $$
begin
  -- Drive reminders that were signed in the meantime are skipped, not sent.
  update private.notification_outbox o set status = 'skipped'
   where o.kind = 'drive_pending' and o.status = 'queued'
     and exists (select 1 from public.drives d where d.id = (o.payload ->> 'drive_id')::uuid and d.status <> 'pending');

  return query
  with due as (
    select o.id from private.notification_outbox o
     where o.status in ('queued', 'failed') and o.next_attempt_at <= now()
     order by o.next_attempt_at
     limit least(greatest(coalesce(p_limit, 50), 1), 200)
     for update skip locked
  ), upd as (
    update private.notification_outbox o set status = 'sending', attempts = o.attempts + 1
      from due where o.id = due.id
    returning o.*
  )
  select u.id, u.kind,
         coalesce(u.to_email, (select au.email::text from auth.users au where au.id = u.to_user_id)),
         u.payload || jsonb_build_object(
           'student_first_name', (select s.first_name from public.students s where s.id = (u.payload ->> 'student_id')::uuid),
           'school_name', (select sc.name from public.students s join public.schools sc on sc.id = s.school_id
                            where s.id = (u.payload ->> 'student_id')::uuid)),
         u.attempts, u.idempotency_key
    from upd u;
end;
$$;

create or replace function public.svc_finish_notification(p_id uuid, p_ok boolean, p_error text default null)
returns void
language sql security definer set search_path = ''
as $$
  update private.notification_outbox
     set status = case when p_ok then 'sent' when attempts >= 6 then 'dead' else 'failed' end,
         sent_at = case when p_ok then now() end,
         last_error = case when p_ok then null else left(p_error, 1000) end,
         next_attempt_at = now() + make_interval(mins => power(2, least(attempts, 8))::int)
   where id = p_id;
$$;

-- Daily housekeeping: returns storage paths of expired exports so the function can delete the files.
create or replace function public.svc_expire_exports()
returns table (storage_path text)
language sql security definer set search_path = ''
as $$
  update public.exports set status = 'expired'
   where status = 'ready' and expires_at < now()
  returning storage_path;
$$;

create or replace function public.svc_housekeeping()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  a int; b int; c int; d int; e int;
begin
  delete from private.code_attempts where at < now() - interval '7 days';
  get diagnostics a = row_count;
  delete from private.qbo_webhook_events where received_at < now() - interval '30 days';
  get diagnostics b = row_count;
  delete from private.qbo_sync_jobs where status = 'done' and updated_at < now() - interval '30 days';
  get diagnostics c = row_count;
  delete from private.notification_outbox where status in ('sent', 'skipped') and created_at < now() - interval '30 days';
  get diagnostics d = row_count;
  delete from private.qbo_oauth_states where expires_at < now();
  -- Raw GPS chunks of drives signed more than a year ago (the drive keeps its simplified
  -- route and the sign-off keeps its fingerprint). Change the interval to keep them longer.
  delete from public.drive_route_chunks c
   using public.drives d
   where d.id = c.drive_id and d.locked_at < now() - interval '365 days';
  get diagnostics e = row_count;
  return jsonb_build_object('code_attempts', a, 'webhook_events', b, 'sync_jobs', c, 'notifications', d, 'route_chunks', e);
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.svc_claim_notifications(int)',
    'public.svc_finish_notification(uuid, boolean, text)',
    'public.svc_expire_exports()',
    'public.svc_housekeeping()'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
