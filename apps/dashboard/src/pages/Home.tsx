import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { CalendarDays, Car, ClipboardCheck, Package, MapPin, UserPlus, CheckCircle2 } from "lucide-react";
import { supabase } from "../lib/supabase";
import { friendly, listCars, listLots, listPackageCatalog, membersPage, pendingDrivesPage, profileNames, schedule } from "../lib/api";
import { useSchool } from "../session";
import { perms } from "../lib/perms";
import { Card, Empty, ErrorBox, Loading, PageHeader } from "../components/ui";
import { CalendarMapSplit } from "../components/CalendarMapSplit";
import type { Lesson } from "../lib/types";

const CHECKLIST_KEY = (schoolId: string) => `ll-setup-${schoolId}`;

type ChecklistState = {
  dismissed?: boolean;
  invite?: boolean;
  lot?: boolean;
  packages?: boolean;
  car?: boolean;
};

function dayBounds(d = new Date()) {
  const start = new Date(d);
  start.setHours(0, 0, 0, 0);
  const end = new Date(d);
  end.setHours(23, 59, 59, 999);
  return { from: start, to: end };
}

export default function HomePage() {
  const membership = useSchool();
  const schoolId = membership.school_id;
  const schoolName = membership.schools?.name ?? "your school";
  const p = perms(membership);
  const [lessons, setLessons] = useState<Lesson[] | null>(null);
  const [names, setNames] = useState<Record<string, string>>({});
  const [pendingN, setPendingN] = useState(0);
  const [carN, setCarN] = useState(0);
  const [dueCars, setDueCars] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const [check, setCheck] = useState<ChecklistState>({});

  const { from, to } = useMemo(() => dayBounds(), []);

  useEffect(() => {
    try {
      setCheck(JSON.parse(localStorage.getItem(CHECKLIST_KEY(schoolId)) || "{}") as ChecklistState);
    } catch {
      setCheck({});
    }
  }, [schoolId]);

  function saveCheck(next: ChecklistState) {
    setCheck(next);
    localStorage.setItem(CHECKLIST_KEY(schoolId), JSON.stringify(next));
  }

  const load = useCallback(async () => {
    setErr(null);
    try {
      const [ls, cars, lots, packs, mem] = await Promise.all([
        schedule(supabase, schoolId, from, to),
        listCars(supabase, schoolId).catch(() => []),
        listLots(supabase, schoolId).catch(() => []),
        listPackageCatalog(supabase, schoolId).catch(() => []),
        membersPage(supabase, schoolId, 0).catch(() => ({ rows: [] })),
      ]);
      setLessons(ls);
      setCarN(cars.length);
      setDueCars(
        cars.filter((c) => {
          const dates = [c.ins_due, c.reg_due, c.inspect_due, c.service_due].filter(Boolean) as string[];
          return dates.some((d) => (new Date(d).getTime() - Date.now()) / 86400000 < 30);
        }).length,
      );
      const ids = [...new Set(ls.map((l) => l.instructor_id).filter(Boolean))] as string[];
      setNames(await profileNames(supabase, ids));
      if (p.reviewDrives) {
        const pd = await pendingDrivesPage(supabase, schoolId, null, 5);
        setPendingN(pd.rows.length);
      } else setPendingN(0);

      // auto-complete checklist from live data
      const staff = mem.rows.filter((m) => m.role === "instructor" || m.role === "front_desk");
      const pinned = lots.some((l) => l.lat != null && l.lng != null);
      const priced = packs.some((pk) => Number(pk.price) > 0);
      setCheck((prev) => {
        const next = {
          ...prev,
          invite: prev.invite || staff.length > 0,
          lot: prev.lot || pinned,
          packages: prev.packages || priced,
          car: prev.car || cars.length > 0,
        };
        localStorage.setItem(CHECKLIST_KEY(schoolId), JSON.stringify(next));
        return next;
      });
    } catch (e) {
      setErr(friendly(e));
      setLessons([]);
    }
  }, [schoolId, from, to, p.reviewDrives]);

  useEffect(() => {
    void load();
  }, [load]);

  const hour = new Date().getHours();
  const hello = hour < 12 ? "Good Morning" : hour < 17 ? "Good Afternoon" : "Good Evening";
  const items = [
    { key: "invite" as const, label: "Invite an instructor or front desk", to: "/people", icon: <UserPlus size={16} /> },
    { key: "lot" as const, label: "Pin your lot on the map", to: "/fleet", icon: <MapPin size={16} /> },
    { key: "packages" as const, label: "Set package prices", to: "/packages", icon: <Package size={16} /> },
    { key: "car" as const, label: "Add a training car", to: "/fleet", icon: <Car size={16} /> },
  ];
  const remaining = items.filter((i) => !check[i.key]).length;
  const showChecklist = p.manageSchool && !check.dismissed && remaining > 0;

  if (lessons === null && !err) return <Loading label="Loading today…" />;

  return (
    <>
      <PageHeader title={`${hello}`} desc={`${schoolName} · Today At A Glance`}>
        <Link className="btn primary" to="/board">
          Open board
        </Link>
      </PageHeader>
      {err && <ErrorBox error={err} onRetry={() => void load()} />}

      <div className="kpi-grid">
        <div className="kpi">
          <div className="kpi-label">
            <CalendarDays size={16} /> Lessons Today
          </div>
          <div className="kpi-value">{lessons?.length ?? 0}</div>
          <Link className="kpi-link" to="/board">
            View board
          </Link>
        </div>
        {p.reviewDrives && (
          <div className="kpi">
            <div className="kpi-label">
              <ClipboardCheck size={16} /> Sign-offs
            </div>
            <div className="kpi-value">{pendingN}</div>
            <Link className="kpi-link" to="/drives">
              Review
            </Link>
          </div>
        )}
        {p.manageSchool && (
          <div className="kpi">
            <div className="kpi-label">
              <Car size={16} /> Fleet
            </div>
            <div className="kpi-value">{carN}</div>
            <div className="kpi-meta">{dueCars ? `${dueCars} due soon` : "All clear"}</div>
          </div>
        )}
        <div className="kpi">
          <div className="kpi-label">
            <Package size={16} /> Setup
          </div>
          <div className="kpi-value">{showChecklist ? remaining : "✓"}</div>
          <div className="kpi-meta">{showChecklist ? "steps left" : "Ready"}</div>
        </div>
      </div>

      {lessons && (
        <CalendarMapSplit schoolId={schoolId} lessons={lessons} names={names} schoolCity={membership.schools?.city} defaultView="day" />
      )}

      {showChecklist && (
        <Card
          title="Get Your School Ready"
          count={`${remaining} left`}
          actions={
            <button type="button" className="btn sm ghost" onClick={() => saveCheck({ ...check, dismissed: true })}>
              Dismiss
            </button>
          }
        >
          <ul className="checklist">
            {items.map((i) => {
              const done = !!check[i.key];
              return (
                <li key={i.key} className={done ? "done" : ""}>
                  <CheckCircle2 size={18} className={done ? "ok" : "muted"} />
                  <span>{i.label}</span>
                  {!done && (
                    <Link className="btn sm" to={i.to}>
                      {i.icon} Go
                    </Link>
                  )}
                </li>
              );
            })}
          </ul>
        </Card>
      )}

      <Card title="Today’s Lessons" count={lessons?.length ? `${lessons.length}` : undefined} actions={<Link to="/board">Board</Link>}>
        {!lessons?.length ? (
          <Empty>
            No lessons scheduled today. <Link to="/plan">Plan availability</Link> or open the <Link to="/board">Board</Link>.
          </Empty>
        ) : (
          <ul className="today-list">
            {lessons
              .slice()
              .sort((a, b) => a.start_at.localeCompare(b.start_at))
              .map((l) => {
                const t = new Date(l.start_at);
                const time = t.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
                return (
                  <li key={l.id}>
                    <span className="today-time">{time}</span>
                    <span className="today-body">
                      <strong>{l.kind || "Lesson"}</strong>
                      <span className="muted">
                        {names[l.instructor_id || ""] || "Instructor"}
                        {l.meet ? ` · ${l.meet}` : ""}
                      </span>
                    </span>
                    <span className={`badge b-${l.status === "taught" ? "ok" : l.status === "canceled" ? "bad" : "info"}`}>{l.status}</span>
                  </li>
                );
              })}
          </ul>
        )}
      </Card>
    </>
  );
}
