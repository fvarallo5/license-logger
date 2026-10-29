#!/usr/bin/env python3
"""Validate the per-state log layout specs and build the combined layouts.json.

    python3 scripts/build_log_layouts.py [--pdfs PATH_TO_PDF_DIR] [--check]

Source of truth: docs/log_layouts/<ST>.json (one file per state with an official form).
Outputs (both byte-identical):
  docs/log_layouts/layouts.json                          read by the app generator (tool/build_state_rules.py)
  supabase/functions/export-report/log_layouts.json      bundled with the export-report Edge Function
  docs/log_layouts/EVIDENCE.md                           where every printed label/quote was found in the PDF text

Checks:
  * schema: required keys, known column/value keys, filters, formats (fails the build).
  * evidence: every label, heading and quoted sentence must appear in the official PDF's text
    (pdftotext raw and -layout). "exact" = normalized substring; "ordered" = same words in order
    within a short window (multi-line table headers); "scattered" = all words on the page set but
    split by layout (listed for manual review); "missing" fails unless listed in "evidence_exempt".
  * --check: fail if the outputs are not up to date (CI / drift check).
"""
import glob, hashlib, json, os, re, subprocess, sys, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
SPEC_DIR = os.path.join(ROOT, 'docs', 'log_layouts')
OUT_DOCS = os.path.join(SPEC_DIR, 'layouts.json')
OUT_FN = os.path.join(ROOT, 'supabase', 'functions', 'export-report', 'log_layouts.json')
EVIDENCE = os.path.join(SPEC_DIR, 'EVIDENCE.md')
DEFAULT_PDFS = os.path.normpath(os.path.join(ROOT, '..', 'state-driving-logs', 'pdfs'))

COLUMN_KEYS = {"date", "date_time", "start_time", "end_time", "time_range", "amount", "day_amount", "night_amount", "weather_amount",
               "day_hours_part", "day_minutes_part", "night_hours_part", "night_minutes_part", "day_or_night", "cumulative", "weather",
               "roadway", "conditions", "conditions_skills", "location", "skills", "skills_abbrev", "supervisor_name", "supervisor_initials",
               "student_initials", "notes", "blank"}
SUMMABLE = {"amount", "day_amount", "night_amount", "weather_amount"}
VALUE_KEYS = {"", "student_name", "student_name_lfm", "student_first", "student_last", "student_initials", "permit_number", "birthday",
              "permit_issued", "school_name", "supervisor_name", "total", "day", "night", "weather", "total_minutes", "day_minutes",
              "night_minutes", "weather_minutes", "total_hours", "day_hours", "night_hours"}
PLACEHOLDER = re.compile(r"\{([a-z_]+)\}")
FILTERS = {"all", "day", "night", "none"}
AMOUNT_FORMATS = {"hr_min", "hours", "minutes", "hm"}
DATE_FORMATS = {"m/d/yy", "mm/dd/yyyy", "m/d"}
MODES = {"check", "accepted", "transfer"}

# States without a matched layout: they use "generic" below. Reasons come from state_logs.csv.
GENERIC_STATES = {
    "AZ": {"state_name": "Arizona", "reason": "blocked", "form": "Driving Practice Certificate 96-0223 (R07/25)",
           "detail": "azdot.gov returned HTTP 403 to the download (retried once with a browser user agent on 2026-10-22)."},
    "IL": {"state_name": "Illinois", "reason": "blocked", "form": "50-Hour Practice Driving Log DSD X 152 (Mar 2026) / Affidavit DSD X 174",
           "detail": "ilsos.gov failed the download (HTTP/2 INTERNAL_ERROR; an HTTP/1.1 retry timed out) on 2026-10-22."},
    "NH": {"state_name": "New Hampshire", "reason": "blocked", "form": "Certification of Additional Supervised Driving DSMV 509 (Rev. 6/23)",
           "detail": "dmv.nh.gov returned HTTP 403 to the download (retried once with a browser user agent on 2026-10-22)."},
    "AR": {"state_name": "Arkansas", "reason": "no_form", "form": "", "detail": "No official log or certification form."},
    "GA": {"state_name": "Georgia", "reason": "no_form", "form": "Driving Experience Affidavit DDS-7",
           "detail": "Completed at DDS; no downloadable PDF."},
    "ID": {"state_name": "Idaho", "reason": "no_form", "form": "GDL Requirements Verification",
           "detail": "Statement signed at DMV; no downloadable PDF found."},
    "LA": {"state_name": "Louisiana", "reason": "no_form", "form": "", "detail": "Signed parent/guardian statement; no specific OMV form found."},
    "MS": {"state_name": "Mississippi", "reason": "no_form", "form": "", "detail": "No official log or certification form."},
    "NM": {"state_name": "New Mexico", "reason": "no_form", "form": "GDL driving log (any document)",
           "detail": "MVD accepts any handwritten or typed log with the required information.",
           "acceptance": {"mode": "accepted", "basis": "GDL driving log (Graduated Driver's License log - any document that records the necessary information handwritten or typed)",
                          "source": "NM MVD page, quoted in state_logs.csv"}},
    "ND": {"state_name": "North Dakota", "reason": "no_form", "form": "", "detail": "Parent signs at the road test; no separate form."},
    "VA": {"state_name": "Virginia", "reason": "no_form", "form": "", "detail": "Parent certifies on the school-submitted driver education completion certificate."},
    "HI": {"state_name": "Hawaii", "reason": "unconfirmed", "form": "Acknowledgment/Affidavit of Practice Driving (HDOT 6/07, unconfirmed)",
           "detail": "Only found on school/driving-school sites; the official requirement is unconfirmed."},
}

