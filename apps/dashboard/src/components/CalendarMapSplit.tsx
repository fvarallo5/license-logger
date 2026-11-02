import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { listLots } from "../lib/api";
import type { Lesson, Lot } from "../lib/types";
import { useDesktopMedia } from "../lib/theme";
import { Card } from "./ui";
import { LessonCalendar, type CalView } from "./LessonCalendar";
import { LessonMap } from "./LessonMap";
import { pinForLesson } from "../lib/lessonPins";

/**
 * Desktop: TrekTrack-style 50/50 calendar + Leaflet map.
 * Mobile (<900px): calendar / lesson list only — map is not mounted (no Leaflet).
 */
export function CalendarMapSplit({
  schoolId,
  lessons,
  names,
  title,
}: {
  schoolId: string;
  lessons: Lesson[];
  names: Record<string, string>;
  schoolCity?: string | null;
  title?: string;
}) {
  const desktop = useDesktopMedia(900);
  const [lots, setLots] = useState<Lot[]>([]);
  const [view, setView] = useState<CalView>("week");
  const [anchor, setAnchor] = useState(() => new Date());
  const [selectedId, setSelectedId] = useState<string | null>(null);

  useEffect(() => {
    if (!desktop) {
      setLots([]);
      return;
    }
    let cancelled = false;
    void listLots(supabase, schoolId)
      .catch(() => [] as Lot[])
      .then((rows) => {
        if (!cancelled) setLots(rows);
      });
    return () => {
      cancelled = true;
    };
  }, [schoolId, desktop]);

  const selected = useMemo(() => lessons.find((l) => l.id === selectedId) ?? null, [lessons, selectedId]);
  const onSelect = useCallback((id: string | null) => setSelectedId(id), []);
  const mappable = useMemo(() => lessons.filter((l) => Boolean(pinForLesson(l, lots))), [lessons, lots]);
  const heading = title ?? (desktop ? "Schedule & map" : "Schedule");

  return (
    <Card title={heading} count={`${lessons.length} lessons`}>
      <div className={`ll-split${desktop ? "" : " is-mobile"}`} data-testid="calendar-map-split">
        <section className="ll-split-pane" aria-label="Calendar pane">
          {desktop && <h3 className="ll-split-h">Calendar</h3>}
          <LessonCalendar
            lessons={lessons}
            names={names}
            view={view}
            onViewChange={setView}
            anchor={anchor}
            onAnchorChange={setAnchor}
            selectedId={selectedId}
            onSelect={onSelect}
          />
        </section>
        {desktop && (
          <section className="ll-split-pane" aria-label="Map pane">
            <h3 className="ll-split-h">Map</h3>
            <LessonMap lessons={mappable} lots={lots} names={names} selectedId={selectedId} onSelect={onSelect} />
          </section>
        )}
      </div>
      {selected && (
        <div className="ll-split-sel">
          <strong>{selected.kind || "Lesson"}</strong>
          <span className="muted">
            {" "}
            · {names[selected.instructor_id] || "Instructor"} · {selected.meet || "—"} · {selected.status}
          </span>
          {desktop && (
            <Link className="btn sm primary" to="/board" style={{ marginLeft: "auto" }}>
              Open on Board
            </Link>
          )}
        </div>
      )}
    </Card>
  );
}
