# LicenseLogger — UI redesign (cumulative)

Apply from the **repo root** of `fvarallo5/license-logger`.

## Branch

```bash
git fetch origin
git checkout -b redesign/ui-figma origin/main
```

## Apply (dashboard)

```bash
cp -R changed-files/apps/dashboard/* apps/dashboard/
test -f changed-files/package-lock.json && cp changed-files/package-lock.json ./
npm install
cd apps/dashboard
npm run typecheck
npm test
npm run build
```

Optional (migrations already live — **do not re-apply**): renamed SQL under `changed-files/supabase/migrations/20261030170*.sql` (no `_NOT_APPLIED_`). Copy into repo for hygiene only.

## Includes (cumulative)

1. Map fix, teal shell, KPIs, dark mode  
2. Desktop 60/40 calendar+map; mobile list / no map  
3. FullCalendar Day + Month; **Week = day-strip (option D)** everywhere  
4. Map fills pane (`invalidateSize`)  
5. **Title Case** headers & subheaders (source strings, not CSS)  
6. **Mobile zoom lock**: viewport `maximum-scale=1, user-scalable=no`; `touch-action: manipulation`; inputs ≥16px on small screens; iOS standalone/PWA `gesturestart` preventDefault in `main.tsx`  
   - Note: iOS Safari (browser tab) may still allow pinch zoom for accessibility.

## Do not

- Merge / deploy without Frank OK  
- Re-apply the four `20261030170*` migrations (already on `nqfjudwncistygsmcgrq`)  
- Commit secrets  

See `STYLE.md`, `docs/shots/`.
