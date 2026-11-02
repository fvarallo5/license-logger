import { lazy, Suspense } from "react";
import type { Lesson } from "../lib/types";
import { addDays, startOfDay, statusColor, statusTone, weekStart } from "../lib/lessonPins";
import { Badge } from "./ui";
import { WeekStripView } from "./WeekStripView";

export type CalView = "day" | "week" | "month";

const LessonCalendarGrid = lazy(() => import("./LessonCalendarGrid"));

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}
function fmtDay(d: Date) {
  return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
}
function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function headerLabel(view: CalView, anchor: Date): string {
  if (view === "month") {
    return anchor.toLocaleDateString(undefined, { month: "long", year: "numeric" });
  }
  if (view === "day") return fmtDay(anchor);
  const start = weekStart(anchor);
  const end = addDays(start, 6);
  const sameMonth = start.getMonth() === end.getMonth();
  if (sameMonth) {
    return `${start.toLocaleDateString(undefined, { month: "short", day: "numeric" })} – ${end.getDate()}, ${end.getFullYear()}`;
  }
  return `${fmtDay(start)} – ${fmtDay(end)}`;
}

function shiftAnchor(view: CalView, anchor: Date, dir: -1 | 1): Date {
  if (view === "day") return addDays(anchor, dir);
  if (view === "week") return addDays(anchor, dir * 7);
  const d = new Date(anchor);
  d.setMonth(d.getMonth() + dir);
  return d;
}

/** Mobile day list (no FullCalendar). Week uses WeekStripView instead. */
function LessonList({
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
  const day = startOfDay(anchor);
  const rows = lessons
    .filter((l) => sameDay(new Date(l.start_at), day))
    .slice()
    .sort((a, b) => a.start_at.localeCompare(b.start_at));

  return (
    <div className="ll-cal-grid day">
      <div className="ll-cal-day">
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
                    onClick={() => onSelect(l.id)}
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
    </div>
  );
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
  mode = "grid",
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
  /** `grid` = FullCalendar for day/month (desktop); `list` = day list (mobile). Week is always strip (D). */
  mode?: "grid" | "list";
}) {
  const views: CalView[] = mode === "list" ? ["day", "week"] : ["day", "week", "month"];

  function renderBody() {
    if (view === "week") {
      return <WeekStripView lessons={lessons} names={names} anchor={anchor} selectedId={selectedId} onSelect={onSelect} />;
    }
    if (mode === "list") {
      return <LessonList lessons={lessons} names={names} anchor={anchor} selectedId={selectedId} onSelect={onSelect} />;
    }
    return (
      <Suspense fallback={<div className="ll-fc-loading muted">Loading calendar…</div>}>
        <LessonCalendarGrid lessons={lessons} names={names} view={view} anchor={anchor} selectedId={selectedId} onSelect={onSelect} />
      </Suspense>
    );
  }

  return (
    <div className={`ll-cal ll-cal-${mode}`}>
      <div className="ll-cal-toolbar">
        <div className="seg" aria-label="Calendar range">
          {views.map((v) => (
            <button key={v} type="button" aria-pressed={view === v} className={view === v ? "on" : ""} onClick={() => onViewChange(v)}>
              {v === "day" ? "Day" : v === "week" ? "Week" : "Month"}
            </button>
          ))}
        </div>
        <div className="ll-cal-nav">
          <button type="button" className="btn sm" aria-label="Previous" onClick={() => onAnchorChange(shiftAnchor(view, anchor, -1))}>
            ←
          </button>
          <span className="pill soft-ink ll-cal-title">{headerLabel(view, anchor)}</span>
          <button type="button" className="btn sm" aria-label="Next" onClick={() => onAnchorChange(shiftAnchor(view, anchor, 1))}>
            →
          </button>
          <button type="button" className="btn sm" onClick={() => onAnchorChange(new Date())}>
            Today
          </button>
        </div>
      </div>

      {renderBody()}
    </div>
  );
}
