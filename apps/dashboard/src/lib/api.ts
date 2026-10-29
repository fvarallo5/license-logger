// Every database call the dashboard makes lives here, with exact live table / RPC names.
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  Drive,
  DriveListRow,
  Enrollment,
  Invite,
  Car,
  Lesson,
  LinkRequest,
  Reservation,
  SlotTemplate,
  Member,
  Membership,
  QboStatus,
  Role,
  RuleProgress,
  School,
  Student,
  StudentProgressRow,
} from "./types";

export const PAGE_SIZE = 25;

/** Turn Postgres / PostgREST errors into plain language. */
export function friendly(e: unknown): string {
  const err = e as { message?: string; code?: string } | null;
  const msg = err?.message ?? String(e);
  if (err?.code === "42501") return msg.includes("permission denied") ? "You don't have permission to do that." : msg;
  if (err?.code === "P0002") return msg || "Not found.";
  if (err?.code === "PGRST202") return "This feature isn't available on the server yet (function missing).";
  if (/Failed to fetch|NetworkError/i.test(msg)) return "Can't reach the server. Check your connection.";
  return msg;
}
function check<T>(r: { data: T | null; error: unknown }): T {
  if (r.error) throw new Error(friendly(r.error));
  return r.data as T;
}
export interface Page<T, C> {
  rows: T[];
  next: C | null;
}

/** Row range for offset-paginated table reads. */
const pageRange = (page: number): [number, number] => [page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1];
/** Wraps one offset page; a full page means there may be another. */
const offsetPage = <T>(rows: T[], page: number): Page<T, number> => ({ rows, next: rows.length === PAGE_SIZE ? page + 1 : null });

// ---------- schools & membership ----------
export async function myMemberships(sb: SupabaseClient, userId: string): Promise<Membership[]> {
  const r = await sb
    .from("school_members")
    .select(
      "school_id, user_id, role, access, schools(id, name, city, phone, timezone, default_lesson_minutes, cancel_window_hours, who_starts, package_draw)",
    )
    .eq("user_id", userId)
    .order("created_at");
  return check(r) as unknown as Membership[];
}
/** Claims any pending staff invites for the signed-in email. Safe to call on every sign-in. */
export async function acceptMyInvites(sb: SupabaseClient): Promise<number> {
  const r = await sb.rpc("accept_my_invites");
  return r.error ? 0 : Number(r.data ?? 0);
}
export async function createSchool(sb: SupabaseClient, name: string, city: string): Promise<string> {
  return check(await sb.rpc("create_school", { p_name: name, p_city: city })) as string;
}
export async function updateSchool(sb: SupabaseClient, s: School): Promise<void> {
  check(
    await sb.rpc("update_school", {
      p_school_id: s.id,
      p_name: s.name,
      p_city: s.city,
      p_phone: s.phone,
      p_timezone: s.timezone,
      p_default_lesson_minutes: s.default_lesson_minutes,
      p_cancel_window_hours: s.cancel_window_hours,
      p_who_starts: s.who_starts,
    }),
  );
}

