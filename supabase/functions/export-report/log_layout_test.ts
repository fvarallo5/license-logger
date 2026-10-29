import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { PDFDocument } from "npm:pdf-lib@1.17.1";
import { buildLogDocument, fmtAmount, fmtHours, type LogInput, renderStateLogPdf, time12 } from "./log_layout.ts";
import { type Drive, LOG_LAYOUTS, renderStateLog, stateLogInput } from "./render.ts";

const root = new URL("../../../", import.meta.url).pathname;
const fixture = JSON.parse(await Deno.readTextFile(`${root}docs/log_layouts/fixtures/input.json`)) as LogInput & {
  _doc?: string;
};
delete fixture._doc;
const input = (st: string, over: Partial<LogInput> = {}): LogInput => ({
  ...structuredClone(fixture),
  state_code: st,
  ...over,
});
const layouts = LOG_LAYOUTS;

Deno.test("bundled log_layouts.json is byte-identical to docs/log_layouts/layouts.json (no drift)", async () => {
  const a = await Deno.readTextFile(`${root}docs/log_layouts/layouts.json`);
  const b = await Deno.readTextFile(new URL("./log_layouts.json", import.meta.url));
  assertEquals(a, b);
  assertEquals(Object.keys(layouts.states).length, 39);
});

Deno.test("builder matches every shared fixture (the Dart builder checks the same files)", async () => {
  let n = 0;
  for await (const e of Deno.readDir(`${root}docs/log_layouts/fixtures/expected`)) {
    const st = e.name.slice(0, 2);
    const want = JSON.parse(await Deno.readTextFile(`${root}docs/log_layouts/fixtures/expected/${e.name}`));
    assertEquals(buildLogDocument(layouts, input(st, { state_name: st === "ZZ" ? "Nowhere" : undefined })), want, st);
    n++;
  }
  assertEquals(n, 52);
});

Deno.test("formatting rules", () => {
  assertEquals(fmtAmount(90, "hr_min"), "1 hr 30 min");
  assertEquals(fmtAmount(60, "hr_min"), "1 hr");
  assertEquals(fmtAmount(45, "hr_min"), "45 min");
  assertEquals(fmtAmount(3000, "minutes"), "3000");
  assertEquals(fmtAmount(70, "hm"), "1:10");
  assertEquals(fmtHours(70), "1.17");
  assertEquals(fmtHours(90), "1.5");
  assertEquals(fmtHours(120), "2");
  assertEquals(time12(0), "12:00 AM");
  assertEquals(time12(19 * 60 + 10), "7:10 PM");
});

Deno.test("CA: official columns in order, skills abbreviated from the form legend, 10 rows then 21", () => {
  const many = Array.from(
    { length: 25 },
    (_, i) => ({ ...fixture.drives[1], date: `2026-08-${String(i + 1).padStart(2, "0")}` }),
  );
  const d = buildLogDocument(layouts, input("CA", { drives: many }));
  const t1 = d.pages[0].blocks.find((b) => b.type === "table")!;
  assert(t1.type === "table");
  assertEquals(t1.table.panels[0].columns.map((c) => c.label), [
    "Date",
    "Driving Skills Practiced",
    "DAY",
    "NIGHT",
    "Skills needing more practice (use abbrev.)",
    "Adult\u2019s Initials",
  ]);
  assertEquals(t1.table.row_count, 10);
  assertEquals(t1.table.panels[0].rows[0], ["8/1/26", "FD, LC, KSAC", "1 hr 10 min", "35 min", "", "CL"]);
  assertEquals(t1.table.total!.label, "TOTAL PRACTICE TIME");
  assertEquals(d.pages.length, 2);
  assertEquals((d.pages[1].blocks[0] as { table: { row_count: number } }).table.row_count, 21);
  assertEquals(d.disclaimer_mode, "check");
  assertStringIncludes(d.disclaimer, "check your state accepts this copy");
});

Deno.test("NV: day and night parts go to Column A / Column B; transfer wording; certification first", () => {
  const d = buildLogDocument(layouts, input("NV"));
  assertEquals(d.disclaimer_mode, "transfer");
  assertStringIncludes(d.disclaimer, "Filled copy to transfer/print onto the official Nevada DLD130");
  assert(d.pages[0].blocks.some((b) => b.type === "signatures"));
  const t = d.pages[1].blocks[0];
  assert(t.type === "table");
  const [a, b] = t.table.panels;
  // 17:40-19:25 with 35 night minutes: 5:40-6:50 PM day + 6:50-7:25 PM night; 06:15 drive: dark first.
  assert(a.rows.some((r) => r.join("|") === "10/12/26|5:40 PM|6:50 PM|70"));
  assert(b.rows.some((r) => r.join("|") === "10/12/26|6:50 PM|7:25 PM|35"));
  assert(b.rows.some((r) => r.join("|") === "10/12/26|6:15 AM|6:35 AM|20"));
  assertEquals(t.table.total!.cells, [["", "", "", "235"], ["", "", "", "115"]]);
});

