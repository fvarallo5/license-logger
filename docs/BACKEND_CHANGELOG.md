# Changelog

## 2026-10-25 — polish (no schema or behavior change)
- Edge Functions: `deno fmt` (120 cols, config in `supabase/functions/deno.json`), `deno lint` now clean.
  Removed 3 unused variables/imports; typed the `qbo-sync` job result instead of `as any` casts. Remaining `any`
  uses are at untyped external JSON boundaries and carry a `deno-lint-ignore` with a reason.
- Migrations: **unchanged, byte-identical** (all are applied on the live project).
- Added `.editorconfig`, `.sqlfluff` (for NEW migrations only), `LICENSE` placeholder, CI workflow.

## 2026-10-23
- 11 launch migrations, Edge Functions (export-report, family-invite, qbo-*, send-notifications), 444 pgTAP checks.
