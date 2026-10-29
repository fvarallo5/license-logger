import { useCallback, useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase";
import {
  acceptReservation,
  addBlock,
  addSlotTemplate,
  bookLesson,
  declineReservation,
  friendly,
  listCars,
  listReservations,
  listSlotTemplates,
  membersPage,
  profileNames,
  studentsPage,
} from "../lib/api";
import { perms } from "../lib/perms";
import { statusTone } from "../lib/format";
import { addDays, fmtTime, weekStart } from "../lib/boardHelpers";
import { useSchool, useSession } from "../session";
import type { Car, Member, Reservation, SlotTemplate, StudentProgressRow } from "../lib/types";
import { Badge, Card, Empty, ErrorBox, Loading, Modal, PageHeader } from "../components/ui";

const DAY_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export default function PlanPage() {
  const { session } = useSession();
  const current = useSchool();
  const p = perms(current);
  const schoolId = current.school_id;
  const me = session?.user.id ?? "";

  const [anchor, setAnchor] = useState(() => weekStart(new Date()));
  const [templates, setTemplates] = useState<SlotTemplate[] | null>(null);
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [cars, setCars] = useState<Car[]>([]);
  const [instructors, setInstructors] = useState<Member[]>([]);
  const [students, setStudents] = useState<StudentProgressRow[]>([]);
  const [names, setNames] = useState<Record<string, string>>({});
  const [err, setErr] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  const [showTemplate, setShowTemplate] = useState(false);
  const [showBook, setShowBook] = useState(false);
  const [showBlock, setShowBlock] = useState(false);

  const from = anchor;
  const to = useMemo(() => addDays(anchor, 7), [anchor]);

  const load = useCallback(async () => {
    setErr(null);
    try {
      const [tpl, res, carRows, mem, stu] = await Promise.all([
        listSlotTemplates(supabase, schoolId),
        listReservations(supabase, schoolId, from, to),
        listCars(supabase, schoolId).catch(() => [] as Car[]),
        membersPage(supabase, schoolId, 0),
        studentsPage(supabase, schoolId, null, 100),
      ]);
      setTemplates(p.instructorOnly ? tpl.filter((t) => t.instructor_id === me) : tpl);
      setReservations(p.instructorOnly ? res.filter((r) => r.instructor_id === me) : res.filter((r) => r.status === "requested"));
      setCars(carRows);
      setInstructors(mem.rows.filter((m) => ["instructor", "owner", "admin"].includes(m.role)));
      setStudents(stu.rows);
      const ids = [...new Set([...tpl.map((t) => t.instructor_id), ...res.map((r) => r.instructor_id)])];
      setNames(await profileNames(supabase, ids));
    } catch (e) {
      setErr(friendly(e));
      setTemplates([]);
    }
  }, [schoolId, from, to, p.instructorOnly, me, tick]);

  useEffect(() => {
    void load();
  }, [load]);

  const openRequests = reservations.filter((r) => r.status === "requested");

  return (
    <>
      <PageHeader title="Plan" desc="Slot templates, booking requests, and blocks for the week.">
        <button className="btn" aria-label="Previous week" onClick={() => setAnchor((a) => addDays(a, -7))}>
          ←
        </button>
        <span className="pill light">
          {anchor.toLocaleDateString(undefined, { month: "short", day: "numeric" })} –{" "}
          {addDays(anchor, 6).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
        </span>
        <button className="btn" aria-label="Next week" onClick={() => setAnchor((a) => addDays(a, 7))}>
          →
        </button>
        <button className="btn" onClick={() => setAnchor(weekStart(new Date()))}>
          This week
        </button>
        {p.manageBoard && (
          <button className="btn primary" onClick={() => setShowTemplate(true)}>
            + Template
          </button>
        )}
        <button className="btn" onClick={() => setShowBook(true)}>
          Book lesson
        </button>
        <button className="btn" onClick={() => setShowBlock(true)}>
          Block time
        </button>
      </PageHeader>

      {err && <ErrorBox error={err} onRetry={() => setTick((t) => t + 1)} />}

      <Card title="Booking requests" count={openRequests.length}>
        {openRequests.length === 0 ? (
          <Empty>No open requests this week.</Empty>
        ) : (
          <ul className="plan-list">
            {openRequests.map((r) => (
              <li key={r.id} className="plan-row">
                <div>
                  <strong>
                    {fmtTime(r.start_at)}–{fmtTime(r.end_at)}
                  </strong>
                  <span className="muted">
                    {" "}
                    · {names[r.instructor_id] || "Instructor"} · {r.meet} · {r.kind}
                  </span>
                  {r.note && <div className="muted">{r.note}</div>}
                </div>
                <Badge tone={statusTone(r.status)}>{r.status}</Badge>
                {p.manageBoard || r.instructor_id === me ? (
                  <div className="board-actions">
                    <button
                      className="btn sm primary"
                      onClick={() =>
                        void acceptReservation(supabase, r.id)
                          .then(() => setTick((t) => t + 1))
                          .catch((e) => setErr(friendly(e)))
                      }
                    >
                      Accept
                    </button>
                    <button
                      className="btn sm"
                      onClick={() => {
                        const reason = window.prompt("Decline reason?") || "";
                        if (!reason.trim()) return;
                        void declineReservation(supabase, r.id, reason)
                          .then(() => setTick((t) => t + 1))
                          .catch((e) => setErr(friendly(e)));
                      }}
                    >
                      Decline
                    </button>
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card title="Slot templates" count={templates === null ? "" : templates.length}>
        {templates === null ? (
          <Loading label="Loading templates…" />
        ) : templates.length === 0 ? (
          <Empty>No templates yet. Add one to open booking windows.</Empty>
        ) : (
          <div className="plan-templates">
            {templates.map((t) => (
              <article key={t.id} className="board-card">
                <div className="board-card-top">
                  <div>
                    <h3>{t.name}</h3>
                    <p className="muted">
                      {names[t.instructor_id] || "Instructor"} · {t.duration_minutes} min · {t.meet} · {t.kind}
                    </p>
                    <p className="muted">
                      {t.window_start.slice(0, 5)}–{t.window_end.slice(0, 5)} ·{" "}
                      {(t.days || []).map((d) => DAY_LABELS[(d + 6) % 7] || d).join(" ")}
                    </p>
                  </div>
                  <Badge tone="info">active</Badge>
                </div>
              </article>
            ))}
          </div>
        )}
      </Card>

      {showTemplate && (
        <TemplateModal
          instructors={instructors}
          cars={cars}
          names={names}
          defaultInstructor={p.instructorOnly ? me : instructors[0]?.user_id || me}
          onClose={() => setShowTemplate(false)}
          onSave={async (form) => {
            try {
              await addSlotTemplate(supabase, { schoolId, ...form });
              setShowTemplate(false);
              setTick((t) => t + 1);
            } catch (e) {
              setErr(friendly(e));
            }
          }}
        />
      )}

      {showBook && (
        <BookModal
          students={students}
          instructors={instructors}
          cars={cars}
          names={names}
          defaultInstructor={p.instructorOnly ? me : instructors[0]?.user_id || me}
          onClose={() => setShowBook(false)}
          onSave={async (form) => {
            try {
              await bookLesson(supabase, { schoolId, ...form });
              setShowBook(false);
              setTick((t) => t + 1);
            } catch (e) {
              setErr(friendly(e));
            }
          }}
        />
      )}

      {showBlock && (
        <BlockModal
          instructors={instructors}
          names={names}
          defaultInstructor={p.instructorOnly ? me : instructors[0]?.user_id || me}
          onClose={() => setShowBlock(false)}
          onSave={async (instructorId, start, end, name) => {
            try {
              await addBlock(supabase, schoolId, instructorId, start, end, name);
              setShowBlock(false);
              setTick((t) => t + 1);
            } catch (e) {
              setErr(friendly(e));
            }
          }}
        />
      )}
    </>
  );
}

function TemplateModal({
  instructors,
  cars,
  names,
  defaultInstructor,
  onClose,
  onSave,
}: {
  instructors: Member[];
  cars: Car[];
  names: Record<string, string>;
  defaultInstructor: string;
  onClose: () => void;
  onSave: (f: {
    instructorId: string;
    name: string;
    durationMinutes: number;
    days: number[];
    windowStart: string;
    windowEnd: string;
    meet: string;
    carId: string | null;
  }) => Promise<void>;
}) {
  const [name, setName] = useState("Weekday BTW");
  const [instructorId, setInstructorId] = useState(defaultInstructor);
  const [duration, setDuration] = useState(60);
  const [days, setDays] = useState([1, 2, 3, 4, 5]);
  const [windowStart, setWindowStart] = useState("09:00");
  const [windowEnd, setWindowEnd] = useState("17:00");
  const [meet, setMeet] = useState("lot");
  const [carId, setCarId] = useState("");
  const [busy, setBusy] = useState(false);
  const toggleDay = (d: number) => setDays((prev) => (prev.includes(d) ? prev.filter((x) => x !== d) : [...prev, d].sort()));
  return (
    <Modal title="New slot template" onClose={onClose}>
      <label className="stack">
        Name
        <input value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <label className="stack">
        Instructor
        <select value={instructorId} onChange={(e) => setInstructorId(e.target.value)}>
          {instructors.map((m) => (
            <option key={m.user_id} value={m.user_id}>
              {names[m.user_id] || m.user_id.slice(0, 8)}
            </option>
          ))}
        </select>
      </label>
      <label className="stack">
        Duration (minutes)
        <input type="number" value={duration} onChange={(e) => setDuration(Number(e.target.value))} />
      </label>
      <fieldset className="stack">
        <legend>Days</legend>
        <div className="board-actions">
          {[1, 2, 3, 4, 5, 6, 0].map((d) => (
            <button key={d} type="button" className={`btn sm${days.includes(d) ? " primary" : ""}`} onClick={() => toggleDay(d)}>
              {DAY_LABELS[(d + 6) % 7]}
            </button>
          ))}
        </div>
      </fieldset>
      <label className="stack">
        Window start
        <input value={windowStart} onChange={(e) => setWindowStart(e.target.value)} placeholder="09:00" />
      </label>
      <label className="stack">
        Window end
        <input value={windowEnd} onChange={(e) => setWindowEnd(e.target.value)} placeholder="17:00" />
      </label>
      <label className="stack">
        Meet
        <select value={meet} onChange={(e) => setMeet(e.target.value)}>
          <option value="lot">Lot</option>
          <option value="pickup">Pickup</option>
        </select>
      </label>
      <label className="stack">
        Car
        <select value={carId} onChange={(e) => setCarId(e.target.value)}>
          <option value="">Any</option>
          {cars.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </label>
      <div className="row" style={{ gap: 8, marginTop: 12 }}>
        <button className="btn" onClick={onClose}>
          Back
        </button>
        <button
          className="btn primary"
          disabled={busy || !name.trim()}
          onClick={() => {
            setBusy(true);
            void onSave({
              instructorId,
              name: name.trim(),
              durationMinutes: duration,
              days,
              windowStart,
              windowEnd,
              meet,
              carId: carId || null,
            }).finally(() => setBusy(false));
          }}
        >
          Save template
        </button>
      </div>
    </Modal>
  );
}

function BookModal({
  students,
  instructors,
  cars,
  names,
  defaultInstructor,
  onClose,
  onSave,
}: {
  students: StudentProgressRow[];
  instructors: Member[];
  cars: Car[];
  names: Record<string, string>;
  defaultInstructor: string;
  onClose: () => void;
  onSave: (f: { studentId: string; instructorId: string; start: string; end: string; meet: string; carId: string | null }) => Promise<void>;
}) {
  const [studentId, setStudentId] = useState(students[0]?.student_id || "");
  const [instructorId, setInstructorId] = useState(defaultInstructor);
  const [startLocal, setStartLocal] = useState("");
  const [endLocal, setEndLocal] = useState("");
  const [meet, setMeet] = useState("lot");
  const [carId, setCarId] = useState("");
  const [busy, setBusy] = useState(false);
  return (
    <Modal title="Book lesson" onClose={onClose}>
      <label className="stack">
        Student
        <select value={studentId} onChange={(e) => setStudentId(e.target.value)}>
          {students.map((s) => (
            <option key={s.student_id} value={s.student_id}>
              {s.first_name} {s.last_name}
            </option>
          ))}
        </select>
      </label>
      <label className="stack">
        Instructor
        <select value={instructorId} onChange={(e) => setInstructorId(e.target.value)}>
          {instructors.map((m) => (
            <option key={m.user_id} value={m.user_id}>
              {names[m.user_id] || m.user_id.slice(0, 8)}
            </option>
          ))}
        </select>
      </label>
      <label className="stack">
        Start
        <input type="datetime-local" value={startLocal} onChange={(e) => setStartLocal(e.target.value)} />
      </label>
      <label className="stack">
        End
        <input type="datetime-local" value={endLocal} onChange={(e) => setEndLocal(e.target.value)} />
      </label>
      <label className="stack">
        Meet
        <select value={meet} onChange={(e) => setMeet(e.target.value)}>
          <option value="lot">Lot</option>
          <option value="pickup">Pickup</option>
        </select>
      </label>
      <label className="stack">
        Car
        <select value={carId} onChange={(e) => setCarId(e.target.value)}>
          <option value="">None</option>
          {cars.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </label>
      <div className="row" style={{ gap: 8, marginTop: 12 }}>
        <button className="btn" onClick={onClose}>
          Back
        </button>
        <button
          className="btn primary"
          disabled={busy || !studentId || !startLocal || !endLocal}
          onClick={() => {
            setBusy(true);
            void onSave({
              studentId,
              instructorId,
              start: new Date(startLocal).toISOString(),
              end: new Date(endLocal).toISOString(),
              meet,
              carId: carId || null,
            }).finally(() => setBusy(false));
          }}
        >
          Book
        </button>
      </div>
    </Modal>
  );
}

function BlockModal({
  instructors,
  names,
  defaultInstructor,
  onClose,
  onSave,
}: {
  instructors: Member[];
  names: Record<string, string>;
  defaultInstructor: string;
  onClose: () => void;
  onSave: (instructorId: string, start: string, end: string, name: string) => Promise<void>;
}) {
  const [instructorId, setInstructorId] = useState(defaultInstructor);
  const [startLocal, setStartLocal] = useState("");
  const [endLocal, setEndLocal] = useState("");
  const [name, setName] = useState("Blocked");
  const [busy, setBusy] = useState(false);
  return (
    <Modal title="Block time" onClose={onClose}>
      <label className="stack">
        Instructor
        <select value={instructorId} onChange={(e) => setInstructorId(e.target.value)}>
          {instructors.map((m) => (
            <option key={m.user_id} value={m.user_id}>
              {names[m.user_id] || m.user_id.slice(0, 8)}
            </option>
          ))}
        </select>
      </label>
      <label className="stack">
        Label
        <input value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <label className="stack">
        Start
        <input type="datetime-local" value={startLocal} onChange={(e) => setStartLocal(e.target.value)} />
      </label>
      <label className="stack">
        End
        <input type="datetime-local" value={endLocal} onChange={(e) => setEndLocal(e.target.value)} />
      </label>
      <div className="row" style={{ gap: 8, marginTop: 12 }}>
        <button className="btn" onClick={onClose}>
          Back
        </button>
        <button
          className="btn primary"
          disabled={busy || !startLocal || !endLocal}
          onClick={() => {
            setBusy(true);
            void onSave(instructorId, new Date(startLocal).toISOString(), new Date(endLocal).toISOString(), name).finally(() =>
              setBusy(false),
            );
          }}
        >
          Block
        </button>
      </div>
    </Modal>
  );
}
