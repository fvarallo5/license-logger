-- LicenseLogger 011: billing mirror of QuickBooks Online + the sync machinery.
--
--  * public.billing_customers / invoices / invoice_lines / payments: what the
--    dashboard Pay tab and the family portal read. Money is numeric(12,2).
--  * public.qbo_connections: one QuickBooks company per school (status only, no secrets).
--  * private.qbo_tokens: pointers to the OAuth tokens, which live in Supabase Vault.
--  * private.qbo_sync_jobs: an outbox. App changes queue a "push"; webhooks queue a "pull".
--    Every push uses the job id as QuickBooks' requestid, so retries never create duplicates.
--  * private.qbo_webhook_events: every webhook event id we've seen (dedupe).
--  * svc_* functions: callable ONLY by service_role (Edge Functions), never by the apps.

-- ---------------------------------------------------------------------------
-- Mirror tables
-- ---------------------------------------------------------------------------
create table if not exists public.billing_customers (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  student_id uuid references public.students (id) on delete set null,
  display_name text not null check (char_length(trim(display_name)) between 1 and 100),
  email text not null default '',
  phone text not null default '',
  active boolean not null default true,
  qbo_customer_id text,
  qbo_sync_token text,
  qbo_updated_at timestamptz,
  sync_status text not null default 'local' check (sync_status in ('local', 'pending', 'synced', 'error')),
  sync_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, qbo_customer_id)
);
create index if not exists billing_customers_school_idx on public.billing_customers (school_id, display_name);
create index if not exists billing_customers_student_idx on public.billing_customers (student_id);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  customer_id uuid not null references public.billing_customers (id) on delete restrict,
  student_id uuid references public.students (id) on delete set null,
  doc_number text,
  txn_date date not null default current_date,
  due_date date,
  currency text not null default 'USD' check (char_length(currency) = 3),
  subtotal numeric(12, 2) not null default 0,
  tax numeric(12, 2) not null default 0,
  total numeric(12, 2) not null default 0 check (total >= 0),
  balance numeric(12, 2) not null default 0 check (balance >= 0),
  status text not null default 'draft' check (status in ('draft', 'open', 'partially_paid', 'paid', 'void')),
  memo text not null default '' check (char_length(memo) <= 1000),
  qbo_invoice_id text,
  qbo_sync_token text,
  qbo_updated_at timestamptz,
  sync_status text not null default 'local' check (sync_status in ('local', 'pending', 'synced', 'error')),
  sync_error text,
  created_by uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, qbo_invoice_id),
  check (balance <= total)
);
create index if not exists invoices_school_date_idx on public.invoices (school_id, txn_date desc, id desc);
create index if not exists invoices_customer_idx on public.invoices (customer_id);
create index if not exists invoices_student_idx on public.invoices (student_id);
create index if not exists invoices_created_by_idx on public.invoices (created_by);
create index if not exists invoices_open_idx on public.invoices (school_id) where status in ('open', 'partially_paid');

create table if not exists public.invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  school_id uuid not null references public.schools (id) on delete cascade,
  line_no int not null check (line_no between 1 and 250),
  description text not null default '' check (char_length(description) <= 500),
  package_catalog_id uuid references public.package_catalog (id) on delete set null,
  qbo_item_id text,
  quantity numeric(10, 2) not null default 1 check (quantity > 0),
  unit_price numeric(12, 2) not null default 0,
  amount numeric(12, 2) not null default 0,
  unique (invoice_id, line_no)
);
create index if not exists invoice_lines_school_idx on public.invoice_lines (school_id);
create index if not exists invoice_lines_catalog_idx on public.invoice_lines (package_catalog_id);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  customer_id uuid not null references public.billing_customers (id) on delete restrict,
  invoice_id uuid references public.invoices (id) on delete set null,
  student_id uuid references public.students (id) on delete set null,
  amount numeric(12, 2) not null check (amount > 0),
  received_on date not null default current_date,
  method text not null default '' check (char_length(method) <= 40),
  reference text not null default '' check (char_length(reference) <= 100),
  qbo_payment_id text,
  qbo_sync_token text,
  qbo_updated_at timestamptz,
  sync_status text not null default 'local' check (sync_status in ('local', 'pending', 'synced', 'error')),
  sync_error text,
  created_by uuid references auth.users (id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, qbo_payment_id)
);
create index if not exists payments_school_date_idx on public.payments (school_id, received_on desc, id desc);
create index if not exists payments_customer_idx on public.payments (customer_id);
create index if not exists payments_invoice_idx on public.payments (invoice_id);
create index if not exists payments_student_idx on public.payments (student_id);
create index if not exists payments_created_by_idx on public.payments (created_by);

