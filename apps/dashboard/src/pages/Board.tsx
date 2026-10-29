import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { friendly, listCars, markLesson, membersPage, pendingDrivesPage, profileNames, reassignLesson, schedule } from "../lib/api";
import { perms } from "../lib/perms";
import { fullName, statusTone } from "../lib/format";
import {
  addDays,
  canMark,
  filterLessons,
  fmtDayLabel,
  fmtTime,
  isLive,
  rangeForView,
  sortBoardLessons,
  type BoardView,
  weekStart,
} from "../lib/boardHelpers";
import { enqueueMutation, flushMutationQueue, isNetworkError, isOnline, pendingCount, subscribeOffline } from "../lib/offline";
import { useSchool, useSession } from "../session";
import type { Car, Drive, Lesson, Member } from "../lib/types";
import { Badge, Card, Empty, ErrorBox, Loading, Modal, PageHeader } from "../components/ui";

export default function BoardPage() {
  const { session } = useSession();
  const current = useSchool();
  const p = perms(current);
  const schoolId = current.school_id;
  const me = session?.user.id ?? "";

  const [view, setView] = useState<BoardView>("today");
  const [anchor, setAnchor] = useState(() => new Date());
  const [instructorFilter, setInstructorFilter] = useState<string>("all");
  const [carFilter, setCarFilter] = useState<string>("all");

  const [lessons, setLessons] = useState<Lesson[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [names, setNames] = useState<Record<string, string>>({});
  const [cars, setCars] = useState<Car[]>([]);
  const [instructors, setInstructors] = useState<Member[]>([]);
  const [pending, setPending] = useState<Drive[]>([]);
  const [queueN, setQueueN] = useState(0);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [reassign, setReassign] = useState<Lesson | null>(null);
  const [tick, setTick] = useState(0);

  const { from, to } = useMemo(() => rangeForView(view, anchor), [view, anchor]);
  const forceInstructor = p.instructorOnly ? me : null;

  const load = useCallback(async () => {
    setErr(null);
    setLessons(null);
    try {
      const [ls, carRows, memPage] = await Promise.all([
        schedule(supabase, schoolId, from, to),
        listCars(supabase, schoolId).catch(() => [] as Car[]),
        membersPage(supabase, schoolId, 0).catch(() => ({ rows: [] as Member[], next: null })),
      ]);
      setLessons(ls);
      setCars(carRows);
      setInstructors(memPage.rows.filter((m) => m.role === "instructor" || m.role === "owner" || m.role === "admin"));
      const studentIds = [...new Set(ls.map((l) => l.student_id).filter(Boolean))] as string[];
      const instructorIds = [...new Set(ls.map((l) => l.instructor_id).filter(Boolean))];
      const [prof, studentNames] = await Promise.all([profileNames(supabase, instructorIds), fetchStudentNames(studentIds)]);
      setNames({ ...prof, ...studentNames });
      if (p.reviewDrives) {
        const pd = await pendingDrivesPage(supabase, schoolId, null, 5);
        setPending(pd.rows);
      } else {
        setPending([]);
      }
    } catch (e) {
      setErr(friendly(e));
      setLessons([]);
    }
  }, [schoolId, from, to, p.reviewDrives]);

  useEffect(() => {
    void load();
  }, [load, tick]);

  useEffect(() => {
    void pendingCount().then(setQueueN);
    return subscribeOffline((d) => setQueueN(d.pending));
  }, []);

  useEffect(() => {
    const onOnline = () => {
      void flushBoardQueue().then(() => {
        setTick((t) => t + 1);
      });
    };
    window.addEventListener("online", onOnline);
    return () => window.removeEventListener("online", onOnline);
  }, []);

  const filtered = useMemo(() => {
    if (!lessons) return [];
    return sortBoardLessons(
      filterLessons(lessons, {
        instructorId: instructorFilter as "all" | string,
        carId: carFilter as "all" | string,
        forceInstructorId: forceInstructor,
      }),
    );
  }, [lessons, instructorFilter, carFilter, forceInstructor]);

  const live = filtered.find((l) => isLive(l));
  const carName = (id: string | null | undefined) => cars.find((c) => c.id === id)?.name ?? null;

  async function runMark(lesson: Lesson, status: "taught" | "no_show" | "cancelled") {
    setBusyId(lesson.id);
    setErr(null);
    try {
      if (!isOnline()) {
        await enqueueMutation({ type: "mark_lesson", payload: { lessonId: lesson.id, status } });
        setLessons((prev) => prev?.map((l) => (l.id === lesson.id ? { ...l, status } : l)) ?? null);
        setQueueN(await pendingCount());
        return;
      }
      await markLesson(supabase, lesson.id, status);
      setTick((t) => t + 1);
    } catch (e) {
      if (isNetworkError(e)) {
        await enqueueMutation({ type: "mark_lesson", payload: { lessonId: lesson.id, status } });
        setLessons((prev) => prev?.map((l) => (l.id === lesson.id ? { ...l, status } : l)) ?? null);
        setQueueN(await pendingCount());
      } else {
        setErr(friendly(e));
      }
    } finally {
      setBusyId(null);
    }
  }

  async function flushBoardQueue() {
    await flushMutationQueue({
      mark_lesson: async (payload) => {
        await markLesson(supabase, String(payload.lessonId), payload.status as "taught" | "no_show" | "cancelled");
      },
      reassign_lesson: async (payload) => {
        await reassignLesson(supabase, String(payload.lessonId), String(payload.instructorId), (payload.carId as string | null) ?? null);
      },
    });
    setQueueN(await pendingCount());
  }

  async function doReassign(lessonId: string, instructorId: string, carId: string | null) {
    setBusyId(lessonId);
    setErr(null);
    try {
      if (!isOnline()) {
        await enqueueMutation({ type: "reassign_lesson", payload: { lessonId, instructorId, carId } });
        setLessons((prev) => prev?.map((l) => (l.id === lessonId ? { ...l, instructor_id: instructorId, car_id: carId } : l)) ?? null);
        setQueueN(await pendingCount());
        setReassign(null);
        return;
      }
      await reassignLesson(supabase, lessonId, instructorId, carId);
      setReassign(null);
      setTick((t) => t + 1);
    } catch (e) {
      const msg = friendly(e);
      if (isNetworkError(e)) {
        await enqueueMutation({ type: "reassign_lesson", payload: { lessonId, instructorId, carId } });
        setQueueN(await pendingCount());
        setReassign(null);
      } else if (/function|PGRST202|not exist|schema cache/i.test(msg)) {
        setErr("Reassign RPC is missing from the schema cache. Hard-refresh the dashboard.");
      } else {
        setErr(msg);
      }
    } finally {
      setBusyId(null);
    }
  }

  const shift = (n: number) => {
    setAnchor((a) => addDays(a, view === "today" ? n : n * 7));
  };

  const rangeLabel =
    view === "today"
      ? anchor.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })
      : `${weekStart(anchor).toLocaleDateString(undefined, { month: "short", day: "numeric" })} – ${addDays(weekStart(anchor), 6).toLocaleDateString(undefined, { month: "short", day: "numeric" })}`;

  return (
    <>
      <PageHeader
        title="Board"
        desc={
          p.instructorOnly
            ? "Your lessons today — mark taught, no-show, or cancel."
            : "Today’s lessons across the school. Filter by instructor or car."
        }
      >
        <div className="seg" role="tablist" aria-label="Board range">
          {(["today", "week"] as BoardView[]).map((v) => (
            <button key={v} role="tab" aria-selected={view === v} className={view === v ? "on" : ""} onClick={() => setView(v)}>
              {v === "today" ? "Today" : "Week"}
            </button>
          ))}
        </div>
        <button className="btn" aria-label="Previous" onClick={() => shift(-1)}>
          ←
        </button>
        <span className="pill light" aria-live="polite">
          {rangeLabel}
        </span>
        <button className="btn" aria-label="Next" onClick={() => shift(1)}>
          →
        </button>
        <button className="btn" onClick={() => setAnchor(new Date())}>
          Now
        </button>
        <button className="btn" onClick={() => setTick((t) => t + 1)} aria-label="Refresh board">
          Refresh
        </button>
      </PageHeader>

      {queueN > 0 && (
        <div className="alert warn offline-banner" role="status">
          {queueN} change{queueN === 1 ? "" : "s"} waiting to sync
          {isOnline() && (
            <button className="btn sm" onClick={() => void flushBoardQueue().then(() => setTick((t) => t + 1))}>
              Sync now
            </button>
          )}
        </div>
      )}

      {err && <ErrorBox error={err} onRetry={() => setTick((t) => t + 1)} />}

      {p.reviewDrives && pending.length > 0 && (
        <Card title="Pending sign-offs" count={pending.length} actions={<Link to="/drives">Open queue</Link>}>
          <ul className="board-pending">
            {pending.map((d) => (
              <li key={d.id}>
                <strong>{fullName(d.students)}</strong>
                <span className="muted">
                  {" "}
                  · {d.kind} · {Math.round(d.duration_minutes)} min
                </span>
              </li>
            ))}
          </ul>
        </Card>
      )}

      <div className="board-filters">
        {!p.instructorOnly && (
          <label>
            Instructor
            <select aria-label="Filter by instructor" value={instructorFilter} onChange={(e) => setInstructorFilter(e.target.value)}>
              <option value="all">All instructors</option>
              {instructors.map((m) => (
                <option key={m.user_id} value={m.user_id}>
                  {names[m.user_id] || m.user_id.slice(0, 8)}
                </option>
              ))}
            </select>
          </label>
        )}
        <label>
          Car
          <select aria-label="Filter by car" value={carFilter} onChange={(e) => setCarFilter(e.target.value)}>
            <option value="all">All cars</option>
            {cars.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
                {c.plate ? ` · ${c.plate}` : ""}
              </option>
            ))}
          </select>
        </label>
      </div>

      {live && (
        <div className="board-live" aria-live="polite">
          <Badge tone="ok">Live now</Badge>
          <strong>
            {fmtTime(live.start_at)}–{fmtTime(live.end_at)}
          </strong>
          <span>{live.student_id ? names[live.student_id] || "Student" : live.name || "Blocked"}</span>
          <span className="muted">{names[live.instructor_id] || "Instructor"}</span>
        </div>
      )}

      {lessons === null && !err ? (
        <Loading label="Loading board…" />
      ) : filtered.length === 0 ? (
        <Empty>
          No lessons in this range
          {forceInstructor ? " for you" : ""}. Try another day, or open Schedule to book.
        </Empty>
      ) : (
        <div className="board-list">
          {filtered.map((l) => {
            const studentLabel = l.kind === "blocked" ? l.name || "Blocked" : l.student_id ? names[l.student_id] || "Student" : "Open slot";
            const tone = statusTone(l.status === "taught" ? "taught" : l.status);
            return (
              <article key={l.id} className={`board-card${isLive(l) ? " live" : ""}`} aria-label={`${studentLabel} ${fmtTime(l.start_at)}`}>
                <div className="board-card-top">
                  <div>
                    <div className="board-time">
                      {view === "week" && <span className="board-day">{fmtDayLabel(l.start_at)} · </span>}
                      {fmtTime(l.start_at)}–{fmtTime(l.end_at)}
                    </div>
                    <h3>{studentLabel}</h3>
                    <p className="muted">
                      {names[l.instructor_id] || "Instructor"}
                      {carName(l.car_id) ? ` · ${carName(l.car_id)}` : ""}
                      {l.meet ? ` · ${l.meet}` : ""}
                      {l.topic ? ` · ${l.topic}` : ""}
                    </p>
                  </div>
                  <Badge tone={tone}>{l.status.replace("_", " ")}</Badge>
                </div>
                <div className="board-actions">
                  {l.student_id && (
                    <Link className="btn sm" to={`/students/${l.student_id}`}>
                      Hours
                    </Link>
                  )}
                  {canMark(l) && (
                    <>
                      <button className="btn sm primary" disabled={busyId === l.id} onClick={() => void runMark(l, "taught")}>
                        Taught
                      </button>
                      <button className="btn sm" disabled={busyId === l.id} onClick={() => void runMark(l, "no_show")}>
                        No-show
                      </button>
                      <button className="btn sm" disabled={busyId === l.id} onClick={() => void runMark(l, "cancelled")}>
                        Cancel
                      </button>
                    </>
                  )}
                  {p.manageBoard && canMark(l) && (
                    <button className="btn sm" disabled={busyId === l.id} onClick={() => setReassign(l)}>
                      Reassign
                    </button>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      )}

      {reassign && (
        <ReassignModal
          lesson={reassign}
          instructors={instructors}
          cars={cars}
          names={names}
          onClose={() => setReassign(null)}
          onSave={(instructorId, carId) => void doReassign(reassign.id, instructorId, carId)}
        />
      )}
    </>
  );
}

async function fetchStudentNames(ids: string[]): Promise<Record<string, string>> {
  if (!ids.length) return {};
  const { data } = await supabase.from("students").select("id, first_name, last_name").in("id", ids);
  const out: Record<string, string> = {};
  for (const s of (data ?? []) as { id: string; first_name: string; last_name: string }[]) {
    out[s.id] = `${s.first_name} ${s.last_name}`.trim();
  }
  return out;
}

function ReassignModal({
  lesson,
  instructors,
  cars,
  names,
  onClose,
  onSave,
}: {
  lesson: Lesson;
  instructors: Member[];
  cars: Car[];
  names: Record<string, string>;
  onClose: () => void;
  onSave: (instructorId: string, carId: string | null) => void;
}) {
  const [instructorId, setInstructorId] = useState(lesson.instructor_id);
  const [carId, setCarId] = useState(lesson.car_id ?? "");
  return (
    <Modal title="Reassign lesson" onClose={onClose}>
      <p className="muted" style={{ marginTop: 0 }}>
        {fmtTime(lesson.start_at)}–{fmtTime(lesson.end_at)}
        {lesson.student_id ? ` · ${names[lesson.student_id] || "Student"}` : ""}
      </p>
      <label className="stack">
        Instructor
        <select value={instructorId} onChange={(e) => setInstructorId(e.target.value)} aria-label="New instructor">
          {instructors.map((m) => (
            <option key={m.user_id} value={m.user_id}>
              {names[m.user_id] || m.user_id.slice(0, 8)}
            </option>
          ))}
        </select>
      </label>
      <label className="stack">
        Car
        <select value={carId} onChange={(e) => setCarId(e.target.value)} aria-label="Car">
          <option value="">No car</option>
          {cars.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </label>
      <div className="row" style={{ marginTop: 12, gap: 8 }}>
        <button className="btn" onClick={onClose}>
          Back
        </button>
        <button className="btn primary" onClick={() => onSave(instructorId, carId || null)}>
          Save
        </button>
      </div>
      <p className="muted" style={{ fontSize: 12 }}>
        Saves via <code>reassign_lesson</code> (desk staff or the current instructor).
      </p>
    </Modal>
  );
}
