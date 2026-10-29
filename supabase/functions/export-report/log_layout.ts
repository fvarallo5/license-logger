// State-matched log layouts: ONE spec (docs/log_layouts/<ST>.json -> log_layouts.json) drives this
// renderer and the app's "Generate my filled log" preview (lib/data/log_layouts.dart).
//
//   buildLogDocument(layouts, input)  pure: spec + drives -> LogDocument (pages of blocks with cell text)
//   renderStateLogPdf(doc, meta)      pdf-lib drawing of a LogDocument at the official page size
//
// The Dart port must produce the same LogDocument for the same input; both sides are checked against
// docs/log_layouts/fixtures/expected/<ST>.json (see render_test.ts and the app's test/log_layouts_test.dart).
// Fill rules are documented in docs/log_layouts/README.md.
import { PDFDocument, type PDFFont, type PDFPage, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";

// ---------------------------------------------------------------- spec types (subset used here)
export type Field = { label: string; value: string };
export type Column = { label: string; key: string; w: number; group?: string };
export type Panel = { filter: "all" | "day" | "night" | "none"; title?: string; columns: Column[] };
export type TableSpec = {
  panels: Panel[];
  rows: number;
  rows_first: number;
  title?: string;
  page_total?: { label: string; sum: string[] };
  example_row?: string;
};
export type Certification = {
  title: string;
  text: string;
  fields: Field[];
  totals: Field[];
  signatures: Field[];
  notary: null | { title: string; text: string; lines: string[] };
  extra_text?: string;
};
export type Acceptance = { mode: "check" | "accepted" | "transfer"; basis: string; source: string };
export type LayoutSpec = {
  state_code: string;
  state_name: string;
  kind: "full_log" | "certification" | "generic";
  form: { name: string; number: string; revision: string; source_pdf: string; source_pages: number[]; url: string };
  page: { size: [number, number]; orientation: string };
  title: string;
  subtitle?: string;
  header_fields: Field[];
  amount_format: "hr_min" | "hours" | "minutes" | "hm";
  date_format: "m/d/yy" | "mm/dd/yyyy" | "m/d";
  tables: TableSpec[];
  summary: Field[];
  certification: Certification | null;
  cert_position: "before_log" | "after_log";
  legend: string | null;
  abbrev: Record<string, string>;
  unfillable: string[];
  notes: string[];
  acceptance: Acceptance;
};
export type GenericState = {
  state_name: string;
  reason: "blocked" | "no_form" | "unconfirmed";
  form: string;
  detail: string;
  acceptance?: Acceptance;
};
export type Layouts = {
  schema: string;
  sha256: string;
  states: Record<string, LayoutSpec>;
  generic: LayoutSpec;
  generic_states: Record<string, GenericState>;
};

// ---------------------------------------------------------------- input / output
export type LogDriveInput = {
  date: string;
  start: string;
  end: string; // local YYYY-MM-DD, HH:MM, HH:MM
  minutes: number;
  night_minutes: number;
  weather_minutes: number;
  weather: string;
  roadway: string;
  supervisor: string;
  initials: string;
  skills: string[];
  conditions: string[];
  location: string;
  notes: string;
};
export type LogInput = {
  state_code: string;
  state_name?: string;
  student: {
    first: string;
    last: string;
    permit_number: string;
    birthday: string;
    permit_issued: string;
    school: string;
  };
  main_supervisor: string;
  drives: LogDriveInput[]; // signed practice drives only
  totals: { total: number; day: number; night: number; weather: number }; // credited minutes (state math)
  excluded: { unsigned_drives: number; unsigned_minutes: number; lessons: number };
};
export type Item = { label: string; value: string };
export type LogTable = {
  title: string;
  row_count: number;
  panels: { title: string; columns: { label: string; group: string; w: number; key: string }[]; rows: string[][] }[];
  total: null | { label: string; cells: string[][] };
};
export type LogBlock =
  | { type: "fields"; items: Item[] }
  | { type: "table"; table: LogTable }
  | { type: "totals"; items: Item[] }
  | { type: "text"; style: "heading" | "cert" | "legend" | "note"; text: string }
  | { type: "signatures"; items: Item[] }
  | { type: "notary"; title: string; text: string; lines: string[] }
  | { type: "computed"; title: string; items: Item[] };
export type LogDocument = {
  schema: "licenselogger.log_document/v1";
  state_code: string;
  state_name: string;
  kind: string;
  title: string;
  subtitle: string;
  form_label: string;
  source_pdf: string;
  page: { width: number; height: number };
  disclaimer: string;
  disclaimer_mode: string;
  footer: string;
  notes: string[];
  unfillable: string[];
  pages: { label: string; blocks: LogBlock[] }[];
};

// ---------------------------------------------------------------- formatting (mirrored in Dart)
const pad2 = (n: number) => (n < 10 ? "0" : "") + n;
export function fmtAmount(m: number, f: LayoutSpec["amount_format"]): string {
  m = Math.max(0, Math.round(m));
  const h = Math.floor(m / 60), r = m % 60;
  switch (f) {
    case "minutes":
      return String(m);
    case "hm":
      return `${h}:${pad2(r)}`;
    case "hours":
      return fmtHours(m);
    default:
      return h > 0 && r > 0 ? `${h} hr ${r} min` : h > 0 ? `${h} hr` : `${r} min`;
  }
}
export function fmtHours(m: number): string {
  const hh = Math.round((Math.max(0, Math.round(m)) * 100) / 60);
  const i = Math.floor(hh / 100), f = hh % 100;
  return f === 0 ? String(i) : f % 10 === 0 ? `${i}.${f / 10}` : `${i}.${pad2(f)}`;
}
export function fmtDate(iso: string, f: LayoutSpec["date_format"]): string {
  if (!iso) return "";
  const [y, mo, d] = iso.split("-").map((x) => parseInt(x, 10));
  if (f === "mm/dd/yyyy") return `${pad2(mo)}/${pad2(d)}/${y}`;
  if (f === "m/d") return `${mo}/${d}`;
  return `${mo}/${d}/${pad2(y % 100)}`;
}
const toMin = (hhmm: string) => {
  const [h, m] = hhmm.split(":").map((x) => parseInt(x, 10));
  return h * 60 + m;
};
export function time12(min: number): string {
  min = ((min % 1440) + 1440) % 1440;
  const h = Math.floor(min / 60), m = min % 60;
  return `${h % 12 === 0 ? 12 : h % 12}:${pad2(m)} ${h < 12 ? "AM" : "PM"}`;
}
const initialsOf = (name: string) =>
  name.split(/\s+/).filter((w) => w).map((w) => w[0].toUpperCase()).slice(0, 3).join("");

// ---------------------------------------------------------------- builder
type RowItem = {
  d: LogDriveInput;
  start: number;
  end: number;
  day: number;
  night: number;
  weather: number;
  filter: string;
};

function itemsFor(drives: LogDriveInput[], filter: string): RowItem[] {
  const out: RowItem[] = [];
  for (const d of drives) {
    const s = toMin(d.start),
      total = Math.max(0, d.minutes),
      night = Math.min(Math.max(0, d.night_minutes), total),
      day = total - night;
    if (filter === "all") {
      out.push({ d, start: s, end: s + total, day, night, weather: Math.min(d.weather_minutes, total), filter });
      continue;
    }
    if (filter === "none") continue;
    const nightFirst = s < 12 * 60; // morning drives: dark first; evening drives: daylight first
    const dayStart = nightFirst ? s + night : s, nightStart = nightFirst ? s : s + day;
    if (filter === "day" && day > 0) {
      out.push({ d, start: dayStart, end: dayStart + day, day, night: 0, weather: 0, filter });
    }
    if (filter === "night" && night > 0) {
      out.push({ d, start: nightStart, end: nightStart + night, day: 0, night, weather: 0, filter });
    }
  }
  return out;
}

function abbreviate(skills: string[], map: Record<string, string>): string {
  const lower = new Map(Object.entries(map).map(([k, v]) => [k.toLowerCase(), v]));
  const out: string[] = [];
  for (const s of skills) {
    const a = lower.get(s.toLowerCase()) ?? s;
    if (!out.includes(a)) out.push(a);
  }
  return out.join(", ");
}

export function resolveSpec(layouts: Layouts, state: string): { spec: LayoutSpec; generic: GenericState | null } {
  const s = layouts.states[state];
  if (s) return { spec: s, generic: null };
  return { spec: layouts.generic, generic: layouts.generic_states[state] ?? null };
}

export function disclaimerFor(
  spec: LayoutSpec,
  generic: GenericState | null,
  stateName: string,
  isGeneric: boolean,
): { text: string; mode: string } {
  if (isGeneric) {
    const g = generic;
    if (!g) return { text: "LicenseLogger generic layout. Check what your licensing office accepts.", mode: "generic" };
    if (g.reason === "blocked") {
      return {
        text:
          `LicenseLogger generic layout: the official ${stateName} ${g.form} could not be downloaded to copy its layout. Copy these entries onto the official form.`,
        mode: "generic_blocked",
      };
    }
    if (g.reason === "unconfirmed") {
      return {
        text:
          `LicenseLogger generic layout: ${stateName}'s requirement is unconfirmed (${g.form}). Check with the licensing office before relying on it.`,
        mode: "generic_unconfirmed",
      };
    }
    const acc = g.acceptance;
    return {
      text: `LicenseLogger generic layout: ${stateName} has no official log form${g.form ? ` (${g.form})` : ""}.` +
        (acc && acc.mode === "accepted"
          ? ` ${stateName} accepts other formats: "${acc.basis}" (${acc.source}).`
          : " Check what your licensing office accepts."),
      mode: acc && acc.mode === "accepted" ? "generic_accepted" : "generic_no_form",
    };
  }
  const form = `${stateName} ${spec.form.number ? spec.form.number + " " : ""}${spec.form.name}`;
  const a = spec.acceptance;
  if (a.mode === "accepted") {
    return {
      text:
        `Prepared with LicenseLogger from the official ${form}. ${stateName} accepts other log formats: "${a.basis}" (${a.source}).`,
      mode: "accepted",
    };
  }
  if (a.mode === "transfer") {
    return {
      text:
        `Filled copy to transfer/print onto the official ${form}. ${stateName} accepts only its own form: "${a.basis}" (${a.source}).`,
      mode: "transfer",
    };
  }
  return {
    text: `Prepared with LicenseLogger from the official ${form}; check your state accepts this copy.`,
    mode: "check",
  };
}

export function buildLogDocument(layouts: Layouts, input: LogInput): LogDocument {
  const { spec, generic } = resolveSpec(layouts, input.state_code);
  const isGeneric = !layouts.states[input.state_code];
  const stateName = isGeneric ? (generic?.state_name ?? input.state_name ?? input.state_code) : spec.state_name;
  const fmt = (m: number) => fmtAmount(m, spec.amount_format);
  const cellAmt = (m: number) => (m > 0 ? fmt(m) : "");
  const st = input.student;
  const name = `${st.first} ${st.last}`.trim();
  const t = input.totals;
  const value = (key: string): string => {
    switch (key) {
      case "student_name":
        return name;
      case "student_name_lfm":
        return st.last ? `${st.last}, ${st.first}` : st.first;
      case "student_first":
        return st.first;
      case "student_last":
        return st.last;
      case "student_initials":
        return initialsOf(name);
      case "permit_number":
        return st.permit_number;
      case "birthday":
        return fmtDate(st.birthday, spec.date_format);
      case "permit_issued":
        return fmtDate(st.permit_issued, spec.date_format);
      case "school_name":
        return st.school;
      case "supervisor_name":
        return input.main_supervisor;
      case "total":
        return fmt(t.total);
      case "day":
        return fmt(t.day);
      case "night":
        return fmt(t.night);
      case "weather":
        return fmt(t.weather);
      case "total_minutes":
        return String(t.total);
      case "day_minutes":
        return String(t.day);
      case "night_minutes":
        return String(t.night);
      case "weather_minutes":
        return String(t.weather);
      case "total_hours":
        return fmtHours(t.total);
      case "day_hours":
        return fmtHours(t.day);
      case "night_hours":
        return fmtHours(t.night);
      default:
        return "";
    }
  };
  const items = (fs: Field[]): Item[] => fs.map((f) => ({ label: f.label, value: value(f.value) }));
  const fill = (s: string) => s.replace(/\{([a-z_]+)\}/g, (_, k) => value(k) || "________");

  const drives = [...input.drives].sort((a, b) => (a.date + a.start).localeCompare(b.date + b.start));
  const cell = (key: string, it: RowItem, cum: number): string => {
    const d = it.d;
    switch (key) {
      case "date":
        return fmtDate(d.date, spec.date_format);
      case "date_time":
        return `${fmtDate(d.date, spec.date_format)} ${time12(it.start)}`;
      case "start_time":
        return time12(it.start);
      case "end_time":
        return time12(it.end);
      case "time_range":
        return `${time12(it.start)} - ${time12(it.end)}`;
      case "amount":
        return cellAmt(it.day + it.night);
      case "day_amount":
        return cellAmt(it.day);
      case "night_amount":
        return cellAmt(it.night);
      case "weather_amount":
        return cellAmt(it.weather);
      case "day_hours_part":
        return it.day > 0 ? String(Math.floor(it.day / 60)) : "";
      case "day_minutes_part":
        return it.day > 0 ? String(it.day % 60) : "";
      case "night_hours_part":
        return it.night > 0 ? String(Math.floor(it.night / 60)) : "";
      case "night_minutes_part":
        return it.night > 0 ? String(it.night % 60) : "";
      case "day_or_night":
        return it.night === 0 ? "Day" : it.day === 0 ? "Night" : "Day + Night";
      case "cumulative":
        return fmt(cum);
      case "weather":
        return d.weather;
      case "roadway":
        return d.roadway;
      case "conditions":
        return d.conditions.join(", ");
      case "conditions_skills":
        return [...d.conditions, ...d.skills].join(", ");
      case "location":
        return d.location;
      case "skills":
        return d.skills.join(", ");
      case "skills_abbrev":
        return abbreviate(d.skills, spec.abbrev);
      case "supervisor_name":
        return d.supervisor;
      case "supervisor_initials":
        return d.initials;
      case "student_initials":
        return initialsOf(name);
      case "notes":
        return d.notes;
      default:
        return "";
    }
  };
  const minutesOf = (key: string, it: RowItem) =>
    key === "amount"
      ? it.day + it.night
      : key === "day_amount"
      ? it.day
      : key === "night_amount"
      ? it.night
      : key === "weather_amount"
      ? it.weather
      : 0;

  // ---- log pages (each table paginates on its own; panels with the same filter share one stream)
  const logPages: LogBlock[][] = [];
  const tables = spec.kind === "certification" ? [] : spec.tables;
  for (const tb of tables) {
    const streams = new Map<string, { items: RowItem[]; pos: number; cum: number }>();
    for (const p of tb.panels) {
      if (!streams.has(p.filter)) streams.set(p.filter, { items: itemsFor(drives, p.filter), pos: 0, cum: 0 });
    }
    let page = 0;
    do {
      const cap = page === 0 ? tb.rows_first : tb.rows;
      const panels = tb.panels.map((p) => {
        const s = streams.get(p.filter)!;
        const rows: string[][] = [];
        const sums = new Map<string, number>();
        for (let i = 0; i < cap && s.pos < s.items.length; i++, s.pos++) {
          const it = s.items[s.pos];
          s.cum += it.day + it.night;
          rows.push(p.columns.map((c) => cell(c.key, it, s.cum)));
          for (const c of p.columns) sums.set(c.key, (sums.get(c.key) ?? 0) + minutesOf(c.key, it));
        }
        return { panel: p, rows, sums };
      });
      const total = tb.page_total
        ? {
          label: tb.page_total.label,
          cells: panels.map(({ panel, sums }) =>
            panel.columns.map((c) => tb.page_total!.sum.includes(c.key) ? fmt(sums.get(c.key) ?? 0) : "")
          ),
        }
        : null;
      logPages.push([{
        type: "table",
        table: {
          title: tb.title ?? "",
          row_count: cap,
          total,
          panels: panels.map(({ panel, rows }) => ({
            title: panel.title ?? "",
            columns: panel.columns.map((c) => ({ label: c.label, group: c.group ?? "", w: c.w, key: c.key })),
            rows,
          })),
        },
      }]);
      page++;
    } while ([...streams.values()].some((s) => s.pos < s.items.length));
  }

  // ---- certification / summary blocks
  const certBlocks: LogBlock[] = [];
  const c = spec.certification;
  if (c) {
    if (c.title) certBlocks.push({ type: "text", style: "heading", text: c.title });
    if (c.fields.length) certBlocks.push({ type: "fields", items: items(c.fields) });
    if (c.totals.length) certBlocks.push({ type: "totals", items: items(c.totals) });
    if (c.text) certBlocks.push({ type: "text", style: "cert", text: fill(c.text) });
    if (c.extra_text) certBlocks.push({ type: "text", style: "cert", text: fill(c.extra_text) });
    if (c.signatures.length) certBlocks.push({ type: "signatures", items: items(c.signatures) });
    if (c.notary) {
      certBlocks.push({ type: "notary", title: c.notary.title, text: fill(c.notary.text), lines: c.notary.lines });
    }
  }
  const summaryBlocks: LogBlock[] = spec.summary.length ? [{ type: "totals", items: items(spec.summary) }] : [];
  const legendBlocks: LogBlock[] = spec.legend ? [{ type: "text", style: "legend", text: spec.legend }] : [];
  const computed: LogBlock = {
    type: "computed",
    title: "Computed by LicenseLogger (not part of the official form)",
    items: [
      { label: "Credited total", value: fmt(t.total) },
      { label: "Day", value: fmt(t.day) },
      { label: "Night", value: fmt(t.night) },
      ...(t.weather > 0 ? [{ label: "Bad weather", value: fmt(t.weather) }] : []),
      { label: "Signed drives listed", value: String(drives.length) },
      ...(input.excluded.unsigned_drives > 0
        ? [{
          label: "Not listed: unsigned",
          value: `${input.excluded.unsigned_drives} (${fmt(input.excluded.unsigned_minutes)})`,
        }]
        : []),
      ...(input.excluded.lessons > 0
        ? [{ label: "Not listed: school lessons", value: String(input.excluded.lessons) }]
        : []),
    ],
  };
  const header: LogBlock[] = spec.header_fields.length ? [{ type: "fields", items: items(spec.header_fields) }] : [];

  const pages: LogBlock[][] = [];
  if (spec.kind === "certification") {
    const p1: LogBlock[] = [...header, ...certBlocks];
    for (const tb of spec.tables) {
      p1.push({
        type: "table",
        table: {
          title: tb.title ?? "",
          row_count: tb.rows,
          total: null,
          panels: tb.panels.map((p) => ({
            title: p.title ?? "",
            columns: p.columns.map((c) => ({ label: c.label, group: c.group ?? "", w: c.w, key: c.key })),
            rows: [],
          })),
        },
      });
    }
    p1.push(computed);
    pages.push(p1);
    // Supporting record: the generic table, clearly outside the official form.
    const g = layouts.generic.tables[0];
    const cols = g.panels[0].columns;
    const its = itemsFor(drives, "all");
    for (let i = 0, cum = 0; i === 0 || i < its.length; i += g.rows) {
      const rows = its.slice(i, i + g.rows).map((it) => {
        cum += it.day + it.night;
        return cols.map((c) => cell(c.key, it, cum));
      });
      pages.push([{
        type: "text",
        style: "heading",
        text: "Supporting drive record (LicenseLogger; not part of the official form)",
      }, {
        type: "table",
        table: {
          title: "",
          row_count: Math.max(rows.length, 1),
          total: null,
          panels: [{ title: "", columns: cols.map((c) => ({ label: c.label, group: "", w: c.w, key: c.key })), rows }],
        },
      }]);
      if (its.length === 0) break;
    }
  } else if (spec.cert_position === "before_log") {
    pages.push([...header, ...certBlocks]);
    logPages.forEach((p, i) => pages.push(i === 0 ? [...p, ...legendBlocks] : p));
    pages[pages.length - 1].push(...summaryBlocks, computed);
  } else {
    logPages.forEach((p, i) => pages.push(i === 0 ? [...p, ...legendBlocks] : p));
    if (!pages.length) pages.push([]);
    pages[0].unshift(...header);
    pages[pages.length - 1].push(...summaryBlocks, ...certBlocks, computed);
  }

  const d = disclaimerFor(spec, generic, stateName, isGeneric);
  const n = pages.length;
  return {
    schema: "licenselogger.log_document/v1",
    state_code: input.state_code,
    state_name: stateName,
    kind: isGeneric ? "generic" : spec.kind,
    title: spec.title,
    subtitle: spec.subtitle ?? "",
    form_label: isGeneric
      ? (generic?.form ?? "")
      : [spec.form.number, spec.form.revision ? `(${spec.form.revision})` : ""].filter((x) => x).join(" "),
    source_pdf: isGeneric ? "" : spec.form.source_pdf,
    page: { width: spec.page.size[0], height: spec.page.size[1] },
    disclaimer: d.text,
    disclaimer_mode: d.mode,
    footer: `${name} - prepared with LicenseLogger`,
    notes: isGeneric && generic ? [generic.detail, ...spec.notes] : spec.notes,
    unfillable: spec.unfillable,
    pages: pages.map((blocks, i) => ({ label: `Page ${i + 1} of ${n}`, blocks })),
  };
}

// ---------------------------------------------------------------- PDF renderer
const INK = rgb(0.08, 0.1, 0.14),
  GREY = rgb(0.4, 0.43, 0.48),
  LINE = rgb(0.25, 0.27, 0.3),
  SHADE = rgb(0.93, 0.94, 0.96),
  BLUE = rgb(0.07, 0.3, 0.62);
const safe = (s: string) =>
  s.replace(/[\u2013\u2014]/g, "-").replace(/[\u2018\u2019]/g, "'").replace(/[\u201C\u201D]/g, '"')
    .replace(/\u2265/g, ">=").replace(/[^\x20-\x7E\u00A0-\u00FF]/g, "?");

type R = {
  doc: PDFDocument;
  page: PDFPage;
  f: PDFFont;
  b: PDFFont;
  y: number;
  W: number;
  H: number;
  m: number;
  s: number;
  label: string;
  foot: string;
  disclaimer: string;
  count: number;
};

function wrap(font: PDFFont, text: string, size: number, width: number): string[] {
  const out: string[] = [];
  for (const para of safe(text).split("\n")) {
    let line = "";
    for (const w of para.split(/\s+/)) {
      const next = line ? `${line} ${w}` : w;
      if (font.widthOfTextAtSize(next, size) > width && line) {
        out.push(line);
        line = w;
      } else line = next;
    }
    out.push(line);
  }
  return out;
}
function fit(font: PDFFont, text: string, size: number, width: number): string {
  let s = safe(text);
  if (font.widthOfTextAtSize(s, size) <= width) return s;
  while (s.length > 1 && font.widthOfTextAtSize(s + "...", size) > width) s = s.slice(0, -1);
  return s + "...";
}
function newPage(r: R, cont = false) {
  r.page = r.doc.addPage([r.W, r.H]);
  r.count++;
  r.y = r.H - r.m;
  const fs = 5.5 * r.s;
  r.page.drawText(fit(r.f, `${r.foot}  |  ${r.label}${cont ? " (continued)" : ""}`, fs, r.W - 2 * r.m), {
    x: r.m,
    y: r.m * 0.45,
    size: fs,
    font: r.f,
    color: GREY,
  });
}
function ensure(r: R, h: number) {
  if (r.y - h < r.m + 6 * r.s) newPage(r, true);
}
function para(r: R, text: string, size: number, font?: PDFFont, color = INK, indent = 0) {
  const lh = size * 1.25;
  for (const l of wrap(font ?? r.f, text, size, r.W - 2 * r.m - indent)) {
    ensure(r, lh);
    r.page.drawText(l, { x: r.m + indent, y: r.y - size, size, font: font ?? r.f, color });
    r.y -= lh;
  }
}

function drawFields(r: R, items: Item[]) {
  const cols = r.W > 500 ? 2 : 1,
    gap = 10 * r.s,
    cw = (r.W - 2 * r.m - gap * (cols - 1)) / cols,
    size = 7 * r.s,
    rowH = 17 * r.s;
  for (let i = 0; i < items.length; i += cols) {
    ensure(r, rowH);
    for (let j = 0; j < cols && i + j < items.length; j++) {
      const it = items[i + j], x = r.m + j * (cw + gap);
      const lw = Math.min(r.f.widthOfTextAtSize(safe(it.label), size) + 4, cw * 0.55);
      r.page.drawText(fit(r.f, it.label, size, lw), { x, y: r.y - rowH + 5 * r.s, size, font: r.f, color: GREY });
      r.page.drawLine({
        start: { x: x + lw, y: r.y - rowH + 3 * r.s },
        end: { x: x + cw, y: r.y - rowH + 3 * r.s },
        thickness: 0.5,
        color: LINE,
      });
      if (it.value) {
        r.page.drawText(fit(r.b, it.value, size + 0.5, cw - lw - 4), {
          x: x + lw + 3,
          y: r.y - rowH + 5 * r.s,
          size: size + 0.5,
          font: r.b,
          color: BLUE,
        });
      }
    }
    r.y -= rowH;
  }
  r.y -= 4 * r.s;
}

function drawTable(r: R, t: LogTable, reserve: number) {
  const size = 6.3 * r.s, hsize = 6 * r.s, gap = t.panels.length > 1 ? 8 * r.s : 0;
  if (t.title) {
    ensure(r, 14 * r.s);
    r.page.drawText(fit(r.b, t.title, 8.5 * r.s, r.W - 2 * r.m), {
      x: r.m,
      y: r.y - 9 * r.s,
      size: 8.5 * r.s,
      font: r.b,
      color: INK,
    });
    r.y -= 13 * r.s;
  }
  const pw = (r.W - 2 * r.m - gap * (t.panels.length - 1)) / t.panels.length;
  const geo = t.panels.map((p) => {
    const sw = p.columns.reduce((a, c) => a + c.w, 0);
    let x = 0;
    return p.columns.map((c) => {
      const g = { x, w: (c.w / sw) * pw };
      x += g.w;
      return g;
    });
  });
  // header height: wrapped labels (max 4 lines) + group row if any
  const hasGroup = t.panels.some((p) => p.columns.some((c) => c.group));
  const hasTitle = t.panels.some((p) => p.title);
  let lines = 1;
  t.panels.forEach((p, pi) =>
    p.columns.forEach((c, ci) => {
      lines = Math.max(lines, Math.min(4, wrap(r.b, c.label, hsize, geo[pi][ci].w - 3).length));
    })
  );
  const groupH = hasGroup ? 3 * hsize * 1.2 + 3 : 0, titleH = hasTitle ? 11 * r.s : 0, headH = lines * hsize * 1.2 + 4;
  const avail = r.y - r.m - 8 * r.s - reserve - groupH - headH - titleH - (t.total ? 12 * r.s : 0);
  const rowH = Math.max(9 * r.s, Math.min(24 * r.s, avail / Math.max(1, t.row_count)));
  if (avail < rowH * Math.min(5, t.row_count)) newPage(r, true);
  const top = r.y;
  t.panels.forEach((p, pi) => {
    const x0 = r.m + pi * (pw + gap);
    let y = top;
    if (hasTitle) {
      if (p.title) {
        r.page.drawText(fit(r.b, p.title, 7.5 * r.s, pw), {
          x: x0,
          y: y - 8 * r.s,
          size: 7.5 * r.s,
          font: r.b,
          color: INK,
        });
      }
      y -= titleH;
    }
    if (hasGroup) {
      let ci = 0;
      while (ci < p.columns.length) {
        const g = p.columns[ci].group;
        let cj = ci;
        while (cj + 1 < p.columns.length && g && p.columns[cj + 1].group === g) cj++;
        if (g) {
          const gx = x0 + geo[pi][ci].x, gw = geo[pi][cj].x + geo[pi][cj].w - geo[pi][ci].x;
          r.page.drawRectangle({
            x: gx,
            y: y - groupH,
            width: gw,
            height: groupH,
            color: SHADE,
            borderColor: LINE,
            borderWidth: 0.5,
          });
          wrap(r.b, g, hsize, gw - 3).slice(0, 3).forEach((l, k) =>
            r.page.drawText(l, { x: gx + 1.5, y: y - (k + 1) * hsize * 1.2, size: hsize, font: r.b, color: INK })
          );
        }
        ci = cj + 1;
      }
    }
    const hy = y - groupH;
    p.columns.forEach((c, ci) => {
      const gx = x0 + geo[pi][ci].x, gw = geo[pi][ci].w;
      const span = hasGroup && !c.group; // ungrouped columns span the group row too
      const yy = span ? y : hy, hh = span ? headH + groupH : headH;
      r.page.drawRectangle({
        x: gx,
        y: yy - hh,
        width: gw,
        height: hh,
        color: SHADE,
        borderColor: LINE,
        borderWidth: 0.5,
      });
      wrap(r.b, c.label, hsize, gw - 3).slice(0, span ? 7 : 4).forEach((l, k) =>
        r.page.drawText(l, { x: gx + 1.5, y: yy - 2 - (k + 1) * hsize * 1.2 + 1, size: hsize, font: r.b, color: INK })
      );
    });
    let ry = hy - headH;
    for (let i = 0; i < t.row_count; i++) {
      const row = p.rows[i];
      p.columns.forEach((_c, ci) => {
        const gx = x0 + geo[pi][ci].x, gw = geo[pi][ci].w;
        r.page.drawRectangle({ x: gx, y: ry - rowH, width: gw, height: rowH, borderColor: LINE, borderWidth: 0.4 });
        if (row && row[ci]) {
          r.page.drawText(fit(r.f, row[ci], size, gw - 3), {
            x: gx + 1.5,
            y: ry - rowH / 2 - size / 3,
            size,
            font: r.f,
            color: BLUE,
          });
        }
      });
      ry -= rowH;
    }
    if (t.total) {
      const cells = t.total.cells[pi], th = 12 * r.s;
      const sumIdx = p.columns.map((_c, k) => (t.total!.cells[pi][k] !== "" ? k : -1)).filter((k) => k >= 0);
      const first = sumIdx.length ? sumIdx[0] : -1;
      const lw = first > 0 ? geo[pi][first].x : pw;
      r.page.drawRectangle({
        x: x0,
        y: ry - th,
        width: lw,
        height: th,
        color: SHADE,
        borderColor: LINE,
        borderWidth: 0.5,
      });
      r.page.drawText(fit(r.b, t.total.label, hsize, lw - 3), {
        x: x0 + 1.5,
        y: ry - th / 2 - hsize / 3,
        size: hsize,
        font: r.b,
        color: INK,
      });
      cells.forEach((v, k) => {
        if (first >= 0 && k >= first) {
          const gx = x0 + geo[pi][k].x, gw = geo[pi][k].w;
          r.page.drawRectangle({ x: gx, y: ry - th, width: gw, height: th, borderColor: LINE, borderWidth: 0.5 });
          if (v) {
            r.page.drawText(fit(r.b, v, size, gw - 3), {
              x: gx + 1.5,
              y: ry - th / 2 - size / 3,
              size,
              font: r.b,
              color: BLUE,
            });
          }
        }
      });
      ry -= th;
    }
    r.y = Math.min(r.y, ry);
  });
  r.y -= 8 * r.s;
}

function drawTotals(r: R, items: Item[]) {
  const size = 7 * r.s;
  for (const it of items) {
    ensure(r, 14 * r.s);
    const lw = Math.min(r.f.widthOfTextAtSize(safe(it.label), size), (r.W - 2 * r.m) * 0.7);
    r.page.drawText(fit(r.b, it.label, size, (r.W - 2 * r.m) * 0.7), {
      x: r.m,
      y: r.y - 10 * r.s,
      size,
      font: r.b,
      color: INK,
    });
    const bx = r.m + lw + 6, bw = Math.max(60 * r.s, Math.min(110 * r.s, r.W - r.m - bx));
    r.page.drawRectangle({
      x: bx,
      y: r.y - 13 * r.s,
      width: bw,
      height: 12 * r.s,
      borderColor: LINE,
      borderWidth: 0.6,
    });
    if (it.value) {
      r.page.drawText(fit(r.b, it.value, size + 0.5, bw - 4), {
        x: bx + 3,
        y: r.y - 10 * r.s,
        size: size + 0.5,
        font: r.b,
        color: BLUE,
      });
    }
    r.y -= 15 * r.s;
  }
  r.y -= 3 * r.s;
}

function drawSignatures(r: R, items: Item[]) {
  const cols = r.W > 500 ? 2 : 1,
    gap = 14 * r.s,
    cw = (r.W - 2 * r.m - gap * (cols - 1)) / cols,
    size = 6.3 * r.s,
    rowH = 26 * r.s;
  for (let i = 0; i < items.length; i += cols) {
    ensure(r, rowH);
    for (let j = 0; j < cols && i + j < items.length; j++) {
      const it = items[i + j], x = r.m + j * (cw + gap), ly = r.y - rowH + 10 * r.s;
      r.page.drawLine({ start: { x, y: ly }, end: { x: x + cw, y: ly }, thickness: 0.6, color: INK });
      if (it.value) {
        r.page.drawText(fit(r.b, it.value, 7.5 * r.s, cw), {
          x: x + 2,
          y: ly + 3,
          size: 7.5 * r.s,
          font: r.b,
          color: BLUE,
        });
      }
      wrap(r.f, it.label, size, cw).slice(0, 2).forEach((l, k) =>
        r.page.drawText(l, { x, y: ly - (k + 1) * size * 1.15, size, font: r.f, color: GREY })
      );
    }
    r.y -= rowH;
  }
  r.y -= 4 * r.s;
}

function drawNotary(r: R, n: { title: string; text: string; lines: string[] }) {
  const size = 6.5 * r.s, w = r.W - 2 * r.m;
  const textLines = n.text ? wrap(r.f, n.text, size, w - 16 * r.s) : [];
  const h = 10 * r.s + (n.title ? 11 * r.s : 0) + textLines.length * size * 1.25 +
    Math.ceil(n.lines.length / 2) * 24 * r.s + 6 * r.s;
  ensure(r, h + 4);
  const top = r.y;
  r.page.drawRectangle({ x: r.m, y: top - h, width: w, height: h, borderColor: INK, borderWidth: 0.8 });
  let y = top - 6 * r.s;
  if (n.title) {
    wrap(r.b, n.title, 7 * r.s, w - 12).slice(0, 2).forEach((l) => {
      r.page.drawText(l, { x: r.m + 6, y: y - 7 * r.s, size: 7 * r.s, font: r.b, color: INK });
      y -= 9 * r.s;
    });
    y -= 2 * r.s;
  }
  for (const l of textLines) {
    r.page.drawText(l, { x: r.m + 6, y: y - size, size, font: r.f, color: INK });
    y -= size * 1.25;
  }
  const cw = (w - 30 * r.s) / 2;
  n.lines.forEach((l, i) => {
    const x = r.m + 6 + (i % 2) * (cw + 18 * r.s), ly = y - 18 * r.s - Math.floor(i / 2) * 24 * r.s;
    r.page.drawLine({ start: { x, y: ly }, end: { x: x + cw, y: ly }, thickness: 0.5, color: INK });
    r.page.drawText(fit(r.f, l, size, cw), { x, y: ly - size * 1.2, size, font: r.f, color: GREY });
  });
  r.y = top - h - 8 * r.s;
}

function drawComputed(r: R, title: string, items: Item[]) {
  const size = 6.3 * r.s, w = r.W - 2 * r.m;
  const text = items.map((i) => `${i.label}: ${i.value}`).join("   |   ");
  const lines = wrap(r.f, text, size, w - 12);
  const h = 12 * r.s + lines.length * size * 1.3 + 4;
  ensure(r, h + 2);
  r.page.drawRectangle({
    x: r.m,
    y: r.y - h,
    width: w,
    height: h,
    color: rgb(0.95, 0.97, 1),
    borderColor: BLUE,
    borderWidth: 0.5,
    borderDashArray: [2, 2],
  });
  r.page.drawText(fit(r.b, title, size, w - 12), { x: r.m + 6, y: r.y - 9 * r.s, size, font: r.b, color: BLUE });
  lines.forEach((l, k) =>
    r.page.drawText(l, { x: r.m + 6, y: r.y - 12 * r.s - (k + 1) * size * 1.3 + 2, size, font: r.f, color: INK })
  );
  r.y -= h + 6 * r.s;
}

/** Height a block needs below a table on the same page (keeps the table from pushing the block off). */
function reserveFor(blocks: LogBlock[], s: number): number {
  let h = 0;
  for (const b of blocks) {
    if (b.type === "table") continue;
    if (b.type === "totals") h += b.items.length * 15 * s;
    else if (b.type === "fields") h += Math.ceil(b.items.length / 2) * 17 * s;
    else if (b.type === "signatures") h += Math.ceil(b.items.length / 2) * 26 * s;
    else if (b.type === "notary") h += 80 * s;
    else if (b.type === "computed") h += 30 * s;
    else h += Math.ceil(b.text.length / 110) * 10 * s + 6;
  }
  return Math.min(h, 330 * s);
}

export async function renderStateLogPdf(
  d: LogDocument,
  meta: { generatedAt: string; exportId: string },
): Promise<Uint8Array> {
  const doc = await PDFDocument.create();
  doc.setTitle(safe(`${d.state_name} ${d.form_label} ${d.title}`.trim()));
  doc.setProducer("LicenseLogger");
  const W = d.page.width, H = d.page.height;
  const s = Math.max(0.85, Math.min(1.1, Math.min(W, H) / 612));
  const r: R = {
    doc,
    page: undefined as unknown as PDFPage,
    f: await doc.embedFont(StandardFonts.Helvetica),
    b: await doc.embedFont(StandardFonts.HelveticaBold),
    y: 0,
    W,
    H,
    m: Math.max(20, Math.min(W, H) * 0.055),
    s,
    label: "",
    foot: `${d.footer} | export ${meta.exportId} | ${meta.generatedAt}`,
    disclaimer: d.disclaimer,
    count: 0,
  };
  d.pages.forEach((pg, i) => {
    r.label = pg.label;
    // Pages without a log table (certifications, affidavits) are set larger, like the paper forms.
    // Blank write-in tables (e.g. NY MV-262 school rows) count as roomy too when they are short.
    const roomy = !pg.blocks.some((b) =>
      b.type === "table" && b.table.row_count > 3 &&
      (b.table.row_count > 12 || b.table.panels.some((p) => p.rows.length > 0))
    );
    r.s = s * (roomy ? 1.6 : 1);
    newPage(r);
    // Page head: state + form number on page 1, short running head after that.
    if (i === 0) {
      const head = `${d.state_name.toUpperCase()}${d.form_label ? "  |  " + d.form_label : ""}`;
      r.page.drawText(fit(r.f, head, 6.5 * r.s, W - 2 * r.m), {
        x: r.m,
        y: r.y - 6.5 * r.s,
        size: 6.5 * r.s,
        font: r.f,
        color: GREY,
      });
      r.y -= 10 * r.s;
      if (d.subtitle) para(r, d.subtitle, 7 * r.s, r.b, GREY);
      para(r, d.title, (W < 450 ? 11 : 13) * r.s, r.b, INK);
      r.y -= 2;
      para(r, d.disclaimer, 6.5 * r.s, r.f, BLUE);
      r.y -= 6 * r.s;
    } else {
      r.page.drawText(fit(r.b, `${d.title}${d.form_label ? "  -  " + d.form_label : ""}`, 7 * r.s, W - 2 * r.m), {
        x: r.m,
        y: r.y - 7 * r.s,
        size: 7 * r.s,
        font: r.b,
        color: GREY,
      });
      r.y -= 13 * r.s;
    }
    pg.blocks.forEach((b, bi) => {
      switch (b.type) {
        case "fields":
          drawFields(r, b.items);
          break;
        case "table":
          drawTable(r, b.table, reserveFor(pg.blocks.slice(bi + 1), r.s));
          break;
        case "totals":
          drawTotals(r, b.items);
          break;
        case "signatures":
          drawSignatures(r, b.items);
          break;
        case "notary":
          drawNotary(r, b);
          break;
        case "computed":
          drawComputed(r, b.title, b.items);
          break;
        case "text":
          if (b.style === "heading") {
            r.y -= 2 * r.s;
            para(r, b.text, 8.5 * r.s, r.b, INK);
            r.y -= 2 * r.s;
          } else if (b.style === "legend") {
            para(r, b.text, 5.8 * r.s, r.f, GREY);
            r.y -= 4 * r.s;
          } else if (b.style === "note") para(r, b.text, 6 * r.s, r.f, GREY);
          else {
            para(r, b.text, 7 * r.s, r.f, INK);
            r.y -= 4 * r.s;
          }
      }
    });
    if (i === d.pages.length - 1 && (d.unfillable.length || d.notes.length)) {
      r.y -= 4 * r.s;
      para(r, "Notes on this copy", 6.5 * r.s, r.b, GREY);
      if (d.unfillable.length) {
        para(r, `Left blank for you to fill by hand: ${d.unfillable.join("; ")}.`, 5.8 * r.s, r.f, GREY);
      }
      for (const n of d.notes) para(r, n, 5.8 * r.s, r.f, GREY);
    }
  });
  return await doc.save();
}
