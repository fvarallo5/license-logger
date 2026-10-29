import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import {
  type StudentCursor,
  addStudent,
  cancelLinkRequest,
  formerStudentsPage,
  linkRequestsPage,
  requestStudentLink,
  studentsPage,
  type NewStudent,
} from "../lib/api";
import { usePaged } from "../lib/usePaged";
import { useSchool } from "../session";
import { perms } from "../lib/perms";
import { fmtDate, fmtDateTime, statusTone } from "../lib/format";
import { Badge, Card, Empty, ErrorBox, Loading, Modal, PageHeader, Pager, Progress } from "../components/ui";

type Tab = "active" | "requests" | "former";

export default function Students() {
  const current = useSchool();
  const schoolId = current.school_id;
  const p = perms(current);
  const [tab, setTab] = useState<Tab>("active");
  const [adding, setAdding] = useState(false);
  const [linking, setLinking] = useState(false);
  const [flash, setFlash] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const done = (m: string) => {
    setFlash(m);
    setReloadKey((k) => k + 1);
  };

  return (
    <>
      <PageHeader title="Students" desc="Everyone enrolled at your school, their hours, and pending sign-offs.">
        <div className="seg" role="tablist">
          {(["active", "requests", "former"] as Tab[]).map((t) => (
            <button key={t} role="tab" aria-selected={tab === t} className={tab === t ? "on" : ""} onClick={() => setTab(t)}>
              {{ active: "Enrolled", requests: "Join requests", former: "Former" }[t]}
            </button>
          ))}
        </div>
        {p.manageStudents && (
          <button className="btn" onClick={() => setLinking(true)}>
            Link app student
          </button>
        )}
        {p.manageStudents && (
          <button className="btn primary" onClick={() => setAdding(true)}>
            + Add student
          </button>
        )}
      </PageHeader>
      {flash && (
        <div className="alert ok" role="status">
          {flash}{" "}
          <button className="btn link" onClick={() => setFlash(null)}>
            Dismiss
          </button>
        </div>
      )}
      {tab === "active" && <Roster key={reloadKey} schoolId={schoolId} />}
      {tab === "requests" && <Requests key={reloadKey} schoolId={schoolId} canManage={p.manageStudents} onDone={done} />}
      {tab === "former" && <Former schoolId={schoolId} />}
      {adding && (
        <AddStudent
          schoolId={schoolId}
          onClose={() => setAdding(false)}
          onDone={(m) => {
            setAdding(false);
            setTab("active");
            done(m);
          }}
        />
      )}
      {linking && (
        <LinkStudent
          schoolId={schoolId}
          onClose={() => setLinking(false)}
          onDone={(m) => {
            setLinking(false);
            setTab("requests");
            done(m);
          }}
        />
      )}
    </>
  );
}

