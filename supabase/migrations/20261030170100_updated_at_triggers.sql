-- Applied 2026-10-30 on nqfjudwncistygsmcgrq.
-- Attach private.touch_updated_at() where updated_at exists but no trigger yet.

do $$
begin
  if not exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'device_push_tokens'
      and not t.tgisinternal and t.tgname = 'device_push_tokens_touch_updated_at'
  ) then
    create trigger device_push_tokens_touch_updated_at
      before update on public.device_push_tokens
      for each row execute function private.touch_updated_at();
  end if;
end $$;

-- drives already bumps updated_at inside a BEFORE trigger in some paths;
-- add a dedicated touch trigger only if none mention updated_at.
do $$
begin
  if not exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'drives'
      and not t.tgisinternal
      and pg_get_triggerdef(t.oid) ilike '%updated_at%'
  ) then
    create trigger drives_touch_updated_at
      before update on public.drives
      for each row execute function private.touch_updated_at();
  end if;
end $$;
