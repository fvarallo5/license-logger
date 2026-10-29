# Live Supabase migration map

Project: `nqfjudwncistygsmcgrq` (us-east-2).

This repo ships the backend kit migrations under `supabase/migrations/` (box kit timestamps `20261023*`).
Live applied the same logical migrations under later timestamps, plus two live-only names:

| Live version | Live name | Repo file (approx) |
|---|---|---|
| 20261019175634 | schools | 20261019175634_schools.sql |
| 20261019175702 | school_fk_indexes | 20261019175702_school_fk_indexes.sql |
| 20261019181531 | students | 20261019181531_students.sql |
| 20261020213528 | lots_cars | 20261020213528_lots_cars.sql |
| 20261023222828 | scheduling | **live-only** (slot_templates, reservations, board RPCs). See `supabase/migrations/20261020220000_scheduling.sql (live version was 20261023222828)` placeholder + notes. |
| 20261024001614 | ll_foundation | 20261023120000_ll_foundation.sql |
| 20261024001637 | ll_state_rules | 20261023120100_ll_state_rules.sql |
| 20261024001645 | ll_family_supervisors | 20261023120200_ll_family_supervisors.sql |
| 20261024001647 | ll_drives | 20261023120300_ll_drives.sql |
| 20261024001649 | ll_hours | 20261023120400_ll_hours.sql |
| 20261024001653 | ll_lessons_compat | 20261023120500_ll_lessons.sql (compat: live uses `start_at`/`end_at`, status `taught`) |
| 20261024001759 | ll_billing_qbo | 20261023120600_ll_billing_qbo.sql |
| 20261024001804 | ll_exports_notifications | 20261023120700_ll_exports_notifications.sql |
| 20261024001813 | ll_independent_students | 20261023120800_ll_independent_students.sql |
| 20261024001821 | ll_state_rules_v2 | 20261023120900_ll_state_rules_v2.sql |
| 20261024001827 | ll_state_rules_data | 20261023121000_ll_state_rules_data.sql |
| 20261029184409 | reassign_lesson | 20261029184409_reassign_lesson.sql (applied on live; EXECUTE authenticated only) |

**Do not `supabase db push` to production** without comparing this map. Staging should apply the repo migrations on a fresh project. Production already has the objects.

**Dashboard note:** `mark_lesson` on live accepts `taught` (not `completed`). Phase 0 patches the desk to send `taught`.

| 20261029192814 | fleet_compliance | 20261029192814_fleet_compliance.sql |
| 20261029192816 | device_push_tokens | 20261029192816_device_push_tokens.sql |
| 20261029192818 | pay_packages_lockdown | 20261029192818_pay_packages_lockdown.sql |
| 20261029192822 | instructor_pay | 20261029192822_instructor_pay.sql |
| 20261029192825 | skills_checklist_rpc | 20261029192825_skills_checklist_rpc.sql |
| 20261029192841 | request_slot_family | 20261029192841_request_slot_family.sql (live 12-arg RPC; family/desk allowed) |
