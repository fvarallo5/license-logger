# LicenseLogger school desk

React 19 + Vite 6 + TypeScript PWA. Canonical signed-in dashboard for Admins and Instructors.

## Dev

```sh
# from repo root
cp apps/dashboard/.env.example apps/dashboard/.env.local
# fill VITE_SUPABASE_PUBLISHABLE_KEY
npm install
npm run dev
```

Demo (no Supabase): `npm run demo`

## Checks

`npm run ci` — format, typecheck, lint, test, build.

## Deploy

Cloudflare Pages — see `docs/CLOUDFLARE_PAGES.md`. Root directory `apps/dashboard`, output `dist`.
