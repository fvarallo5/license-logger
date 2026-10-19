# LicenseLogger

Driving school hours for students, instructors, and the school desk. UltraForge LLC.

This is a new Flutter shell. It is not a copy of TrekTrack.

| | |
|---|---|
| Store name | LicenseLogger |
| Subtitle | Driving school hours |
| Domain | licenselogger.com |
| Desk | [app.licenselogger.com](https://app.licenselogger.com) |
| Bundle | `com.ultraforge.licenselogger` |
| Dart package | `license_logger` |
| Support | support.ultraforgellc@gmail.com |

## Phone v1

Local hours on the device until the school desk exists.

- First launch: profile (name, birthday, state, optional permit date). State rules fill hour goals and the test-ready checklist
- Header: logo, status (Ready / Watching / Driving), settings
- Dashboard: compact Track start-trip box, this-week calendar (expand to month), checklist `(done/N)` for road-test eligibility
- Lessons: GPS map of saved routes plus the drive list
- A trip must cover 15 miles per hour of driving (and at least 0.5 mi) or it is discarded: "Trip Too Short To Save"
- Auto-track: same GPS engine as TrekTrack (Balanced start ~17s / 60 m / ~9 mph, park 120s + 45s stitch, silence failsafe, adaptive in-lesson sampling, idle GPS sleep + significant-change wake). iOS vehicle gate (Motion & Fitness) sleeps GPS until automotive; Android is GPS-only.
- Hours: 50h permit arc (green) with night overlay (yellow), week/month/all list filter
- Settings: profile, seat, auto-track, iOS vehicle gate, GPS Saver/Balanced/Accuracy, hour/night goals, night window (default 6pm–6am)
- State GDL catalog: 50 states + DC from the Oct 17, 2026 requirements spreadsheet; confirm with the DMV before applying

Hours persist in `SharedPreferences`. No account, no TrekTrack API.

## Run

```sh
flutter run -d "iPhone 16 Plus"
```

Desk PWA shell (sample data, no Auth yet). Live: `https://app.licenselogger.com` and `/portal`.

```sh
cd web
npm install
npm run dev
```

Open `http://127.0.0.1:5175` (Board / Plan / Students) and `http://127.0.0.1:5175/portal`.

## Do not

- Copy `mileage-tracker` into this repo
- Reuse TrekTrack’s App ID, App Group, or `.env`
