#!/usr/bin/env python3
"""Generate supabase/migrations/20261023121000_ll_state_rules_data.sql from the verified
research in /workspace/state-driving-logs/state_logs.csv (official sources, checked 2026-10-22).

Text, links and statuses come straight from the CSV. The numbers and rule types below are
transcribed by hand from that CSV's total_hours / night_hours / other_rules / notes columns.
Every value has its source text next to it. Nothing is invented: unknown means None (SQL NULL),
with a note in field_status.

    python3 scripts/build_state_rules_seed.py [path/to/state_logs.csv]
"""
import csv, json, sys, pathlib

CSV = sys.argv[1] if len(sys.argv) > 1 else "/workspace/state-driving-logs/state_logs.csv"
OUT = pathlib.Path(__file__).resolve().parent.parent / "supabase/migrations/20261023121000_ll_state_rules_data.sql"
H = 60

# ---- hand-transcribed structure (hours -> minutes below). Comments quote the CSV. ----
S = {
 "AL": dict(total=50, night=None, fs={"night_minutes": "not specified"},
            alternatives=[dict(key="driver_ed", label="SDE-approved driver ed completion submitted instead of the 50 h", replaces_hours=True)]),
 "AK": dict(total=40, night=None, weather=10, weather_counts_night=True, notar=("if_signer_absent", "notarize if signer not present"),
            fs={"weather_minutes": "10 h in 'progressively challenging' conditions incl. darkness/inclement weather (not strictly night)"}),
 "AZ": dict(total=30, night=10, notar=("required", "notarized or witnessed by MVD agent"),
            alternatives=[dict(key="driver_ed_reduced", label="Approved traffic-survival / defensive-driving-school driver ed", total=20, night=6),
                          dict(key="driver_ed_complete", label="Completed high-school / authorized third-party driver ed", replaces_hours=True)]),
 "AR": dict(total=None, night=None, sup=(21, None, "6 months restricted driving with licensed 21+ adult")),
 "CA": dict(total=50, night=10),
 "CO": dict(total=50, night=10, lessons=dict(max=6), lessons_note="6 h BTW with driver-ed provider may count"),
 "CT": dict(total=40, night=5, sup=(20, 4, "'Qualified Trainer' 20+, licensed 4 yrs"),
            fs={"night_minutes": "not specified by statute; official log lists 'Driving at Night (min. 5 hrs.)'"}),
 "DE": dict(total=50, night=10),
 "DC": dict(total=40, night=None, sup=(21, None, "tutor 21+ with full license"), fs={"night_minutes": "not specified"}),
 "FL": dict(total=50, night=10, notar=("required", "notarized or witnessed by examiner")),
 "GA": dict(total=40, night=6),
 "HI": dict(total=None, night=None, fs={"total_minutes": "unconfirmed: an HDOT-labelled affidavit (40 day + 10 night) circulates only on school/driving-school sites; honolulu.gov lists no hours requirement",
                                        "night_minutes": "unconfirmed (10 per HDOT affidavit text)",
                                        "supervisor_min_age": "unconfirmed (21+ per HDOT affidavit text)",
                                        "notarization": "unconfirmed (HDOT affidavit text says notarized)"}),
 "ID": dict(total=50, night=10, sup=(21, None, "supervisor 21+")),
 "IL": dict(total=50, night=10, sup=(21, 1, "supervisor 21+ licensed at least 1 year"),
            notar=("if_signer_absent", "notarized DSD X 174 Affidavit/Consent if the parent is not present"),
            lessons_note="hours are in addition to instructor time (instructor time does not count)"),
 "IN": dict(total=50, night=10),
 "IA": dict(total=30, night=4, stages=[
            dict(key="intermediate", label="Before the intermediate license", total=20, night=2, counting="cumulative"),
            dict(key="full", label="While on the intermediate license, before the full license", total=10, night=2,
                 counting="since_previous_milestone", milestone="intermediate")]),
 "KS": dict(total=50, night=10, sup=(21, None, "supervisor licensed 21+"), lessons=dict(max=None), lessons_note="instructor BTW time counts if instructor 21+",
            fs={"total_minutes": "DOV FAQ also mentions a 25-hour affidavit earlier; not modelled"}, partial=True),
 "KY": dict(total=60, night=10, sup=(21, None, "supervisor licensed 21+")),
 "LA": dict(total=50, night=15, sup=(21, None, "supervisor licensed parent/guardian/adult 21+")),
 "ME": dict(total=70, night=10),
 "MD": dict(total=60, night=10, sup=(21, 3, "supervisor 21+ licensed at least 3 years"),
            alternatives=[dict(key="age_25_plus", label="Applicant is 25 or older", total=14, night=3)],
            digital_note="RoadReady app adopted by MVA in 2019 per earlier research; not re-verified"),
 "MA": dict(total=40, night=None, sup=(21, 1, "supervisor 21+ licensed 1 year, seated beside"), fs={"night_minutes": "not specified"},
            alternatives=[dict(key="rmv_program", label="RMV-approved driver skills development program", total=30)]),
 "MI": dict(total=50, night=10, digital=("accepted", [], "parents, guardians, or teens may create their own logbook modelled on the SOS one"),
            stages=[dict(key="segment_2", label="Before Segment 2", total=30, night=2, counting="cumulative")]),
 "MN": dict(total=50, night=15, unit="minutes",
            alternatives=[dict(key="parent_class", label="Parent completed the supplemental parent class", total=40)]),
 "MS": dict(total=None, night=None),
 "MO": dict(total=40, night=10),
 "MT": dict(total=50, night=10, digital=("accepted", [], "bring log (hard copy or digital); official log says 'OR consider using a mobile app'")),
 "NE": dict(total=50, night=10, sup=(21, None, "supervisor 21+")),
 "NV": dict(total=50, night=10, unit="minutes",
            digital=("listed_apps", ["RoadReady"], "ONLY the DLD-130 or the RoadReady app log is accepted; parent/guardian signs page 1 even with the app")),
 "NH": dict(total=40, night=10, sup=(25, None, "licensed parent/guardian or licensed adult 25+"), parent_exempt=True,
            digital=("accepted", ["RoadReady"], "signed log sheet or the resources offered through the Parent's Supervised Driving Program (RoadReady)")),
 "NJ": dict(total=50, night=10, effective_from="2025-02-01"),
 "NM": dict(total=50, night=10, sup=(21, 3, "supervisor 21+ licensed 3 years"),
            digital=("accepted", [], "any handwritten or typed log with the required info")),
 "NY": dict(total=50, night=15, lessons=dict(max=None), lessons_note="certified driver-ed hours can count",
            fs={"instructor_max_minutes": "certified driver-ed hours can count; amount not specified"}, partial=True),
 "NC": dict(total=60, night=10, weekly_cap=10, digital=("accepted", [], "digital and printed copies accepted")),
 "ND": dict(total=50, night=None, fs={"total_minutes": "applies to applicants under 16 only", "night_minutes": "not specified ('variable conditions')"}),
 "OH": dict(total=50, night=10, notar=("required", "eligible adult signs the affidavit before a notary"),
            digital=("listed_apps", ["RoadReady Ohio"], "affidavit log can be completed manually or via the RoadReady Ohio app")),
 "OK": dict(total=50, night=10, sup=(21, 2, "trainer 21+ with Class D license 2+ years"), notar=("required", "complete before a notary")),
 "OR": dict(total=100, night=None, sup=(21, 3, "supervisor 21+ licensed 3 years"), fs={"night_minutes": "not specified"},
            alternatives=[dict(key="driver_ed", label="Completed ODOT-approved driver education", total=50)]),
 "PA": dict(total=65, night=10, weather=5, sup=(21, None, "supervisor 21+")),
 "RI": dict(total=50, night=10, notar=("required", "signed AND notarized parent affidavit")),
 "SC": dict(total=40, night=10),
 "SD": dict(total=50, night=10, weather=10, effective_from="2020-07-01", sup=(None, 1, "parent/guardian or licensed adult with 1+ yr experience"),
            notar=("required", "notary or DL examiner")),
 "TN": dict(total=50, night=10),
 "TX": dict(total=30, night=10, daily_cap=2, sup=(21, 1, "supervisor licensed 21+ with 1+ yr")),
 "UT": dict(total=40, night=10),
 "VT": dict(total=40, night=10),
 "VA": dict(total=45, night=15, pending=("2027-01-01", "New rules for first-time 18-20 applicants start Jan 1, 2027 (not modelled)")),
 "WA": dict(total=50, night=10, sup=(21, 3, "supervisor 21+ with valid license 3+ years (RCW 46.20.075)")),
 "WV": dict(total=50, night=10, sup=(21, None, "supervising adult 21+")),
 "WI": dict(total=50, night=10, effective_from="2021-07-11", lessons=dict(max=5, mult=2), lessons_note="each instructor hour counts as 2 (max 5 instructor hours)"),
 "WY": dict(total=50, night=10),
}
# Extra versions for permits issued before a change (effective_to = next version's effective_from).
EXTRA = {
 "NJ": dict(version=1, effective_to="2025-02-01", total=None, night=None, status="unconfirmed", kind="unconfirmed",
            label="New Jersey (permits issued before 2025-02-01)",
            fs={"total_minutes": "the research covers only permits issued on/after 2025-02-01; earlier requirement not researched"}),
 "WI": dict(version=1, effective_to="2021-07-11", total=30, night=None, status="partially_verified",
            label="Wisconsin (permits issued before 2021-07-11)",
            fs={"night_minutes": "not in research for permits before 2021-07-11",
                "instructor_multiplier": "instructor rule for permits before 2021-07-11 not in research (not counted)"}),
}
NIGHT_RULE = {"NH": "half_hour_after_sunset", "OH": "half_hour_after_sunset", "VT": "half_hour_after_sunset",
              "NY": "after_sunset", "UT": "after_sunset", "VA": "after_sunset",
              "NE": "sunset_sunrise", "NV": "darkness", "NJ": "darkness", "ME": "darkness"}