// ---------- students ----------
export interface StudentCursor {
  last: string;
  first: string;
  id: string;
}
export async function studentsPage(
  sb: SupabaseClient,
  schoolId: string,
  after: StudentCursor | null,
  limit = PAGE_SIZE,
): Promise<Page<StudentProgressRow, StudentCursor>> {
  const rows = check(
    await sb.rpc("school_students_progress", {
      p_school_id: schoolId,
      p_after_last: after?.last ?? null,
      p_after_first: after?.first ?? null,
      p_after_id: after?.id ?? null,
      p_limit: limit,
    }),
  ) as StudentProgressRow[];
  const last = rows[rows.length - 1];
  return { rows, next: rows.length === limit && last ? { last: last.last_name, first: last.first_name, id: last.student_id } : null };
}
export interface NewStudent {
  first_name: string;
  last_name: string;
  birthday: string | null;
  parent_name: string;
  parent_email: string;
  instructor_id: string | null;
  package_hours: number | null;
}
export async function addStudent(sb: SupabaseClient, schoolId: string, s: NewStudent): Promise<string> {
  return check(
    await sb.rpc("add_student", {
      p_school_id: schoolId,
      p_first_name: s.first_name,
      p_last_name: s.last_name,
      p_birthday: s.birthday,
      p_parent_name: s.parent_name,
      p_parent_email: s.parent_email,
      p_instructor_id: s.instructor_id,
      p_package_hours: s.package_hours,
    }),
  ) as string;
}
export async function getStudent(sb: SupabaseClient, id: string): Promise<Student | null> {
  return check(
    await sb
      .from("students")
      .select(
        "id, school_id, first_name, last_name, birthday, state_code, phone, seat, permit_on, join_code, instructor_id, user_id, notes",
      )
      .eq("id", id)
      .maybeSingle(),
  ) as Student | null;
}
export async function releaseStudent(sb: SupabaseClient, studentId: string): Promise<unknown> {
  return check(await sb.rpc("release_student", { p_student_id: studentId }));
}
/** School asks an independent student (by the code shown in their app) to join. The STUDENT/FAMILY accepts in the app. */
export async function requestStudentLink(sb: SupabaseClient, schoolId: string, code: string): Promise<unknown> {
  return check(await sb.rpc("request_student_link", { p_school_id: schoolId, p_student_code: code.trim() }));
}
export async function cancelLinkRequest(sb: SupabaseClient, requestId: string): Promise<void> {
  check(await sb.rpc("cancel_student_link_request", { p_request_id: requestId }));
}
export async function linkRequestsPage(sb: SupabaseClient, schoolId: string, page: number): Promise<Page<LinkRequest, number>> {
  const rows = check(
    await sb
      .from("school_link_requests")
      .select("id, school_id, student_id, status, created_at, expires_at, responded_at")
      .eq("school_id", schoolId)
      .order("created_at", { ascending: false })
      .range(...pageRange(page)),
  ) as LinkRequest[];
  return offsetPage(rows, page);
}
export async function formerStudentsPage(sb: SupabaseClient, schoolId: string, page: number): Promise<Page<Enrollment, number>> {
  const rows = check(
    await sb
      .from("school_enrollments")
      .select("id, student_id, school_id, joined_at, joined_via, left_at, left_reason, first_name, last_name")
      .eq("school_id", schoolId)
      .not("left_at", "is", null)
      .order("left_at", { ascending: false })
      .range(...pageRange(page)),
  ) as Enrollment[];
  return offsetPage(rows, page);
}

// ---------- progress & resources ----------
export async function ruleProgress(sb: SupabaseClient, studentId: string): Promise<RuleProgress> {
  return check(await sb.rpc("student_rule_progress", { p_student_id: studentId })) as RuleProgress;
}
export async function stateResources(sb: SupabaseClient, state: string, permitOn: string | null): Promise<Record<string, unknown>> {
  return check(await sb.rpc("state_resources", { p_state_code: state, p_permit_on: permitOn })) as Record<string, unknown>;
}

// ---------- drives ----------
export interface DriveCursor {
  started_at: string;
  id: string;
}
/** Pending sign-off queue for one school, newest first, keyset-paginated on the drives table (RLS-scoped). */
export async function pendingDrivesPage(
  sb: SupabaseClient,
  schoolId: string,
  before: DriveCursor | null,
  limit = PAGE_SIZE,
): Promise<Page<Drive, DriveCursor>> {
  let q = sb
    .from("drives")
    .select(
      "id, student_id, school_id, kind, source, status, started_at, duration_minutes, night_minutes, distance_miles, start_label, end_label, notes, students(first_name, last_name)",
    )
    .eq("school_id", schoolId)
    .eq("status", "pending");
  if (before) q = q.or(`started_at.lt.${before.started_at},and(started_at.eq.${before.started_at},id.lt.${before.id})`);
  const rows = check(
    await q.order("started_at", { ascending: false }).order("id", { ascending: false }).limit(limit),
  ) as unknown as Drive[];
  const last = rows[rows.length - 1];
  return { rows, next: rows.length === limit && last ? { started_at: last.started_at, id: last.id } : null };
}
export async function studentDrivesPage(
  sb: SupabaseClient,
  studentId: string,
  before: DriveCursor | null,
  limit = PAGE_SIZE,
): Promise<Page<DriveListRow, DriveCursor>> {
  const rows = check(
    await sb.rpc("list_drives", {
      p_student_id: studentId,
      p_before_started_at: before?.started_at ?? null,
      p_before_id: before?.id ?? null,
      p_limit: limit,
    }),
  ) as DriveListRow[];
  const last = rows[rows.length - 1];
  return { rows, next: rows.length === limit && last ? { started_at: last.started_at, id: last.id } : null };
}
/** Instructor sign-off. The backend only lets the school sign LESSON drives; practice drives are signed by family. */
export async function signLesson(sb: SupabaseClient, driveId: string): Promise<unknown> {
  return check(
    await sb.rpc("sign_drive", {
      p_drive_id: driveId,
      p_method: "instructor",
      p_supervisor_id: null,
      p_initials: null,
      p_device: { client: "dashboard", ua: typeof navigator === "undefined" ? "" : navigator.userAgent.slice(0, 200) },
    }),
  );
}
export async function rejectDrive(sb: SupabaseClient, driveId: string, reason: string): Promise<void> {
  check(await sb.rpc("reject_drive", { p_drive_id: driveId, p_reason: reason }));
}
export async function voidDrive(sb: SupabaseClient, driveId: string, reason: string): Promise<void> {
  if (reason.trim().length < 3) throw new Error("Please give a reason (at least 3 characters).");
  check(await sb.rpc("void_drive", { p_drive_id: driveId, p_reason: reason }));
}

