import type { Lesson } from "../lib/types";
import { addDays, startOfDay, statusColor, statusTone, weekStart } from "../lib/lessonPins";
import { Badge } from "./ui";

export type CalView = "day" | "week";

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}
function fmtDay(d: Date) {
  return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
}
function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export function LessonCalendar({
  lessons,
  names,
  view,
  onViewChange,
  anchor,
  onAnchorChange,
  selectedId,
  onSelect,
  onOpen,
}: {
  lessons: Lesson[];
  names: Record<string, string>;
  view: CalView;
  onViewChange: (v: CalView) => void;
  anchor: Date;
  onAnchorChange: (d: Date) => void;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  onOpen?: (lesson: Lesson) => void;
}) {
  const days = view === "day" ? [startOfDay(anchor)] : Array.from({ length: 7 }, (_, i) => addDays(weekStart(anchor), i));

  function lessonsOn(day: Date) {
    return lessons
      .filter((l) => sameDay(new Date(l.start_at), day))
      .slice()
      .sort((a, b) => a.start_at.localeCompare(b.start_at));
  }

  return (
    <div className="ll-cal">
      <div className="ll-cal-toolbar">
        <div className="seg" aria-label="Calendar range">
          {(["day", "week"] as CalView[]).map((v) => (
            <button key={v} type="button" aria-pressed={view === v} className={view === v ? "on" : ""} onClick={() => onViewChange(v)}>
              {v === "day" ? "Day" : "Week"}
            </button>
          ))}
        </div>
        <div className="ll-cal-nav">
          <button
            type="button"
            className="btn sm"
            aria-label="Previous"
            onClick={() => onAnchorChange(addDays(anchor, view === "day" ? -1 : -7))}
          >
            ←
          </button>
          <span className="pill soft-ink">{view === "day" ? fmtDay(anchor) : `${fmtDay(days[0])} – ${fmtDay(days[6])}`}</span>
          <button
            type="button"
            className="btn sm"
            aria-label="Next"
            onClick={() => onAnchorChange(addDays(anchor, view === "day" ? 1 : 7))}
          >
            →
          </button>
          <button type="button" className="btn sm" onClick={() => onAnchorChange(new Date())}>
            Today
          </button>
        </div>
      </div>

      <div className={`ll-cal-grid ${view}`}>
        {days.map((day) => {
          const rows = lessonsOn(day);
          return (
            <div key={day.toISOString()} className="ll-cal-day">
              {view === "week" && <div className="ll-cal-dayhead">{fmtDay(day)}</div>}
              {rows.length === 0 ? (
                <p className="ll-cal-empty muted">No lessons</p>
              ) : (
                <ul className="ll-cal-list">
                  {rows.map((l) => {
                    const on = selectedId === l.id;
                    const color = statusColor(l.status);
                    return (
                      <li key={l.id}>
                        <button
                          type="button"
                          className={`ll-cal-item${on ? " is-on" : ""}`}
                          style={{ borderLeftColor: color }}
                          onClick={() => {
                            onSelect(l.id);
                            onOpen?.(l);
                          }}
                        >
                          <span className="ll-cal-time">{fmtTime(l.start_at)}</span>
                          <span className="ll-cal-dot" style={{ background: color }} aria-hidden />
                          <span className="ll-cal-copy">
                            <strong>{l.kind || l.topic || "Lesson"}</strong>
                            <small className="muted">
                              {names[l.instructor_id] || "Instructor"}
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
          );
        })}
      </div>
    </div>
  );
}
