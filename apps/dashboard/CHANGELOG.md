# Changelog

## 0.1.1 — 2026-10-25 (polish, no behavior change)

- Prettier formatting and stricter ESLint (`typescript-eslint` strict, no non-null assertions, no `console.log`).
- `useSchool()` hook replaces `current!` assertions; `usePaged` takes a reset key instead of a spread deps array.
- Shared `statusTone()` for status badges; shared offset-pagination helpers in `api.ts`; removed unused `pct`.
- Accessibility: dialogs close on Escape, focus their first field and set `aria-modal`; nav/pagination landmarks;
  week arrows have labels; visible keyboard focus ring; per-page browser tab titles.
- Added `.editorconfig`, `LICENSE` placeholder, CI workflow, `npm run ci` and `format` scripts.
- 3 new UI tests (19 total).

## 0.1.0 — 2026-10-24

- First version: auth, school setup/settings, roster, join requests, former students, student detail with state-rule
  progress and resources, reports, sign-off queue, schedule, people, QuickBooks status.
