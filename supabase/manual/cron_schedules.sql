-- UPDATED 2026-10-30: still NOT a migration. Enable pg_cron + pg_net in Dashboard first.
-- Replace <project-ref> with nqfjudwncistygsmcgrq and set LL_APP_LINK=https://app.licenselogger.com
-- on Edge Function secrets. Run only after Frank types "push" for related migrations AND
-- Edge Functions are deployed.

-- Background jobs. NOT a migration: run it once per environment (staging, then production)
-- in the SQL Editor AFTER the Edge Functions are deployed and their secrets are set.
-- Needs the pg_cron and pg_net extensions (Dashboard > Integrations > Cron / Database > Extensions).
-- Replace the two <...> values first. They are stored in Vault, not in this file or in cron.job.

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- 1) Store the project URL and the same CRON_SECRET you set with `supabase secrets set`.
select vault.create_secret('https://<project-ref>.supabase.co', 'll_project_url', 'LicenseLogger cron target');
select vault.create_secret('<same value as the CRON_SECRET function secret>', 'll_cron_secret', 'LicenseLogger cron auth');

-- 2) Helper that calls one of our functions with the secret header.
create or replace function private.call_function(p_name text, p_query text default '')
returns bigint
language sql
security definer
set search_path = ''
as $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'll_project_url')
           || '/functions/v1/' || p_name || p_query,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'll_cron_secret')),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000);
$$;
revoke all on function private.call_function(text, text) from public, anon, authenticated;

-- 3) Schedules (re-running this file replaces them).
select cron.unschedule(jobname) from cron.job
 where jobname in ('ll-send-notifications', 'll-qbo-sync', 'll-qbo-refresh', 'll-housekeeping');

select cron.schedule('ll-send-notifications', '* * * * *',    $$ select private.call_function('send-notifications') $$);
select cron.schedule('ll-qbo-sync',           '* * * * *',    $$ select private.call_function('qbo-sync') $$);
select cron.schedule('ll-qbo-refresh',        '*/30 * * * *', $$ select private.call_function('qbo-refresh') $$);
select cron.schedule('ll-housekeeping',       '15 8 * * *',   $$ select private.call_function('send-notifications', '?housekeeping=1') $$);

-- Check: select jobname, schedule, active from cron.job;
--        select status, return_message, start_time from cron.job_run_details order by start_time desc limit 20;
