// Pure rendering (no network): CSV and PDF from already-authorized data.
// Unit-tested in render_test.ts.
import { PDFDocument, type PDFFont, type PDFPage, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";
import layoutsJson from "./log_layouts.json" with { type: "json" };
import { buildLogDocument, type Layouts, type LogDocument, type LogInput, renderStateLogPdf } from "./log_layout.ts";

export type Summary = {
  rule_label: string | null;
  rule_verified: boolean;
  form_code: string | null;
  state_code: string;
  required_minutes: number | null;
  required_night_minutes: number | null;
  daily_cap_minutes: number | null;
  credited_minutes: number;
  night_credited_minutes: number;
  day_credited_minutes: number;
  pending_extra_minutes: number;
  pending_drives: number;
  signed_miles: number;
  lesson_minutes: number;
  school_goal_minutes: number | null;
  requirement_met: boolean; // null for independent students
  remaining_minutes?: number;
  remaining_night_minutes?: number;
};
export type Day = {
  local_date: string;
  raw_minutes: number;
  credited_minutes: number;
  night_credited_minutes: number;
  capped: boolean;
  raw_weather_minutes?: number;
  weather_credited_minutes?: number;
  week_start?: string;
};
/** Subset of student_rule_progress() used here (docs/STATE_RULES_SCHEMA.md section 6). */
export type Requirement = {
  key: string;
  label: string;
  required_minutes: number;
  credited_minutes: number;
  pending_minutes: number;
  remaining_minutes: number;
  met: boolean;
};
export type Progress = {
  rule: null | {
    state_code: string;
    jurisdiction_name: string;
    version: number;
    label: string;
    status: string;
    requirement_kind: string;
    log_unit: "hours" | "minutes";
    permit_on: string | null;
    selected_by: string;
  };
  alternative: null | { key: string; label: string; replaces_hours: boolean };
  caps?: { daily_minutes: number | null; weekly_minutes: number | null; capped_days: number; capped_weeks: number };
  instructor?: {
    counts: boolean;
    multiplier: number;
    max_minutes: number | null;
    raw_minutes: number;
    counted_minutes: number;
    credited_minutes: number;
  };
  requirements: Requirement[];
  stages: {
    key: string;
    label: string;
    window_from: string | null;
    milestone_assumed: boolean;
    met: boolean;
    requirements: Requirement[];
  }[];
  all_met: boolean | null;
  still_needed: string[];
  supervisor?: {
    min_age: number | null;
    min_years_licensed: number | null;
    parent_exempt: boolean;
    rule: string;
    unverified_drives: number;
  };
};
/** Subset of state_resources() / my_rule_resources() used here (section 7). */
export type Resources = {
  form: {
    type: string;
    name: string;
    number: string;
    pdf_url: string;
    notarization: string;
    notarization_note: string;
    digital_log: string;
    digital_log_apps: string[];
    digital_log_note: string;
  };
  how_to_use_licenselogger_log: string;
  last_checked: string | null;
  status: string;
};
export type Drive = {
  id: string;
  kind: string;
  source: string;
  status: string;
  started_at: string;
  ended_at: string | null;
  tz?: string;
  local_date: string;
  duration_minutes: number;
  night_minutes: number;
  distance_miles: number;
  supervisor_name: string | null;
  start_label: string;
  end_label: string;
  conditions: string[];
  skills: string[];
  notes: string;
  route_polyline?: string | null;
  weather_minutes?: number;
};
export type Signoff = {
  drive_id: string;
  method: string;
  supervisor_name: string;
  initials: string | null;
  signed_at: string;
  snapshot_sha256: string;
};
export type Student = {
  first_name: string;
  last_name: string;
  state_code: string;
  permit_on: string | null;
  school_name: string;
  school_phone: string;
};

/** Shown where the school name goes for students who practise without a driving school. */
export const INDEPENDENT_LABEL = "Independent (practising with family)";

export const hm = (m: number) => `${Math.floor(m / 60)}h ${String(Math.round(m % 60)).padStart(2, "0")}m`;
export const h1 = (m: number) => (Math.round(m / 6) / 10).toFixed(1);

export function localTime(iso: string | null, tz = "America/Chicago"): string {
  if (!iso) return "";
  return new Intl.DateTimeFormat("en-US", { timeZone: tz, hour: "numeric", minute: "2-digit" }).format(new Date(iso));
}

/** Spreadsheet-safe CSV cell (quotes + formula-injection guard). */
export function cell(v: unknown): string {
  let s = v === null || v === undefined ? "" : Array.isArray(v) ? v.join("; ") : String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export function renderCsv(drives: Drive[], signoffs: Signoff[], days: Day[]): string {
  const sig = new Map(signoffs.map((s) => [s.drive_id, s]));
  const dayCredit = new Map(days.map((d) => [d.local_date, d.credited_minutes]));
  const header = [
    "drive_id",
    "date",
    "start",
    "end",
    "kind",
    "source",
    "status",
    "minutes",
    "night_minutes",
    "miles",
    "day_credited_minutes",
    "supervisor",
    "signed_by",
    "sign_method",
    "initials",
    "signed_at",
    "conditions",
    "skills",
    "notes",
    "snapshot_sha256",
    "weather_minutes",
  ];
  const rows = [...drives].sort((a, b) => a.started_at.localeCompare(b.started_at)).map((d) => {
    const s = sig.get(d.id);
    return [
      d.id,
      d.local_date,
      localTime(d.started_at, d.tz),
      localTime(d.ended_at, d.tz),
      d.kind,
      d.source,
      d.status,
      d.duration_minutes,
      d.night_minutes,
      d.distance_miles,
      d.status === "signed" && d.kind === "practice" ? dayCredit.get(d.local_date) ?? "" : "",
      d.supervisor_name ?? "",
      s?.supervisor_name ?? "",
      s?.method ?? "",
      s?.initials ?? "",
      s?.signed_at ?? "",
      d.conditions,
      d.skills,
      d.notes,
      s?.snapshot_sha256 ?? "",
      d.weather_minutes ?? 0,
    ].map(cell).join(",");
  });
  return "\uFEFF" + [header.join(","), ...rows].join("\r\n") + "\r\n";
}

// Standard PDF fonts only cover Latin-1; replace anything else so rendering never throws.
const safe = (s: string) =>
  s.replace(/[\u2013\u2014]/g, "-").replace(/[\u2018\u2019]/g, "'").replace(/[\u201C\u201D]/g, '"')
    .replace(/[^\x20-\x7E\u00A0-\u00FF]/g, "?");

export function decodePolyline(str: string, precision = 5): [number, number][] {
  let i = 0, lat = 0, lng = 0;
  const out: [number, number][] = [], f = Math.pow(10, precision);
  while (i < str.length) {
    for (const which of [0, 1]) {
      let shift = 0, result = 0, b: number;
      do {
        b = str.charCodeAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && i < str.length);
      const d = result & 1 ? ~(result >> 1) : result >> 1;
      if (which === 0) lat += d;
      else lng += d;
    }
    out.push([lat / f, lng / f]);
  }
  return out;
}

type Ctx = { doc: PDFDocument; page: PDFPage; font: PDFFont; bold: PDFFont; y: number; pageNo: number; footer: string };
const NAVY = rgb(0.06, 0.11, 0.18), GREY = rgb(0.42, 0.45, 0.5), AMBER = rgb(0.72, 0.45, 0.05);

function newPage(c: Ctx) {
  c.page = c.doc.addPage([612, 792]);
  c.pageNo++;
  c.y = 750;
  c.page.drawText(safe(`${c.footer}  ·  page ${c.pageNo}`), { x: 40, y: 24, size: 7, font: c.font, color: GREY });
}
function text(c: Ctx, s: string, x: number, size = 9, f?: PDFFont, color = NAVY) {
  c.page.drawText(safe(s), { x, y: c.y, size, font: f ?? c.font, color });
}
function ensure(c: Ctx, h: number) {
  if (c.y - h < 50) newPage(c);
}

/** Amount in the state's own unit: "47 min" for minute states (MN, NV), else "1.2 h". */
export const amt = (m: number, unit: "hours" | "minutes" = "hours") =>
  unit === "minutes" ? `${Math.round(m).toLocaleString("en-US")} min` : `${h1(m)} h`;

/** What the official paperwork needs, in plain words (also used by the app preview). */
export function paperworkLines(res: Resources | null | undefined): string[] {
  if (!res) return [];
  const f = res.form, out: string[] = [];
  const form = f.name ? `${f.name}${f.number ? ` (${f.number})` : ""}` : "";
  if (form) out.push(`State form: ${form}`);
  if (f.pdf_url) out.push(`Official PDF: ${f.pdf_url}`);
  switch (res.how_to_use_licenselogger_log) {
    case "copy_to_official_form":
      out.push(
        `The state asks for its own log. Copy these entries onto the state form and sign it there; this report is your worksheet.`,
      );
      break;
    case "official_form_only":
      out.push(
        `Only the state form${
          f.digital_log_apps.length ? ` or ${f.digital_log_apps.join(" / ")}` : ""
        } is accepted. ${f.digital_log_note}`.trim(),
      );
      break;
    case "submit_printout":
      out.push(`A printed or digital log is accepted. ${f.digital_log_note}`.trim());
      break;
    case "records_only":
      out.push("The state needs a signed certification of the hours; keep this log as the record behind it.");
      break;
    case "none":
      out.push("This state has no supervised-hours requirement; this log is for your own records.");
      break;
    default:
      out.push("This state's requirement is unconfirmed. Check with the licensing office before relying on it.");
  }
  return out;
}

export async function renderHoursPdf(opts: {
  student: Student;
  summary: Summary;
  days: Day[];
  drives: Drive[];
  signoffs: Signoff[];
  generatedAt: string;
  exportId: string;
  progress?: Progress | null;
  resources?: Resources | null;
}): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.setTitle(`Driving log - ${opts.student.first_name} ${opts.student.last_name}`);
  doc.setProducer("LicenseLogger");
  const c: Ctx = {
    doc,
    page: undefined as unknown as PDFPage,
    font: await doc.embedFont(StandardFonts.Helvetica),
    bold: await doc.embedFont(StandardFonts.HelveticaBold),
    y: 0,
    pageNo: 0,
    footer: `LicenseLogger export ${opts.exportId} · generated ${opts.generatedAt}`,
  };
  newPage(c);
  const s = opts.summary, st = opts.student, pr = opts.progress ?? null, res = opts.resources ?? null;
  const unit = pr?.rule?.log_unit ?? "hours";
  const status = pr?.rule?.status ?? (s.rule_verified ? "verified" : "unconfirmed");
  const reqs: Requirement[] = pr?.requirements ?? [
    {
      key: "total",
      label: "Total supervised driving",
      required_minutes: s.required_minutes ?? 0,
      credited_minutes: s.credited_minutes,
      pending_minutes: s.pending_extra_minutes,
      remaining_minutes: s.remaining_minutes ?? 0,
      met: s.requirement_met,
    },
    {
      key: "night",
      label: "At night",
      required_minutes: s.required_night_minutes ?? 0,
      credited_minutes: s.night_credited_minutes,
      pending_minutes: 0,
      remaining_minutes: s.remaining_night_minutes ?? 0,
      met: s.requirement_met,
    },
  ];
  const hasWeather = reqs.some((r) => r.key === "weather" || r.key === "challenging");

  // ---- Header + form reference
  const place = pr?.rule?.jurisdiction_name ?? st.state_code;
  text(c, `Supervised driving log - ${place}`, 40, 18, c.bold);
  c.y -= 22;
  text(
    c,
    `${st.first_name} ${st.last_name}  ·  ${st.school_name}${st.school_phone ? "  ·  " + st.school_phone : ""}` +
      `${st.permit_on ? `  ·  permit issued ${st.permit_on}` : ""}`,
    40,
    10,
  );
  c.y -= 14;
  text(
    c,
    `${s.rule_label ?? `No rule on file for ${st.state_code}`}${pr?.rule ? `  ·  rule v${pr.rule.version}` : ""}`,
    40,
    10,
  );
  c.y -= 14;
  if (pr?.alternative) {
    text(c, `Path: ${pr.alternative.label}`, 40, 9);
    c.y -= 13;
  }
  for (const line of paperworkLines(res)) {
    ensure(c, 14);
    text(c, line.slice(0, 130), 40, 8, c.font, GREY);
    c.y -= 11;
  }
  if (status !== "verified") {
    const msg = status === "partially_verified"
      ? "Some details of this state's rule are not fully verified. Check the official requirement before submitting."
      : "This state's requirement is UNCONFIRMED. Check the official requirement before submitting.";
    text(c, msg, 40, 9, c.bold, AMBER);
    c.y -= 14;
  }
  c.y -= 6;

  // ---- Requirement boxes (one per requirement, then pending + miles)
  const boxes: [string, string][] = reqs.map((
    r,
  ) => [
    r.label + (r.met ? "  (met)" : ""),
    `${amt(r.credited_minutes, unit)}${r.required_minutes ? ` of ${amt(r.required_minutes, unit)}` : ""}`,
  ]);
  if (!pr?.requirements?.length && pr) {
    boxes.splice(0, boxes.length, ["Credited (signed)", amt(s.credited_minutes, unit)]);
  }
  boxes.push(["Waiting for signature", `${amt(s.pending_extra_minutes, unit)} (${s.pending_drives})`]);
  boxes.push(["Miles (signed)", `${Number(s.signed_miles).toFixed(1)}`]);
  const w = Math.min(125, Math.floor(532 / boxes.length) - 6);
  boxes.slice(0, 6).forEach(([k, v], i) => {
    const x = 40 + i * (w + 6);
    c.page.drawRectangle({ x, y: c.y - 30, width: w, height: 40, color: rgb(0.95, 0.96, 0.98) });
    c.page.drawText(safe(k.slice(0, 30)), { x: x + 6, y: c.y - 2, size: 6.5, font: c.font, color: GREY });
    c.page.drawText(safe(v), { x: x + 6, y: c.y - 20, size: boxes.length > 4 ? 9 : 12, font: c.bold, color: NAVY });
  });
  c.y -= 50;
  const capDaily = pr?.caps?.daily_minutes ?? s.daily_cap_minutes, capWeekly = pr?.caps?.weekly_minutes ?? null;
  if (capDaily) {
    text(c, `Daily cap: at most ${amt(capDaily, unit)} per day counts toward the log.`, 40, 8, c.font, GREY);
    c.y -= 12;
  }
  if (capWeekly) {
    text(
      c,
      `Weekly cap: at most ${amt(capWeekly, unit)} per week (Mon-Sun) counts.${
        pr?.caps?.capped_weeks ? ` ${pr.caps.capped_weeks} week(s) hit the cap.` : ""
      }`,
      40,
      8,
      c.font,
      GREY,
    );
    c.y -= 12;
  }
  if (pr?.instructor?.counts) {
    const i = pr.instructor;
    text(
      c,
      `Instructor lessons: ${amt(i.raw_minutes, unit)} taken, ${amt(i.counted_minutes, unit)} counted` +
        `${i.multiplier !== 1 ? ` x${i.multiplier}` : ""} = ${amt(i.credited_minutes, unit)} credited.`,
      40,
      8,
      c.font,
      GREY,
    );
    c.y -= 12;
  }
  for (const sg of pr?.stages ?? []) {
    ensure(c, 14);
    const detail = sg.requirements.map((r) =>
      `${r.label.toLowerCase()} ${amt(r.credited_minutes, unit)} / ${amt(r.required_minutes, unit)}`
    ).join(", ");
    text(
      c,
      `Stage: ${sg.label}${
        sg.window_from ? ` (from ${sg.window_from}${sg.milestone_assumed ? ", estimated" : ""})` : ""
      }: ${detail}${sg.met ? " - met" : ""}`.slice(0, 140),
      40,
      8,
    );
    c.y -= 12;
  }
  if (pr?.still_needed?.length) {
    ensure(c, 14);
    text(c, `Still needed: ${pr.still_needed.join("; ")}`.slice(0, 140), 40, 8, c.bold);
    c.y -= 12;
  }
  c.y -= 6;

  // ---- Drives table (weather column only where the state counts weather)
  const sig = new Map(opts.signoffs.map((x) => [x.drive_id, x]));
  const cols = hasWeather ? [40, 100, 162, 207, 247, 292, 332, 432, 505] : [40, 105, 175, 225, 265, 305, 420, 500];
  const head = hasWeather
    ? [
      "Date",
      "Time",
      unit === "minutes" ? "Min" : "Minutes",
      "Night",
      "Weather",
      "Miles",
      "Supervisor",
      "Signed",
      "Status",
    ]
    : ["Date", "Time", "Minutes", "Night", "Miles", "Supervisor", "Signed", "Status"];
  const drawHead = () => {
    head.forEach((h, i) => text(c, h, cols[i], 8, c.bold, GREY));
    c.y -= 4;
    c.page.drawLine({ start: { x: 40, y: c.y }, end: { x: 572, y: c.y }, thickness: 0.5, color: GREY });
    c.y -= 11;
  };
  ensure(c, 40);
  text(c, "Drives", 40, 12, c.bold);
  c.y -= 16;
  drawHead();
  for (const d of [...opts.drives].sort((a, b) => a.started_at.localeCompare(b.started_at))) {
    if (c.y < 60) {
      newPage(c);
      drawHead();
    }
    const sg = sig.get(d.id);
    const row = [
      d.local_date,
      `${localTime(d.started_at, d.tz)}`,
      String(d.duration_minutes),
      String(d.night_minutes),
      ...(hasWeather ? [String(d.weather_minutes ?? 0)] : []),
      Number(d.distance_miles).toFixed(1),
      (d.supervisor_name ?? "").slice(0, 20) + (d.kind === "lesson" ? " (lesson)" : ""),
      sg
        ? `${sg.initials ?? ""} ${
          sg.method === "family_account" ? "app" : sg.method === "on_device" ? "phone" : "school"
        }`
        : "",
      d.status,
    ];
    row.forEach((v, i) =>
      text(c, v, cols[i], 8, c.font, d.status === "voided" || d.status === "rejected" ? GREY : NAVY)
    );
    c.y -= 12;
  }

  // ---- Credited by day (what a state form needs)
  c.y -= 10;
  ensure(c, 60);
  text(c, "Credited by day (signed practice drives)", 40, 12, c.bold);
  c.y -= 16;
  const dcols = [40, 130, 220, 310, 400];
  const fmt = (m: number) => unit === "minutes" ? `${m} min` : hm(m);
  ["Date", "Driven", "Counts", "Night counts", ...(hasWeather ? ["Weather counts"] : [])].forEach((h, i) =>
    text(c, h, dcols[i], 8, c.bold, GREY)
  );
  c.y -= 12;
  for (const d of opts.days) {
    if (c.y < 60) newPage(c);
    [
      d.local_date,
      fmt(d.raw_minutes),
      fmt(d.credited_minutes) + (d.capped ? " (cap)" : ""),
      fmt(d.night_credited_minutes),
      ...(hasWeather ? [fmt(d.weather_credited_minutes ?? 0)] : []),
    ].forEach((v, i) => text(c, v, dcols[i], 8));
    c.y -= 12;
  }

  // ---- Signatures (+ notary block where the state requires one)
  const notary = res?.form.notarization ?? "not_stated";
  ensure(c, notary === "not_stated" ? 110 : 250);
  c.y -= 24;
  text(c, "Parent / guardian certification", 40, 10, c.bold);
  c.y -= 13;
  text(
    c,
    `I certify that ${st.first_name} ${st.last_name} completed the supervised driving recorded above` +
      `${reqs[0]?.credited_minutes ? ` (${amt(reqs[0].credited_minutes, unit)} credited)` : ""}.`,
    40,
    8,
  );
  c.y -= 11;
  if (pr?.supervisor?.rule) {
    text(c, `Supervisor rule (${place}): ${pr.supervisor.rule}`.slice(0, 140), 40, 7, c.font, GREY);
    c.y -= 10;
  }
  const sigLine = (labels: [string, number, number][]) => {
    c.y -= 22;
    for (const [, x, w] of labels) {
      c.page.drawLine({ start: { x, y: c.y }, end: { x: x + w, y: c.y }, thickness: 0.5, color: NAVY });
    }
    c.y -= 10;
    for (const [l, x] of labels) text(c, l, x, 7, c.font, GREY);
  };
  sigLine([["Parent / guardian signature", 40, 220], ["Printed name", 280, 150], ["Date", 450, 110]]);
  sigLine([["Supervising driver signature (if different)", 40, 220], ["Driver license no.", 280, 150], [
    "Date",
    450,
    110,
  ]]);
  if (notary !== "not_stated") {
    c.y -= 22;
    text(
      c,
      notary === "required"
        ? "Notary acknowledgment (required by the state)"
        : "Notary acknowledgment (only if the parent / guardian cannot be present)",
      40,
      10,
      c.bold,
    );
    c.y -= 12;
    if (res?.form.notarization_note) {
      text(c, `State note: ${res.form.notarization_note}`, 40, 8, c.font, GREY);
      c.y -= 12;
    }
    text(c, "State of ______________________   County of ______________________", 40, 8);
    c.y -= 12;
    text(c, "Subscribed and sworn to (or affirmed) before me on this date: ____________________", 40, 8);
    c.y -= 8;
    sigLine([["Notary public signature", 40, 220], ["Commission expires", 280, 150]]);
    c.page.drawRectangle({ x: 460, y: c.y - 6, width: 100, height: 70, borderColor: GREY, borderWidth: 0.5 });
    text(c, "Seal", 500, 7, c.font, GREY);
    c.y -= 16;
  }
  if (res?.form.name) {
    ensure(c, 20);
    c.y -= 14;
    text(
      c,
      `Reference: ${res.form.name}${res.form.number ? ` (${res.form.number})` : ""}. Official requirements checked ${
        res.last_checked ?? "-"
      }.`.slice(0, 150),
      40,
      7,
      c.font,
      GREY,
    );
  }
  return await doc.save();
}

export async function renderDrivePdf(
  opts: { student: Student; drive: Drive; signoff: Signoff | null; generatedAt: string; exportId: string },
): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  const c: Ctx = {
    doc,
    page: undefined as unknown as PDFPage,
    font: await doc.embedFont(StandardFonts.Helvetica),
    bold: await doc.embedFont(StandardFonts.HelveticaBold),
    y: 0,
    pageNo: 0,
    footer: `LicenseLogger export ${opts.exportId} · generated ${opts.generatedAt}`,
  };
  newPage(c);
  const d = opts.drive, s = opts.signoff;
  text(c, `Drive on ${d.local_date}`, 40, 18, c.bold);
  c.y -= 20;
  text(c, `${opts.student.first_name} ${opts.student.last_name}  ·  ${opts.student.school_name}`, 40, 10);
  c.y -= 24;
  const lines: [string, string][] = [
    ["Time", `${localTime(d.started_at, d.tz)} - ${localTime(d.ended_at, d.tz)} (${hm(d.duration_minutes)})`],
    ["Night", hm(d.night_minutes)],
    ["Bad weather", hm(d.weather_minutes ?? 0)],
    ["Miles", Number(d.distance_miles).toFixed(1)],
    ["From / to", `${d.start_label} -> ${d.end_label}`],
    ["Supervisor", d.supervisor_name ?? ""],
    ["Source", d.source],
    ["Status", d.status],
    ["Conditions", d.conditions.join(", ")],
    ["Skills", d.skills.join(", ")],
    ["Notes", d.notes.slice(0, 300)],
  ];
  for (const [k, v] of lines) {
    text(c, k, 40, 9, c.bold, GREY);
    text(c, v, 130, 9);
    c.y -= 14;
  }

  if (d.route_polyline) {
    const pts = decodePolyline(d.route_polyline);
    if (pts.length > 1) {
      c.y -= 10;
      const box = { x: 40, y: c.y - 260, w: 532, h: 250 };
      c.page.drawRectangle({ x: box.x, y: box.y, width: box.w, height: box.h, color: rgb(0.96, 0.97, 0.98) });
      const lats = pts.map((p) => p[0]), lngs = pts.map((p) => p[1]);
      const [minLat, maxLat, minLng, maxLng] = [
        Math.min(...lats),
        Math.max(...lats),
        Math.min(...lngs),
        Math.max(...lngs),
      ];
      const sx = box.w / Math.max(maxLng - minLng, 1e-6),
        sy = box.h / Math.max(maxLat - minLat, 1e-6),
        sc = Math.min(sx, sy) * 0.9;
      const px = (p: [number, number]) => ({
        x: box.x + box.w / 2 + (p[1] - (minLng + maxLng) / 2) * sc,
        y: box.y + box.h / 2 + (p[0] - (minLat + maxLat) / 2) * sc,
      });
      for (let i = 1; i < pts.length; i++) {
        c.page.drawLine({ start: px(pts[i - 1]), end: px(pts[i]), thickness: 2, color: rgb(0.07, 0.34, 0.76) });
      }
      c.y = box.y - 16;
      text(c, "Route shape (not to map scale)", 40, 7, c.font, GREY);
      c.y -= 18;
    }
  }

  text(c, "Sign-off", 40, 12, c.bold);
  c.y -= 16;
  if (s) {
    text(
      c,
      `${s.supervisor_name}${s.initials ? ` (initials ${s.initials})` : ""} · ${
        s.method.replace("_", " ")
      } · ${s.signed_at}`,
      40,
      9,
    );
    c.y -= 14;
    text(c, `Record fingerprint (SHA-256): ${s.snapshot_sha256}`, 40, 7, c.font, GREY);
    c.y -= 12;
    text(c, "Time, route and miles are locked once signed.", 40, 7, c.font, GREY);
  } else {
    text(c, "Not signed yet.", 40, 9, c.font, AMBER);
  }
  return await doc.save();
}

