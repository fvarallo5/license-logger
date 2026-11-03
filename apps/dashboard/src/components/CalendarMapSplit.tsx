import { lazy, Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { listLots, schedule } from "../lib/api";
import type { Lesson, Lot } from "../lib/types";
import { useDesktopMedia } from "../lib/theme";
import { pinForLesson, rangeForCalView } from "../lib/lessonPins";
import { Card } from "./ui";
import { LessonCalendar, type CalView } from "./LessonCalendar";
const LessonMap = lazy(() => import("./LessonMap").then((m) => ({ default: m.LessonMap })));

async function studentNames(ids: string[]): Promise<Record<string, string>> {
  if (!ids.length) return {};
  const { data } = await supabase.from("students").select("id, first_name, last_name").in("id", ids);
  const out: Record<string, string> = {};
  for (const row of data ?? []) {
    const r = row as { id: string; first_name?: string | null; last_name?: string | null };
    out[r.id] = [r.first_name, r.last_name].filter(Boolean).join(" ").trim() || "Student";
  }
  return out;
}

/**
 * Desktop: 60/40 calendar (FullCalendar) + Leaflet map (map fills pane height).
 * Mobile (<900px): simple lesson list only — map is not mounted (no Leaflet).
 */
export function CalendarMapSplit({
  schoolId,
  lessons: seedLessons,
  names,
  title,
  defaultView = "day",
}: {
  schoolId: string;
  lessons: Lesson[];
  names: Record<string, string>;
  schoolCity?: string | null;
  title?: string;
  defaultView?: CalView;
}) {
  const desktop = useDesktopMedia(900);
  const [lots, setLots] = useState<Lot[]>([]);
  const [view, setView] = useState<CalView>(defaultView);
  const [anchor, setAnchor] = useState(() => new Date());
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [calLessons, setCalLessons] = useState<Lesson[]>(seedLessons);
  const [extraNames, setExtraNames] = useState<Record<string, string>>({});

  useEffect(() => {
    if (!desktop) setCalLessons(seedLessons);
  }, [seedLessons, desktop]);

  useEffect(() => {
    if (!desktop) return;
    let cancelled = false;
    const { from, to } = rangeForCalView(view, anchor);
    void schedule(supabase, schoolId, from, to)
      .catch(() => seedLessons)
      .then((rows) => {
        if (!cancelled) setCalLessons(rows);
      });
    return () => {
      cancelled = true;
    };
  }, [schoolId, desktop, view, anchor, seedLessons]);

  useEffect(() => {
    let cancelled = false;
    const ids = [...new Set(calLessons.map((l) => l.student_id).filter(Boolean))] as string[];
    const missing = ids.filter((id) => !names[id]);
    if (!missing.length) return;
    void studentNames(missing).then((rows) => {
      if (cancelled) return;
      setExtraNames((prev) => {
        let changed = false;
        const next = { ...prev };
        for (const [k, v] of Object.entries(rows)) {
          if (next[k] !== v) {
            next[k] = v;
            changed = true;
          }
        }
        return changed ? next : prev;
      });
    });
    return () => {
      cancelled = true;
    };
  }, [calLessons, names]);

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

  const allNames = useMemo(() => ({ ...extraNames, ...names }), [names, extraNames]);
  const selected = useMemo(() => calLessons.find((l) => l.id === selectedId) ?? null, [calLessons, selectedId]);
  const onSelect = useCallback((id: string | null) => setSelectedId(id), []);
  const mappable = useMemo(() => calLessons.filter((l) => Boolean(pinForLesson(l, lots))), [calLessons, lots]);
  const heading = title ?? (desktop ? "Schedule & Map" : "Schedule");
  const layoutKey = `${view}-${anchor.toISOString().slice(0, 10)}-${calLessons.length}`;

  return (
    <Card title={heading} count={`${calLessons.length} lessons`}>
      <div className={`ll-split${desktop ? "" : " is-mobile"}`} data-testid="calendar-map-split">
        <section className="ll-split-pane" aria-label="Calendar pane">
          {desktop && <h3 className="ll-split-h">Calendar</h3>}
          <LessonCalendar
            lessons={calLessons}
            names={allNames}
            view={desktop ? view : view === "month" ? "day" : view}
            onViewChange={setView}
            anchor={anchor}
            onAnchorChange={setAnchor}
            selectedId={selectedId}
            onSelect={onSelect}
            mode={desktop ? "grid" : "list"}
          />
        </section>
        {desktop && (
          <section className="ll-split-pane ll-split-pane-map" aria-label="Map pane">
            <h3 className="ll-split-h">Map</h3>
            <Suspense fallback={<div className="ll-map-empty muted">Loading map…</div>}>
              <LessonMap
                lessons={mappable}
                lots={lots}
                names={allNames}
                selectedId={selectedId}
                onSelect={onSelect}
                layoutKey={layoutKey}
              />
            </Suspense>
          </section>
        )}
      </div>
      {selected && (
        <div className="ll-split-sel">
          <strong>{selected.student_id ? allNames[selected.student_id] || selected.kind || "Lesson" : selected.kind || "Lesson"}</strong>
          <span className="muted">
            {" "}
            · {allNames[selected.instructor_id] || "Instructor"} · {selected.meet || "—"} · {selected.status}
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
