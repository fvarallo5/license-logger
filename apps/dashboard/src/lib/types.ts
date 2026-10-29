// Shapes mirror the LIVE license-logger schema (read 2026-10-24). Keep names exact.
export type Role = "owner" | "admin" | "front_desk" | "instructor";

export interface School {
  id: string;
  name: string;
  city: string;
  phone: string;
  timezone: string;
  default_lesson_minutes: number;
  cancel_window_hours: number;
  who_starts: string;
  package_draw: string;
}
export interface Membership {
  school_id: string;
  user_id: string;
  role: Role;
  access: Record<string, boolean>;
  schools: School | null;
}

/** school_students_progress(p_school_id, p_after_last, p_after_first, p_after_id, p_limit) */
export interface StudentProgressRow {
  student_id: string;
  first_name: string;
  last_name: string;
  seat: string;
  instructor_id: string | null;
  practice_hours: number;
  night_hours: number;
  school_hours: number;
  hour_goal: number;
  night_goal: number;
  pending_drives: number;
  last_drive_at: string | null;
}
export interface Student {
  id: string;
  school_id: string | null;
  first_name: string;
  last_name: string;
  birthday: string | null;
  state_code: string;
  phone: string;
  seat: string;
  permit_on: string | null;
  join_code: string;
  instructor_id: string | null;
  user_id: string | null;
  notes: string;
}
export interface Enrollment {
  id: string;
  student_id: string;
  school_id: string;
  joined_at: string;
  joined_via: string;
  left_at: string | null;
  left_reason: string | null;
  first_name: string;
  last_name: string;
}
export interface LinkRequest {
  id: string;
  school_id: string;
  student_id: string;
  status: string;
  created_at: string;
  expires_at: string;
  responded_at: string | null;
}
/** drives table (pending review queue) */
export interface Drive {
  id: string;
  student_id: string;
  school_id: string | null;
  kind: "practice" | "lesson";
  source: string;
  status: string;
  started_at: string;
  duration_minutes: number;
  night_minutes: number;
  distance_miles: number;
  start_label: string;
  end_label: string;
  notes: string;
  students?: { first_name: string; last_name: string } | null;
}
/** list_drives(...) row */
export interface DriveListRow {
  id: string;
  student_id: string;
  supervisor_name: string | null;
  kind: string;
  source: string;
  status: string;
  started_at: string;
  ended_at: string | null;
  local_date: string;
  duration_minutes: number;
  night_minutes: number;
  distance_miles: number;
  start_label: string;
  end_label: string;
  has_route: boolean;
  locked_at: string | null;
  weather_minutes: number;
}
export interface Requirement {
  key?: string;
  label?: string;
  required_minutes?: number;
  credited_minutes?: number;
  pending_minutes?: number;
  remaining_minutes?: number;
  met?: boolean;
}
export interface RuleProgress {
  student_id: string;
  rule: null | {
    state_code: string;
    jurisdiction_name: string;
    label: string;
    status: string;
    requirement_kind: string;
    permit_on: string | null;
    selected_by: string;
  };
  requirements: Requirement[];
  stages: { key: string; label: string; met: boolean; requirements: Requirement[] }[];
  all_met: boolean;
  still_needed: string[];
  caps?: { daily_minutes: number | null; weekly_minutes: number | null };
  paperwork?: { form_name: string; form_number: string; form_pdf_url: string; notarization: string; digital_log: string };
}
export interface Lesson {
  id: string;
  school_id: string;
  student_id: string | null;
  instructor_id: string;
  start_at: string;
  end_at: string;
  kind: string;
  status: string;
  name: string;
  meet: string;
  topic: string;
}
export interface Member {
  school_id: string;
  user_id: string;
  role: Role;
  license_expires: string | null;
  hourly_rate: number | null;
  color: string | null;
}
export interface Invite {
  id: number;
  email: string;
  role: string;
  created_at: string;
  expires_at: string;
  accepted_at: string | null;
}
export interface QboStatus {
  status: string;
  company_name: string | null;
  last_sync_at: string | null;
  last_error: string | null;
  queued: number;
  failed: number;
  dead: number;
  refresh_expires_at: string | null;
}