GENERIC = {
    "schema": "licenselogger.log_layout/v1", "state_code": "", "state_name": "", "kind": "generic",
    "form": {"name": "Supervised driving log", "number": "", "revision": "", "source_pdf": "", "source_pages": [], "url": "", "extra_sources": []},
    "page": {"size": [612, 792], "orientation": "portrait"}, "title": "Supervised driving log",
    "header_fields": [{"label": "Student", "value": "student_name"}, {"label": "Permit #", "value": "permit_number"},
                      {"label": "Permit issued", "value": "permit_issued"}],
    "amount_format": "hr_min", "date_format": "m/d/yy",
    "tables": [{"panels": [{"filter": "all", "columns": [
        {"label": "Date", "key": "date", "w": 0.9}, {"label": "Start", "key": "start_time", "w": 0.8}, {"label": "End", "key": "end_time", "w": 0.8},
        {"label": "Time", "key": "amount", "w": 0.9}, {"label": "Night", "key": "night_amount", "w": 0.9},
        {"label": "Weather", "key": "weather", "w": 0.9}, {"label": "Supervisor", "key": "supervisor_name", "w": 1.6},
        {"label": "Initials", "key": "supervisor_initials", "w": 0.7}]}], "rows": 30, "rows_first": 24,
        "page_total": {"label": "Page total", "sum": ["amount", "night_amount"]}}],
    "summary": [{"label": "Total", "value": "total"}, {"label": "Night", "value": "night"}],
    "certification": {"title": "Parent / guardian", "text": "", "fields": [], "totals": [],
                      "signatures": [{"label": "Parent / guardian signature", "value": ""}, {"label": "Printed name", "value": ""}, {"label": "Date", "value": ""}],
                      "notary": None},
    "cert_position": "after_log", "legend": None, "abbrev": {}, "unfillable": [], "notes": ["LicenseLogger's own layout (no official form layout on file)."],
    "acceptance": {"mode": "check", "basis": "", "source": ""},
}


def norm(s):
    s = unicodedata.normalize("NFKC", s)
    s = s.replace("\u2019", "'").replace("\u2018", "'").replace("\u201c", '"').replace("\u201d", '"')
    s = s.replace("\u2013", "-").replace("\u2014", "-").replace("\u00ad", "")
    s = re.sub(r"[^A-Za-z0-9#&%/]+", " ", s.lower())
    return re.sub(r"\s+", " ", s).strip()


def pdf_text(path, pages):
    out = []
    for args in (["pdftotext"], ["pdftotext", "-layout"]):
        for p in pages or [None]:
            cmd = list(args) + (["-f", str(p), "-l", str(p)] if p else []) + [path, "-"]
            out.append(subprocess.run(cmd, capture_output=True, text=True).stdout)
    return norm("\n".join(out))


def find(label, text):
    n = norm(label)
    if not n:
        return "exact"
    if n in text:
        return "exact"
    words, toks = n.split(), text.split()
    # ordered within a window of 4x the label length
    pos = {}
    for i, t in enumerate(toks):
        pos.setdefault(t, []).append(i)
    if all(w in pos for w in words):
        win = max(12, 4 * len(words))
        for start in pos[words[0]]:
            j, ok = start, True
            for w in words[1:]:
                nxt = [k for k in pos[w] if j < k <= start + win]
                if not nxt:
                    ok = False
                    break
                j = nxt[0]
            if ok:
                return "ordered"
        return "scattered"
    return "missing"


