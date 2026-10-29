export const hrs = (minutes: number | null | undefined) => `${((minutes ?? 0) / 60).toFixed(1)} h`;
export const fmtDate = (iso: string | null | undefined) =>
  iso ? new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }) : "—";
export const fmtDateTime = (iso: string | null | undefined) =>
  iso ? new Date(iso).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }) : "—";
export const fullName = (p: { first_name?: string; last_name?: string } | null | undefined) =>
  p ? `${p.first_name ?? ""} ${p.last_name ?? ""}`.trim() || "Unnamed" : "Unknown";
/** Badge color for any row status used across drives, requests and lessons. */
export function statusTone(status: string): "ok" | "warn" | "bad" | "info" | "" {
  if (["signed", "accepted", "completed", "taught", "active"].includes(status)) return "ok";
  if (status === "pending") return "warn";
  if (["rejected", "voided", "declined", "cancelled", "no_show", "expired"].includes(status)) return "bad";
  if (status === "booked" || status === "in_lesson") return "info";
  return "";
}
export const roleLabel: Record<string, string> = { owner: "Owner", admin: "Admin", front_desk: "Front desk", instructor: "Instructor" };
