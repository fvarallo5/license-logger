import { useEffect, useMemo, useState } from "react";
import type { Lesson } from "../lib/types";
import { addDays, startOfDay, statusColor, statusTone, weekStart } from "../lib/lessonPins";
import { Badge } from "./ui";

function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

function fmtDow(d: Date) {
  return d.toLocaleDateString(undefined, { weekday: "short" });
}

function studentLabel(l: Lesson, names: Record<string, string>) {
  if (l.kind === "blocked") return l.name || "Blocked";
  if (l.student_id && names[l.student_id]) return names[l.student_id];
  return l.topic || l.kind || "Lesson";
}

/**
 * Option D week view: 7-day strip with lesson counts + selected day's cards.
 * Used for Week tab on desktop and mobile (everywhere).
 */
export function WeekStripView({
  lessons,
  names,
  anchor,
  selectedId,
  onSelect,
}: {
  lessons: Lesson[];
  names: Record<string, string>;
  anchor: Date;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}) {
  const days = useMemo(() => Array.from({ length: 7 }, (_, i) => addDays(weekStart(anchor), i)), [anchor]);
  const today = useMemo(() => startOfDay(new Date()), []);
  const [selectedDay, setSelectedDay] = useState<Date>(() => startOfDay(new Date()));

  useEffect(() => {
    const inWeek = days.some((d) => sameDay(d, selectedDay));
    if (inWeek) return;
    const todayInWeek = days.find((d) => sameDay(d, today));
    setSelectedDay(todayInWeek ?? days[0]);
  }, [days, selectedDay, today]);

  const counts = useMemo(() => {
    return days.map((day) => lessons.filter((l) => sameDay(new Date(l.start_at), day)).length);
  }, [days, lessons]);

  const rows = useMemo(() => {
    return lessons
      .filter((l) => sameDay(new Date(l.start_at), selectedDay))
      .slice()
      .sort((a, b) => a.start_at.localeCompare(b.start_at));
  }, [lessons, selectedDay]);

  const dayTitle = selectedDay.toLocaleDateString(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
  });

  return (
    <div className="ll-week-d" data-testid="week-strip-view">
      <div className="ll-week-d-strip" role="tablist" aria-label="Days of week">
        {days.map((day, i) => {
          const on = sameDay(day, selectedDay);
          const isToday = sameDay(day, today);
          const n = counts[i];
          return (
            <button
              key={day.toISOString()}
              type="button"
              role="tab"
              aria-selected={on}
              className={`ll-week-d-day${on ? " is-on" : ""}${isToday ? " is-today" : ""}`}
              onClick={() => setSelectedDay(startOfDay(day))}
            >
              <span className="ll-week-d-dow">{fmtDow(day)}</span>
              <span className="ll-week-d-dom">{day.getDate()}</span>
              <span className="ll-week-d-cnt">
                {n} lesson{n === 1 ? "" : "s"}
              </span>
            </button>
          );
        })}
      </div>

      <div className="ll-week-d-detail">
        <div className="ll-week-d-detail-h">
          <strong>{dayTitle}</strong>
          {sameDay(selectedDay, today) ? <span className="pill soft-ink">Today</span> : null}
        </div>
        {rows.length === 0 ? (
          <p className="ll-cal-empty muted">No lessons this day</p>
        ) : (
          <ul className="ll-week-d-list">
            {rows.map((l) => {
              const on = selectedId === l.id;
              const color = statusColor(l.status);
              const student = studentLabel(l, names);
              const instructor = names[l.instructor_id] || "Instructor";
              return (
                <li key={l.id}>
                  <button
                    type="button"
                    className={`ll-week-d-card${on ? " is-on" : ""}`}
                    style={{ borderLeftColor: color }}
                    onClick={() => onSelect(l.id)}
                  >
                    <span className="ll-week-d-time">
                      {fmtTime(l.start_at)}
                      <span className="muted"> – {fmtTime(l.end_at)}</span>
                    </span>
                    <span className="ll-week-d-copy">
                      <strong>{student}</strong>
                      <small className="muted">
                        {instructor}
                        {l.kind ? ` · ${l.kind}` : ""}
                        {l.meet ? ` · ${l.meet}` : ""}
                      </small>
                    </span>
                    <Badge tone={statusTone(l.status)}>{l.status}</Badge>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}
