# Phase 3 — Sign-off queue + notifications

## Desk (this zip)

- Sign-offs nav badge with live pending count (60s poll + focus refresh)
- Queue count chip on Sign-offs page header

## Edge functions (code only — NOT deployed)

Already in monorepo under `supabase/functions/`:

- `send-notifications` — drains `notification_outbox`
- `family-invite` — family join emails

**Frank deploy checklist (after Pro + Resend):**

1. Upgrade UltraForge org to Pro
2. Set secrets: `RESEND_API_KEY`, `RESEND_FROM`, optional `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` / `VAPID_SUBJECT`
3. `supabase functions deploy send-notifications family-invite --project-ref nqfjudwncistygsmcgrq`
4. Apply cron from `supabase/cron_schedules.sql` (if present) or schedule invoke every minute
5. Auth SMTP → Resend custom SMTP in dashboard

## Migration (NOT APPLIED)

`supabase/migrations/_NOT_APPLIED_device_push_tokens.sql`

- `device_push_tokens` table + RLS
- `register_web_push` SECURITY DEFINER (`search_path ''`), anon revoked

Apply only after Frank types **push**.

## Open decisions

- Web Push VAPID keys (generate + store in Vault) vs email-only first
- Whether instructors get badge for own-student drives only (RLS already scopes; UI shows school queue)
