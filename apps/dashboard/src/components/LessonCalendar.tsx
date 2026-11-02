import type { Lesson } from "../lib/types";
import { addDays, addMonths, monthCells, startOfDay, statusColor, statusTone, weekStart } from "../lib/lessonPins";
import { Badge } from "./ui";

export type CalView = "day" | "week" | "month";

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}
function fmtDay(d: Date) {
  return d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" });
}
function fmtMonth(d: Date) {
  return d.toLocaleDateString(undefined, { month: "long", year: "numeric" });
}
function weekdayShort(d: Date) {
  return d.toLocaleDateString(undefined, { weekday: "short" });
}
function sameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
function sameMonth(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth();
}

function lessonsOn(lessons: Lesson[], day: Date) {
  return lessons
    .filter((l) => sameDay(new Date(l.start_at), day))
    .slice()
    .sort((a, b) => a.start_at.localeCompare(b.start_at));
}

function LessonCards({
  rows,
  names,
  selectedId,
  onSelect,
  onOpen,
}: {
  rows: Lesson[];
  names: Record<string, string>;
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  onOpen?: (lesson: Lesson) => void;
}) {
  if (rows.length === 0) return <p className="ll-cal-empty muted">No lessons</p>;
  return (
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
  const selected = startOfDay(anchor);
  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart(anchor), i));
  const cells = monthCells(anchor);

  function step(dir: number) {
    if (view === "day") onAnchorChange(addDays(anchor, dir));
    else if (view === "week") onAnchorChange(addDays(anchor, dir * 7));
    else onAnchorChange(addMonths(anchor, dir));
  }

  const rangeLabel =
    view === "day" ? fmtDay(anchor) : view === "week" ? `${fmtDay(weekDays[0])} – ${fmtDay(weekDays[6])}` : fmtMonth(anchor);

  return (
    <div className="ll-cal">
      <div className="ll-cal-toolbar">
        <div className="seg" aria-label="Calendar range">
          {(["day", "week", "month"] as CalView[]).map((v) => (
            <button key={v} type="button" aria-pressed={view === v} className={view === v ? "on" : ""} onClick={() => onViewChange(v)}>
              {v === "day" ? "Day" : v === "week" ? "Week" : "Month"}
            </button>
          ))}
        </div>
        <div className="ll-cal-nav">
          <button type="button" className="btn sm" aria-label="Previous" onClick={() => step(-1)}>
            ←
          </button>
          <span className="pill soft-ink">{rangeLabel}</span>
          <button type="button" className="btn sm" aria-label="Next" onClick={() => step(1)}>
            →
          </button>
          <button type="button" className="btn sm" onClick={() => onAnchorChange(new Date())}>
            Today
          </button>
        </div>
      </div>

      {view === "week" && (
        <>
          <div className="ll-week-strip" role="tablist" aria-label="Week days">
            {weekDays.map((day) => {
              const n = lessonsOn(lessons, day).length;
              const on = sameDay(day, selected);
              return (
                <button
                  key={day.toISOString()}
                  type="button"
                  role="tab"
                  aria-selected={on}
                  aria-label={fmtDay(day)}
                  className={`ll-week-day${on ? " is-on" : ""}`}
                  onClick={() => onAnchorChange(day)}
                >
                  <span className="ll-week-wd">{weekdayShort(day)}</span>
                  <span className="ll-week-dn">{day.getDate()}</span>
                  {n > 0 ? <span className="ll-week-n">{n}</span> : <span className="ll-week-n is-zero">0</span>}
                </button>
              );
            })}
          </div>
          <div className="ll-cal-grid day">
            <LessonCards rows={lessonsOn(lessons, selected)} names={names} selectedId={selectedId} onSelect={onSelect} onOpen={onOpen} />
          </div>
        </>
      )}

      {view === "day" && (
        <div className="ll-cal-grid day">
          <LessonCards rows={lessonsOn(lessons, selected)} names={names} selectedId={selectedId} onSelect={onSelect} onOpen={onOpen} />
        </div>
      )}

      {view === "month" && (
        <div className="ll-cal-grid month" role="grid" aria-label="Month calendar">
          {weekDays.map((d) => (
            <div key={`h-${d.toISOString()}`} className="ll-cal-dayhead" role="columnheader">
              {weekdayShort(d)}
            </div>
          ))}
          {cells.map((day) => {
            const rows = lessonsOn(lessons, day);
            const inMonth = sameMonth(day, anchor);
            const on = sameDay(day, selected);
            return (
              <button
                key={day.toISOString()}
                type="button"
                role="gridcell"
                aria-selected={on}
                aria-label={fmtDay(day)}
                className={`ll-month-cell${on ? " is-on" : ""}${inMonth ? "" : " is-out"}`}
                onClick={() => onAnchorChange(day)}
              >
                <span className="ll-month-dn">{day.getDate()}</span>
                {rows.slice(0, 3).map((l) => (
                  <span key={l.id} className="ll-month-chip" style={{ background: statusColor(l.status) }}>
                    {fmtTime(l.start_at)}
                  </span>
                ))}
                {rows.length > 3 ? <span className="ll-month-more">+{rows.length - 3}</span> : null}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