// ---------- reports ----------
export type ExportResult = { ok: true; url: string } | { ok: false; notDeployed: boolean; message: string };
export async function exportReport(
  sb: SupabaseClient,
  body: { student_id: string; format: "pdf" | "csv"; layout?: "report" | "state"; drive_id?: string },
): Promise<ExportResult> {
  const { data, error } = await sb.functions.invoke("export-report", { body });
  if (!error) {
    const url = (data as { url?: string } | null)?.url;
    return url ? { ok: true, url } : { ok: false, notDeployed: false, message: "The server didn't return a download link." };
  }
  const e = error as { name?: string; message?: string; context?: { status?: number; json?: () => Promise<{ error?: string }> } };
  const status = e.context?.status;
  if (status === 404 || e.name === "FunctionsFetchError" || e.name === "FunctionsRelayError") {
    return {
      ok: false,
      notDeployed: true,
      message: "Report export isn't switched on yet (the export-report function hasn't been deployed).",
    };
  }
  let msg = e.message ?? "Export failed.";
  try {
    const j = await e.context?.json?.();
    if (j?.error) msg = j.error;
  } catch {
    /* body not JSON */
  }
  return { ok: false, notDeployed: false, message: msg };
}

// ---------- people & scheduling ----------
export async function membersPage(sb: SupabaseClient, schoolId: string, page: number, role?: Role): Promise<Page<Member, number>> {
  let q = sb.from("school_members").select("school_id, user_id, role, license_expires, hourly_rate, color").eq("school_id", schoolId);
  if (role) q = q.eq("role", role);
  const rows = check(await q.order("created_at").range(...pageRange(page))) as Member[];
  return offsetPage(rows, page);
}
export async function profileNames(sb: SupabaseClient, ids: string[]): Promise<Record<string, string>> {
  if (!ids.length) return {};
  const { data } = await sb.from("profiles").select("id, full_name").in("id", ids);
  const out: Record<string, string> = {};
  for (const p of (data ?? []) as { id: string; full_name: string }[]) out[p.id] = p.full_name;
  return out;
}
export async function invitesPage(sb: SupabaseClient, schoolId: string, page: number): Promise<Page<Invite, number>> {
  const rows = check(
    await sb
      .from("school_invites")
      .select("id, email, role, created_at, expires_at, accepted_at")
      .eq("school_id", schoolId)
      .is("accepted_at", null)
      .order("created_at", { ascending: false })
      .range(...pageRange(page)),
  ) as Invite[];
  return offsetPage(rows, page);
}
export async function inviteToSchool(sb: SupabaseClient, schoolId: string, email: string, role: Exclude<Role, "owner">): Promise<void> {
  check(await sb.rpc("invite_to_school", { p_school_id: schoolId, p_email: email.trim(), p_role: role, p_access: {} }));
}
export async function revokeInvite(sb: SupabaseClient, id: number): Promise<void> {
  check(await sb.rpc("revoke_invite", { p_invite_id: id }));
}
export async function schedule(sb: SupabaseClient, schoolId: string, from: Date, to: Date): Promise<Lesson[]> {
  return check(await sb.rpc("school_schedule", { p_school_id: schoolId, p_from: from.toISOString(), p_to: to.toISOString() })) as Lesson[];
}
export async function markLesson(sb: SupabaseClient, lessonId: string, status: "taught" | "cancelled" | "no_show"): Promise<void> {
  check(await sb.rpc("mark_lesson", { p_lesson_id: lessonId, p_status: status }));
}

// ---------- QuickBooks (read-only status in v1) ----------
export async function qboStatus(sb: SupabaseClient, schoolId: string): Promise<QboStatus | null> {
  const rows = check(await sb.rpc("qbo_sync_status", { p_school_id: schoolId })) as QboStatus[] | null;
  return rows?.[0] ?? null;
}

// ---------- board (cars + offline-aware lesson marks) ----------
export async function listCars(sb: SupabaseClient, schoolId: string): Promise<Car[]> {
  return check(
    await sb
      .from("cars")
      .select("id, school_id, name, plate, color, model, dual_control, assigned_user_id, active")
      .eq("school_id", schoolId)
      .eq("active", true)
      .order("name"),
  ) as Car[];
}

/**
 * Reassign instructor (and optional car) on a booked lesson.
 * Requires migration supabase/migrations/_NOT_APPLIED_reassign_lesson.sql (NOT applied on live yet).
 */
