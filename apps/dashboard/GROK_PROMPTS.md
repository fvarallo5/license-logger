# Grok prompts — wiring & testing the dashboard against STAGING

Paste these one at a time. Each one is safe on its own. Never run them against the live `license-logger` project until step 6.

## 1. Create a staging project

> Inky, create a new Supabase project called `license-logger-staging` (same region as license-logger, Free plan). Apply every migration from `licenselogger-backend/supabase/migrations` to it, plus the live-only `scheduling` migration pulled from license-logger with `supabase db pull`. Show me the dry run first. Give me the staging URL and publishable key name (not the value in chat) and put them in `licenselogger-dashboard/.env.staging.local`.

## 2. Seed fake test data on staging only

> On STAGING only: create 3 test users (owner, instructor, front desk) with +staging email aliases, one school, 12 fake students in TX/NC/PA, a mix of pending/signed practice and lesson drives, 2 former students, and 1 independent student with a join code. Confirm the project ref before every write.

## 3. Run the dashboard against staging

> Start `npm run dev -- --mode staging` in licenselogger-dashboard, sign in as each test user, and screenshot every tab. Tell me anything that errors, shows the wrong role's buttons, or shows data from another school.

## 4. RLS cross-school test

> On staging, create a second school with its own owner. Sign in as that owner and confirm they see 0 of the first school's students, drives, enrollments, invites and link requests (both in the dashboard and by calling the REST API directly with their token).

## 5. Deploy export-report to staging and test reports

> Deploy the `export-report` Edge Function to STAGING. From the dashboard, export a state-layout PDF, hours report and CSV for a TX student and an NC student. Confirm the links expire after 10 minutes.

## 6. Go live (only after 1–5 pass)

> Deploy the dashboard to Vercel with the LIVE publishable key, set Auth Site URL / Redirect URLs to the Vercel domain, and deploy `export-report` to license-logger. Dry-run first and show me exactly what changes.

## Known backend gaps to decide on (ask Inky)

- `pending_signoffs(p_limit)` has no cursor, so the dashboard pages the `drives` table directly. Fine with RLS + the `(school_id, status)` index; optional: add a keyset version.
- No school-side RPC to list staff names: the People page reads `profiles` and falls back to a short ID if RLS hides other members' profiles. Optional: a `school_staff(p_school_id)` RPC.
- Link requests show the student's ID, not their name, until they accept (by design for privacy). Optional: return first name only.
- 44 SECURITY DEFINER functions are callable by any signed-in user (advisor warning). Each checks the caller inside; worth a one-time review.