Deno.test("OH: hours/minutes split columns, notary on the affidavit page", () => {
  const d = buildLogDocument(layouts, input("OH"));
  assert(d.pages[0].blocks.some((b) => b.type === "notary"));
  const t = d.pages[1].blocks[0];
  assert(t.type === "table");
  const row = t.table.panels[0].rows.find((r) => r[0] === "10/12/26" && r[3] === "5:40 PM")!;
  assertEquals(row.slice(5), ["1", "10", "0", "35"]);
  assertEquals(row[2], ""); // Ohio DL # of the supervisor is never invented
});

Deno.test("MI accepted with a quoted source; FL / NY / NJ certification-only with a supporting record", () => {
  const mi = buildLogDocument(layouts, input("MI"));
  assertEquals(mi.disclaimer_mode, "accepted");
  assertStringIncludes(mi.disclaimer, "Other driving log formats will be accepted.");
  for (const st of ["FL", "NY", "NJ"]) {
    const d = buildLogDocument(layouts, input(st));
    assertEquals(d.kind, "certification");
    assert(d.pages.length >= 2);
    assertStringIncludes(JSON.stringify(d.pages[1]), "not part of the official form");
  }
  const fl = buildLogDocument(layouts, input("FL"));
  assertStringIncludes(
    JSON.stringify(fl.pages[0]),
    "I do hereby certify that Maya Lopez, a minor, date of birth 3/9/10",
  );
  assert(fl.pages[0].blocks.some((b) => b.type === "notary"));
});

Deno.test("generic states say why (blocked / no form / accepted any document)", () => {
  assertStringIncludes(buildLogDocument(layouts, input("IL")).disclaimer, "could not be downloaded");
  assertEquals(buildLogDocument(layouts, input("NM")).disclaimer_mode, "generic_accepted");
  assertEquals(buildLogDocument(layouts, input("GA")).disclaimer_mode, "generic_no_form");
  assertEquals(buildLogDocument(layouts, input("HI")).disclaimer_mode, "generic_unconfirmed");
});

Deno.test("PDFs render at the official page size for several layouts", async () => {
  const want: Record<string, [number, number]> = {
    CA: [378, 603],
    OH: [612, 792],
    MI: [576, 756],
    NV: [612, 792],
    FL: [612, 792],
    NY: [612, 792],
    ME: [792, 612],
    MD: [396, 612],
    UT: [612, 1008],
    KY: [612, 792],
    AZ: [612, 792],
    NM: [612, 792],
  };
  for (const [st, [w, h]] of Object.entries(want)) {
    const doc = buildLogDocument(layouts, input(st));
    const bytes = await renderStateLogPdf(doc, { generatedAt: "now", exportId: "t" });
    assertEquals(new TextDecoder().decode(bytes.slice(0, 5)), "%PDF-");
    const pdf = await PDFDocument.load(bytes);
    const { width, height } = pdf.getPage(0).getSize();
    assertEquals([Math.round(width), Math.round(height)], [w, h], st);
    assert(pdf.getPageCount() >= doc.pages.length, st);
  }
});

Deno.test("export adapter: only signed practice drives, local times, initials from the sign-off", async () => {
  const base: Drive = {
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
    distance_miles: 20,
    supervisor_name: "Ana Lopez",
    start_label: "Home",
    end_label: "Home",
    conditions: ["Rain", "Wet"],
    skills: ["Night driving"],
    notes: "",
    weather_minutes: 60,
  };
  const drives: Drive[] = [base, { ...base, id: "d2", status: "pending" }, { ...base, id: "d3", kind: "lesson" }];
  const summary = {
    rule_label: null,
    rule_verified: true,
    form_code: null,
    state_code: "CA",
    required_minutes: 3000,
    required_night_minutes: 600,
    daily_cap_minutes: null,
    credited_minutes: 60,
    night_credited_minutes: 60,
    day_credited_minutes: 0,
    pending_extra_minutes: 60,
    pending_drives: 1,
    signed_miles: 20,
    lesson_minutes: 60,
    school_goal_minutes: null,
    requirement_met: false,
  };
  const student = {
    first_name: "Maya",
    last_name: "Lopez",
    state_code: "CA",
    permit_on: "2026-04-14",
    school_name: "x",
    school_phone: "",
    birthday: null,
  };
  const signoffs = [{
    drive_id: "d1",
    method: "on_device",
    supervisor_name: "Ana Lopez",
    initials: "AJL",
    signed_at: "",
    snapshot_sha256: "",
  }];
  const inp = stateLogInput({ student, summary, drives, signoffs });
  assertEquals(inp.drives.length, 1);
  assertEquals([
    inp.drives[0].start,
    inp.drives[0].end,
    inp.drives[0].initials,
    inp.drives[0].weather,
    inp.drives[0].roadway,
  ], ["19:10", "20:10", "AJL", "Rain", "Wet"]);
  assertEquals(inp.excluded, { unsigned_drives: 1, unsigned_minutes: 60, lessons: 1 });
  const { bytes, doc } = await renderStateLog({
    student,
    summary,
    drives,
    signoffs,
    generatedAt: "now",
    exportId: "t",
  });
  assertEquals(doc.state_code, "CA");
  assert(bytes.byteLength > 1500);
});
