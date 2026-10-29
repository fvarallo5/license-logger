# License Logger — ALL PHASES apply / merge order

Grok: apply zips **in order** onto `fvarallo5/license-logger`. Do **not** push, open PRs, deploy Supabase, or deploy Cloudflare unless Frank types **push** / explicitly asks.

Reality check (2026-10-29):

- PR #1 — Phase 0 monorepo — **open**
- PR #2 — worker-config — **open**
- Phase 1 Board — **not yet a PR**

Priority: (1) Admin/Instructor ease of use (2) 2026-grade PWA.

---

## Apply order (stack)

| # | Zip | Branch suggestion | Notes |
|---|-----|-------------------|--------|
| 0 | `/workspace/licenselogger-phase0.zip` | `phase-0-monorepo` | PR #1 open |
| 1 | `/workspace/licenselogger-phase1-board.zip` | `phase-1-board` | Not a PR yet — open after Frank ok |
| 1b | `/workspace/licenselogger-worker-config.zip` | `worker-assets-config` | PR #2 open; stacks after Phase 0 (+ ideally after Phase 1 build layout) |
| 2 | `/workspace/licenselogger-phase2-plan.zip` | `phase-2-plan` | Plan + templates |
| 3 | `/workspace/licenselogger-phase3-signoffs-notify.zip` | `phase-3-signoffs-notify` | Badge + notify docs |
| 4 | `/workspace/licenselogger-phase4-packages-pay.zip` | `phase-4-packages-pay` | Packages + Pay |
| 5 | `/workspace/licenselogger-phase5-export-qbo.zip` | `phase-5-export-qbo` | Export UX + QBO flag |
| 6 | `/workspace/licenselogger-phase6-fleet.zip` | `phase-6-fleet` | Fleet + OSM map |
| 7 | `/workspace/licenselogger-phase7-payouts.zip` | `phase-7-payouts` | Instructor payouts |
| 8 | `/workspace/licenselogger-phase8-pwa.zip` | `phase-8-pwa` | Icons + SW prompt |
| 9 | `/workspace/licenselogger-phase9-portal.zip` | `phase-9-portal` | Family `/portal` |
| 10 | `/workspace/licenselogger-phase10-flutter-cloud.zip` | `phase-10-flutter-cloud` | Flutter CloudSync (default off) |
| 11 | `/workspace/licenselogger-phase11-skills.zip` | `phase-11-skills` | Skills checklist |

Each zip contains:

- `changed-files/` — copy onto repo root
- `*.patch` — optional `git apply` / `patch -p1` (Phase 10 may use changed-files only)
- `README-GROK.md` — per-phase prereqs, CI, branch, open decisions
- `DELETED.txt` — paths removed vs previous (if any)

### Per-zip apply recipe

```bash
cd /path/to/license-logger
# Prefer changed-files overlay:
rsync -a /path/to/unzipped/changed-files/ ./
# Or: patch -p1 < phaseN-*.patch
cd apps/dashboard && npm ci && npm run ci
# If Flutter touched (Phase 10+):
cd ../mobile && flutter pub get && flutter analyze && flutter test
```

---

## Migrations NOT APPLIED (Frank must type **push** before any)

List for Frank — all under `supabase/migrations/`:

1. `_NOT_APPLIED_reassign_lesson.sql` — Phase 1 (Board reassign)
2. `_NOT_APPLIED_device_push_tokens.sql` — Phase 3
3. `_NOT_APPLIED_pay_packages_lockdown.sql` — Phase 4
4. `_NOT_APPLIED_fleet_compliance.sql` — Phase 6
5. `_NOT_APPLIED_instructor_pay.sql` — Phase 7
6. `_NOT_APPLIED_request_slot.sql` — Phase 9
7. `_NOT_APPLIED_skills_checklist_rpc.sql` — Phase 11

Each uses RLS / SECURITY DEFINER + `search_path = ''` / revoke anon where applicable.

---

## Edge functions (code only — not deployed)

Already in tree; deploy only after Frank push + secrets:

- `export-report`
- `send-notifications`, `family-invite`
- `qbo-connect`, `qbo-callback`, `qbo-refresh`, `qbo-sync`, `qbo-webhook`

See `docs/PHASE3_NOTIFY.md`, `docs/PHASE5_EXPORT_QBO.md`.

---

## Feature flags / defaults

| Flag | Default | Phase |
|------|---------|-------|
| `VITE_ENABLE_WEB_PUSH` | off | 3 |
| `VITE_ENABLE_QBO` | off | 5 |
| Flutter `LL_CLOUD` | off | 10 |
| OSM embed map (no API key) | on | 6 |
| Manual record payment (no Stripe) | on | 4 |

---

## Open decisions (need Frank)

- `generate_slots` RPC vs on-demand book only (Phase 2)
- Resend + Pro upgrade before notify deploy (Phase 3)
- Card processor Stripe/Square vs manual (Phase 4)
- Intuit sandbox vs production (Phase 5)
- Mapbox/Google vs OSM (Phase 6)
- Payout approve/paid workflow vs report-only (Phase 7)
- Portal subdomain vs `/portal` (Phase 9)
- Store listings / student_id binding (Phase 10)
- Document uploads + certificates (Phase 11 deferred)

---

## Per-phase one-liners

See each zip’s `README-GROK.md` for ships, tests, migrations, and branch names.
