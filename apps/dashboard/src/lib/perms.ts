import type { Membership } from "./types";
// Mirrors private.desk_school_ids / pay checks in the backend. UI hiding is convenience only; RLS + RPC checks enforce.
export function perms(m: Membership | null) {
  const role = m?.role;
  const admin = role === "owner" || role === "admin";
  const desk = admin || (role === "front_desk" && m?.access?.students !== false);
  return {
    role,
    manageSchool: admin, // settings, invites, QuickBooks
    manageStudents: desk, // add / release / link requests
    reviewDrives: desk || role === "instructor",
    viewBilling: admin || (role === "front_desk" && m?.access?.pay === true),
  };
}
