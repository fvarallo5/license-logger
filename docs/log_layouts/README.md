# State log layouts (one spec, two renderers)

Each `<ST>.json` file here copies the **official** state driving-log or certification form, field by field. The backend
PDF export (`supabase/functions/export-report/log_layout.ts`) and the Flutter app's "Generate my filled log" screen
(`lib/data/log_layouts.dart`) both render from the same data, so they can't drift apart.

```
docs/log_layouts/<ST>.json  (source of truth, hand-authored from state-driving-logs/pdfs/)
   │  python3 scripts/build_log_layouts.py      validate + evidence check (every printed label must appear in pdftotext)
   ├─► docs/log_layouts/layouts.json             combined (39 states + 12 generic entries)
   ├─► supabase/functions/export-report/log_layouts.json   byte-identical copy bundled with the function
   └─► docs/log_layouts/EVIDENCE.md              where each label was found in the PDF
   │  deno run -A scripts/gen_log_fixtures.ts    TS builder output for fixtures/input.json
   └─► fixtures/expected/<ST>.json               52 documents both builders must reproduce exactly
   │  (app) python3 tool/build_state_rules.py    copies layouts.json → assets/data/log_layouts.json
   └─►                                           and fixtures → test/fixtures/log_layouts/ ; --check = drift check only
```

**Rebuild order after any spec edit:** `build_log_layouts.py` → `gen_log_fixtures.ts` → app `tool/build_state_rules.py`
→ `deno test -A` (export-report) and `flutter test`. `build_log_layouts.py --check` and `build_state_rules.py --check`
fail if anything is stale.

## Coverage

| Kind | States |
|---|---|
| Full log (28) | CA CO CT DC DE IA IN KY MA MD ME MI MN MO MT NC NV OH OR PA RI SC SD TX VT WI WV WY |
| Certification only (11) | AK AL FL KS NE NJ NY OK TN UT WA |
| Generic: official PDF blocked (3) | AZ (96-0223), IL (DSD X 152 / X 174), NH (DSMV 509). The download retry failed, so these use the generic layout and say so |
| Generic: no state form (8) | AR GA ID LA MS ND VA, plus NM (any document accepted) |
| Generic: unconfirmed (1) | HI (the affidavit appears only on school sites) |

## Schema (`licenselogger.log_layout/v1`)

- `state_code`, `state_name`, `kind`: `full_log` or `certification`.
- `form`:
  - `name`, `number` and `revision`, only as printed.
  - `source_pdf` and `source_pages`, plus `extra_sources[{pdf, pages, role}]`.
- `page`: `{size, orientation}` from `pdfinfo`. `title` and `subtitle` are as printed.
- `header_fields[{label, value}]`. The value is a value key, or `""` to leave the field blank.
- `amount_format` is one of `hr_min`, `hours`, `minutes`, `hm`. `date_format` is one of `m/d/yy`, `mm/dd/yyyy`, `m/d`.
- `tables[]`:
  - `panels[{filter: all|day|night|none, title, columns[{label, key, w, group}]}]`.
  - `rows`, `rows_first`, `page_total{label, sum[]}` and `example_row`.
  - Columns are listed in the official order, with labels exactly as printed.
- `summary[{label, value}]`.
- `certification`:
  - `{title, text, fields, totals, signatures, notary{title, text, lines} | null, extra_text}`.
  - The text is quoted from the PDF, and `{placeholders}` are filled in.
- `cert_position`: `before_log` or `after_log`.
- `legend`, `abbrev`, `unfillable` (labels we leave blank) and `notes` (anything unclear in the PDF).
- `acceptance`: `{mode: check | accepted | transfer, basis, source}`. The basis is quoted from `state_logs.csv`.

## Fill rules

- Only **signed practice drives** are listed. Unsigned drives and school lessons are counted in the "Computed by
  LicenseLogger (not part of the official form)" box only. A zero amount prints as a blank cell.
- Day/night panels split each drive by its day and night minutes.
- Page totals are computed per panel. The legend prints on the first log page.
- Certification-only states:
  - Page 1 has the header, the certification text, any blank tables on the form, signatures, any notary block and the
    computed box.
  - After that come "Supporting drive record (LicenseLogger; not part of the official form)" pages.
- Disclaimer by `acceptance.mode`:
  - `check`: "Prepared with LicenseLogger from the official {State} {number} {name}; check your state accepts this copy."
  - `accepted` (MI, MT, NC): states that the state accepts other log formats, and quotes the source.
  - `transfer` (NV, MN, IN, OH): "Filled copy to transfer/print onto the official …", quoting why.
- Nothing is invented. Fields we can't fill, like supervisor license numbers, addresses and notary details, stay blank
  with their printed label.

## Known PDF quirks (see each file's `notes`)

- WV: the title is a graphic, so it is exempt from the evidence check.
- CO: the minimum hints are misprinted on the form.
- TX: the lesson/session columns are left blank.
- MD: the second option isn't modelled.
- UT: there is an unlabeled "X" signature line.
- The backend doesn't store permit numbers, so that field is left blank in server exports.

## Samples

```
deno run -A scripts/render_log_samples.ts OUT_DIR [ST...]     # 44 deterministic drives, every layout + AZ/NM/GA generic
python3 scripts/side_by_side.py OUT.png OFFICIAL.pdf PAGE OURS.pdf PAGE "title"
```
