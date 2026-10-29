-- Guard rails from the TrekTrack audit, enforced as tests so they stay true.
begin;
\ir 00_helpers.psql
select no_plan();

select is(
  (select coalesce(string_agg(n.nspname || '.' || c.relname, ', '), '') from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and c.relkind in ('r', 'p') and not c.relrowsecurity),
  '', 'every table in public/private has RLS enabled');

select is(
  (select coalesce(string_agg(n.nspname || '.' || c.relname, ', '), '') from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and c.relkind in ('r', 'p') and not c.relforcerowsecurity),
  '', 'every table has RLS forced (even for the table owner)');

select is(
  (select coalesce(string_agg(schemaname || '.' || tablename || ':' || policyname, ', '), '') from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') ~ 'auth\.uid\(\)' or coalesce(with_check, '') ~ 'auth\.uid\(\)')
      and not (coalesce(qual, '') || coalesce(with_check, '')) ~ '\(\s*SELECT auth\.uid\(\) AS uid\)'),
  '', 'no policy calls auth.uid() bare (always (select auth.uid()))');

select is(
  (select coalesce(string_agg(schemaname || '.' || tablename || ':' || policyname, ', '), '') from pg_policies
    where schemaname = 'public' and not ('authenticated' = any (roles))),
  '', 'every policy is scoped TO authenticated (nothing for anon)');

select is(
  (select coalesce(string_agg(c.conrelid::regclass::text || '(' || c.conname || ')', ', '), '')
     from pg_constraint c
     join pg_class t on t.oid = c.conrelid
     join pg_namespace n on n.oid = t.relnamespace
    where c.contype = 'f' and n.nspname in ('public', 'private') and t.relispartition = false
      and not exists (
        select 1 from pg_index i
         where i.indrelid = c.conrelid
           and (i.indkey::int2[])[0:cardinality(c.conkey) - 1] = c.conkey)),
  '', 'every foreign key has a covering index');

select is(
  (select coalesce(string_agg(p.oid::regprocedure::text, ', '), '') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private') and p.prokind = 'f'
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%')),
  '', 'every function has a fixed search_path');

select is(
  (select coalesce(string_agg(p.oid::regprocedure::text, ', '), '') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'svc\_%' and has_function_privilege('authenticated', p.oid, 'execute')),
  '', 'no svc_* function is executable by app users');

select is(
  (select coalesce(string_agg(p.oid::regprocedure::text, ', '), '') from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'execute')),
  '', 'signed-out visitors can execute no public function');

select is(
  (select coalesce(string_agg(c.relname, ', '), '') from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p', 'v')
      and has_table_privilege('anon', c.oid, 'select')),
  '', 'signed-out visitors can read no table');

select is(
  (select coalesce(string_agg(table_name || '.' || column_name, ', '), '') from information_schema.columns
    where table_schema = 'public' and data_type in ('real', 'double precision', 'money')),
  '', 'no floating-point/money columns (numeric with fixed scale instead)');

select is(
  (select coalesce(string_agg(c.relname || ':' || r.rolname, ', '), '') from pg_class c join pg_namespace n on n.oid = c.relnamespace
     cross join (values ('anon'), ('authenticated')) r(rolname)
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and (has_table_privilege(r.rolname, c.oid, 'truncate') or has_table_privilege(r.rolname, c.oid, 'trigger')
           or has_table_privilege(r.rolname, c.oid, 'references'))),
  '', 'app roles cannot TRUNCATE (bypasses RLS), add triggers or reference any table');

select is(
  (select coalesce(string_agg(n.nspname || '.' || c.relname, ', '), '') from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'private' and c.relkind in ('r', 'p')
      and (has_table_privilege('authenticated', c.oid, 'select') or has_table_privilege('anon', c.oid, 'select'))),
  '', 'private tables are unreadable by app roles');

select * from finish();
rollback;
