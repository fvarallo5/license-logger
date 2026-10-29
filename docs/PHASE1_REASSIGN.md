# Phase 1 — `reassign_lesson` (NOT APPLIED)

File: `supabase/migrations/_NOT_APPLIED_reassign_lesson.sql`

**Why:** Board “Reassign” needs to change `lessons.instructor_id` / `car_id`. Live RLS on `lessons` is SELECT-only for authenticated users; updates go through SECURITY DEFINER RPCs. No such RPC exists on live yet.

**Rules followed:** `search_path = ''`, revoke from `anon`/`public`, grant execute to `authenticated` only, permission check via `private.can_schedule_row`.

**Apply:** Frank types `push` after reviewing. Then rename to a normal timestamped migration or `supabase migration repair` as appropriate.
