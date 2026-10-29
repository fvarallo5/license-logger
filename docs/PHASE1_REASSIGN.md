# Phase 1 — `reassign_lesson` (applied)

Live: `nqfjudwncistygsmcgrq` version `20261029184409` name `reassign_lesson`.

Repo file: `supabase/migrations/20261029184409_reassign_lesson.sql`

Board “Reassign” changes `lessons.instructor_id` / `car_id`. Live RLS on `lessons` is SELECT-only; updates go through this SECURITY DEFINER RPC (`search_path ''`, revoke anon/public, grant execute to `authenticated`). Permission check: `private.can_schedule_row`. Null `p_car_id` keeps the current car (`coalesce`).
