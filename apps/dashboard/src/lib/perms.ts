import type { Membership } from "./types";
// Mirrors private.desk_school_ids / pay checks in the backend. UI hiding is convenience only; RLS + RPC checks enforce.
export function perms(m: Membership | null) {
  const role = m?.role;
  const admin = role === "owner" || role === "admin";
  const desk = admin || (role === "front_desk" && m?.access?.students !== false);
  const instructor = role === "instructor";
  return {
    role,
    manageSchool: admin, // settings, invites, QuickBooks
    manageStudents: desk, // add / release / link requests
    reviewDrives: desk || instructor,
    viewBilling: admin || (role === "front_desk" && m?.access?.pay === true),
    /** Board is for every school member. Instructors only see their own lessons (client + RLS). */
    seeBoard: Boolean(m),
    /** Reassign / school-wide filters — owners, admins, front desk. */
    manageBoard: desk,
    /** True when the signed-in user is an instructor (force self filter). */
    instructorOnly: instructor && !admin,
  };
}
