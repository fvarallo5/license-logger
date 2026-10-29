# Cloudflare Pages — LicenseLogger desk

| Setting | Value |
|---|---|
| Project name | `licenselogger-desk` (or similar) |
| Production branch | `main` |
| Root directory | `apps/dashboard` |
| Build command | `npm ci && npm run build` |
| Build output | `dist` |
| Node version | `20` (env `NODE_VERSION=20`) |
| Env vars | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_SITE_URL` |

Custom domain: `app.licenselogger.com` → this Pages project (cutover from the old GitHub Pages sample).

`public/_headers` and `public/_redirects` ship with the dashboard build (immutable `/assets/*`, no-cache for `sw.js` / HTML).
