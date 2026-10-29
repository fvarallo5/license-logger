# Phase 5 — export-report + QuickBooks

## Desk

- Student detail Reports card: clearer copy for state log / hours / CSV
- QuickBooks Connect + Sync now behind `VITE_ENABLE_QBO=1` (safe default off)
- API: `qboConnect`, `qboSyncNow`

## Edge functions (code only — do not deploy until Frank says push)

Already in `supabase/functions/`:

- `export-report`
- `qbo-connect`, `qbo-callback`, `qbo-refresh`, `qbo-sync`, `qbo-webhook`

### Deploy checklist (Frank)

1. Intuit developer app credentials → Vault / secrets: `INTUIT_CLIENT_ID`, `INTUIT_CLIENT_SECRET`, `INTUIT_REDIRECT_URI`
2. `supabase functions deploy export-report qbo-connect qbo-callback qbo-refresh qbo-sync qbo-webhook --project-ref nqfjudwncistygsmcgrq`
3. Rebuild desk with `VITE_ENABLE_QBO=1`
4. Smoke: Student → State log PDF; Pay school → Connect QBO

## Migrations

None new.

## Open decisions

- Intuit production vs sandbox app
- Whether QBO is required before launch or optional
