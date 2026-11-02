# LicenseLogger — UI redesign (desktop-first; minimal mobile)

Apply from the **repo root** of `fvarallo5/license-logger`.

## Branch

```bash
git fetch origin
git checkout -b redesign/ui-figma origin/main
```

## Apply

```bash
cp -R changed-files/apps/dashboard/* apps/dashboard/
test -f changed-files/package-lock.json && cp changed-files/package-lock.json ./
cd apps/dashboard
npm install
npm run typecheck
npm test
npm run build
```

Includes (cumulative):
1. **Map fix** — Leaflet lot map, city center, search/click-to-pin; Board instructor names
2. **Shell redesign** — teal sidebar, Home KPIs, dark mode, plain-language copy, lucide icons
3. **Calendar + map 50/50** — TrekTrack desk pattern on Home + Board (**desktop ≥900px only**)
4. **Mobile strip-down (<900px)** — no map (Leaflet not mounted), no bottom dock / big header buttons; compact 44px top bar with 32px aligned menu opening the sidebar drawer; single-column calendar/list + compact KPIs

## Desktop (≥900px) — keep as-is

- Dark teal sidebar (`#0B2E2B`) + desk grid (sidebar + desk-main only)
- Home KPI row
- `CalendarMapSplit`: LessonCalendar + LessonMap **50/50**, synced selection
- Palette: primary `#0D9488`, accent `#14B8A6`, canvas `#F3F6F5`

## Mobile (<900px) — minimal for now

- `useDesktopMedia(900)` gates map: **do not load Leaflet** on narrow viewports
- No redesigned bottom dock; `nav.dock` hidden
- Compact top bar (44px) + small menu button (32×32) → sidebar drawer
- Content single column; calendar / lesson list only; KPIs compact (2-col, 18px values)
- Page header actions sized down (`.ph .btn` ~30px height)

## TrekTrack source (read-only reference)

Ported from `fvarallo5/mileage-tracker`:
- `frontend/src/components/manager/DeskOverview.jsx` — Live Map (`DispatchMap`) + `JobTimeline` in `.easy-home` columns
- `frontend/src/styles/desk.css` — `.easy-home` columns; stacks on narrow
- `frontend/src/components/manager/DispatchMap.jsx` / `JobTimeline.jsx`

LicenseLogger: `CalendarMapSplit` → left `LessonCalendar` + right `LessonMap` (desktop only); shared `selectedId`.

## Verify

```bash
cd apps/dashboard
npm run typecheck && npm test && npm run build
# Optional: demo build + shots at 1440 and 390
```

Screenshots in zip `docs/shots/` (01–05 desktop, 06–07 mobile).

## PR (do not merge without Frank)

```bash
git add apps/dashboard package-lock.json
git commit -m "feat(dashboard): desktop redesign + minimal mobile (no map)"
git push -u origin redesign/ui-figma
gh pr create --title "feat(dashboard): redesign shell + calendar/map (desktop); minimal mobile" \
  --body "Figma-inspired shell, teal brand, Home KPIs, TrekTrack calendar+map 50/50 on desktop. Mobile <900px: no Leaflet map, no dock, compact top bar + drawer. Screenshots in zip docs/shots. No merge until Frank OK."
```

## Do not

- Merge without Frank’s explicit OK
- Deploy unless Frank asks
- Commit secrets / service role keys
- Re-introduce mobile map / bottom dock without Frank asking

## Style / shots

See `STYLE.md`, `docs/fig/`, `docs/shots/`.