function Roster({ schoolId }: { schoolId: string }) {
  const pg = usePaged((c: StudentCursor | null) => studentsPage(supabase, schoolId, c), schoolId);
  return (
    <Card title="Enrolled students" count={pg.loading ? "" : `${pg.rows.length} on this page`}>
      {pg.error ? (
        <ErrorBox error={pg.error} onRetry={pg.reload} />
      ) : pg.loading ? (
        <Loading />
      ) : !pg.rows.length ? (
        <Empty>No students yet. Add one, or give students your school join code from their app.</Empty>
      ) : (
        <div style={{ overflowX: "auto" }}>
          <table className="t">
            <thead>
              <tr>
                <th>Student</th>
                <th>Status</th>
                <th>Practice</th>
                <th style={{ width: 160 }}>Progress</th>
                <th>Night</th>
                <th>School hrs</th>
                <th>Pending</th>
                <th>Last drive</th>
              </tr>
            </thead>
            <tbody>
              {pg.rows.map((r) => (
                <tr key={r.student_id}>
                  <td>
                    <Link to={`/students/${r.student_id}`}>
                      {r.first_name} {r.last_name}
                    </Link>
                  </td>
                  <td>
                    <Badge tone={r.seat === "active" ? "ok" : "info"}>{r.seat}</Badge>
                  </td>
                  <td className="num">
                    {Number(r.practice_hours).toFixed(1)} / {Number(r.hour_goal)} h
                  </td>
                  <td>
                    <Progress have={Number(r.practice_hours)} need={Number(r.hour_goal)} label="Practice hours" />
                  </td>
                  <td className="num">
                    {Number(r.night_hours).toFixed(1)} / {Number(r.night_goal)} h
                  </td>
                  <td className="num">{Number(r.school_hours).toFixed(1)} h</td>
                  <td>
                    {Number(r.pending_drives) > 0 ? (
                      <Badge tone="warn">{r.pending_drives} pending</Badge>
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                  <td>{fmtDate(r.last_drive_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager {...pg} />
    </Card>
  );
}

function Requests({ schoolId, canManage, onDone }: { schoolId: string; canManage: boolean; onDone: (m: string) => void }) {
  const pg = usePaged((c: number | null) => linkRequestsPage(supabase, schoolId, c ?? 0), schoolId);
  const [err, setErr] = useState<string | null>(null);
  async function cancel(id: string) {
    setErr(null);
    try {
      await cancelLinkRequest(supabase, id);
      onDone("Request cancelled.");
    } catch (e) {
      setErr((e as Error).message);
    }
  }
  return (
    <Card title="Join requests to app students" count="Students or their parents accept these in the LicenseLogger app">
      {err && <ErrorBox error={err} />}
      {pg.error ? (
        <ErrorBox error={pg.error} onRetry={pg.reload} />
      ) : pg.loading ? (
        <Loading />
      ) : !pg.rows.length ? (
        <Empty>No requests yet. Use “Link app student” with the code a student shows in their app.</Empty>
      ) : (
        <table className="t">
          <thead>
            <tr>
              <th>Request</th>
              <th>Status</th>
              <th>Sent</th>
              <th>Expires</th>
              <th>Answered</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {pg.rows.map((r) => (
              <tr key={r.id}>
                <td className="mono">{r.student_id.slice(0, 8)}</td>
                <td>
                  <Badge tone={statusTone(r.status)}>{r.status}</Badge>
                </td>
                <td>{fmtDateTime(r.created_at)}</td>
                <td>{fmtDate(r.expires_at)}</td>
                <td>{fmtDateTime(r.responded_at)}</td>
                <td>
                  {canManage && r.status === "pending" && (
                    <button className="btn sm danger" onClick={() => void cancel(r.id)}>
                      Cancel
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <Pager {...pg} />
    </Card>
  );
}

function Former({ schoolId }: { schoolId: string }) {
  const pg = usePaged((c: number | null) => formerStudentsPage(supabase, schoolId, c ?? 0), schoolId);
  return (
    <Card title="Former students" count="Kept for your records. Their new hours are private to them.">
      {pg.error ? (
        <ErrorBox error={pg.error} onRetry={pg.reload} />
      ) : pg.loading ? (
        <Loading />
      ) : !pg.rows.length ? (
        <Empty>No former students.</Empty>
      ) : (
        <table className="t">
          <thead>
            <tr>
              <th>Name</th>
              <th>Joined</th>
              <th>How</th>
              <th>Left</th>
              <th>Reason</th>
            </tr>
          </thead>
          <tbody>
            {pg.rows.map((r) => (
              <tr key={r.id}>
                <td>
                  {r.first_name} {r.last_name}
                </td>
                <td>{fmtDate(r.joined_at)}</td>
                <td>{r.joined_via.replace(/_/g, " ")}</td>
                <td>{fmtDate(r.left_at)}</td>
                <td>{(r.left_reason ?? "—").replace(/_/g, " ")}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <Pager {...pg} />
    </Card>
  );
}

function AddStudent({ schoolId, onClose, onDone }: { schoolId: string; onClose: () => void; onDone: (m: string) => void }) {
  const [f, setF] = useState<NewStudent>({
    first_name: "",
    last_name: "",
    birthday: null,
    parent_name: "",
    parent_email: "",
    instructor_id: null,
    package_hours: null,
  });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof NewStudent) => (e: { target: { value: string } }) =>
    setF({
      ...f,
      [k]: k === "package_hours" ? (e.target.value ? Number(e.target.value) : null) : e.target.value || (k === "birthday" ? null : ""),
    });
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      await addStudent(supabase, schoolId, f);
      onDone(`${f.first_name} added. Share their join code from their profile so they can connect the app.`);
    } catch (x) {
      setErr((x as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title="Add student" onClose={onClose}>
      <form onSubmit={submit}>
        {err && <ErrorBox error={err} />}
        <div className="row">
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="fn">First name</label>
            <input id="fn" required value={f.first_name} onChange={set("first_name")} />
          </div>
          <div className="field" style={{ flex: 1 }}>
            <label htmlFor="ln">Last name</label>
            <input id="ln" required value={f.last_name} onChange={set("last_name")} />
          </div>
        </div>
        <div className="field">
          <label htmlFor="bd">Birthday</label>
          <input id="bd" type="date" value={f.birthday ?? ""} onChange={set("birthday")} />
        </div>
        <div className="field">
          <label htmlFor="pn">Parent / guardian name</label>
          <input id="pn" value={f.parent_name} onChange={set("parent_name")} />
        </div>
        <div className="field">
          <label htmlFor="pe">Parent email</label>
          <input id="pe" type="email" value={f.parent_email} onChange={set("parent_email")} />
        </div>
        <div className="field">
          <label htmlFor="ph">Package hours (optional)</label>
          <input id="ph" type="number" min={0} step={0.5} value={f.package_hours ?? ""} onChange={set("package_hours")} />
        </div>
        <div className="row">
          <button className="btn primary" disabled={busy}>
            {busy ? "Adding…" : "Add student"}
          </button>
          <button type="button" className="btn" onClick={onClose}>
            Cancel
          </button>
        </div>
      </form>
    </Modal>
  );
}

function LinkStudent({ schoolId, onClose, onDone }: { schoolId: string; onClose: () => void; onDone: (m: string) => void }) {
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setErr(null);
    try {
      await requestStudentLink(supabase, schoolId, code);
      onDone("Request sent. The student or parent accepts it in their app; it then appears in Enrolled.");
    } catch (x) {
      setErr((x as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal title="Link a student who already uses the app" onClose={onClose}>
      <p className="muted">
        Students without a school can still use LicenseLogger. Ask them for the student code shown in their app’s profile. They (or a
        parent) must accept before you see any of their drives.
      </p>
      <form onSubmit={submit}>
        {err && <ErrorBox error={err} />}
        <div className="field">
          <label htmlFor="code">Student code</label>
          <input id="code" className="mono" required value={code} onChange={(e) => setCode(e.target.value.toUpperCase())} />
        </div>
        <div className="row">
          <button className="btn primary" disabled={busy}>
            {busy ? "Sending…" : "Send request"}
          </button>
          <button type="button" className="btn" onClick={onClose}>
            Cancel
          </button>
        </div>
      </form>
    </Modal>
  );
}
