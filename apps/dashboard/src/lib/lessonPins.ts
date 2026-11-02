import type { Lesson, Lot } from "./types";

export type LessonPin = {
  lessonId: string;
  lat: number;
  lng: number;
  label: string;
  kind: "lot" | "pickup";
};

function hashId(id: string): number {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0;
  return h;
}

/** Resolve a map pin for a lesson: lot coords, or a stable offset for pickups. */
export function pinForLesson(lesson: Lesson, lots: Lot[]): LessonPin | null {
  const lot = lots.find((l) => l.is_default && l.lat != null && l.lng != null) ?? lots.find((l) => l.lat != null && l.lng != null);
  if (!lot || lot.lat == null || lot.lng == null) return null;
  const meet = (lesson.meet || "lot").toLowerCase();
  if (meet === "lot" || meet === "school" || meet === "") {
    return { lessonId: lesson.id, lat: Number(lot.lat), lng: Number(lot.lng), label: lot.name, kind: "lot" };
  }
  const h = hashId(lesson.id);
  const dLat = ((h % 7) - 3) * 0.0035;
  const dLng = (((h >> 3) % 5) - 2) * 0.0045;
  return {
    lessonId: lesson.id,
    lat: Number(lot.lat) + dLat,
    lng: Number(lot.lng) + dLng,
    label: meet === "pickup" ? "Pickup" : meet,
    kind: "pickup",
  };
}

export function statusTone(status: string): "ok" | "info" | "warn" | "bad" | "" {
  const s = status.toLowerCase();
  if (s === "taught" || s === "completed") return "ok";
  if (s === "booked" || s === "confirmed") return "info";
  if (s === "blocked" || s === "no_show" || s === "no-show") return "warn";
  if (s === "canceled" || s === "cancelled") return "bad";
  return "";
}

export function statusColor(status: string): string {
  const t = statusTone(status);
  if (t === "ok") return "#059669";
  if (t === "info") return "#0d9488";
  if (t === "warn") return "#d97706";
  if (t === "bad") return "#e11d48";
  return "#64748b";
}

export function startOfDay(d: Date): Date {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function addDays(d: Date, n: number): Date {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

/** Monday-start week containing `d`. */
export function weekStart(d: Date): Date {
  const x = startOfDay(d);
  const day = (x.getDay() + 6) % 7; // Mon=0
  x.setDate(x.getDate() - day);
  return x;
}
