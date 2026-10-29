# LicenseLogger

Driving-school hours and desk. UltraForge LLC.

| | |
|---|---|
| Product | LicenseLogger |
| Domain | [licenselogger.com](https://licenselogger.com) |
| Desk PWA | [app.licenselogger.com](https://app.licenselogger.com) |
| Supabase | `nqfjudwncistygsmcgrq` (us-east-2) |
| Phone bundle | `com.ultraforge.licenselogger` |

## Monorepo layout

```
apps/dashboard/     School desk (React + Vite PWA) — canonical signed-in UI
apps/mobile/        Flutter student / family app
supabase/           Migrations + Edge Functions
docs/               Launch plan, state rules, Cloudflare, migration map
scripts/            Local test helpers
```

The old sample desk (`web/`) was retired in Phase 0. Use `apps/dashboard`.

## Quick start (desk)

```sh
cp apps/dashboard/.env.example apps/dashboard/.env.local
# set VITE_SUPABASE_PUBLISHABLE_KEY (anon / publishable only)
npm install
npm run dev          # Vite on the dashboard
npm run ci           # format + typecheck + lint + test + build
```

Never put `service_role` / `sb_secret_` in the dashboard. The app refuses to start if you do.

## Backend

Migrations and functions live under `supabase/`. **Production already has the schema applied** (see `docs/LIVE_MIGRATION_MAP.md`). Do not `db push` to prod without Frank typing `push` and comparing the map. Edge functions are not deployed yet.

## Hosting

Cloudflare Pages for the desk — `docs/CLOUDFLARE_PAGES.md`.

## Standing rules

- Migrations go live only after Frank types `push`.
- Merges need Frank’s explicit okay.