KIND = {"yes": "log", "yes (any format)": "log_any_format", "certification only": "certification", "no": "none", "unconfirmed": "unconfirmed"}
FORM = {"official full log PDF": "full_log", "certification-only PDF": "certification", "no official form": "none", "unconfirmed": "unconfirmed"}

def q(v):
    if v is None: return "null"
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return str(v)
    if isinstance(v, (list, dict)): return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb"
    return "'" + str(v).replace("'", "''") + "'"

def arr(v): return "'{" + ",".join('"%s"' % a for a in v) + "}'::text[]"
def m(h): return None if h is None else int(round(h * H))

rows = {r["abbr"]: r for r in csv.DictReader(open(CSV, newline="", encoding="utf-8"))}
assert len(rows) == 51, len(rows)
assert set(rows) == set(S), set(rows) ^ set(S)

cols = ["state_code", "version", "jurisdiction_name", "effective_from", "effective_to", "label", "status", "verified", "verified_on",
        "last_checked", "requirement_kind", "total_minutes", "night_minutes", "night_rule", "night_definition", "weather_minutes",
        "weather_counts_night", "daily_cap_minutes", "weekly_cap_minutes", "log_unit", "lessons_count", "instructor_multiplier",
        "instructor_max_minutes", "stages", "alternatives", "supervisor_min_age", "supervisor_min_years_licensed",
        "supervisor_parent_exempt", "supervisor_rule", "notarization", "notarization_note", "digital_log", "digital_log_apps",
        "digital_log_note", "form_type", "form_type_detail", "form_name", "form_number", "form_pdf_url", "form_pdf_status",
        "alt_form_name", "alt_form_pdf_url", "form_code", "form_url", "handbook_url", "parent_guide_url", "gdl_page_url",
        "source_url", "link_status", "other_rules", "notes", "field_status", "pending_change_on", "pending_change_note"]

