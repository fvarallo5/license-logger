# Dashboard audit — 2026-10-30 (America/New_York)

Repo: `fvarallo5/license-logger` @ `a6f826e` (PR #4 phases 0–11 merged). Local `npm run ci`: typecheck/lint/48 tests/build pass after this zip.

## Severity-ranked findings

### P0 — Live deploy broken
- `https://app.licenselogger.com` serves **old sample desk** HTML (`/src/main.jsx`, grain-wash textures), not `apps/dashboard` Vite output.
- `/sw.js`, `/manifest.webmanifest`, `/board` → **404**.
- Cloudflare: Worker `license-logger` has assets, domain attached, but **no Workers Builds config** (API 404). Last Worker touch ~2026-10-29 18:48 UTC — before phase merge finished landing a real build.
- **Action:** attach Builds or `wrangler deploy` from `apps/dashboard/dist` (documented).

### P1 — Routing / PWA
- App used **HashRouter** while Worker uses SPA `not_found_handling` → deep links like `/board` never worked even with a good deploy. → **BrowserRouter**.
- Single ~597 kB JS chunk (no lazy). → **React.lazy** page splits (+ verify-dist).

### P2 — Admin / Instructor ease-of-use
- Top nav too dense on phones; Schedule duplicated Board-week. → phone **dock**, Schedule **redirect**, QBO **nav-gated**, Family **secondary**.
- Board empty state said “open Schedule” (wrong). → link to **Plan**.
- Missing skip-to-content / inconsistent `#main`. → fixed.
- Tiny PWA icons remain (pre-existing); apple-touch meta added to `index.html`.

### P3 — Backend notes (see backend-upgrades zip)
- All six formerly “pending” migrations **are live** on Supabase (device_push_tokens, pay_packages_lockdown, fleet_compliance, instructor_pay, skills_checklist_rpc, request_slot) plus reassign_lesson.
- Advisors: unindexed FKs on `instructor_pay_runs`; multiple permissive policies on pay_runs / schools / students; partition RLS INFO; Auth leaked-password WARN; pg_cron not installed yet (manual cron file exists).
- No client secrets found; `supabase.ts` rejects `service_role` / `sb_secret_`.

### Grok / phase deviations
- Live Worker content ≠ monorepo desk (deploy gap, not a zip drift).
- Phase docs said migrations wait for “push”; Grok/Frank applied phases 3–11 RPCs on live during PR #4 (`7b276e7`). Repo migration files still carry “NOT APPLIED” comments — historical only.
