-- READ-ONLY checks to run against the live project BEFORE `supabase db push`.
-- Nothing here writes. Paste into the SQL Editor (or `psql`) and compare with the expected results.

-- 1) The live history must be exactly the 4 migrations this repo starts with.
--    Expected: 20261019175634 schools, 20261019175702 school_fk_indexes,
--              20261019181531 students, 20261020213528 lots_cars
select version, name from supabase_migrations.schema_migrations order by version;

-- 2) None of the new tables may exist yet (expected: 0 rows).
select table_schema, table_name from information_schema.tables
 where (table_schema, table_name) in (
   ('public','audit_log'), ('public','state_rule_sets'), ('public','family_links'), ('public','family_invites'),
   ('public','supervisors'), ('public','drives'), ('public','drive_route_chunks'), ('public','drive_signoffs'),
   ('public','lessons'), ('public','billing_customers'), ('public','invoices'), ('public','invoice_lines'),
   ('public','payments'), ('public','qbo_connections'), ('public','exports'),
   ('public','school_enrollments'), ('public','school_link_requests'), ('public','student_rule_milestones'));

-- 3) Columns the migrations add must not exist yet (expected: 0 rows).
select table_name, column_name from information_schema.columns
 where table_schema = 'public'
   and ((table_name = 'profiles' and column_name in ('account_type', 'notify_email', 'updated_at'))
     or (table_name = 'students' and column_name in ('rule_set_id', 'rule_alternative')));

-- 4) Extensions available (btree_gist is installed by migration 005; expected: a row with installed_version null or set).
select name, installed_version from pg_available_extensions where name in ('btree_gist', 'pgcrypto', 'supabase_vault', 'pg_cron', 'pg_net');

-- 5) Data volume (so you know what a backup contains).
select (select count(*) from auth.users) as users, (select count(*) from public.schools) as schools,
       (select count(*) from public.students) as students;

-- 6) Independent students (migration 013). Before the push, live still requires a school:
--    expected is_nullable = 'NO' and 0 students without a school. After the push: 'YES'.
select is_nullable from information_schema.columns
 where table_schema = 'public' and table_name = 'students' and column_name = 'school_id';
select count(*) as students_without_school from public.students where school_id is null;
-- No triggers of ours on students yet (expected: only live ones, none named students_*_school_change).
select tgname from pg_trigger where tgrelid = 'public.students'::regclass and not tgisinternal;

-- 7) State rules v2 (migrations 014 + 015). Function names they create must not exist on live
--    (expected: 0 rows), and live students' states/permit dates show which rule each will get.
select n.nspname, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where (n.nspname, p.proname) in (('public','student_rule_progress'), ('public','state_resources'), ('public','my_rule_resources'),
                                  ('public','set_rule_alternative'), ('public','set_rule_milestone'), ('private','rule_credit'),
                                  ('private','rule_for_state'));
select state_code, count(*) as students, min(permit_on) as earliest_permit, count(*) filter (where permit_on is null) as no_permit_date
  from public.students group by state_code order by state_code;
