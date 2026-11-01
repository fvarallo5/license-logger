# Map audit (2026-11-01)

| Finding | Severity | Detail |
|---------|----------|--------|
| Empty map | P1 UX | Lots seeded without lat/lng; iframe only rendered when coords exist |
| “API key” confusion | P2 | Live copy mentioned OSM embed / no key — correct, but implied key might be needed |
| Manual lat/lng prompts | P2 | `prompt()` for coords is hostile for admins |
| Board filter raw ids | P1 UX | `profileNames` omitted staff not on this week’s schedule |

**Fix:** Leaflet + Nominatim + click-to-pin (this zip). No Cloudflare build var required.