// ---------------------------------------------------------------- state-matched log (docs/log_layouts)
export const LOG_LAYOUTS = layoutsJson as unknown as Layouts;

/** Condition tags that name the weather / the road surface (same lists as the app's log_layouts.dart). */
export const WEATHER_TAGS = [
  "rain",
  "light rain",
  "heavy rain",
  "snow",
  "sleet",
  "ice",
  "fog",
  "hail",
  "clear",
  "sunny",
  "cloudy",
  "overcast",
  "windy",
];
export const ROADWAY_TAGS = ["dry", "wet", "icy", "snowy", "slush"];

function hhmm(iso: string | null, tz = "America/Chicago"): string {
  if (!iso) return "00:00";
  const p = new Intl.DateTimeFormat("en-GB", { timeZone: tz, hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    .formatToParts(new Date(iso));
  return `${p.find((x) => x.type === "hour")!.value}:${p.find((x) => x.type === "minute")!.value}`;
}

/** Export data -> the builder's input. Only signed practice drives are listed; totals are the credited (state-math) totals. */
export function stateLogInput(
  o: {
    student: Student & { birthday?: string | null };
    summary: Summary;
    drives: Drive[];
    signoffs: Signoff[];
    progress?: Progress | null;
  },
): LogInput {
  const sig = new Map(o.signoffs.map((s) => [s.drive_id, s]));
  const signed = o.drives.filter((d) => d.kind === "practice" && d.status === "signed");
  const pending = o.drives.filter((d) => d.kind === "practice" && d.status === "pending");
  const tag = (d: Drive, list: string[]) => d.conditions.find((c) => list.includes(c.toLowerCase())) ?? "";
  const count = new Map<string, number>();
  for (const d of signed) if (d.supervisor_name) count.set(d.supervisor_name, (count.get(d.supervisor_name) ?? 0) + 1);
  const main = [...count.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0]?.[0] ?? "";
  const reqW = o.progress?.requirements?.find((r) => r.key === "weather" || r.key === "challenging");
  const s = o.summary;
  return {
    state_code: o.student.state_code,
    student: {
      first: o.student.first_name,
      last: o.student.last_name,
      permit_number: "",
      birthday: o.student.birthday ?? "",
      permit_issued: o.student.permit_on ?? "",
      school: o.student.school_name === INDEPENDENT_LABEL ? "" : o.student.school_name,
    },
    main_supervisor: main,
    drives: signed.map((d) => {
      const so = sig.get(d.id);
      const who = so?.supervisor_name ?? d.supervisor_name ?? "";
      return {
        date: d.local_date,
        start: hhmm(d.started_at, d.tz),
        end: hhmm(d.ended_at, d.tz),
        minutes: d.duration_minutes,
        night_minutes: d.night_minutes,
        weather_minutes: d.weather_minutes ?? 0,
        weather: tag(d, WEATHER_TAGS),
        roadway: tag(d, ROADWAY_TAGS),
        supervisor: d.supervisor_name ?? who,
        initials: so?.initials ?? who.split(/\s+/).filter((w) => w).map((w) => w[0].toUpperCase()).slice(0, 3).join(""),
        skills: d.skills,
        conditions: d.conditions,
        location: d.start_label === d.end_label ? d.start_label : `${d.start_label} to ${d.end_label}`,
        notes: d.notes,
      };
    }),
    totals: {
      total: s.credited_minutes,
      day: s.day_credited_minutes,
      night: s.night_credited_minutes,
      weather: reqW ? reqW.credited_minutes : signed.reduce((a, d) => a + (d.weather_minutes ?? 0), 0),
    },
    excluded: {
      unsigned_drives: pending.length,
      unsigned_minutes: pending.reduce((a, d) => a + d.duration_minutes, 0),
      lessons: o.drives.filter((d) => d.kind === "lesson").length,
    },
  };
}

/** The state-matched log PDF (official layout where we have one; generic layout otherwise). */
export async function renderStateLog(
  o: Parameters<typeof stateLogInput>[0] & { generatedAt: string; exportId: string; layouts?: Layouts },
): Promise<{ bytes: Uint8Array; doc: LogDocument }> {
  const doc = buildLogDocument(o.layouts ?? LOG_LAYOUTS, stateLogInput(o));
  return { bytes: await renderStateLogPdf(doc, { generatedAt: o.generatedAt, exportId: o.exportId }), doc };
}
