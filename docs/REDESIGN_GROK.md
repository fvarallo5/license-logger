# LicenseLogger — UI redesign (desktop-first; calendar + map)

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
npm install
cd apps/dashboard
npm run typecheck
npm test
npm run build
```

Includes (cumulative):
1. Map fix (Leaflet lots/pins)
2. Shell redesign (teal sidebar, KPIs, dark mode)
3. Calendar + map desktop split; mobile list / no map
4. FullCalendar Day + Month (lazy chunk)
5. **60/40** calendar/map; map fills pane (`invalidateSize` + absolute canvas)
6. **Week = option D everywhere** — 7-day strip with lesson counts + selected-day cards (time, student, instructor, status); click selects / syncs map. Defaults: Home→Day, Board→Week. Prev/next week arrows; default selected day = today when in range.

## Desktop (≥900px)

- Split: `3fr / 2fr` (60/40); map pane flex-fills height
- Day / Month: FullCalendar timeGrid / dayGrid
- Week: `WeekStripView` (not hourly FC week)
- Palette: `#0B2E2B` sidebar, `#0D9488` primary, `#F3F6F5` canvas

## Mobile (<900px)

- No Leaflet / no FullCalendar
- Day: simple list; **Week: same strip + cards (D)**
- Compact top bar + drawer; no bottom dock

## Dependencies

`@fullcalendar/*` v6.1.x (Day/Month only). Week strip is custom React.

## Verify

```bash
cd apps/dashboard && npm run typecheck && npm test && npm run build
```

Shots: `docs/shots/09-board-week-*` (strip), `01-home-*` (day FC), `06`/`07` mobile.

## Do not

- Merge / deploy without Frank OK
- Commit secrets
- Push migrations unless Frank says “push”

See `STYLE.md`, `docs/shots/`.
