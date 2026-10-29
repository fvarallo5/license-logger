import type { Lesson } from "./types";

/** Monday 00:00 local of the week containing `d`. */
export function weekStart(d: Date): Date {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  x.setDate(x.getDate() - ((x.getDay() + 6) % 7));
  return x;
}

export function dayStart(d: Date): Date {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

export function dayEnd(d: Date): Date {
  const x = dayStart(d);
  x.setDate(x.getDate() + 1);
  return x;
}

export function addDays(d: Date, n: number): Date {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}

export type BoardView = "today" | "week";

export function rangeForView(view: BoardView, anchor: Date): { from: Date; to: Date } {
  if (view === "today") {
    const from = dayStart(anchor);
    return { from, to: dayEnd(anchor) };
  }
  const from = weekStart(anchor);
  return { from, to: addDays(from, 7) };
}

export interface BoardFilters {
  instructorId: string | "all";
  carId: string | "all";
  /** When set, force instructor filter (instructor role). */
  forceInstructorId?: string | null;
}

export function filterLessons(lessons: Lesson[], f: BoardFilters): Lesson[] {
  const instructor = f.forceInstructorId || (f.instructorId === "all" ? null : f.instructorId);
  const car = f.carId === "all" ? null : f.carId;
  return lessons.filter((l) => {
    if (instructor && l.instructor_id !== instructor) return false;
    if (car && (l.car_id ?? null) !== car) return false;
    return true;
  });
}

/** Active board rows: booked / in_lesson first; hide cancelled unless keepCancelled. */
export function sortBoardLessons(lessons: Lesson[]): Lesson[] {
  const rank = (s: string) => {
    if (s === "in_lesson") return 0;
    if (s === "booked") return 1;
    if (s === "taught" || s === "completed") return 2;
    return 3;
  };
  return [...lessons].sort((a, b) => {
    const ra = rank(a.status);
    const rb = rank(b.status);
    if (ra !== rb) return ra - rb;
    return a.start_at.localeCompare(b.start_at);
  });
}

export function isLive(lesson: Lesson, now = new Date()): boolean {
  if (lesson.kind === "blocked") return false;
  if (!["booked", "in_lesson"].includes(lesson.status)) return false;
  const start = new Date(lesson.start_at).getTime();
  const end = new Date(lesson.end_at).getTime();
  const t = now.getTime();
  return start <= t && t < end;
}

export function canMark(lesson: Lesson): boolean {
  if (lesson.kind === "blocked") return false;
  return lesson.status === "booked" || lesson.status === "in_lesson";
}

export function fmtTime(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });
}

export function fmtDayLabel(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
}
