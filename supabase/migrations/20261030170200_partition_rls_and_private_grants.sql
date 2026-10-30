-- Applied 2026-10-30 on nqfjudwncistygsmcgrq.
-- 1) Route-chunk partitions: RLS on + no policies (advisor INFO). Parent already
--    has SELECT/INSERT for authenticated. Lock partitions down: no direct grants,
--    keep RLS forced with zero policies (= deny for non-owner).
-- 2) Belt-and-suspenders: revoke EXECUTE on private.* from anon (never needed).
--    Keep authenticated EXECUTE on private helpers used inside RLS expressions.

revoke all on table public.drive_route_chunks_p0 from public, anon, authenticated;
revoke all on table public.drive_route_chunks_p1 from public, anon, authenticated;
revoke all on table public.drive_route_chunks_p2 from public, anon, authenticated;
revoke all on table public.drive_route_chunks_p3 from public, anon, authenticated;
grant all on table public.drive_route_chunks_p0 to service_role;
grant all on table public.drive_route_chunks_p1 to service_role;
grant all on table public.drive_route_chunks_p2 to service_role;
grant all on table public.drive_route_chunks_p3 to service_role;

-- Private schema must never be reachable by anon.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
  end loop;
end $$;

-- Public SECURITY DEFINER RPCs: ensure anon cannot execute (authenticated stays).
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and p.proname not like 'svc_%'
  loop
    execute format('revoke all on function %s from public, anon', r.sig);
  end loop;
end $$;

-- Service-only RPCs (cron / edge): revoke from authenticated too if present.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'svc_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    execute format('grant execute on function %s to service_role', r.sig);
  end loop;
end $$;
