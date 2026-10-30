# Backend upgrades — 2026-10-30

## Already live (do not re-apply)

These were previously listed as waiting for “push” but **are applied** on `nqfjudwncistygsmcgrq` (see `list_migrations` / PR #4 `7b276e7`):

- `reassign_lesson` (`20261029184409`)
- `fleet_compliance` (`20261029192814`)
- `device_push_tokens` (`20261029192816`)
- `pay_packages_lockdown` (`20261029192818`)
- `instructor_pay` (`20261029192822`)
- `skills_checklist_rpc` (`20261029192825`)
- `request_slot_family` (`20261029192841`)

This zip’s migrations were **new**; applied live 2026-10-30 (MCP `apply_migration`, not kit `db push`).

## New migrations (applied 2026-10-30)

| File | Purpose |
|---|---|
| `20261030170000_pay_runs_indexes_policies.sql` | FK indexes + split overlapping RLS on `instructor_pay_runs` |
| `20261030170100_updated_at_triggers.sql` | `touch_updated_at` on `device_push_tokens` (+ drives if missing) |
| `20261030170200_partition_rls_and_private_grants.sql` | Lock route-chunk partitions; revoke anon on private/public definer RPCs; svc_* service-only |
| `20261030170300_audit_rpc_touchpoints.sql` | `private.audit_safe` helper for best-effort audit inserts |

## Edge Functions

- `_shared/validate.ts`, `_shared/rate_limit.ts`
- `send-notifications` — correct default `LL_APP_LINK`, isolate rate limit
- `family-invite` — JSON size cap, UUID/email validation, rate limit, app link
- `export-report` — UUID validation + isolate rate limit (DB hourly cap kept)

Edge functions `send-notifications`, `family-invite`, `export-report` redeployed with this pack.

## Types

`apps/dashboard/src/lib/database.types.ts` — generated from live schema. Optional: switch `createClient` to `createClient<Database>(…)`.

## Frank dashboard toggles (not SQL)

1. Auth → enable **Leaked password protection**
2. Enable **pg_cron** + **pg_net**, then run `supabase/manual/cron_schedules.sql` (with vault secrets) after functions are deployed
3. Set function secret `LL_APP_LINK=https://app.licenselogger.com`
