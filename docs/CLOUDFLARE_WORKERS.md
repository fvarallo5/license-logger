# Cloudflare Worker — LicenseLogger desk

Worker name: **`license-logger`** (Workers Builds → `fvarallo5/license-logger`).

Wrangler configs exist at **repo root**, **`apps/dashboard`**, and **`web/`** (shim if the dashboard root is still the retired sample folder). Each has `name = license-logger`, a `main` worker, and SPA assets.

| Setting | Value |
|---|---|
| Root directory | `apps/dashboard` (preferred). Repo root and `web/` also work. |
| Build command | `npm ci && npm run build` |
| Deploy command | `npx wrangler deploy` |
| Node version | `20` (`NODE_VERSION=20`) |
| Config | `wrangler.jsonc` → `main` `./worker.js`, assets from `./dist`, binding `ASSETS`, SPA `not_found_handling` |

## Build env vars (Workers Builds → Variables)

| Name | Value |
|---|---|
| `VITE_SUPABASE_URL` | `https://nqfjudwncistygsmcgrq.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | publishable / anon key only (never `service_role`) |
| `VITE_SITE_URL` | `https://app.licenselogger.com` |
| `NODE_VERSION` | `20` |

These are baked in at **build** time by Vite. Redeploy after changing them.

## Custom domain

`app.licenselogger.com` → Worker `license-logger`.

## Supabase Auth

Authentication → URL configuration:

- **Site URL:** `https://app.licenselogger.com`
- **Redirect URLs:** include `https://app.licenselogger.com` and `https://app.licenselogger.com/**` (and any `*.workers.dev` preview URL while testing).

## If GitHub check fails in the same second

Workers Builds is dying at **initialization**, before `npm ci`. Typical causes:

1. **Stale API token** — Settings → Build → API Token → Create new token, then Retry build.
2. **Root directory** — set to `apps/dashboard` (or leave repo root / `web/`; all three have wrangler configs now).
3. **Worker name** must stay `license-logger`.

Local wrangler is not logged in, so this agent cannot `wrangler deploy` to production. After `npx wrangler login` in this repo, deploy is:

```sh
cd apps/dashboard
npm run build
npx wrangler deploy
```

Do not change DNS. `app.licenselogger.com` is already on this Worker.

## Local check

```sh
cd apps/dashboard
npm ci
npm run build
npx wrangler deploy --dry-run
```