create table if not exists public.qbo_connections (
  school_id uuid primary key references public.schools (id) on delete cascade,
  realm_id text not null unique,
  environment text not null default 'production' check (environment in ('sandbox', 'production')),
  company_name text not null default '',
  status text not null default 'connected' check (status in ('connected', 'needs_reauth', 'disconnected')),
  access_expires_at timestamptz,
  refresh_expires_at timestamptz,
  connected_by uuid references auth.users (id) on delete set null,
  connected_at timestamptz not null default now(),
  last_sync_at timestamptz,
  last_error text,
  updated_at timestamptz not null default now()
);
create index if not exists qbo_connections_connected_by_idx on public.qbo_connections (connected_by);

-- ---------------------------------------------------------------------------
-- Private machinery (not reachable through the API at all)
-- ---------------------------------------------------------------------------
create table if not exists private.qbo_tokens (
  school_id uuid primary key references public.schools (id) on delete cascade,
  access_secret_id uuid not null,       -- vault.secrets.id
  refresh_secret_id uuid not null,      -- vault.secrets.id
  updated_at timestamptz not null default now()
);

create table if not exists private.qbo_oauth_states (
  state_hash text primary key,
  school_id uuid not null references public.schools (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes'
);
create index if not exists qbo_oauth_states_school_idx on private.qbo_oauth_states (school_id);
create index if not exists qbo_oauth_states_user_idx on private.qbo_oauth_states (user_id);

create table if not exists private.qbo_sync_jobs (
  id uuid primary key default gen_random_uuid(),     -- also sent to QuickBooks as requestid
  school_id uuid not null references public.schools (id) on delete cascade,
  direction text not null check (direction in ('push', 'pull')),
  entity text not null check (entity in ('customer', 'invoice', 'payment')),
  local_id uuid,
  qbo_id text,
  status text not null default 'queued' check (status in ('queued', 'running', 'done', 'failed', 'dead')),
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  locked_until timestamptz,
  last_error text,
  source_event_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((direction = 'push' and local_id is not null) or (direction = 'pull' and qbo_id is not null))
);
-- Coalesce: at most one open push per local row, one open pull per QuickBooks entity.
create unique index if not exists qbo_jobs_one_open_push on private.qbo_sync_jobs (entity, local_id)
  where direction = 'push' and status in ('queued', 'running', 'failed');
create unique index if not exists qbo_jobs_one_open_pull on private.qbo_sync_jobs (school_id, entity, qbo_id)
  where direction = 'pull' and status in ('queued', 'running', 'failed');
create index if not exists qbo_jobs_due_idx on private.qbo_sync_jobs (next_attempt_at)
  where status in ('queued', 'failed');
create index if not exists qbo_jobs_school_idx on private.qbo_sync_jobs (school_id);

create table if not exists private.qbo_webhook_events (
  event_id text primary key,             -- CloudEvents "id"
  realm_id text not null,
  event_type text not null,              -- e.g. qbo.invoice.updated.v1
  entity_id text not null,
  event_time timestamptz,
  received_at timestamptz not null default now()
);
create index if not exists qbo_webhook_events_received_idx on private.qbo_webhook_events (received_at);

alter table private.qbo_tokens enable row level security;
alter table private.qbo_oauth_states enable row level security;
alter table private.qbo_sync_jobs enable row level security;
alter table private.qbo_webhook_events enable row level security;
alter table private.qbo_tokens force row level security;
alter table private.qbo_oauth_states force row level security;
alter table private.qbo_sync_jobs force row level security;
alter table private.qbo_webhook_events force row level security;
revoke all on table private.qbo_tokens, private.qbo_oauth_states, private.qbo_sync_jobs,
                    private.qbo_webhook_events from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
drop trigger if exists billing_customers_touch on public.billing_customers;
create trigger billing_customers_touch before update on public.billing_customers
  for each row execute function private.touch_updated_at();
drop trigger if exists invoices_touch on public.invoices;
create trigger invoices_touch before update on public.invoices
  for each row execute function private.touch_updated_at();
drop trigger if exists payments_touch on public.payments;
create trigger payments_touch before update on public.payments
  for each row execute function private.touch_updated_at();
drop trigger if exists qbo_connections_touch on public.qbo_connections;
create trigger qbo_connections_touch before update on public.qbo_connections
  for each row execute function private.touch_updated_at();

drop trigger if exists invoices_audit on public.invoices;
create trigger invoices_audit after insert or update or delete on public.invoices
  for each row execute function private.audit_row();
drop trigger if exists payments_audit on public.payments;
create trigger payments_audit after insert or update or delete on public.payments
  for each row execute function private.audit_row();
drop trigger if exists qbo_connections_audit on public.qbo_connections;
create trigger qbo_connections_audit after insert or update or delete on public.qbo_connections
  for each row execute function private.audit_row();

-- Invoice lines inherit school_id from their invoice.
create or replace function private.invoice_lines_school()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  select school_id into new.school_id from public.invoices where id = new.invoice_id;
  if new.school_id is null then raise exception 'Invoice not found' using errcode = 'P0002'; end if;
  return new;
end;
$$;
revoke all on function private.invoice_lines_school() from public, anon, authenticated;
drop trigger if exists invoice_lines_school on public.invoice_lines;
create trigger invoice_lines_school before insert or update on public.invoice_lines
  for each row execute function private.invoice_lines_school();

-- An edit made in the app (role 'authenticated') queues a push if the school is connected.
-- Changes written by sync itself (service/RPC) do not, so there are no loops.
-- SECURITY INVOKER on purpose (reads current_user); the enqueue helper is definer.
create or replace function private.billing_mark_pending()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if current_user = 'authenticated' and private.qbo_is_connected(new.school_id) then
    new.sync_status := 'pending';
    new.sync_error := null;
  end if;
  return new;
end;
$$;

create or replace function private.qbo_is_connected(p_school_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.qbo_connections where school_id = p_school_id and status = 'connected');
$$;

create or replace function private.qbo_enqueue_push(p_school_id uuid, p_entity text, p_local_id uuid)
returns void language sql security definer set search_path = ''
as $$
  insert into private.qbo_sync_jobs (school_id, direction, entity, local_id)
  values (p_school_id, 'push', p_entity, p_local_id)
  on conflict (entity, local_id) where direction = 'push' and status in ('queued', 'running', 'failed')
  do update set next_attempt_at = least(private.qbo_sync_jobs.next_attempt_at, now()), updated_at = now();
$$;

create or replace function private.billing_enqueue()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.sync_status = 'pending' and current_user = 'authenticated' then
    perform private.qbo_enqueue_push(new.school_id, tg_argv[0], new.id);
  end if;
  return null;
end;
$$;

create or replace function private.invoice_lines_enqueue()
returns trigger language plpgsql set search_path = ''
as $$
declare
  r record;
begin
  r := coalesce(new, old);
  if current_user = 'authenticated' and private.qbo_is_connected(r.school_id) then
    perform private.qbo_enqueue_push(r.school_id, 'invoice', r.invoice_id);
  end if;
  return null;
end;
$$;

revoke all on function private.billing_mark_pending() from public, anon, authenticated;
revoke all on function private.billing_enqueue() from public, anon, authenticated;
revoke all on function private.invoice_lines_enqueue() from public, anon, authenticated;
revoke all on function private.qbo_is_connected(uuid) from public, anon;
revoke all on function private.qbo_enqueue_push(uuid, text, uuid) from public, anon;
grant execute on function private.qbo_is_connected(uuid) to authenticated;
grant execute on function private.qbo_enqueue_push(uuid, text, uuid) to authenticated;

-- Billing / QuickBooks is only for students OF THIS SCHOOL. An app user can't attach a
-- customer/invoice/payment to an independent student or another school's student.
-- (Sync writes from QuickBooks run as trusted roles and keep historical links after a student leaves.)
create or replace function private.billing_check_student()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') and new.student_id is not null
     and (tg_op = 'INSERT' or new.student_id is distinct from old.student_id)
     and private.student_school_id(new.student_id) is distinct from new.school_id then
    raise exception 'Billing is only for students of this school' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.billing_check_student() from public, anon, authenticated;
drop trigger if exists billing_customers_student_check on public.billing_customers;
create trigger billing_customers_student_check before insert or update on public.billing_customers
  for each row execute function private.billing_check_student();
drop trigger if exists invoices_student_check on public.invoices;
create trigger invoices_student_check before insert or update on public.invoices
  for each row execute function private.billing_check_student();
drop trigger if exists payments_student_check on public.payments;
create trigger payments_student_check before insert or update on public.payments
  for each row execute function private.billing_check_student();

drop trigger if exists billing_customers_pending on public.billing_customers;
create trigger billing_customers_pending before insert or update on public.billing_customers
  for each row execute function private.billing_mark_pending();
drop trigger if exists invoices_pending on public.invoices;
create trigger invoices_pending before insert or update on public.invoices
  for each row execute function private.billing_mark_pending();
drop trigger if exists payments_pending on public.payments;
create trigger payments_pending before insert or update on public.payments
  for each row execute function private.billing_mark_pending();

drop trigger if exists billing_customers_enqueue on public.billing_customers;
create trigger billing_customers_enqueue after insert or update on public.billing_customers
  for each row execute function private.billing_enqueue('customer');
drop trigger if exists invoices_enqueue on public.invoices;
create trigger invoices_enqueue after insert or update on public.invoices
  for each row execute function private.billing_enqueue('invoice');
drop trigger if exists payments_enqueue on public.payments;
create trigger payments_enqueue after insert or update on public.payments
  for each row execute function private.billing_enqueue('payment');
drop trigger if exists invoice_lines_enqueue on public.invoice_lines;
create trigger invoice_lines_enqueue after insert or update or delete on public.invoice_lines
  for each row execute function private.invoice_lines_enqueue();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.billing_customers enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_lines enable row level security;
alter table public.payments enable row level security;
alter table public.qbo_connections enable row level security;
alter table public.billing_customers force row level security;
alter table public.invoices force row level security;
alter table public.invoice_lines force row level security;
alter table public.payments force row level security;
alter table public.qbo_connections force row level security;

drop policy if exists billing_customers_select on public.billing_customers;
create policy billing_customers_select on public.billing_customers for select to authenticated
  using (school_id in (select private.pay_school_ids()));
drop policy if exists billing_customers_insert on public.billing_customers;
create policy billing_customers_insert on public.billing_customers for insert to authenticated
  with check (school_id in (select private.pay_school_ids()));
drop policy if exists billing_customers_update on public.billing_customers;
create policy billing_customers_update on public.billing_customers for update to authenticated
  using (school_id in (select private.pay_school_ids()))
  with check (school_id in (select private.pay_school_ids()));

-- Families/students can read their own invoices and payments (portal Billing tab).
drop policy if exists invoices_select on public.invoices;
create policy invoices_select on public.invoices for select to authenticated
  using (school_id in (select private.pay_school_ids())
         or (status <> 'draft' and (student_id in (select private.own_student_ids())
                                    or student_id in (select private.family_student_ids()))));
drop policy if exists invoices_insert on public.invoices;
create policy invoices_insert on public.invoices for insert to authenticated
  with check (school_id in (select private.pay_school_ids()));
drop policy if exists invoices_update on public.invoices;
create policy invoices_update on public.invoices for update to authenticated
  using (school_id in (select private.pay_school_ids()))
  with check (school_id in (select private.pay_school_ids()));

drop policy if exists invoice_lines_select on public.invoice_lines;
create policy invoice_lines_select on public.invoice_lines for select to authenticated
  using (school_id in (select private.pay_school_ids())
         or invoice_id in (select i.id from public.invoices i
                            where i.status <> 'draft'
                              and (i.student_id in (select private.own_student_ids())
                                   or i.student_id in (select private.family_student_ids()))));
drop policy if exists invoice_lines_write on public.invoice_lines;
create policy invoice_lines_write on public.invoice_lines for insert to authenticated
  with check (school_id in (select private.pay_school_ids()));
drop policy if exists invoice_lines_update on public.invoice_lines;
create policy invoice_lines_update on public.invoice_lines for update to authenticated
  using (school_id in (select private.pay_school_ids()))
  with check (school_id in (select private.pay_school_ids()));
drop policy if exists invoice_lines_delete on public.invoice_lines;
create policy invoice_lines_delete on public.invoice_lines for delete to authenticated
  using (school_id in (select private.pay_school_ids())
         and exists (select 1 from public.invoices i where i.id = invoice_id and i.status = 'draft'));

drop policy if exists payments_select on public.payments;
create policy payments_select on public.payments for select to authenticated
  using (school_id in (select private.pay_school_ids())
         or student_id in (select private.own_student_ids())
         or student_id in (select private.family_student_ids()));
drop policy if exists payments_insert on public.payments;
create policy payments_insert on public.payments for insert to authenticated
  with check (school_id in (select private.pay_school_ids()));
drop policy if exists payments_update on public.payments;
create policy payments_update on public.payments for update to authenticated
  using (school_id in (select private.pay_school_ids()))
  with check (school_id in (select private.pay_school_ids()));

drop policy if exists qbo_connections_select on public.qbo_connections;
create policy qbo_connections_select on public.qbo_connections for select to authenticated
  using (school_id in (select private.manager_school_ids()) or school_id in (select private.pay_school_ids()));

revoke all on table public.billing_customers, public.invoices, public.invoice_lines, public.payments,
                    public.qbo_connections from public, anon, authenticated;
grant select, insert, update on table public.billing_customers, public.invoices, public.payments to authenticated;
grant select, insert, update, delete on table public.invoice_lines to authenticated;
grant select on table public.qbo_connections to authenticated;
grant select, insert, update, delete on table public.billing_customers, public.invoices, public.invoice_lines,
      public.payments, public.qbo_connections to service_role;

-- ---------------------------------------------------------------------------
-- App-facing RPCs
-- ---------------------------------------------------------------------------

-- Dashboard "Connect to QuickBooks": returns a one-time state value for the OAuth URL.
create or replace function public.qbo_begin_connect(p_school_id uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  raw text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if not private.is_school_manager(p_school_id) then
    raise exception 'Only an owner or admin can connect QuickBooks' using errcode = '42501';
  end if;
  delete from private.qbo_oauth_states where expires_at < now();
  insert into private.qbo_oauth_states (state_hash, school_id, user_id)
  values (encode(extensions.digest(raw, 'sha256'), 'hex'), p_school_id, (select auth.uid()));
  return raw;
end;
$$;

-- Disconnect: forget tokens (the Edge Function also revokes them at Intuit first).
create or replace function public.qbo_disconnect(p_school_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  t private.qbo_tokens;
begin
  if not private.is_school_manager(p_school_id) then
    raise exception 'Only an owner or admin can disconnect QuickBooks' using errcode = '42501';
  end if;
  select * into t from private.qbo_tokens where school_id = p_school_id;
  if t.school_id is not null then
    delete from vault.secrets where id in (t.access_secret_id, t.refresh_secret_id);
    delete from private.qbo_tokens where school_id = p_school_id;
  end if;
  update public.qbo_connections set status = 'disconnected', access_expires_at = null where school_id = p_school_id;
end;
$$;

-- Sync health for the Settings > QuickBooks card.
create or replace function public.qbo_sync_status(p_school_id uuid)
returns table (status text, company_name text, last_sync_at timestamptz, last_error text,
               queued int, failed int, dead int, refresh_expires_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_school_id not in (select private.pay_school_ids()) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  return query
    select c.status, c.company_name, c.last_sync_at, c.last_error,
           (select count(*)::int from private.qbo_sync_jobs j where j.school_id = p_school_id and j.status = 'queued'),
           (select count(*)::int from private.qbo_sync_jobs j where j.school_id = p_school_id and j.status = 'failed'),
           (select count(*)::int from private.qbo_sync_jobs j where j.school_id = p_school_id and j.status = 'dead'),
           c.refresh_expires_at
      from public.qbo_connections c where c.school_id = p_school_id;
end;
$$;

revoke all on function public.qbo_begin_connect(uuid) from public, anon;
revoke all on function public.qbo_disconnect(uuid) from public, anon;
revoke all on function public.qbo_sync_status(uuid) from public, anon;
grant execute on function public.qbo_begin_connect(uuid) to authenticated;
grant execute on function public.qbo_disconnect(uuid) to authenticated;
grant execute on function public.qbo_sync_status(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Service-only RPCs (Edge Functions with the service_role key). Not executable by apps.
-- ---------------------------------------------------------------------------
create or replace function public.svc_qbo_consume_state(p_state text)
returns table (school_id uuid, user_id uuid)
language sql security definer set search_path = ''
as $$
  delete from private.qbo_oauth_states s
   where s.state_hash = encode(extensions.digest(p_state, 'sha256'), 'hex') and s.expires_at > now()
  returning s.school_id, s.user_id;
$$;

create or replace function public.svc_qbo_store_tokens(
  p_school_id uuid, p_realm_id text, p_access_token text, p_refresh_token text,
  p_access_expires_in int, p_refresh_expires_in int,
  p_user_id uuid default null, p_environment text default 'production', p_company_name text default null
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  t private.qbo_tokens;
  a uuid; r uuid;
begin
  if exists (select 1 from public.qbo_connections where realm_id = p_realm_id and school_id <> p_school_id) then
    raise exception 'This QuickBooks company is already connected to another school' using errcode = '23505';
  end if;
  select * into t from private.qbo_tokens where school_id = p_school_id;
  if t.school_id is null then
    a := vault.create_secret(p_access_token, 'qbo_access:' || p_school_id, 'QuickBooks access token');
    r := vault.create_secret(p_refresh_token, 'qbo_refresh:' || p_school_id, 'QuickBooks refresh token');
    insert into private.qbo_tokens (school_id, access_secret_id, refresh_secret_id) values (p_school_id, a, r);
  else
    perform vault.update_secret(t.access_secret_id, p_access_token);
    perform vault.update_secret(t.refresh_secret_id, p_refresh_token);
    update private.qbo_tokens set updated_at = now() where school_id = p_school_id;
  end if;

  insert into public.qbo_connections (school_id, realm_id, environment, company_name, status,
                                      access_expires_at, refresh_expires_at, connected_by)
  values (p_school_id, p_realm_id, coalesce(p_environment, 'production'), coalesce(p_company_name, ''), 'connected',
          now() + make_interval(secs => p_access_expires_in), now() + make_interval(secs => p_refresh_expires_in), p_user_id)
  on conflict (school_id) do update set
    realm_id = excluded.realm_id,
    environment = excluded.environment,
    company_name = coalesce(nullif(excluded.company_name, ''), public.qbo_connections.company_name),
    status = 'connected',
    access_expires_at = excluded.access_expires_at,
    refresh_expires_at = excluded.refresh_expires_at,
    connected_by = coalesce(excluded.connected_by, public.qbo_connections.connected_by),
    last_error = null;
end;
$$;

create or replace function public.svc_qbo_get_tokens(p_school_id uuid)
returns table (realm_id text, environment text, access_token text, refresh_token text, access_expires_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select c.realm_id, c.environment, a.decrypted_secret, r.decrypted_secret, c.access_expires_at
    from public.qbo_connections c
    join private.qbo_tokens t on t.school_id = c.school_id
    join vault.decrypted_secrets a on a.id = t.access_secret_id
    join vault.decrypted_secrets r on r.id = t.refresh_secret_id
   where c.school_id = p_school_id and c.status = 'connected';
$$;

create or replace function public.svc_qbo_mark_error(p_school_id uuid, p_error text, p_needs_reauth boolean default false)
returns void
language sql security definer set search_path = ''
as $$
  update public.qbo_connections
     set last_error = left(p_error, 500),
         status = case when p_needs_reauth then 'needs_reauth' else status end
   where school_id = p_school_id;
$$;

create or replace function public.svc_qbo_due_for_refresh(p_within_minutes int default 15)
returns table (school_id uuid)
language sql stable security definer set search_path = ''
as $$
  select c.school_id from public.qbo_connections c
   where c.status = 'connected'
     and (c.access_expires_at is null or c.access_expires_at < now() + make_interval(mins => p_within_minutes));
$$;

-- Webhook receiver hands us the CloudEvents array; returns how many were new.
create or replace function public.svc_qbo_record_events(p_events jsonb)
returns int
language plpgsql security definer set search_path = ''
as $$
declare
  e jsonb;
  v_school uuid;
  v_entity text;
  n int := 0;
  inserted boolean;
begin
  for e in select * from jsonb_array_elements(coalesce(p_events, '[]'::jsonb)) loop
    continue when e ->> 'id' is null or e ->> 'intuitaccountid' is null or e ->> 'intuitentityid' is null;
    inserted := null;
    insert into private.qbo_webhook_events (event_id, realm_id, event_type, entity_id, event_time)
    values (e ->> 'id', e ->> 'intuitaccountid', coalesce(e ->> 'type', ''), e ->> 'intuitentityid',
            nullif(e ->> 'time', '')::timestamptz)
    on conflict (event_id) do nothing
    returning true into inserted;
    continue when inserted is null;
    n := n + 1;

    v_entity := split_part(e ->> 'type', '.', 2);       -- qbo.invoice.updated.v1 -> invoice
    continue when v_entity not in ('customer', 'invoice', 'payment');
    select school_id into v_school from public.qbo_connections
     where realm_id = e ->> 'intuitaccountid' and status = 'connected';
    continue when v_school is null;

    insert into private.qbo_sync_jobs (school_id, direction, entity, qbo_id, source_event_id)
    values (v_school, 'pull', v_entity, e ->> 'intuitentityid', e ->> 'id')
    on conflict (school_id, entity, qbo_id) where direction = 'pull' and status in ('queued', 'running', 'failed')
    do nothing;
  end loop;
  return n;
end;
$$;

-- Claim due jobs (safe to run from several workers: SKIP LOCKED).
create or replace function public.svc_qbo_claim_jobs(p_limit int default 20)
returns table (id uuid, school_id uuid, direction text, entity text, local_id uuid, qbo_id text, attempts int, payload jsonb)
language plpgsql security definer set search_path = ''
as $$
begin
  return query
  with due as (
    select j.id from private.qbo_sync_jobs j
     where j.status in ('queued', 'failed') and j.next_attempt_at <= now()
        or (j.status = 'running' and j.locked_until < now())
     order by j.next_attempt_at
     limit least(greatest(coalesce(p_limit, 20), 1), 100)
     for update skip locked
  ), upd as (
    update private.qbo_sync_jobs j
       set status = 'running', attempts = j.attempts + 1, locked_until = now() + interval '5 minutes', updated_at = now()
      from due where j.id = due.id
    returning j.*
  )
  select u.id, u.school_id, u.direction, u.entity, u.local_id, u.qbo_id, u.attempts,
         case when u.direction = 'push' and u.entity = 'customer' then
                (select to_jsonb(c) from public.billing_customers c where c.id = u.local_id)
              when u.direction = 'push' and u.entity = 'invoice' then
                (select to_jsonb(i) || jsonb_build_object(
                          'lines', coalesce((select jsonb_agg(to_jsonb(l) order by l.line_no)
                                               from public.invoice_lines l where l.invoice_id = i.id), '[]'::jsonb),
                          'customer_qbo_id', (select c.qbo_customer_id from public.billing_customers c where c.id = i.customer_id))
                   from public.invoices i where i.id = u.local_id)
              when u.direction = 'push' and u.entity = 'payment' then
                (select to_jsonb(p) || jsonb_build_object(
                          'customer_qbo_id', (select c.qbo_customer_id from public.billing_customers c where c.id = p.customer_id),
                          'invoice_qbo_id', (select i.qbo_invoice_id from public.invoices i where i.id = p.invoice_id))
                   from public.payments p where p.id = u.local_id)
         end
    from upd u;
end;
$$;

-- Finish a job. On failure: exponential backoff (2, 4, 8 ... min), "dead" after 8 tries.
create or replace function public.svc_qbo_finish_job(
  p_job_id uuid, p_ok boolean, p_error text default null,
  p_qbo_id text default null, p_sync_token text default null, p_qbo_updated_at timestamptz default null
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  j private.qbo_sync_jobs;
begin
  select * into j from private.qbo_sync_jobs where id = p_job_id for update;
  if j.id is null then return; end if;

  if p_ok then
    update private.qbo_sync_jobs set status = 'done', last_error = null, locked_until = null, updated_at = now()
     where id = p_job_id;
    if j.direction = 'push' then
      if j.entity = 'customer' then
        update public.billing_customers set qbo_customer_id = coalesce(p_qbo_id, qbo_customer_id),
               qbo_sync_token = coalesce(p_sync_token, qbo_sync_token), qbo_updated_at = coalesce(p_qbo_updated_at, qbo_updated_at),
               sync_status = 'synced', sync_error = null where id = j.local_id;
      elsif j.entity = 'invoice' then
        update public.invoices set qbo_invoice_id = coalesce(p_qbo_id, qbo_invoice_id),
               qbo_sync_token = coalesce(p_sync_token, qbo_sync_token), qbo_updated_at = coalesce(p_qbo_updated_at, qbo_updated_at),
               sync_status = 'synced', sync_error = null where id = j.local_id;
      else
        update public.payments set qbo_payment_id = coalesce(p_qbo_id, qbo_payment_id),
               qbo_sync_token = coalesce(p_sync_token, qbo_sync_token), qbo_updated_at = coalesce(p_qbo_updated_at, qbo_updated_at),
               sync_status = 'synced', sync_error = null where id = j.local_id;
      end if;
    end if;
    update public.qbo_connections set last_sync_at = now(), last_error = null where school_id = j.school_id;
  else
    update private.qbo_sync_jobs
       set status = case when j.attempts >= 8 then 'dead' else 'failed' end,
           last_error = left(p_error, 1000),
           next_attempt_at = now() + make_interval(mins => power(2, least(j.attempts, 10))::int),
           locked_until = null, updated_at = now()
     where id = p_job_id;
    if j.direction = 'push' and j.attempts >= 8 then
      if j.entity = 'customer' then update public.billing_customers set sync_status = 'error', sync_error = left(p_error, 500) where id = j.local_id;
      elsif j.entity = 'invoice' then update public.invoices set sync_status = 'error', sync_error = left(p_error, 500) where id = j.local_id;
      else update public.payments set sync_status = 'error', sync_error = left(p_error, 500) where id = j.local_id; end if;
    end if;
  end if;
end;
$$;

-- Apply an entity read from QuickBooks (pull). Ignores stale data (older LastUpdatedTime).
create or replace function public.svc_qbo_apply_entity(p_school_id uuid, p_entity text, p_obj jsonb)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  qid text := p_obj ->> 'Id';
  tok text := p_obj ->> 'SyncToken';
  upd timestamptz := nullif(p_obj #>> '{MetaData,LastUpdatedTime}', '')::timestamptz;
  cust uuid;
  out_id uuid;
  inv uuid;
begin
  if qid is null then raise exception 'QuickBooks object has no Id'; end if;

  if p_entity = 'customer' then
    insert into public.billing_customers (school_id, display_name, email, phone, active, qbo_customer_id,
                                          qbo_sync_token, qbo_updated_at, sync_status)
    values (p_school_id, left(coalesce(p_obj ->> 'DisplayName', 'Customer ' || qid), 100),
            coalesce(p_obj #>> '{PrimaryEmailAddr,Address}', ''), coalesce(p_obj #>> '{PrimaryPhone,FreeFormNumber}', ''),
            coalesce((p_obj ->> 'Active')::boolean, true), qid, tok, upd, 'synced')
    on conflict (school_id, qbo_customer_id) do update set
      display_name = excluded.display_name, email = excluded.email, phone = excluded.phone, active = excluded.active,
      qbo_sync_token = excluded.qbo_sync_token, qbo_updated_at = excluded.qbo_updated_at, sync_status = 'synced', sync_error = null
      where public.billing_customers.qbo_updated_at is null or excluded.qbo_updated_at >= public.billing_customers.qbo_updated_at
    returning id into out_id;

  elsif p_entity = 'invoice' then
    select id into cust from public.billing_customers
     where school_id = p_school_id and qbo_customer_id = p_obj #>> '{CustomerRef,value}';
    if cust is null then
      insert into public.billing_customers (school_id, display_name, qbo_customer_id, sync_status)
      values (p_school_id, left(coalesce(p_obj #>> '{CustomerRef,name}', 'Customer'), 100), p_obj #>> '{CustomerRef,value}', 'synced')
      returning id into cust;
      -- full customer details arrive with their own webhook / the nightly CDC sweep
    end if;
    insert into public.invoices (school_id, customer_id, student_id, doc_number, txn_date, due_date, currency,
                                 total, balance, tax, subtotal, status, qbo_invoice_id, qbo_sync_token, qbo_updated_at, sync_status)
    values (p_school_id, cust, (select student_id from public.billing_customers where id = cust),
            p_obj ->> 'DocNumber', coalesce((p_obj ->> 'TxnDate')::date, current_date), (p_obj ->> 'DueDate')::date,
            coalesce(p_obj #>> '{CurrencyRef,value}', 'USD'),
            coalesce((p_obj ->> 'TotalAmt')::numeric, 0), coalesce((p_obj ->> 'Balance')::numeric, 0),
            coalesce((p_obj #>> '{TxnTaxDetail,TotalTax}')::numeric, 0),
            coalesce((p_obj ->> 'TotalAmt')::numeric, 0) - coalesce((p_obj #>> '{TxnTaxDetail,TotalTax}')::numeric, 0),
            case when coalesce((p_obj ->> 'Balance')::numeric, 0) = 0 then 'paid'
                 when coalesce((p_obj ->> 'Balance')::numeric, 0) < coalesce((p_obj ->> 'TotalAmt')::numeric, 0) then 'partially_paid'
                 else 'open' end,
            qid, tok, upd, 'synced')
    on conflict (school_id, qbo_invoice_id) do update set
      customer_id = excluded.customer_id, doc_number = excluded.doc_number, txn_date = excluded.txn_date,
      due_date = excluded.due_date, total = excluded.total, balance = excluded.balance, tax = excluded.tax,
      subtotal = excluded.subtotal, status = case when public.invoices.status = 'void' then 'void' else excluded.status end,
      qbo_sync_token = excluded.qbo_sync_token, qbo_updated_at = excluded.qbo_updated_at, sync_status = 'synced', sync_error = null
      where public.invoices.qbo_updated_at is null or excluded.qbo_updated_at >= public.invoices.qbo_updated_at
    returning id into out_id;

  elsif p_entity = 'payment' then
    select id into cust from public.billing_customers
     where school_id = p_school_id and qbo_customer_id = p_obj #>> '{CustomerRef,value}';
    if cust is null then
      insert into public.billing_customers (school_id, display_name, qbo_customer_id, sync_status)
      values (p_school_id, left(coalesce(p_obj #>> '{CustomerRef,name}', 'Customer'), 100), p_obj #>> '{CustomerRef,value}', 'synced')
      returning id into cust;
    end if;
    select i.id into inv from public.invoices i
     where i.school_id = p_school_id
       and i.qbo_invoice_id = (select l #>> '{LinkedTxn,0,TxnId}' from jsonb_array_elements(coalesce(p_obj -> 'Line', '[]'::jsonb)) l
                                where l #>> '{LinkedTxn,0,TxnType}' = 'Invoice' limit 1);
    insert into public.payments (school_id, customer_id, invoice_id, student_id, amount, received_on, reference,
                                 qbo_payment_id, qbo_sync_token, qbo_updated_at, sync_status)
    values (p_school_id, cust, inv, (select student_id from public.billing_customers where id = cust),
            greatest(coalesce((p_obj ->> 'TotalAmt')::numeric, 0), 0.01),
            coalesce((p_obj ->> 'TxnDate')::date, current_date), left(coalesce(p_obj ->> 'PaymentRefNum', ''), 100),
            qid, tok, upd, 'synced')
    on conflict (school_id, qbo_payment_id) do update set
      customer_id = excluded.customer_id, invoice_id = excluded.invoice_id, amount = excluded.amount,
      received_on = excluded.received_on, reference = excluded.reference,
      qbo_sync_token = excluded.qbo_sync_token, qbo_updated_at = excluded.qbo_updated_at, sync_status = 'synced', sync_error = null
      where public.payments.qbo_updated_at is null or excluded.qbo_updated_at >= public.payments.qbo_updated_at
    returning id into out_id;
  else
    raise exception 'Unknown entity %', p_entity;
  end if;
  return out_id;
end;
$$;

-- Entity deleted/voided in QuickBooks.
create or replace function public.svc_qbo_mark_deleted(p_school_id uuid, p_entity text, p_qbo_id text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if p_entity = 'invoice' then
    update public.invoices set status = 'void', balance = 0 where school_id = p_school_id and qbo_invoice_id = p_qbo_id;
  elsif p_entity = 'customer' then
    update public.billing_customers set active = false where school_id = p_school_id and qbo_customer_id = p_qbo_id;
  elsif p_entity = 'payment' then
    delete from public.payments where school_id = p_school_id and qbo_payment_id = p_qbo_id;
  end if;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.svc_qbo_consume_state(text)',
    'public.svc_qbo_store_tokens(uuid, text, text, text, int, int, uuid, text, text)',
    'public.svc_qbo_get_tokens(uuid)',
    'public.svc_qbo_mark_error(uuid, text, boolean)',
    'public.svc_qbo_due_for_refresh(int)',
    'public.svc_qbo_record_events(jsonb)',
    'public.svc_qbo_claim_jobs(int)',
    'public.svc_qbo_finish_job(uuid, boolean, text, text, text, timestamptz)',
    'public.svc_qbo_apply_entity(uuid, text, jsonb)',
    'public.svc_qbo_mark_deleted(uuid, text, text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
