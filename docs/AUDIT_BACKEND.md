# Backend audit notes — 2026-10-30

## Security advisor
- Private tables + route-chunk partitions: RLS on, no policies → intentional deny for clients; zip locks partition grants.
- 54× authenticated can execute SECURITY DEFINER public RPCs → **intentional** desk API; anon already revoked; zip re-asserts revoke anon.
- Auth leaked password protection disabled → Frank toggle (not SQL).

## Performance advisor
- Unindexed FKs: `instructor_pay_runs(instructor_id, created_by)` → migration.
- Multiple permissive policies on `instructor_pay_runs` → split ALL policy.
- Multiple permissive on `schools` / `students` SELECT → kept (member vs family are different predicates; merging risks correctness). Documented only.
- 96 unused indexes → expected on empty/low-traffic tables; do **not** drop yet.

## Other
- RLS policies already use `(select auth.uid())` form — good.
- SECURITY DEFINER functions already `search_path=''` — good.
- `pg_cron` not installed — manual SQL ready.
- Edge: cron secret compare is constant-time; added isolate rate limits + JSON caps.
