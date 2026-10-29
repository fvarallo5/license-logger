-- Family invite codes, student join codes, rate limiting.
begin;
\ir 00_helpers.psql
select no_plan();

-- Maya makes a code for her grandma (the "stranger" account)
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
create temporary table inv on commit drop as
  select create_family_invite('20000000-0000-4000-8000-000000000001', 'guardian', 1, 'grandma@nowhere.example') as j;
grant select on inv to authenticated;
select matches((select j ->> 'code' from inv), '^LL-[2-9A-HJKMNP-Z]{4}-[2-9A-HJKMNP-Z]{2}$', 'code looks like LL-7Q4K-M2 (no 0/O/1/I/L)');
select is((select count(*)::int from family_invites where code_hint = right(regexp_replace((select j ->> 'code' from inv), '-', '', 'g'), 2)), 1,
          'only a 2-character hint is visible');
select is((select redeem_family_invite((select j ->> 'code' from inv)) ->> 'status'), 'own_code', 'student cannot redeem her own code');
reset role;
select is((select count(*)::int from family_invites where code_hash like '%' || (select replace(j ->> 'code', '-', '') from inv) || '%'), 0,
          'the raw code is never stored');
select is((select count(*)::int from private.notification_outbox where payload::text like '%' || (select replace(j ->> 'code', '-', '') from inv) || '%'
             or payload::text like '%' || (select j ->> 'code' from inv) || '%'), 0, 'the code is not sitting in the email queue either');

-- Stranger can't create codes for Maya before being linked
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;
select throws_ok($$ select create_family_invite('20000000-0000-4000-8000-000000000001') $$, '42501', null,
                 'unlinked user cannot create an invite');
select is((redeem_family_invite(lower(replace((select j ->> 'code' from inv), '-', ' '))) ->> 'status'), 'ok',
          'code works typed lower-case with spaces');
select is((select count(*)::int from students), 1, 'now sees Maya');
select is((select count(*)::int from drives), 14, 'and Maya''s drives');
select is((select count(*)::int from supervisors where user_id = '00000000-0000-4000-8000-000000000041'), 1,
          'and was added to Maya''s supervisor picker');
select is((select account_type from profiles where id = '00000000-0000-4000-8000-000000000041'), 'family', 'account type set to family');
reset role;

-- Single-use code is now used up
select pg_temp.login('00000000-0000-4000-8000-000000000031'); set local role authenticated;
select is((redeem_family_invite((select j ->> 'code' from inv)) ->> 'status'), 'expired', 'max_uses reached');
-- Rate limit: 10 bad tries per hour (the expired try above counted as one)
select redeem_family_invite('LL-AAAA-A' || g) from generate_series(1, 9) g;
select is((redeem_family_invite('LL-BBBB-BB') ->> 'status'), 'rate_limited', 'brute force is rate limited');
reset role;

-- Maya removes grandma
select pg_temp.login('00000000-0000-4000-8000-000000000011'); set local role authenticated;
select lives_ok($$ select revoke_family_link((select id from family_links where user_id = '00000000-0000-4000-8000-000000000041')) $$,
                'student can remove a family link');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000041'); set local role authenticated;
select is((select count(*)::int from drives), 0, 'removed family member loses access immediately');
select is((select count(*)::int from my_students()), 0, 'and the student disappears from their switcher');
-- Claim a roster seat with the school's join code
select is((claim_student_profile('riley4') ->> 'status'), 'ok', 'join code (any case) links the account to the roster row');
select is((select count(*)::int from students where id = '20000000-0000-4000-8000-000000000004'), 1, 'now sees own student row');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000031'); set local role authenticated;
select is((claim_student_profile('NOPE99') ->> 'status'), 'invalid', 'join-code attempts are rate limited separately from invite codes');
reset role;
select pg_temp.login('00000000-0000-4000-8000-000000000012'); set local role authenticated;
select is((claim_student_profile('RILEY4') ->> 'status'), 'invalid', 'an already-claimed seat cannot be taken');
reset role;

-- Desk staff can invite for any student in their school, not others
select pg_temp.login('00000000-0000-4000-8000-000000000003'); set local role authenticated;
select ok((create_family_invite('20000000-0000-4000-8000-000000000001') ->> 'code') is not null, 'front desk can create a code');
select throws_ok($$ select create_family_invite('20000000-0000-4000-8000-000000000003') $$, '42501', null,
                 'front desk cannot create codes for another school');
reset role;

select * from finish();
rollback;