def quote_parts(text):
    """Split a quoted sentence at placeholders and blank lines so each printed piece is checked."""
    parts = re.split(r"\{[a-z_]+\}|_{2,}|\.\.\.|\[ \]", text or "")
    return [p.strip(" ,.;:") for p in parts if len(norm(p).split()) >= 1]


def labels_of(spec):
    out = [("title", spec["title"])]
    if spec.get("subtitle"):
        out.append(("subtitle", spec["subtitle"]))
    if spec["form"]["number"]:
        out.append(("form number", spec["form"]["number"]))
    if spec["form"]["revision"]:
        out.append(("revision", spec["form"]["revision"]))
    for f in spec["header_fields"]:
        out.append(("header field", f["label"]))
    for t in spec["tables"]:
        if t.get("title"):
            out.append(("table title", t["title"]))
        for p in t["panels"]:
            if p.get("title"):
                out.append(("panel title", p["title"]))
            for c in p["columns"]:
                out.append(("column", c["label"]))
                if c.get("group"):
                    out.append(("column group", c["group"]))
        if t.get("page_total"):
            out.append(("page total", t["page_total"]["label"]))
    for f in spec["summary"]:
        out.append(("summary", f["label"]))
    c = spec.get("certification")
    if c:
        if c["title"]:
            out.append(("certification title", c["title"]))
        for part in quote_parts(c["text"]):
            out.append(("certification text", part))
        for part in quote_parts(c.get("extra_text", "")):
            out.append(("certification extra", part))
        for k in ("fields", "totals", "signatures"):
            for f in c[k]:
                out.append((f"certification {k[:-1]}", f["label"]))
        n = c.get("notary")
        if n:
            if n["title"]:
                out.append(("notary title", n["title"]))
            for part in quote_parts(n["text"]):
                out.append(("notary text", part))
            for l in n["lines"]:
                out.append(("notary line", l))
    return out


def validate(spec, st):
    errs = []
    for k in ("schema", "state_code", "kind", "form", "page", "title", "header_fields", "amount_format", "date_format", "tables",
              "summary", "certification", "cert_position", "unfillable", "notes", "acceptance"):
        if k not in spec:
            errs.append(f"missing key {k}")
    if errs:
        return errs
    if spec["state_code"] != st:
        errs.append("state_code does not match file name")
    if spec["kind"] not in ("full_log", "certification"):
        errs.append(f"bad kind {spec['kind']}")
    if spec["amount_format"] not in AMOUNT_FORMATS:
        errs.append("bad amount_format")
    if spec["date_format"] not in DATE_FORMATS:
        errs.append("bad date_format")
    if spec["acceptance"]["mode"] not in MODES:
        errs.append("bad acceptance mode")
    if spec["acceptance"]["mode"] != "check" and not spec["acceptance"]["basis"]:
        errs.append("accepted/transfer needs a quoted basis")
    if spec["cert_position"] not in ("before_log", "after_log"):
        errs.append("bad cert_position")
    if spec["kind"] == "full_log" and not spec["tables"]:
        errs.append("full_log needs a table")
    if spec["kind"] == "certification" and not spec["certification"]:
        errs.append("certification kind needs a certification block")
    w, h = spec["page"]["size"]
    if not (200 <= w <= 1300 and 200 <= h <= 1300):
        errs.append("odd page size")
    for t in spec["tables"]:
        if t["rows"] < 1 or t["rows_first"] < 1:
            errs.append("rows must be >= 1")
        for p in t["panels"]:
            if p["filter"] not in FILTERS:
                errs.append(f"bad filter {p['filter']}")
            for c in p["columns"]:
                if c["key"] not in COLUMN_KEYS:
                    errs.append(f"unknown column key {c['key']}")
                if c["w"] <= 0:
                    errs.append("column width must be > 0")
        pt = t.get("page_total")
        if pt:
            keys = {c["key"] for p in t["panels"] for c in p["columns"]}
            for k in pt["sum"]:
                if k not in SUMMABLE or k not in keys:
                    errs.append(f"page_total sums {k}, which is not a summable column of the table")
    fields = list(spec["header_fields"]) + list(spec["summary"])
    c = spec["certification"]
    if c:
        fields += c["fields"] + c["totals"] + c["signatures"]
        for ph in PLACEHOLDER.findall(c["text"] + c.get("extra_text", "")):
            if ph not in VALUE_KEYS:
                errs.append(f"unknown placeholder {{{ph}}}")
    for f in fields:
        if f["value"] not in VALUE_KEYS:
            errs.append(f"unknown value key {f['value']}")
    for k, v in spec["abbrev"].items():
        if not v:
            errs.append(f"empty abbreviation for {k}")
    return errs


