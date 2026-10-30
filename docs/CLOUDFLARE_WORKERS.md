# Cloudflare Worker — LicenseLogger desk

Worker name: **`license-logger`** (custom domain `app.licenselogger.com`).

## Critical (audit 2026-10-30)

As of the audit, **Workers Builds is not attached** to this Worker (`GET …/builds/workers/license-logger` → 404). The live site was still serving an **old sample desk** (`/src/main.jsx` + grain-wash textures), not `apps/dashboard`’s Vite build. That means:

1. Merges to `main` do **not** auto-deploy.
2. `sw.js` / `manifest.webmanifest` / `/board` return 404 until a real `dist/` deploy lands.

**Fix once (Frank):** Cloudflare Dashboard → Workers & Pages → `license-logger` → Settings → Builds:

| Setting | Value |
|---|---|
| Connect repo | `fvarallo5/license-logger` |
| Root directory | `apps/dashboard` |
| Build command | `npm ci && npm run build` |
| Deploy command | `npx wrangler deploy` |
| Node | `20` (`NODE_VERSION=20`) |

Or deploy manually after login:

```sh
cd apps/dashboard
npm ci
# ensure VITE_* are in .env / Workers Builds vars
npm run build          # runs verify-dist (fails if index still points at /src)
npx wrangler deploy
```

Then hard-refresh `https://app.licenselogger.com/` — HTML title should be **LicenseLogger · School dashboard**, scripts under `/assets/…`, and `/sw.js` + `/manifest.webmanifest` should be 200.

## Wrangler configs

Configs exist at **repo root**, **`apps/dashboard`**, and a shim under **`web/`**. Prefer **`apps/dashboard`**.

| Setting | Value |
|---|---|
| `main` | `./worker.js` (SPA passthrough to `ASSETS`) |
| assets.directory | `./dist` |
| assets.not_found_handling | `single-page-application` |

## Build env vars (Workers Builds → Variables)

| Name | Value |
|---|---|
| `VITE_SUPABASE_URL` | `https://nqfjudwncistygsmcgrq.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | publishable / anon key only (never `service_role` / `sb_secret_`) |
| `VITE_SITE_URL` | `https://app.licenselogger.com` |
| `NODE_VERSION` | `20` |
| `VITE_ENABLE_QBO` | omit or `0` until Intuit is ready; set `1` to show QuickBooks nav |

These are baked in at **build** time by Vite. Redeploy after changing them.

## Supabase Auth

Authentication → URL configuration:

- **Site URL:** `https://app.licenselogger.com`
- **Redirect URLs:** `https://app.licenselogger.com` and `https://app.licenselogger.com/**` (plus any `*.workers.dev` preview).

Also enable **Leaked password protection** (Auth → Attack Protection / Password security) — advisor WARN.

## Local check

```sh
cd apps/dashboard
npm ci
npm run ci
npx wrangler deploy --dry-run
```
