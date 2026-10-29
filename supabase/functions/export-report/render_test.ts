import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  cell,
  decodePolyline,
  type Drive,
  INDEPENDENT_LABEL,
  renderCsv,
  renderDrivePdf,
  renderHoursPdf,
} from "./render.ts";

const drive = (over: Partial<Drive> = {}): Drive => ({
  id: "d1",
  kind: "practice",
  source: "gps",
  status: "signed",
  started_at: "2026-10-18T00:10:00Z",
  ended_at: "2026-10-18T01:10:00Z",
  tz: "America/Chicago",
  local_date: "2026-10-17",
  duration_minutes: 60,
  night_minutes: 60,
  distance_miles: 25.2,
  supervisor_name: "Ana Lopez",
  start_label: "Home · Mueller",
  end_label: "Home · Mueller",
  conditions: ["Dry", "Night"],
  skills: ["Night driving"],
  notes: 'Short run, "290"',
  route_polyline: "_p~iF~ps|U_ulLnnqC_mqNvxq`@",
  ...over,
});

Deno.test("CSV cells are quoted and formula-safe", () => {
  assertEquals(cell("a,b"), '"a,b"');
  assertEquals(cell('=HYPERLINK("x")'), `"'=HYPERLINK(""x"")"`);
  assertEquals(cell(["Dry", "Night"]), "Dry; Night");
  assertEquals(cell(null), "");
});

Deno.test("CSV has header, local times and day credit", () => {
  const csv = renderCsv([drive()], [{
    drive_id: "d1",
    method: "on_device",
    supervisor_name: "Ana Lopez",
    initials: "AL",
    signed_at: "2026-10-18T01:15:00Z",
    snapshot_sha256: "ab",
  }], [{ local_date: "2026-10-17", raw_minutes: 60, credited_minutes: 60, night_credited_minutes: 60, capped: false }]);
  const lines = csv.trim().split("\r\n");
  assertEquals(lines.length, 2);
  assertStringIncludes(lines[0], "drive_id,date,start,end");
  assertStringIncludes(lines[1], "7:10 PM"); // 00:10 UTC = 7:10 PM in Chicago (CDT)
  assertStringIncludes(lines[1], ",60,AL".slice(0, 3));
  assertStringIncludes(lines[1], '"Short run, ""290"""');
});

Deno.test("polyline decodes (Google reference example)", () => {
  const pts = decodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@");
  assertEquals(pts.length, 3);
  assertEquals(pts[0], [38.5, -120.2]);
  assertEquals(pts[2], [43.252, -126.453]);
});

Deno.test("hours PDF renders (unverified banner path, many rows, non-Latin text)", async () => {
  const drives = Array.from(
    { length: 120 },
    (_, i) => drive({ id: `d${i}`, notes: "emoji 🚗 ok", supervisor_name: "Zoë 李" }),
  );
  const pdf = await renderHoursPdf({
    student: {
      first_name: "Maya",
      last_name: "Lopez",
      state_code: "MI",
      permit_on: null,
      school_name: "Green Light",
      school_phone: "",
    },
    summary: {
      rule_label: "Michigan (example)",
      rule_verified: false,
      form_code: null,
      state_code: "MI",
      required_minutes: 3000,
      required_night_minutes: 600,
      daily_cap_minutes: null,
      credited_minutes: 564,
      night_credited_minutes: 120,
      day_credited_minutes: 444,
      pending_extra_minutes: 180,
      pending_drives: 2,
      signed_miles: 220.5,
      lesson_minutes: 120,
      school_goal_minutes: 3000,
      requirement_met: false,
    },
    days: [{
      local_date: "2026-10-17",
      raw_minutes: 150,
      credited_minutes: 120,
      night_credited_minutes: 0,
      capped: true,
    }],
    drives,
    signoffs: [],
    generatedAt: "2026-10-22 18:00 UTC",
    exportId: "test",
  });
  assert(pdf.byteLength > 2000);
  assertEquals(new TextDecoder().decode(pdf.slice(0, 5)), "%PDF-");
});

Deno.test("single drive PDF renders with route", async () => {
  const pdf = await renderDrivePdf({
    student: {
      first_name: "Maya",
      last_name: "Lopez",
      state_code: "TX",
      permit_on: null,
      school_name: "Green Light",
      school_phone: "",
    },
    drive: drive(),
    signoff: null,
    generatedAt: "now",
    exportId: "t",
  });
  assertEquals(new TextDecoder().decode(pdf.slice(0, 5)), "%PDF-");
});