def main():
    args = sys.argv[1:]
    pdfs = DEFAULT_PDFS
    if "--pdfs" in args:
        pdfs = args[args.index("--pdfs") + 1]
    check_only = "--check" in args
    specs, errors = {}, []
    for path in sorted(glob.glob(os.path.join(SPEC_DIR, "[A-Z][A-Z].json"))):
        st = os.path.basename(path)[:2]
        spec = json.load(open(path, encoding="utf-8"))
        for e in validate(spec, st):
            errors.append(f"{st}: {e}")
        specs[st] = spec
    overlap = set(specs) & set(GENERIC_STATES)
    if overlap:
        errors.append(f"states both matched and generic: {sorted(overlap)}")

    # ---- evidence
    ev_lines = ["# Log layout evidence", "",
                "Generated by scripts/build_log_layouts.py. Every printed label and quoted sentence in docs/log_layouts/<ST>.json",
                "was searched for in the official PDF text (pdftotext raw + -layout, the pages listed in the spec).",
                "exact = found verbatim (after normalizing quotes/punctuation); ordered = same words in order within a short window",
                "(multi-line table headers); scattered = words present but split by the layout (checked by eye on the rendered page).", ""]
    have_pdfs = os.path.isdir(pdfs)
    counts = {"exact": 0, "ordered": 0, "scattered": 0, "missing": 0}
    if not have_pdfs:
        print(f"evidence check skipped ({pdfs} not found)")
    for st, spec in sorted(specs.items()):
        if not have_pdfs:
            break
        srcs = [(spec["form"]["source_pdf"], spec["form"]["source_pages"])] + [(e["pdf"], e["pages"]) for e in spec["form"]["extra_sources"]]
        text = ""
        for pdf, pages in srcs:
            p = os.path.join(pdfs, pdf)
            if not os.path.exists(p):
                errors.append(f"{st}: source PDF {pdf} not found")
                continue
            text += " " + pdf_text(p, pages)
        exempt = set(spec.get("evidence_exempt", []))
        rows = []
        for kind, label in labels_of(spec):
            r = find(label, text)
            counts[r] += 1
            if r == "missing" and label not in exempt:
                errors.append(f"{st}: {kind} not found in PDF text: {label!r}")
            if r != "exact":
                rows.append(f"| {kind} | {label} | {r} |")
        ev_lines.append(f"## {st} - {spec['form']['name']} {spec['form']['number']}".rstrip())
        ev_lines.append(f"Sources: {', '.join(f'{p} pp.{pp}' for p, pp in srcs)}. {len(labels_of(spec))} labels checked.")
        if rows:
            ev_lines += ["", "| what | label | match |", "|---|---|---|"] + rows
        else:
            ev_lines.append("All exact.")
        ev_lines.append("")
    if errors:
        print("\n".join(errors))
        sys.exit(1)

    body = {"schema": "licenselogger.log_layouts/v1",
            "doc": "docs/log_layouts/README.md",
            "states": specs, "generic": GENERIC, "generic_states": GENERIC_STATES}
    raw = json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    body["sha256"] = hashlib.sha256(raw.encode()).hexdigest()
    text = json.dumps(body, ensure_ascii=False, indent=1, sort_keys=True) + "\n"
    if check_only:
        stale = [p for p in (OUT_DOCS, OUT_FN) if not os.path.exists(p) or open(p, encoding="utf-8").read() != text]
        if stale:
            print("layouts.json is out of date: run python3 scripts/build_log_layouts.py\n  " + "\n  ".join(stale))
            sys.exit(1)
        print(f"log layouts up to date: {len(specs)} states, sha256 {body['sha256'][:12]}")
        return
    for p in (OUT_DOCS, OUT_FN):
        with open(p, "w", encoding="utf-8") as f:
            f.write(text)
    if have_pdfs:
        with open(EVIDENCE, "w", encoding="utf-8") as f:
            f.write("\n".join(ev_lines))
    print(f"wrote {len(specs)} layouts (+ generic for {len(GENERIC_STATES)} states), sha256 {body['sha256'][:12]}")
    if have_pdfs:
        print("evidence:", counts)


if __name__ == "__main__":
    main()