def build(ab, spec, extra=None):
    r = rows[ab]; e = extra or {}
    kind = e.get("kind") or KIND[r["log_required"].strip()]
    total = m(e["total"]) if "total" in e else m(spec["total"])
    night = m(e["night"]) if "night" in e else m(spec.get("night"))
    fs = dict(e.get("fs") or spec.get("fs") or {}) if extra else dict(spec.get("fs") or {})
    status = e.get("status")
    if not status:
        if kind == "unconfirmed": status = "unconfirmed"
        elif spec.get("partial") or any(v.startswith("not verified") for k, v in r.items() if k.endswith("_status") and v): status = "partially_verified"
        else: status = "verified"
    if extra is None and spec.get("lessons_note"): fs.setdefault("lessons_count", spec["lessons_note"])
    les = spec.get("lessons") if extra is None else None
    sup = spec.get("sup", (None, None, "")) if extra is None or ab != "NJ" else (None, None, "")
    if ab == "HI": sup = (None, None, "")
    notar = spec.get("notar", ("not_stated", ""))
    dig = spec.get("digital", ("not_stated", [], spec.get("digital_note", "")))
    stages = [] if extra else [dict(key=s["key"], label=s["label"], total_minutes=m(s.get("total")), night_minutes=m(s.get("night")),
                                    weather_minutes=m(s.get("weather")), counting=s["counting"], **({"milestone": s["milestone"]} if "milestone" in s else {}))
                               for s in spec.get("stages", [])]
    alts = [] if extra else [dict(key=a["key"], label=a["label"], total_minutes=m(a.get("total")), night_minutes=m(a.get("night")),
                                  weather_minutes=None, replaces_hours=bool(a.get("replaces_hours")))
                             for a in spec.get("alternatives", [])]
    name = r["state"]
    label = e.get("label") or (f"{name}: {r['log_form_name']}" if r["log_form_name"] else f"{name}: no hours requirement" if kind == "none" else name)
    v = dict(
        state_code=ab, version=e.get("version", 2 if ab in EXTRA else 1), jurisdiction_name=name,
        effective_from=e.get("effective_from", spec.get("effective_from", "2000-01-01") if not extra else "2000-01-01"),
        effective_to=e.get("effective_to"), label=label[:200], status=status, verified=status == "verified",
        verified_on=r["last_checked"] if status == "verified" else None, last_checked=r["last_checked"],
        requirement_kind=kind, total_minutes=total if kind not in ("none",) else None, night_minutes=night if kind != "none" else None,
        night_rule=NIGHT_RULE.get(ab, "unspecified"), night_definition=r["night_hours"],
        weather_minutes=None if extra else m(spec.get("weather")), weather_counts_night=bool(spec.get("weather_counts_night")) and not extra,
        daily_cap_minutes=None if extra else m(spec.get("daily_cap")), weekly_cap_minutes=None if extra else m(spec.get("weekly_cap")),
        log_unit=spec.get("unit", "hours"), lessons_count=bool(les), instructor_multiplier=(les or {}).get("mult", 1),
        instructor_max_minutes=m((les or {}).get("max")), stages=stages, alternatives=alts,
        supervisor_min_age=sup[0], supervisor_min_years_licensed=sup[1], supervisor_parent_exempt=bool(spec.get("parent_exempt")),
        supervisor_rule=sup[2], notarization=notar[0], notarization_note=notar[1],
        digital_log=dig[0], digital_log_apps=dig[1], digital_log_note=dig[2],
        form_type=FORM[r["category"]], form_type_detail=r["log_form_type"], form_name=r["log_form_name"], form_number=r["log_form_number"],
        form_pdf_url=r["log_pdf_url"], form_pdf_status=r["log_pdf_status"], alt_form_name=r["alt_form_name"], alt_form_pdf_url=r["alt_form_pdf_url"],
        form_code=r["log_form_number"], form_url=r["log_pdf_url"], handbook_url=r["handbook_url"], parent_guide_url=r["parent_guide_url"],
        gdl_page_url=r["gdl_page_url"], source_url=r["source_page_url"],
        link_status={k: r[s] for k, s in [("form_pdf", "log_pdf_status"), ("alt_form_pdf", "alt_form_pdf_status"), ("handbook", "handbook_status"),
                                           ("parent_guide", "parent_guide_status"), ("gdl_page", "gdl_page_status"), ("source_page", "source_page_status")] if r[s]},
        other_rules=r["other_rules"], notes=r["notes"], field_status=fs,
        pending_change_on=(spec.get("pending") or (None, None))[0] if not extra else None,
        pending_change_note=(spec.get("pending") or (None, ""))[1] or "" if not extra else "",
    )
    out = []
    for c in cols:
        x = v[c]
        out.append(arr(x) if c == "digital_log_apps" else q(x))
    return "  (" + ", ".join(out) + ")"

values = []
for ab in sorted(S):
    if ab in EXTRA: values.append(build(ab, S[ab], EXTRA[ab]))
    values.append(build(ab, S[ab]))

sql = f"""-- LicenseLogger 015: reference data for all 51 jurisdictions (50 states + DC).
-- GENERATED by scripts/build_state_rules_seed.py from the verified research in
-- state-driving-logs/state_logs.csv (official sources, last checked 2026-10-22).
-- This is real reference data, not fake. Unknown values are NULL with a note in field_status.
-- Re-run the script and add a NEW migration to change the data later; don't edit this file once pushed.

-- The v1 example rows from migration 006 (MI/CO/NY/CA/PA) are replaced by the researched values.
insert into public.state_rule_sets ({", ".join(cols)})
values
{(","+chr(10)).join(values)}
on conflict (state_code, version) do update set
{(","+chr(10)).join(f"  {c} = excluded.{c}" for c in cols if c not in ("state_code", "version"))};
"""
OUT.write_text(sql, encoding="utf-8")
print(f"wrote {OUT} ({len(values)} rule sets for {len(S)} jurisdictions)")
