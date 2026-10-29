import { useEffect, useMemo, useState } from "react";
import { supabase } from "../lib/supabase";
import { markLesson, profileNames, schedule } from "../lib/api";
import { useSchool, useSession } from "../session";
import type { Lesson } from "../lib/types";
import { statusTone } from "../lib/format";
import { Badge, Card, Empty, ErrorBox, Loading, PageHeader } from "../components/ui";

function weekStart(d: Date) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  x.setDate(x.getDate() - ((x.getDay() + 6) % 7));
  return x;
}

export default function SchedulePage() {
  const { session } = useSession();
  const current = useSchool();
  const schoolId = current.school_id;
  const mine = current.role === "instructor";
  const [start, setStart] = useState(() => weekStart(new Date()));
  const end = useMemo(() => new Date(start.getTime() + 7 * 864e5), [start]);
  const [rows, setRows] = useState<Lesson[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [names, setNames] = useState<Record<string, string>>({});
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    setRows(null);
    setErr(null);
    schedule(supabase, schoolId, start, end)
      .then((r) => {
        if (!live) return;
        const list = mine ? r.filter((l) => l.instructor_id === session?.user.id) : r;
        setRows(list);
        void profileNames(supabase, [...new Set(list.map((l) => l.instructor_id))]).then((n) => live && setNames(n));
      })
      .catch((e: Error) => live && setErr(e.message));
    return () => {
      live = false;
    };
  }, [schoolId, start, end, mine, session, tick]);

  const byDay = useMemo(() => {
    const m = new Map<string, Lesson[]>();
    for (const l of [...(rows ?? [])].sort((x, y) => x.start_at.localeCompare(y.start_at))) {
      const k = new Date(l.start_at).toDateString();
      m.set(k, [...(m.get(k) ?? []), l]);
    }
    return [...m.entries()];
  }, [rows]);
  const move = (n: number) => setStart(new Date(start.getTime() + n * 7 * 864e5));
  async function mark(l: Lesson, s: "taught" | "no_show" | "cancelled") {
    try {
      await markLesson(supabase, l.id, s);
      setTick((t) => t + 1);
    } catch (e) {
      setErr((e as Error).message);
    }
  }
  const t = (iso: string) => new Date(iso).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" });

  return (
    <>
      <PageHeader title="Schedule" desc={mine ? "Your lessons this week." : "Lessons across your school, one week at a time."}>
        <button className="btn" aria-label="Previous week" onClick={() => move(-1)}>
          ←
        </button>
        <span className="pill light" aria-live="polite">
          {start.toLocaleDateString(undefined, { month: "short", day: "numeric" })} –{" "}
          {new Date(end.getTime() - 1).toLocaleDateString(undefined, { month: "short", day: "numeric" })}
        </span>
        <button className="btn" aria-label="Next week" onClick={() => move(1)}>
          →
        </button>
        <button className="btn" onClick={() => setStart(weekStart(new Date()))}>
          This week
        </button>
      </PageHeader>
      {err && <ErrorBox error={err} onRetry={() => setTick((x) => x + 1)} />}
      {!rows && !err ? (
        <Loading />
      ) : rows && !rows.length ? (
        <Card>
          <Empty>No lessons this week. Booking from the dashboard is coming in v2; the app’s booking flow still works.</Empty>
        </Card>
      ) : (
        byDay.map(([day, ls]) => (
          <Card
            key={day}
            title={new Date(day).toLocaleDateString(undefined, { weekday: "long", month: "short", day: "numeric" })}
            count={`${ls.length} lesson${ls.length > 1 ? "s" : ""}`}
          >
            <table className="t fixed">
              <colgroup>
                <col style={{ width: 190 }} />
                <col />
                <col style={{ width: 150 }} />
                <col style={{ width: 160 }} />
                <col style={{ width: 130 }} />
                <col style={{ width: 170 }} />
              </colgroup>
              <tbody>
                {ls.map((l) => (
                  <tr key={l.id}>
                    <td>
                      {t(l.start_at)} – {t(l.end_at)}
                    </td>
                    <td>{l.topic || l.name || l.kind}</td>
                    <td className="muted">{l.meet}</td>
                    <td>{names[l.instructor_id] ?? "Instructor"}</td>
                    <td>
                      <Badge tone={statusTone(l.status)}>{l.status.replace(/_/g, " ")}</Badge>
                    </td>
                    <td>
                      {l.status === "booked" && (
                        <span className="row nowrap">
                          <button className="btn sm" onClick={() => void mark(l, "taught")}>
                            Done
                          </button>
                          <button className="btn sm" onClick={() => void mark(l, "no_show")}>
                            No-show
                          </button>
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        ))
      )}
    </>
  );
}