Deno.test("independent student (no school) hours PDF renders", async () => {
  const pdf = await renderHoursPdf({
    student: {
      first_name: "Riley",
      last_name: "Nguyen",
      state_code: "TX",
      permit_on: null,
      school_name: INDEPENDENT_LABEL,
      school_phone: "",
    },
    summary: {
      rule_label: "Texas (TDLR)",
      rule_verified: true,
      form_code: "DES150N",
      state_code: "TX",
      required_minutes: 1800,
      required_night_minutes: 600,
      daily_cap_minutes: 120,
      credited_minutes: 150,
      night_credited_minutes: 30,
      day_credited_minutes: 120,
      pending_extra_minutes: 0,
      pending_drives: 0,
      signed_miles: 40,
      lesson_minutes: 0,
      school_goal_minutes: null,
      requirement_met: false,
    },
    days: [],
    drives: [drive()],
    signoffs: [],
    generatedAt: "2026-10-22 18:00 UTC",
    exportId: "indep",
  });
  assertEquals(new TextDecoder().decode(pdf.slice(0, 5)), "%PDF-");
});

// ---- State-matched layout (state rules v2) ----
import { amt, paperworkLines, type Progress, type Resources } from "./render.ts";

/** Pull the visible text out of a pdf-lib PDF: inflate each content stream, then decode <hex> Tj strings. */
async function pdfText(pdfP: Uint8Array | Promise<Uint8Array>): Promise<string> {
  const pdf = await pdfP, raw = new TextDecoder("latin1").decode(pdf), out: string[] = [];
  for (const m of raw.matchAll(/stream\r?\n/g)) {
    const start = m.index! + m[0].length;
    let end = raw.indexOf("endstream", start);
    while (end > start && (raw[end - 1] === "\n" || raw[end - 1] === "\r")) end--;
    let body = raw.slice(start, end);
    try {
      const bytes = pdf.slice(start, end);
      const ds = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate"));
      body = new TextDecoder("latin1").decode(new Uint8Array(await new Response(ds).arrayBuffer()));
    } catch { /* not compressed */ }
    for (const t of body.matchAll(/<([0-9A-Fa-f]+)>\s*Tj/g)) {
      out.push(t[1].match(/../g)!.map((h) => String.fromCharCode(parseInt(h, 16))).join(""));
    }
  }
  return out.join("\n");
}
const baseSummary = {
  rule_label: "x",
  rule_verified: true,
  form_code: null,
  state_code: "AZ",
  required_minutes: 1800,
  required_night_minutes: 600,
  daily_cap_minutes: null,
  credited_minutes: 60,
  night_credited_minutes: 0,
  day_credited_minutes: 60,
  pending_extra_minutes: 0,
  pending_drives: 0,
  signed_miles: 10,
  lesson_minutes: 0,
  school_goal_minutes: null,
  requirement_met: false,
};
const req = (key: string, label: string, required: number, credited: number) => ({
  key,
  label,
  required_minutes: required,
  credited_minutes: credited,
  pending_minutes: 0,
  remaining_minutes: Math.max(required - credited, 0),
  met: credited >= required,
});
const prog = (over: Partial<Progress> = {}): Progress => ({
  rule: {
    state_code: "AZ",
    jurisdiction_name: "Arizona",
    version: 1,
    label: "Arizona: Driving Practice Certificate",
    status: "verified",
    requirement_kind: "certification",
    log_unit: "hours",
    permit_on: "2026-05-01",
    selected_by: "permit_date",
  },
  alternative: null,
  caps: { daily_minutes: null, weekly_minutes: null, capped_days: 0, capped_weeks: 0 },
  requirements: [req("total", "Total supervised driving", 1800, 60), req("night", "At night", 600, 0)],
  stages: [],
  all_met: false,
  still_needed: ["29 h more in total", "10 h more at night"],
  supervisor: { min_age: null, min_years_licensed: null, parent_exempt: false, rule: "", unverified_drives: 0 },
  ...over,
});
const resources = (over: Partial<Resources["form"]> = {}, how = "records_only"): Resources => ({
  form: {
    type: "certification",
    name: "Driving Practice Certificate",
    number: "96-0223",
    pdf_url: "https://azdot.gov/x.pdf",
    notarization: "required",
    notarization_note: "notarized or witnessed by MVD agent",
    digital_log: "not_stated",
    digital_log_apps: [],
    digital_log_note: "",
    ...over,
  },
  how_to_use_licenselogger_log: how,
  last_checked: "2026-10-22",
  status: "verified",
});

Deno.test("amounts use the state's unit", () => {
  assertEquals(amt(3000, "minutes"), "3,000 min");
  assertEquals(amt(90), "1.5 h");
});

Deno.test("paperwork lines name the form and how to use the log", () => {
  const nv = paperworkLines(
    resources({
      name: "Beginning Driver Experience Log",
      number: "DLD-130",
      notarization: "not_stated",
      digital_log: "listed_apps",
      digital_log_apps: ["RoadReady"],
      digital_log_note: "ONLY the DLD-130 or RoadReady",
    }, "official_form_only"),
  );
  assertEquals(nv[0], "State form: Beginning Driver Experience Log (DLD-130)");
  assertStringIncludes(nv.join("\n"), "or RoadReady is accepted");
  assertEquals(paperworkLines(null), []);
});

