# LicenseLogger redesign style notes

## Figma source (Frank)
- File: fig-kiwi binary (Dashboard V3a template family)
- Preview: `docs/fig/fig-decoder-preview.png` (same as embedded thumbnail)
- Extracted tokens (`docs/fig/style-extract.json`):
  - Fonts: **Gilroy** (primary), Inter fallback; sizes 12 / 14 / 16 / 18 / 24
  - Figma colors: sidebar `#1c1f37`, accent `#017efa`, canvas `#f5f7fb` / `#f1f2fa`, chart cyan/magenta/green
  - Radii: 8–12px cards; soft elevation

## LicenseLogger palette (changed from Figma — driving-school “road/go”)
| Token | Value | Role |
|-------|-------|------|
| `--sidebar` | `#0B2E2B` | Deep teal sidebar (not Figma navy) |
| `--primary` | `#0D9488` | Actions / active (not Figma `#017efa`) |
| `--accent` | `#14B8A6` | Highlights / badges |
| `--primary-soft` | `#CCFBF1` | Soft fills |
| `--bg` | `#F3F6F5` | Canvas |
| `--ink` | `#0F1B2D` | Text |
| `--surface` | `#FFFFFF` | Cards |
| `--radius` / `--radius-lg` | 10 / 14 | Cards & controls |
| `--shadow` | soft dual-layer | Figma-like float |

Dark mode: `html[data-theme="dark"]` + Auto/Light/Dark cycle in sidebar.

Layout borrowed from Figma: persistent left sidebar, KPI card row, soft cards, Lucide line icons, mobile bottom dock.


## Mobile (<900px) — minimal for now
- No map / Leaflet; calendar + list only
- Compact top bar (44px) + 32px menu → sidebar drawer
- No bottom dock; compact KPIs
- Full desktop redesign (sidebar + calendar/map 50/50) at ≥900px


## Calendar (desktop)
- FullCalendar v6 (lazy `LessonCalendarGrid`): Day/Week time grid 7am–9pm, Month chips
- Tokens via `--fc-*` CSS variables; dark mode under `[data-theme="dark"]`
- Defaults: Home → Day, Board → Week


## Split layout
- Desktop calendar/map: **60/40** (`3fr / 2fr`)
- Map pane must stretch with calendar; Leaflet host absolute-fill + invalidateSize


## Week view (option D)
- 7-day strip with counts; selected day cards (time, student, instructor, status)
- Replaces FullCalendar week everywhere (desktop + mobile)
