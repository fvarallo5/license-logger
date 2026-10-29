-- NOT APPLIED — Phase 3. Frank must type "push" before applying.
-- device_push_tokens: staff PWA + student app push endpoints (APNs / FCM / Web Push).
-- Pattern adapted from TrekTrack. Edge send-notifications will read this after deploy.

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('web', 'ios', 'android')),
  token text not null,
  endpoint text,
  p256dh text,
  auth text,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, platform, token)
);

create index if not exists device_push_tokens_user_id_idx
  on public.device_push_tokens (user_id);

comment on table public.device_push_tokens is
  'Push endpoints for desk PWA (web) and native apps. Service role sends; users manage own rows.';

alter table public.device_push_tokens enable row level security;
alter table public.device_push_tokens force row level security;

revoke all on table public.device_push_tokens from public;
revoke all on table public.device_push_tokens from anon;

drop policy if exists "Users read own device_push_tokens" on public.device_push_tokens;
create policy "Users read own device_push_tokens"
  on public.device_push_tokens for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users upsert own device_push_tokens" on public.device_push_tokens;
create policy "Users upsert own device_push_tokens"
  on public.device_push_tokens for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users update own device_push_tokens" on public.device_push_tokens;
create policy "Users update own device_push_tokens"
  on public.device_push_tokens for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users delete own device_push_tokens" on public.device_push_tokens;
create policy "Users delete own device_push_tokens"
  on public.device_push_tokens for delete
  to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on public.device_push_tokens to authenticated;
grant all on public.device_push_tokens to service_role;

-- Optional: register web push subscription (SECURITY DEFINER, locked search_path)
create or replace function public.register_web_push(
  p_endpoint text,
  p_p256dh text,
  p_auth text,
  p_user_agent text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into public.device_push_tokens (user_id, platform, token, endpoint, p256dh, auth, user_agent)
  values (auth.uid(), 'web', p_endpoint, p_endpoint, p_p256dh, p_auth, p_user_agent)
  on conflict (user_id, platform, token) do update
    set p256dh = excluded.p256dh,
        auth = excluded.auth,
        user_agent = excluded.user_agent,
        updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.register_web_push(text, text, text, text) from public;
revoke all on function public.register_web_push(text, text, text, text) from anon;
grant execute on function public.register_web_push(text, text, text, text) to authenticated;