Deno.test("notary state (AZ) PDF has the form reference and a notary block", async () => {
  const pdf = await renderHoursPdf({
    student: {
      first_name: "Ava",
      last_name: "Diaz",
      state_code: "AZ",
      permit_on: "2026-05-01",
      school_name: INDEPENDENT_LABEL,
      school_phone: "",
    },
    summary: baseSummary,
    days: [],
    drives: [drive()],
    signoffs: [],
    generatedAt: "now",
    exportId: "az",
    progress: prog(),
    resources: resources(),
  });
  const t = await pdfText(pdf);
  assertStringIncludes(t, "Supervised driving log - Arizona");
  assertStringIncludes(t, "State form: Driving Practice Certificate (96-0223)");
  assertStringIncludes(t, "Notary acknowledgment (required by the state)");
  assertStringIncludes(t, "Still needed: 29 h more in total");
});

Deno.test("IL-style 'notary only if parent absent' and no-notary states", async () => {
  const il = await pdfText(
    renderHoursPdf({
      student: {
        first_name: "A",
        last_name: "B",
        state_code: "IL",
        permit_on: null,
        school_name: "S",
        school_phone: "",
      },
      summary: baseSummary,
      days: [],
      drives: [],
      signoffs: [],
      generatedAt: "now",
      exportId: "il",
      progress: prog(),
      resources: resources({ notarization: "if_signer_absent", notarization_note: "if the parent is not present" }),
    }),
  );
  assertStringIncludes(il, "only if the parent / guardian cannot be present");
  const tx = await pdfText(
    renderHoursPdf({
      student: {
        first_name: "A",
        last_name: "B",
        state_code: "TX",
        permit_on: null,
        school_name: "S",
        school_phone: "",
      },
      summary: baseSummary,
      days: [],
      drives: [],
      signoffs: [],
      generatedAt: "now",
      exportId: "tx",
      progress: prog(),
      resources: resources({ notarization: "not_stated" }, "copy_to_official_form"),
    }),
  );
  assert(!tx.includes("Notary acknowledgment"));
  assertStringIncludes(tx, "Copy these entries onto the state form");
});

Deno.test("PA weather column, NV minutes, stages and unconfirmed banner", async () => {
  const pa = await pdfText(
    renderHoursPdf({
      student: {
        first_name: "P",
        last_name: "A",
        state_code: "PA",
        permit_on: null,
        school_name: "S",
        school_phone: "",
      },
      summary: baseSummary,
      days: [{
        local_date: "2026-06-01",
        raw_minutes: 200,
        credited_minutes: 200,
        night_credited_minutes: 0,
        capped: false,
        raw_weather_minutes: 100,
        weather_credited_minutes: 100,
      }],
      drives: [drive({ weather_minutes: 100 })],
      signoffs: [],
      generatedAt: "now",
      exportId: "pa",
      progress: prog({
        requirements: [
          req("total", "Total supervised driving", 3900, 200),
          req("weather", "In inclement weather", 300, 100),
        ],
      }),
      resources: resources({ notarization: "not_stated" }),
    }),
  );
  assertStringIncludes(pa, "Weather counts");
  assertStringIncludes(pa, "In inclement weather");
  const nv = await pdfText(
    renderHoursPdf({
      student: {
        first_name: "N",
        last_name: "V",
        state_code: "NV",
        permit_on: null,
        school_name: "S",
        school_phone: "",
      },
      summary: baseSummary,
      days: [],
      drives: [],
      signoffs: [],
      generatedAt: "now",
      exportId: "nv",
      progress: prog({
        rule: { ...prog().rule!, jurisdiction_name: "Nevada", log_unit: "minutes" },
        requirements: [req("total", "Total supervised driving", 3000, 47)],
      }),
      resources: resources({ notarization: "not_stated" }),
    }),
  );
  assertStringIncludes(nv, "47 min of 3,000 min");
  const ia = await pdfText(
    renderHoursPdf({
      student: {
        first_name: "I",
        last_name: "A",
        state_code: "IA",
        permit_on: null,
        school_name: "S",
        school_phone: "",
      },
      summary: baseSummary,
      days: [],
      drives: [],
      signoffs: [],
      generatedAt: "now",
      exportId: "ia",
      progress: prog({
        rule: { ...prog().rule!, status: "unconfirmed" },
        stages: [{
          key: "full",
          label: "Before the full license",
          window_from: "2026-03-11",
          milestone_assumed: true,
          met: false,
          requirements: [req("total", "Total supervised driving", 600, 300)],
        }],
      }),
      resources: null,
    }),
  );
  assertStringIncludes(ia, "Stage: Before the full license (from 2026-03-11, estimated)");
  assertStringIncludes(ia, "UNCONFIRMED");
});
