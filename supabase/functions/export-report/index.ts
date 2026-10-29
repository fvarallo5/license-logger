// POST /functions/v1/export-report   (signed-in user's JWT required)
//   { "student_id": "...", "format": "pdf" | "csv" }               full hours report
//   { "student_id": "...", "format": "pdf", "drive_id": "..." }     single drive page
//   { "student_id": "...", "format": "pdf", "layout": "state" }     state-matched log (official form layout,
//                                                                   docs/log_layouts); default layout "report" is unchanged
// -> { url, expires_in, export_id }   url is a 10-minute signed link to a PRIVATE bucket.
// All data is read AS THE CALLER (RLS decides what they may export). The service role is
// used only to write the file, record it, and sign the URL.
import { json, pgStatus, preflight } from "../_shared/http.ts";
import { requireUser, serviceClient, userClient } from "../_shared/clients.ts";
import {
  type Drive,
  INDEPENDENT_LABEL,
  renderCsv,
  renderDrivePdf,
  renderHoursPdf,
  renderStateLog,
  type Signoff,
  type Student,
} from "./render.ts";

const MAX_DRIVES = 3000;

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json(req, { error: "POST only" }, 405);
  const user = await requireUser(req);
  if (!user) return json(req, { error: "Sign in required" }, 401);
  const { student_id, format = "pdf", drive_id = null, layout = "report" } = await req.json().catch(() => ({}));
  if (!student_id || !["pdf", "csv"].includes(format)) {
    return json(req, { error: "student_id and format (pdf|csv) required" }, 400);
  }
  if (!["report", "state"].includes(layout)) return json(req, { error: "layout must be report or state" }, 400);

  const db = userClient(req);
  const svc = serviceClient();

  // Simple abuse guard: 30 exports per hour per person.
  const { count } = await svc.from("exports").select("id", { count: "exact", head: true })
    .eq("requested_by", user.id).gte("created_at", new Date(Date.now() - 3600_000).toISOString());
  if ((count ?? 0) >= 30) return json(req, { error: "Too many exports, try again later" }, 429);

  const { data: stu, error: e1 } = await db.from("students")
    .select("id, first_name, last_name, birthday, state_code, permit_on, school_id, schools(name, phone)").eq(
      "id",
      student_id,
    ).maybeSingle();
  if (e1) return json(req, { error: e1.message }, pgStatus(e1.code));
  if (!stu) return json(req, { error: "Student not found" }, 404);
  // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
  const sch = (stu as any).schools ?? {};
  const student: Student = {
    first_name: stu.first_name,
    last_name: stu.last_name,
    state_code: stu.state_code,
    permit_on: stu.permit_on,
    school_name: stu.school_id ? (sch.name ?? "") : INDEPENDENT_LABEL,
    school_phone: sch.phone ?? "",
  };

  const exportId = crypto.randomUUID();
  const generatedAt = new Date().toISOString().replace("T", " ").slice(0, 16) + " UTC";
  let bytes: Uint8Array, kind: string, ext: string;

  if (drive_id) {
    const { data: d, error } = await db.from("drives")
      .select(
        "id, kind, source, status, started_at, ended_at, tz, local_date, duration_minutes, night_minutes, weather_minutes, distance_miles, start_label, end_label, conditions, skills, notes, route_polyline, supervisors(name)",
      )
      .eq("id", drive_id).eq("student_id", student_id).maybeSingle();
    if (error) return json(req, { error: error.message }, pgStatus(error.code));
    if (!d) return json(req, { error: "Drive not found" }, 404);
    const { data: so } = await db.from("drive_signoffs").select(
      "drive_id, method, supervisor_name, initials, signed_at, snapshot_sha256",
    )
      .eq("drive_id", drive_id).maybeSingle();
    // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
    const drive = { ...(d as any), supervisor_name: (d as any).supervisors?.name ?? null } as Drive;
    bytes = await renderDrivePdf({ student, drive, signoff: (so as Signoff) ?? null, generatedAt, exportId });
    kind = "drive_pdf";
    ext = "pdf";
  } else {
    const { data: summary, error: es } = await db.rpc("student_hours_summary", { p_student_id: student_id }).single();
    if (es) return json(req, { error: es.message }, pgStatus(es.code));
    const { data: days, error: ed } = await db.rpc("student_hours_by_day", { p_student_id: student_id });
    if (ed) return json(req, { error: ed.message }, pgStatus(ed.code));
    // State-matched layout: requirements, caps, stages, form name/number, notary block.
    const { data: resources, error: er } = await db.rpc("my_rule_resources", { p_student_id: student_id });
    if (er) return json(req, { error: er.message }, pgStatus(er.code));
    // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
    const progress = (resources as any)?.progress ?? null;

    // Page through drives and sign-offs (never one unbounded request).
    const drives: Drive[] = [];
    let cursor: { t: string; id: string } | null = null;
    while (drives.length < MAX_DRIVES) {
      const { data: page, error } = await db.rpc("list_drives", {
        p_student_id: student_id,
        p_before_started_at: cursor?.t ?? null,
        p_before_id: cursor?.id ?? null,
        p_limit: 200,
      });
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      const rows = (page ?? []) as Drive[];
      drives.push(...rows);
      if (rows.length < 200) break;
      cursor = { t: rows[rows.length - 1].started_at, id: rows[rows.length - 1].id };
    }
    const signoffs: Signoff[] = [];
    for (let from = 0;; from += 1000) {
      const { data: s, error } = await db.from("drive_signoffs")
        .select("drive_id, method, supervisor_name, initials, signed_at, snapshot_sha256")
        .eq("student_id", student_id).order("signed_at").range(from, from + 999);
      if (error) return json(req, { error: error.message }, pgStatus(error.code));
      signoffs.push(...((s ?? []) as Signoff[]));
      if (!s || s.length < 1000) break;
    }
    if (format === "csv") {
      // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
      bytes = new TextEncoder().encode(renderCsv(drives, signoffs, (days ?? []) as any));
      kind = "hours_csv";
      ext = "csv";
    } else if (layout === "state") {
      // Same data, laid out like the state's official form (kind stays hours_pdf: no schema change).
      ({ bytes } = await renderStateLog({
        // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
        student: { ...student, birthday: (stu as any).birthday ?? null },
        // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
        summary: summary as any,
        drives,
        signoffs,
        progress,
        generatedAt,
        exportId,
      }));
      kind = "hours_pdf";
      ext = "pdf";
    } else {
      bytes = await renderHoursPdf({
        student,
        // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
        summary: summary as any,
        // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
        days: (days ?? []) as any,
        drives,
        signoffs,
        generatedAt,
        exportId,
        progress,
        // deno-lint-ignore no-explicit-any -- untyped external JSON (QuickBooks API / PostgREST embed)
        resources: (resources as any)?.form ? (resources as any) : null,
      });
      kind = "hours_pdf";
      ext = "pdf";
    }
  }

  // Independent students (no driving school) have school_id = null.
  const path = `${stu.school_id ?? "independent"}/${student_id}/${exportId}.${ext}`;
  const contentType = ext === "pdf" ? "application/pdf" : "text/csv";
  const up = await svc.storage.from("exports").upload(path, bytes, { contentType, upsert: false });
  if (up.error) return json(req, { error: "Upload failed" }, 500);
  const { error: ei } = await svc.from("exports").insert({
    id: exportId,
    student_id,
    drive_id,
    requested_by: user.id,
    kind,
    storage_path: path,
    byte_size: bytes.byteLength,
  });
  if (ei) return json(req, { error: "Could not record export" }, 500);

  const filename = `LicenseLogger-${student.first_name}-${kind}.${ext}`.replace(/[^A-Za-z0-9._-]/g, "_");
  const { data: signed, error: eu } = await svc.storage.from("exports").createSignedUrl(path, 600, {
    download: filename,
  });
  if (eu || !signed) return json(req, { error: "Could not sign URL" }, 500);
  return json(req, { url: signed.signedUrl, expires_in: 600, export_id: exportId });
});