export async function reassignLesson(
  sb: SupabaseClient,
  lessonId: string,
  instructorId: string,
  carId: string | null = null,
): Promise<void> {
  check(
    await sb.rpc("reassign_lesson", {
      p_lesson_id: lessonId,
      p_instructor_id: instructorId,
      p_car_id: carId,
    }),
  );
}

// ---------- plan / templates / booking ----------
export async function listSlotTemplates(sb: SupabaseClient, schoolId: string): Promise<SlotTemplate[]> {
  return check(
    await sb
      .from("slot_templates")
      .select(
        "id, school_id, instructor_id, car_id, lot_id, name, kind, duration_minutes, travel_before_minutes, travel_after_minutes, days, window_start, window_end, meet, min_notice_hours, max_advance_days, note, active, created_at",
      )
      .eq("school_id", schoolId)
      .eq("active", true)
      .order("name"),
  ) as SlotTemplate[];
}

export async function listReservations(sb: SupabaseClient, schoolId: string, from: Date, to: Date): Promise<Reservation[]> {
  return check(
    await sb
      .from("reservations")
      .select(
        "id, school_id, student_id, instructor_id, car_id, template_id, lesson_id, start_at, end_at, travel_before_minutes, travel_after_minutes, meet, kind, status, note, decline_reason, created_at",
      )
      .eq("school_id", schoolId)
      .gte("start_at", from.toISOString())
      .lt("start_at", to.toISOString())
      .order("start_at"),
  ) as Reservation[];
}

export async function addSlotTemplate(
  sb: SupabaseClient,
  args: {
    schoolId: string;
    instructorId: string;
    name: string;
    kind?: string;
    durationMinutes?: number;
    travelBefore?: number;
    travelAfter?: number;
    days?: number[];
    windowStart?: string;
    windowEnd?: string;
    meet?: string;
    carId?: string | null;
    minNoticeHours?: number;
    maxAdvanceDays?: number;
    note?: string;
  },
): Promise<string> {
  return check(
    await sb.rpc("add_slot_template", {
      p_school_id: args.schoolId,
      p_instructor_id: args.instructorId,
      p_name: args.name,
      p_kind: args.kind ?? "btw",
      p_duration_minutes: args.durationMinutes ?? 60,
      p_travel_before_minutes: args.travelBefore ?? 0,
      p_travel_after_minutes: args.travelAfter ?? 15,
      p_days: args.days ?? [1, 2, 3, 4, 5],
      p_window_start: args.windowStart ?? "09:00",
      p_window_end: args.windowEnd ?? "17:00",
      p_meet: args.meet ?? "lot",
      p_car_id: args.carId ?? null,
      p_min_notice_hours: args.minNoticeHours ?? 24,
      p_max_advance_days: args.maxAdvanceDays ?? 14,
      p_note: args.note ?? "",
    }),
  ) as string;
}

export async function bookLesson(
  sb: SupabaseClient,
  args: {
    schoolId: string;
    studentId: string;
    instructorId: string;
    start: string;
    end: string;
    meet?: string;
    kind?: string;
    carId?: string | null;
    travelBefore?: number;
    travelAfter?: number;
    notes?: string;
    templateId?: string | null;
  },
): Promise<string> {
  return check(
    await sb.rpc("book_lesson", {
      p_school_id: args.schoolId,
      p_student_id: args.studentId,
      p_instructor_id: args.instructorId,
      p_start: args.start,
      p_end: args.end,
      p_meet: args.meet ?? "lot",
      p_kind: args.kind ?? "btw",
      p_car_id: args.carId ?? null,
      p_travel_before_minutes: args.travelBefore ?? 0,
      p_travel_after_minutes: args.travelAfter ?? 15,
      p_notes: args.notes ?? "",
      p_template_id: args.templateId ?? null,
    }),
  ) as string;
}

export async function addBlock(
  sb: SupabaseClient,
  schoolId: string,
  instructorId: string,
  start: string,
  end: string,
  name = "Blocked",
): Promise<string> {
  return check(
    await sb.rpc("add_block", {
      p_school_id: schoolId,
      p_instructor_id: instructorId,
      p_start: start,
      p_end: end,
      p_name: name,
    }),
  ) as string;
}

export async function acceptReservation(sb: SupabaseClient, reservationId: string): Promise<string> {
  return check(await sb.rpc("accept_reservation", { p_reservation_id: reservationId })) as string;
}

export async function declineReservation(sb: SupabaseClient, reservationId: string, reason: string): Promise<void> {
  if (reason.trim().length < 1) throw new Error("Decline reason is required.");
  check(await sb.rpc("decline_reservation", { p_reservation_id: reservationId, p_reason: reason.trim() }));
}
